# GDC Design System (macOS)

Stare: sistemul e DEFINIT (Faza 2, 2026-09-25). Tokenii există în cod
(`Sources/GDCPluginManagerCore/DesignSystem/GDCDesignTokens.swift`); singurul consumator de până acum
e `glassCardBackground()` (aceleași valori, aspect neschimbat). Ecranele se migrează în faza de redesign.

```
GDCTokens (Core)  →  GDC UI Components  →  Screens  →  Product experience
```

## Direcția vizuală

Fundație nativă Apple + identitate GDC + prezentare premium. Nu glassmorphism generic.

- **Materialul are un rol, nu e decor.** Translucid doar ce plutește peste conținut: carduri în grilă,
  bannere, popover-uri, bara laterală (nativ). Tabele, formulare, pagini de setări și Furnizor = suprafețe opace.
- **Ierarhia vine din tipografie și spațiu**, nu din chenare, umbre sau gradienți.
- **Accentul GDC (amber/cupru)** marchează doar acțiunea principală și selecția. Nu colorează text de citit.
- **Densitate:** client = aerisit, bazat pe artwork. Furnizor = dens, bazat pe tabele (vezi la final).

## Tokeni

| Categorie | Trepte | Note |
|---|---|---|
| Spațiu | `xxs 2 · xs 4 · s 8 · m 12 · l 16 · xl 24 · xxl 32 · page 40 · grid 14` | valorile dominante azi |
| Rază | `badge 6 · control 8 · inset 10 · card 12 · panel 16` | concentrice: interior = o treaptă sub container |
| Tipografie | `display · pageTitle · sectionTitle · cardTitle · body · secondary · metadata · caption · label · numeric · code` | semantice, Dynamic Type (Regula 24); `numeric` = cifre monospațiate |
| Culoare | `accent · textPrimary/Secondary/Tertiary · disabled · selection · separator · windowBackground · surface · success · warning · error · destructive · info` | semantice de sistem; accentul are variantă Light/Dark |
| Suprafață | `card = ultraThin · floating = regular · bar` | vezi „Materialul are un rol” |
| Bordură | `hairline 1 · cardColor · focusWidth 2` | |
| Elevație | `none · card · hover · floating` | nicio umbră arbitrară |
| Mișcare | `fast 0.12 · standard 0.2 · emphasized 0.32` | `Motion.animation(_:reduceMotion:)` întoarce `nil` la Reduce Motion |
| Dimensiuni | `minHitTarget 28 · cardMinWidth 260 · cardArtworkHeight 140 · sidebarMinWidth 220 · icon S/M/L` | |

**Regulă:** în codul nou sau atins, orice valoare vizuală literală repetată e defect de review.
Excepții documentate local: desene, măști, dimensiuni de artwork impuse de sursă.

## Componente (de construit în faza de redesign, în ordinea asta)

1. `StatusBadge(kind:)` — free/trial/promo/donation/installed/update/incompatible; culoare + iconiță + text (niciodată doar culoare).
2. `GDCButtonStyle(.primary/.secondary/.destructive/.plain)` — stări hover/pressed/disabled/loading; `minHitTarget`.
3. `ContentCard` — artwork, titlu, metadate, descriere pliabilă, acțiuni; hover = `Elevation.hover`, fără mărire de scară.
4. `ProductCard` — `ContentCard` + `ProductActionState` (vezi UI_ARCHITECTURE.md §3).
5. `StateView(.loading/.empty/.error/.offline)` — titlu, explicație, acțiune (Reîncearcă/Deschide setările).
6. `Banner(kind:)` — update, dependențe, eșec de verificare, ofertă; un singur stil, închidere consistentă.
7. `ProgressRow` — progres determinat/nedeterminat, anulare.

## Stări care trebuie proiectate pentru cardul de produs

| Stare | Ce comunică | Acțiune principală |
|---|---|---|
| NORMAL / NOT INSTALLED | tip, versiune, platformă, gratuit/probă/donație | Instalează / Donează |
| DOWNLOADING | progres (%), dimensiune dacă e cunoscută | Anulează |
| PAUSED | progres păstrat | Reia |
| INSTALLED | versiunea instalată | Elimină (secundar) |
| UPDATE AVAILABLE | instalată → nouă | Actualizează |
| UPDATING | progres | — |
| FAILED | motiv pe înțelesul clientului (detaliul tehnic în `DiagnosticLog`) | Reîncearcă |
| OFFLINE | catalog din cache, acțiunile de rețea dezactivate | — |
| LICENSE REQUIRED / INVALID | de ce, ce face clientul | Activează licența |
| INCOMPATIBLE | platforma cerută | — |

Stări de ecran: LOADING, EMPTY, CATALOG ERROR (cu Reîncearcă), OFFLINE.

## Accesibilitate (parte din sistem)
Contrast ≥ 4.5:1 pentru text (accentul Light e mai închis tocmai pentru asta); focus vizibil (`focusWidth`);
etichete VoiceOver pe butoane doar-iconiță; `minHitTarget`; Reduce Motion prin `Motion.animation`; Dynamic Type prin `Typography`.

## Furnizor — aceeași identitate, altă UX
Împarte tokenii, NU layout-ul clientului: tabele native (`Table`) + inspector lateral, suprafețe opace,
tipografie `metadata`/`numeric` pentru date, acțiuni distructive mereu cu confirmare și `Palette.destructive`,
fără artwork mare, fără material pe tabele. Redesign-ul Furnizor/CRM e o fază separată (Faza 5).
