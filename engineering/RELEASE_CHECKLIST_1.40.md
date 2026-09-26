# Release coordonat — Mac 1.40.0 · Furnizor 1.53.0 · Windows 1.38.1 (NEPUBLICAT — cere aprobare)

Stare locală: `main` (Mac/Furnizor) și `main` (Windows) integrate, neîmpinse. Gate: `scripts/preflight-all.sh` = OK.
Manifest candidat: `release/update.candidate.json` (publicul `docs/update.json` rămâne 1.39.4 / 1.37.2 până la pasul 4).

## ATENȚIE — ce declanșează publicarea
- `git push` pe `main` Windows = CI publică AUTOMAT release-ul v1.38.1 (`--latest=false`) și scrie secțiunea `windows` din
  `docs/update.json` (rădăcina = minimul platformelor). Deci push-ul Windows = release Windows.
- `git push` pe `main` Mac/Furnizor publică `docs/` pe gordas.dev (catalog/banner/update.json neschimbate în acest lot → fără efect la clienți).

## Ordinea (fiecare pas cu aprobarea lui Cristi)
1. Push `main` Mac/Furnizor (fără release). Verifică: gordas.dev servește același `update.json` (1.39.4 / 1.37.2).
2. Mac 1.40.0: build → semnare → notarizare → stapler (Regulile 5, 45) → release `v1.40.0` **latest** cu asset versionat + stabil
   (Regula 17/41) → `verify-update-flow.sh` pe linkul stabil. Abia apoi secțiunea `mac` din `update.json` (sha256 real).
3. Windows 1.38.1: push `main` Windows → CI (semnat, verificat) → release non-latest → CI actualizează `update.json`.
   Verifică: `releases/latest` rămâne `v1.40.0` (altfel linkul Mac „latest” dă 404 — Regula 35).
4. `verify-update-flow.sh https://gordas.dev/update.json` pentru ambele platforme (200 real, sha, versiuni).
5. Furnizor 1.53.0: doar build + instalare locală (`./build_furnizor_app.sh`), după pasul 1. La prima pornire: „Continuă în PRODUCȚIE”.
6. Validare pe client real: Mac P1–P5; Windows în VM: 1.37.2 publică → oferta de actualizare → instalare 1.38.1 → pornire
   (necesită aprobare pentru snapshot `baza-1.37.0-public` — Regula laboratorului).

## Compatibilitatea clienților vechi
- `update.json`: niciun câmp eliminat; rădăcina = minimul (1.38.1) pentru clienții ≤ 1.27; Mac pe `latest`, Windows versionat.
- Bannere: fără campanii publicate nu se schimbă nimic; cu campanii, clienții ≤ 1.40 / ≤ 1.37 văd textul RO de rezervă
  („Doar imagine” = ascuns la ei). Bannerul „PREȚURI SPECIALE” din producție rămâne neatins (Regula 3 — decizia lui Cristi).
- Descărcări: clienții Mac ≤ 1.39.3 / Windows ≤ 1.37.0 folosesc încă PAT-ul vechi — NU se revocă în acest release.
- Licențe: format identic (vector comun Mac/Windows verificat).

## Rollback
- Clienți: readuce secțiunea afectată din `update.json` la 1.39.4 / 1.37.2 (commit în `docs/`) — clienții nu mai primesc oferta.
- Mac: `gh release edit v1.39.4 --latest` + release `v1.40.0` marcat pre-release (ștergerea doar cu aprobare).
- Windows: release `v1.38.1` marcat pre-release; instalatorul 1.37.2 rămâne pe `v1.37.2`.
- Cod: `rollback/pre-faza5`, `rollback/pre-f3-f4`, `rollback/pre-lot-a` (Mac); `rollback/pre-win-parity` (Windows).

## Blocaj cunoscut
Testul real de actualizare Windows public → candidat nu se poate face izolat înainte de publicare: clientul 1.37.2 citește doar
`https://gordas.dev/update.json` și acceptă doar instalatoare semnate de CI. Opțiuni: (a) după pasul 3, în VM (snapshot aprobat);
(b) înainte: build CI pe o ramură (artefact semnat, fără release) + redirecționare DNS doar în VM — cere aprobare.

## Rezultat test pre-publicare Windows (2026-09-26)
- CI pe ramura `ci-test-1.38.1` (workflow_dispatch, run 36217905260): semnare + teste OK, pasul de publicare SĂRIT; niciun release,
  `update.json` public neschimbat (verificat live). Artefact: `~/Downloads/GDC-update-test-1.38.1/GDCPluginManagerSetup-1.38.1-citest.exe`.
- VM: snapshot nou `inainte-test-update-1.38.1`. În VM: SHA-256 identic, thumbprint GDC corect (rădăcina neimportată = UnknownError,
  normal), verificatorul de actualizare (cod identic cu 1.37.2 publicat) acceptă instalatorul semnat și respinge copia alterată.
- Instalare peste 1.37.2 (silențios, ca SYSTEM, după închiderea aplicației — ca SelfUpdater): exit 0, 1.38.1 în Program Files și în
  „Apps & Features”, pornire OK, catalog + banner clasic + verificarea de actualizare (nu oferă 1.37.2) funcționale.
- NETESTAT: detecția + descărcarea din aplicație prin gordas.dev. Redirecționarea cere un certificat TLS fals pentru gordas.dev
  (CA de test în VM) = slăbirea validării → oprit intenționat; se verifică după publicare, pe snapshot.
