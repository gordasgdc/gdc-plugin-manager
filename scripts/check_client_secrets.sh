#!/usr/bin/env bash
# S1: clientul distribuit nu trebuie să conțină credentiale. Verifică un binar,
# un .app sau un .pkg/.dmg extras. Nu afișează valorile găsite, doar numărul.
#   scripts/check_client_secrets.sh <cale> [<cale>…]
# Cod de ieșire: 0 = curat, 1 = credential găsit, 2 = utilizare greșită.
set -uo pipefail
[ $# -ge 1 ] || { echo "utilizare: $0 <binar|.app|folder> …" >&2; exit 2; }
patterns='github_pat_[A-Za-z0-9_]{20,}|gh[pousr]_[A-Za-z0-9]{30,}|-----BEGIN [A-Z ]*PRIVATE KEY|service_role'
found=0
for target in "$@"; do
  [ -e "$target" ] || { echo "✗ lipsește: $target" >&2; exit 2; }
  while IFS= read -r -d '' f; do
    n=$( { strings -a "$f" 2>/dev/null || true; } | grep -cE "$patterns" || true)
    if [ "${n:-0}" -gt 0 ]; then
      echo "✗ $f: $n potrivire(i) de credential (valorile nu se afișează)"
      found=1
    fi
  done < <(find "$target" -type f -print0)
done
[ $found -eq 0 ] && echo "✓ fără credentiale în: $*"
exit $found
