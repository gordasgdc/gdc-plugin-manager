# GDC Plugin Manager

A native macOS app that installs, updates, and removes Cristi Gordas' (GDC)
own DCTL, LUT, and Fuse products for DaVinci Resolve with one click — instead
of manually copying files into DaVinci Resolve's plugin folders.

Built as a lightweight, native (Swift/SwiftUI) Apple Silicon app, in the same
family as [CursorPro GDC](https://github.com/gordasgdc/cursorpro-gdc) and
[GDC License Manager](https://github.com/gordasgdc/gdc-license-manager).

Romanian / English / Spanish interface.

## What it does

- Fetches a catalog of GDC's DCTL/LUT/Fuse products for DaVinci Resolve.
- Installs the selected product straight into the folder DaVinci Resolve
  reads at launch (asking for the admin password only if a direct write is
  refused).
- Tracks installed versions and offers one-click updates.
- Warns before installing/removing while DaVinci Resolve is open, since
  Resolve only loads plugins at startup.

## Download

Get the latest build from [Releases](../../releases/latest). A **7-day free
trial** starts automatically on first launch — the full catalog can be
installed, updated, and removed during the trial, no license needed to try it.

## License

GDC Plugin Manager works fully for 7 days from first launch. After that, a
license is needed to keep installing/updating products — already-installed
products keep working in DaVinci Resolve regardless. See the **License** page
in the app, or message on WhatsApp from there to buy a one-time, lifetime
license that unlocks the whole current and future catalog.

Source code in this repository is provided under the MIT license (see
[LICENSE](LICENSE)) — it's open for review, but using the distributed app
past the trial period requires an activation code, per the app's own terms
(see [installer/License.txt](installer/License.txt)).

## Building from source

Requires macOS 14+ and Swift 5.9+ (Xcode Command Line Tools).

```bash
git clone https://github.com/gordasgdc/gdc-plugin-manager.git
cd gdc-plugin-manager
./build_app.sh
```

This builds and installs straight to `/Applications/GDCPluginManager.app`.

To build the signed `.pkg` installer:

```bash
./build_installer.sh
```
