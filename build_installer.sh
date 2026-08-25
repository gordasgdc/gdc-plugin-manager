#!/usr/bin/env bash
# Builds GDCPluginManager.app fresh, then wraps it in a signed-content .pkg
# installer with a license (Terms & Conditions) pane the user must
# accept to continue — via productbuild's native license-pane support.
#
# NOTE: produces a SIGNED + NOTARIZED .pkg automatically once the Apple
# Developer ID Installer certificate is configured (see
# codesigning/README.md, one-time setup). Until then, falls back to an
# UNSIGNED package — macOS Gatekeeper shows an "unidentified developer"
# warning on first open (right-click the .pkg → Open, or allow it in
# System Settings → Privacy & Security). Mention that in download
# instructions only while unsigned.
set -euo pipefail
cd "$(dirname "$0")"

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Info.plist)
PKG_ID="com.gordasgdc.pluginmanager.installer"
APP_NAME="GDCPluginManager.app"
DIST_DIR="dist"
PAYLOAD_ROOT="$DIST_DIR/payload"
COMPONENT_PKG="$DIST_DIR/GDCPluginManager-component.pkg"
FINAL_PKG="$DIST_DIR/GDCPluginManager-$VERSION.pkg"

echo "==> Building app…"
./build_app.sh

rm -rf "$DIST_DIR"
mkdir -p "$PAYLOAD_ROOT/Applications"
cp -R "/Applications/$APP_NAME" "$PAYLOAD_ROOT/Applications/$APP_NAME"

echo "==> Building component package…"
# --install-location "/" (NOT "/Applications") because $PAYLOAD_ROOT already
# contains its own Applications/ subfolder — using "/Applications" here would
# nest it again into /Applications/Applications/, exactly the bug found and
# fixed today in gdc-production-manager's installer.
#
# --scripts: preinstall CURATA doar o instalare veche ramasa (pkill +
# rm -rf /Applications/GDCPluginManager.app), ca sa nu ramana doua copii
# ale aplicatiei cu acelasi bundle ID pe disc. NU contine niciun hack de
# Gatekeeper/quarantine - pachetul e semnat + notarizat + stapled mai jos,
# deci Gatekeeper il accepta nativ (vezi CLAUDE.md, 2026-08-25).
pkgbuild \
    --root "$PAYLOAD_ROOT" \
    --identifier "$PKG_ID" \
    --version "$VERSION" \
    --install-location "/" \
    --scripts "installer/scripts" \
    "$COMPONENT_PKG"

echo "==> Writing distribution definition…"
cat > "$DIST_DIR/Distribution.xml" << EOF
<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="1">
    <title>GDC Plugin Manager $VERSION</title>
    <license file="License.txt" mime-type="text/plain"/>
    <options customize="never" require-scripts="false" rootVolumeOnly="true"/>
    <domains enable_localSystem="true"/>
    <choices-outline>
        <line choice="default">
            <line choice="$PKG_ID"/>
        </line>
    </choices-outline>
    <choice id="default"/>
    <choice id="$PKG_ID" visible="false">
        <pkg-ref id="$PKG_ID"/>
    </choice>
    <pkg-ref id="$PKG_ID" version="$VERSION" onConclusion="none">GDCPluginManager-component.pkg</pkg-ref>
</installer-gui-script>
EOF

cp installer/License.txt "$DIST_DIR/License.txt"

echo "==> Building final installer package…"
productbuild \
    --distribution "$DIST_DIR/Distribution.xml" \
    --package-path "$DIST_DIR" \
    --resources "$DIST_DIR" \
    "$FINAL_PKG"

rm -rf "$PAYLOAD_ROOT" "$COMPONENT_PKG"

# Semnare + notarizare a .pkg-ului final, daca certificatul Installer e
# configurat (vezi codesigning/README.md) - altfel ramane nesemnat, ca
# pana acum (avertisment Gatekeeper la instalare).
./codesigning/sign-and-notarize.sh pkg "$FINAL_PKG"

# A version-agnostic copy too — the landing page always links to this
# stable filename (releases/latest/download/GDCPluginManager.pkg), so it
# doesn't need editing every release. Upload BOTH files to each GitHub
# release: the versioned one (so old links keep working) and this one
# (so the landing page's link always resolves to whatever is newest).
cp "$FINAL_PKG" "$DIST_DIR/GDCPluginManager.pkg"

# REGULA PERMANENTA (2026-08-25): fiecare pachet trebuie sa includa un
# uninstaller complet, nu doar instalatorul - vezi CLAUDE.md. Copiat aici,
# nu generat din nou, ca sa nu existe doua surse de adevar pentru script.
echo "==> Copying uninstaller (Dezinstalare_GDCPluginManager.command)…"
cp "Dezinstalare_GDCPluginManager.command" "$DIST_DIR/Dezinstalare_GDCPluginManager.command"
chmod +x "$DIST_DIR/Dezinstalare_GDCPluginManager.command"

# Bundle .pkg + uninstaller + ghid PDF intr-un zip curat. Pachetul e semnat
# + notarizat + stapled, deci Gatekeeper il accepta nativ la dublu-click -
# NU mai exista niciun launcher/script de bypass (eliminat 2026-08-25,
# acelasi motiv ca la CursorPro: inutil si arata neprofesionist cand
# certificarea Apple e deja in regula). Totul la radacina arhivei.
echo "==> Building GDCPluginManager-Mac.zip (pkg + uninstaller + ghid)…"
ZIP_STAGE="$DIST_DIR/zip_stage"
rm -rf "$ZIP_STAGE"
mkdir -p "$ZIP_STAGE"
cp "$DIST_DIR/GDCPluginManager.pkg" "$ZIP_STAGE/"
cp "$DIST_DIR/Dezinstalare_GDCPluginManager.command" "$ZIP_STAGE/"
chmod +x "$ZIP_STAGE/Dezinstalare_GDCPluginManager.command"
cp "Sources/GDCPluginManager/Resources/Ghid-GDCPluginManager-ro.pdf" "$ZIP_STAGE/Ghid-de-Utilizare.pdf" 2>/dev/null || true
( cd "$ZIP_STAGE" && zip -q -r -y "../GDCPluginManager-Mac.zip" . )
rm -rf "$ZIP_STAGE"

echo "==> Done: $FINAL_PKG"
echo "==> Also: $DIST_DIR/GDCPluginManager.pkg, $DIST_DIR/Dezinstalare_GDCPluginManager.command, $DIST_DIR/GDCPluginManager-Mac.zip"
echo "    Upload GDCPluginManager-Mac.zip to the GitHub release (that's what the website links to)."
