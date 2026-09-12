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

# Bundle-ul de resurse generat de SPM (PDF-urile de ghid — vezi HelpGuide.swift,
# Bundle.module) — SPM il pune langa executabil in .build/release/, NU se
# copiaza automat in .app; fara asta, Bundle.module.url(...) intoarce nil in
# aplicatia instalata, desi merge la `swift run` local.
SPM_RESOURCE_BUNDLE=".build/release/GDCPluginManager_GDCPluginManager.bundle"
if [ -d "$SPM_RESOURCE_BUNDLE" ]; then
    cp -R "$SPM_RESOURCE_BUNDLE" "$BUILD_OUT/Contents/Resources/"
fi

# Python portabil (cpython-build-standalone, arm64, ~66MB) — bundle-uit ca
# PowerGradeImporter sa NU mai depinda de python3 de sistem (Apple a scos
# /usr/bin/python3 din macOS implicit pe versiunile recente; vine doar cu
# Command Line Tools). Vezi PowerGradeImporter.swift findPython3().
cp -R PythonRuntime "$BUILD_OUT/Contents/Resources/PythonRuntime"

# Semnare + notarizare Apple Developer ID, daca certificatul e configurat
# (vezi codesigning/README.md) - altfel fallback la identitatea locala
# ad-hoc de mai jos (fara cont Apple Developer, ramane cu avertismentul
# Gatekeeper "unidentified developer", ca pana acum).
if [ -n "${APPLE_SIGN_IDENTITY_APP:-}" ]; then
    ./codesigning/sign-and-notarize.sh app "$BUILD_OUT"
else
    # [2026-09-12] Fallback-ul de dinainte semna TACIT cu certificatul local
    # auto-semnat "CursorPro" — numele altei aplicatii, copiat aici si ramas
    # nesincronizat. Doua probleme reale, nu teoretice:
    #   1. Un build local inlocuia aplicatia din /Applications cu una
    #      auto-semnata, iar `build_installer.sh` putea ambala EXACT acel
    #      binar intr-un pachet destinat clientilor.
    #   2. Identitatea de semnare se schimba intre build-ul local si cel
    #      livrat, iar macOS leaga permisiunile de semnatura — vezi cazul
    #      CursorPro, unde asta cerea permisiunile la fiecare pornire.
    # Acum se cauta identitatea reala din breloc; fallback-ul auto-semnat
    # ramane posibil, dar explicit si zgomotos.
    DEV_ID=$(security find-identity -v -p codesigning 2>/dev/null \
             | grep -m1 "Developer ID Application" | sed -E 's/.*"(.*)"/\1/')
    if [ -n "$DEV_ID" ]; then
        echo "==> Semnez cu identitatea reala din breloc: $DEV_ID"
        codesign --force --deep --sign "$DEV_ID" --options runtime "$BUILD_OUT"
    elif [ "${GDCPM_ALLOW_SELFSIGNED:-}" = "1" ]; then
        echo "ATENTIE: semnez cu certificatul local auto-semnat. NU impacheta" >&2
        echo "acest build pentru clienti — ramane nesemnat pentru Gatekeeper." >&2
        codesign --force --deep --sign "CursorPro" "$BUILD_OUT"
    else
        echo "EROARE: niciun 'Developer ID Application' in breloc si nici" >&2
        echo "APPLE_SIGN_IDENTITY_APP setat — refuz sa semnez cu un certificat" >&2
        echo "auto-semnat, ca sa nu ajunga din greseala intr-un pachet livrat." >&2
        echo "Pentru un test local izolat: GDCPM_ALLOW_SELFSIGNED=1 ./build_app.sh" >&2
        exit 1
    fi
fi

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
