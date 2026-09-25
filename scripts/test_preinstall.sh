#!/bin/bash
# Testeaza installer/scripts/preinstall pe un volum fals (nu atinge /Applications
# si nu opreste aplicatia reala: pkill/sleep sunt inlocuite in PATH).
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
mkdir -p "$T/bin"; printf '#!/bin/sh\necho "$0 $*" >> "%s/calls"\n' "$T" > "$T/bin/pkill"; cp "$T/bin/pkill" "$T/bin/sleep"; chmod +x "$T/bin/"*
fail=0
run() { # run <versiune pachet> <versiune instalata|-> <cod asteptat> <aplicatia ramane: da|nu>
  local vol="$T/vol"; rm -rf "$vol" "$T/calls"; mkdir -p "$vol/Applications"
  if [ "$2" != - ]; then
    mkdir -p "$vol/Applications/GDCPluginManager.app/Contents"
    /usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string $2" "$vol/Applications/GDCPluginManager.app/Contents/Info.plist" >/dev/null
  fi
  sed "s/__PKG_VERSION__/$1/" "$ROOT/installer/scripts/preinstall" > "$T/pre"
  PATH="$T/bin:$PATH" bash "$T/pre" "/pkg" "$vol" "$vol" 2>/dev/null; local code=$?
  local left=nu; [ -d "$vol/Applications/GDCPluginManager.app" ] && left=da
  local pk=nu; [ -f "$T/calls" ] && grep -q pkill "$T/calls" && pk=da
  if [ "$code" = "$3" ] && [ "$left" = "$4" ]; then echo "✓ pachet $1 peste $2 → cod $code, aplicatia ramane: $left, pkill: $pk"
  else echo "✗ pachet $1 peste $2 → cod $code (astept $3), aplicatia ramane: $left (astept $4)"; fail=1; fi
}
run 1.39.3 1.39.4 1 da   # retrogradare: refuz, nimic atins
run 1.39.3 1.40.0 1 da
run 1.39.4 1.39.3 0 nu   # actualizare normala
run 1.39.4 1.39.4 0 nu   # reinstalare aceeasi versiune
run 1.39.4 -      0 nu   # instalare curata
run 1.39.4 abc    0 nu   # versiune instalata ilizibila: comportamentul vechi
exit $fail
