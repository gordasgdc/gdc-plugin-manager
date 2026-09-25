# Matricea de testare — GDC Plugin Manager

Actualizat 2026-09-25 (Security Foundation). Stări: **AUTO** = AUTOMATED în CI · **LOCAL** = automat, rulat doar local ·
**MANUAL** · **NONE** = netestat · **BLOCKED** · **N/A** = nu se aplică · **HW** = cere hardware fizic.
Niciun rând nu înseamnă PASS dacă testul nu a fost rulat; rezultatele rulărilor sunt în secțiunea de la final.

| Domeniu | Mac | Windows | Ce acoperă / ce lipsește |
|---|---|---|---|
| CORE — licență | AUTO (15 teste) | AUTO parțial (smoke: product hash) | valid v1/v2, expirat, alt produs, semnătură străină, payload modificat, malformat, alt Mac, HWID indisponibil, platformă greșită. Lipsă: starea demo/probă din `LicenseManager` (client) |
| CATALOG — decodare | AUTO (13 teste) | NONE | catalog real, ordine, câmpuri obligatorii, chei/tipuri necunoscute, legacy, JSON invalid |
| CATALOG — integritate | AUTO (structură) + LOCAL (`--files-root`: existență + SHA-256) | — | fișierele private nu sunt accesibile în CI (repo privat, fără token) |
| CATALOG — republicări | LOCAL (`--history`) | — | produse șterse și readăugate |
| LOCALIZARE | AUTO (`check_localization.py`; Regula 3 = avertisment tranzitoriu) | NONE (client doar RO) | chei lipsă, limbi lipsă, Regula 3. Lipsă: randarea textelor lungi |
| NETWORKING | NONE | NONE | fetch catalog/update/pricing: timeout, 404, 5xx, răspuns gol |
| DOWNLOAD | NONE | NONE | descărcare autentificată din repo-ul privat, verificare SHA-256 la client |
| INSTALLATION | NONE (MANUAL la release) | NONE — **HW** | scriere în folderele Resolve, permisiuni, dezinstalare |
| UPDATE — manifest | AUTO (7 teste) | — (același `update.json`) | secțiuni mac/windows, bloc legacy ≤1.27.1, minimul la rădăcină, comparația de versiuni, Info.plist ≤ publicat |
| UPDATE — verificare pachet (S2) | AUTO (10 teste) + LOCAL (pachet semnat real din `dist/`, sărit în CI) | N/A (Windows: Authenticode în CI la build) | semnătură validă/Team ID corect → acceptat; alt Team ID, nesemnat, certificat non-Installer, non-distribuție, corupt, înlocuit după verificare, SHA-256 diferit → instalare BLOCATĂ; versiune cu injecție → respinsă; scriptul root rulat real prin osascript (fără elevare) |
| UPDATE — self-updater complet | MANUAL (prompt admin + `installer` real + relansare, Regula 20) — NErulat pentru noul flux | NONE — **HW** | pasul privilegiat nu poate fi automatizat fără parolă |
| UI STATE | NONE | NONE — **HW** | stările cardului nu au încă model (vezi UI_ARCHITECTURE.md §3) |
| ERROR HANDLING | parțial (decodare) | NONE | mesaje pentru client vs log tehnic |
| SECURITY — licență/catalog | AUTO (semnătură Ed25519, căi nesigure, https în catalog) | parțial (smoke) | |
| SECURITY — actualizare (T2–T5) | AUTO (vezi S2) | N/A | |
| SECURITY — autorizare artefacte (server) | AUTO: 26 teste Deno (`authorize-download`), job CI | N/A | valid/gratuit/legacy; serial lipsă/invalid/altă cheie/alt produs/alt calculator/expirat/revocat; platformă; produs/fișier/repo în afara allowlist; fișier lipsă; rate limit; cereri malformate; vector Swift↔TS |
| SECURITY — autorizare artefacte (client) | AUTO: 8 teste (`DownloadAuthorizerTests`) | AUTO: 10 teste (`tests/GDCPluginManager.Core.Tests`, ramura `s1-authorize-download`) | fără serial la gratuit; mapare erori; URL expirat → o reautorizare; SHA-256 greșit; autorizare pentru alt fișier / http respinsă fără descărcare |
| SECURITY — credential absent din client | AUTO: `scripts/check_client_secrets.sh` în CI (binar Release) + LOCAL pe build-ul real | AUTO: scanare ASCII+UTF-16 a `publish\` în CI | control pozitiv verificat (Furnizor, fișier UTF-16) |
| SECURITY — autorizare end-to-end (funcție deployată) | BLOCKED: deploy Supabase | BLOCKED | după deploy: gratuit → 200, plătit fără serial → 403, cale străină → 403 |
| SECURITY — căi privilegiate | vezi `PRIVILEGED_PATHS.md` | de inventariat | |
| SECURITY — secret scanning | NONE | NONE | propus: gitleaks în ambele CI |
| macOS BUILD | AUTO (`swift build`, toate țintele) | — | |
| macOS PACKAGE | AUTO smoke (binar Release Mach-O) | — | `.app`/`.pkg`/semnare/notarizare: doar local (`build_app.sh`) |
| WINDOWS BUILD / PACKAGE | — | AUTO (publish win-x64, Inno Setup, semnare dacă există secretul) | lipsă: `dotnet test`, verificarea semnăturii după semnare |
| CI/CD | AUTO (`mac-ci.yml`) | AUTO (`build-windows.yml`) | |
| RELEASE | LOCAL (`_gdc-tools/preflight-release.sh`, `verify-update-flow.sh`) | idem | |

## Stări de validare (nu se confundă)

| Stare | Mac | Windows |
|---|---|---|
| BUILD PASSED | CI | CI |
| TESTS PASSED | CI (Core) | CI (smoke Core.dll) |
| PACKAGE VALIDATED | CI: doar binarul; pachetul semnat: local | CI: installer produs + semnat |
| INSTALLATION VALIDATED | manual, la release | **REQUIRES PHYSICAL WINDOWS VALIDATION** |
| RUNTIME VALIDATED | manual, la release | **REQUIRES PHYSICAL WINDOWS VALIDATION** |
| VISUAL VALIDATED | manual | **REQUIRES PHYSICAL WINDOWS VALIDATION** |

## Următoarele teste cu cea mai mare valoare
1. `ProductActionState` (când există) — stările cardului, fără UI.
2. `CatalogService`: răspuns 404/5xx/JSON invalid → stare de eroare, nu catalog gol tăcut.
3. Verificarea SHA-256 la instalare (`InstallManager`) cu fixture-uri locale izolate (niciodată căi de producție).
4. Windows: proiect `GDCPluginManager.Core.Tests` + `dotnet test` în CI (licență, catalog, update).

## Rulări (2026-09-25)
| Verificare | Rezultat | Unde |
|---|---|---|
| `swift test` (45 teste, inclusiv pachetul semnat real) | PASS local | `.build/logs/s2-tests.log` |
| Mac CI pe `d85c80e` | PASS | GitHub Actions „Mac CI” |
| Mac CI pentru S2 (`28253ef`) | PASS | GitHub Actions |
| Deno `authorize-download` (26) | PASS local + job CI | `.build/logs/authorize-download-tests.log` |
| `swift test` (53) | PASS local | `.build/logs/s1-client-tests.log` |
| Teste Core Windows (10) | PASS local (.NET 10, RollForward) | ramura `s1-authorize-download` |
| Instalare reală prin noul SelfUpdater | NErulat (MANUAL) | |
