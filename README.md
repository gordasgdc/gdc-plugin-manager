# GDC Plugin Manager

A native **macOS-only** (Apple Silicon) app that installs, updates, and removes
Cristi Gordas' (GDC) own DCTL, LUT, and Fuse products for DaVinci Resolve with
one click — instead of manually copying files into DaVinci Resolve's plugin
folders.

**The app itself is free.** Browsing the catalog costs nothing — you only pay
for the individual products you actually want, each bought and licensed
separately.

Built with Swift/SwiftUI, in the same family as
[CursorPro GDC](https://github.com/gordasgdc/cursorpro-gdc) and
[GDC License Manager](https://github.com/gordasgdc/gdc-license-manager).

Romanian / English / Spanish interface.

## What it does

- Fetches a catalog of GDC's DCTL/LUT/Fuse products for DaVinci Resolve, with
  a price on each.
- Installs the selected (purchased) product straight into the folder DaVinci
  Resolve reads at launch (asking for the admin password only if a direct
  write is refused).
- Tracks installed versions and offers one-click updates.
- Warns before installing/removing while DaVinci Resolve is open, since
  Resolve only loads plugins at startup.
- Checks for app updates automatically and shows a banner when a newer
  version is available.

## Download

Get the latest build from [Releases](../../releases/latest) — free, no
account, no trial. Each product's price and a "Buy" button (opens WhatsApp)
are shown on its own card in the catalog; a purchased product's license code
is pasted into the app's **License** page to unlock installing/updating that
one product.

## License

The app is free forever. Each product requires its own one-time, per-computer
license (see the **License** page in the app) — buying one product does not
unlock any other. Already-installed products keep working in DaVinci Resolve
regardless of license state.

Source code in this repository is provided under the MIT license (see
[LICENSE](LICENSE)) — it's open for review; the app's own terms for buying and
activating individual products are in
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
cp Sources/GDCPluginManager/PrivateCatalogAuth.swift.example Sources/GDCPluginManager/PrivateCatalogAuth.swift
# edit PrivateCatalogAuth.swift and paste in a real token to build the client target
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
