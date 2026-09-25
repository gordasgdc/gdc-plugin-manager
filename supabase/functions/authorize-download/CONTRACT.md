# `authorize-download` — contract (v1, 2026-09-25)

Supabase Edge Function. Autorizează descărcarea UNUI fișier de produs. Nu întoarce niciodată credentialul GitHub.

## Cerere
`POST /functions/v1/authorize-download` · `Content-Type: application/json` · antet `apikey`/`Authorization: Bearer <anon key>` (cheia publică a proiectului, doar pentru gateway).

```json
{
  "productID": "gdc-style-m02-film-demo",
  "path": "gdc-style-m02-film-demo/1.46.0/Contents/Info.plist",
  "machineID": "ABCDEFGHIJ",            // MachineID.display (Base32 al celor 6 octeți de hash)
  "platform": "mac",                    // "mac" | "windows"
  "serial": "XXXXX-XXXXX-…",            // obligatoriu doar pentru produse plătite
  "clientVersion": "1.40.0"             // informativ (audit)
}
```

## Validare pe server (în ordine; primul eșec oprește)
1. Cerere bine formată: câmpuri de tip string, lungimi maxime, `path` relativ fără `..`/`\`/`//`, `platform` ∈ {mac, windows}, `machineID` = 10 caractere Base32.
2. Rate limit: max 120 autorizări / machineID / 10 min și 300 / IP / 10 min.
3. Produsul există în catalogul publicat (`items`, `scriptItems`, `downloadableResources`, `pdfResources`, `scriptResources`).
4. Fișierul cerut e EXACT unul dintre fișierele produsului, iar calea începe cu `<productID>/` (artifact allowlist).
5. Repo-ul fișierului ∈ allowlist (`files`, `pdfs`, `scripts`, `resources` → repo-urile private cunoscute).
6. Platformă: `supportedOS` al produsului permite platforma cerută.
7. Drept de acces: produs gratuit/probă → permis. Altfel serial Ed25519 valid (semnătură cu cheia publică GDC, product hash = SHA-512(productID)[:4], neexpirat, machine hash = `machineID` dacă serialul e legat de mașină, octetul de platformă permite platforma cerută).
8. Revocare: `(machineID, productID)` absent din `license_revocations` (doar pentru produse plătite).
9. Se cere la GitHub (credential server-side, read-only) metadatele fișierului; se întoarce `download_url`-ul temporar.

## Răspuns 200
```json
{
  "url": "https://raw.githubusercontent.com/…?token=…",   // temporar, valabil DOAR pentru acest fișier
  "productID": "…", "path": "…",
  "sha256": "…",                                          // din catalog; clientul îl verifică după descărcare
  "size": 1234,                                           // de la GitHub
  "issuedAt": "2026-09-25T12:00:00Z",
  "useWithinSeconds": 60                                  // recomandare; expirarea reală o stabilește GitHub
}
```

## Erori (corp: `{"error": "<cod>", "message": "<text scurt, fără detalii interne>"}`)
| HTTP | cod | când |
|---|---|---|
| 400 | `malformed_request` | JSON invalid, câmpuri lipsă/invalide |
| 403 | `invalid_license` | serial lipsă/invalid/semnătură greșită/alt produs/alt calculator/expirat |
| 403 | `revoked_license` | licență revocată |
| 403 | `unauthorized_platform` | platforma nu e permisă de produs sau de licență |
| 403 | `unauthorized_artifact` | fișierul nu aparține produsului sau repo-ul nu e în allowlist |
| 404 | `unknown_product` | produsul nu există în catalog |
| 404 | `artifact_unavailable` | fișierul lipsește din stocare |
| 429 | `rate_limited` | limită depășită (antet `Retry-After`) |
| 500 | `internal_error` | orice altă eroare (detaliul doar în logul serverului) |

## Ce garantează fiecare parte
| Garanție | GitHub (URL temporar) | Funcția |
|---|---|---|
| Acces la un singur fișier | DA (verificat empiric: alt fișier → 404) | alege fișierul |
| Expirare | DA, durată nedocumentată public, nemăsurată | `useWithinSeconds` informativ |
| Cine are drept | NU | licență, revocare, platformă, produs |
| Replay / partajare | NU — URL-ul e un bearer până expiră | risc rezidual acceptat: fereastră scurtă, un fișier; audit per emitere |
| Revocare după emitere | NU | revocarea blochează doar emiterile următoare |
| Integritate | NU | SHA-256 din catalog, verificat de client |
| Rate limit / audit | NU | DA (tabel `download_authorizations`) |

## Secrete (doar în Supabase → Edge Functions → Secrets)
`GITHUB_READ_TOKEN` (PAT fine-grained NOU, Contents: Read-only DOAR pe repo-urile de produse), plus variabilele implicite
`SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`. Opțional `CATALOG_URL` (implicit `https://gordas.dev/catalog.json`).
