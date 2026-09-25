#!/usr/bin/env bash
# Deploy + verificare `authorize-download` prin Supabase Management API (fără CLI).
# Tokenul de acces Supabase se citește din Keychain (serviciul `gdc-supabase-deploy`), nu se afișează și nu apare
# în argumentele proceselor (curl îl primește prin --config de pe stdin).
#   scripts/deploy_authorize_download.sh check     # doar citiri: funcții, secrete (nume), tabel
#   scripts/deploy_authorize_download.sh deploy    # ⚠️ publică funcția în proiectul de producție
# Permisiuni necesare tokenului (docs Supabase, tabelul de endpoint-uri):
#   Edge Functions: Read-write · Edge Function Secrets: Read · Database: Read · Project Settings: Read
set -euo pipefail
REF="jvxrclpyngdcqnbwvtfn"
API="https://api.supabase.com/v1/projects/$REF"
FN_DIR="$(cd "$(dirname "$0")/.." && pwd)/supabase/functions/authorize-download"
MODE="${1:-check}"

TOKEN="$(security find-generic-password -s gdc-supabase-deploy -a gdc -w 2>/dev/null || true)"
[ -n "$TOKEN" ] || { echo "✗ Nu găsesc tokenul în Keychain (serviciul gdc-supabase-deploy). Vezi DEPLOY_AUTHORIZE_DOWNLOAD.md, Etapa F." >&2; exit 2; }

api() { # api METHOD PATH [curl args…] → corp în $BODY, cod în $CODE
  local method="$1" path="$2"; shift 2
  local out; out="$(mktemp)"
  CODE="$(printf 'header = "Authorization: Bearer %s"\n' "$TOKEN" | curl -s -m 60 -o "$out" -w '%{http_code}' -X "$method" --config - "$@" "$API$path")"
  BODY="$(cat "$out")"; rm -f "$out"
}
msg() { python3 -c 'import json,sys
try: d=json.loads(sys.argv[1]); print(d.get("message") or d.get("error") or str(d)[:160]) if isinstance(d,dict) else print(str(d)[:160])
except Exception: print(sys.argv[1][:160])' "$BODY"; }

echo "── verificări (citire)"
api GET /functions
if [ "$CODE" = 200 ]; then echo "✓ funcții: $(python3 -c 'import json,sys;print([f["slug"]+" v"+str(f.get("version")) for f in json.loads(sys.argv[1])])' "$BODY")"; else echo "✗ GET functions: HTTP $CODE — $(msg)"; fi
api GET /secrets
if [ "$CODE" = 200 ]; then
  has=$(python3 -c 'import json,sys;print(any(s.get("name")=="GITHUB_READ_TOKEN" for s in json.loads(sys.argv[1])))' "$BODY")
  echo "$([ "$has" = True ] && echo ✓ || echo ✗) secretul GITHUB_READ_TOKEN există: $has (valoarea nu se citește)"
else echo "✗ GET secrets: HTTP $CODE — $(msg)"; fi
api POST /database/query -H 'Content-Type: application/json' \
  -d '{"query":"select c.relrowsecurity as rls, (select count(*) from public.download_authorizations) as rows from pg_class c where c.oid = '"'"'public.download_authorizations'"'"'::regclass"}'
if [ "$CODE" = 200 ] || [ "$CODE" = 201 ]; then echo "✓ tabel download_authorizations: $BODY"; else echo "✗ query tabel: HTTP $CODE — $(msg)"; fi

[ "$MODE" = deploy ] || exit 0

echo "── ⚠️ deploy authorize-download în $REF"
meta='{"name":"authorize-download","entrypoint_path":"index.ts","verify_jwt":true}'
api POST "/functions/deploy?slug=authorize-download" \
  -F "metadata=$meta;type=application/json" \
  -F "file=@$FN_DIR/index.ts;filename=index.ts;type=application/typescript" \
  -F "file=@$FN_DIR/core.ts;filename=core.ts;type=application/typescript" \
  -F "file=@$FN_DIR/license.ts;filename=license.ts;type=application/typescript"
if [ "$CODE" = 200 ] || [ "$CODE" = 201 ]; then
  echo "✓ deploy: $(python3 -c 'import json,sys;d=json.loads(sys.argv[1]);print(d.get("slug"),"v"+str(d.get("version")),d.get("status"),"verify_jwt="+str(d.get("verify_jwt")))' "$BODY")"
else
  echo "✗ deploy: HTTP $CODE — $(msg)"; exit 1
fi
