#!/bin/bash
# Pornește Furnizorul într-un mediu explicit și VERIFICĂ mediul procesului pornit.
#   scripts/furnizor-env.sh staging      # mediu de test (repo-uri *-staging, banner roșu)
#   scripts/furnizor-env.sh production   # înapoi la producție
#
# De ce: `open --env` NU schimbă mediul unei instanțe deja pornite (LaunchServices o readuce în față),
# deci o instanță de producție deschisă ar putea fi confundată cu staging. Scriptul:
#   1. închide GRAȚIOS orice instanță (echivalent ⌘Q; niciodată forțat) și se oprește dacă nu se închide;
#   2. pornește aplicația cu mediul cerut;
#   3. citește variabila din mediul procesului pornit și eșuează dacă nu corespunde.
# După pornire, verificarea vizuală rămâne obligatorie: în staging bannerul roșu
# „MEDIU DE TEST — STAGING” trebuie să fie vizibil sus, în fereastră.
set -euo pipefail

BUNDLE_ID="com.gordasgdc.pluginmanager.furnizor"
PROC_PATTERN="GDC Plugin Manager Furnizor.app/Contents/MacOS/GDCPluginManagerFurnizor"
ENV_NAME="${1:-}"
case "$ENV_NAME" in
    staging|production) ;;
    *) echo "Utilizare: $0 staging|production" >&2; exit 2 ;;
esac

running_pid() { pgrep -f "$PROC_PATTERN" | head -1 || true; }

if [ -n "$(running_pid)" ]; then
    echo "==> Furnizorul rulează (PID $(running_pid)) — îl închid grațios (⌘Q)…"
    osascript -e "tell application id \"$BUNDLE_ID\" to quit" >/dev/null 2>&1 || true
    for _ in $(seq 1 15); do [ -z "$(running_pid)" ] && break; sleep 1; done
    if [ -n "$(running_pid)" ]; then
        echo "EROARE: Furnizorul nu s-a închis (poate are o fereastră de confirmare deschisă)." >&2
        echo "Închide-l manual (⌘Q), apoi rulează din nou scriptul. Nu l-am oprit forțat." >&2
        exit 1
    fi
fi

echo "==> Pornesc Furnizorul în mediul: $ENV_NAME"
if [ "$ENV_NAME" = staging ]; then
    open -b "$BUNDLE_ID" --env GDC_FURNIZOR_ENV=staging
else
    open -b "$BUNDLE_ID"
fi

PID=""
for _ in $(seq 1 15); do PID="$(running_pid)"; [ -n "$PID" ] && break; sleep 1; done
[ -n "$PID" ] || { echo "EROARE: Furnizorul nu a pornit." >&2; exit 1; }

# Mediul REAL al procesului (ps eww afișează variabilele proceselor proprii).
ACTUAL="production"
if ps eww -o command= -p "$PID" | tr ' ' '\n' | grep -qx "GDC_FURNIZOR_ENV=staging"; then ACTUAL="staging"; fi

if [ "$ACTUAL" != "$ENV_NAME" ]; then
    echo "EROARE: procesul pornit (PID $PID) rulează în „$ACTUAL”, nu în „$ENV_NAME”. Îl închid grațios." >&2
    osascript -e "tell application id \"$BUNDLE_ID\" to quit" >/dev/null 2>&1 || true
    exit 1
fi
echo "✓ Furnizor (PID $PID) rulează în: $ACTUAL"
[ "$ACTUAL" = staging ] && echo "  Verifică vizual: bannerul roșu „MEDIU DE TEST — STAGING” trebuie să fie vizibil sus."
exit 0
