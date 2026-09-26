#!/bin/bash
# Lot B — monitorizarea migrării clienților de pe PAT-ul GitHub vechi pe authorize-download.
# DOAR CITIRE (un singur SELECT prin Supabase Management API). Fără nume/email în ieșire;
# machine ID-urile apar doar trunchiate, cu --list.
#
# Semnale:
#   download_authorizations  → scris DOAR de clienții noi (Mac ≥1.39.4, Windows ≥1.37.2): migrare CONFIRMATĂ.
#   download_events          → scris de toți clienții la descărcare: activitate.
#   devices                  → înregistrare la onboarding (fără versiune): baza de aparate cunoscute.
# Clasificare pe fereastra de N zile (implicit 30):
#   MIGRAT (confirmat)       — are autorizare în fereastră.
#   PROBABIL VECHI (ESTIMARE)— are descărcări în fereastră, dar nicio autorizare după prima lor descărcare.
#   INACTIV (ESTIMARE)       — cunoscut, fără activitate în fereastră; versiunea nu se poate ști.
# Utilizare: scripts/migration-status.sh [zile] [--list]
set -euo pipefail
DAYS="${1:-30}"; LIST="${2:-}"
[[ "$DAYS" =~ ^[0-9]+$ ]] || { LIST="$DAYS"; DAYS=30; }
REF="jvxrclpyngdcqnbwvtfn"
TOKEN="$(security find-generic-password -s gdc-supabase-deploy -a gdc -w 2>/dev/null || true)"
[ -n "$TOKEN" ] || { echo "✗ Lipsește tokenul gdc-supabase-deploy din Keychain." >&2; exit 2; }

read -r -d '' SQL <<SQLEOF || true
with win as (select now() - interval '$DAYS days' as t0),
auth as (select machine_id, max(created_at) last_auth, min(created_at) first_auth,
                (array_agg(platform order by created_at desc))[1] platform,
                (array_agg(client_version order by created_at desc))[1] ver
         from public.download_authorizations group by machine_id),
ev as (select machine_id, max(downloaded_at) last_ev from public.download_events group by machine_id),
known as (select machine_id from public.devices union select machine_id from ev union select machine_id from auth),
cls as (
  select k.machine_id, a.platform, a.ver,
    case when a.last_auth >= (select t0 from win) then 'migrat'
         when e.last_ev >= (select t0 from win) and (a.last_auth is null or a.last_auth < e.last_ev - interval '1 day') then 'probabil_vechi'
         when e.last_ev >= (select t0 from win) then 'migrat'
         else 'inactiv' end as c,
    greatest(a.last_auth, e.last_ev) last_seen
  from known k left join auth a using (machine_id) left join ev e using (machine_id))
select json_build_object(
  'window_days', $DAYS,
  'counts', (select json_object_agg(c, n) from (select c, count(*) n from cls group by c) x),
  'versions', (select json_object_agg(coalesce(platform,'?')||' '||coalesce(ver,'?'), n)
               from (select platform, ver, count(*) n from cls where c='migrat' group by 1,2) y),
  'old_sample', (select json_agg(json_build_object('id', left(machine_id,8), 'last', to_char(last_seen,'YYYY-MM-DD')))
                 from (select * from cls where c='probabil_vechi' order by last_seen desc limit 50) z)
) as r;
SQLEOF

PAYLOAD="$(mktemp)"; trap 'rm -f "$PAYLOAD"' EXIT
python3 -c 'import json,sys;print(json.dumps({"query":sys.argv[1]}))' "$SQL" > "$PAYLOAD"
BODY="$(printf 'header = "Authorization: Bearer %s"\n' "$TOKEN" | curl -s -m 60 -w '\n%{http_code}' --config - \
  -H 'Content-Type: application/json' --data-binary @"$PAYLOAD" "https://api.supabase.com/v1/projects/$REF/database/query")"
CODE="${BODY##*$'\n'}"; BODY="${BODY%$'\n'*}"
if [ "$CODE" != 200 ] && [ "$CODE" != 201 ]; then
  echo "✗ Interogarea a eșuat (HTTP $CODE): $(echo "$BODY" | head -c 200)"
  echo "  Dacă e 401/403: tokenul de deploy nu are drept de citire în baza de date — rulează interogarea din Supabase → SQL Editor (textul e în acest script)."
  exit 1
fi
python3 - "$BODY" "$LIST" <<'PY'
import json,sys
rows=json.loads(sys.argv[1]); r=rows[0]["r"]; r=json.loads(r) if isinstance(r,str) else r
c=r.get("counts") or {}
print(f"Migrare PAT → authorize-download · fereastră {r['window_days']} zile · {sum(c.values())} aparate cunoscute")
print(f"  MIGRAT (confirmat)        : {c.get('migrat',0)}")
print(f"  PROBABIL VECHI (ESTIMARE) : {c.get('probabil_vechi',0)}")
print(f"  INACTIV (ESTIMARE)        : {c.get('inactiv',0)}  — versiune necunoscută; un client vechi inactiv poate reveni oricând")
v=r.get("versions") or {}
if v: print("  Versiuni migrate active   : " + ", ".join(f"{k}={n}" for k,n in sorted(v.items())))
if sys.argv[2]=="--list":
    for o in r.get("old_sample") or []: print(f"    probabil vechi: {o['id']}…  ultima activitate {o['last']}")
print("Revocarea PAT-ului e sigură pentru clienții ACTIVI când PROBABIL VECHI = 0; inactivii vechi vor primi eroare la descărcare până la actualizare.")
PY
