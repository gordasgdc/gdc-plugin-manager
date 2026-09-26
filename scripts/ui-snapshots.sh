#!/bin/bash
# Capturi locale ale clientului pentru verificare vizuală (RO/EN/ES × Light/Dark), FĂRĂ instalare:
# construiește un .app temporar în <out>/, semnat ad-hoc, și îl pornește cu setările date ca
# argumente (domeniul NSArgumentDomain — preferințele reale ale utilizatorului nu se modifică).
# Utilizare: scripts/ui-snapshots.sh <out-dir> [repo-dir]    (repo-dir implicit: acest repo)
# Filtre: LANGS="ro" THEMES="dark". Redimensionare reală: EXTRA_ARGS="-GDCWindowSize 760x500 [-GDCWindowResizeStress YES]".
# Argumente suplimentare de pornire: EXTRA_ARGS="-GDCComponentGallery YES -GDCGalleryWidth 560 -GDCGalleryOffset 3" (galeria există doar în DEBUG).
set -euo pipefail
OUT="${1:?director de ieșire}"; REPO="${2:-$(cd "$(dirname "$0")/.." && pwd)}"
mkdir -p "$OUT"; APP="$OUT/GDCPluginManager-preview.app"
(cd "$REPO" && swift build --product GDCPluginManager >/dev/null)
BIN="$REPO/.build/debug"
rm -rf "$APP"; mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/GDCPluginManager" "$APP/Contents/MacOS/"; cp "$REPO/Info.plist" "$APP/Contents/"
cp "$REPO/AppIcon.icns" "$APP/Contents/Resources/" 2>/dev/null || true
[ -d "$BIN/GDCPluginManager_GDCPluginManager.bundle" ] && cp -R "$BIN/GDCPluginManager_GDCPluginManager.bundle" "$APP/Contents/Resources/"
codesign --force --deep --sign - "$APP" >/dev/null 2>&1
if pgrep -x GDCPluginManager >/dev/null; then echo "✗ Închide întâi GDC Plugin Manager (instanța instalată)." >&2; exit 1; fi
WID_SWIFT="$OUT/.wid.swift"
cat > "$WID_SWIFT" <<'SW'
import CoreGraphics
let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as! [[String: Any]]
let w = list.filter { ($0[kCGWindowOwnerName as String] as? String) == "GDC Plugin Manager" && ($0[kCGWindowLayer as String] as? Int) == 0 }
    .max { (($0[kCGWindowBounds as String] as? [String: Double])?["Width"] ?? 0) < (($1[kCGWindowBounds as String] as? [String: Double])?["Width"] ?? 0) }
print(w?[kCGWindowNumber as String] as? Int ?? 0)
SW
for lang in ${LANGS:-ro en es}; do for theme in ${THEMES:-light dark}; do
  open -n "$APP" --args -gdcpm_lang "$lang" -GDCPluginManager.appTheme "$theme" -NSQuitAlwaysKeepsWindows NO ${EXTRA_ARGS:-}
  sleep "${WAIT:-9}"
  wid=$(swift "$WID_SWIFT" 2>/dev/null || echo 0)
  if [ "$wid" != 0 ]; then screencapture -x -o -l"$wid" "$OUT/$lang-$theme.png" && echo "✓ $lang-$theme"; else echo "✗ $lang-$theme: fereastră negăsită"; fi
  pkill -x GDCPluginManager || true; sleep 2
done; done
