# Integrarea unui produs în platformă — capitol obligatoriu al lansării

Se aplică oricărui produs GDC care apare în GDC Plugin Manager sau pe https://gordas.dev/. Nu se aplică retroactiv:
un produs intră aici când își declară integrarea în `scripts/product-integration.json`.

## Contracte (nu se amestecă)

| Tip | Unde trăiește | Ce face Managerul |
|---|---|---|
| Plugin (DCTL/LUT/Fuse/OFX/PowerGrade/script) | `items[]` / `scriptItems[]` din `docs/catalog.json`, cu `files` + `sha256` | instalează, actualizează, elimină |
| Aplicație independentă | `apps[]` (`AppLink`) + opțional intrare în `knownGDCApps` (`Sources/GDCPluginManager/MyAppsLauncher.swift`) | listează, deschide pagina de descărcare; pe Mac recunoaște instalarea existentă |

Un produs nu e în ambele. O aplicație nu se tratează ca OFX și nu primește `files`.

## Lista de verificare

1. **Catalog:** intrare în `apps[]` cu `id`, `name`, `url` (pagina produsului), `downloadURL` (link stabil `releases/latest/download/…`),
   `supportedOS` corect (nu se prezintă pe un sistem pe care nu rulează), `access.note` fără sume, copertă 512×512 cu `?v=<8 hex sha256>`.
   Fără `pricingProductID` dacă produsul nu își arată prețul în catalog (sumele vin din sursa comercială declarată a produsului).
2. **Identitate și compatibilitate:** bundle id, Team ID și cerințele (OS minim, arhitectură) se scriu o singură dată și se verifică în `scripts/product-integration.json`.
3. **Detectare (doar dacă se aplică, Mac):** intrare în `knownGDCApps` cu `bundleIdentifier`, `teamIdentifier`, `versionSource` (manifestul produsului) și `pageURL`.
   Recunoașterea = bundle id + semnătură Apple cu Team ID, nu numele folderului. Copiile din imagini de disc montate, `DerivedData`, `AppTranslocation` sau `/tmp` nu sunt „instalarea utilizatorului”.
   „Instalat” ≠ „activat”; nu se fabrică chitanțe de instalare și nu se presupune că Managerul poate dezinstala o aplicație descoperită.
4. **Versiune și actualizare:** o singură sursă autoritară (manifestul `update.json` al produsului) pentru versiune; `version` și `build` sunt șiruri (clienții vechi decodează strict). Descărcarea răspunde.
5. **Imagine, pagină, documentație:** pagina produsului și pagina platformei (`scripts/build_platform_site.py`) în RO/EN/ES; README-uri, manuale și ajutor în aceleași limbi; fără sume unde produsul le-a exclus.
6. **Verificare în client și în catalogul public:** `scripts/verify_product_integration.py --live`, apoi pe client real (copie de verificare cu alt bundle id, fără a atinge profilul sau aplicația rulată a utilizatorului):
   produsul apare în catalog, în „Aplicațiile mele” cu versiunea corectă, cu acțiunile corecte. HTTP 200 sau JSON valid nu sunt suficiente.
7. **Manager nou?** Dacă s-a modificat clientul: semnat, notarizat, stapled, `update.json` actualizat, `/Users/gordasgdc/Developer/_gdc-tools/verify-update-flow.sh https://gordas.dev/update.json <versiune>`; clienții vechi nu primesc promisiunea noilor funcții.

## Comenzi

```bash
scripts/verify_product_integration.py            # local (catalog, copertă, detectare, pagini, fără sume)
scripts/verify_product_integration.py --live     # + ce primește clientul real
scripts/build_platform_site.py --check           # paginile platformei sunt la zi față de catalog/update.json
scripts/preflight.sh                             # rulează verificarea de mai sus când se ating fișierele relevante
```
