#!/usr/bin/env bash
# Builds "GDC Plugin Manager Furnizor.app" - Cristi-only, never
# distributed. Mirrors build_app.sh's exact pattern but stays completely
# separate: its own scoped build, its own Info.plist/bundle id, its own
# fixed /Applications destination, its own pkill target - building or
# relaunching this one never touches the client app's running instance
# or bundle.
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release --product GDCPluginManagerFurnizor

BUILD_OUT="/tmp/GDCPluginManagerFurnizor.app.build-$$"
rm -rf "$BUILD_OUT"
mkdir -p "$BUILD_OUT/Contents/MacOS"
mkdir -p "$BUILD_OUT/Contents/Resources"

cp .build/release/GDCPluginManagerFurnizor "$BUILD_OUT/Contents/MacOS/GDCPluginManagerFurnizor"
cp Info-Furnizor.plist "$BUILD_OUT/Contents/Info.plist"
cp AppIcon.icns "$BUILD_OUT/Contents/Resources/AppIcon.icns"

# BUG REAL, gasit 2026-09-03: acest pas lipsea complet — SPM pune bundle-ul
# de resurse (SeasonalPresets PNG-uri, acum si ghidurile PDF) langa
# executabil in .build/release/, NU-l copiaza automat in .app. Fara asta,
# Bundle.module.url(...) intoarce nil in aplicatia INSTALATA (desi merge la
# `swift run` local, care rezolva Bundle.module direct din .build/) — exact
# tiparul deja documentat in build_app.sh pentru Client.
SPM_RESOURCE_BUNDLE=".build/release/GDCPluginManager_GDCPluginManagerFurnizor.bundle"
if [ -d "$SPM_RESOURCE_BUNDLE" ]; then
    cp -R "$SPM_RESOURCE_BUNDLE" "$BUILD_OUT/Contents/Resources/"
fi

SIGN_IDENTITY="CursorPro"
codesign --force --deep --sign "$SIGN_IDENTITY" "$BUILD_OUT"

INSTALLED="/Applications/GDC Plugin Manager Furnizor.app"
if [ -d "$INSTALLED" ]; then
    pkill -x GDCPluginManagerFurnizor 2>/dev/null || true
    sleep 0.5
fi
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
"$LSREGISTER" -u "$INSTALLED" 2>/dev/null || true
# sudo on purpose - see build_app.sh for why: a root-owned leftover
# (e.g. from a previous .pkg install) would otherwise fail with
# "Permission denied" instead of just asking for the admin password.
if [ -e "$INSTALLED" ] && [ ! -O "$INSTALLED" ]; then
    sudo rm -rf "$INSTALLED"
    sudo mv "$BUILD_OUT" "$INSTALLED"
    sudo chown -R "$(id -u):$(id -g)" "$INSTALLED"
else
    rm -rf "$INSTALLED"
    mv "$BUILD_OUT" "$INSTALLED"
fi
"$LSREGISTER" -f "$INSTALLED" 2>/dev/null || true
echo "Installed to $INSTALLED"
