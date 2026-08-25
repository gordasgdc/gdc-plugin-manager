# codesigning/ — modul comun de semnare + notarizare Mac (toate repo-urile GDC)

Acest folder e gândit să fie **copiat neschimbat** în orice alt repo GDC de
pe Mac (`gdc-production-manager`, `cursorpro-gdc`, `gdc-resolve-encoder`),
o singură dată setup, apoi refolosit fără nicio adaptare de cod — doar
variabilele de mediu diferă per-mașină/CI, nu scripturile.

## Ce conține

- `entitlements.plist` — necesar pentru Hardened Runtime (obligatoriu la
  notarizare). Acoperă bundle-ul de Python portabil (`PythonRuntime/`)
  folosit de toate aplicațiile GDC desktop.
- `sign-and-notarize.sh` — semnează + notarizează + capsează („staple")
  un `.app` sau un `.pkg`. Nu face nimic dacă certificatul nu e configurat
  încă (fluxul actual, nesemnat, rămâne neschimbat).

## Setup unic (o dată per Mac, după ce cumperi contul Apple Developer)

1. **Certificatele** (Apple Developer → Certificates, Identifiers & Profiles):
   - `Developer ID Application` — pentru `.app`.
   - `Developer ID Installer` — pentru `.pkg`.
   Descarcă-le și dă dublu-click (se instalează în Keychain automat).

2. **Găsește numele exact al identității** din Keychain:
   ```bash
   security find-identity -v -p codesigning
   ```
   Va afișa ceva de genul:
   ```
   1) ABCDEF... "Developer ID Application: Cristi Gordas (X7Y8Z9ABCD)"
   2) 123456... "Developer ID Installer: Cristi Gordas (X7Y8Z9ABCD)"
   ```

3. **Setează variabilele de mediu** (adaugă în `~/.zshrc`, o singură dată,
   valabil pentru toate repo-urile):
   ```bash
   export APPLE_SIGN_IDENTITY_APP="Developer ID Application: Cristi Gordas (X7Y8Z9ABCD)"
   export APPLE_SIGN_IDENTITY_INSTALLER="Developer ID Installer: Cristi Gordas (X7Y8Z9ABCD)"
   ```

4. **Credențiale de notarizare** (o singură dată, salvate în Keychain,
   nu se mai repetă niciodată):
   ```bash
   xcrun notarytool store-credentials gdc-notary \
     --apple-id "adresa-ta@icloud.com" \
     --team-id "X7Y8Z9ABCD" \
     --password "parola-specifica-aplicatiei"
   ```
   Parola specifică aplicației se generează pe appleid.apple.com →
   Sign-In and Security → App-Specific Passwords. NU e parola contului.

Odată făcuți pașii 1-4, **toate** repo-urile GDC de pe acest Mac
funcționează automat — `sign-and-notarize.sh` găsește `gdc-notary` din
Keychain fără nicio configurare suplimentară.

## Cum îl cablezi într-un build script existent

La finalul lui `build_app.sh` (după `codesign` local existent, sau
înlocuindu-l):
```bash
"$(dirname "$0")/codesigning/sign-and-notarize.sh" app "/Applications/GDCPluginManager.app"
```

La finalul lui `build_installer.sh` (după ce `.pkg`-ul final e gata):
```bash
"$(dirname "$0")/codesigning/sign-and-notarize.sh" pkg "$FINAL_PKG"
```

## Pentru GitHub Actions (CI), în loc de Keychain local

Trei secrete noi în repo (Settings → Secrets and variables → Actions),
**aceleași nume peste tot**, ca să poți copia și workflow-ul YAML neschimbat:

| Secret | Conține |
|---|---|
| `APPLE_SIGN_IDENTITY_APP` | Textul identității, ca mai sus |
| `APPLE_SIGN_IDENTITY_INSTALLER` | Textul identității, ca mai sus |
| `APPLE_NOTARY_KEY_ID` | Key ID-ul cheii API (App Store Connect → Users and Access → Integrations) |
| `APPLE_NOTARY_ISSUER_ID` | Issuer ID, de pe aceeași pagină |
| `APPLE_NOTARY_KEY_P8` | Conținutul integral al fișierului `.p8` descărcat (o singură dată — Apple nu-l mai oferă a doua oară) |

Certificatele `.p12` (Application + Installer, exportate din Keychain cu
parolă) trebuie și ele importate într-un keychain temporar în job-ul CI
înainte de `codesign` — asta e un pas separat, standard pentru orice
proiect Mac pe GitHub Actions (import via `security import`), de adăugat
când chiar pregătim varianta CI pentru `gdc-production-manager`.

## De ce e separat de restul codului aplicației

Ca să poți `cp -R codesigning/ ../alt-repo-gdc/` fără să atingi nimic
altceva — singurul cost al integrării într-un repo nou e 2 linii adăugate
în scriptul lui de build, restul e identic peste tot.
