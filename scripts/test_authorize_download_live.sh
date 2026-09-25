#!/usr/bin/env bash
# Teste live pentru `authorize-download` deployată. Folosește doar cheia publică anon (din SupabaseConfig.swift)
# și catalogul public; nu citește niciun secret. Rezultate: PASS/FAIL per caz; cod de ieșire 1 la orice FAIL.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
URL="https://jvxrclpyngdcqnbwvtfn.supabase.co/functions/v1/authorize-download"
ANON="$(grep -oE 'eyJ[A-Za-z0-9_.-]+' "$ROOT/Sources/GDCPluginManagerCore/SupabaseConfig.swift" | head -1)"
exec python3 - "$URL" "$ANON" <<'PY'
import hashlib, json, sys, urllib.request, urllib.error
url, anon = sys.argv[1], sys.argv[2]
catalog = json.load(urllib.request.urlopen("https://gordas.dev/catalog.json", timeout=30))
MACHINE = "AAAAAAAAAA"  # ID de test, format valid (10 caractere Base32)
fails = 0

def call(body, raw=False):
    data = body if raw else json.dumps(body).encode()
    req = urllib.request.Request(url, data=data, method="POST", headers={
        "Content-Type": "application/json", "apikey": anon, "Authorization": f"Bearer {anon}"})
    try:
        with urllib.request.urlopen(req, timeout=30) as r: return r.status, json.loads(r.read() or b"{}")
    except urllib.error.HTTPError as e:
        try: return e.code, json.loads(e.read() or b"{}")
        except Exception: return e.code, {}

def check(name, cond, detail=""):
    global fails
    print(("PASS " if cond else "FAIL ") + name + (f" — {detail}" if detail and not cond else ""))
    fails += 0 if cond else 1

def get(u):
    try:
        with urllib.request.urlopen(u, timeout=60) as r: return r.status, r.read()
    except urllib.error.HTTPError as e: return e.code, b""

# Resurse gratuite reale, cu fișiere (formă nouă sau legacy).
free = []
for key in ("items", "scriptItems", "downloadableResources", "pdfResources", "scriptResources"):
    for x in catalog.get(key) or []:
        files = [(f["path"], f.get("sha256")) for f in x.get("files") or []]
        if x.get("filePath"): files.append((x["filePath"], x.get("fileSHA256")))
        if x.get("isFree") and files: free.append((x["id"], files))
check("catalogul public are resurse gratuite de test", bool(free))
if not free: sys.exit(1)

s, b = call(b"nu e json", raw=True);                         check("JSON invalid → 400 malformed_request", (s, b.get("error")) == (400, "malformed_request"), f"{s} {b}")
s, b = call({"productID": "x", "path": "../x", "machineID": MACHINE, "platform": "mac"}); check("cale cu .. → 400", s == 400, f"{s} {b}")
s, b = call({"productID": "nu-exista-gdc", "path": "nu-exista-gdc/a", "machineID": MACHINE, "platform": "mac"}); check("produs inexistent → 404 unknown_product", (s, b.get("error")) == (404, "unknown_product"), f"{s} {b}")
pid, files = free[0]
s, b = call({"productID": pid, "path": f"{pid}/nu-exista.bin", "machineID": MACHINE, "platform": "mac"}); check("fișier străin produsului → 403 unauthorized_artifact", (s, b.get("error")) == (403, "unauthorized_artifact"), f"{s} {b}")

# Autorizare validă + descărcare + SHA-256.
path, sha = files[0]
s, b = call({"productID": pid, "path": path, "machineID": MACHINE, "platform": "mac", "clientVersion": "live-test"})
check(f"resursă gratuită reală ({pid}) → 200", s == 200, f"{s} {b}")
if s == 200:
    check("răspunsul nu conține alte câmpuri decât contractul", set(b) <= {"url","productID","path","sha256","size","issuedAt","useWithinSeconds"}, str(sorted(b)))
    check("URL https, fără credential GitHub în răspuns", b["url"].startswith("https://") and "github_pat_" not in json.dumps(b))
    st, data = get(b["url"])
    check("URL temporar descarcă fișierul (200)", st == 200, str(st))
    if st == 200 and sha:
        check("SHA-256 descărcat = catalog", hashlib.sha256(data).hexdigest() == sha.lower())
    # Același token temporar, alt fișier: nu trebuie să funcționeze.
    others = [(p, h) for (i, fs) in free for (p, h) in fs if p != path]
    if others and "?" in b["url"]:
        base = b["url"].split("?", 1)
        other_url = base[0].rsplit("/", len(path.split("/")))[0] + "/" + urllib.request.quote(others[0][0]) + "?" + base[1]
        st2, _ = get(other_url)
        check("URL-ul unui fișier NU deschide alt fișier", st2 in (401, 403, 404), str(st2))
print(f"{'FAIL' if fails else 'PASS'}: {fails} eșec(uri)")
sys.exit(1 if fails else 0)
PY
