#!/usr/bin/env python3
"""Identitatea vizuală a platformei = iconița aplicației GDC Plugin Manager (AppIcon.icns din rădăcina repo-ului,
identică cu cea din aplicația distribuită). Acest script NU desenează nimic: extrage mărimile din .icns și produce
reprezentările tehnice ale site-ului (favicon, apple-touch-icon, iconițe PWA, logo pentru antet/footer, previzualizare socială).
Singurele adaptări permise: redimensionare, spațiere (padding) și fundal opac unde formatul îl cere (apple-touch, maskable).

    scripts/build_brand_assets.py            # scrie fișierele din docs/
    scripts/build_brand_assets.py --check    # iese 1 dacă fișierele de pe disc diferă de ce s-ar genera
"""
import hashlib
import io
import os
import subprocess
import sys
import tempfile

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DOCS = os.path.join(ROOT, "docs")
DARK = (20, 22, 26, 255)  # #14161A — fundal opac doar pentru apple-touch/maskable


def load_icns():
    with tempfile.TemporaryDirectory() as t:
        subprocess.check_call(["iconutil", "-c", "iconset", os.path.join(ROOT, "AppIcon.icns"), "-o", os.path.join(t, "a.iconset")])
        g = lambda n: Image.open(os.path.join(t, "a.iconset", n)).convert("RGBA").copy()  # noqa: E731
        return {"1024": g("icon_512x512@2x.png"), "128": g("icon_128x128.png"), "32": g("icon_32x32.png"), "16": g("icon_16x16.png")}


def png(im):
    b = io.BytesIO()
    im.save(b, "PNG", optimize=True)
    return b.getvalue()


def on_dark(master, size, scale):
    bg = Image.new("RGBA", (size, size), DARK)
    d = round(size * scale)
    bg.alpha_composite(master.resize((d, d), Image.LANCZOS), ((size - d) // 2, (size - d) // 2))
    return bg


def build():
    s = load_icns()
    m = s["1024"]
    out = {
        "icons/icon-512.png": png(m.resize((512, 512), Image.LANCZOS)),
        "icons/icon-192.png": png(m.resize((192, 192), Image.LANCZOS)),
        "icons/icon-maskable-512.png": png(on_dark(m, 512, 0.7)),
        "icons/icon-maskable-192.png": png(on_dark(m, 192, 0.7)),
        "apple-touch-icon.png": png(on_dark(m, 180, 0.9)),
        "favicon-32.png": png(s["32"]),
    }
    ico = io.BytesIO()
    s["128"].resize((48, 48), Image.LANCZOS).save(ico, "ICO", sizes=[(16, 16), (32, 32), (48, 48)], append_images=[s["16"], s["32"]])
    out["favicon.ico"] = ico.getvalue()
    return out


def version(files):
    return hashlib.sha256(files["icons/icon-512.png"]).hexdigest()[:8]


if __name__ == "__main__":
    files = build()
    bad = 0
    for rel, data in files.items():
        p = os.path.join(DOCS, rel)
        if "--check" in sys.argv:
            if not os.path.exists(p) or open(p, "rb").read() != data:
                print("DIFERĂ:", rel); bad = 1
        else:
            open(p, "wb").write(data); print("scris", rel, len(data))
    v = version(files)
    if "--check" in sys.argv:
        # paginile platformei trebuie să refere logo/favicon cu versiunea reală, fără șabloane nerezolvate
        for rel in ("index.html", "en/index.html", "es/index.html"):
            t = open(os.path.join(DOCS, rel), encoding="utf8").read()
            for need in ("/favicon.ico?v=" + v, "/favicon-32.png?v=" + v, "/apple-touch-icon.png?v=" + v, "/icons/icon-192.png?v=" + v, "/icons/icon-512.png?v=" + v):
                if need not in t:
                    print("LIPSEȘTE în", rel + ":", need); bad = 1
            if "{bv}" in t:
                print("ȘABLON nerezolvat în", rel); bad = 1
    print("versiune-brand", v)
    sys.exit(bad)
