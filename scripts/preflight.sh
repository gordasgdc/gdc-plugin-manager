#!/bin/bash
# Preflight unic: alege verificările după fișierele modificate față de <bază> (implicit main).
# Utilizare: scripts/preflight.sh [--full] [bază]     --full = toate verificările, indiferent de diff.
# Ieșire: o linie per verificare (✓/✗) + REZULTAT. Detaliile eșecurilor în $TMPDIR/preflight-*.log.
set -uo pipefail
cd "$(dirname "$0")/.."
FULL=0; [ "${1:-}" = "--full" ] && { FULL=1; shift; }
BASE="${1:-main}"; LOG="${TMPDIR:-/tmp}/preflight"
CHANGED=$( { git diff --name-only "$BASE"...HEAD; git diff --name-only; git ls-files -o --exclude-standard; } 2>/dev/null | sort -u)
has() { [ $FULL = 1 ] || grep -qE "$1" <<<"$CHANGED"; }
FAIL=0
run() { local name="$1"; shift; if "$@" >"$LOG-$name.log" 2>&1; then echo "✓ $name"; else echo "✗ $name (vezi $LOG-$name.log)"; FAIL=1; fi; }

has '^(Sources|Tests|Package)' && run build swift build
if has '^(Sources/GDCPluginManagerCore|Tests/GDCPluginManagerCoreTests|Package)'; then
  # Singurul eșec tolerat: testul de versiune, cât timp versiunea locală e încă nepublicată (update.json rămâne pe cea publică).
  if swift test >"$LOG-teste.log" 2>&1; then echo "✓ teste-toate"
  else
    fails=$(grep -oE "\[[A-Za-z.]+Tests [A-Za-z]+\]' failed" "$LOG-teste.log" | sort -u)
    if [ "$fails" = "[GDCPluginManagerCoreTests.UpdateManifestTests testInstalledVersionMatchesManifest]' failed" ]; then
      echo "✓ teste-toate (1 eșec cunoscut: versiune locală nepublicată în update.json)"
    else echo "✗ teste-toate (vezi $LOG-teste.log)"; FAIL=1; fi
  fi
else
  has '^(Sources/GDCPluginManagerFurnizor|Tests/GDCPluginManagerFurnizorTests)' && run teste-furnizor swift test --filter GDCPluginManagerFurnizorTests
  has 'PromoBanner|LaunchBanner' && run teste-bannere swift test --filter 'PromoBannerTests|BannerImageProcessorTests'
fi
has '^Sources/(GDCPluginManager|GDCPluginManagerFurnizor)/' && run literale-design scripts/audit-design-literals.sh
has '\.swift$' && run culori-tema ~/Developer/_gdc-tools/audit-theme-colors.sh
has '^Sources/GDCPluginManagerFurnizor/|PrivateCatalogAuth|Package.swift' && run token-vechi scripts/verify-no-legacy-token.sh
# Localizarea are 22 erori preexistente: se compară doar numărul, nu pică pe ele.
if has 'Localization.swift'; then
  n=$(python3 scripts/check_localization.py 2>&1 | tail -1 | grep -oE '[0-9]+ erori' | grep -oE '[0-9]+')
  if [ "${n:-99}" -le 22 ]; then echo "✓ localizare (${n} erori preexistente)"; else echo "✗ localizare: ${n} erori (>22)"; FAIL=1; fi
fi
has '^Sources/GDCPluginManager(Core)?/.*\.swift$' && swift build -c release --product GDCPluginManager >"$LOG-release.log" 2>&1 \
  && strings .build/release/GDCPluginManager | grep -qE 'GDCComponentGallery|PromoBannerFixture' \
  && { echo "✗ cod DEBUG în build-ul release"; FAIL=1; }
[ $FAIL = 0 ] && echo "REZULTAT: OK" || echo "REZULTAT: EȘEC"
exit $FAIL
