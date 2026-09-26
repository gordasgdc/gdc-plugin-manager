#!/bin/bash
# Preflight consolidat pentru release-ul coordonat: client Mac + Furnizor (acest repo) + client Windows.
# Doar citire/verificare locală: nu publică, nu împinge, nu modifică manifestul public.
# Utilizare: scripts/preflight-all.sh [versiune-mac] [versiune-windows]
set -uo pipefail
cd "$(dirname "$0")/.."
MAC="${1:-1.40.0}"; WIN="${2:-1.38.1}"; WINREPO=../GDCPluginManagerWin; L="${TMPDIR:-/tmp}/preflight-all"
FAIL=0; ok(){ echo "✓ $*"; }; ko(){ echo "✗ $*"; FAIL=1; }
step(){ local n="$1"; shift; if "$@" >"$L-$n.log" 2>&1; then ok "$n"; else ko "$n (vezi $L-$n.log)"; fi; }

step mac-preflight scripts/preflight.sh --full
step mac-release-rules ~/Developer/_gdc-tools/preflight-release.sh "$MAC"
step win-teste bash -c "cd $WINREPO/tests/GDCPluginManager.Core.Tests && dotnet run -c Release"
step win-build-release bash -c "cd $WINREPO/src/GDCPluginManager.Client && dotnet build -c Release -v q"
step win-release-rules bash -c "cd $WINREPO && ~/Developer/_gdc-tools/preflight-release.sh $WIN"

# Secrete: tokenul vechi (după valoare), tipare generice, în fișierele urmărite ȘI în commit-urile nepublicate.
PAT='(github_pat_|ghp_|sb_secret_|sbp_)[A-Za-z0-9_]{20,}|eyJ[A-Za-z0-9_-]{30,}\.[A-Za-z0-9_-]{20,}|BEGIN [A-Z ]*PRIVATE KEY'
T=$(sed -nE 's/.*token = "([^"]+)".*/\1/p' ~/Developer/Certificates/legacy-github-pat-2026-09-26/PrivateCatalogAuth.swift 2>/dev/null)
for repo in . "$WINREPO"; do
  name=$(basename "$(cd "$repo" && pwd)")
  # JWT-urile cu rol „anon” (cheia publică Supabase din SupabaseConfig, livrată intenționat) nu sunt secrete.
  hits=$( { git -C "$repo" grep -hoE "$PAT" -- . ':!*.md' 2>/dev/null; git -C "$repo" log -p origin/main..HEAD 2>/dev/null | grep -E "^\+" | grep -oE "$PAT"; } \
          | python3 -c 'import sys,base64,json
bad=0
for t in sys.stdin.read().split():
    if t.startswith("eyJ"):
        try:
            p=t.split(".")[1]; p+="="*(-len(p)%4)
            if json.loads(base64.urlsafe_b64decode(p)).get("role")=="anon": continue
        except Exception: pass
    bad+=1
print(bad if bad else "")' )
  [ -n "$T" ] && git -C "$repo" log -p origin/main..HEAD 2>/dev/null | grep -qF "$T" && hits="$hits tokenul-vechi"
  [ -z "$hits" ] && ok "secrete $name" || ko "secrete $name: $hits"
  n=$(git -C "$repo" log --format=%B origin/main..HEAD | grep -ci "co-authored-by: claude"); [ "$n" = 0 ] && ok "atribuire $name" || ko "atribuire Claude în $name ($n)"
done
step token-vechi scripts/verify-no-legacy-token.sh

# Manifestul public rămâne neatins; candidatul respectă Regula 35.
git diff --quiet origin/main -- docs/update.json && ok "docs/update.json public neschimbat (1.39.4 / 1.37.2)" || ko "docs/update.json modificat înainte de publicare"
python3 - "$MAC" "$WIN" <<'PY' && ok "manifest candidat (release/update.candidate.json)" || ko "manifest candidat"
import json,sys
mac,win=sys.argv[1:3]; c=json.load(open("release/update.candidate.json")); p=json.load(open("docs/update.json"))
v=lambda s: tuple(int(x) for x in s.split("."))
assert c["mac"]["version"]==mac and c["windows"]["version"]==win, "versiuni"
assert c["version"]==min(mac,win,key=v), "rădăcina = minimul platformelor (Regula 35)"
assert set(p)<=set(c) and set(p["mac"])<=set(c["mac"]) and set(p["windows"])<=set(c["windows"]), "niciun câmp public eliminat (Regula 35)"
assert f"/v{win}/" in c["windows"]["download_url"], "linkul Windows versionat"
assert "releases/latest/download" in c["mac"]["download_url"], "Mac pe latest"
PY
[ $FAIL = 0 ] && echo "REZULTAT: OK" || echo "REZULTAT: EȘEC"
exit $FAIL
