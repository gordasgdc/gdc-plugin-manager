#!/bin/bash
# Lot A — garda: PAT-ul GitHub vechi nu mai e în surse compilate, configurații de build sau binare.
# Nu afișează niciodată valoarea tokenului (doar ✓/✗ și numele fișierelor).
# Utilizare: scripts/verify-no-legacy-token.sh [--build]   (--build: construiește release înainte)
set -uo pipefail
cd "$(dirname "$0")/.."
FAIL=0; ok(){ echo "✓ $*"; }; ko(){ echo "✗ $*"; FAIL=1; }
AUTH=Sources/GDCPluginManagerFurnizor/PrivateCatalogAuth.swift
WIN=../GDCPluginManagerWin

TOKEN=""
[ -f "$AUTH" ] && TOKEN=$(sed -nE 's/.*public static let token = "([^"]+)".*/\1/p' "$AUTH" | head -1)
[ "$TOKEN" = "PASTE_TOKEN_HERE" ] && TOKEN=""
PAT_RE='(github_pat_[A-Za-z0-9_]{30,}|ghp_[A-Za-z0-9]{30,})'

# 1. Surse compilate: nicio referință la PrivateCatalogAuth în afara fișierului exclus.
refs=$(grep -rlE 'PrivateCatalogAuth\.(token|repos|owner|repo|defaultRepoKey)' Sources Tests 2>/dev/null | grep -v "PrivateCatalogAuth.swift$" || true)
[ -z "$refs" ] && ok "sursele nu mai folosesc PrivateCatalogAuth" || ko "referințe rămase: $refs"
grep -q '"PrivateCatalogAuth.swift"' Package.swift && ok "Package.swift exclude PrivateCatalogAuth.swift" || ko "PrivateCatalogAuth.swift nu e exclus în Package.swift"
git check-ignore -q "$AUTH" && ok "PrivateCatalogAuth.swift rămâne gitignored" || ko "PrivateCatalogAuth.swift NU e ignorat de git"
leak=$(git grep -lE "$PAT_RE" -- . ':!*.md' 2>/dev/null || true)
[ -z "$leak" ] && ok "niciun PAT în fișierele urmărite de git" || ko "tipar PAT în: $leak"

# 2. Windows: build-ul nu mai folosește tokenul / secretul.
if [ -d "$WIN" ]; then
  grep -q 'Compile Remove="Services\\PrivateCatalogAuth.cs"' "$WIN/src/GDCPluginManager.Core/GDCPluginManager.Core.csproj" \
    && ok "Windows: PrivateCatalogAuth.cs exclus din build" || ko "Windows: PrivateCatalogAuth.cs încă intră în build"
  if grep -hE 'secrets\.PRIVATE_CATALOG_TOKEN' "$WIN"/.github/workflows/*.yml >/dev/null 2>&1; then ko "Windows: workflow-ul folosește încă PRIVATE_CATALOG_TOKEN"; else ok "Windows: niciun workflow nu citește PRIVATE_CATALOG_TOKEN"; fi
fi

# 3. Binare.
if [ "${1:-}" = "--build" ]; then
  swift build -c release >/tmp/.gdc-lotA-build.log 2>&1 && ok "swift build -c release" || { ko "build eșuat (vezi /tmp/.gdc-lotA-build.log)"; }
fi
bins=$(find -L .build/release .build/debug dist -maxdepth 4 -type f -perm -111 -name 'GDCPluginManager*' 2>/dev/null | grep -v '\.dSYM' || true)
[ -z "$bins" ] && ko "niciun binar de verificat (rulează cu --build)"
for b in $bins; do
  hit=0
  [ -n "$TOKEN" ] && LC_ALL=C grep -qaF "$TOKEN" "$b" && hit=1   # -a: fără el, grep BSD ratează potriviri în binare
  strings "$b" | grep -qE "$PAT_RE" && hit=1
  # dist/ conține build-uri vechi (dinainte de lot A): se raportează, nu pică garda.
  if [ $hit = 1 ]; then case "$b" in dist/*) echo "! $b: build VECHI cu token (se înlocuiește la următorul build)";; *) ko "$b conține tokenul";; esac
  else ok "$b: fără token"; fi
done

# 3b. Control pozitiv: aplicația instalată (build anterior lotului A) trebuie DETECTATĂ — dovedește că garda vede tokenul.
for app in /Applications/*Furnizor*.app; do
  [ -d "$app" ] || continue
  f="$app/Contents/MacOS/GDCPluginManagerFurnizor"
  if strings "$f" 2>/dev/null | grep -qE "$PAT_RE"; then echo "! control: $(basename "$app") instalat conține încă tokenul (build vechi; se înlocuiește la instalarea aprobată)"
  else ok "control: $(basename "$app") instalat fără token"; fi
done

# 4. gh: autentificat + acces la repo-urile de resurse; comportament fără autentificare.
GH=$(command -v gh || echo /opt/homebrew/bin/gh)
if [ -x "$GH" ]; then
  "$GH" auth status >/dev/null 2>&1 && ok "gh autentificat" || ko "gh NEautentificat (gh auth login)"
  for r in files pdfs scripts resources; do
    s=$("$GH" api "/repos/gordasgdc/gdc-plugin-manager-$r" --jq .size 2>/dev/null) && ok "gh → gdc-plugin-manager-$r (${s} KB)" || ko "gh nu poate citi gdc-plugin-manager-$r"
  done
  tmp=$(mktemp -d)
  if env -u GH_TOKEN -u GITHUB_TOKEN GH_CONFIG_DIR="$tmp" GH_PROMPT_DISABLED=1 "$GH" api /repos/gordasgdc/gdc-plugin-manager-files --jq .size >/dev/null 2>&1; then
    ko "fără autentificare, repo-ul privat e totuși citibil (neașteptat)"
  else ok "fără autentificare: gh eșuează curat → Furnizorul arată dimensiunea ca necunoscută"; fi
  rm -rf "$tmp"
else ko "gh lipsește"; fi

[ $FAIL = 0 ] && echo "REZULTAT: OK" || echo "REZULTAT: EȘEC"
exit $FAIL
