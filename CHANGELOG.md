# Changelog — GDC Plugin Manager

## Client v1.27.0 (2026-09-01) — Descriere colapsabilă peste tot în catalog

Toate cardurile din catalog (Produse, Cursuri, Materiale, Evenimente,
Pachete, Oferte, Magazine, Service, Resurse Download, Audio, Tutoriale)
au acum descrierea ascunsă implicit, cu un buton „Descriere” care o
desfășoară la cerere — cardurile ocupă mai puțin spațiu, dar poți citi
oricând detaliile complete. Tagurile de la Tutoriale se comportă la fel.

## Furnizor v1.25.1 (2026-09-01) — Ghid pas-cu-pas pentru cheia YouTube Data API

Panoul „Tutoriale” din Furnizor arată acum un ghid desfășurabil cu 4 pași
pentru obținerea unei chei YouTube Data API v3 (buton spre fiecare pagină
relevantă din Google Cloud Console), plus un buton „Testează cheia” care
verifică imediat dacă e configurată corect.

## Client v1.26.0 + Furnizor v1.25.0 (2026-09-01) — Tutoriale (YouTube embedded) + căutare în meniu

- **Secțiune nouă „Tutoriale”** (Comunitate & Educație) — video-uri YouTube
  afișate ca playere embedded: imagine, titlu și descriere preluate automat
  de la link, descriere expandabilă la cerere, taguri, grupare pe
  categorie (liberă) și căutare deasupra grilei.
- Furnizor primește un panou dedicat de publicare a tutorialelor, cu
  preluare automată a informațiilor de pe YouTube și editare liberă a
  tuturor câmpurilor înainte de publicare, inclusiv valabilitate temporală
  opțională (perioadă de afișare).

## Client v1.25.1 + Furnizor v1.24.1 (2026-09-01) — Iconiță nouă: roata de culori

Iconița aplicației (Mac + Windows) a fost înlocuită cu un design nou —
un inel plin cu spectrul complet de culori — la cererea lui Cristi.
Aplicată identic pe Client, Furnizor și clientul Windows.

## Furnizor v1.23.0 (2026-08-31) — FIX CRITIC: publicarea putea șterge tot catalogul

**Cauza reală**: dacă `docs/catalog.json` lipsea de pe disc în momentul unei
publicări (folder șters extern, ex. de un curățător de disc), Furnizor trata
tăcut situația ca „catalog gol" și republica DOAR produsul curent — ștergând
ireversibil (după push) toate celelalte produse/aplicații/evenimente din
catalog, fără nicio eroare vizibilă. Așa au dispărut produse publicate
anterior (LUT/DCTL/PowerGrade).

**Fix**: dacă fișierul lipsește, Furnizor încearcă întâi să-l recupereze
singur din git (recuperare automată); dacă tot nu reușește, publicarea
eșuează cu eroare clară — nu mai rescrie niciodată tăcut catalogul cu date
incomplete.

## Client v1.25.0 + Furnizor v1.22.0 (2026-08-31) — Preț/ofertă/countdown pe cardurile din „Aplicații”

Cardurile din „Aplicații” (CG Convertor, CursorPro, DataMover, GDC Vault,
Master Control Studio Pro, MediaFlow Monitor) arată acum preț, ofertă activă
și countdown direct pe card, citind `pricing.json` — exact ca la LUT/DCTL/
PowerGrade. Furnizor capătă un câmp nou (opțional) în „Aplicații”: ID din
Pricing Manager, care leagă cardul de produsul corespunzător.

**Fix separat, real**: fișierul comprimat ales pentru coperta unui produs
era ținut într-un folder temporar de sistem (`/var/folders/.../T/`) până la
„Publică” — un curățător de disc (CleanMyMac, între timp eliminat) putea
șterge acel fișier între alegere și publicare, iar Furnizor eșua cu o
eroare care arăta un nume de fișier intern (UUID), nu numele ales de
furnizor. Mutat în Application Support, niciodată tratat ca temp/cache.

## Client v1.24.5 (2026-08-31) — Fix real: Mărime Text nu făcea nimic (Mac)

`dynamicTypeSize` (infrastructura de accesibilitate SwiftUI) nu producea
nicio schimbare vizibilă pe macOS, în ciuda a două tentative de fix.
Înlocuit cu aceeași tehnică deja dovedită pe Windows: o scalare vizuală
directă a întregului conținut. Confirmat funcțional de Cristi.

## Client v1.24.3 (2026-08-31) — Poziție text sus/jos, aleasă din Furnizor

- Bannerul de lansare nu mai suprapune textul peste imagine — text și
  imagine sunt elemente separate, unul deasupra celuilalt.
- Furnizor: opțiune nouă „Poziția textului" (deasupra/sub imagine).

## Client v1.24.2 (2026-08-31) — Fix: textul bannerului se suprapunea peste imagine

Raportul de aspect al imaginii era hardcodat (cel al imaginii inițiale) —
după ce imaginea a fost înlocuită prin Furnizor cu un raport diferit,
textul ajungea poziționat greșit. Fix: raportul se citește acum direct din
imaginea primită. Adăugat și un voal întunecat sub text, ca să rămână
lizibil indiferent de conținutul imaginii (Mac + Windows).

## Client v1.24.1 (2026-08-31) — Fix: bannerul de lansare nu se afișa niciodată

Bug real, identic cu cel deja documentat la filigranul sezonier: `.task`
(care pornea fetch-ul) era atașat pe un container gol condiționat — la
primul randaj SwiftUI nu-l pornea niciodată. Confirmat din log ("zero
apeluri LaunchBanner") și reparat: `.task` mutat pe un container CONCRET,
mereu prezent.

## Client v1.24.0 (2026-08-31) — Valabilitate temporală pentru bannerul de lansare

Bannerul de lansare (v1.23.0) poate avea acum o perioadă programată — se
ascunde automat după data de sfârșit, fără nicio acțiune manuală. Aceeași
componentă `SchedulingPicker` folosită de tot restul catalogului.

## Client v1.23.0 (2026-08-31) — Banner de lansare controlabil din Furnizor

Înlocuiește v1.22.0 (imagine statică bundled în app): Cristi poate acum
schimba imaginea/textul bannerului oricând, fără recompilare — la fel ca
prețurile dinamice (Regula 27).

- **`docs/launch-banner.json`** (nou) — sursa canonică (enabled, imagine,
  text), servită static la `gordas.dev/launch-banner.json`.
- **Furnizor — panoul "Banner Lansare"** (`LaunchBannerManagerView.swift`,
  nou) — comutator, două câmpuri de text, upload de imagine (reutilizează
  `CoverImagePicker`/`CoverImageStore` deja existente), buton „Publică".
- **Client — `LaunchBannerChecker.swift`** (nou) — fetch la lansare, cache
  local (offline-first, ca filigranele sezoniere), ascuns complet dacă
  bannerul e dezactivat sau nu s-a putut încărca nimic.

## Client v1.22.0 (2026-08-31) — Banner de lansare publică

Cerută de Cristi pentru lansarea publică a platformei: un banner static,
ancorat jos de tot pe ecranul principal, cu imaginea generată AI (3D,
obiecte simbolice pentru fiecare tip de conținut din catalog) și textul
real „LANSARE" / „PREȚURI SPECIALE DE DESCHIDERE" suprapus (SwiftUI
`Text`, nu parte din imagine — generatoarele AI de imagini nu randează
fiabil text cu diacritice românești).

- **`LaunchOfferBanner.swift`** (nou) — imagine statică `.copy`-uită în
  bundle-ul Client (`Resources/LaunchOfferBanner.jpg`), NU parte din
  biblioteca de filigrane sezoniere (`SeasonalBackgroundsLayer`/Furnizor) —
  e temporară, scoasă manual din cod când se încheie oferta de lansare, nu
  are nevoie de scheduling.
- Inserată ca frate în `VStack`-ul din `ContentView.detail` (Regula 24 —
  niciodată `.safeAreaInset` direct pe un `List`/`ScrollView`),
  non-interactivă (`.allowsHitTesting(false)`).
- **Verificat**: `swift build --product GDCPluginManager` — 0 erori.

## Client v1.21.0 + Furnizor v1.18.0 (2026-08-31) — Ceas live opțional (countdown) pentru oferte cu termen
Cerință explicită a lui Cristi: "dacă pun un eveniment sau o aplicație la
ofertă... să apară ca un ceas câte zile, ore, minute mai este până dispare".
- **`Scheduling.showCountdown`** (nou, opțional, implicit `false`) —
  câmp nou pe modelul de valabilitate temporală comun tuturor secțiunilor
  (Evenimente, Cursuri, Aplicații, Oferte Parteneri, Bundle-uri, Materiale,
  Magazine Parteneri, Centre Service, Resurse descărcabile/educaționale).
- **Furnizor** — comutator nou "Arată countdown live la clienți (opțional)"
  în `SchedulingPicker`, vizibil doar când valabilitatea temporală e activă.
- **Client** — badge portocaliu "MAI SUNT Xz Yh" pe cardul respectiv, cât
  timp conținutul e activ, auto-actualizat la 60s — pe toate cele 11 tipuri
  de conținut din catalog.
- Compatibil cu `catalog.json` existent — orice intrare fără acest câmp
  se comportă identic ca înainte (countdown OFF implicit).

## Furnizor v1.17.1 (2026-08-31) — Fix: valabilitatea temporală nu apărea corect la editare
Raportat de Cristi: la editarea unui Eveniment (sau oricărei alte secțiuni
— Cursuri, Oferte Parteneri, Materiale, Aplicații, etc.) care avea deja o
perioadă de valabilitate setată, comutatorul „Valabilitate temporală”
apărea greșit ca OFF/gol, ca și cum trebuia setat din nou — deși valoarea
reală rămânea salvată corect în `catalog.json`. Cauza reală: `SchedulingPicker`
(componenta reutilizată de toate cele 10 secțiuni) își inițializează starea
internă o singură dată, la primul render — SwiftUI păstrează aceeași
instanță de view (și starea ei) între „adaugă nou” și „editează existent”,
deci schimbarea ulterioară a valorii din formularul părinte nu se mai
reflectă vizual. Fix: `.id(editingID ?? "new")` pe fiecare `SchedulingPicker`
— forțează o identitate nouă de view la fiecare editare, deci inițializarea
citește mereu valoarea reală curentă. (`SeasonalBackgroundView` avea deja
acest fix, dintr-o sesiune anterioară — doar nu fusese propagat la
celelalte 10 fișiere care folosesc aceeași componentă.)

## Client v1.20.1 (2026-08-31) — Fix: eticheta „Actualizare disponibilă” persista după update real
Raportat de Cristi: după ce actualiza o aplicație (ex. DataMover) la ultima
versiune și dădea „Refresh” în „Aplicațiile mele”, eticheta de actualizare
rămânea afișată — dispărea DOAR după ce închidea complet și redeschidea GDC
Plugin Manager. Cauza reală: `Bundle(url:)` cache-uiește `infoDictionary`-ul
pentru toată durata procesului — o citire ulterioară din același proces
(inclusiv Refresh) întorcea versiunea veche, chiar dacă `Info.plist`-ul de
pe disc se schimbase între timp. Fix: citire directă a `Info.plist`-ului
(`PropertyListSerialization`, fără `Bundle`), fără cache — Refresh reflectă
mereu starea reală, fără să fie nevoie de o repornire.

## Furnizor v1.17.0 (2026-08-30) — Pricing Manager: prețuri/oferte dinamice fără recompilare
Cerință directă a lui Cristi: o ofertă de Black Friday necesita până acum
recompilarea + resemnarea + republicarea FIECĂREI aplicații standalone
(12 repo-uri) doar ca să schimbi o cifră afișată.
- **Panou nou „Prețuri & Oferte"** — pentru fiecare aplicație standalone
  (`gdcStandaloneProducts`): preț de bază editabil + un PROGRAM de ferestre
  de ofertă, programabile din timp ("1-15 sept: preț X, Black Friday: preț
  Y, Crăciun: preț Z"), nu doar o singură ofertă on/off. Fiecare fereastră
  are preț, etichetă, interval de timp, și un comutator opțional „Arată
  countdown live" (creează urgență — "Se termină în 2z 14h").
- **„Publică" = `git pull` → scrie `docs/pricing.json` → `commit` + `push`**
  (reutilizează `GitOps` deja existent) — fără recompilare, live pe toate
  aplicațiile care citesc `pricing.json` în câteva minute.
- **`docs/pricing.json`** (nou) — servit static la `https://gordas.dev/pricing.json`,
  citit de `PricingChecker` (portat identic per aplicație client, după
  modelul `UpdateChecker`/`update.json`) — **fail-open**: fără conexiune,
  aplicația folosește prețul hardcodat din cod, niciodată un ecran gol.
- **Pilot implementat**: DataMover (Mac) — `ActivationSheet` arată prețul
  efectiv (bază sau ofertă activă) + countdown opțional, iar mesajul
  WhatsApp pre-completat folosește prețul curent, nu unul fix. Restul
  aplicațiilor (Windows DataMover + celelalte 10 repo-uri) rămân TODO,
  documentat ca Regula 27 în CLAUDE.md.

## v1.20.0 (2026-08-30) — Iconițe reale + auto-detectare live „Aplicațiile Mele"
- **Fix real**: Master Control Studio Pro nu apărea în „Aplicațiile Mele" — lipsea din lista hardcodată `knownGDCApps`. Adăugat, plus un listener `NSWorkspace.didLaunchApplicationNotification` care reface lista instant la lansarea oricărei aplicații GDC.
- **Watcher live pe `/Applications` + `~/Applications`**: o instalare prin `.pkg`/copiere manuală apare acum și fără ca aplicația să fi fost lansată vreodată.
- **Iconițe REALE**, nu simboluri generice: cardurile din „Aplicații GDC instalate" și „Scurtături personalizate" extrag acum iconița adevărată direct din bundle-ul instalat (`NSWorkspace.icon(forFile:)`) — inclusiv pentru scurtături terțe (DaVinci Resolve, Photoshop, Lightroom etc.). Nu bundle-uim nicio siglă terță în cod (risc de marcă înregistrată) — extragerea se face mereu din aplicația deja instalată pe mașina userului, exact ca Finder.
- **Adăugare multiplă de scurtături** — `fileImporter` acceptă acum mai multe aplicații deodată, nu doar una.

## v1.19.14 (2026-08-29) — Ghiduri PDF redesenate + ghid din aplicație completat

- PDF-urile de utilizare (RO/EN/ES) redesenate cu 4 capturi reale ale
  aplicației (fereastra principală, instalare produs, setări, verificare
  dependențe) + fix real: punctele 🔴/🟢 apăreau ca pătrate goale în PDF
  (Arial nu are glyph-uri emoji) — acum puncte colorate reale.
- Ghidul din aplicație (Ajutor) completat cu 2 secțiuni lipsă găsite la
  audit: Panoul de Dependențe și Aplicația mobilă.
- Audit date confidențiale pe paginile publice: nimic expus.
- Windows: neschimbat, doar sincronizare de versiune.

## v1.19.13 (2026-08-29) — Bump doar de versiune (sincronizare cu Windows, fără cod nou)

Necesar ca `update.json` comun să indice o versiune reală, existentă pe
ambele platforme, ca să putem valida manual că self-updater-ul Windows
(reparat în v1.19.12) chiar funcționează end-to-end din program. Mac
neschimbat față de v1.19.10 — pachet reutilizat, doar redenumit.

## v1.19.12 (2026-08-29) — Windows: HTTP/1.1 forțat + fix real self-updater

- Forțat HTTP/1.1 explicit la fetch de imagini — elimină ALPN/HTTP2 ca
  variabilă în eroarea SSL persistentă de la `gordas.dev` (v1.19.9/10 nu
  au rezolvat-o).
- Fix real self-updater: folosea un `HttpClient` propriu fără User-Agent
  și fără logare — orice eșec cădea tăcut pe fallback-ul de descărcare
  manuală ("trebuie tot timpul să descarc de pe pagina web"). Mac:
  neschimbat.

## v1.19.10 (2026-08-29) — Windows: diagnostic certificat TLS real (v1.19.9 nu a rezolvat)

- Fix-ul v1.19.9 (reciclare conexiune HTTPS) NU a rezolvat eroarea SSL —
  confirmat din log, persistă identic. Adăugat log explicit al
  certificatului real respins (Subject/Issuer/Thumbprint/ChainStatus) la
  orice eșec de validare TLS, ca să găsim cauza definitivă din date reale,
  nu ipoteze. Mac: neschimbat.

## v1.19.9 (2026-08-29) — Windows: fix real eroare SSL filigran (conexiune HTTPS reciclată)

- Cauza reală a eșecului SSL intermitent (Windows): `RemoteCertificateNameMismatch`
  pe conexiunea HTTPS statică a aplicației, ținută deschisă la infinit —
  nu ceas de sistem greșit în VM, cum se bănuia inițial. `HttpClient`
  reciclează acum conexiunea la 5 minute, robust la anycast-ul Cloudflare
  din spatele `gordas.dev`. Mac: neschimbat față de v1.19.8.

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

## Furnizor v1.23.1 (2026-08-31) — FIX: republicarea unei coperte/filigran cu același nume eșua

**Cauza reală**: la reîncărcarea unei imagini pentru un produs/eveniment/
magazin/filigran deja publicat, dacă fișierul vechi de pe disc nu putea fi
șters (rămas dintr-un ciclu extern de ștergere/restaurare), copierea noii
imagini eșua cu „fișier deja existent" — singurul ocol era să schimbi
numele produsului. Fix: fișierul vechi se șterge explicit înainte de
copiere, de fiecare dată — republicarea funcționează acum indiferent de
starea anterioară a fișierului.

## Furnizor v1.24.0 (2026-08-31) — Bibliotecă de imagini reutilizabile

Nou buton „Din bibliotecă…" lângă „Alege imagine…", la orice copertă din
orice secțiune (Aplicații, Evenimente, Materiale, Magazine, Service,
Cursuri, Oferte, Pachete, Resurse) — arată toate imaginile deja publicate
și permite reutilizarea uneia existente pe un produs nou, fără reîncărcare
de pe disc.
