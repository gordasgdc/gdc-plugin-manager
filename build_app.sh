#!/usr/bin/env bash
# Builds GDCPluginManager.app from the SPM executable + Info.plist and
# installs it straight to /Applications - the ONLY copy that's ever
# allowed to exist on disk (never leave a second copy in the project
# folder too - two bundles sharing one identifier confuses macOS's
# permission system).
set -euo pipefail
cd "$(dirname "$0")"

if [ ! -x "PythonRuntime/bin/python3" ]; then
    ./fetch_python_runtime.sh
fi

swift build -c release --product GDCPluginManager

BUILD_OUT="/tmp/GDCPluginManager.app.build-$$"
rm -rf "$BUILD_OUT"
mkdir -p "$BUILD_OUT/Contents/MacOS"
mkdir -p "$BUILD_OUT/Contents/Resources"

cp .build/release/GDCPluginManager "$BUILD_OUT/Contents/MacOS/GDCPluginManager"
cp Info.plist "$BUILD_OUT/Contents/Info.plist"
cp AppIcon.icns "$BUILD_OUT/Contents/Resources/AppIcon.icns"

# Python portabil (cpython-build-standalone, arm64, ~66MB) — bundle-uit ca
# PowerGradeImporter sa NU mai depinda de python3 de sistem (Apple a scos
# /usr/bin/python3 din macOS implicit pe versiunile recente; vine doar cu
# Command Line Tools). Vezi PowerGradeImporter.swift findPython3().
cp -R PythonRuntime "$BUILD_OUT/Contents/Resources/PythonRuntime"

# Same local trusted certificate reused across every GDC Mac app this
# session - this app needs no TCC-gated permissions, so a dedicated cert
# isn't necessary, but a stable identity still avoids Gatekeeper "unknown
# developer" friction being different every rebuild.
SIGN_IDENTITY="CursorPro"
codesign --force --deep --sign "$SIGN_IDENTITY" "$BUILD_OUT"

INSTALLED="/Applications/GDCPluginManager.app"
if [ -d "$INSTALLED" ]; then
    pkill -x GDCPluginManager 2>/dev/null || true
    sleep 0.5
fi
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
"$LSREGISTER" -u "$INSTALLED" 2>/dev/null || true
# sudo on purpose: a previous .pkg-based install (or Installer.app) can
# leave /Applications/GDCPluginManager.app root-owned, which makes a
# plain `rm`/`mv` fail with "Permission denied" - asking for the admin
# password up front here means the script always works, prompting only
# when actually needed (sudo -n checks first, no prompt if already owned
# by the current user).
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
