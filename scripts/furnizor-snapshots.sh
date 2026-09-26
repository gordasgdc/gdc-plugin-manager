#!/bin/bash
# Capturi locale ale Furnizorului (build DEBUG, FĂRĂ instalare): .app temporar semnat ad-hoc, pornit cu
# argumente (tema, rubrica, mărimea ferestrei). Închide DOAR instanța pornită de script, niciodată Furnizorul tău.
# Utilizare: SECTIONS="publish salesHistory" THEMES="dark light" SIZE=1280x800 scripts/furnizor-snapshots.sh <out>
set -euo pipefail
OUT="${1:?director de ieșire}"; REPO="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$OUT"; APP="$OUT/GDCFurnizor-preview.app"
(cd "$REPO" && swift build --product GDCPluginManagerFurnizor >/dev/null)
BIN="$REPO/.build/debug"
rm -rf "$APP"; mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/GDCPluginManagerFurnizor" "$APP/Contents/MacOS/"; cp "$REPO/Info-Furnizor.plist" "$APP/Contents/Info.plist"
for b in "$BIN"/GDCPluginManager_GDCPluginManagerFurnizor.bundle; do [ -d "$b" ] && cp -R "$b" "$APP/Contents/Resources/"; done
codesign --force --deep --sign - "$APP" >/dev/null 2>&1
cat > "$OUT/.wid.swift" <<'SW'
import CoreGraphics
let pid = Int(CommandLine.arguments[1]) ?? 0
let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as! [[String: Any]]
let w = list.filter { ($0[kCGWindowOwnerPID as String] as? Int) == pid && ($0[kCGWindowLayer as String] as? Int) == 0 }
    .max { (($0[kCGWindowBounds as String] as? [String: Double])?["Width"] ?? 0) < (($1[kCGWindowBounds as String] as? [String: Double])?["Width"] ?? 0) }
print(w?[kCGWindowNumber as String] as? Int ?? 0)
SW
for sec in ${SECTIONS:-publish}; do for theme in ${THEMES:-dark light}; do
  open -n "$APP" --args -GDCPluginManager.appTheme "$theme" -FurnizorStartSection "$sec" -GDCWindowSize "${SIZE:-1280x800}" -NSQuitAlwaysKeepsWindows NO ${EXTRA_ARGS:-}
  sleep "${WAIT:-8}"
  pid=$(pgrep -f "$APP/Contents/MacOS/GDCPluginManagerFurnizor" | head -1 || true)
  wid=$( [ -n "$pid" ] && swift "$OUT/.wid.swift" "$pid" 2>/dev/null || echo 0)
  if [ "${wid:-0}" != 0 ]; then screencapture -x -o -l"$wid" "$OUT/$sec-$theme.png" && echo "✓ $sec-$theme"; else echo "✗ $sec-$theme"; fi
  pkill -f "$APP/Contents/MacOS/GDCPluginManagerFurnizor" || true; sleep 2
done; done
