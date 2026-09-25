#!/usr/bin/env bash
# S1: clientul distribuit nu trebuie să conțină credentiale. Verifică binare, .app,
# DLL-uri .NET (literale UTF-16), foldere extrase din .pkg/.dmg/installer.
# Nu afișează valorile găsite, doar numărul.
#   scripts/check_client_secrets.sh <cale> [<cale>…]
# Cod de ieșire: 0 = curat, 1 = credential găsit, 2 = utilizare greșită.
set -uo pipefail
[ $# -ge 1 ] || { echo "utilizare: $0 <binar|.app|folder> …" >&2; exit 2; }
exec python3 - "$@" <<'PY'
import os, re, sys
pattern = re.compile(rb"github_pat_[A-Za-z0-9_]{20,}|gh[pousr]_[A-Za-z0-9]{30,}|-----BEGIN [A-Z ]*PRIVATE KEY|service_role")
def encodings(data):
    yield data                                   # ASCII / UTF-8
    for off in (0, 1):                           # UTF-16LE (literale .NET), ambele alinieri
        yield data[off::2]
found = 0
for target in sys.argv[1:]:
    if not os.path.exists(target):
        print(f"✗ lipsește: {target}", file=sys.stderr); sys.exit(2)
    files = [target] if os.path.isfile(target) else [os.path.join(d, f) for d, _, fs in os.walk(target) for f in fs]
    for path in files:
        try:
            with open(path, "rb") as fh: data = fh.read()
        except OSError:
            continue
        hits = sum(len(pattern.findall(view)) for view in encodings(data))
        if hits:
            print(f"✗ {path}: {hits} potrivire(i) de credential (valorile nu se afișează)"); found = 1
if not found:
    print("✓ fără credentiale în: " + " ".join(sys.argv[1:]))
sys.exit(found)
PY
