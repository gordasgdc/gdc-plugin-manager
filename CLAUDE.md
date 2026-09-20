# GDC Plugin Manager — reguli de arhitectură (Mac)

> **[SYSTEM DIRECTIVE FOR CLAUDE: DO NOT DELETE OR OVERWRITE EXISTING RULES. ONLY APPEND NEW RULES.]**
> Acest fișier e un jurnal viu, nu un document care se rescrie. La orice actualizare de arhitectură, adaugă regulile noi la finalul secțiunii potrivite — nu șterge/înlocui reguli vechi, decât dacă sunt explicit invalidate de o schimbare reală de arhitectură (și în acel caz, marcheaz-o ca **[ÎNVECHIT]** cu motivul, nu o șterge din istoric).
> Excepție reală, nu scuză: dacă o regulă descrie ceva ce ai verificat live că nu mai e adevărat (ex. o cale de fișier redenumită), corecteaz-o — dar lasă o notă în "Technical Decisions & Known Pitfalls" de mai jos ca să nu se piardă contextul schimbării.

Acest fișier e citit automat de Claude Code la fiecare sesiune în acest repo. Ține-l scurt și corect — dacă o regulă de aici devine falsă, corecteaz-o imediat, nu o lăsa să mintă.

**Checklist obligatoriu înainte de orice `git commit`/push în acest repo:**
1. Link-urile de download ating `.../releases/latest/download/...`, niciodată un tag fix?
2. Orice schimbare de structură (OFX/DCTL/PowerGrade/tip nou de plugin) e oglindită și în `gdc-plugin-manager-win` (Client Windows)?
3. Dacă schimbarea afectează formatul fișierelor publicate, `PublishView.swift` (Furnizor) încă produce exact ce așteaptă `InstallManager.swift`/`.cs` la instalare?
4. Comentariile WARNING/ARCHITECTURE NOTE din cod încă reflectă realitatea (nu mint despre un comportament schimbat între timp)?
5. A apărut un bug nou, real, rezolvat în sesiunea asta? Adaugă-l în "Technical Decisions & Known Pitfalls" de mai jos, ÎNAINTE de commit.

## [PARTEA 1: REGULI GLOBALE ECOSISTEM GDC] — mutată în `~/Developer/CLAUDE.md`

> Din 2026-09-18, regulile globale stau într-un singur fișier,
> `~/Developer/CLAUDE.md`, citit automat de Claude Code în orice proiect din
> `~/Developer/`. Nu se mai copiază aici. Ce era specific acestui repo în fosta
> Partea 1 (statusuri, excepții) e la finalul fișierului.

## [PARTEA 2: SPECIFICAȚII TEHNICE PROIECT]

## Structura repo-ului
- `Sources/GDCPluginManagerCore/` — model de date comun (`CatalogModel.swift`), folosit și de Client și de Furnizor.
- `Sources/GDCPluginManager/` — aplicația **Client** (ce descarcă/instalează utilizatorul final).
- `Sources/GDCPluginManagerFurnizor/` — aplicația **Furnizor** (ce publică produse noi, doar pentru tine).
- `docs/` — site-ul static (GitHub Pages, domeniu `gordas.dev` prin CNAME) + `catalog.json` (catalogul public) + `update.json` (self-update).
- Fișierele fizice ale produselor (LUT/DCTL/Fuse/OFX/PowerGrade) **nu** stau în acest repo — ele merg în repo-ul privat separat `gdc-plugin-manager-files`, prin push direct din Furnizor.

## Reguli de aur

**0. Rebuild+reinstall OBLIGATORIU pentru AMBELE aplicații (Client ȘI
Furnizor) la orice commit care atinge codul vreuneia — nu doar cea testată
în acel moment.** (Promovată din `CLAUDE_ARCHIVE.md`, 2026-08-31 — regula
exista din 2026-08-24, dar trăia într-un fișier care explicit NU se
citește automat, deci a fost încălcată din nou.) Bug real, repetat:
`Client v1.24.0 + Furnizor v1.20.0` au fost bump-uite în ACELAȘI commit
(scheduling pe bannerul de lansare), dar doar Client-ul a fost rebuild-uit
+ reinstalat + testat imediat — Furnizor-ul instalat a rămas la binarul
vechi (`v1.19.0`, fără scheduling), până când Cristi a întrebat explicit
"Furnizor este actualizat?". Regulă practică:
- După orice commit care schimbă cod în `Sources/GDCPluginManager/`,
  `Sources/GDCPluginManagerCore/`, SAU `Sources/GDCPluginManagerFurnizor/`,
  rulează AMBELE `build_app.sh` ȘI `build_furnizor_app.sh` înainte de a
  raporta lucrul ca fiind gata — niciodată doar scriptul aplicației la care
  te-ai gândit ultima. `GDCPluginManagerCore` e comun ambelor, deci orice
  schimbare acolo atinge implicit pe amândouă.
- Verifică explicit versiunea INSTALATĂ (nu doar cea din sursă) înainte de
  a spune "gata" — `/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString"`
  pe bundle-ul din `/Applications`, comparată cu `Info.plist`/
  `Info-Furnizor.plist` din repo. O versiune bump-uită în sursă, dar
  nereflectată pe disc, e exact genul de discrepanță care a cauzat bug-ul
  de mai sus.

**1. Download links — NICIODATĂ hardcodate.**
Orice link de download (site, `update.json`, README) trebuie să folosească `.../releases/latest/download/<fisier>` — GitHub rezolvă automat spre ultimul release nepublicat ca draft/prerelease. Nu scrie niciodată un tag fix (`v1.2.4`) într-un link public. Verificat live 2026-08-22: toate cele 4 site-uri GDC respectă deja asta.

**2. Nu există o "bază de date" separată.**
Catalogul public E `docs/catalog.json`, versionat în git, servit static prin GitHub Pages. Furnizor scrie direct în el (via `CatalogEditor.swift`) și face `git commit && push`. Nu există backend/API/DB separat de sincronizat — dacă cineva propune "sincronizare cu baza de date", verifică întâi dacă chiar există una înainte de a construi ceva nou.

**3. Fiecare schimbare de structură (OFX/DCTL/PowerGrade) trebuie oglindită în 3 locuri:**
- `CatalogModel.swift` (Core) — tipul + `installDirectory`
- `InstallManager.swift` (Client) — cum se scrie pe disc
- `PublishView.swift` (Furnizor) — cum se colectează fișierele de la vendor (`collectFiles` deja păstrează structura de subfoldere corect — nu aplatizează; verificat 2026-08-22)
- **Și** portul lor 1:1 în `gdc-plugin-manager-win` (vezi CLAUDE.md de acolo) — cele două clienți trebuie să rămână sincronizați manual, nu există cod partajat între Swift și C#.

**4. Permisiuni macOS: chown, nu chmod 777.**
Orice folder care cere elevare (`/Library/OFX/Plugins`) se scrie cu `osascript ... with administrator privileges`, niciodată `sudo` scriptat. La primul fallback elevat, se face `chown` pe rădăcina folderului către userul curent, ca instalările următoare să nu mai ceară parola — nu `chmod -R 777` (world-writable, risc de securitate pe o mașină multi-user).

**5. PowerGrade: EXCLUSIV prin Scripting API-ul DaVinci, niciodată scriere directă în baza de date de Gallery.**
Vezi `PowerGradeImporter.swift`. Resolve nu expune Gallery-ul ca fișiere editabile manual (nu există `index.xml`/`.drx` documentat oficial) — orice scriere directă în structura internă a bazei de date de proiecte riscă s-o corupă. Dacă scripting-ul nu e disponibil (Resolve închis, Free edition fără bridge), cade pe `stagedOnly` — fișierele rămân verificate pe disc, userul face un import manual, niciodată eroare dură.

**6. [ÎNVECHIT 2026-08-25] Bundle-ul `.command`.**
Exista un wrapper `Instalare_GDCPluginManager.command` care rula
`xattr -dr com.apple.quarantine` pe `.pkg` — ELIMINAT complet (fișier
șters). Pachetul e semnat + notarizat + **stapled**, deci Gatekeeper îl
acceptă nativ la dublu-click, fără nicio intervenție. Curățarea unei
instalări vechi se face acum corect, în `installer/scripts/preinstall`
(`pkgbuild --scripts`) — pkill + `rm -rf` pe copia veche, nimic legat de
Gatekeeper/quarantine acolo. Vezi aceeași decizie în `CursorPro/CLAUDE.md`.

## Unde se rulează testele reale
Testarea Windows depinde de disponibilitatea unui prieten (sesiune AnyDesk la distanță) — poate dura ore/zile între ferestre de test. Nu bloca alt lucru așteptând un retest.


## REGULĂ PERMANENTĂ DE COMUNICARE & SALVARE TOKENI (2026-08-25)
1. Fără explicații lungi de proces, teorii sau introduceri meta.
2. Nu descrie pașii intermediari de analiză decât dacă sunt ceruți explicit.
3. Răspunde ultra-concis: direct codul, diff-ul, comenzile de rulat și statusul scurt.
4. Păstrează toate ieșirile de text scurte, la obiect și eficiente.

## REGULĂ PERMANENTĂ: Documentație + Paritate Mac/Windows (2026-08-25)
1. La orice modificare/release nou: actualizează `CHANGELOG.md` (ce s-a făcut,
   ce platforme sunt afectate) și comentariile relevante din cod.
2. Orice funcționalitate nouă adăugată pe O SINGURĂ platformă (Mac sau
   Windows) trebuie marcată explicit în `CHANGELOG.md` ca "TODO paritate
   pe [cealaltă platformă]" — nu se lasă nedocumentată, ca să nu se piardă
   din vedere la sesiunea următoare.

## REGULĂ PERMANENTĂ: Locația proiectelor pe disc (2026-08-25)
Toate repo-urile GDC (acesta, `GDCPluginManagerWin`, `gdc-plugin-manager-files`,
`gdc-plugin-manager-catalog-vendor` etc.) trăiesc în **`~/Developer/`**, NU în
`~/Downloads` sau `~/Desktop`. Motiv real: `~/Downloads` e curățat automat de
unelte precum CleanMyMac/Hazel pe acest Mac — au șters ambele repo-uri de
sursă în timpul unei sesiuni de lucru (recuperate din Coșul de gunoi la timp,
dar ar fi putut fi pierdere ireversibilă). Vezi `PROJECT_STRUCTURE.md` pentru
harta completă a directoarelor și cum se leagă între ele (Furnizor citește
`RepoCheckoutPaths.swift`, care presupune exact `~/Developer/<nume-repo>`).
Dacă vreun viitor asistent găsește codul în `~/Downloads`, e semn că a fost
mutat greșit înapoi — relocă-l în `~/Developer/` și actualizează
`RepoCheckoutPaths.swift` dacă s-a schimbat structura.

## REGULĂ PERMANENTĂ: Certificate & chei private — NICIODATĂ în git (2026-08-25)
Certificatele Apple (`.p12`/`.cer`) și orice altă cheie privată (`.p8`,
`.key`, `.pem`, `.mobileprovision`) stau EXCLUSIV local, în
`~/Developer/Certificates/` — un folder în afara oricărui repo git
(`~/Developer/` nu e sub git). Toate aceste extensii sunt în `.gitignore`
al fiecărui repo GDC, ca plasă de siguranță suplimentară. Motiv: sistemele
Apple detectează și REVOCĂ automat certificate expuse public, iar contul
de Developer poate fi suspendat. Niciun script de build nu are nevoie să
citească din acest folder — semnarea locală folosește identitatea din
Keychain (`security find-identity`) + credențialele de notarizare deja
salvate acolo (`gdc-notary`, vezi `codesigning/README.md`). Dacă un viitor
asistent găsește un `.p12`/`.cer` oriunde altundeva decât în acest folder
(Desktop, Downloads, un repo), mută-l imediat acolo și verifică
`git log --all --diff-filter=A` că n-a fost comis vreodată.

## DIRECTIVĂ PERMANENTĂ SUPREMĂ: Checklist obligatoriu la FIECARE release (2026-08-25)
Valabilă pentru TOATE aplicațiile ecosistemului GDC (CursorPro, GDC Plugin
Manager + Furnizor, GDC Plugin Manager Windows, DataMover, GDC Production
Manager, și orice proiect nou). Înainte de a raporta un release ca fiind
gata, TREBUIE bifate intern toate cele 4 puncte de mai jos — dacă unul
lipsește, spune-o explicit, nu declara release-ul "gata".

1. **Versiune vizibilă în UI** — About/Meniu/Settings/Footer trebuie să
   arate versiunea curentă (`v1.2.21` etc.), fără excepție.
2. **Verificator de actualizări** — la pornire sau printr-un buton
   „Caută actualizări", aplicația verifică versiunea de pe server/GitHub
   și notifică userul când există un release mai nou.
3. **Pachetul standard de release** — orice arhivă livrată clientului
   conține FĂRĂ EXCEPȚIE:
   - executabilul/installer-ul semnat + notarizat,
   - `Dezinstalare_[NumeAplicație].command` (dezinstalare completă:
     procese, permisiuni TCC, toate fișierele din `~/Library/`),
   - un ghid/PDF de instrucțiuni.
4. **Sincronizare site ↔ GitHub Releases** — linkurile de download de pe
   site trebuie să pointeze mereu la `releases/latest/download/...`
   (HTTP 200 verificat, nu presupus) și să menționeze numărul ultimei
   versiuni.


## Jurnal tehnic detaliat — arhivat

Technical Decisions & Known Pitfalls complet, cele două fluxuri de update,
Faza 3/4, secțiunea Audio, toate cele 9 etape v2.0 și restul jurnalului
datat sunt mutate în `CLAUDE_ARCHIVE.md` (NU se citește automat) — citește-l
explicit când investighezi o zonă veche de cod. Rezumat "stare curentă" mai
jos rămâne aici, fiindcă e activ relevant sesiune de sesiune.

## Client v1.29.0 / Furnizor v1.32.0 (2026-09-05) — Evenimente multi-locație, sedii suplimentare

Cerință explicită: un eveniment (workshop/curs/festival) rulează des în
mai multe orașe/perioade, uneori cu bilet/cost diferit pe locație — modelul
vechi (o singură `location`/`dateDisplay`, zero preț) nu acoperea asta.
Extins și la `ServiceCenter`/`PartnerStore` (singurele entități cu adresă
unică OPȚIONALĂ, structural identice ca nevoie — "mai multe sedii ale
aceleiași afaceri"). `Course` (`options: [CourseOption]`) și `ProductBundle`
(`items: [BundleItemRef]`) NU s-au atins — au deja tiparul echivalent.

**Model (`CatalogModel.swift`)**: `EventOccurrence` (nou struct — `location`/
`dateDisplay` libere, `priceEUR`/`priceLabel` opționale) +
`Event.occurrences: [EventOccurrence]`. `ServiceCenter`/`PartnerStore`
capătă `additionalAddresses: [String]`. Toate trei structuri au primit un
`init(from: Decoder)` CUSTOM nou (nu existau înainte, erau sintetizate) —
altfel array-urile non-optionale noi ar fi aruncat la decodare pentru
orice eveniment/service/magazin deja publicat (cheia lipsește din
`catalog.json`-ul lor). Verificat REAL, nu presupus: rulat un decoder de
test direct pe `docs/catalog.json` (7 evenimente, 1 service, 1 magazin) —
zero erori, toate cu `occurrences`/`additionalAddresses` goale ca înainte;
plus un round-trip encode/decode complet pe date noi, plus JSON vechi
("fără cheia nouă deloc") construit manual, confirmat că decodează la `[]`.

**Furnizor**: `PublishEventView.swift` — listă nouă (add/remove) +
`AddEventOccurrenceSheet.swift` (locație/interval/preț/etichetă, TOATE
opționale, pe tiparul `AddPromoWindowSheet` din `PricingManagerView.swift`).
`PublishServiceCenterView.swift`/`PublishPartnerStoreView.swift` —
`AdditionalAddressesEditor.swift` (nou, reutilizat de amândouă — listă
inline simplă, fără sheet, un singur câmp).

**Client**: `EventCard` — rând suplimentar per ocurență (locație+interval,
buton hartă propriu, badge de preț dacă există), linia principală
neschimbată. `PartnerStoreCard`/`ServiceCenterCard` — câte un rând per
adresă suplimentară.

**Windows (`GDCPluginManagerWin`, doar Core+Client — fără Furnizor,
confirmat din CLAUDE.md-ul acelui repo)**: `EventOccurrence` record nou +
`Event.Occurrences`/`ServiceCenter.AdditionalAddresses`/`PartnerStore.
AdditionalAddresses` (`IReadOnlyList<T>` cu default `Array.Empty<T>()` —
System.Text.Json lasă implicit valoarea declarată când cheia lipsește,
retrocompatibil fără niciun converter custom, spre deosebire de Swift).
`EventViewModel`/`AddressLinkViewModel` (nou, reutilizat de PartnerStore/
ServiceCenter) + `MainWindow.xaml` — `ItemsControl` nou per card. Verificat
cu `dotnet build ... -r win-x64` (0 erori) + un decoder de test separat,
rulat REAL pe același `catalog.json` de producție + round-trip + JSON vechi
construit manual — identic ca acoperire cu testul Swift de mai sus.

**Verificat**: `swift build` (Client+Core+Furnizor) — 0 erori. `dotnet
build src/GDCPluginManager.Client/GDCPluginManager.Client.csproj -r
win-x64` — 0 erori. Versiune bump-uită doar în sursă (`Info.plist`/
`Info-Furnizor.plist`/`.csproj`/`installer.iss`) — **`docs/update.json`
NU e atins încă**, intenționat: bump-ul lui e rezervat momentului în care
un release real, descărcabil, chiar există (Regula 14/istoricul de bug-uri
404 deja documentat în acest fișier).

## `docs/catalog.json` + `docs/pricing.json` (2026-09-04) — GDC Production Manager capătă preț propriu

Completare cerută din sesiunea de refactorizare majoră a
`gdc-production-manager` (Regula 12/27 — profil+HWID, revocare, preț
dinamic) — acea aplicație era deja în `catalog.json`, dar fără
`pricingProductID`, deci `AppPricingFetcher`/cardul din "Aplicațiile mele"
n-avea de unde citi un preț pentru ea.

- `docs/catalog.json` — adăugat `"pricingProductID": "gdc-production-manager"`
  pe intrarea deja existentă. Editat CHIRURGICAL (o linie) — prima
  încercare, prin `json.dump(..., sort_keys=True)` din Python, a rescris
  formatarea ÎNTREGULUI fișier (847 din ~/900 linii schimbate doar pentru
  un câmp) fiindcă ordinea cheilor și stilul de indentare al scriptului nu
  coincideau cu cele ale fișierului original — anulată explicit
  (`git checkout`) înainte de commit, refăcută ca edit de text simplu.
  **Regulă practică**: orice modificare a acestui fișier (sau a
  `pricing.json`) prin script/cod, nu prin editare directă de text, TREBUIE
  să păstreze formatarea exactă existentă (indent 2 spații, `"cheie" :
  valoare` cu spațiu înainte de `:`) — un rescrieri complet, chiar dacă
  JSON-ul rezultat e semantic identic, face imposibil de recenzat diff-ul
  și riscă regresii de formatare într-un fișier live, citit de toți
  clienții din ecosistem.
- `docs/pricing.json` — intrare nouă `"gdc-production-manager"`
  (`basePrice: 25 EUR`, `promoSchedule: []`) — 25 €, suma deja documentată
  de acel repo (nu 23 € generic, Regula 3), fără nicio promoție
  programată automat — decizie de preț/ofertă rămâne a lui Cristi, din
  Furnizor.
- **Stare la commit**: modificate local, NEPUBLICATE încă (necesită
  `git add docs/catalog.json docs/pricing.json && git commit && git push`
  în acest repo) — Claude nu a împins automat o schimbare cu efect
  imediat pe toate aplicațiile client care citesc aceste fișiere live.

## Furnizor v1.31.1 (2026-09-04) — FIX REAL SISTEMIC: publicarea putea șterge tăcut `docs/covers/` întreg

**Raportat de Cristi**: "iarăși a dispărut folderul cu imagini" — toate
cele 14 coperte din `docs/covers/` lipseau de pe disc (confirmat: `git
ls-tree HEAD -- docs/covers/` arăta doar `launch-banner.jpg`).

**Investigație** (nu presupunere — verificat prin `~/.gdc-developer-backup`,
LaunchAgent-ul de backup zilnic către `github.com/gordasgdc/developer-backup`,
creat tot într-un incident anterior legat de CleanMyMac): istoricul acelui
backup arată clar toate cele 14 imagini prezente la 31 aug. 08:49, complet
dispărute de pe disc la 08:50 (un minut mai târziu) — exact tiparul deja
documentat în `CoverImageStore.prepareLocal` (CleanMyMac/Hazel tratează
foldere ca "junk" la scanare, vezi Regula 1). Incidentul s-a repetat 3 sept.:
`git log --diff-filter=D -- "docs/covers/CG Convertor.png"` a dus direct la
commit-ul `9ae47cf "Banner Lansare: activat"` — o acțiune complet neînrudită
cu copertele — care a șters toate cele 14 fișiere în același commit.

**Cauza reală, sistemică**: TOATE cele 24 de apeluri `GitOps.commitAndPush`
din Furnizor (fiecare `Publish*View.swift` + `LaunchBannerEditor`) trec
`paths: ["docs/catalog.json", "docs/covers"]` — `git add docs/covers`
stage-uiește ORICE stare curentă a folderului, inclusiv fișiere dispărute
de pe disc din motive complet neînrudite cu publicarea în curs. Dacă
CleanMyMac ștergea folderul ÎNTRE două publicări, PRIMA publicare
următoare (oricare ar fi fost ea) confirma și trimitea acea ștergere pe
GitHub, tăcut, sub un mesaj de commit fără nicio legătură.

**Fix**: `GitOps.commitAndPush` (`guardAgainstUnexpectedDeletions`) rulează
acum `git status --porcelain` pe path-urile de publicat ÎNAINTE de orice
`git add` — dacă apar mai mult de 2 fișiere șterse neașteptat (o publicare
normală atinge cel mult coperta veche a produsului curent + `previous`),
publicarea se oprește cu o eroare clară, în loc să confirme silențios
ștergerea. O singură gardă, centralizată în `GitOps.swift`, protejează
toate cele 24 de locuri deodată — nu a fost nevoie să ating fiecare
`Publish*View.swift` individual.

**Restaurare**: cele 14 coperte recuperate din ultimul commit bun al
PROPRIULUI repo (`d02904b`, tot de azi) — nimic pierdut ireversibil,
istoricul git chiar a funcționat ca plasă de siguranță aici.

**Rămâne nerezolvat, semnalat explicit lui Cristi**: cine/ce anume șterge
fișierele de pe disc (CleanMyMac e suspectul cu cel mai mult precedent
documentat în acest repo, dar nu confirmat cu certitudine absolută — nu
există un log de sistem care să identifice exact procesul). Recomandare
directă: exclude `~/Developer` din scanările CleanMyMac (Preferences →
Ignore List), și verifică dacă Hazel are vreo regulă activă pe acel folder.
Garda de mai sus previne PROPAGAREA pagubei către git/GitHub de-acum
înainte, dar nu previne ștergerea inițială de pe disc — asta rămâne de
rezolvat la nivel de sistem, nu de cod.

## Client v1.24.2 (2026-08-31) — FIX REAL: textul se suprapunea peste imagine

Raportat direct de Cristi ("vad ca se pune textul peste imagine la mine").
Cauza reală: `imageAspectRatio` era hardcodat la `1248.0/832.0` (imaginea
AI generată inițial). După ce Cristi a republicat o imagine nouă prin
Furnizor (`CoverImagePicker`, preset `.cover` — decupează la un alt raport
de aspect), imaginea REALĂ a devenit `1248x477` — confirmat direct cu
`sips -g pixelWidth -g pixelHeight` pe cache-ul local descărcat de
aplicație. Cu raportul vechi hardcodat, `height`-ul calculat pentru
container nu mai corespundea imaginii reale, iar textul (poziționat
relativ la acel `height` greșit) ajungea suprapus.

**Fix, două părți**:
1. Raportul de aspect se citește DIRECT din `nsImage.size`
   (`Image.Source.Width/Height` pe Windows), niciodată presupus/hardcodat.
2. Voal (gradient) întunecat sub text, INDIFERENT de compoziția imaginii —
   nu ne mai bazăm pe o "bandă goală" anume generată de AI; orice imagine
   viitoare, încărcată prin uploader-ul STANDARD de copertă (folosit și de
   restul catalogului), poate avea orice compoziție/raport de aspect.

**Verificat live**: rebuild+reinstall local + relansare + `grep` pe log
(`view task pornit`, `OK, enabled=true`).

## Client v1.24.1 (2026-08-31) — FIX REAL: bannerul nu se afișa niciodată

Raportat direct de Cristi ("nu apare banerul"). `LaunchOfferBanner.swift`
avea EXACT bug-ul deja documentat la `SeasonalBackgroundLayer`
(2026-08-29): `.task` atașat pe un `Group { if let ... }` — la primul
randaj (`checker.config` încă `nil`), Group-ul n-are niciun copil concret,
SwiftUI nu garantează `.task` pe un gol condiționat. Confirmat DIRECT din
`%TEMP%/gdcpm-crash.log`: zero apeluri "LaunchBanner" în tot log-ul,
deși `UpdateChecker` avea zeci de intrări din aceeași sesiune - deci
task-ul chiar nu pornea niciodată, nu era o problemă de rețea/server.
Fix: `.task` mutat pe `Color.clear.frame(...)` (container concret, mereu
prezent), conținutul real ca `.overlay` suprapus doar când există.
**Verificat live, nu doar cod**: rebuild + reinstall local + relansare +
grep pe log — apar acum "view task pornit" și "OK, enabled=true".

**Lecție de proces**: acest bug exista din commit-ul inițial al
bannerului (v1.22.0) - a scăpat pentru că verificarea de atunci s-a oprit
la "swift build - 0 erori", niciodată la rularea REALĂ + verificarea
log-ului. Un `.task`/`.onAppear` nou, atașat pe orice conținut
CONDIȚIONAT, se verifică de-acum obligatoriu prin rulare + log, nu doar
prin compilare - la fel cum Regula 25 (Log de Diagnostic) există special
pentru genul ăsta de eșec silențios.

## Client v1.24.0 (2026-08-31) — Valabilitate temporală pentru banner

Raportat direct de Cristi ("dar nu pot sa-i dau valabilitate temporala?")
imediat după publicarea v1.23.0: `LaunchBannerConfig` capătă un câmp
`scheduling: Scheduling?` (aceeași struct folosită de tot restul
catalogului, nimic nou de construit) - `isDisplayable` verifică acum și
`scheduling?.isActiveNow ?? true`.

- **Furnizor** - `SchedulingPicker` adăugat în `LaunchBannerManagerView`,
  cu `.id(loadGeneration)` (nu `.id(editingID)` ca la restul view-urilor -
  aici nu există "editare unui item din listă", ci un singur `reload()`
  async la `onAppear`; `loadGeneration` se incrementează o singură dată,
  după ce `scheduling` real e citit din git, forțând `SchedulingPicker`
  să-și re-inițializeze starea cu valoarea reală, nu cu `nil`-ul inițial).
  Fără asta ar fi fost EXACT bug-ul deja documentat și reparat sistemic
  în cele 11 `Publish*View.swift` (Furnizor v1.17.1).
- **Client** (Mac + Windows) - `LaunchOfferBanner`/`LaunchBannerChecker`
  NU au avut nevoie de nicio modificare - `isDisplayable` era deja unicul
  punct de decizie "arăt sau nu bannerul", verificat direct din Core.

**Verificat**: `swift build` (Client + Core + Furnizor) - 0 erori.
`dotnet build ... -r win-x64` (Windows) - 0 erori.

## Client v1.23.0 (2026-08-31) — Banner de lansare, controlabil din Furnizor

v1.22.0 (imagine bundled static in Sources/GDCPluginManager/Resources) a
fost publicat, apoi INLOCUIT la cererea lui Cristi: "eu cum pot controla
imaginea?" - vroia sa poata schimba imaginea/textul singur, oricand, fara
sa ma astepte pe mine sau un rebuild. Port 1:1 al arhitecturii
`PricingCatalog`/Regula 27 (docs/pricing.json), dar pentru un singur
"produs" (nu o lista):

- **`LaunchBannerModel.swift`** (Core, nou) - `LaunchBannerConfig`
  (enabled/imagePath/topText/mainText), decodare tolerantă (fail-open,
  camp lipsa = valoare implicita, niciodata crash).
- **`docs/launch-banner.json`** (nou) - servit static la
  `gordas.dev/launch-banner.json`, scris de Furnizor prin
  `LaunchBannerEditor.swift` (port 1:1 al `PricingEditor.swift` - pull ->
  scrie -> commit+push).
- **Furnizor - panoul "Banner Lansare"** (`LaunchBannerManagerView.swift`) -
  reutilizeaza `CoverImagePicker`/`CoverImageStore.commit(id: "launch-banner")`
  deja existente (acelasi pipeline de compresie + cache-bust prin hash SHA256
  ca orice coperta de produs) - nu s-a scris cod nou de upload.
- **Client - `LaunchBannerChecker.swift`** (nou) - fetch + retry + cache
  local pe disc, port 1:1 al tiparului deja verificat in
  `SeasonalBackgroundLayer` (ContentView.swift): verificare explicita de
  status HTTP (nu doar exceptii), 2 incercari, fallback pe cache offline,
  ascuns complet (nu doar gol) daca nici cache-ul nu exista.
- `LaunchOfferBanner.swift` (view) simplificat la un simplu observator al
  checker-ului - nicio logica de retea in view.

**Verificat**: `swift build` (Client + Core + Furnizor) - 0 erori.

## Client v1.21.0 + Furnizor v1.18.0 (2026-08-31) — Ceas live optional (countdown)

Cerinta explicita a lui Cristi, dupa fix-ul de scheduling de mai jos:
"sa apara ca un ceas cat timp mai este pana dispare", pe modelul deja
existent `PricingPromo.showCountdown` din DataMover (Regula 27), dar
generalizat la ORICE continut din catalog cu valabilitate temporala, nu
doar preturi.

- **`Scheduling.showCountdown: Bool`** (nou, `CatalogModel.swift`) -
  decodare custom (`decodeIfPresent ?? false`) pentru compatibilitate cu
  `catalog.json` existent. `countdownText` computed - "Mai sunt Xz Yh" /
  "Mai sunt Yh Zm" / "Mai sunt Zm", `nil` daca nu se aplica (fara endDate,
  expirat, sau flag-ul OFF). Fara secunde - un ceas la secunda pe zeci de
  carduri simultan e cost UI nejustificat.
- **Furnizor** (`SchedulingPicker.swift`) - toggle nou, vizibil doar cand
  valabilitatea temporala e activa.
- **Client** (`ContentView.swift`) - `CountdownBadge` (nou, reutilizabil,
  `Timer.publish(every: 60)`) inserat in toate cele 11 tipuri de card
  (Plugin/Curs/Resursa educationala/Eveniment/Bundle/Oferta Partener/
  Magazin Partener/Centru Service/Aplicatie/Resursa descarcabila/Audio) -
  insertie facuta printr-un script Python scopat pe fiecare `struct...Card`
  (nu sed global - `PublishDownloadableResourceView`/`PublishEducationalResourceView`
  foloseau AMBELE variabila `resource`, ambiguu pentru un simplu sed).

**Verificat**: `swift build` (Client + Furnizor + Core) - 0 erori.

## Furnizor v1.17.1 (2026-08-31) — fix real de identitate SwiftUI, sistemic

Raportat de Cristi: edita un Eveniment cu valabilitate temporală deja
setată, deschidea Edit, iar comutatorul din `SchedulingPicker` aparea OFF,
ca si cum trebuia setat din nou - desi datele reale ramaneau corecte in
`catalog.json` (bug PUR VIZUAL, nu pierdere de date - CU EXCEPTIA cazului
in care Cristi, nestiind asta, chiar interactiona cu comutatorul/date
picker-ele crezand ca le seteaza din nou - in acel moment `onChange`
suprascria efectiv valoarea reala cu una noua).

**Cauza radacina reala**: `SchedulingPicker.init(scheduling:)` citeste
valoarea curenta a binding-ului o SINGURA data, la primul render al
view-ului - `@State`-ul unui view SwiftUI se initializeaza o singura data,
la crearea instantei, si NU se re-executa doar pentru ca binding-ul extern
s-a schimbat ulterior. Toate cele 11 `Publish*View.swift` (Eveniment,
Curs, Bundle, Oferta Partener, Aplicatie, Audio, Serviciu, Resursa
descarcabila, Resursa educationala, Magazin Partener) folosesc un SINGUR
view persistent per sectiune (nu recreat per-eveniment), cu propriul
`@State private var editingID`/`scheduling` - apasarea "Edit" pe un item
schimba DOAR valoarea acestor @State-uri ale PARINTELUI, dar `SchedulingPicker`
insusi (aceeasi identitate de view, needificata) nu-si re-executa `init`-ul,
deci `isEnabled`/`startDate`/`endDate` interne raman blocate la ce au fost
la primul render (tipic `nil`/false, din starea initiala "eveniment nou").

**Descoperire importanta**: `SeasonalBackgroundView.swift` avea DEJA acest
fix (`.id(config.id)`, cu comentariu explicit "starea interna a picker-ului
e per-intrare") - dintr-o sesiune anterioara, dar NICIODATA propagat la
celelalte 10 fisiere care folosesc aceeasi componenta `SchedulingPicker`.
**Regula practica noua**: cand un fix de tipul asta (bug de identitate
SwiftUI intr-o componenta REUTILIZATA) e gasit si reparat intr-un singur
loc, verifica explicit `grep -rln "NumeComponenta("` pe tot repo-ul inainte
de a declara fix-ul complet - un fix izolat intr-un singur fisier, cand
bug-ul e sistemic in componenta, lasa 9-10 alte locuri sparte identic.

**Fix**: `.id(editingID ?? "new")` adaugat pe fiecare apel `SchedulingPicker(
scheduling: $scheduling)` in toate cele 10 fisiere ramase - forteaza SwiftUI
sa arunce instanta veche si sa creeze una noua (deci sa ruleze `init` din
nou, cu valoarea REALA curenta) de fiecare data cand `editingID` se schimba
(intre "adauga nou" si "editeaza X", sau intre editarea a doua iteme
diferite consecutiv).

**Verificat**: `swift build --product GDCPluginManagerFurnizor` - 0 erori.
**Nu s-a testat inca manual, live** - Cristi urmeaza sa confirme ca, la
editarea unui Eveniment cu valabilitate deja setata, comutatorul apare
acum corect ON cu datele reale precompletate.

## Stare curentă (2026-08-31) — versiune Client `1.20.1`

- **Fix real, gasit de Cristi**: eticheta „Actualizare disponibilă” din
  „Aplicațiile mele” persista dupa un update real, pana la o repornire
  completa a GDC Plugin Manager. Cauza: `Bundle(url:)` (`MyAppsLauncher.
  swift`, `refresh()`) cache-uieste `infoDictionary`-ul intern pentru toata
  durata procesului - o citire ulterioara din ACELASI proces (Refresh
  inclus) intorcea versiunea VECHE, indiferent ca fisierul `Info.plist` de
  pe disc se schimbase. Fix: `readInfoPlistVersion()` citeste plist-ul
  DIRECT (`PropertyListSerialization`), ocolind `Bundle` complet - nu mai
  are cache, Refresh reflecta mereu starea reala de pe disc. **Regula
  practica noua**: orice cod care citeste versiunea unei aplicatii TERTE
  instalate (nu a propriului bundle) foloseste citire directa de plist,
  niciodata `Bundle(url:)`/`Bundle(path:)` - cache-ul acelei clase e gandit
  pentru bundle-ul PROPRIU al procesului, nu pentru monitorizarea altor
  aplicatii care se pot schimba pe disc in timp ce procesul curent ruleaza.

## Stare curentă (2026-08-29) — versiune Client `1.19.8`

- **Fix real, găsit din log**: retry-ul de filigran sezonier nu reîncerca
  la un 404 tranzitoriu de CDN (`URLSession.shared.data(from:)` nu aruncă
  pe status HTTP de eroare, doar pe eșec de transport) — reparat cu
  verificare explicită de status + `continue` în loc de `break`.
  **Regulă practică**: orice fetch nou pe Mac verifică manual
  `HTTPURLResponse.statusCode`, nu se bazează pe excepții.
- **Windows, în paralel**: bug critic de imagini (WinINet vs HttpClient)
  rezolvat în v1.19.7; v1.19.8 adaugă logare completă a lanțului de
  `InnerException` pentru diagnosticarea unui eșec SSL încă nerezolvat
  (posibil ceas de sistem greșit în VM Parallels) — vezi
  `GDCPluginManagerWin/CLAUDE.md`.
- Detalii complete: `CLAUDE_ARCHIVE.md` (ultimele 2 intrări) sau
  `CHANGELOG.md` (`Client v1.19.7`/`v1.19.8`).

## Etapa 2026-09-11 — Sistem universal de acces/filtrare/grupare (`CatalogAccess`)

Cerut de Cristi: aceleași badge-uri de status/preț, aceeași bară de filtre și
aceleași grupuri/etichete în TOATE secțiunile, nu doar la Aplicații. Plan
aprobat explicit înainte de implementare (analiza modelelor → structură comună
→ componente UI → compatibilitate).

**Ce a găsit auditul modelelor (verificat în cod, nu presupus)**: existau deja
PATRU dialecte diferite de „e gratuit?" — `PluginItem.isFree`+`priceEUR`,
`DownloadableResource.isFree`+`priceEUR`, `Course.accessType`+`options[]`,
`AppLink.pricingProductID`→`pricing.json` — plus `ProductBundle.bundlePriceEUR`
fără noțiune de gratuit, și TREI dialecte de categorie (enum tipizat, String
liber la `Tutorial`, sau nimic). Problema reală nu era lipsa câmpurilor, ci
fragmentarea lor.

**Decizia de arhitectură**: `CatalogAccess` e un strat **DERIVAT**, nu paralel.
Dacă ar fi stocat și el un `isFree`/`kind` peste cele existente, s-ar fi creat
exact a doua sursă de adevăr interzisă de Regula 30.

**REGULA DE PRECEDENȚĂ** (unică, explicită, aplicată în `resolvedAccess`):
1. Câmpul NATIV al modelului câștigă ÎNTOTDEAUNA.
2. `access.kind`/`referencePriceEUR` se consultă DOAR dacă modelul n-are nativ
   acea informație.
3. `group`/`tags`/`note` sunt pur aditive — nu există nicăieri azi.

Practic: `PluginItem` NU primește niciodată un `kind` propriu. În Furnizor,
`AccessEditorSection(showsKind: false)` pentru secțiunile cu câmp nativ —
un al doilea selector acolo ar fi fost fix bug-ul de evitat.

`isFree == nil` înseamnă NECUNOSCUT, deliberat: un element fără informație de
preț apare doar la „Toate", niciodată clasificat greșit ca „premium".

**Decizii explicite ale lui Cristi**: (1) `Tutorial.category` rămâne `String`
liber — etichetele din `access` îl COMPLETEAZĂ (reunite fără duplicate în
`Tutorial.resolvedAccess`), nu îl înlocuiesc; (2) câmpurile adăugate inițial
direct pe `AppLink` (`accessType`/`tags`/`group`) au fost mutate sub
`CatalogAccess` înainte de orice publicare, pentru uniformitate din start.

**Eliminare de cod duplicat**: `PriceFilter`/`OSFilter` trăiau în
`ContentView.swift` și erau copiate, cu propriul `@State` și propriile
`Picker`-e, în fiecare secțiune (14 apariții). Înlocuite cu
`CatalogFilterBar.swift` — `CatalogFilterState` + `CatalogFilterBar` +
`AccessBadge`/`AccessPriceLabel`/`AccessTagsRow` + `FilteredCatalogSection`
(înfășoară o secțiune întreagă prin shadowing pe numele colecției, deci
corpul vechi al fiecărui grid rămâne neschimbat).

**Compatibilitate — verificat pe catalogul LIVE real, nu presupus**: 14
aplicații + 3 plugin-uri + 1 tutorial de pe `gordas.dev/catalog.json`,
decodare + round-trip, zero regresie. Test separat al precedenței: un plugin
cu `isFree=true` nativ ȘI `access.kind=.paid`/999 € → nativul câștigă, 999 €
ignorat, tag-urile/grupul preluate. `CatalogAccess` are decodor explicit
(`tags` e array non-optional); modelele primesc doar un `access` Optional,
deci Codable-ul sintetizat le acoperă — cele 7 cu decodor custom au primit
linia manual.

**Fără migrare de date**: catalogul existent rămâne valid byte-for-byte;
Furnizorul scrie `access` doar la următoarea editare a fiecărui element.

Versiuni: Client 1.29.2 → **1.30.0**, Furnizor 1.32.0 → **1.33.0** (MINOR,
Regula 14 — funcționalitate nouă vizibilă). Windows: vezi `GDCPluginManagerWin`.

## Etapa 2026-09-11 (2) — Furnizor 1.34.0: etichete cu selecție + autocompletare

Cerut de Cristi imediat după livrarea sistemului de etichete: *"tot ce introduc,
tag-uri sau chiar și nume, să-mi apară sau să se autocompleteze când încep să
scriu ceva și deja a mai fost scris... sau la tag-uri să am posibilitatea să le
aleg pur și simplu"*.

**Infrastructura exista deja** — `AutocompleteTextField.swift` (2026-08-29,
aceeași cerință, pentru locații/adrese/branduri). Nu s-a inventat un tipar nou:
s-a extins cel existent, cu aceeași decizie de fond — **fără store propriu de
istoric**, sursa de sugestii e catalogul publicat, nu un fișier local paralel
care ar putea diverge.

**`AccessTagsEditor` (nou)** — selecție multiplă pentru `CatalogAccess.tags`:
etichetele alese apar ca „chips" cu x, cele deja folosite oriunde în catalog
apar ca butoane sub câmp (un click le adaugă), iar la tastare se filtrează cu
`FuzzySearch`. Sursa de adevăr rămâne `tagsText` (același `String` ca în model)
— se parsează/recompune, fără o a doua stare care ar putea diverge de formular.
Duplicatele se elimină case-insensitive, deci „Emulare Film" și „emulare film"
nu mai pot coexista ca etichete distincte. Folosit automat de toate cele 11
panouri, fiind în `AccessEditorSection`.

**`CatalogTagIndex`** — colectează etichetele din TOATE cele 12 colecții prin
`resolvedAccess`, plus `loadValues(_:)` pentru orice câmp text repetitiv.

**`FlowRow`** — `Layout` propriu, cu revenire pe rând nou: `HStack` ar tăia
etichetele care nu încap, iar `LazyVGrid` cere coloane de lățime fixă (etichetele
au lățimi foarte diferite). SwiftUI n-are FlowLayout nativ pe macOS 14.

**`TagSuggestionsRow`** — pentru `PublishTutorialView`, care are deja propriul
editor de tag-uri (`TagChipsFlow`, câmpul nativ `Tutorial.tags`): nu i s-a
înlocuit editorul, doar i s-au adăugat sugestiile.

**Autocompletare adăugată la**: `Tutorial.category` (String liber, cel mai
repetitiv câmp din catalog), `Course.formatLabel`, etichetele opțiunilor de
curs, și `AppLink.pricingProductID` — ultimul sugerat din `pricing.json` REAL
(`PricingEditor.load()`), nu din catalog: o literă greșită acolo rupea tăcut
legătura prețului dinamic, fără niciun avertisment.

Versiune: Furnizor 1.33.0 → **1.34.0** (MINOR). Clientul rămâne 1.30.0 —
schimbarea e strict în panoul de publicare, nu atinge nimic la client.

## Etapa 2026-09-12 (v1.30.1) — „Aplicațiile mele": avizul de actualizare nu dispărea

Raportat de Cristi: în „Aplicațiile mele", avizul „există actualizare" rămânea
aprins și DUPĂ ce actualizarea fusese instalată — cel mai vizibil la
DisplayCAL-CG.

**Cauza, verificată direct pe mașina reală, nu presupusă — DOUĂ defecte care se
compun:**

1. **Versiunea instalată se citea din alt loc decât cea publicată.**
   `readInfoPlistVersion` citea `CFBundleShortVersionString`, care pentru
   DisplayCAL-CG păstrează versiunea proiectului ORIGINAL (`3.10.0.dev82`) —
   numărul de build GDC stă separat, în `Contents/Resources/CG_BUILD` (`3`).
   Tag-ul publicat e însă `v3.10.0.dev82-cg.3`. Comparația se făcea deci între
   `3.10.0.dev82` și `3.10.0.dev82-cg.3`: două forme ale ACELEIAȘI versiuni,
   care nu puteau ieși egale niciodată.

   Dovadă, rulată pe bundle-ul instalat:
   ```
   citire VECHE (doar Info.plist): 3.10.0.dev82
   citire NOUA (VERSION+CG_BUILD):  3.10.0.dev82-cg.3
   tag publicat:                    v3.10.0.dev82-cg.3
   ```

2. **Comparatorul elimina componentele netextuale în loc să le păstreze pe
   poziție.** `a.split(".").compactMap { Int($0) }` nu ignoră „dev82-cg" — îl
   **scoate din listă**, urcând ce vine după el cu o poziție. Pe
   `3.10.0.dev82-cg.3` rezulta `[3, 10, 0, 3]`, unde `3`-ul final e numărul de
   build ajuns pe poziția a patra de versiune, comparat cu `[3, 10, 0]` al
   versiunii instalate → „3 > 0" → actualizare disponibilă permanent.

**Reparat:**
- `MyAppEntry.installedVersionSource` (`.infoPlist` implicit,
  `.versionPlusCGBuild` pentru DisplayCAL-CG) — versiunea instalată se compune
  în exact forma tag-ului: `<VERSION>-cg.<CG_BUILD>`. Fișierele se citesc direct
  de pe disc, fără `Bundle`, din același motiv documentat deja pentru
  `readInfoPlistVersion`: fără cache, deci avizul dispare imediat după
  actualizare, fără repornirea aplicației.
- `isNewer` desparte explicit nucleul de build-ul GDC și compară componentele
  pe poziția lor reală (numeric unde ambele sunt numere, altfel textual, ordonat
  natural). Fără `-cg.`, comportamentul rămâne identic cu cel de dinainte.
- Verificat cu 10 cazuri reale din ecosistem (DisplayCAL egal/mai nou/mai vechi,
  nucleu mai nou vs build mai mare, DataMover, CGConvertor, CursorPro, Plugin
  Manager, plus o capcană lexicală `2.0.0` vs `10.0.0`) — toate trec.

**Paritate Windows (Regula 31)**: `VersionCompare.IsNewer`
(`GDCPluginManagerWin`) nu avea bug-ul de *eliminare* — `Parse` mapează
componentele netextuale la `0`, deci nu decalează pozițiile — dar avea aceeași
slăbiciune de fond: un `-cg.N` ar fi bătut un nucleu egal, pe o poziție de
versiune. Portat `SplitBuild` + tie-break pe build. DisplayCAL-CG nu e încă
listată în clientul Windows, deci acolo defectul era latent, nu vizibil.
`dotnet build` pe Core: 0 erori.

**Regula 35 respectată la bump**: `docs/update.json` are Mac la `1.30.1` și
Windows la `1.30.0` (nimic livrat pe Windows acum), iar câmpul de la rădăcină —
cel citit de clienții ≤1.27 pentru AMBELE platforme — a fost pus la MINIMUL
dintre ele (`1.30.0`), nu la maxim.

### Adăugat la publicarea 1.30.1 — două găuri de proces în scripturile de build

Găsite chiar în timpul acestei publicări, nu raportate de nimeni:

1. **`build_app.sh` semna TĂCIT cu certificatul local auto-semnat
   `"CursorPro"`** — numele altei aplicații, copiat aici și rămas
   nesincronizat (exact tiparul din regula „zero drift de identitate între
   repo-uri"). Efectul real, verificat: primul build al acestei sesiuni a
   înlocuit `/Applications/GDCPluginManager.app` cu un binar semnat
   `Authority=CursorPro, TeamIdentifier=not set`, iar `build_installer.sh` a
   împachetat exact acel binar. Acum scriptul caută identitatea reală din
   breloc și **eșuează** dacă nu o găsește; fallback-ul auto-semnat cere
   `GDCPM_ALLOW_SELFSIGNED=1`.
2. **`build_installer.sh` producea liniștit un `.pkg` NESEMNAT** când
   `APPLE_SIGN_IDENTITY_APP` nu era exportată. Mesajul „sar peste semnare"
   apărea la mijlocul unui log de sute de linii — l-am ratat prima dată și
   pachetul nesemnat era gata de urcat pe release, o regresie față de v1.30.0
   care e semnat + notarizat. Adăugată o gardă finală care verifică semnătura
   pachetului rezultat și oprește scriptul cu instrucțiunile exacte;
   ocolibilă doar explicit, cu `GDCPM_ALLOW_UNSIGNED_PKG=1`.

Ambele identități există în brelocul mașinii (`Developer ID Application` și
`Developer ID Installer`), iar notarizarea locală merge prin profilul salvat
`gdc-notary` — nu lipsea nimic, doar nu erau exportate variabilele. De aceea
garda e la nivel de script, nu o notă în jurnal.

## Etapa 2026-09-14 (Furnizor v1.34.1) — publicarea eșua pe `git pull --ff-only`

Raportat de Cristi cu captură din Furnizor, la publicarea unui produs nou
(LUT „ProGDC"): panoul arăta în roșu

```
git pull --ff-only a eșuat:
There is no tracking information for the current branch.
```

**Cauza reală, verificată direct pe disc, nu presupusă:** în
`~/Developer/gdc-plugin-manager-files`, ramura `main` **nu avea upstream
configurat** (`git rev-parse --abbrev-ref @{u}` → `fatal: no upstream
configured`). `GitOps.pull` rula `git pull --ff-only` fără argumente, care
depinde exclusiv de configurația de tracking a ramurii locale — lipsă ea,
comanda eșuează înainte de orice acces la rețea. Nu era o problemă de
autentificare, de rețea sau de GitHub.

Aceeași slăbiciune o avea și `push` (tot fără remote/ramură explicite), deci ar
fi eșuat imediat după, chiar dacă pull-ul ar fi trecut.

**Reparat în cod** (`GitOps.swift`):
- `currentBranch(at:)` nou — citește ramura cu `rev-parse --abbrev-ref HEAD`.
- `pull` → `git pull --ff-only origin <ramură>`; `push` → `git push -u origin
  <ramură>`. Explicit, deci independent de configurația locală.
- `-u` la push **repară singur** configurația lipsă la prima publicare
  reușită — un checkout pornit greșit nu rămâne defect până când cineva rulează
  manual `git branch --set-upstream-to`.

**Dovada că fix-ul ține**, pe o clonă de test căreia i-am scos intenționat
upstream-ul:
```
comanda VECHE : There is no tracking information for the current branch.
comanda NOUĂ  : * branch main -> FETCH_HEAD / Already up to date.
```

**Reparat și pe disc**, ca să poată publica imediat: `git branch
--set-upstream-to=origin/main main` în `gdc-plugin-manager-files`.

**Două lucruri găsite pe drum** (Regula 30):
- `.DS_Store` era **urmărit** în `gdc-plugin-manager-files`, iar publicarea
  face `git add -A` acolo — fiecare produs publicat căra după el și o
  modificare de `.DS_Store`, într-un commit fără nicio legătură cu ea.
  Adăugat `.gitignore` și scos din urmărire.
- `build_furnizor_app.sh` semna necondiționat cu certificatul local
  auto-semnat `"CursorPro"` — exact tiparul de identitate copiată din alt
  repo, reparat deja în `build_app.sh` (2026-09-12). Acum caută întâi
  `Developer ID Application` din breloc; auto-semnatul cere
  `GDCPM_ALLOW_SELFSIGNED=1`.

Verificat (Regula 0): versiunea **INSTALATĂ** din
`/Applications/GDC Plugin Manager Furnizor.app` e `1.34.1`, semnată
`Developer ID Application: ... (8AR6XP8MG7)`.

## Etapa 2026-09-14 (Client 1.31.0 / Furnizor 1.35.0) — PDF-uri cu upload și descărcare directă

Cerut în 3 etape; asta e **Etapa 1**. Etapele 2 (categoria „Scripts" pentru
Resolve) și 3 (optimizare pentru versiunile noi de Resolve) rămân de făcut.

### Ce s-a construit

`DownloadCategory` capătă `pdf`; `DownloadableResource` capătă `filePath`,
`fileSHA256` și `pdfKind` (`PDFKind`: instrucțiuni audio / ghid tehnic / carte
/ manual). Când `filePath` există, clientul descarcă fișierul din repo-ul privat
prin ACELAȘI mecanism autentificat ca produsele Resolve
(`InstallManager.fetchPrivateFileData`) — nu s-a scris un al doilea mecanism de
descărcare — verifică SHA-256, salvează în folderul ales de user
(`DownloadLocationStore`, implicit `~/Downloads`) și deschide Finder pe fișier.
**Fără browser** (Regula 20). Link-ul extern rămâne posibil, ca variantă.

În Furnizor, calea e `<id>/pdf/<nume>.pdf` (fără versionare — decis explicit cu
Cristi: un ghid nu are nevoie de istoric de versiuni), iar fișierul urcă
ÎNAINTE de catalog, ca la copertele de produs — altfel catalogul ar referi un
fișier încă nepublicat.

### DEFECT GRAV EVITAT ÎN ULTIMUL MOMENT — de reținut

Planul inițial (aprobat) era `category: "pdf"` în array-ul existent
`downloadableResources`. **Verificat experimental înainte de a publica ceva**,
cu modelul exact al clienților deja livrați:

```
CATALOGUL INTREG A PICAT: DecodingError.dataCorrupted
  Path: downloadableResources[1].category
  Cannot initialize OldCategory from invalid String value pdf
```

Un enum Swift simplu **aruncă** la o valoare necunoscută, iar eroarea urcă până
la `Catalog` — deci o singură resursă PDF publicată ar fi lăsat **fiecare client
instalat fără NIMIC**: nici produse, nici cursuri, nici aplicații. Convertorul
C# de pe Windows era și mai explicit: `throw new JsonException("Unknown
DownloadCategory")`. Exact tiparul Regulii 35, dar cu efect total, nu tăcut.

**Soluția, verificată la rândul ei:** PDF-urile stau într-o **cheie nouă de
nivel superior**, `catalog.pdfResources`, cu același tip de date. Decodoarele
vechi ignoră pur și simplu cheia necunoscută:

```
CLIENT VECHI: decodat OK, vede 1 resursa — cheia noua ignorata
```

Zero risc pentru cine n-a actualizat. **Regulă practică de reținut pentru tot
ecosistemul: o valoare NOUĂ într-un enum deja publicat rupe clienții vechi; o
CHEIE nouă nu.** Când ai de ales, adaugi o cheie.

Suplimentar, `DownloadCategory` are acum `unknown` ca plasă de siguranță
(exclus din `allCases`, deci invizibil în UI), iar convertorul C# nu mai aruncă
— ca următoarea categorie să degradeze la „o resursă pe care versiunea asta
n-o afișează", nu la un catalog mort.

### Paritate Windows (Regula 31)

Model, convertoare JSON, `Catalog.PdfResources`, `CatalogService.PdfResources` și
colecția `MainViewModel.DownloadPdfs` — portate și compilate (`dotnet build`: 0
erori, atât Core cât și Client WPF).
**RĂMÂNE DE FĂCUT pe Windows**: fila din XAML care afișează `DownloadPdfs` și
butonul de descărcare directă. Nu am scris XAML pe care nu-l pot vedea randat;
partea de date e completă, deci e un pas mic.

### Verificat

Pe catalogul REAL publicat: se decodează neschimbat cu modelul nou (3 produse,
1 resursă, 0 PDF-uri). Dus-întors pe o resursă PDF sintetică: `filePath`,
`pdfKind`, `hasDirectFile` și numele fișierului se păstrează corect. Versiuni
INSTALATE confirmate (Regula 0): Client `1.31.0`, Furnizor `1.35.0`.

## REGULĂ DE ARHITECTURĂ (2026-09-14): compatibilitate de catalog & stocare multi-repo

Două reguli care se aplică de acum înainte oricărei extinderi de catalog, în tot
ecosistemul (Mac + Windows).

### 1. O VALOARE nouă într-un enum publicat rupe clienții vechi. O CHEIE nouă, nu.

Dovedit experimental, nu presupus, cu modelul exact al clienților deja livrați:

```
CATALOGUL INTREG A PICAT: DecodingError.dataCorrupted
  Path: downloadableResources[1].category
  Cannot initialize OldCategory from invalid String value pdf
```

Un enum Swift simplu **aruncă** la o valoare necunoscută, iar eroarea urcă până
la `Catalog` — deci o singură intrare nouă lasă clientul instalat **fără nimic**:
nici produse, nici cursuri, nici aplicații. Convertorul C# de pe Windows arunca
la fel de explicit (`throw new JsonException("Unknown ...")`). O cheie nouă de
nivel superior e, în schimb, pur și simplu ignorată de decodoarele vechi:

```
CLIENT VECHI: decodat OK, vede 1 resursa — cheia noua ignorata
```

**Regula practică**: când adaugi un tip/o categorie nouă de conținut,
- pui elementele într-o **cheie nouă de nivel superior** (`pdfResources`,
  `scriptItems`), nu într-un array existent;
- adaugi în paralel un caz `unknown` la enum (exclus din `allCases`, invizibil
  în UI) și faci convertoarele să **degradeze**, nu să arunce.

Cazuri existente: `Catalog.pdfResources` (PDF-uri), `Catalog.scriptItems`
(scripturi Fusion). `DownloadCategory.unknown` și `PluginType.unknown` sunt
plasele de siguranță.

### 2. Stocare multi-repo: fiecare tip de resursă în repo-ul lui privat

Un singur repo de fișiere ajunge la limite de dimensiune și face descărcările să
concureze între ele. De aceea fișierele se distribuie:

| cheie | repo | conținut |
|---|---|---|
| `files` | `gdc-plugin-manager-files` | LUT, DCTL, Fuse, OFX, PowerGrade |
| `pdfs` | `gdc-plugin-manager-pdfs` | ghiduri, manuale, cărți |
| `scripts` | `gdc-plugin-manager-scripts` | scripturi Lua/Python pentru Fusion |

Cheia se scrie în catalog pe fișier (`PluginFile.repo`) sau pe resursă
(`DownloadableResource.fileRepo`). **`nil` înseamnă repo-ul principal**, deci tot
ce e publicat până acum rămâne valid fără nicio migrare. Maparea cheie → repo
trăiește într-un singur loc pe fiecare platformă: `PrivateCatalogAuth.repos`
(Swift) și `PrivateCatalogAuth.Repos` (C#). Furnizor rezolvă checkout-ul local
prin `RepoCheckoutPaths.resourceCheckout(for:)`, care **eșuează explicit** dacă
clona lipsește, în loc să creeze un folder gol și să eșueze mai departe.

Token: **un singur PAT fine-grained**, `Contents: Read-only` pe toate cele trei
repo-uri (decis explicit — mai ușor de rotit decât trei). Structura suportă și
token per repo, dacă se schimbă vreodată decizia.

**INVARIANT OBLIGATORIU**: o resursă stocată într-un repo secundar trebuie să
stea într-o cheie de catalog pe care clienții vechi **nu o citesc**. Altfel un
client vechi ar vedea resursa, ar ignora câmpul `repo` necunoscut și ar căuta
fișierul în repo-ul principal, unde nu există — eșec de descărcare în loc de
degradare curată. PDF-urile și scripturile respectă condiția prin construcție.

## Etapa 2026-09-14 (Etapa 2) — categoria „Scripts" pentru DaVinci Resolve

`PluginType.scripts`, cu fișierele în `gdc-plugin-manager-scripts` și intrările
în `catalog.scriptItems`.

**Verificat pe o instalare reală de Resolve, nu din documentație:**
- Calea corectă pe macOS e `~/Library/Application Support/Blackmagic Design/
  DaVinci Resolve/Fusion/Scripts` — **nivel utilizator**. `Support/Fusion/Scripts`
  din cerință e layout-ul de **Windows**; pe macOS nu există.
- Subfolderele reale sunt **șapte**: `Comp`, `Tool`, `Utility`, `Edit`, `Color`,
  `Deliver`, `Coding` — nu trei. Modelate în `ScriptFolder`, implicit `Utility`.
- Folderul e `drwxrwxrwx`, deci **instalarea unui script NU cere parolă de
  administrator** — singurul tip din catalog cu această proprietate. `writeFile`
  încearcă oricum scrierea directă întâi și escaladează doar la eșec, deci nu a
  fost nevoie de nicio ramură specială.

Scripturile NU intră într-un subfolder numit după `id` (cum fac pack-urile de
LUT/DCTL): Resolve construiește meniul Scripts din exact cele 7 subfoldere, iar
un folder în plus ar însemna un submeniu în plus, cu numele produsului. Un pachet
urcat cu structură proprie (`Utility/X.lua`) și-o păstrează, prin
`relativeInstallPath`.

**Verificat direct pe mașină**: cele trei subfoldere testate (`Utility`, `Comp`,
`Deliver`) există și sunt scriabile; un `type` necunoscut decodează la `unknown`
în loc să dărâme catalogul; un fișier vechi fără câmp `repo` cade corect pe
repo-ul principal.

## Etapa 2026-09-14 (Etapa 3) — verificare post-instalare & compatibilitate cu Resolve 21

### 1. Instalarea reușită nu spunea NIMIC

`ContentView` avea literalmente `case .installed: break` — după o instalare
reușită de LUT/DCTL/Fuse/OFX/Script, userul nu primea nicio confirmare și,
mai ales, nu afla **unde** a ajuns fișierul. Singurele tipuri cu feedback erau
PowerGrade-urile (import în Gallery).

Reparat: `InstallOutcome.installed` poartă acum **căile reale**, iar cardul
arată „Instalat în ~/Library/…" plus un buton care deschide Finder pe fișier.

### 2. Verificare reală după scriere, nu „n-a aruncat, deci a mers"

Scrierea se putea încheia fără excepție și fără ca fișierul să fie întreg la
destinație: pe calea elevată copierea o face un proces separat (`osascript`),
iar un disc plin sau o copiere parțială nu se vedeau nicăieri. Acum, după
scriere, fiecare fișier e confirmat pe disc: **există** și are **aceeași
dimensiune** ca sursa temporară.

Nu se recalculează SHA-ul la destinație: octeții au fost deja verificați
criptografic ÎNAINTE de scriere, iar singurul pas dintre ei și disc e copierea
— o copiere trunchiată se vede ca diferență de dimensiune. Verificat pe fișiere
reale:

```
1. copiere corecta -> TRECE
2. trunchiat -> PRINS: dimensiune diferita (1200 in loc de 5000)
3. lipsa     -> PRINS: fisierul nu exista dupa instalare
```

Eroarea nouă (`verificationFailed`) spune EXACT ce și unde, nu „a eșuat".

### 3. Coliziuni de nume și resturi de la versiunea anterioară

Un pack reinstalat peste o versiune mai veche lăsa în urmă fișierele care nu
mai existau în versiunea nouă (un DCTL scos din pachet rămânea încărcat de
Resolve la nesfârșit). Acum folderul produsului se curăță înainte de scriere.

**EXCEPȚIE CRITICĂ, nu o scăpare — scripturile.** Destinația lor
(`Fusion/Scripts/Utility` etc.) e un folder COMUN al Resolve-ului, în care stau
și scripturile utilizatorului sau ale altor furnizori. O ștergere de folder
acolo ar distruge munca lui. De aceea condiția e `item.isPack && item.type !=
.scripts` — „folderul îmi aparține mie", nu „e un pack". Pentru scripturi,
coliziunea se rezolvă la nivel de fișier: `writeFile` șterge fișierul existent
înainte de copiere, deci suprascrierea e curată, fără să atingă vecinii.

### 4. Compatibilitate cu build-urile noi de Resolve — VERIFICAT, nimic de schimbat

Două verificări independente, niciuna presupusă:

- **Changelog-ul oficial, 25 de versiuni** (19.0.1 → 21.0.4), filtrat după
  LUT/DCTL/OFX/Fuse/Scripts/Gallery: **nicio schimbare de structură de
  directoare**. Schimbările pe DCTL sunt de funcționalitate (color picker,
  ACES 2.0, criptare în LUT browser), nu de amplasare.
- **Instalarea reală de pe această mașină (Resolve 21.1.0)** — toate cele cinci
  căi există și sunt populate:

```
/Library/.../DaVinci Resolve/LUT              42 intrari
/Library/.../DaVinci Resolve/LUT/DCTL         29 intrari
/Library/.../DaVinci Resolve/Fusion/Fuses      0 intrari
/Library/OFX/Plugins                          19 intrari
~/Library/.../Fusion/Scripts                   7 intrari
```

Concluzie: modulele de instalare NU au nevoie de ajustări pentru versiunile
noi. Dacă Blackmagic schimbă vreodată structura, `PluginType.installDirectory`
e singurul loc de modificat — o verificare pe disc, ca cea de mai sus, o va
prinde.

## Etapa 2026-09-14 (Client 1.34.0 / Furnizor 1.37.0) — pachete întregi + categorie de scripturi generale

Raportat direct: „am încercat să încarc un folder de LUT-uri și mă pune să
selectez fiecare fișier în parte".

### Două defecte, al doilea nesesizat de nimeni

1. **Selectorul accepta un singur fișier.** `canChooseDirectories = false`,
   `allowsMultipleSelection = false` — un pachet de zeci de LUT-uri ar fi
   trebuit urcat bucată cu bucată. Acum acceptă un fișier, mai multe fișiere
   SAU un folder întreg, cu subfolderele păstrate exact.
2. **Repo-ul de destinație era hardcodat `"pdfs"`** — scris la Etapa 1, când
   singurul caz era PDF-ul. Un pachet de LUT-uri urcat prin acel formular ar fi
   ajuns în repo-ul de PDF-uri. Acum destinația se alege după categorie:

| categorie | repo |
|---|---|
| `pdf` | `gdc-plugin-manager-pdfs` |
| `script` | `gdc-plugin-manager-scripts` |
| restul (LUT/SFX/VFX/Plugin) | `gdc-plugin-manager-resources` (**nou**) |

Arhiva principală de produse nu mai primește nimic din zona de resurse
descărcabile — exact cerința: „să nu încărcăm arhiva cu dimensiunea".

### Model: resursă cu MAI MULTE fișiere

`DownloadableResource.files: [PluginFile]` (implicit `[]`). Când e nevidă, are
prioritate față de `filePath`, care rămâne pentru resursele cu un singur fișier
deja decodate de clienții 1.31+. Structura relativă se păstrează la urcare ȘI
la descărcare: un pachet ajunge la user într-un folder propriu, cu subfolderele
lui; un fișier singur rămâne un fișier, direct în Descărcări.

### Categorie nouă: `DownloadCategory.script`

Scripturi de uz general (optimizare de sistem, automatizări) — **fără legătură
cu DaVinci Resolve**, deci distinctă de `PluginType.scripts`, care
auto-instalează în `Fusion/Scripts`. Astea se descarcă, atât.

Compatibilitatea Mac/Windows/ambele **nu a cerut niciun câmp nou**:
`DownloadableResource.supportedOS` există deja și e afișat pe card.

Cheie nouă de catalog `scriptResources`, după aceeași regulă documentată mai
sus (o valoare nouă de enum rupe clienții vechi, o cheie nouă nu).

### Verificat

```
1. Catalog real OK — 1 resurse, 2 PDF, 0 scripturi
2. Pachet: 3 fisiere | descarcare directa=true | repo=resources
     Cinematic/warm.cube
     Cinematic/cold.cube
     README.txt
3. Script: categorie=script sistem=macOS fisiere=1
4. Forma veche: fisiere=1 nume=x.pdf directa=true
5. Categorie necunoscuta -> unknown
```

Cele două PDF-uri deja publicate de Cristi sunt în `pdfs`, corect — nu necesită
migrare.

**DE FĂCUT de Cristi**: repo-ul `gdc-plugin-manager-resources` trebuie adăugat
în lista de acces a PAT-ului existent (Settings → token → Repository access).
Valoarea token-ului NU se schimbă, deci nu e nevoie de regenerare și nici de
reconstruit aplicațiile. Până atunci, descărcările din acel repo dau 401.

### Notă tehnică

`CatalogEditor.write()` a depășit pragul de type-check al compilatorului Swift
(„unable to type-check this expression in reasonable time") la 17 argumente cu
`??`. Desfăcut în variabile intermediare — rezultat identic, compilează.

## Etapa 2026-09-14 (Furnizor 1.38.0) — refolosirea fișierelor + ștergeri independente

Cerut direct: „vor fi multe lucruri care se vor regăsi identic" și „dacă vreau
să-l șterg din resurse, să nu fie afectat DaVinci, și invers".

### Refolosirea fișierelor unui produs deja publicat

`ResourceFileSource` capătă a treia variantă, `.reuseProduct`. În loc să reîncarci
aceleași fișiere, alegi un produs publicat și resursa **leagă exact fișierele
lui** — aceleași căi, același repo. Nu se urcă niciun octet.

Motivul concret: aceleași LUT-uri se oferă și auto-instalabile pentru Resolve, și
descărcabile pentru Premiere/Final Cut. Reîncărcarea le stoca de două ori.
Verificat pe ProGDC: cele 6 fișiere aveau SHA-uri identice în ambele locuri.

`DownloadableResource.sourceProductID` reține de unde vin. Clientul nu-l
folosește deloc — fiecare fișier își poartă deja calea și repo-ul — dar Furnizor
îl afișează (🔗 în lista de resurse) și permite o resincronizare ulterioară.

### Ștergerile sunt independente, în ambele direcții

Una din direcții era deja sigură; cealaltă NU:

| Acțiune | Înainte | Acum |
|---|---|---|
| Ștergi **resursa** | produsul neatins ✓ | neschimbat ✓ |
| Ștergi **produsul** | `removeItem(<id>/)` ștergea folderul din repo — o resursă legată rămânea cu descărcări moarte ✗ | fișierele rămân dacă le mai folosește cineva ✓ |

`CatalogEditor.resourcesUsingProductFiles(id:in:)` verifică ambele forme de
legătură: `sourceProductID` explicit, și calea `<id>/…` pentru resurse publicate
înainte de câmp.

**Regula e cale + repo, nu doar cale.** Prima variantă compara numai calea și
dădea fals pozitiv: resursa ProGDC are propria copie, cu aceeași cale `ProGDC/…`,
dar în repo-ul `resources`, nu `files`. Ar fi păstrat pe veci fișiere pe care
nimeni nu le mai folosește. Verificat pe catalogul real după corecție:

```
Intermediate Workflow [repo files] -> fisierele SE STERG
LiniarWorkflow        [repo files] -> fisierele SE STERG
ProGDC                [repo files] -> fisierele SE STERG
caz legat (sourceProductID)        -> RAMAN, folosite de: ProGDC pentru FCP
```

### Notă

`CatalogEditor.swift` a ajuns temporar nevalid printr-o înlocuire care a
duplicat o semnătură de funcție pe aceeași linie. Compilatorul a raportat-o la
50 de linii distanță („expected declaration"), fiindcă parserul pierduse
echilibrul acoladelor mult mai devreme — numărarea acoladelor a arătat imediat
unde.

### Completări specifice acestui repo, mutate din fosta Partea 1 (2026-09-18)

Păstrate verbatim. Regula generală la care se referă fiecare e în
`~/Developer/CLAUDE.md`.

**Regula 20:**

**Status acest repo (2026-08-27): IMPLEMENTAT (Mac).** `Sources/GDCPluginManager/SelfUpdater.swift`. Perechea Windows trăiește în `GDCPluginManagerWin`.

**Regula 32:**

- **Repo-uri deja curățate** (istoric verificat, 0 apariții reale — cele
  câteva găsite ulterior sunt mențiuni ale regulii ÎN CONȚINUTUL acestui
  fișier, nu atribuiri reale de commit): CGConvertor (2026-09-05),
  **gdc-plugin-manager (acest repo, 2026-09-05)** — `git filter-repo`
  rulat, verificat pe clonă de test (arbore identic, 603 commit-uri/60
  tag-uri păstrate), apoi aplicat pe repo-ul real + `push --force` pe
  `main` și toate tag-urile. Restul repo-urilor din ecosistem rămân de
  curățat INCREMENTAL, la următoarea lor atingere reală.

**Regula 21:**

**Status acest repo (2026-08-28, verificat partial): DE VERIFICAT LA URMATOAREA MODIFICARE, nu urgent acum.** Auditat la cererea lui Cristi — `ImageProcessor.swift` proceseaza thumbnail-uri (probabil imagini mici), iar catalogul de LUT/DCTL/PowerGrade presupune upload/download de fisiere care NU au fost confirmate ca raman mereu mici. Nu s-a gasit cod de streaming manual (nici bun, nici problematic) de citire/scriere in bucati pentru aceste fisiere - daca vreun asset din catalog ajunge vreodata la zeci de MB+ (ex. un LUT 3D foarte mare sau un pachet ZIP), aplica Regula 21 (buffer fix, streaming) dupa modelul DataMover.

## Etapa 2026-09-19 (client v1.38.0 nepublicat, Furnizor v1.46.0) — descărcare directă + GDC LUT Lab

- **`AppLink.downloadURL`** (opțional, decodare sintetizată → clienții vechi îl
  ignoră): cardul aplicației arată „Descarcă” (`AppDirectDownload.swift`:
  URLSession → Descărcări, numele versionat de pe server, apoi `NSWorkspace.open`),
  „Deschide” rămâne pentru `url`. Furnizorul îl are în formularul de publicare și
  îl PĂSTREAZĂ la editare — `CatalogEditor` rescrie catalogul prin model, deci
  orice câmp absent din `AppLink` se pierde la următoarea publicare din Furnizor.
  **Capcană existentă, nerezolvată aici**: `description`, `updateURL`, `version`
  din intrările gdc-firewall și gdc-lut-lab NU sunt în `AppLink` → dispar la
  prima republicare a oricărei aplicații din Furnizor.
- **Categoria „Developer”**: etichetele (`access.tags`) sunt text liber, iar filtrul
  clientului le calculează din produse (`CatalogFacets.tags`) → apare singură cu
  primul produs etichetat; adăugată și în `AccessTagSuggestions.apps`.
- **GDC LUT Lab** în catalog: fără `access.kind` (altfel insigna „PLĂTIT”, Regula 3),
  donația de 23 € prin `pricing.json` (`gdc-lut-lab`), DMG pe
  `gordas.dev/gdc-lut-lab/` (sincronizat de `gdc-lut-lab/scripts/sync-site.sh`).
- `catalog.json`/`pricing.json` editate direct au păstrat EXACT formatul
  `JSONEncoder` (`"cheie" : valoare`, liste goale pe 3 rânduri) — verificat prin
  reserializarea HEAD identic, ca diff-ul să conțină doar intrarea nouă.
  Decodarea validată cu modelul real (pachet izolat cu `GDCPluginManagerCore`).
- TODO paritate Windows (Regula 31): `downloadURL` în clientul Windows.
- **Secțiunea DEVELOPER** (`SidebarSection.developer(DeveloperShelf)`): rafturile
  sunt mapate prin etichete — aplicații cu „Developer” → „Aplicații & Utilitare”
  (excluse din „Aplicații” din Ecosistem), resurse descărcabile/scripturi/PDF cu
  eticheta „Scripturi & Automation” sau „SDK & Resurse Dev” → raftul respectiv.
  Pentru a publica acolo, Furnizorul pune eticheta exactă. TODO paritate Windows.
- **2026-09-20 — DMG notarizat (Regula 45).** `build_installer.sh` produce `dist/GDCPluginManager-<v>.dmg` (pkg + ghid; semnat Developer ID, notarizat, stapled; `GDCPluginManager.dmg` stabil) prin modul nou `dmg` din `codesigning/sign-and-notarize.sh` (commit 6d24795). `GDCPluginManager-Mac.zip` rămâne DOAR canal pentru Self-Updater-ul instalărilor vechi (`update.json` `mac.download_url`, neschimbat). Butonul din `docs/index.html` încă duce la zip-ul de pe release — de mutat pe DMG odată cu release-ul 1.38.0. `swift build` verde pe arborele curent (secțiunea DEVELOPER inclusă).

### Jurnal 2026-09-20 — Redesign carduri catalog (glass + grilă uniformă)
- `PluginCard` (`ContentView.swift`): înălțime fixă `cardHeight` (340), cover 128pt `.clipped()`, titlu `lineLimit(1)`, descriere `lineLimit(2)` (completă la `.help`), `Spacer` intern → butonul de acțiune (Instalează/Deschide/Elimină) pe aceeași linie în tot rândul. Fundal `.ultraThinMaterial`, colț 12pt, bordură albă 0.2, umbră difuză.
- `priceBadges`: ecusoane GRATUIT/TRIAL/LICENȚĂ/PROMO + sumă, uniform în colțul dreapta-sus al copertei; `CountdownBadge` stânga-sus; fonturi rounded.
- Pierdut intenționat: `CollapsibleDescription` nu mai e folosit în card. NU aplicat încă: `CourseCard`, `MyAppCard`, `CommunityChannelCard`. Versiune NEbumpată (nelivrat); nevalidat vizual (fără screenshot).

### Jurnal 2026-09-20 (2) — buton de actualizare + stil glass pe toate cardurile
- `SidebarUpdateButton` (`ContentView.swift`, lângă `vX.Y.Z` în sidebar): iconiță „Caută actualizări” (spinner cât verifică, trimite `gdcCheckForUpdatesRequested`); când `UpdateChecker.availableUpdate` există devine ecuson verde „Actualizare disponibilă vX” care cheamă direct `SelfUpdater.downloadAndInstall`.
- `GlassCard.swift`: `.glassCardBackground()` (ultraThinMaterial, 12pt, bordură albă 0.2, umbră) aplicat pe TOATE cardurile (Course/MyApp/CustomLauncher/Community + celelalte 12 din `ContentView`). Doar `PluginCard` are înălțime fixă (340); celelalte păstrează înălțimile lor.
- Mesajele de stare/eroare din `PluginCard`: `lineLimit(1)` + `.help` cu textul complet. NEvalidat vizual; versiune nebumpată.

### Jurnal 2026-09-20 (3) — v1.39.0: dezinstalare in-app
- `AppUninstaller.swift` (buton „Dezinstalează complet aplicația…” în panoul Licență): dialog nativ → șterge `Application Support/GDCPluginManager` (+ „GDC Plugin Manager”), Caches, Preferences, Saved State, Logs, HTTPStorages, WebKit (bundle ID real `com.gordasgdc.pluginmanager`) → `NSWorkspace.recycle` pe aplicație → ieșire. Jurnal în `DiagnosticLog`. Nu atinge resursele instalate în Resolve. Keychain neșters. `Dezinstalare_*.command` rămâne în repo, nedistribuit (Regula 45).
- `PluginCard`: butonul de suport are `lineLimit(1)`.
- Versiune 1.39.0 în Info.plist + CHANGELOG. `docs/update.json` NEmodificat intenționat (Regula 35): rămâne la 1.38.0 până la publicarea release-ului cu DMG; altfel clienții ar primi un update fără fișier. NEvalidat: dezinstalarea reală (nerulată, ar șterge aplicația).
- **LIVE 2026-09-20**: v1.39.0 publicat (DMG semnat+notarizat+stapled, `.pkg` semnat Installer+notarizat, zip legacy; linkuri latest 200). Notă: staple-ul DMG a eșuat la prima încercare (ticket încă nepropagat) — reluat după ~30 s. Build-ul fără `APPLE_SIGN_IDENTITY_INSTALLER` produce pkg nesemnat, respins de notarizare.
