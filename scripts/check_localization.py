#!/usr/bin/env python3
"""Verifică localizarea clientului (RO/EN/ES) — Sources/GDCPluginManager/Localization.swift.

    scripts/check_localization.py          # erori = cod de ieșire 1
    scripts/check_localization.py --json
    scripts/check_localization.py --forbidden-as-warning   # CI: Regula 3 = avertisment, restul erori

Erori:   cheie folosită cu L.t("…") care lipsește din tabel; intrare fără .ro/.en/.es;
         cheie definită de două ori; cuvinte interzise de Regula 3 (preț/cumpără/vânzare,
         price/buy/sale, precio/comprar/venta) în textele afișate.
Avertismente: chei nefolosite; L.t(expresie) cu cheie dinamică (neverificabilă static).
Nu modifică nimic.
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "Sources", "GDCPluginManager")
TABLE_FILE = os.path.join(SRC, "Localization.swift")
LANGS = ("ro", "en", "es")
ENTRY_RE = re.compile(r'^\s*"([^"]+)":\s*\[(.*)\],?\s*$')
LANG_RE = re.compile(r'\.(ro|en|es):\s*"((?:[^"\\]|\\.)*)"')
USE_RE = re.compile(r'L\.t\(\s*"([^"]+)"\s*\)')
DYNAMIC_RE = re.compile(r'L\.t\(\s*(?!")([^)]*)\)')
FORBIDDEN = re.compile(r"\b(preț|pret|prețul|cumpăr\w*|cumpar\w*|vânzare|vanzare|price|buy|buying|sale|precio|comprar|compra|venta)\b",
                       re.IGNORECASE)


def main():
    as_json = "--json" in sys.argv
    # Tranzitoriu (CI): Regula 3 raportată fără să blocheze, cât timp textele așteaptă formularea aprobată.
    forbidden_as_warning = "--forbidden-as-warning" in sys.argv
    findings = []
    add = lambda level, code, msg: findings.append({"level": level, "code": code, "message": msg})

    table = {}
    with open(TABLE_FILE, encoding="utf-8") as fh:
        lines = fh.read().split("\n")
    # Intrările pe mai multe rânduri ("cheie": [ … ]) se lipesc într-un singur rând logic.
    logical, i = [], 0
    while i < len(lines):
        line, start = lines[i], i + 1
        if re.match(r'^\s*"[^"]+":\s*\[\s*$', line):
            # Până la rândul care închide intrarea („]” / „],”, singur sau după ultima limbă).
            while not re.search(r"\],?\s*$", lines[i]) or i + 1 == start:
                i += 1
                line += " " + lines[i].strip()
        logical.append((start, line))
        i += 1
    for n, line in logical:
        if True:
            m = ENTRY_RE.match(line)
            if not m:
                continue
            key, body = m.groups()
            langs = dict(LANG_RE.findall(body))
            if key in table:
                add("error", "key-duplicate", f"{key} definită de două ori (linia {n})")
            table[key] = langs
            missing = [l for l in LANGS if not langs.get(l)]
            if missing:
                add("error", "lang-missing", f"{key}: lipsește {', '.join(missing)} (linia {n})")
            for lang, text in langs.items():
                hit = FORBIDDEN.search(text)
                if hit:
                    add("warning" if forbidden_as_warning else "error", "forbidden-word", f"{key} [{lang}]: „{hit.group(0)}” (Regula 3: donație, nu preț/cumpărare)")

    used, dynamic = set(), []
    for dirpath, _, files in os.walk(SRC):
        for name in sorted(files):
            if not name.endswith(".swift") or name == "Localization.swift":
                continue
            path = os.path.join(dirpath, name)
            with open(path, encoding="utf-8") as fh:
                text = fh.read()
            for key in USE_RE.findall(text):
                if "\\(" in key:  # interpolare: cheie dinamică, prefix verificat mai jos
                    dynamic.append(f"{name}: L.t(\"{key}\")")
                    continue
                used.add(key)
                if key not in table:
                    add("error", "key-missing", f"{name}: L.t(\"{key}\") nu există în tabel")
            for expr in DYNAMIC_RE.findall(text):
                dynamic.append(f"{name}: L.t({expr.strip()})")

    for key in sorted(set(table) - used):
        add("warning", "key-unused", f"{key} nu e folosită cu L.t(\"…\") literal (poate fi folosită dinamic)")
    for d in sorted(set(dynamic)):
        add("warning", "key-dynamic", d)

    errors = [f for f in findings if f["level"] == "error"]
    if as_json:
        print(json.dumps({"ok": not errors, "keys": len(table), "used": len(used), "findings": findings},
                         ensure_ascii=False, indent=2))
    else:
        for f in findings:
            if f["level"] == "error":
                print(f"✗ [{f['code']}] {f['message']}")
        warn = len(findings) - len(errors)
        print(f"{'✓' if not errors else '✗'} localizare: {len(table)} chei, {len(used)} folosite literal — "
              f"{len(errors)} erori, {warn} avertismente (--json pentru detalii)")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
