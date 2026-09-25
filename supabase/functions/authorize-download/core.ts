// Logica pură a autorizării (fără rețea): toate dependențele sunt injectate,
// ca testele să ruleze fără Supabase, GitHub sau secrete. Contract: CONTRACT.md.
import { PUBLIC_KEY_BASE64, type Platform, verifySerial } from "./license.ts";

export const REPO_ALLOWLIST: Record<string, string> = {
  files: "gdc-plugin-manager-files",
  pdfs: "gdc-plugin-manager-pdfs",
  scripts: "gdc-plugin-manager-scripts",
  resources: "gdc-plugin-manager-resources",
};
export const REPO_OWNER = "gordasgdc";
const PRODUCT_KEYS = ["items", "scriptItems", "downloadableResources", "pdfResources", "scriptResources"] as const;
export const RATE_LIMIT = { windowSeconds: 600, perMachine: 120, perIP: 300 };

export interface AuthorizeRequest {
  productID: string;
  path: string;
  machineID: string;
  platform: Platform;
  serial?: string;
  clientVersion?: string;
}

export interface CatalogFile { path: string; sha256?: string; repo?: string | null }
export interface CatalogEntry {
  id: string;
  isFree?: boolean;
  isTrial?: boolean;
  supportedOS?: string;
  files?: CatalogFile[];
  filePath?: string;
  fileSHA256?: string;
  fileRepo?: string | null;
}

export interface GitHubFile { downloadURL: string; size: number }

export interface Deps {
  getCatalog(): Promise<Record<string, unknown>>;
  isRevoked(machineID: string, productID: string): Promise<boolean>;
  /** Numărul de autorizări din fereastra curentă pentru machineID și pentru IP. */
  recentCount(machineID: string, ip: string, sinceISO: string): Promise<{ machine: number; ip: number }>;
  audit(row: Record<string, unknown>): Promise<void>;
  /** null = fișierul nu există. Folosește credentialul server-side; nu îl întoarce. */
  githubFile(owner: string, repo: string, path: string): Promise<GitHubFile | null>;
  now(): Date;
  /** Doar pentru teste; producția folosește cheia publică GDC. */
  licensePublicKey?: string;
}

export interface Outcome { status: number; body: Record<string, unknown>; headers?: Record<string, string> }

const fail = (status: number, error: string, message: string, headers?: Record<string, string>): Outcome =>
  ({ status, body: { error, message }, headers });

export function parseRequest(raw: unknown): AuthorizeRequest | null {
  if (typeof raw !== "object" || raw === null) return null;
  const r = raw as Record<string, unknown>;
  const str = (v: unknown, max: number) => typeof v === "string" && v.length > 0 && v.length <= max;
  if (!str(r.productID, 200) || !str(r.path, 1024) || !str(r.machineID, 64)) return null;
  if (r.platform !== "mac" && r.platform !== "windows") return null;
  if (r.serial !== undefined && r.serial !== null && !str(r.serial, 400)) return null;
  if (r.clientVersion !== undefined && r.clientVersion !== null && !str(r.clientVersion, 32)) return null;
  const path = r.path as string;
  if (path.startsWith("/") || path.includes("\\") || path.includes("//") || path.split("/").includes("..")) return null;
  if (!/^[A-Z2-7]{10}$/.test(r.machineID as string)) return null;
  return {
    productID: r.productID as string,
    path,
    machineID: r.machineID as string,
    platform: r.platform,
    serial: (r.serial as string | undefined) ?? undefined,
    clientVersion: (r.clientVersion as string | undefined) ?? undefined,
  };
}

export function findEntry(catalog: Record<string, unknown>, productID: string): CatalogEntry | null {
  for (const key of PRODUCT_KEYS) {
    const list = catalog[key];
    if (!Array.isArray(list)) continue;
    const hit = list.find((e) => e && typeof e === "object" && (e as CatalogEntry).id === productID);
    if (hit) return hit as CatalogEntry;
  }
  return null;
}

/** Fișierul cerut, doar dacă aparține produsului (listă `files` sau forma veche `filePath`). */
export function findFile(entry: CatalogEntry, path: string): CatalogFile | null {
  const files: CatalogFile[] = [...(entry.files ?? [])];
  if (entry.filePath) files.push({ path: entry.filePath, sha256: entry.fileSHA256, repo: entry.fileRepo });
  const hit = files.find((f) => f.path === path);
  if (!hit) return null;
  return { ...hit, repo: hit.repo ?? entry.fileRepo ?? null };
}

function platformSupported(supportedOS: string | undefined, platform: Platform): boolean {
  if (!supportedOS || supportedOS === "crossPlatform") return true;
  return (supportedOS === "macOS" && platform === "mac") || (supportedOS === "windows" && platform === "windows");
}

export async function authorize(raw: unknown, ip: string, deps: Deps): Promise<Outcome> {
  const req = parseRequest(raw);
  if (!req) return fail(400, "malformed_request", "Cerere invalidă.");
  const now = deps.now();
  const auditBase = { product_id: req.productID, path: req.path, machine_id: req.machineID, ip, platform: req.platform, client_version: req.clientVersion ?? null };
  const result = async (o: Outcome) => {
    await deps.audit({ ...auditBase, status: o.status, result: (o.body.error as string) ?? "authorized" }).catch(() => {});
    return o;
  };

  const since = new Date(now.getTime() - RATE_LIMIT.windowSeconds * 1000).toISOString();
  const counts = await deps.recentCount(req.machineID, ip, since);
  if (counts.machine >= RATE_LIMIT.perMachine || counts.ip >= RATE_LIMIT.perIP) {
    return result(fail(429, "rate_limited", "Prea multe cereri. Reîncearcă mai târziu.", { "Retry-After": String(RATE_LIMIT.windowSeconds) }));
  }

  const entry = findEntry(await deps.getCatalog(), req.productID);
  if (!entry) return result(fail(404, "unknown_product", "Produs necunoscut."));

  const file = findFile(entry, req.path);
  const repoKey = file?.repo ?? "files";
  if (!file || !req.path.startsWith(`${req.productID}/`) || !(repoKey in REPO_ALLOWLIST)) {
    return result(fail(403, "unauthorized_artifact", "Fișierul nu aparține produsului."));
  }
  if (!platformSupported(entry.supportedOS, req.platform)) {
    return result(fail(403, "unauthorized_platform", "Produsul nu e disponibil pe această platformă."));
  }

  const free = entry.isFree === true;
  if (!free) {
    if (!req.serial) return result(fail(403, "invalid_license", "Licență lipsă."));
    const lic = await verifySerial(req.serial, req.productID, req.machineID, req.platform, Math.floor(now.getTime() / 1000), deps.licensePublicKey ?? PUBLIC_KEY_BASE64);
    if (!lic.ok) {
      return result(lic.reason === "wrong_platform"
        ? fail(403, "unauthorized_platform", "Licența nu e valabilă pe această platformă.")
        : fail(403, "invalid_license", "Licență invalidă."));
    }
    if (await deps.isRevoked(req.machineID, req.productID)) {
      return result(fail(403, "revoked_license", "Licența nu mai este activă."));
    }
  }

  const gh = await deps.githubFile(REPO_OWNER, REPO_ALLOWLIST[repoKey], req.path);
  if (!gh) return result(fail(404, "artifact_unavailable", "Fișierul nu este disponibil."));

  return result({
    status: 200,
    body: {
      url: gh.downloadURL,
      productID: req.productID,
      path: req.path,
      sha256: file.sha256 ?? null,
      size: gh.size,
      issuedAt: now.toISOString(),
      useWithinSeconds: 60,
    },
  });
}
