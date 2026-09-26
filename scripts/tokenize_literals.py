#!/usr/bin/env python3
"""Înlocuiește valorile vizuale literale cu tokenii GDCTokens care au EXACT aceeași valoare
(zero schimbare vizuală). Valorile fără token echivalent rămân literale și sunt numărate de
scripts/audit-design-literals.sh. Utilizare: scripts/tokenize_literals.py <dir>... [--dry-run]"""
import re, sys, pathlib
SPACE = {"2": "xxs", "4": "xs", "8": "s", "12": "m", "16": "l", "24": "xl", "32": "xxl", "40": "page"}
RADIUS = {"6": "badge", "8": "control", "10": "inset", "12": "card", "16": "panel"}
COLOR = {"red": "error", "orange": "warning", "green": "success", "blue": "info"}
S = lambda v: f"GDCTokens.Space.{SPACE[v]}"
def sp(m): return m.group(1) + S(m.group(2)) if m.group(2) in SPACE else m.group(0)
RULES = [
    (re.compile(r"(\.padding\((?:\.[a-zA-Z]+, )?)(\d+)(?=\))"), sp),
    (re.compile(r"(\bspacing: )(\d+)\b(?!\.)"), sp),
    (re.compile(r"(cornerRadius: ?)(\d+)\b(?!\.)"), lambda m: m.group(1) + f"GDCTokens.Radius.{RADIUS[m.group(2)]}" if m.group(2) in RADIUS else m.group(0)),
    (re.compile(r"(\.cornerRadius\()(\d+)(?=\))"), lambda m: m.group(1) + f"GDCTokens.Radius.{RADIUS[m.group(2)]}" if m.group(2) in RADIUS else m.group(0)),
    (re.compile(r"(\.(?:foregroundStyle|foregroundColor|tint|fill)\()\.(red|orange|green|blue)(?=\))"), lambda m: m.group(1) + f"GDCTokens.Palette.{COLOR[m.group(2)]}"),
    (re.compile(r"\bColor\.(red|orange|green|blue)\b"), lambda m: f"GDCTokens.Palette.{COLOR[m.group(1)]}"),
]
GRID14 = (re.compile(r"(\bspacing: )14\b(?!\.)"), lambda m: m.group(1) + "GDCTokens.Space.grid")
dry = "--dry-run" in sys.argv
total = 0
for root in [a for a in sys.argv[1:] if not a.startswith("--")]:
    for p in sorted(pathlib.Path(root).rglob("*.swift")):
        if "DesignSystem" in p.parts: continue
        src = p.read_text(); out = []
        for line in src.split("\n"):
            if line.lstrip().startswith("//"): out.append(line); continue
            new = line
            for rx, fn in RULES: new = rx.sub(fn, new)
            if "Grid" in new: new = GRID14[0].sub(GRID14[1], new)
            out.append(new)
        res = "\n".join(out)
        if res != src:
            n = sum(a != b for a, b in zip(src.split("\n"), out)); total += n
            if "import GDCPluginManagerCore" not in res:
                res = res.replace("import SwiftUI\n", "import SwiftUI\nimport GDCPluginManagerCore\n", 1)
            if not dry: p.write_text(res)
            print(f"{n:4d}  {p}")
print(f"rânduri modificate: {total}{' (dry-run)' if dry else ''}")
