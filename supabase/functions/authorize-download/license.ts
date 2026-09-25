// Port server-side al LicenseCore.swift (validate): același format de serial,
// aceeași cheie PUBLICĂ Ed25519. Nicio cheie privată aici.
//   [4 product hash][8 expiry BE][4 nonce][6 machine hash][(1 platform)][64 semnătură Ed25519]

export const PUBLIC_KEY_BASE64 = "I1h23MNMRbOhc0ObKJrfa3oFHKA9w+SzbNrroAIy8hs=";
const ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";
const V1 = 22;
const V2 = 23;

export type Platform = "mac" | "windows";
export type LicenseFailure = "malformed" | "bad_signature" | "wrong_product" | "wrong_machine" | "wrong_platform" | "expired";
export type LicenseResult =
  | { ok: true; expiresAt: number; machineLocked: boolean }
  | { ok: false; reason: LicenseFailure };

export function base32Decode(input: string): Uint8Array | null {
  const cleaned = input.toUpperCase().replace(/[-\s=]/g, "");
  let bits = 0, value = 0;
  const out: number[] = [];
  for (const ch of cleaned) {
    const idx = ALPHABET.indexOf(ch);
    if (idx < 0) return null;
    value = ((value << 5) | idx) & 0xffffff;
    bits += 5;
    if (bits >= 8) {
      out.push((value >> (bits - 8)) & 0xff);
      bits -= 8;
    }
  }
  return new Uint8Array(out);
}

export function base32Encode(data: Uint8Array): string {
  let bits = 0, value = 0, out = "";
  for (const b of data) {
    value = ((value << 8) | b) & 0xffff;
    bits += 8;
    while (bits >= 5) {
      out += ALPHABET[(value >> (bits - 5)) & 31];
      bits -= 5;
    }
  }
  if (bits > 0) out += ALPHABET[(value << (5 - bits)) & 31];
  return out;
}

export async function productHash(productID: string): Promise<Uint8Array> {
  const digest = await crypto.subtle.digest("SHA-512", new TextEncoder().encode(productID));
  return new Uint8Array(digest).slice(0, 4);
}

function equal(a: Uint8Array, b: Uint8Array): boolean {
  return a.length === b.length && a.every((v, i) => v === b[i]);
}

// 0 any · 1 mac only · 2 windows only · 3 cross-platform; octet necunoscut => any (ca în Swift).
function platformAllows(byte: number | undefined, platform: Platform): boolean {
  if (byte === undefined || byte === 0 || byte === 3 || byte > 3) return true;
  return (byte === 1 && platform === "mac") || (byte === 2 && platform === "windows");
}

export async function verifySerial(
  serial: string,
  expectedProductID: string,
  machineID: string,
  platform: Platform,
  nowSeconds: number,
  publicKeyBase64: string = PUBLIC_KEY_BASE64,
): Promise<LicenseResult> {
  const packed = base32Decode(serial);
  if (!packed) return { ok: false, reason: "malformed" };
  let size: number;
  if (packed.length === V1 + 64) size = V1;
  else if (packed.length === V2 + 64) size = V2;
  else return { ok: false, reason: "malformed" };

  const payload = packed.slice(0, size);
  const signature = packed.slice(size);
  const keyBytes = Uint8Array.from(atob(publicKeyBase64), (c) => c.charCodeAt(0));
  let valid = false;
  try {
    const key = await crypto.subtle.importKey("raw", keyBytes, { name: "Ed25519" }, false, ["verify"]);
    valid = await crypto.subtle.verify({ name: "Ed25519" }, key, signature, payload);
  } catch {
    return { ok: false, reason: "malformed" };
  }
  if (!valid) return { ok: false, reason: "bad_signature" };
  if (!equal(payload.slice(0, 4), await productHash(expectedProductID))) return { ok: false, reason: "wrong_product" };

  let expiresAt = 0;
  for (let i = 4; i < 12; i++) expiresAt = expiresAt * 256 + payload[i];
  const machine = payload.slice(16, 22);
  const machineLocked = machine.some((b) => b !== 0);
  if (!platformAllows(size === V2 ? payload[22] : undefined, platform)) return { ok: false, reason: "wrong_platform" };
  if (machineLocked) {
    const claimed = base32Decode(machineID);
    if (!claimed || !equal(claimed.slice(0, 6), machine)) return { ok: false, reason: "wrong_machine" };
  }
  if (expiresAt !== 0 && expiresAt < nowSeconds) return { ok: false, reason: "expired" };
  return { ok: true, expiresAt, machineLocked };
}
