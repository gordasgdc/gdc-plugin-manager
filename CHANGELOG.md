# Changelog — GDC Plugin Manager

## Client v1.19.8 (2026-08-29) — Fix retry filigran (404 tranzitoriu de CDN)

- Fetch-ul de filigran nu reîncerca la un 404 tranzitoriu de CDN (bug real:
  `URLSession` nu aruncă pe status HTTP de eroare, doar pe eșec de rețea).
  Acum verifică statusul explicit și reîncearcă corect.
- Bump doar de sincronizare cu Windows (fix suplimentar de logging acolo).

## Client v1.19.2 (2026-08-29) — Release final, paritate Windows completă

- **Fix critic**: filigranul sezonier nu se încărca NICIODATĂ — `.task`
  atașat greșit pe un container gol la primul randaj. Reparat, verificat
  direct (rulat din Terminal cu print-uri de diagnostic).
- Iconițe sociale COLORATE de brand (Facebook/YouTube/Instagram/TikTok/
  LinkedIn), nu SF Symbols alb-negru. Tooltips pe butonul YouTube + toate
  iconițele sociale.
- Fix poziționare filigran: padding negativ care tăia imaginea din colț →
  pozitiv, mărit apoi la 48px (de la 24px) la cerere.
- Fix sidebar: profilul nu mai suprapune meniul la redimensionare rapidă.
- Setare nouă "Mărime Text" (Mic/Normal/Mare/Foarte mare), în Preferences.
- Cele 7 preseturi de filigran predefinite au trecut de la SVG (text
  invizibil — bug real ImageIO găsit azi) la PNG randat corect.
- Intensitate (opacitate) reglabilă per filigran, din Furnizor.

## Furnizor v1.16.1 (2026-08-29)

- Fix: formularul de Produse nu se golea după publicare (trebuia să
  închizi și să redeschizi aplicația pentru al doilea produs).
- Fix: fiecare control al filigranului (Activ/Poziție/Intensitate/
  Perioadă) publica INSTANT, la fiecare atingere — acum totul e local,
  publicat printr-un buton explicit "Trimite modificările".
- Preseturi PNG (nu SVG) — vezi mai sus.

**TODO paritate Windows**: acum COMPLETĂ — vezi CHANGELOG.md din
`GDCPluginManagerWin`, v1.19.2.

## Client v1.16.0 + Furnizor v1.15.0 (2026-08-29) — Social pe toate rubricile, selector de temă, bibliotecă de filigrane

Trei cerințe explicite ale lui Cristi, în trei commit-uri separate.
Platforme afectate: **Mac (Client + Furnizor) + PWA/mobil** (`docs/app.html`).

1. **Rețele sociale la TOATE rubricile + LinkedIn.** `socialLinks` adăugat pe
   Course/EducationalResource/Event/PartnerStore/ServiceCenter/AppLink (Core,
   retrocompatibil); `linkedinURL` nou pe `SocialLinks`. Furnizor: componentă
   partajată `SocialLinksEditor.swift` integrată în toate cele 10 formulare.
   Client + PWA: rând de iconițe pe cardurile respective.
2. **Selector explicit de temă Sistem/Light/Dark** (Regula 18, lipsea complet).
   `AppTheme.swift` în Core, aplicat prin `NSApp.appearance`, persistat local,
   fără repornire. Client: Preferences. Furnizor: ecran de Preferences NOU.
3. **Filigrane sezoniere — bibliotecă reutilizabilă**, cu perioadă
   (`Scheduling`), poziție (5 opțiuni) și toggle activ/inactiv per intrare.
   `Catalog.seasonalBackground` (String) → `seasonalBackgrounds` (listă), cu
   migrare silențioasă a cheii vechi, verificată pe catalogul live.
   Recomandare documentată: **SVG** peste PNG (ambele rămân suportate).

`docs/sw.js`: CACHE_VERSION v12 → v14. `docs/update.json` NEATINS.

**TODO paritate pe Windows** (`GDCPluginManagerWin`, repo separat): niciuna
dintre cele 3 nu e portată — social/LinkedIn pe cele 6 modele, selector de
temă WPF, și filigranele sezoniere (acolo nu există deloc încă). Detalii în
CLAUDE.md, secțiunea "SESIUNE 2026-08-29".

## Client v1.6.0 + Furnizor v1.4.0 (2026-08-29) — Etapa 2 finalizată: Resurse Download (LUT/SFX/VFX/Plugin)
Cristi a confirmat: "produse noi, separate, cu simplu link de download, ca
Audio". `DownloadableResource`/`DownloadCategory` (Core, nou) — 4
categorii, model de download direct (nu auto-install ca LUT/DCTL). Furnizor:
tab nou "Resurse Download". Client: 4 categorii noi în sidebar, cu filtru
OS + linkuri Achiziție/Demo/Social pe card, incluse și în căutarea globală.
Vezi CLAUDE.md pentru detalii complete + nota de scop (Audio vechi rămâne
neschimbat, neunificat cu noua categorie SFX).

## Client + Furnizor Mac v1.5.0 (2026-08-29) — Etapa 2 (parțial) din Planul Integrat de Upgrade v2.0
Model `PluginItem` (Core) extins, retrocompatibil: `purchaseURL` (Link
Achiziție/Magazin extern), `demoURL` (Link Demo/Preview), `socialLinks`
(`SocialLinks`: Facebook/YouTube/Instagram/TikTok, toate opționale — nil
pentru orice produs vechi). Furnizor (`PublishView.swift`): secțiune
`DisclosureGroup` "Linkuri suplimentare & rețele sociale (opțional)" cu
cele 6 câmpuri noi. Client (`PluginCard`): rând nou de iconițe (SF Symbols,
nu emoji/logo-uri de brand) sub versiune — apare DOAR dacă produsul are
cel puțin un link completat. **Scope rămas din Etapa 2**: categoriile noi
LUT-uri/SFX/VFX/Plugin-uri pentru download direct (Premiere/FCP/Resolve) —
arhitectură neclară încă (se suprapune cu modelul auto-install existent al
LUT/DCTL) — de clarificat cu Cristi înainte de implementare.

## Client Mac v1.5.0 (2026-08-29) — Etapa 1 din Planul Integrat de Upgrade v2.0
Căutare fuzzy (typo-tolerant, `FuzzySearch.swift`, Core) + istoric de
căutări recente + autocomplete (`SearchBar.swift`) și filtru rapid
Toate/Mac/Windows (`OSFilter`), adăugate în `CatalogGrid` (secțiunea
Produse — DCTL/LUT/Fuse/OFX/PowerGrade). Caută în nume, descriere, ID și
tip. **TODO paritate**: `GDCPluginManagerWin` (Client Windows) nu are încă
această bară — portare separată. **TODO scope**: AppsGrid/CoursesGrid/etc.
nu au încă bara — extindere la o etapă viitoare, dacă se confirmă util.
Nu s-a atins `docs/update.json` — fără release nou încă (Regula practică
2026-08-27: nu bump `update.json` fără artefact publicat).

**[COMPLETARE 2026-08-29] Badge-uri de compatibilitate OS: SF Symbols, nu
emoji.** Cristi: "simbolurile de măr... nu-mi place, prefer SVG... impecabil,
profesionist". `🍎/🪟/🔄` (emoji color) → `SupportedOS.badgeSymbol` (SF
Symbols vectoriale: `apple.logo`/`pc`/`arrow.triangle.2.circlepath`), randate
ca chip circular discret pe card + `Label(systemImage:)` în selectorul din
Furnizor. **Port 1:1 pe Windows** (`GDCPluginManagerWin`): `BadgeSymbol()`
(Fluent: `DesktopMac24`/`DesktopTower24`/`ArrowSync24`) + `SymbolNameConverter`
(nou) + `ui:SymbolIcon` în `MainWindow.xaml`, în loc de `TextBlock` cu emoji.

**[COMPLETARE 2026-08-29] Căutarea devine GLOBALĂ, nu doar pe Produse.**
Cristi a semnalat explicit că bara de căutare trebuie să funcționeze din
ORICE rubrică, pe TOT ce există în aplicație — nu doar pe secțiunea
Produse. Bara locală din `CatalogGrid` a fost eliminată; o singură bară
`SearchBar` acum trăiește deasupra `detailContent` (vizibilă indiferent de
selecția din sidebar). Câmp gol → rubrica selectată se comportă exact ca
înainte. Câmp nevid → `GlobalSearchResults` (nou) afișează, în ORICE
rubrică te-ai afla, rezultate unificate din TOATE cele 8 colecții
(Produse/Aplicații/Audio/Cursuri/Materiale/Evenimente/Magazine/Service),
grupate pe secțiuni (o secțiune fără potriviri nu se afișează deloc).

Format: fiecare intrare listează versiunea, platformele afectate, și — pentru
funcționalități noi — dacă are paritate completă Mac/Windows sau e "doar pe
o platformă, portare pe cealaltă e TODO".

## Site (gordas.dev) — 2026-08-25
**Bug critic găsit și reparat**: catalogul rămânea blocat la „Se încarcă
catalogul…" pe TOATE limbile — cauza NU era rețeaua/`fetch` (`catalog.json`
încărca oricum în ~0.2s, verificat direct), ci un **crash de sintaxă JS**:
`browser\\'s menu` (backslash dublu + apostrof) în textul EN
`hero.android.note` termina string-ul JS prematur, oprind execuția
întregului `<script>` ÎNAINTE să ajungă la `fetch()` — pagina rămânea pe
placeholder-ul static din HTML. Fix: `\\'` → `\'` (un singur backslash).
Verificat cu `node --check` pe scriptul extras + testat local (server
Python + Browser) pe toate 3 limbi (RO/EN/ES) — catalogul se randă corect.
Adăugat și un timeout explicit de 8s (`AbortController`) pe `fetch`-ul de
catalog, ca un hang real de rețea (nu doar o eroare) să nu blocheze pagina
la infinit — nu exista niciun timeout înainte.

## v1.2.22 (2026-08-25)
**Doar Mac** — TODO paritate Windows (uninstaller Windows deja există separat, vezi `gdc-plugin-manager-win`):
- Eliminat launcher-ul `Instalare_GDCPluginManager.command` (hack Gatekeeper/quarantine inutil — pachetul e deja semnat+notarizat+stapled).
- Adăugat `Dezinstalare_GDCPluginManager.command`, inclus automat în fiecare release (`GDCPluginManager-Mac.zip`).
- Curățare de versiune veche mutată corect într-un `installer/scripts/preinstall` (fără hack-uri).
- Ghid PDF de utilizare inclus direct în arhiva de release, nu doar în meniul Help al aplicației.

## v1.2.21 (2026-08-25)
**Mac + Windows** — **paritate completă**, în urma unui audit complet cerut explicit (Furnizor → Server → Client):
- Badge compatibilitate OS (🍎/🪟/🔄) vizibil acum pentru TOATE cele 3 stări, inclusiv „Ambele"/`crossPlatform` — decizia inițială de a-l ascunde pentru starea implicită a fost o presupunere greșită despre așteptările UX.
- **Fix real Windows**: coperțile la Materiale/Evenimente nu se încărcau deloc (bug confirmat prin audit de cod, nu presupunere) — `UriToImageSourceConverter` nu asculta `DownloadFailed`, deci un eșec silențios lăsa un dreptunghi gol în loc de fallback pe iconiță. Înlocuit cu încărcare explicită în `CoverViewModel` (Windows), cu fallback vizual real.
- `CatalogAssets.ImageUrl` (Windows) escapează acum explicit fiecare segment de path, nu doar se bazează pe combinarea implicită `Uri`.
- **Relocare structurală**: toate repo-urile GDC mutate din `~/Downloads` (curățat automat de CleanMyMac/Hazel — a șters ambele repo-uri de sursă în timpul unei sesiuni, recuperate din Coș) în `~/Developer/`. `RepoCheckoutPaths.swift` actualizat, adăugat `PROJECT_STRUCTURE.md` în ambele repo-uri.

## v1.2.20 (2026-08-25)
**Doar Windows** — hotfix critic:
- Crash real la pornire pe client Windows (`BadImageFormatException: Duplicate type`, `MainWindow` → `LicensePaneViewModel`), cauzat de un bug de corupere a metadatelor în Obfuscar 3.0.0-beta.19 (confirmat cu două configurații diferite — vezi comentariul din `build-windows.yml`).
- Fix: obfuscarea de tipuri e dezactivată definitiv pe `GDCPluginManager.Core.dll` — corectitudinea contează mai mult decât obscurizarea codului. TODO: re-evaluat alt tool de obfuscare, dacă devine nevoie.

## v1.2.19 (2026-08-25)
**Toate 4 componente afectate** (Mac Swift, Windows C#) — **paritate completă**:
- Selector Compatibilitate OS pe produse: câmp `supportedOS` (macOS/Windows/crossPlatform) în `PluginItem`, implicit `crossPlatform` (retro-compatibil, nicio intrare veche nu e afectată).
- Furnizor (Mac): selector segmentat la publicare/editare produs.
- Client (Mac + Windows): badge 🍎/🪟/🔄 pe card, buton de instalare ascuns + mesaj „Incompatibil cu sistemul tău” pentru produsele mono-platformă nepotrivite.

## v1.2.18 (2026-08-25)
**Windows** — paritate cu Mac:
- Secțiune "Service & Reparații Echipament" (carduri, contact rapid, website/locație) — era doar pe Mac din v1.2.16.
- `SystemDependencyChecker` (DaVinci Resolve, Visual C++ Redistributable) — era doar pe Mac.
- Fix: `/Applications`-echivalent (instalare peste o copie root-owned) — n/a pe Windows, doar Mac avea nevoie.

## v1.2.17 (2026-08-25)
**Toate 4 componente** (Mac Swift, Windows C#, C++ resolve-encoder, Python production-manager) — **paritate completă**:
- Schemă de licențiere v2: payload extins de la 22 la 23 octeți (byte de platformă:
  `mac_only` / `windows_only` / `cross_platform`), 100% compatibil retroactiv cu codurile v1.
- Fix critic: release-ul Windows lipsea complet din `v1.2.16` (404 real la descărcare, nu problemă de site).

## v1.2.16 (2026-08-25)
**Doar Mac** — TODO paritate Windows (parțial acoperit în v1.2.18, vezi mai sus):
- Meniu nativ macOS (About, Check for Updates..., Preferences Cmd+,).
- Ghid PDF de utilizare (RO/EN/ES), deschis din meniul Help.
- Secțiune "Service & Reparații Echipament" (nouă, Client + Furnizor).
- `SystemDependencyChecker` (verificare DaVinci Resolve la lansare).
- Regulă de comunicare ultra-concisă adăugată în `CLAUDE.md`.

## v1.2.15 (2026-08-25)
**Mac + Windows** — Code Signing & Notarizare Apple completă (modul comun `codesigning/`, reutilizabil în orice repo GDC).

## v1.2.14 și anterior
Vezi istoricul `git log` — GDC-SEC-02 (Machine ID întărit), kill-switch diferențiat, retragere APK/TWA → PWA.

---

## Regulă de proces (vezi și CLAUDE.md)
Orice funcționalitate nouă adăugată **doar pe o platformă** trebuie:
1. Marcată explicit aici ca "doar pe X — TODO paritate pe Y".
2. Portată pe cealaltă platformă într-un ciclu de lucru ulterior, nu lăsată nedefinit.

## Client v1.19.4 (2026-08-29) — Documentație la zi: PDF redesenat + ghid din aplicație

- **Ghidul PDF** (RO/EN/ES) redesenat complet: copertă cu banner de brand,
  16 secțiuni (față de 8) — acoperă acum căutarea globală, Resurse Download,
  Comunitate, Aplicațiile Mele, Oferte & Pachete, temă/mărime text, aplicația
  de telefon. Footer cu număr de pagină pe fiecare pagină, casete evidențiate
  pentru note importante.
- **Ghidul din aplicație** ("Ajutor" din sidebar) — 4 secțiuni noi
  (Căutare globală, Resurse Download, Comunitate/Aplicații/Oferte, Temă),
  în toate 3 limbile.
- **Bug fix web**: pagina principală (gordas.dev) avea un preview de
  catalog separat de aplicație, cu 4 rubrici lipsă (Resurse Download,
  Oferte Parteneri, Service & Reparații, Pachete) — corectat.
