#!/bin/bash
set -euo pipefail

# Împachetează Furnizorul ca .pkg semnat + notarizat, pe același tipar ca
# build_installer.sh (clientul). Scopul e restrâns și declarat: reinstalare pe
# un Mac nou sau o a doua stație a lui Cristi — NU distribuție către clienți.
#
# CE CONȚINE BINARUL (verificat, nu presupus, 2026-09-14): aceeași cheie
# Supabase `anon` și același token GitHub read-only pe care le are și clientul
# public. Cheia Ed25519 de licențiere NU e în binar — se citește la rulare din
# ~/Library/Application Support/GDC License Manager/private_key.txt, deci un
# Furnizor instalat pe o mașină fără acel fișier nu poate genera nicio licență.
# Publicarea la vedere rămâne totuși nerecomandată (Regula 29: unealta internă
# nu se expune public) — atașează-l pe un repo PRIVAT.

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Info-Furnizor.plist)
PKG_ID="com.gordasgdc.pluginmanager.furnizor.installer"
APP_NAME="GDC Plugin Manager Furnizor.app"
DIST_DIR="dist-furnizor"
PAYLOAD_ROOT="$DIST_DIR/payload"
COMPONENT_PKG="$DIST_DIR/Furnizor-component.pkg"
FINAL_PKG="$DIST_DIR/GDCPluginManagerFurnizor-$VERSION.pkg"

# Garda Regula 23: un dist/ rămas root-owned face `rm -rf` să eșueze parțial și
# tăcut, cu zeci de "Permission denied" pierdute într-un log lung.
if [ -d "$DIST_DIR" ] && find "$DIST_DIR" -maxdepth 2 -user root -print -quit 2>/dev/null | grep -q .; then
    echo "EROARE: '$DIST_DIR/' conține fișiere deținute de root. Rulează manual:" >&2
    echo "    sudo rm -rf $(pwd)/$DIST_DIR" >&2
    exit 1
fi

echo "==> Construiesc aplicația…"
./build_furnizor_app.sh

rm -rf "$DIST_DIR"
mkdir -p "$PAYLOAD_ROOT/Applications"
cp -R "/Applications/$APP_NAME" "$PAYLOAD_ROOT/Applications/$APP_NAME"

echo "==> Pachet componentă…"
pkgbuild \
    --root "$PAYLOAD_ROOT" \
    --identifier "$PKG_ID" \
    --version "$VERSION" \
    --install-location "/" \
    "$COMPONENT_PKG"

echo "==> Definiție de distribuție…"
cat > "$DIST_DIR/Distribution.xml" << EOF
<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="1">
    <title>GDC Plugin Manager Furnizor $VERSION</title>
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
    <pkg-ref id="$PKG_ID" version="$VERSION" onConclusion="none">Furnizor-component.pkg</pkg-ref>
</installer-gui-script>
EOF

echo "==> Pachet final…"
productbuild \
    --distribution "$DIST_DIR/Distribution.xml" \
    --package-path "$DIST_DIR" \
    --resources "$DIST_DIR" \
    "$FINAL_PKG"

rm -rf "$PAYLOAD_ROOT" "$COMPONENT_PKG"

./codesigning/sign-and-notarize.sh pkg "$FINAL_PKG"

# Aceeași gardă ca la client: un pachet nesemnat nu trebuie să treacă drept gata.
if ! pkgutil --check-signature "$FINAL_PKG" 2>/dev/null | grep -q "Status: signed"; then
    echo "EROARE: $FINAL_PKG a ieșit NESEMNAT — vezi build_installer.sh pentru variabilele necesare." >&2
    exit 1
fi

echo "==> Gata: $FINAL_PKG"
