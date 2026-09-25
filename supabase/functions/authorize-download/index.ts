// Supabase Edge Function `authorize-download` — cablarea dependențelor reale.
// Secrete: GITHUB_READ_TOKEN (Supabase → Edge Functions → Secrets). Nu se loghează, nu se întoarce.
import { authorize, type Deps, type GitHubFile } from "./core.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const GITHUB_TOKEN = Deno.env.get("GITHUB_READ_TOKEN") ?? "";
const CATALOG_URL = Deno.env.get("CATALOG_URL") ?? "https://gordas.dev/catalog.json";
const CATALOG_TTL_MS = 60_000;

let catalogCache: { at: number; data: Record<string, unknown> } | null = null;

const rest = (path: string, init: RequestInit = {}) =>
  fetch(`${SUPABASE_URL}/rest/v1/${path}`, {
    ...init,
    headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}`, "Content-Type": "application/json", ...(init.headers ?? {}) },
  });

async function countSince(column: string, value: string, sinceISO: string): Promise<number> {
  const q = `download_authorizations?select=id&${column}=eq.${encodeURIComponent(value)}&created_at=gte.${encodeURIComponent(sinceISO)}`;
  const res = await rest(q, { method: "HEAD", headers: { Prefer: "count=exact" } });
  const range = res.headers.get("content-range") ?? "*/0";
  return Number(range.split("/")[1] ?? "0") || 0;
}

const deps: Deps = {
  async getCatalog() {
    if (catalogCache && Date.now() - catalogCache.at < CATALOG_TTL_MS) return catalogCache.data;
    const res = await fetch(CATALOG_URL, { headers: { "Cache-Control": "no-cache" } });
    if (!res.ok) throw new Error(`catalog HTTP ${res.status}`);
    catalogCache = { at: Date.now(), data: await res.json() };
    return catalogCache.data;
  },
  async isRevoked(machineID, productID) {
    const res = await rest("rpc/is_license_revoked", {
      method: "POST",
      body: JSON.stringify({ p_machine_id: machineID, p_product_id: productID }),
    });
    if (!res.ok) throw new Error(`revocation HTTP ${res.status}`); // fail-closed pe server
    return (await res.json()) === true;
  },
  async recentCount(machineID, ip, sinceISO) {
    const [machine, byIP] = await Promise.all([countSince("machine_id", machineID, sinceISO), countSince("ip", ip, sinceISO)]);
    return { machine, ip: byIP };
  },
  async audit(row) {
    await rest("download_authorizations", { method: "POST", body: JSON.stringify(row), headers: { Prefer: "return=minimal" } });
  },
  async githubFile(owner, repo, path): Promise<GitHubFile | null> {
    const encoded = path.split("/").map(encodeURIComponent).join("/");
    const res = await fetch(`https://api.github.com/repos/${owner}/${repo}/contents/${encoded}`, {
      headers: { Authorization: `Bearer ${GITHUB_TOKEN}`, Accept: "application/vnd.github+json", "X-GitHub-Api-Version": "2022-11-28" },
    });
    if (res.status === 404) return null;
    if (!res.ok) throw new Error(`github HTTP ${res.status}`);
    const meta = await res.json();
    if (meta?.type !== "file" || typeof meta.download_url !== "string") return null;
    return { downloadURL: meta.download_url, size: Number(meta.size) || 0 };
  },
  now: () => new Date(),
};

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response(JSON.stringify({ error: "malformed_request", message: "Doar POST." }), { status: 405 });
  const ip = (req.headers.get("x-forwarded-for") ?? "").split(",")[0].trim() || "unknown";
  let body: unknown = null;
  try { body = await req.json(); } catch { /* rămâne null → 400 */ }
  try {
    const out = await authorize(body, ip, deps);
    return new Response(JSON.stringify(out.body), {
      status: out.status,
      headers: { "Content-Type": "application/json", "Cache-Control": "no-store", ...(out.headers ?? {}) },
    });
  } catch (e) {
    console.error("authorize-download internal error:", e instanceof Error ? e.message : "unknown");
    return new Response(JSON.stringify({ error: "internal_error", message: "Eroare internă." }), {
      status: 500,
      headers: { "Content-Type": "application/json", "Cache-Control": "no-store" },
    });
  }
});
