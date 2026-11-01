# GDC Plugin Manager

The free app for finding, installing, opening and updating GDC products:
plugins for DaVinci Resolve (DCTL, LUT, Fuse, OFX, PowerGrade, scripts) and
standalone apps. A native app for **macOS 14+ (Apple Silicon)**, with a separate
**Windows (64-bit)** client. Site: <https://gordas.dev/>

**The app itself is free** and needs no account. Products that need a licence
are activated separately, through a donation or a granted right; a licence for
one product never unlocks another.

Interface and site in Romanian, English and Spanish:
<https://gordas.dev/> · <https://gordas.dev/en/> · <https://gordas.dev/es/>

## What it does

- Fetches the public catalog of GDC products, with filters by system and access.
- **Plugins:** installs them straight into the folder DaVinci Resolve reads at
  launch (asking for the admin password only if a direct write is refused),
  tracks installed versions and offers one-click updates. It warns before
  installing or removing while DaVinci Resolve is open.
- **Apps:** lists them with their download page. On Mac, *My Apps* recognises
  GDC apps already on disk — including ones installed without the Manager — by
  bundle identity and Apple signature (not by folder name), shows the installed
  version and whether the app is running, and flags a newer version. *Update*
  opens the product page; a running app is never replaced. Installed does not
  mean activated, and the Manager does not uninstall apps it did not install.
- Checks for Manager updates automatically and shows a banner when one exists.

## Download

Get the latest build from [Releases](../../releases/latest) or from
<https://gordas.dev/>. Mac: `GDCPluginManager-Mac.dmg`. Windows:
`GDCPluginManager-Windows.zip`. Free, no account.

## Resumen (ES) · Rezumat (RO)

- **ES:** aplicación gratuita para encontrar, instalar, abrir y actualizar los
  productos GDC. En Mac, *Mis aplicaciones* reconoce las aplicaciones GDC ya
  instaladas (también las instaladas sin el Manager). Sitio:
  <https://gordas.dev/es/>
- **RO:** aplicația gratuită prin care găsești, instalezi, deschizi și
  actualizezi produsele GDC. Pe Mac, *Aplicațiile mele* recunoaște aplicațiile
  GDC deja instalate (și cele instalate fără Manager). Site:
  <https://gordas.dev/>

## License

The app is free. Each licensed product has its own licence, tied to one
computer (see the **License** page in the app); activating one product does not
unlock any other. Already-installed products keep working in DaVinci Resolve
regardless of licence state.

Source code in this repository is provided under the MIT license (see
[LICENSE](LICENSE)) — it's open for review; the app's own terms for activating
individual products are in
[installer/License.txt](installer/License.txt).

## Repository layout

This repo contains **two** Swift executable targets, sharing a common core:

- `GDCPluginManager` — the distributed client app (above).
- `GDCPluginManagerFurnizor` — a Cristi-only admin tool for publishing new
  products and generating license codes. Never distributed; not useful
  without write access to the private product-files repo and the GDC signing
  key, so there's nothing to configure here if you're not GDC.

## Building from source

Requires macOS 14+ and Swift 5.9+ (Xcode Command Line Tools).

```bash
git clone https://github.com/gordasgdc/gdc-plugin-manager.git
cd gdc-plugin-manager
cp Sources/GDCPluginManagerFurnizor/PrivateCatalogAuth.swift.example Sources/GDCPluginManagerFurnizor/PrivateCatalogAuth.swift
# edit PrivateCatalogAuth.swift and paste in a real token — only the vendor app (Furnizor) uses it; the client has no storage credential
./build_app.sh
```

This builds and installs straight to `/Applications/GDCPluginManager.app`.

To build the signed `.pkg` installer:

```bash
./build_installer.sh
```

To build the vendor tool (GDC-only, needs the signing key at
`~/Library/Application Support/GDC License Manager/private_key.txt`):

```bash
./build_furnizor_app.sh
```
