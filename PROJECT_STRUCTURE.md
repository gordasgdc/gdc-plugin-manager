# Structura proiectului — GDC Plugin Manager (Mac)

> Pentru orice sesiune viitoare (Claude sau om): citește asta ÎNAINTE de a
> presupune unde e ceva pe disc. Actualizat ultima dată: 2026-08-25.

## Locația canonică

Toate repo-urile GDC legate de acest ecosistem trăiesc în **`~/Developer/`**:

```
~/Developer/
├── GDCPluginManager/                    ← acest repo (gordasgdc/gdc-plugin-manager)
├── GDCPluginManagerWin/                 ← clientul Windows (gordasgdc/gdc-plugin-manager-win)
├── gdc-plugin-manager-files/            ← repo PRIVAT: fișierele vandabile (.dctl/.cube/.fuse)
└── gdc-plugin-manager-catalog-vendor/   ← acest repo, ALT checkout, folosit DOAR de Furnizor
                                            pentru publicare (catalog.json + covers/)
```

**Istoric relocare**: până pe 2026-08-25, aceste repo-uri stăteau în
`~/Downloads/` — mutate în `~/Developer/` pentru că `~/Downloads` e curățat
automat de CleanMyMac/Hazel pe acest Mac (au dispărut ambele repo-uri de
sursă în timpul unei sesiuni, recuperate din Coșul de gunoi la timp).

## De ce DOUĂ checkout-uri ale aceluiași repo public?

`GDCPluginManager/` (acesta) e arborele de lucru pentru COD — unde editezi
Swift, rulezi `swift build`, `build_app.sh` etc.

`gdc-plugin-manager-catalog-vendor/` e un checkout SEPARAT al aceluiași
`gordasgdc/gdc-plugin-manager`, folosit EXCLUSIV de aplicația Furnizor (vezi
`RepoCheckoutPaths.swift`) ca să publice `docs/catalog.json` + `docs/covers/`.
Separarea e intenționată: publicarea unui produs din Furnizor nu trebuie
niciodată să amestece cu editări de cod în lucru în celălalt checkout.

Dacă muți/redenumești oricare din aceste două căi, actualizează
`Sources/GDCPluginManagerFurnizor/RepoCheckoutPaths.swift` — Furnizor
presupune exact aceste nume, sub `~/Developer/`.

## Structura codului (acest repo)

```
Sources/
├── GDCPluginManagerCore/       ← model de date + logică partajată (Client + Furnizor)
│   ├── CatalogModel.swift      ← PluginItem, ServiceCenter, SupportedOS, etc.
│   ├── LicenseCore.swift       ← criptografie licențe (Ed25519), payload v1+v2
│   └── SystemDependencyChecker.swift
├── GDCPluginManager/           ← app-ul CLIENT (ce descarcă/instalează clienții)
│   ├── ContentView.swift       ← UI principal, toate cardurile de catalog
│   ├── LicenseManager.swift
│   └── Localization.swift      ← RO/EN/ES
└── GDCPluginManagerFurnizor/   ← app-ul FURNIZOR (Cristi publică produse/licențe)
    ├── PublishView.swift       ← formularul de editare produs (aici e selectorul OS)
    ├── CatalogEditor.swift     ← strat de date (citește/scrie catalog.json)
    └── RepoCheckoutPaths.swift ← căile hardcodate către celelalte 2 checkout-uri
```

## Build & instalare locală

```bash
cd ~/Developer/GDCPluginManager
./build_app.sh              # compilează + instalează GDCPluginManager.app (Client)
./build_furnizor_app.sh     # compilează + instalează GDC Plugin Manager Furnizor.app
./build_installer.sh        # build_app.sh + semnare/notarizare + .pkg (necesită
                             # variabilele APPLE_SIGN_IDENTITY_* din ~/.zshrc — rulează
                             # DOAR din terminalul propriu al userului, nu din tool-uri
                             # non-interactive, altfel sare peste semnare silențios)
```

## Certificate & chei private (2026-08-25)

**`~/Developer/Certificates/`** — folder LOCAL, SEPARAT de orice repo git
(`~/Developer/` nu e sub git deloc). Conține `.p12`/`.cer` pentru semnarea
Apple (Developer ID Application/Installer, intermediarul G2CA). Permisiuni
restrânse (`chmod 700` folder, `chmod 600` fișiere — doar tu poți citi).

**REGULĂ ABSOLUTĂ: niciun `.p12`/`.cer`/`.p8`/`.key`/`.pem`/`.mobileprovision`
nu intră NICIODATĂ într-un commit git, în niciun repo, public sau privat.**
Sistemele Apple detectează și revocă automat certificate expuse public, iar
contul de Developer poate fi suspendat. Toate aceste extensii sunt în
`.gitignore` (verificat: niciodată comise în istoricul acestui repo).

Scripturile de semnare (`codesigning/sign-and-notarize.sh`) NU citesc direct
din acest folder — folosesc identitatea deja importată în macOS Keychain
(`security find-identity`) + credențialele de notarizare deja salvate acolo
(`xcrun notarytool store-credentials gdc-notary`, o singură dată per Mac,
vezi `codesigning/README.md`). Folderul `Certificates/` e doar arhiva
personală a fișierelor originale (utile dacă trebuie re-importate pe alt
Mac sau pentru export CI ulterior) — nu o dependință de build.

## Repo-uri înrudite (nu în acest folder)

- `gordasgdc/gdc-plugin-manager-win` → `~/Developer/GDCPluginManagerWin`
- `gordasgdc/gdc-plugin-manager-files` (privat) → `~/Developer/gdc-plugin-manager-files`
- `gordasgdc/cursorpro-gdc`, `gordasgdc/gdc-production-manager`,
  `gordasgdc/gdc-resolve-encoder` — alte produse GDC, folosesc același modul
  `codesigning/` (copiat, nu partajat prin symlink) și același sistem de
  licențiere Ed25519 (vezi `LicenseCore.swift`).
