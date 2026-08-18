#!/usr/bin/env bash
# Builds GDCPluginManager.app fresh, then wraps it in a signed-content .pkg
# installer with a license (Terms & Conditions) pane the user must
# accept to continue — via productbuild's native license-pane support.
#
# NOTE: this produces an UNSIGNED installer package (we don't have a
# paid Apple Developer ID Installer certificate, only a free local code-
# signing identity for the app itself). macOS Gatekeeper will show an
# "unidentified developer" warning on first open — right-click the .pkg
# → Open, or allow it in System Settings → Privacy & Security. This is
# normal for indie-distributed tools outside the App Store; mention it
# in the download instructions.
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
pkgbuild \
    --root "$PAYLOAD_ROOT" \
    --identifier "$PKG_ID" \
    --version "$VERSION" \
    --install-location "/" \
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

# A version-agnostic copy too — the landing page always links to this
# stable filename (releases/latest/download/GDCPluginManager.pkg), so it
# doesn't need editing every release. Upload BOTH files to each GitHub
# release: the versioned one (so old links keep working) and this one
# (so the landing page's link always resolves to whatever is newest).
cp "$FINAL_PKG" "$DIST_DIR/GDCPluginManager.pkg"

echo "==> Done: $FINAL_PKG"
echo "==> Also: $DIST_DIR/GDCPluginManager.pkg (upload both to the GitHub release)"
