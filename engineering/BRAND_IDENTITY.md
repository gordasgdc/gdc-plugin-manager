# Identitatea vizuală a platformei GDC Plugin Manager

**Sursa autoritară:** `AppIcon.icns` din rădăcina repo-ului (aceeași cu cea distribuită în aplicația `GDCPluginManager.app`): roata de culori cu centru alb și „GDC".
`make_icon.swift` și puzzle-ul vechi sunt ÎNVECHITE: nu se folosesc pentru site.

## Regula de reutilizare
- Logo-ul din antet/subsol, favicon-ul, apple-touch-icon, iconițele PWA și previzualizările sociale (og:image/twitter:image) provin din `AppIcon.icns`, prin `scripts/build_brand_assets.py` (nu se redesenează, nu se generează alt logo; doar adaptări tehnice de dimensiune și margine).
- Fișierele derivate: `docs/icons/*`, `docs/favicon.ico`, `docs/favicon-32.png`, `docs/apple-touch-icon.png`. Se referă cu `?v=<8 hex sha256 al icon-512.png>` (calculat în `scripts/build_platform_site.py`); la schimbare se ridică și `CACHE_VERSION` din `docs/sw.js`.
- Identitatea platformei rămâne separată de cea a produselor (SADROG, Foto Asist etc.): paginile și copertele produselor nu se modifică.
- Iconița aplicației NU se schimbă pentru a se potrivi cu pagina; dacă o schimbă cineva, se schimbă mai întâi aplicația, apoi se rulează `scripts/build_brand_assets.py`.

## Verificare
```bash
python3 scripts/build_brand_assets.py --check
python3 scripts/build_platform_site.py --check
```
