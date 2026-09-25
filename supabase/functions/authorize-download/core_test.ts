// deno test supabase/functions/authorize-download/
// Fără rețea, fără secrete: cheie Ed25519 generată în test, dependențe false.
// Aserțiuni locale (fără dependențe de rețea la rularea testelor).
function assert(cond: unknown, msg = "aserțiune eșuată"): asserts cond { if (!cond) throw new Error(msg); }
function assertEquals(actual: unknown, expected: unknown, msg = "") {
  const norm = (v: unknown) => JSON.stringify(v, (_k, x) => x instanceof Uint8Array ? [...x] : x);
  if (norm(actual) !== norm(expected)) throw new Error(`${msg} așteptat ${norm(expected)}, primit ${norm(actual)}`);
}
import { authorize, type Deps, parseRequest, RATE_LIMIT } from "./core.ts";
import { base32Decode, base32Encode, PUBLIC_KEY_BASE64, productHash, verifySerial } from "./license.ts";

const MACHINE = base32Encode(new Uint8Array([1, 2, 3, 4, 5, 6])); // 10 caractere
const OTHER_MACHINE = base32Encode(new Uint8Array([7, 7, 7, 7, 7, 7]));
const NOW = new Date("2026-09-25T12:00:00Z");

const keyPair = await crypto.subtle.generateKey({ name: "Ed25519" }, true, ["sign", "verify"]) as CryptoKeyPair;
const testPublicKey = btoa(String.fromCharCode(...new Uint8Array(await crypto.subtle.exportKey("raw", keyPair.publicKey))));

async function makeSerial(productID: string, opts: { expiresAt?: number; machine?: number[]; platform?: number; signer?: CryptoKey } = {}) {
  const p: number[] = [...await productHash(productID)];
  const exp = opts.expiresAt ?? 0;
  for (let s = 7; s >= 0; s--) p.push(Math.floor(exp / 2 ** (8 * s)) & 0xff);
  p.push(9, 9, 9, 9, ...(opts.machine ?? [0, 0, 0, 0, 0, 0]));
  if (opts.platform !== undefined) p.push(opts.platform);
  const payload = new Uint8Array(p);
  const sig = new Uint8Array(await crypto.subtle.sign({ name: "Ed25519" }, opts.signer ?? keyPair.privateKey, payload));
  const all = new Uint8Array(payload.length + 64);
  all.set(payload);
  all.set(sig, payload.length);
  return base32Encode(all);
}

const PAID = "gdc-paid-product";
const FREE = "gdc-free-demo";
const SHA = "a".repeat(64);
const catalog = {
  items: [
    { id: PAID, isFree: false, supportedOS: "crossPlatform", files: [{ path: `${PAID}/1.0/a.ofx`, sha256: SHA, repo: "files" }] },
    { id: FREE, isFree: true, isTrial: true, supportedOS: "macOS", files: [{ path: `${FREE}/1.0/b.ofx`, sha256: SHA, repo: "files" }] },
    { id: "gdc-bad-repo", isFree: true, files: [{ path: "gdc-bad-repo/x", sha256: SHA, repo: "secret-repo" }] },
    { id: "gdc-foreign-path", isFree: true, files: [{ path: `${PAID}/1.0/a.ofx`, sha256: SHA, repo: "files" }] },
  ],
  pdfResources: [{ id: "doc", isFree: true, filePath: "doc/x.pdf", fileSHA256: SHA, fileRepo: "pdfs" }],
};

function deps(over: Partial<Deps> = {}) {
  const audits: Record<string, unknown>[] = [];
  const githubCalls: string[] = [];
  const d: Deps = {
    getCatalog: () => Promise.resolve(catalog),
    isRevoked: () => Promise.resolve(false),
    recentCount: () => Promise.resolve({ machine: 0, ip: 0 }),
    audit: (row) => { audits.push(row); return Promise.resolve(); },
    githubFile: (owner, repo, path) => {
      githubCalls.push(`${owner}/${repo}/${path}`);
      return Promise.resolve({ downloadURL: `https://raw.example/${repo}/${path}?token=T`, size: 10 });
    },
    now: () => NOW,
    licensePublicKey: testPublicKey,
    ...over,
  };
  return { d, audits, githubCalls };
}

const req = (o: Record<string, unknown> = {}) => ({ productID: PAID, path: `${PAID}/1.0/a.ofx`, machineID: MACHINE, platform: "mac", ...o });

// ── VALID ────────────────────────────────────────────────────────────────
Deno.test("valid serial + product + platform + artifact → URL temporar", async () => {
  const { d, githubCalls, audits } = deps();
  const out = await authorize(req({ serial: await makeSerial(PAID) }), "1.1.1.1", d);
  assertEquals(out.status, 200);
  assertEquals(out.body.sha256, SHA);
  assertEquals(githubCalls, [`gordasgdc/gdc-plugin-manager-files/${PAID}/1.0/a.ofx`]);
  assertEquals(audits[0].result, "authorized");
  assert(!JSON.stringify(audits).includes("serial"), "serialul nu se auditează");
});

Deno.test("serial legat de mașină, pe mașina corectă → 200", async () => {
  const { d } = deps();
  const out = await authorize(req({ serial: await makeSerial(PAID, { machine: [1, 2, 3, 4, 5, 6], platform: 3 }) }), "ip", d);
  assertEquals(out.status, 200);
});

Deno.test("produs gratuit/probă fără serial → 200", async () => {
  const { d } = deps();
  assertEquals((await authorize(req({ productID: FREE, path: `${FREE}/1.0/b.ofx` }), "ip", d)).status, 200);
});

Deno.test("resursă legacy (filePath + fileRepo) → repo pdfs", async () => {
  const { d, githubCalls } = deps();
  assertEquals((await authorize(req({ productID: "doc", path: "doc/x.pdf" }), "ip", d)).status, 200);
  assertEquals(githubCalls, ["gordasgdc/gdc-plugin-manager-pdfs/doc/x.pdf"]);
});

// ── REJECT ───────────────────────────────────────────────────────────────
const expectError = async (body: unknown, status: number, code: string, over: Partial<Deps> = {}) => {
  const { d, githubCalls } = deps(over);
  const out = await authorize(body, "ip", d);
  assertEquals([out.status, out.body.error], [status, code]);
  assertEquals(githubCalls.length, 0, "GitHub nu trebuie atins la respingere");
  return out;
};

Deno.test("serial lipsă pentru produs plătit", async () => { await expectError(req(), 403, "invalid_license"); });
Deno.test("serial invalid (text)", async () => { await expectError(req({ serial: "NU-E-SERIAL" }), 403, "invalid_license"); });
Deno.test("serial semnat de altă cheie", async () => {
  const other = await crypto.subtle.generateKey({ name: "Ed25519" }, true, ["sign", "verify"]) as CryptoKeyPair;
  await expectError(req({ serial: await makeSerial(PAID, { signer: other.privateKey }) }), 403, "invalid_license");
});
Deno.test("serial pentru alt produs", async () => { await expectError(req({ serial: await makeSerial("alt-produs") }), 403, "invalid_license"); });
Deno.test("serial pe alt calculator", async () => {
  await expectError(req({ serial: await makeSerial(PAID, { machine: [1, 2, 3, 4, 5, 6] }), machineID: OTHER_MACHINE }), 403, "invalid_license");
});
Deno.test("serial expirat", async () => {
  await expectError(req({ serial: await makeSerial(PAID, { expiresAt: Math.floor(NOW.getTime() / 1000) - 1 }) }), 403, "invalid_license");
});
Deno.test("licență revocată", async () => {
  await expectError(req({ serial: await makeSerial(PAID) }), 403, "revoked_license", { isRevoked: () => Promise.resolve(true) });
});
Deno.test("serial windows_only cerut pe mac", async () => {
  await expectError(req({ serial: await makeSerial(PAID, { platform: 2 }) }), 403, "unauthorized_platform");
});
Deno.test("produs doar macOS cerut pe windows", async () => {
  await expectError(req({ productID: FREE, path: `${FREE}/1.0/b.ofx`, platform: "windows" }), 403, "unauthorized_platform");
});
Deno.test("produs inexistent", async () => { await expectError(req({ productID: "nu-exista", path: "nu-exista/x" }), 404, "unknown_product"); });
Deno.test("fișier care nu aparține produsului", async () => {
  await expectError(req({ path: `${PAID}/1.0/altceva.ofx`, serial: await makeSerial(PAID) }), 403, "unauthorized_artifact");
});
Deno.test("produs gratuit care indică fișierul altui produs (prefix)", async () => {
  await expectError(req({ productID: "gdc-foreign-path", path: `${PAID}/1.0/a.ofx` }), 403, "unauthorized_artifact");
});
Deno.test("repo în afara allowlist-ului", async () => {
  await expectError(req({ productID: "gdc-bad-repo", path: "gdc-bad-repo/x" }), 403, "unauthorized_artifact");
});
Deno.test("fișier lipsă din stocare", async () => {
  const { d } = deps({ githubFile: () => Promise.resolve(null) });
  const out = await authorize(req({ productID: FREE, path: `${FREE}/1.0/b.ofx` }), "ip", d);
  assertEquals([out.status, out.body.error], [404, "artifact_unavailable"]);
});
Deno.test("rate limit per mașină și per IP", async () => {
  const out = await expectError(req({ productID: FREE, path: `${FREE}/1.0/b.ofx` }), 429, "rate_limited",
    { recentCount: () => Promise.resolve({ machine: RATE_LIMIT.perMachine, ip: 0 }) });
  assertEquals(out.headers?.["Retry-After"], String(RATE_LIMIT.windowSeconds));
  await expectError(req({ productID: FREE, path: `${FREE}/1.0/b.ofx` }), 429, "rate_limited",
    { recentCount: () => Promise.resolve({ machine: 0, ip: RATE_LIMIT.perIP }) });
});
Deno.test("cereri malformate", async () => {
  for (const bad of [null, "text", {}, req({ platform: "linux" }), req({ path: "../x" }), req({ path: "/abs" }),
    req({ path: `${PAID}//a` }), req({ path: `${PAID}\\a` }), req({ machineID: "short" }), req({ machineID: "abcdefghij" }),
    req({ serial: 42 }), req({ productID: "x".repeat(201) })]) {
    await expectError(bad, 400, "malformed_request");
  }
});

// ── SECURITATE ───────────────────────────────────────────────────────────
Deno.test("răspunsul nu conține niciodată credentialul (doar URL-ul GitHub)", async () => {
  const { d } = deps();
  const out = await authorize(req({ productID: FREE, path: `${FREE}/1.0/b.ofx` }), "ip", d);
  assertEquals(Object.keys(out.body).sort(), ["issuedAt", "path", "productID", "sha256", "size", "url", "useWithinSeconds"]);
});
Deno.test("parseRequest respinge metacaractere de cale", () => {
  assertEquals(parseRequest(req({ path: "a/../b" })), null);
});

// ── COMPATIBILITATE cu LicenseCore.swift ─────────────────────────────────
Deno.test("vector generat de Swift (CryptoKit) verifică în TypeScript", async () => {
  const v = JSON.parse(await Deno.readTextFile(new URL("./swift_vector.json", import.meta.url)));
  const ok = await verifySerial(v.serial, v.productID, v.machineID, "mac", 1_800_000_000, v.publicKey);
  assert(ok.ok, JSON.stringify(ok));
  const win = await verifySerial(v.serial, v.productID, v.machineID, "windows", 1_800_000_000, v.publicKey);
  assertEquals(win, { ok: false, reason: "wrong_platform" });
});
Deno.test("product hash identic cu Swift (SHA-512(\"abc\")[:4])", async () => {
  assertEquals([...await productHash("abc")], [0xdd, 0xaf, 0x35, 0xa1]);
});
Deno.test("cheia publică de producție nu acceptă seriale de test", async () => {
  const r = await verifySerial(await makeSerial(PAID), PAID, MACHINE, "mac", 0, PUBLIC_KEY_BASE64);
  assertEquals(r, { ok: false, reason: "bad_signature" });
});
Deno.test("base32 round-trip", () => {
  const data = new Uint8Array(87).map((_, i) => (i * 7) & 0xff);
  assertEquals(base32Decode(base32Encode(data)), data);
});
