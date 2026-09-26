#!/bin/bash
# Gardă „ratchet” pentru DESIGN_SYSTEM.md: numărul de valori vizuale literale per țintă nu are voie să crească.
# Baza: engineering/design-literals-baseline.txt. Scade → rulează cu --update ca să fixezi noul prag.
set -uo pipefail
cd "$(dirname "$0")/.."
BASE=engineering/design-literals-baseline.txt
RX='\.padding\((\.[a-zA-Z]+, )?[0-9.]+\)|\bspacing: [0-9.]+|cornerRadius: ?[0-9.]+|\.cornerRadius\([0-9.]+\)|\.system\(size: [0-9.]+|Color\((red|white|srgbRed):|\bColor\.(red|orange|green|blue|yellow|purple|pink)\b|\((\.)?(red|orange|green|blue|yellow)\)'
count() { grep -rhoE "$RX" "Sources/$1" --include='*.swift' 2>/dev/null | grep -v "^//" | wc -l | tr -d ' '; }
FAIL=0; NEW=""
for t in GDCPluginManager GDCPluginManagerFurnizor; do
  n=$(count "$t"); b=$(grep -E "^$t " "$BASE" 2>/dev/null | awk '{print $2}')
  NEW+="$t $n"$'\n'
  if [ -z "$b" ]; then echo "• $t: $n (fără bază)"
  elif [ "$n" -gt "$b" ]; then echo "✗ $t: $n > bază $b — folosește GDCTokens (DESIGN_SYSTEM.md) în codul nou"; FAIL=1
  else echo "✓ $t: $n (bază $b)"; fi
done
if [ "${1:-}" = "--update" ]; then printf "%s" "$NEW" > "$BASE"; echo "bază actualizată"; fi
exit $FAIL
