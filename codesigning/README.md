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

## Pentru GitHub Actions (CI) — ex: gdc-production-manager

Spre deosebire de GDC Plugin Manager/CursorPro GDC (build local, pe Mac-ul
tău, unde certificatele deja există în Keychain), `gdc-production-manager`
se compilează pe un runner GitHub proaspăt — fără Keychain, fără
certificate. Sunt necesari 2 pași suplimentari.

**1. Exportă certificatele din Keychain-ul tău local, ca `.p12`:**

```bash
security export -k login.keychain-db -t identities -f pkcs12 \
  -P "o-parola-noua-doar-pentru-acest-export" \
  -o ~/Desktop/app.p12
```
(Keychain Access → click pe certificat → dropdown ▸ → Export — echivalent, dacă preferi UI. Alege o parolă nouă, diferită de orice altă parolă — o pui într-un secret separat mai jos.) Repetă pentru Installer.

**2. Adaugă 7 secrete noi în `gdc-production-manager`** (Settings → Secrets
and variables → Actions) — **aceleași nume peste tot**, ca workflow-ul YAML
să fie copiabil neschimbat:

| Secret | Conține |
|---|---|
| `APPLE_SIGN_IDENTITY_APP` | Textul identității (`security find-identity -v -p codesigning`) |
| `APPLE_SIGN_IDENTITY_INSTALLER` | Textul identității Installer |
| `APPLE_CERT_APP_P12_BASE64` | `base64 -i app.p12 \| pbcopy`, lipit ca secret |
| `APPLE_CERT_APP_P12_PASSWORD` | Parola aleasă la export (Pasul 1) |
| `APPLE_CERT_INSTALLER_P12_BASE64` | La fel, pentru certificatul Installer |
| `APPLE_CERT_INSTALLER_P12_PASSWORD` | Parola acelui export |
| `APPLE_NOTARY_APPLE_ID` | `d.cristigordas@gmail.com` |
| `APPLE_NOTARY_TEAM_ID` | `8AR6XP8MG7` |
| `APPLE_NOTARY_PASSWORD` | Parola de aplicație (App-Specific Password), **nu** parola contului |

**3. În workflow-ul YAML**, adaugă un pas nou chiar la început (după checkout),
apoi apelurile de semnare/notarizare unde e nevoie:

```yaml
- name: Import Apple certificates
  env:
    APPLE_CERT_APP_P12_BASE64: ${{ secrets.APPLE_CERT_APP_P12_BASE64 }}
    APPLE_CERT_APP_P12_PASSWORD: ${{ secrets.APPLE_CERT_APP_P12_PASSWORD }}
    APPLE_CERT_INSTALLER_P12_BASE64: ${{ secrets.APPLE_CERT_INSTALLER_P12_BASE64 }}
    APPLE_CERT_INSTALLER_P12_PASSWORD: ${{ secrets.APPLE_CERT_INSTALLER_P12_PASSWORD }}
  run: ./codesigning/ci-import-certs.sh

# ... apoi, dupa ce .app/.pkg exista, cu aceleasi env vars plus:
#   APPLE_SIGN_IDENTITY_APP, APPLE_SIGN_IDENTITY_INSTALLER,
#   APPLE_NOTARY_APPLE_ID, APPLE_NOTARY_TEAM_ID, APPLE_NOTARY_PASSWORD
#   run: ./codesigning/sign-and-notarize.sh app dist/MyApp.app
#   run: ./codesigning/sign-and-notarize.sh pkg dist/MyInstaller.pkg
```

`ci-import-certs.sh` nu face nimic (exit 0) dacă `APPLE_CERT_APP_P12_BASE64`
nu e setat — sigur de adăugat înainte să existe efectiv secretele.

## De ce e separat de restul codului aplicației

Ca să poți `cp -R codesigning/ ../alt-repo-gdc/` fără să atingi nimic
altceva — singurul cost al integrării într-un repo nou e 2 linii adăugate
în scriptul lui de build, restul e identic peste tot.
