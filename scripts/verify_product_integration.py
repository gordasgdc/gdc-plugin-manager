#!/usr/bin/env python3
"""Poarta „integrare în platformă” pentru un produs: contractele care se pot valida automat.

Registrul (scripts/product-integration.json) declară ce a promis un produs; scriptul verifică local
catalogul, coperta, intrarea din „Aplicațiile mele” (doar dacă produsul o declară), pagina platformei în
RO/EN/ES și absența sumelor; cu --live verifică ce primește clientul real (catalog public, manifestul
produsului, descărcarea). Nu scanează discul și nu atinge produsele care nu sunt în registru.

    scripts/verify_product_integration.py [--live] [id ...]     # implicit: toate produsele din registru
Ieșire: o linie per verificare; cod 1 dacă o verificare pică.
"""
import hashlib
import json
import os
import re
import sys
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DOCS = os.path.join(ROOT, "docs")
LIVE = "https://gordas.dev"
PRICE = re.compile(r"(€|\bEUR\b|\blei\b|\bRON\b|\$\s?\d|\b\d+\s?(euro|usd)\b)", re.I)
fails = 0


def ok(msg):
    print("✓", msg)


def bad(msg):
    global fails
    fails += 1
    print("✗", msg)


def check(cond, msg):
    ok(msg) if cond else bad(msg)


def get(url, head=False):
    req = urllib.request.Request(url, method="HEAD" if head else "GET", headers={"User-Agent": "gdc-integration-check"})
    return urllib.request.urlopen(req, timeout=30)


def verify(p, live):
    pid = p["id"]
    print(f"== {pid}")
    cat = json.load(open(os.path.join(DOCS, "catalog.json"), encoding="utf8"))
    entry = next((a for a in cat["apps"] if a["id"] == pid), None)
    check(entry is not None, f"{pid}: intrare în catalog.apps")
    if entry is None:
        return
    check(pid not in {i.get("id") for i in cat.get("items", [])}, f"{pid}: nu e dublat în items[] (contract de plugin)")
    check(entry.get("supportedOS") == p["os"], f"{pid}: sistem {p['os']} (nu se prezintă pe alt sistem)")
    check(entry.get("url") == p["page"], f"{pid}: url pagină = {p['page']}")
    check(entry.get("downloadURL") == p["download"], f"{pid}: descărcare = {p['download']}")
    if p.get("noPricingProductID"):
        check("pricingProductID" not in entry, f"{pid}: fără pricingProductID în catalog")
    cover = entry.get("coverImage", "")
    path, _, q = cover.partition("?v=")
    f = os.path.join(DOCS, path)
    if os.path.exists(f):
        sha = hashlib.sha256(open(f, "rb").read()).hexdigest()
        check(sha.startswith(q) and len(q) >= 8, f"{pid}: coperta există și ?v= = hash ({q})")
    else:
        bad(f"{pid}: coperta lipsește: {path}")
    d = p.get("detect")
    if d:
        src = open(os.path.join(ROOT, "Sources/GDCPluginManager/MyAppsLauncher.swift"), encoding="utf8").read()
        for what, val in d.items():
            check(f'"{val}"' in src, f"{pid}: Aplicațiile mele conține {what} = {val}")
    for lang, rel in (("ro", "index.html"), ("en", "en/index.html"), ("es", "es/index.html")):
        t = open(os.path.join(DOCS, rel), encoding="utf8").read()
        check(p["name"] in t and entry["url"] in t, f"{pid}: pagina platformei {lang} îl listează")
        if p.get("noPublicPrice"):
            check(not PRICE.search(re.sub(r"<[^>]+>", " ", t)), f"{pid}: fără sume pe pagina platformei {lang}")
    if live:
        lc = json.load(get(LIVE + "/catalog.json"))
        le = next((a for a in lc["apps"] if a["id"] == pid), None)
        check(le is not None and le == entry, f"{pid}: catalogul public = cel din repo")
        m = json.load(get(p["manifest"]))
        check(isinstance(m.get("version"), str) and re.fullmatch(r"\d+\.\d+\.\d+", m["version"]) is not None, f"{pid}: manifest cu versiune șir ({m.get('version')})")
        check(isinstance(m.get("build", ""), str), f"{pid}: build șir în manifest")
        try:
            r = get(p["download"], head=True)
            check(r.status == 200, f"{pid}: descărcarea răspunde ({r.status})")
        except Exception as e:  # noqa: BLE001
            bad(f"{pid}: descărcarea nu răspunde ({e})")
        for rel in ("", "en/", "es/"):
            try:
                check(get(f"{LIVE}/{rel}", head=True).status == 200, f"{pid}: pagina publică /{rel} răspunde")
            except Exception as e:  # noqa: BLE001
                bad(f"{pid}: pagina publică /{rel} nu răspunde ({e})")


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    live = "--live" in sys.argv
    reg = json.load(open(os.path.join(ROOT, "scripts", "product-integration.json"), encoding="utf8"))
    for p in reg["products"]:
        if not args or p["id"] in args:
            verify(p, live)
    print("REZULTAT:", "OK" if fails == 0 else f"{fails} eșecuri")
    sys.exit(1 if fails else 0)


if __name__ == "__main__":
    main()
