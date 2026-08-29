# GDC Plugin Manager (Mac) — Arhivă jurnal tehnic detaliat

> Nu se citește automat de Claude Code la fiecare sesiune (doar `CLAUDE.md` e auto-citit).
> Conține: Technical Decisions & Known Pitfalls complet, cele două fluxuri de update (istoric),
> Faza 3/4, secțiunea Audio, toate cele 9 etape v2.0, și toate bug-urile/fix-urile datate 2026-08-29.
> Citește-l explicit (grep/Read) când investighezi o zonă veche de cod sau vrei raționamentul complet.
> Arhivat 2026-08-29 din `CLAUDE.md`, ca să reducem tokenii încărcați automat per sesiune.

## Technical Decisions & Known Pitfalls

Jurnal append-only. Un rând nou de fiecare dată când găsim/rezolvăm un bug real — nu o presupunere, ceva confirmat live sau prin citirea codului.

- **2026-08-22 — Pitfall: `file.filename` (doar basename) apla­tiza orice pack cu subfoldere la instalare.** Un `.ofx.bundle` publicat corect de Furnizor (cu `Contents/MacOS/`, `Contents/Resources/` păstrate — `collectFiles` niciodată nu a aplatizat la publicare) se scria PLAT pe disc la instalare, pierzând structura pe care Resolve o cere pentru a recunoaște bundle-ul. **Soluție**: `relativeInstallPath(for:in:)` (Mac) / `RelativeInstallPath` (Windows) reconstruiesc calea relativă la rădăcina produsului din `file.path` (format `id/versiune/rest...`) și o păstrează integral la scriere. Fără schimbare de comportament pentru pack-urile deja publicate, plate.
- **2026-08-22 — Pitfall: DCTL și LUT împărțeau exact același folder de instalare.** Fără subfolderul `DCTL/` dedicat, un `.dctl` nu apare corect ca nod DCTL în pagina Color a Resolve. **Soluție**: `installDirectory` separă acum cazurile `.dctl`/`.lut` — DCTL merge în `.../LUT/DCTL/`. Instalările vechi rămân orfane în `LUT/` până la un reinstall/update.
- **2026-08-22 — Pitfall: `chmod -R 777` pe folderul OFX ar fi rezolvat "un singur prompt de parolă", dar world-writable pe o mașină multi-user.** **Soluție**: `chown` pe rădăcina `/Library/OFX/Plugins` către userul curent, în același script deja elevat (un singur `osascript ... with administrator privileges`) — instalările OFX următoare scriu direct, fără elevare, fără riscul de securitate.
- **2026-08-22 — Pitfall: presupunerea că PowerGrade pe Windows are nevoie de scriere directă în `%APPDATA%\...\Gallery\index.xml`.** Verificat live cu README-ul oficial Blackmagic (Scripting API): nu există un asemenea format documentat, pe nicio platformă. **Soluție**: rămas exclusiv pe Scripting API (`PowerGradeImporter`), niciodată scriere directă în baza de date de Gallery — vezi și `gdc-plugin-manager-win/CLAUDE.md` pentru pitfall-urile specifice Windows (token gol în CI, Python 3.12 incompatibil cu `fusionscript.dll`).
- **2026-08-23 — Decizie: coperile de catalog stau în repo-ul PUBLIC (`docs/covers/`), nu în `gdc-plugin-manager-files`.** Fișierele vandabile stau în repo-ul privat și se descarcă autentificat, dar site-ul public `gordas.dev` trebuie să poată afișa coperile și nu are cum să se autentifice — iar ele nu sunt conținut protejat, sunt material de prezentare. Se publică odată cu `catalog.json`, la `https://gordas.dev/covers/<id>.jpg`.
- **2026-08-23 — Decizie: sistem hibrid de imagini pe UN SINGUR câmp (`coverImage`), nu două.** Poate ține fie o cale relativă (upload local, comprimat cu `ImageProcessor`), fie un URL absolut (CDN-ul furnizorului, folosit ca atare, fără compresie). Două câmpuri separate ar fi creat starea ambiguă "și upload, și URL — care câștigă?". `CatalogAssets.isExternal(_:)` spune doar din ce ramură provine valoarea. **WARNING**: un URL extern e în afara controlului nostru — dacă furnizorul îl șterge de pe CDN, coperta dispare fără să aflăm, deci orice UI TREBUIE să cadă înapoi pe `iconSymbol` la eșec de încărcare, nu să arate un chenar spart.
- **2026-08-23 — Pitfall: recomprimarea nu e garantat un câștig.** Un logo PNG plat, deja optimizat cu un encoder mai bun decât ImageIO, ieșea de ~3x mai MARE după procesare (măsurat: 11 KB → 32 KB); o poză deja mică sub prag creștea și ea marginal. **Soluție**: `keepOriginalIfSmaller` — dacă rezultatul nu e mai mic iar sursa e deja format web (jpg/png) sub un plafon per preset, se păstrează originalul. Prins de un test pe imagini reale, nu de citit codul.
- **2026-08-23 — Pitfall: `.icon` producea 511x511 în loc de 512x512.** Raportul fracționar `(laturaLungă / laturaScurtă) * 512` dat lui `kCGImageSourceThumbnailMaxPixelSize` ieșea cu un pixel sub țintă, iar decupajul pătrat moștenea eroarea — destul cât să strice alinierea grilei de carduri. **Soluție**: `.rounded(.up)` pe `maxPixelSize`. **NOTE**: `kCGImageSourceThumbnailMaxPixelSize` limitează întotdeauna latura LUNGĂ — pentru un pătrat trebuie cerută proporțional mai mare, ca latura scurtă să ajungă la țintă.
- **2026-08-23 — Notă de arhitectură: `ImageProcessor` NU se portează pe Windows.** `gdc-plugin-manager-win` are doar Client + Core, nu există Furnizor acolo — publicarea și compresia se fac exclusiv de pe Mac. Windows doar consumă imaginile (fără ImageSharp, fără System.Drawing). Dacă vreodată apare un Furnizor pe Windows, ATUNCI trebuie portat, cu praguri identice (512 / 1600 / q=0.82), altfel aceeași imagine ar intra în catalog cu greutăți diferite în funcție de mașina de pe care s-a publicat.
- **2026-08-23 — Regulă de proces: coperta se scrie pe disc ÎNAINTE de commit-ul git, niciodată după.** Ordinea în fiecare `publish()` din Furnizor este: `GitOps.pull` → `CoverImageStore.commit` (scrie `docs/covers/<id>.<ext>`) → `CatalogEditor.upsert...` → `GitOps.commitAndPush`. Dacă imaginea s-ar scrie după commit, `catalog.json` ar referi o copertă încă nepublicată — 404 la toți clienții până la următorul push. `GitOps.commitAndPush` face `git add -A`, deci fișierul nou intră în același commit; verificat și că `.gitignore` nu înghite `docs/covers/*.jpg` (pitfall-ul `python312.zip`).
- **2026-08-23 — Pitfall: schimbarea imaginii lăsa fișiere orfane în repo.** Două cazuri, prinse de test, nu de citit codul: (a) republicare cu o imagine care schimbă extensia (JPEG înlocuit cu PNG cu alpha) lăsa vechiul `.jpg` lângă noul `.png`, ambele pentru același produs; (b) trecerea de la upload local la URL extern lăsa fișierul din repo nereferit de nimeni, pentru totdeauna. **Soluție**: `CoverImageStore.removeLocalFiles` șterge orice `covers/<id>.*` plus fișierul indicat de valoarea anterioară, și e idempotent (republicarea unui produs fără copertă nu mai eșuează degeaba). Ștergerea unui produs își curăță și coperta.
- **2026-08-23 — Decizie: `CoverImageSelection` e enum, nu două câmpuri opționale.** `.none` / `.existing` / `.external` / `.local` — variantele se exclud, iar cu două câmpuri (fișier + URL) ar fi existat starea "și una, și alta", cu UI-ul și publicarea nevoite să decidă arbitrar care câștigă. `.existing` e distinct de `.local`/`.external` tocmai ca să știm că NU trebuie rescris nimic pe disc dacă furnizorul n-a atins imaginea.
- **2026-08-23 — Decizie: compresia se face la ALEGEREA fișierului, nu la publicare.** Așa preview-ul din Furnizor arată exact fișierul care ajunge la clienți (și cât s-a câștigat), nu imaginea sursă. Rezultatul stă într-un temp până la publicare, pentru că id-ul produsului poate fi încă în curs de tastare. Preview-ul pentru URL extern are debounce de 500 ms — fără el am porni un request pe fiecare caracter tastat.

## Cele două fluxuri de actualizare (a nu se confunda)

**PROCESS — actualizarea PRODUSELOR (LUT/DCTL/OFX/Fuse/PowerGrade): in-app, 1 click. Funcționează.**
`catalog.json` (`PluginItem.version`) → `InstallManager.hasUpdate(_:)` compară cu `installedVersions` salvat local → butonul „Actualizează" de pe card → `InstallManager.install`. Fișierele se descarcă și se scriu direct, fără browser. După ce Furnizor publică o versiune nouă, clienții o văd la următorul refresh de catalog. Identic pe Windows (`InstallManager.InstallAsync`).

**PROCESS — actualizarea APLICAȚIEI: NU e self-update, deschide browserul.**
`update.json` (câmpul `version`) → `UpdateChecker.isNewer` vs `CFBundleShortVersionString` (Mac) / `Assembly...GetName().Version` (Windows) → banner → butonul „Descarcă" deschide browserul → userul descarcă arhiva și reinstalează manual.

**WARNING: „update cu 1 click din aplicație" NU există pentru aplicația în sine.** Ca să existe ar trebui descărcare în fundal + înlocuirea bundle-ului/exe-ului + repornire, printr-un proces helper separat — o aplicație nu-și poate suprascrie propriul bundle (Mac) sau `.exe` (Windows) cât timp rulează. Dacă cineva cere asta, e o piesă de construit, nu una de reparat.

- **2026-08-23 — Pitfall: pe Windows banner-ul de update era un fund de sac.** `UpdateDownloadUrl` era setat în `MainViewModel` dar nu era legat de nimic în `MainWindow.xaml` — banner-ul anunța „Versiune nouă disponibilă" și oferea doar „Ascunde", nicio cale de a lua versiunea, nici măcar un link. **Soluție**: adăugat butonul „Descarcă" + `DownloadUpdateCommand` (cu filtru http/https pe URL înainte de `ShellExecute`). Mac-ul avea butonul de la început; doar Windows-ul îl pierduse.
- **2026-08-23 — Convenție: `id`-urile din catalog sunt slug-uri, nu titluri.** Doar litere mici, cifre și cratime (`workshop-sighisoara-2026`), niciodată spații, apostrofuri sau diacritice. Motivul e concret: `id`-ul ajunge în numele fișierului de copertă (`docs/covers/<id>.jpg`) și de acolo într-un URL public — un `id` ca `Don't Be Like Me Workshop` (chiar publicat o dată, ca probă) produce un nume de fișier cu apostrof și spații, care trebuie encodat în URL și se comportă diferit de la un sistem de fișiere la altul. **WARNING**: `id`-ul unui produs intră și în hash-ul SHA-512 al licenței (`LicenseCore.productHash`) — nu se schimbă NICIODATĂ după prima vânzare, deci slug-ul se alege corect de la început, nu se corectează ulterior.
- **2026-08-24 — Decizie: `docs/android.json` e sursa unica pentru APK-ul de Android, si e SINGURA excepție acceptată la Regula de aur 1 („fără tag fix în linkuri").** Aplicația companion de Android e un PWA împachetat ca APK (TWA) peste `gordas.dev`; release-urile ei sunt marcate deliberat `--latest=false` (tag `android-v*`), pentru că `update.json` al aplicațiilor desktop pointează spre `releases/latest/download/GDCPluginManager.pkg` — un release de APK marcat „latest" ar face self-update-ul pe Mac și Windows să descarce un `.apk`. Prin urmare `latest` NU poate fi folosit pentru APK, iar tagul fix există într-un singur loc, `docs/android.json`, citit dinamic de site (`index.html`, butonul `#btn-android`), de Mac (`AndroidPane.swift`) și de Windows (`AndroidReleaseService.cs`). **La fiecare APK nou se actualizează doar `android.json`** — nu se hardcodează tagul în cod sau în HTML. **WARNING**: dacă cineva „repară" linkul înlocuindu-l cu `releases/latest/download/...`, butonul de Android va servi instalatorul de desktop.
- **2026-08-24 — Pitfall: `bubblewrap update` cere versiunea interactiv și, rulat din script, lasă `versionName` GOL în `app/build.gradle`** (aplicația apare fără versiune în Setările Android). **Soluție**: `twa/build-apk.sh` scrie el `versionName`/`versionCode` din `twa/twa-manifest.json` după `update`, înainte de `build`. Prins comparând `aapt dump badging` cu ce era în manifest.
- **2026-08-24 — Notă: `PWA-ul/APK-ul pornește pe `docs/app.html`, nu pe `index.html`.** `index.html` rămâne pagina de prezentare pentru vizitatorii din browser; `app.html` e interfața de aplicație (dashboard cu tab-uri, randat din `catalog.json`). Legătura se face prin `start_url` în `docs/manifest.webmanifest` și `startUrl` în `twa/twa-manifest.json` — dacă schimbi unul, schimbă-le pe amândouă, altfel PWA-ul și APK-ul pornesc pe ecrane diferite. La orice modificare de pagină trebuie incrementat `CACHE_VERSION` din `docs/sw.js` (excepție: `catalog.json` și `android.json`, care sunt network-first și se împrospătează singure).
- **2026-08-24 — Bug raportat: „Șterge” pe Materiale nu reacționează. Investigat: fiecare categorie (Produse/Cursuri/Aplicații/Materiale/Evenimente/Magazine) are handler de ștergere identic și corect — verificat linie cu linie, cele 6 view-uri sunt simetrice.** Confirmat funcțional cu un test dedicat: adaugă+șterge pe toate cele 5 categorii simple, prin `CatalogEditor` direct (fără UI) — toate 10 pași OK, catalog.json revine identic. Nu există „handler lipsă” sau „nepotrivire de ID” cum se bănuia. **Ce era însă real și confirmat prin citire+reproducere**: `GitOps.commitAndPush` folosea `git add -A` la fiecare publicare/ștergere pe `publicCatalogRepo` — care e ACELAȘI checkout cu codul sursă al aplicației (`Sources/`, `twa/`), nu un clone doar-cu-doc-uri. Orice fișier lăsat modificat necomis în acel folder (o modificare de cod în lucru) ar fi fost înghițit tăcut într-un commit „Material: X”/„Curs: X” etc. **Fix**: `commitAndPush` primește acum `paths:` explicit (`["docs/catalog.json", "docs/covers"]`) pentru toate cele 6 apeluri pe `publicCatalogRepo`; `privateFilesRepo` rămâne pe `-A` (acel repo conține DOAR fișiere de produs, scope creep nu e un risc acolo). **Pitfall prins la testare**: `git add docs/covers` cu directorul inexistent (înainte de prima copertă publicată) arunca `fatal: pathspec ... did not match any files` — deci noul cod filtrează `paths` la cele care chiar există pe disc înainte de `git add`. **Al doilea fix, pentru viitor**: eroarea `Text(errorMessage).foregroundStyle(.red)` (un rând subțire, ușor de ratat) a devenit un banner cu icoană + fundal roșu în toate cele 5 view-uri simple — dacă o operație eșuează (ex. `git pull --ff-only` respins pentru că checkout-ul a divergat de remote), utilizatorul TREBUIE să vadă asta, nu să creadă că „butonul nu reacționează”.
- **2026-08-24 — Regulă permanentă: la orice modificare de cod în aplicațiile desktop (Mac/Windows), include la finalul mesajului comanda exactă de Terminal pentru rebuild local pe Mac** (`git pull` + scriptul de build potrivit — `build_app.sh` pentru Client, `build_furnizor_app.sh` pentru Furnizor), ca Cristi să poată testa imediat, fără să întrebe. **Why:** fără asta, el testează din reflex versiunea veche deja deschisă și crede că fix-ul n-a mers (confirmat 2026-08-24, cazul „Șterge nu reacționează” pe Furnizor — bug-ul era deja reparat în cod, dar aplicația de pe disc era stale).
- **2026-08-24 — Regulă permanentă: NICIODATĂ nu șterg/suprascriu `PrivateCatalogAuth.swift` sau `SupabaseAdminConfig.swift` fără backup explicit întâi.** Ambele sunt gitignorate (chei/token-uri reale) — `git pull`/`git checkout` NU le poate reface. Dacă am nevoie temporar de un build funcțional fără ele (ex. verificare de compilare), copiez întâi fișierul real într-un `.bak` în `/tmp`, sau folosesc `.example`-ul într-o copie separată a repo-ului, niciodată suprascriind fișierul real din checkout-ul de lucru. **Why:** 2026-08-24 — am suprascris apoi șters fișierul real al lui Cristi ca să testez un fix, distrugând tokenul GitHub local; s-a recuperat doar pentru că mai exista o copie în altă clonă (`~/Downloads/GDCPluginManager`) — dacă n-ar fi existat, tokenul ar fi trebuit regenerat manual din GitHub.
- **2026-08-24 — Adevăratul bug al „Șterge nu reacționează”: race condition SwiftUI, nu git.** Fix-ul de `git add -A` de mai sus era real dar nu era cauza — confirmat rulând întregul flux (upsert→pull→remove→commitAndPush) headless, prin CLI, cu binarul recompilat: a mers perfect, commit-ul chiar a ajuns pe remote. Bug-ul adevărat, reprodus doar prin descrierea exactă a lui Cristi (dialogul de confirmare apare, confirmă, dar NIMIC nu se întâmplă — fără eroare, fără mesaj): `.confirmationDialog(isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }))` + `Button("Șterge definitiv") { Task { await delete() } }`, unde `delete()` citea `pendingDelete` direct — SwiftUI golește `pendingDelete` (prin binding-ul custom, la închiderea dialogului) ÎN PARALEL cu pornirea Task-ului; dacă nilarea câștigă cursa, `guard let x = pendingDelete else { return }` iese silențios, fără nicio urmă. **Fix**: toate cele 5 view-uri afectate (Cursuri/Aplicații/Materiale/Evenimente/Magazine) capturează acum elementul sincron în butonul dialogului (`let toDelete = pendingDelete` înainte de `Task`) și îl trec ca parametru la `delete(_:)`, care nu mai citește `pendingDelete` deloc. **`PublishView.swift` (Produse) nu avea acest bug** — folosește `@State var showDeleteConfirm: Bool` simplu, nu un binding derivat din elementul de șters, deci nu exista cursa. **Lecție**: „codul e identic pe toate categoriile” nu înseamnă „codul e corect” — bug-ul a fost copiat pe 5 din 6 view-uri exact pentru că erau simetrice.
- **2026-08-24 — Suport de imagini adăugat la categoria Aplicații (era singura fără), pe toate cele 4 suprafețe: `AppLink.coverImage` (Core, Swift + C#), `CoverImagePicker` în `PublishAppView.swift` (Furnizor), `CoverThumbnail` în `AppCard` (Client Mac), copertă în `DataTemplate` pentru `AppLinkViewModel` (Client Windows, `MainWindow.xaml`).** Site-ul (`docs/index.html`) NU a avut nevoie de nicio modificare — `appCard()` deja apela `coverHTML(app, 'square')` generic, la fel ca toate celelalte categorii; doar câmpul lipsea din date. Pattern-ul de referință copiat 1:1 a fost `PartnerStore`/`PartnerStoreViewModel` (identic ca formă: nume+descriere+link+copertă opțională). `docs/app.html` (dashboard mobil) a primit și el o mică variantă (imaginea înlocuiește iconița generică în rândul compact), fără să schimbe structura de layout.
- **2026-08-24 — Regulă permanentă: notificarea de update trebuie să fie și pop-up modal, nu doar banner discret.** Bannerul din antet (existent dinainte) rămâne, dar poate fi ratat — utilizatorii nu citesc mereu bara de sus. Adăugat un `.alert` (Mac, `ContentView.swift`) / `Wpf.Ui.Controls.MessageBox` (Windows, `MainWindow.xaml.cs`) care întrerupe O SINGURĂ DATĂ per versiune nouă, cu textul fix cerut de Cristi: *„Este disponibilă o nouă versiune! Te rugăm să descarci ultimul installer și să îl instalezi peste versiunea actuală.”* — explicit, pentru că self-updater-ul NU e implementat pe nicio platformă (vezi WARNING-urile din `UpdateChecker.swift`/`UpdateChecker.cs`: ar necesita un helper separat care înlocuiește bundle-ul/exe-ul după ieșirea aplicației). Popup-ul și bannerul citesc aceeași stare de „dismissed” (`UpdateChecker.dismiss()`/`.Dismiss()`), deci închiderea popup-ului (orice buton) ascunde și bannerul — nu apar independent, nu se suprapun la fiecare pornire.
- **2026-08-24 — Regulă permanentă, reconfirmată: la orice modificare de cod în aplicațiile desktop (Mac/Windows), comanda de rebuild local Mac se include la finalul răspunsului** (vezi regula deja notată mai sus, din același caz „Șterge nu reacționează”) — și, în plus, pentru schimbări pe Windows: dacă modificarea atinge XAML sau orice API din pachete precum Wpf.Ui, verificarea prin CI (push + `gh run watch`) e obligatorie înainte de a considera treaba terminată, fiindcă `dotnet build` de pe Mac NU compilează XAML și nu detectează un nume de proprietate/metodă greșit dintr-un pachet — vezi pitfall-ul `Symbol="Phone24"` din CLAUDE.md-ul `gdc-plugin-manager-win`.
- **2026-08-24 — Unificare cu fosta aplicație „GDC License Manager": `GenerateSerialView.swift` acoperă acum și cele 4 aplicații standalone** (`gdc-datamover`, `cursorpro`, `gdc-production-manager`, `gdc-resolve-encoder`), nu doar produsele din `catalog.json`. **NU a fost nevoie de nicio migrare criptografică** — `VendorKeyStore.swift` citea deja cheia din `~/Library/Application Support/GDC License Manager/private_key.txt` (exact fișierul generat de aplicația veche; verificat 2026-08-24 că e byte-identică), iar `LicenseGenerator`/`LicenseCore` semnau deja după același format (`SHA-512(productID)[:4]`, aceeași cheie publică hardcodată, verificată identică cu cea din `DataMover`). Deci „migrarea" a fost DOAR acest dropdown — restul arhitecturii era deja unificat de la bun început. Constanta `gdcStandaloneProducts` (id-uri citite manual din sursa fiecărei aplicații — `PRODUCT_ID` în Python, `LicenseManager.productID` în Swift) e sursa unică pentru aceste 4 ID-uri; un ID greșit aici nu sparge nimic ireversibil (semnătura tot e validă), dar codul generat va fi respins de client cu `WrongProduct`. **Backup complet al vechiului sistem** (cod sursă + chei + `customers.csv` + `furnizor_sales.csv`) făcut înainte de această schimbare, în `~/Downloads/BACKUP-GDC-License-Manager-2026-08-24/` — inclusiv descoperirea că existau DOUĂ `customers.csv` divergente (cel din `~/Downloads/gdc-license-system/`, stale, 7 rânduri; cel din `~/Library/Application Support/`, cel real folosit de aplicație, 15 rânduri) — ambele păstrate neatinse. Produsul `gdc-effects-pack` (3 rânduri de test în istoricul vechi) a fost confirmat de Cristi ca fost experiment abandonat — lăsat neatins, fără corespondent în cod nou.
- **2026-08-24 — Confirmat (nu schimbare de cod, deja adevărat): `GenerateSerialView.swift` NU are niciun câmp liber pentru ID-ul de produs.** Selecția e 100% din Picker — pentru produse din catalog (dinamic, citit din `catalog.json` la fiecare deschidere) și pentru cele 4 aplicații standalone (`gdcStandaloneProducts`, constantă hardcodată). Nu există alt loc în Furnizor unde se generează licențe — `GenerateSerialView` e singurul apelator al `LicenseGenerator.generate`. Un typo de ID e deci imposibil din interfață.
  **Referință — toate ID-urile oficiale de produs valide, la 2026-08-24:**
  - **Aplicații standalone** (constanta `gdcStandaloneProducts` din `GenerateSerialView.swift` — ID-uri fixe, NU se schimbă fără să verifici din nou `PRODUCT_ID`/`LicenseManager.productID` din sursa aplicației respective):
    - `gdc-datamover` → DataMover
    - `cursorpro` → CursorPro GDC
    - `gdc-production-manager` → GDC Production Manager
    - `gdc-resolve-encoder` → GDC Resolve Encoder
    - `gdc-vault` → GDC Vault (adăugat 2026-08-24)
    - `media-flow-monitor` → MediaFlow Monitor (adăugat 2026-08-26, Mac+Windows ambele licențiate)
  - **Produse din catalog** (LUT/DCTL/PowerGrade) — NU sunt hardcodate nicăieri; sursa unică de adevăr e `docs/catalog.json` (`items[].id`), citit live de Picker la fiecare deschidere a ecranului. La 2026-08-24: `Cristi` (lut), `FalseColorSkinDetect` (dctl), `GDC` (lut), `IntermediateWorkflow` (lut), `LiniarWorkflow` (lut), `Raz` (powerGrade), `ff` (powerGrade) — listă informativă, se schimbă normal pe măsură ce publici/ștergi produse prin Furnizor, nu trebuie ținută sincronă manual aici.
  - **Istoric, fără corespondent activ**: `gdc-effects-pack` (confirmat de Cristi 2026-08-24: experiment abandonat, apare doar în `customers.csv` vechi, ignorat).
- **2026-08-24 — Regulă permanentă: comanda de rebuild trimisă lui Cristi trebuie să numească EXPLICIT care aplicație** (`build_app.sh` → Client, `build_furnizor_app.sh` → Furnizor) — nu doar "recompilează", fiindcă sunt două binare separate, instalate separat, și o schimbare în una nu se vede în cealaltă. **Why:** 2026-08-24, coperta de la Aplicații (adăugată în Client, `AppCard`/`ContentView.swift`) nu apărea — Cristi rebuild-uise doar Furnizor (unde a testat generarea de licențe), Client-ul instalat rămăsese cu build-ul vechi, fără codul nou. Nicio eroare de date/mapare — doar binarul greșit rulat.
- **2026-08-24 — Bug real, reprodus și fixat: înlocuirea unei coperte la același `id` nu se vedea imediat, pe niciun client.** Cauza: GitHub Pages trimite `Cache-Control: max-age=14400` (4 ore) pe fișierele din `docs/` (verificat live: `curl -I` pe un cover real) — orice client care deja văzuse acel URL exact (`AsyncImage` pe Mac, `BitmapImage` pe Windows, orice browser) rămânea cu imaginea veche până expira cache-ul. Mai grav pe PWA: `docs/sw.js` face cache-first pe imagini FĂRĂ nicio expirare — o copertă înlocuită nu se mai actualiza NICIODATĂ acolo, decât la un `CACHE_VERSION` bump manual. **Fix**: `CoverImageStore.commit`, cazul `.local`, atașează acum un sufix `?v=<primii 8 caractere hex din SHA-256 al fișierului>` la valoarea `coverImage` scrisă în catalog — derivat din CONȚINUT, nu din timestamp, ca republicarea acelorași bytes să nu schimbe URL-ul degeaba. Fix universal, fără nicio modificare de cod pe Client/site/PWA: toate randează direct string-ul din catalog ca URL, deci un URL diferit la conținut diferit rezolvă cache-ul HTTP și cel din service worker deopotrivă. **Pitfall prins la implementare**: `removeLocalFiles` folosea `previous` direct ca nume de fișier pe disc pentru curățare — cu sufixul nou, ar fi căutat literal un fișier `id.jpg?v=abcd1234` (care nu există) și n-ar fi șters nimic; reparat să taie orice sufix `?...` înainte de a rezolva calea reală.
- **2026-08-24 — Regulă permanentă (întreg ecosistemul GDC): orice aplicație — existentă sau nouă — trebuie să vină cu un mecanism dedicat de dezinstalare completă ("Clean Uninstall").** Un uninstall care lasă `.plist`-uri, cache-uri sau preferințe orfane e considerat bug, la fel de grav ca un buton „Șterge” care nu curăță catalogul. **Pe Mac**: șterge `.app`-ul PLUS `~/Library/Application Support/<Nume>`, `~/Library/Caches/<bundle-id>`, `~/Library/Preferences/<bundle-id>.plist` (și `defaults delete`), `~/Library/Logs/<Nume>`, și orice item Keychain scris de aplicație (service propriu, șters în buclă cu `security delete-generic-password` — un singur apel șterge un singur item). **Pe Windows**: uninstaller-ul (Inno Setup sau script separat) trebuie să curețe folderul din `Program Files`, `%AppData%`/`%LocalAppData%\<Nume>`, și orice cheie de Registry creată de aplicație (`HKCU:\Software\GDC\<Nume>` sau echivalent). **Why:** stabilit explicit de Cristi ca standard de calitate obligatoriu pentru tot ecosistemul — vezi implementarea de referință în `gdc-vault-mac/uninstall.sh` și `gdc-vault-win/uninstall.ps1`. **Pentru aplicațiile existente** (GDCPluginManager Client/Furnizor): dacă se adaugă vreodată o setare persistentă nouă (Registry/UserDefaults/cache), stergerea ei trebuie adăugată în același commit la scriptul/instrucțiunile de uninstall — nu lăsată "pentru mai târziu".
- **2026-08-24 — Bug critic pre-release: coperțile de produse/aplicații NU se afișau deloc pe Windows, pe nicio categorie (Mac era OK).** Root cause confirmat: `Image.Source="{Binding Cover.Url}"` leagă direct un `Uri` la `Image.Source` — `ImageSourceConverter` (folosit implicit de WPF cand tipul sursei nu se potrivește) știe să convertească DOAR dintr-un `string`, niciodată dintr-un `System.Uri`. Fără conversie explicită, binding-ul eșuează silențios (eroare doar în Output/debug console, invizibilă la `dotnet build` și la orice test fără debugger atașat) — `Image.Source` rămâne `null` pe toate cele 6 categorii, pe orice mașină Windows. **Fix**: `UriToImageSourceConverter.cs` (construiește explicit un `BitmapImage` din `Uri`, `CacheOption.OnLoad`), legat în toate cele 6 `Image.Source` din `MainWindow.xaml`. Verificat cu `curl -I` că URL-urile din `catalog.json` (inclusiv cele cu spații în nume, ex. `covers/CG Convertor.jpg`) răspund 200 și se encodează corect atât în Swift (`URL(string:relativeTo:)`) cât și în C# (`new Uri(base, relative)`) — deci pe Mac problema raportată era aproape sigur build vechi instalat (nerebuild-uit de la adăugarea suportului de imagini), NU un bug de cod nou identificat.
- **2026-08-24 — `mandatory` din `update.json` exista în model de la început dar NU era citit nicăieri — port greșit, nu bug nou.** Acum: un update `mandatory: true` ignoră închiderea anterioară (reapare la fiecare `check()`/`CheckAsync()`, adică la fiecare lansare + refresh manual, cât timp versiunea instalată rămâne veche) și popup-ul nu mai oferă "Mai târziu"/`CloseButtonText` — vezi `UpdateChecker.dismiss()`/`.Dismiss()` (Mac/Windows). **Tot NU blochează folosirea aplicației** — asta ar cere un helper de self-update real, neimplementat (vezi WARNING-urile deja existente din `UpdateChecker.swift`/`.cs`). E doar o insistență mai puternică, pentru exact cazuri ca bug-ul de mai sus (imagini lipsă pe toate mașinile Windows) unde un simplu banner discret nu era suficient.
- **2026-08-24 — REGULĂ PERMANENTĂ, cerută explicit de Cristi: de fiecare dată când se modifică asset-uri (coperți, iconițe) sau cod în aplicațiile GDC Plugin Manager (Client Mac/Windows), TREBUIE incrementată versiunea (Info.plist + `.csproj` + `docs/update.json`, toate trei sincron — vezi WARNING din `UpdateChecker.swift`) ȘI generat un Release oficial pe GitHub, altfel clienții deja instalați NU află de fix și rămân cu bug-ul.** Push-ul pe `main` declanșează CI-ul de build (`.github/workflows/build-windows.yml`), dar **Release-ul GitHub în sine (upload-ul artefactului, folosit de `update.json.download_url`) e un pas MANUAL al lui Cristi** — Claude nu creează/publică Release-uri GitHub fără aprobare explicită (acțiune outward-facing). După orice fix ca acesta, mesajul de răspuns trebuie să spună clar: "versiunea X.Y.Z e gata în cod, `update.json` actualizat — mai trebuie: 1) rulează/verifică CI, 2) creează Release-ul pe GitHub cu artefactul nou."
- **2026-08-24 — Investigat "imagini lipsă la Magazine/Materiale/Evenimente pe Windows" — NU e regresie de cod, e fragilitatea URL-urilor externe Facebook.** Verificat live: toate 3 URL-urile din catalog (`scontent-*.fbcdn.net`) răspund 200 acum, indiferent de User-Agent, iar `new Uri(...)` în C# le parsează corect chiar și cu query string-uri foarte lungi (confirmat cu test dedicat) — deci NU e un bug de encoding/parsing în `UriToImageSourceConverter`. Explicația cea mai plauzibilă: link-urile Facebook `scontent` sunt semnate cu expirare (`oe=` = timestamp hex) și/sau supuse hotlink-blocking inconsistent (variază după rețea/regiune/IP) — exact riscul deja documentat în WARNING-ul din `CatalogAssets`. **Recomandare permanentă**: Materiale/Evenimente/Magazine ar trebui să folosească coperți LOCALE (upload prin `CoverImagePicker` din Furnizor, ca toate celelalte categorii), nu link-uri Facebook copiate direct — un URL extern e complet în afara controlului nostru, indiferent cât de bine e scris codul de afișare. **Aplicații**: 3 din 8 intrări nu au deloc `coverImage` setat (`None` în catalog) — lipsă de date, nu bug, se rezolvă din Furnizor.
- **2026-08-24 — Badge GRATUIT/LICENȚĂ/PROBĂ + filtru rapid Toate/Gratuite/Premium, pe categoria Produse (Mac + Windows).** Cerere explicită: fără ton de "reclamă agresivă" — eticheta pe card e scurtă ("LICENȚĂ", portocaliu), mesajul complet de încredere ("Dezvoltat și susținut de comunitate. Licență Lifetime la preț promoțional de lansare.") apare doar la hover/tooltip, nu ocupă spațiu pe card. Filtrul e local fiecărei grile de Produse (nu afectează Cursuri/Materiale/Evenimente/Magazine/Aplicații, care n-au conceptul de preț în același fel). Mac: `BadgePill`/`PriceFilter` în `ContentView.swift`. Windows: `ProductViewModel.BadgeText/BadgeBrush/BadgeTooltip`, `MainViewModel.PriceFilter` + `FilterProduct`, `PriceFilterWeightConverter`.
- **2026-08-24 — GDC Vault integrat în ecosistem**: adăugat `gdc-vault` în `gdcStandaloneProducts` (`GenerateSerialView.swift`), adăugat ca intrare în `docs/catalog.json` (categoria `apps`, cu copertă `docs/covers/gdc-vault.png`), și pagină de prezentare nouă la `docs/gdc-vault/index.html` (servită pe `gordas.dev/gdc-vault`, în ACELAȘI repo care deține deja domeniul — NU un repo/CNAME separat, apex domain-ul poate fi legat de un singur repo GitHub Pages). Model de licențiere: probă 15 zile, Lifetime 5€ (preț promoțional beta, notă de transparență despre certificatele de semnare viitoare), activare prin WhatsApp + cod generat manual din Furnizor — identic cu restul uneltelor GDC.
- **2026-08-24 — Bug critic: „Șterge” pe DCTL/LUT/PowerGrade (orice resursă vandabilă, `privateFilesRepo`) eșua cu `error: unknown switch 'A'`.** Cauza: `GitOps.commitAndPush` construiește `addArgs` pentru `git add` (`-A` când `paths == nil`, adică exact fluxul `privateFilesRepo`), dar aceeași variabilă era reciclată greșit ca argument pentru `git status --porcelain` — `-A` nu există ca flag la `git status` (doar la `git add`/`git commit`). Nu apărea la Materiale/Evenimente/Magazine/etc. pentru că acelea folosesc `paths` explicit (path-uri, valide și la `status`), doar `privateFilesRepo` (produsele vandabile) folosește `-A`. **Fix**: la `status`, `-A` devine „niciun argument” (arată tot repo-ul); pentru `paths` explicite, restricția rămâne (nu doar la `add`), ca sa nu declanșeze fals un commit din cauza altceva murdar în checkout.
- **2026-08-24 — Consolidare CSV-uri de vânzări: `furnizor_sales.csv` e acum SURSA UNICĂ de istoric, cu tot ce era înainte în `customers.csv`.** Existau 3 fișiere: `~/Downloads/gdc-license-system/customers.csv` (vechi, 7 rânduri — 1 vânzare reală duplicată + 6 rânduri de test explicit marcate "Test"/"test@test.com", lăsat neatins, nu adaugă nimic nou), `~/Library/Application Support/GDC License Manager/customers.csv` (14 vânzări reale, din vechiul GDC License Manager, PĂSTRAT neatins ca istoric imuabil — nimic mai scrie în el de-acum), și `furnizor_sales.csv` (10 rânduri, din unificarea cu Furnizor). Consolidare: cele 14 rânduri din `customers.csv` (viu) au fost convertite la schema nouă de 9 coloane (`SalesLog.columns` — mapare `produs`→`produs_id`+`produs_nume` cu numele oficiale documentate mai sus) și interclasate cronologic cu cele 10 din `furnizor_sales.csv`, minus un rând de test rămas dintr-o verificare anterioară (`test-vendor-flow`/`Test Client`, confirmat de Cristi ca eliminabil). Rezultat: 23 rânduri în `furnizor_sales.csv`. **Descoperire importantă la consolidare**: `gdc-effects-pack` (crezut anterior "doar experiment abandonat") are 8 vânzări REALE cu clienți reali (până la 25€) — confirmat de Cristi 2026-08-24 să rămână în istoric ca atare, chiar dacă produsul în sine e retras. Backup complet dinainte de consolidare în `~/Downloads/BACKUP-sales-csv-consolidare-2026-08-24/`.
- **2026-08-24 — Securitate: PowerGrade PLĂTIT nu mai lasă fișierul brut pe disc la eșec de import Gallery.** Raportat de Cristi: un client putea provoca intenționat eșecul importului automat (nu deschide Resolve) ca să obțină fișierul `.drx` verificat, brut, de pe disc (`stagedOnly`) și să-l distribuie neautorizat — exact ce header-ul din `PowerGradeImporter.swift`/`.cs` ("EXCLUSIV prin Scripting API") voia să evite. Fix (Mac + Windows, identic): pentru `!item.isFree`, la eșec de import se șterge complet folderul scris + se dezinstalează din starea locală + se aruncă o eroare generică (`InstallError.paidResourceInstallFailed` / `PaidResourceInstallException`) — fără cale de fișier, fără instrucțiuni de instalare manuală. UI arată în schimb un buton de contact WhatsApp. Resursele GRATUITE rămân neschimbate (mesaj vechi de instalare manuală) — cerut explicit: regula se aplică STRICT la cele plătite. Release oficial v1.2.13 (Mac+Windows), verificat live (`releases/latest` → v1.2.13, HTTP 200 pe ambele artefacte).
- **2026-08-24 — Furnizor: autocompletare client (Nume/Email) după ID de mașină + sincronizare automată din Tracker.** Cerut explicit: la generarea unui serial (`GenerateSerialView.swift`), completarea manuală repetată a Nume/Email pentru un client deja cunoscut era ineficientă și predispusă la typo-uri. Arhitectură: `ClientDirectory.swift` combină DOUĂ surse — Tracker (Supabase `devices`, completat de CLIENT la onboarding, vezi `AnalyticsClient.registerDevice`) și istoricul din `furnizor_sales.csv` (`SalesLog`) — indexate după `machineID`. **Tracker-ul e declarat sursa de adevăr** (clientul și-a introdus singur datele): la potrivire pe același `machineID`, Tracker câștigă mereu față de ce a tastat manual Cristi anterior. `TrackerSync.swift` corectează automat (overwrite) rândurile din `furnizor_sales.csv` a căror nume/email diferă de Tracker, rulat automat la deschiderea panoului Clienți + buton manual „Sincronizează cu Tracker". Clienții din Tracker FĂRĂ nicio vânzare încă apar separat, într-o secțiune „Din Tracker, fără licență generată încă" — NU ca rânduri false în `SalesLog` (schema aia e per-vânzare: produs/preț/serial, un rând fără produs ar strica statisticile de vânzări). `DuplicateClientsView.swift` (+ buton „Curăță duplicate") rezolvă manual duplicate PRE-existente (typo-uri vechi, fără corespondent în Tracker) — alegere de variantă canonică per grup de `machineID`.
- **2026-08-24 — Aplicația mobilă Android (APK/TWA) RETRASĂ complet, înlocuită cu PWA direct în browser.** Cerut explicit de Cristi: „scăpăm complet de problemele cu certificatele, erorile de instalare pe Android și fișierele APK". Arhitectural, asta exista deja: `gordas.dev/app.html` ERA deja un PWA complet (manifest, service worker, offline, `catalog.json`) — APK-ul era doar un TWA (Trusted Web Activity) care îl împacheta, fără cod propriu. Fix: panoul „Android" (redenumit „Aplicație mobilă" — `MobileAppPane.swift` pe Mac, fost `AndroidPane.swift`; `AndroidReleaseService.cs` șters pe Windows) NU mai face niciun fetch de rețea (nu mai există `android.json`/versiune de verificat) — QR + buton trimit direct spre link-ul FIX `https://gordas.dev/app.html`, care merge identic pe Android ȘI iPhone, fără instalare, fără avertisment de certificat. „Instalarea" rămasă e opțională: „Adaugă pe ecranul principal" (Android Chrome / iOS Safari), cu instrucțiuni separate pentru fiecare, în panou. Șterse din repo: `docs/android.json`, `docs/ANDROID.md`, `twa/build-apk.sh`, `twa/twa-manifest.json`, `AndroidReleaseService.cs` (Windows). Site-ul (`docs/index.html`): butonul Android → „📱 Deschide pe telefon" spre `app.html` (fără JS de fetch dinamic), nota actualizată pentru „Adaugă pe ecranul principal" în loc de avertismentul „permite din surse necunoscute". Keystore-ul (`twa/android.keystore`, gitignorat) NU a fost șters de pe disc — rămâne acolo, nefolosit, în caz că se reconsideră vreodată APK-ul.


## Faza 3 (2026-08-26) — Profil/HWID sidebar + Sistem de Revocare Licențe + Generare flexibilă
Implementat pe Mac (acest repo) și Windows (gdc-plugin-manager-win), vezi
CLAUDE.md Partea 1, Regula 12 pentru regulile globale.

- **Profil Utilizator**: `UserProfileStore.swift`/`.cs` (nume/email
  persistate local, NU doar trimise o dată la onboarding și uitate),
  `ProfileSidebarBlock.swift` (Mac, popover) / `ProfileEditorWindow.xaml`
  (Windows, fereastră modală) — vizibile în sidebar sub lista principală.
- **Revocare licențe**: `RevocationCheck.swift`/`.cs` (Core) — RPC
  Supabase `is_license_revoked(machine_id, product_id)`, FAIL-OPEN (eroare
  de rețea = NErevocat, niciodată blocaj offline). `RevocationAdminClient.swift`
  + `RevocationsView.swift` (Furnizor, doar Mac — singurul loc care
  generează licențe pentru tot ecosistemul) — panou "Revocări licențe",
  funcționează pentru orice `productID` din `gdcStandaloneProducts` sau
  catalog. **Migrarea SQL** (`supabase/migrations/2026-08-26_license_revocations.sql`)
  trebuie rulată MANUAL de Cristi în Supabase SQL Editor — Claude nu are
  acces la acel proiect Supabase.
- **Generare flexibilă**: `GenerateSerialView.swift` — Picker
  Zile/Luni/Ani/Lifetime (fără schimbare de format criptografic,
  `expiresAt` deja suporta orice valoare/0). "Valabil până la versiunea X"
  e doar o notă informativă (SalesLog) — aplicarea reală se face manual
  prin revocare când acea versiune chiar apare.
- **Scop rămas** (fast-follow, port mecanic al aceluiași tipar): GDC Vault
  (Mac+Win) nu are încă `RevocationCheck`/Profil-sidebar — folosește
  aceeași `LicenseCore`, deci portarea e directă când se cere explicit.

## Secțiune nouă "Audio" (2026-08-27) — modelată pe Aplicații
Adăugat `AudioTrack` (Core, `CatalogModel.swift`) — id/name/description/
url/youtubeURL/coverImage, 1:1 pe `AppLink` dar cu `description` în plus
(cerut explicit: "Informații/Descriere" pe lângă link). Catalog.audioTracks
nou, decode cu default `[]` (retrocompatibil, catalog vechi fără cheie nu
sparge nimic). `CatalogEditor.upsertAudioTrack/removeAudioTrack` (Furnizor)
+ `PublishAudioView.swift` (formular, mirror `PublishAppView.swift`, cu
`TextEditor` pentru descriere) + tag `.audio` în `FurnizorContentView`.
Client: `SidebarSection.audio` plasat ÎN GRUPUL categoriilor
LUT/DCTL/OFX/PowerGrade (cerut explicit — "exact în zona categoriilor
existente"), înaintea Divider-ului spre Cursuri/Materiale/etc.; `AudioGrid`/
`AudioCard` (`ContentView.swift`) mirror `AppsGrid`/`AppCard`, plus rândul
de descriere (`lineLimit(3)`) și buton "Descarcă" (`audio.open`), tint
`.indigo` (culoare nefolosită de nicio altă categorie). Localizare RO/EN/ES
completă (`sidebar.audio`, `audio.badge`, `audio.open`, `audio.empty`).
`swift build` verificat curat pe ambele ținte după fiecare pas.
Versiune: Client 1.3.1→1.4.0, Furnizor 1.2.25→1.3.0 (MINOR — funcționalitate
nouă vizibilă, Regula 14).
**TODO paritate**: `GDCPluginManagerWin` (Client Windows, repo separat) NU
are încă `AudioTrack`/secțiunea Audio — nu a fost cerută explicit în acest
mesaj ("ambele aplicații" = Client Mac + Furnizor Mac, singurele numite),
dar catalogul e partajat, deci un client Windows vechi va ignora pur și
simplu `audioTracks` (decode tolerant) până la portare. Site-ul
(`docs/index.html`/`app.html`) idem — nu randează încă secțiunea Audio.

## Bug real (2026-08-27) — update.json anunta 1.4.0, dar clientii instalau 1.3.1
Dupa ce am bumpat `docs/update.json` la `1.4.0` (sectiunea Audio) si am
rulat CI cu succes, NU am mai construit/publicat efectiv installer-ele
reale v1.4.0 — release-ul "latest" (`v1.3.1`) a ramas neschimbat pe
GitHub. Rezultat: clientii vedeau corect popup-ul "e disponibila 1.4.0",
dar `releases/latest/download/...` servea in continuare binarele 1.3.1 —
raportat live de Cristi (installer-ul Windows arata "version 1.3.1" desi
tocmai fusese descarcat ca "actualizare la 1.4"). **Lectie**: bump-ul de
versiune in `update.json` si publicarea reala a release-ului GitHub cu
artefactele noi NU sunt optionale una fata de cealalta — un `update.json`
schimbat fara un release nou din ACELASI moment e o promisiune stricata,
nu doar o intarziere cosmetica. **Fix**: `v1.4.0` creat manual (`gh
release create`, cu aprobarea explicita a lui Cristi) cu `GDCPluginManager-
1.4.0.pkg` (semnat+notarizat+stapled), `GDCPluginManager.pkg` (stabil),
`GDCPluginManager-Mac.zip`, `Dezinstalare_GDCPluginManager.command`, si
`GDCPluginManager-Windows.zip` (installer-ul Windows luat din artefactul
CI al run-ului `33039378596`, deja verificat pe `windows-latest`) — toate
verificate cu sha256 inainte de upload, si confirmat live ca
`releases/latest/download/...` rezolva la v1.4.0 (HTTP 200 pe ambele
platforme). **Regula de proces intarita**: dupa orice bump de
`update.json`, urmatorul pas OBLIGATORIU in aceeasi sesiune e sa
construiesc si sa public un release real cu artefactele corespunzatoare
— niciodata sa las un `update.json` "in avans" fata de ce e chiar
descarcabil.

## Faza 4 (2026-08-26) — Update Checker popup cu Release Notes
Popup-ul modal de actualizare (existent din sesiuni anterioare, doar
text fix) afișează acum și câmpul `changes` din `update.json`
("Noutăți"/"What's new"), și butonul de descărcare e redenumit
"Actualizează acum" (era generic "Descarcă") — vezi CLAUDE.md Partea 1,
Regula 13. Implementat identic pe Mac (`ContentView.swift`) și Windows
(`MainWindow.xaml.cs`, `Wpf.Ui.Controls.MessageBox`). Ghidul PDF
(`installer/generate_pdf.py`, secțiunea 6) explică acum exact fluxul,
RO/EN/ES. Tot NU e self-update silențios — rămâne un pas asistat
(descărcare + reinstalare manuală), documentat explicit ca atare.
- **2026-08-26 — Bug real (identic pe Mac și Windows): verificarea MANUALĂ de update ("Check for Updates..." / butonul din Preferences) minea „Ești la zi" pe o versiune deja respinsă.** Reprodus live din log-ul de diagnostic al lui Cristi (partea Windows — `dismissed=1.3.0` după un „Mai târziu" apăsat, probabil din greșeală, în timp ce explora UI-ul). `availableUpdate` e filtrat de dismissal — corect pentru banner/popup pasiv, dar verificarea manuală citea tot `availableUpdate`, deci mințea la infinit indiferent câte versiuni noi apăreau. **Soluție**: `UpdateChecker.latestInfo` — populat necenzurat de dismissal, la fiecare `check()` reușit. `ContentView.swift` (meniu „Check for Updates...") și `PreferencesView.swift` citesc acum `latestInfo`. **Notă**: prima ipoteză (cache CDN pe `gordas.dev/update.json`) a fost greșită — verificat direct că serverul răspundea corect tot timpul. Adăugat `DiagnosticLog.swift` (nou, `%TEMP%/gdcpm-crash.log`, pereche a celui de pe Windows) — până acum `check()` eșua complet silențios la orice problemă, fără nicio urmă.
- **2026-08-26 — Bug critic găsit pe MediaFlow Monitor, verificat că exista IDENTIC și pe Mac: `LicenseManager.activate(serial:)` exista din prima versiune dar nu era apelat NICĂIERI din UI.** Un client care dona și primea codul pe WhatsApp nu avea fizic cum să-l introducă în aplicație — meniul avea doar "Activează licența (WhatsApp)…" (deschide link-ul de CERERE a codului), niciun câmp de input pentru codul PRIMIT. **Fix Mac**: `NSAlert` cu `NSTextField` accesoriu ("Introdu codul de activare…"), mesaje de eroare per caz (`LicenseCore.ValidationError`). **Fix Windows** (prima implementare de licențiere Windows din tot ecosistemul GDC — nicio altă app standalone nu avea încă LicenseCore/MachineID/RevocationCheck portate pe C#): `Licensing/LicenseCore.cs` folosește `BouncyCastle.Cryptography` (NuGet, pur managed — .NET nu expune Ed25519 nativ pe Windows/CNG), verificat cu un test izolat (proiect console separat, net8.0 non-Windows): round-trip Base32, generare+verificare semnătură cu cheie de test, rejecție corectă la payload alterat (tamper test), și încărcarea reușită a cheii publice GDC reale — toate 9 verificări au trecut înainte de a considera portul corect. **Machine ID pe Windows** folosește `HKLM\SOFTWARE\Microsoft\Cryptography\MachineGuid` (nu IOPlatformUUID ca pe Mac — surse diferite, dar irelevant: `GenerateSerialView.swift` tratează string-ul Base32 afișat ca opac, doar îl decodează direct, nu re-hashează nimic). `ActivationInputWindow.xaml` (WPF nu are input-box nativ) completează fluxul identic cu Mac.

## Etapa 1 — Plan Integrat de Upgrade v2.0 (2026-08-29): Căutare fuzzy + Filtru OS (Client Mac)
Cerință Cristi (plan pe 8 etape, confirmat "confirm" pentru ordinea propusă).
`FuzzySearch.swift` (Core, nou) — substring pe text normalizat (fără
diacritice) + Levenshtein marginit per-cuvânt (typo tolerance), plus
`SearchHistoryStore` (istoric persistat local, plafonat la 8, fără
duplicate). `SearchBar.swift` (Client, nou) — câmp reutilizabil cu
dropdown de sugestii (istoric când e gol, potriviri live când se tastează).
Integrate în `CatalogGrid` (Produse): bară de căutare (nume/descriere/ID/
tip) + `OSFilter` (Toate/Mac/Windows, segmented picker lângă filtrul de
preț existent — produsele `.crossPlatform` apar la orice filtru).
Localizare RO/EN/ES (`search.placeholder`, `filter.os.*`).
Versiune Client `1.4.0`→`1.5.0` (MINOR). `docs/update.json` NEATINS —
fără release nou încă (regula practică 2026-08-27).

**TODO explicit, nu ascuns**: (1) `GDCPluginManagerWin` (Client Windows)
nu are încă acest component — port separat, planificat; (2) bara e doar pe
`CatalogGrid` — `AppsGrid`/`CoursesGrid`/etc. rămân fără căutare/filtru OS
până la o etapă viitoare confirmată; (3) Furnizor nu e atins în această
etapă (Etapele 2+ din plan ating structura de date a produselor).

**Verificat**: `swift build` — 0 erori, 0 avertismente noi.

**[COMPLETARE 2026-08-29] Căutarea a devenit GLOBALĂ, cerută explicit
("trebuie să cuprindă tot ce există în aplicație", "în toate rubricile").**
`SearchBar` locală (era doar în `CatalogGrid`) a fost mutată la nivelul
`ContentView` — un singur câmp, vizibil deasupra `detailContent` pe ORICE
rubrică din sidebar. Câmp gol → comportament identic cu înainte (rubrica
selectată). Câmp nevid → `GlobalSearchResults` (nou, `ContentView.swift`)
înlocuiește conținutul rubricii curente cu rezultate din TOATE cele 8
colecții ale catalogului (Produse, Aplicații, Audio, Cursuri, Materiale,
Evenimente, Magazine partenere, Service & Reparații), fiecare filtrată cu
`FuzzySearch` pe câmpurile ei relevante (nume/titlu/descriere/ID + câmpuri
specifice — tip pentru Produse, categorie pentru Service). Secțiune goală
= nu se randă deloc. Reutilizează card-urile existente (`PluginCard`,
`AppCard`, `CourseCard`, etc.) — zero cod de UI duplicat.
**TODO paritate neschimbat**: `GDCPluginManagerWin` rămâne fără căutare.
**Verificat**: `swift build` — 0 erori.

**[COMPLETARE 2026-08-29] Badge OS: SF Symbols, nu emoji (port pe ambele
platforme).** `SupportedOS.badgeSymbol`/`badgeLabel` (Core) înlocuiesc
`badgeEmoji` — `apple.logo`/`pc`/`arrow.triangle.2.circlepath`, randate ca
chip circular pe card + `Label(systemImage:)` în picker-ul Furnizor. Port
1:1 pe `GDCPluginManagerWin`: `BadgeSymbol()` (Fluent `DesktopMac24`/
`DesktopTower24`/`ArrowSync24`, verificate prezente prin `strings` pe
`Wpf.Ui.dll` — vezi pitfall-ul de acolo despre absență-nu-e-dovadă) +
`SymbolNameConverter.cs` (nou) + `ui:SymbolIcon` în `MainWindow.xaml`.
Versiune ambele clienți: `1.4.0`→`1.5.0`.

**[Etapa 2, parțial] Multi-link + Social pe produse.** `PluginItem`
(Core) capătă `purchaseURL`/`demoURL`/`socialLinks` (`SocialLinks`, nou —
Facebook/YouTube/Instagram/TikTok), toate opționale, decode retrocompatibil
(`decodeIfPresent`). Furnizor: `DisclosureGroup` nou în `PublishView.swift`.
Client: `PluginCard.extraLinksRow` — iconițe SF Symbols, afișate doar dacă
produsul are cel puțin un link completat. **TODO real**: categoriile noi
LUT/SFX/VFX/Plugin pentru download direct multi-host (cerute în planul lui
Cristi) se suprapun conceptual cu modelul auto-install existent (LUT/DCTL
sunt deja categorii, dar auto-instalează în Resolve) — arhitectura exactă
NU a fost implementată încă, cere o decizie explicită a lui Cristi înainte
de a alege un model (extensie a `PluginItem` vs. tip nou gen `AudioTrack`
de download simplu). **TODO paritate**: `GDCPluginManagerWin` nu are încă
multi-link/social — Windows nu are Furnizor, deci doar AFIȘAREA pe card
ar trebui portată, la o etapă viitoare.
**Verificat**: `swift build` (Mac) — 0 erori. `dotnet build`
(`GDCPluginManagerWin`, C# only) — 0 erori; XML validat manual (XAML nu
compilează pe Mac — vezi pitfall dedicat din CLAUDE.md de acolo).

**[COMPLETARE 2026-08-29] Etapa 2 finalizată — Resurse Download direct
(LUT/SFX/VFX/Plugin), model NOU, separat.** Cristi a confirmat explicit:
"produse noi, separate, cu simplu link de download, ca Audio" — deci NU o
extensie a `PluginItem` (auto-install Resolve). `DownloadCategory` (enum:
lut/sfx/vfx/plugin) + `DownloadableResource` (Core, nou) — model 1:1 pe
`AudioTrack` + câmpurile de linkuri/social din Etapa 2. `Catalog.
downloadableResources: [DownloadableResource] = []` (retrocompatibil).
Furnizor: tab nou "Resurse Download" (`PublishDownloadableResourceView.swift`,
mirror `PublishAudioView.swift` + selector categorie + compatibilitate OS +
linkuri suplimentare). Client: 4 rânduri noi în sidebar (unul per
categorie, `SidebarSection.download(DownloadCategory)`), `DownloadResourceGrid`/
`Card` (mirror `AudioGrid`/`Card`, plus filtru OS ca la Produse și rândul
de linkuri extra — extras logica în `ExtraLinksRow`/`LinkIconButton`,
funcții shared la scope de fișier, reutilizate de `PluginCard` ȘI
`DownloadResourceCard`, ca să nu dubleze cod). `GlobalSearchResults`
extins la 9 colecții (era 8) — căutarea globală acoperă și noile resurse.
**Notă de scop, nu o omisiune**: "Efecte Audio/SFX" ca nouă categorie
coexistă acum cu secțiunea veche "Audio" (`AudioTrack`) — cele două NU
sunt unificate (ar necesita migrare de date/breaking change pe catalogul
existent, nerequested) — Cristi alege unde publică conținut audio nou.
**TODO paritate**: `GDCPluginManagerWin` nu are Furnizor (publicarea
rămâne exclusiv pe Mac) — de portat doar AFIȘAREA (Core model +
sidebar/grid Windows), la o etapă viitoare.
Versiune: Client `1.5.0`→`1.6.0`, Furnizor `1.3.0`→`1.4.0` (MINOR).
**Verificat**: `swift build` (Client + Furnizor + Core) — 0 erori.

**[COMPLETARE 2026-08-29] Sidebar Client — 5 secțiuni clar delimitate
(`Section`, nu doar `Divider`).** Cristi: "să nu se încurce lumea" — grupare
logică cu titlu gri deasupra fiecărui grup: (1) INSTALARE DAVINCI RESOLVE
(Toate + PluginType), (2) RESURSE DOWNLOAD Premiere/FCP/Resolve (Audio +
DownloadCategory), (3) COMUNITATE & EDUCAȚIE (Cursuri/Materiale/Evenimente/
Magazine/Service), (4) ECOSISTEM GDC (Aplicații/Aplicație mobilă), (5)
CONTUL TĂU (Licență/Ajutor). Localizare RO/EN/ES (`sidebar.section.*`).

**NOTĂ pentru Etapa 6 (Watermark/Banner sezonier), NU implementată încă**:
Cristi a cerut explicit ca, atunci când ajungem la acea etapă, pe lângă
upload propriu de imagine, să pregătesc și un SET de SVG-uri tematice
predefinite, alese de el pentru colțul dreapta-jos (suprafață mai mare,
nu doar un icon mic): Oferte Black Friday, Crăciun (brad + Moș Crăciun +
"Sărbători Fericite"), Revelion/Anul Nou, Ofertă de Primăvară, Paște,
Vară/Vacanță, Ofertă Flash/Super Ofertă. Nu uita de asta la Etapa 6.

**[COMPLETARE 2026-08-29] Etapa 3 — "Aplicațiile Mele" (Quick Launcher).**
`MyAppsLauncher.swift` (nou) — sidebar nou `SidebarSection.myApps`, în
grupul ECOSISTEM GDC. Detectarea "deținerii" unei aplicații GDC NU se
face prin licență (fiecare aplicație GDC își ține activarea separat local,
GDCPluginManager n-are acces) — se face prin PREZENȚA aplicației instalate
(`NSWorkspace.urlForApplication(withBundleIdentifier:)`), aproximare
corectă în practică. `knownGDCApps` (hardcodat, 4 aplicații cu bundle .app
real, verificate din `Info.plist`-urile reale ale fiecărui repo):
DataMover (`dev.gordas.datamover`), CursorPro GDC (`com.gordasgdc.cursorpro`),
GDC Vault (`com.gordasgdc.vault`), MediaFlow Monitor
(`com.gdc.mediaflowmonitor`). **Exclus intenționat, nu omis**: `gdc-
production-manager` (script Python, `run-mac.command`, fără bundle .app
standard) și `gdc-resolve-encoder` (bibliotecă C++ apelată DIN Resolve,
niciodată lansată direct de user) — n-au ce "lansa" în sensul ăsta.

Verificare versiune per aplicație (`VersionSource`, două surse reale,
verificate din codul fiecărui repo — NU presupuse): DataMover/CursorPro/
GDC Vault citesc `api.github.com/repos/<repo>/releases/latest`
(`tag_name`); MediaFlow Monitor are propriul `update.json`
(`gordas.dev/media-flow-monitor/update.json`). Badge "ACTUALIZARE" apare
doar dacă versiunea instalată (citită din `Info.plist`-ul real al
bundle-ului găsit) e mai veche decât cea de pe server.

Scurtături personalizate (`CustomLauncher`) — persistate local
(`UserDefaults`, JSON), adăugate prin `fileImporter` (alege orice `.app`
din Finder, ex. DaVinci Resolve Studio/Premiere/Photoshop/Lightroom), cu
buton de lansare + ștergere.

**TODO paritate**: `GDCPluginManagerWin` nu are încă "Aplicațiile Mele" —
pe Windows detectarea ar folosi Registry (`Uninstall` keys) sau căi
cunoscute din Program Files, diferit de `NSWorkspace` — port separat.
Versiune: Client `1.6.0`→`1.7.0` (MINOR). **Verificat**: `swift build` — 0 erori.

**[COMPLETARE 2026-08-29] Etapa 4 — Scheduler From/To, Oferte Parteneri,
Badge-uri Discount.** `Scheduling` (Core, nou) — `startDate`/`endDate`
opționale + `isActiveNow` (comparat cu ora dispozitivului clientului, nu
server — suficient pentru acest caz). Adăugat ca `scheduling: Scheduling?`
pe `Course`, `EducationalResource`, `Event` (retrocompatibil, `nil` =
mereu vizibil, identic cu comportamentul dinainte). Filtrare aplicată la
apelul fiecărui Grid din `ContentView.detailContent` ȘI în
`GlobalSearchResults` (căutarea globală respectă și ea expirarea).

**`PartnerOffer`** (Core, nou) — model separat pentru promoții de la
branduri PARTENERE (ex. discount echipament foto/video). **Decizie de
scop explicită**: limbajul de discount/procent e PERMIS aici (nu intră
sub Regula 3, Partea 1 — aceea acoperă produsele/resursele PROPRII GDC,
nu relații comerciale cu terți). `discountText` (text liber, nu procent
numeric — acoperă și "2 la preț de 1"), `couponCode`, `socialLinks`,
`scheduling`. Furnizor: tab nou "Oferte Parteneri"
(`PublishPartnerOfferView.swift`). Client: sidebar nou (grup COMUNITATE
& EDUCAȚIE) + `PartnerOffersGrid`/`Card` — badge roșu de discount generat
automat din `discountText`, afișat doar dacă e completat.

**`SchedulingPicker.swift`** (Furnizor, nou) — component reutilizabil
(toggle + 2 `DatePicker`), integrat în `PublishCourseView`/
`PublishEducationalResourceView`/`PublishEventView`/`PublishPartnerOfferView`.

**TODO paritate**: `GDCPluginManagerWin` nu are Furnizor — doar AFIȘAREA
(Core model + filtrare scheduling + grid Oferte) ar trebui portată pe
Windows la o etapă viitoare.
Versiune: Client `1.7.0`→`1.8.0`, Furnizor `1.4.0`→`1.5.0` (MINOR).
**Verificat**: `swift build` (Client + Furnizor + Core) — 0 erori.

**[COMPLETARE 2026-08-29] Scheduling extins la TOATE rubricile + fix
buton-mut la publicare + sumă promoțională pe produse proprii.**

1. **Buton "Publică" dezactivat FĂRĂ mesaj — bug real de UX, raportat de
   Cristi ("am încercat să dau publică, dar nu m-a lăsat... doar gri/
   dezactivat, fără mesaj").** `PublishPartnerOfferView` (și implicit
   toate celelalte forme cu `isFormValid`) dezactivau butonul silențios
   dacă lipsea ID/nume/URL valid, fără să spună CE lipsește. Fix (aplicat
   întâi acolo): `validationHint` — text portocaliu sub buton, listează
   explicit ce lipsește ("Lipsește: ID ofertă, Link magazin..."). **TODO
   rămas**: același fix trebuie aplicat și pe celelalte forme mai vechi
   (`PublishAudioView`, etc.) — momentan doar Oferte Parteneri îl are.

2. **`scheduling: Scheduling?` adăugat la TOATE modelele** (nu doar
   Cursuri/Materiale/Evenimente/Oferte): `PluginItem`, `AppLink`,
   `AudioTrack`, `PartnerStore`, `ServiceCenter`, `DownloadableResource`.
   Cerut explicit: "valabilitate temporală trebuie să fie la toate
   rubricile". `SchedulingPicker` integrat în TOATE formularele Furnizor
   (`PublishView`, `PublishAppView`, `PublishAudioView`,
   `PublishPartnerStoreView`, `PublishServiceCenterView`,
   `PublishDownloadableResourceView`). Filtrare aplicată la fiecare punct
   de afișare din `ContentView.detailContent` ȘI în `GlobalSearchResults`
   (toate cele 9 colecții, nu doar 4).

3. **`PluginItem.promoPriceEUR` (nou) — sumă de susținere PROMOȚIONALĂ
   temporară pentru produsele PROPRII GDC (ex. Black Friday).** Cristi:
   "trebuie să pun la anumit preț acele produse, să fie oricum discount".
   **Decizie de conformitate cu Regula 3 (Partea 1)**: rămâne 100%
   donație — activă DOAR cât timp `scheduling` e activ
   (`effectivePriceEUR`/`isPromoActive`), afișată cu suma veche tăiată +
   badge roșu "Susținere promoțională" — NICIODATĂ "reducere"/"discount"/
   "-X% OFF" (acela rămâne EXCLUSIV pentru `PartnerOffer`, relație
   comercială cu terți, unde limbajul de discount e permis). Mesajul
   WhatsApp de activare folosește automat suma promoțională activă.
   Furnizor: câmp nou "Sumă promoțională temporară" în `PublishView`,
   vizibil doar la Acces=Plătit.

**TODO paritate**: `GDCPluginManagerWin` nu are Furnizor — doar AFIȘAREA
(filtrare scheduling + `effectivePriceEUR`) ar trebui portată pe Windows.
Versiune: Client `1.8.0`→`1.9.0`, Furnizor `1.5.0`→`1.6.0` (MINOR).
**Verificat**: `swift build` (Client + Furnizor + Core) — 0 erori.

**[COMPLETARE 2026-08-29] Etapa 5 — Google Maps la adrese + memorare locală
folder de download.**

1. **`MapsLink.url(for:)`** (Core, nou) — deep-link către endpoint-ul
   public de căutare Google Maps (`api=1&query=<text>`), fără cheie API.
   `Event` folosește `location`-ul deja existent; `PartnerStore` și
   `ServiceCenter` capătă un câmp NOU, `address: String?` (opțional,
   distinct de `websiteURL`/`url`). `mapsURL` computed pe toate 3. Client:
   `MapButton(mapsURL:)` (shared, ca `ExtraLinksRow`) — nu se randă deloc
   fără adresă. Furnizor: câmp "Adresă fizică" în `PublishPartnerStoreView`/
   `PublishServiceCenterView`.

2. **[Adăugat mid-etapă, cerut explicit] Memorare loc de descărcare pe
   Resurse Download.** Cristi: "să aibă posibilitatea să își pună path-ul...
   ca să știe tot timpul unde l-a descărcat". `DownloadLocationStore.swift`
   (nou) — stare 100% LOCALĂ (UserDefaults, cheiată după ID resursă), NU
   parte din catalog.json (per-client, nu conținut publicat). Pe
   `DownloadResourceCard`: buton "Unde l-ai salvat?" → `NSOpenPanel`
   (alegere folder) → odată setat, arată calea + buton "Deschide folderul"
   (`NSWorkspace.selectFile`) + "Schimbă".

**TODO paritate**: `GDCPluginManagerWin` nu are Furnizor (adresă/Maps
button ar trebui portate doar la afișare) și nici `DownloadLocationStore`
(echivalent Windows: `Environment.SpecialFolder` + `FolderBrowserDialog`).
Versiune: Client `1.9.0`→`1.10.0`, Furnizor `1.6.0`→`1.7.0` (MINOR).
**Verificat**: `swift build` (Client + Furnizor + Core) — 0 erori.

**[COMPLETARE 2026-08-29] Licențiere completă pe Resurse Download —
lacună reală, semnalată explicit de Cristi ("nu am varianta aia de
gratuit, plătit, trimite ID mașină, cumpără produsul, WhatsApp").**
`DownloadableResource` (Core) trecut la Codable custom (era sintetizat) —
adăugat `isFree`/`isTrial`/`priceEUR`/`promoPriceEUR`, port 1:1 al
modelului de pe `PluginItem` (`effectivePriceEUR`/`isPromoActive`
identice). **Retrocompatibil corect**: `isFree` decodează implicit
`true` (nu `false` ca la `PluginItem`) — orice resursă publicată înainte
de acest câmp rămâne exact "liberă, fără cod", nu devine silențios
"plătită fără licență activabilă".

`LicenseManager.isUnlocked(for: DownloadableResource)` (nou) — REFOLOSEȘTE
`licensedProducts` (cheiat generic după ID de produs) și `RevocationCheck`,
zero infrastructură nouă. `LicensePane.candidateProductIDs` extins cu
`catalog.downloadableResources.map(\.id)`, ca un cod lipit să valideze și
pentru aceste resurse. Furnizor: `PublishDownloadableResourceView` capătă
Picker Acces (Gratuit/Plătit/Probă, reutilizează `AccessMode` din
`PublishView.swift`) + preț + sumă promoțională; `GenerateSerialView`
capătă secțiune nouă "Resurse Download" în Picker-ul de produs. Client:
`DownloadResourceCard` — badge Gratuit/Probă/Licență+preț (identic
`PluginCard`), buton WhatsApp cu ID mașină când blocată, "Descarcă" doar
după deblocare; rândul de "unde l-ai salvat" (Etapa 5) apare doar pe
resurse deblocate.

**[Fix conex] `validationHint` (bug-ul de buton mut) adăugat și pe
`PublishDownloadableResourceView`** — nu doar pe Oferte Parteneri.
**TODO rămas**: celelalte forme mai vechi (`PublishAudioView`, etc.) încă
nu au acest hint.

**TODO paritate**: `GDCPluginManagerWin` nu are Furnizor — doar
afișarea/deblocarea (Core model + `LicenseManager.cs` overload) ar trebui
portată pe Windows.
Versiune: Client `1.10.0`→`1.11.0`, Furnizor `1.7.0`→`1.8.0` (MINOR).
**Verificat**: `swift build` (Client + Furnizor + Core) — 0 erori.

**[COMPLETARE 2026-08-29] Etapa 6 — Filigran sezonier (NU banner mic).**
Cristi a clarificat explicit: nu o iconiță în colț, ci "o imagine mai
mare... ca și cum ar fi sculptat/imprimat în fundal". Implementat ca strat
mare (480×480, depășește ușor colțul), opacitate 7%, ÎN SPATELE
conținutului (`.background()`, `allowsHitTesting(false)`), nu deasupra.

`Catalog.seasonalBackground: String?` (Core, nou) — UN SINGUR slot global
(nu per-produs), același sistem hibrid cale-relativă/URL-extern ca
`coverImage`. `SeasonalBackgroundStore.swift` (Furnizor, nou) —
DELIBERAT separat de `CoverImageStore`: copiază fișierul BRUT, fără
compresie/rasterizare (SVG-ul ales de Cristi rămâne vectorial). Galerie
predefinită (`SeasonalPresets`, 7 SVG-uri inline, monocrome — Black
Friday, Crăciun, Revelion, Primăvară, Paște, Vară, Ofertă Flash), plus
upload propriu (imagine sau SVG). Tab nou Furnizor "Interfață Client
(Filigran)". Client: `SeasonalBackgroundLayer` (nou) randează filigranul
via `AsyncImage` — SVG suportat nativ de ImageIO pe macOS 12+.

**TODO paritate**: `GDCPluginManagerWin` nu are Furnizor — doar AFIȘAREA
(citire `seasonalBackground` din catalog + randare fundal) ar trebui
portată pe Windows.
Versiune: Client `1.11.0`→`1.12.0`, Furnizor `1.8.0`→`1.9.0` (MINOR).
**Verificat**: `swift build` (Client + Furnizor + Core) — 0 erori.

**[COMPLETARE 2026-08-29] Fix hartă pe "Online" + Autocomplete pe câmpuri
repetitive (Furnizor).**

1. **`MapsLink.url(for:)` (Core) ignoră termeni non-fizici** ("online",
   "webinar", "virtual", "zoom", etc., normalizat fără diacritice/
   majuscule) — Cristi: "am multe locuri în care e online... nu are
   sens o căutare Maps pentru asta". Butonul de hartă pur și simplu nu
   apare pentru aceste valori, în loc să deschidă o căutare absurdă.

2. **`AutocompleteTextField.swift` (Furnizor, nou)** — cerut explicit:
   "dacă scriu cuvinte repetitive [ex. „Online", numele unei firme], să
   mi le sugereze". DELIBERAT fără store propriu de istoric — sugestiile
   vin direct din valorile deja folosite pe alte produse deja publicate
   (`existingItems`/`existingStores`/etc., deja încărcate de fiecare
   view), fuzzy-filtrate pe măsură ce tastezi. Integrat pe câmpurile cu
   risc real de repetiție: `PublishEventView` (Locație), `PublishPartnerStoreView`/
   `PublishServiceCenterView` (Adresă fizică, Specializare),
   `PublishPartnerOfferView` (Nume brand).
   **TODO rămas**: nu e încă pe toate câmpurile de text din Furnizor —
   doar cele semnalate explicit ca repetitive.

Versiune: Client `1.12.0`→`1.12.1` (PATCH — doar fix Maps), Furnizor
`1.9.0`→`1.10.0` (MINOR — funcționalitate nouă vizibilă).
**Verificat**: `swift build` (Client + Furnizor + Core) — 0 erori.

**[BUG REAL, GĂSIT ȘI REPARAT 2026-08-29] Filigranul Black Friday nu
apărea deloc în Client — nu era o problemă de publicare.** Cristi a
activat filigranul din Furnizor, dar nimic nu apărea în Client. Verificat
direct, cu `curl`, că publicarea a mers perfect: `catalog.json` live avea
`seasonalBackground` setat corect, iar `background.svg` răspundea HTTP
200 cu `content-type: image/svg+xml`. **Cauza reală**: `AsyncImage`
(SwiftUI) nu randează fiabil SVG pe macOS — decodorul lui intern nu
trece prin `NSImage`, singurul care are suport SVG (adăugat în macOS
12+). Confirmat izolat, cu un test dedicat (`swift /tmp/svgtest.swift`,
`NSImage(data:)` pe același SVG) — a decodat corect. **Fix**:
`SeasonalBackgroundLayer` nu mai folosește `AsyncImage` — descarcă
manual (`URLSession.shared.data(from:)`) și construiește `NSImage(data:)`
explicit, afișat prin `Image(nsImage:)`. **Regulă practică nouă**:
`AsyncImage` NICIODATĂ pentru un URL care poate fi SVG în acest
ecosistem — doar pentru rastere (jpg/png), unde funcționează normal.

**[ÎNVECHIT 2026-08-29, refăcut complet la cererea explicită a lui
Cristi] Galeria predefinită de filigrane era inacceptabil de slabă.**
Feedback direct: "arată ca făcut de un copil de 3 ani... nici pe departe
ce mă imaginam" — prima variantă avea doar o formă geometrică goală și
un simbol vag, fără text, fără să sugereze tema. Refăcute complet toate
cele 7 (`SeasonalPresets` din `SeasonalBackgroundStore.swift`) ca SCENE
recognoscibile + text explicit: Black Friday (text mare + tag de preț cu
"%"), Crăciun (brad cu ornamente + 2 cadouri + stea + ninsoare +
"Sărbători Fericite"), Revelion (artificii + pahar de șampanie +
"LA MULȚI ANI!"), Primăvară (soare + 2 flori + păsărică + iarbă),
Paște (iepuraș + coș cu ouă + "Paște Fericit"), Vară (umbrelă de plajă +
soare + valuri + pahar cu pai), Ofertă Flash (fulger conturat + explozie
+ "FLASH OFFER"). **Regulă de compoziție pentru orice preset viitor**:
text SEPARAT de forme (niciodată suprapus peste o umplere solidă albă) —
un fundal alb cu text tot alb ar deveni invizibil la opacitatea mică
aplicată în Client (`SeasonalBackgroundLayer`), fiindcă tot SVG-ul se
randă la o singură valoare de opacitate uniformă. Verificat vizual
înainte de livrare: randate toate 7 pe fundal întunecat (script Swift
izolat, `NSImage(data:)` → PNG), trimise ca fișiere lui Cristi pentru
confirmare — **confirmat explicit** ("Arată mult mai bine acum").

**[COMPLETARE 2026-08-29] Etapa 7 — Filtrare avansată + Export email pe
loturi pentru BCC (Furnizor, Clienți).** `SalesLog.Entry.isActive` (nou)
— parsează `expiresDisplay` ("nu expira" sau prefixul `yyyy-MM-dd`, format
stabil din `GenerateSerialView.generate()`) pentru filtrul nou
"Toate/Active/Expirate" din `SalesHistoryView`. ID de mașină e acum
căutabil direct din câmpul de căutare existent (nu un filtru separat —
ar fi dublat funcționalitate). **"Select All" = comportamentul implicit**
al exportului deja existent (Regula 15): operează pe TOATE rândurile care
trec de filtrele curente, fără checkbox-uri per-rând (ar fi dublat exact
ce fac filtrele).

`EmailBatchExportView.swift` (nou) — segmentare automată în loturi
(10/50/100 sau personalizat) din e-mailurile UNICE ale selecției curente,
fiecare lot cu propriul buton "Copiază pentru BCC" (separator `; `,
acceptat de Gmail/Outlook/Apple Mail la lipire directă în câmpul BCC).

**TODO paritate**: `GDCPluginManagerWin` nu are Furnizor — nu se aplică.
Versiune: Furnizor `1.10.0`→`1.11.0` (MINOR).
**Verificat**: `swift build` (Furnizor) — 0 erori.

**[COMPLETARE 2026-08-29] Etapa 9 — Pachete/Bundle-uri.** Idee a lui
Cristi: "combin produse, unul sau mai multe, să le vând la bulk, la super
ofertă". **Decizie arhitecturală deliberată**: `ProductBundle` (Core, nou)
e DOAR un construct de prezentare/marketing (grupare + preț total
afișat), NU un mecanism nou de licențiere — achiziția rămâne prin
WhatsApp (ca la orice produs), iar Furnizorul generează în continuare,
manual, câte o licență per produs inclus (fluxul de încredere bazat pe
donație+WhatsApp deja funcțional nu se schimbă). `BundleItemRef` (kind:
`product`/`download`/`course` + id) — un pachet poate combina produse din
categorii diferite (ex. un Curs + un pachet de LUT-uri, exact exemplul
dat). Furnizor: tab nou "Pachete / Bundle-uri" (`PublishBundleView.swift`)
— checklist cu TOATE produsele/resursele/cursurile publicate, preț total
+ afișare automată a sumei individuale pentru comparație. Client: sidebar
nou (grup COMUNITATE & EDUCAȚIE) + `BundleGrid`/`Card` — listă de produse
incluse rezolvate live din catalog (un ID șters ulterior e omis silențios,
nu crapă cardul), sumă individuală tăiată + preț pachet, buton WhatsApp
cu lista produselor în mesaj. Inclus în `GlobalSearchResults` (10 colecții
acum). Scheduling (Etapa 4) funcționează identic — poți lega un pachet
strict de perioada Black Friday.

**TODO paritate**: `GDCPluginManagerWin` nu are Furnizor — doar AFIȘAREA
(Core model + grid Bundle-uri) ar trebui portată pe Windows.
Versiune: Client `1.12.1`→`1.13.0`, Furnizor `1.11.0`→`1.12.0` (MINOR).
**Verificat**: `swift build` (Client + Furnizor + Core) — 0 erori.

**[COMPLETARE 2026-08-29] Pachete extinse la Audio + Aplicații +
Materiale.** Cristi a întrebat dacă poate combina "toate ce există pe
platformă" — clarificat pe rând: Audio adăugat direct (conținut propriu,
fără ambiguitate). Aplicații/Materiale — confirmat explicit de Cristi
("toate aplicații sunt făcute de mine, materiale la fel") — adăugate ca
tipuri valide de pachet. Oferte Parteneri (terți) și Evenimente
(informativ) rămân EXCLUSE deliberat — nu sunt produse proprii vândute.
**Cursurile rămân incluse** (erau deja, de la implementarea inițială —
confirmat explicit prin întrebare directă, nicio schimbare). `BundleItemKind`
capătă `.audio`, `.app`, `.material` (total 6 tipuri combinabile: produse,
resurse download, cursuri, audio, aplicații, materiale). Niciunul din
Audio/Aplicații/Materiale nu are preț propriu în model — nu contribuie la
suma individuală calculată automat, doar apar în lista de conținut a
pachetului.
Versiune: Client `1.13.0`→`1.13.1`, Furnizor `1.12.0`→`1.12.1` (PATCH).
**Verificat**: `swift build` (Client + Furnizor + Core) — 0 erori.

## [COMPLETARE 2026-08-29] Etapa 8 — Cache local finalizat

**Constatare**: `catalog.json` avea deja cache complet funcțional
(`catalog-cache.json` în Application Support, fallback offline automat la
eșec de rețea) — implementat implicit încă de la primele versiuni.

**Gap găsit și rezolvat**: filigranul sezonier (`SeasonalBackgroundLayer`)
se descărca mereu de la zero, fără persistare pe disc — offline sau la
eșec de rețea, filigranul dispărea complet. Adăugat cache pe disc
(`Application Support/GDCPluginManager/seasonal-background-cache`) după
același model ca `catalog-cache.json`: la succes se salvează pe disc, la
eșec se încearcă ultima variantă salvată local.

**Status**: Verificat — build 0 erori, instalat, v1.13.2 (Client).

**TODO paritate Windows**: nu se aplică — `GDCPluginManagerWin` nu are
încă filigran sezonier implementat (vezi TODO Etapa 6).

## [FINALIZARE 2026-08-29] Publicare produs final client — web + Mac

**1. Paritate mobil (PWA, servit la gordas.dev/app.html)** — lipseau complet
Resurse download, Servicii, Oferte Parteneri, Pachete + scheduling + hărți +
filigran sezonier (existau doar pe Mac). Rezolvat:
- Tabbar extins 4→5: Produse, **Resurse** (nou), Cursuri, Evenimente,
  **Comunitate** (extins: Magazine + Servicii + Oferte + Pachete).
- Filtru `isActiveNow` (scheduling) aplicat pe TOATE colecțiile randate —
  logica identică cu `Scheduling.isActiveNow` din Swift, portată în JS
  (`SWIFT_REF_MS = 978307200000`, referința 2001-01-01 UTC a `Date`-urilor
  codate de JSONEncoder).
- Buton hartă (`mapsUrl`) — port 1:1 al stoplist-ului din `MapsLink.swift`.
- Filigran sezonier — `<img>` simplu (nu AsyncImage, nu exista bug-ul de pe
  Mac — un `<img>` de browser randează SVG nativ).
- Bug preexistent găsit și reparat: `onerror` de pe cardurile
  Aplicații/Audio scăpa apostroful dar NU ghilimelele duble din SVG-ul
  inline, rupea atributul HTML la parsare → text vizibil `'">` pe fiecare
  card, indiferent dacă imaginea eșua sau nu. Fix: `.replace(/"/g,"&quot;")`.
- `manifest.webmanifest`: descriere actualizată, shortcut nou "Resurse".
- `sw.js`: CACHE_VERSION v11→v12.
- Android: NU există build/APK de refăcut — comentariul din
  `manifest.webmanifest` confirmă TWA-ul retras pe 2026-08-24; PWA-ul
  CHIAR e aplicația, deschisă direct în browser. Push-ul pe gordas.dev
  actualizează automat Android + iPhone.

**2. Logo-uri reale pentru Aplicații (Client + Furnizor)** — coperțile
foloseau fotografii/bannere generice în loc de logo-ul fiecărei aplicații.
Extrase `.icns`-urile reale din reposurile surori (CGConvertor, CursorPro,
DataMover, gdc-production-manager, GDCVault, MediaFlow-Monitor) + un PNG
existent pentru Clapperboard Digital, procesate prin ACELAȘI
`ImageProcessor.process(preset: .icon)` folosit de Furnizor (via un mini
pachet SwiftPM temporar, ca să nu se atingă `Package.swift`-ul real),
publicate în `docs/covers/`. Rămân neschimbate (fără logo real disponibil):
gdc-resolve-encoder, GDC Metadata View Premium, Simulator DOF.

**3. Release Mac v1.13.2** — semnat (`Developer ID Application` +
`Developer ID Installer`), notarizat (profil `gdc-notary` deja configurat),
stapled. Publicat pe GitHub Releases (`gh release create v1.13.2`, cu
`GDCPluginManager-Mac.zip` + `.pkg`). `update.json` actualizat la 1.13.2.

**RISC CUNOSCUT, ACCEPTAT EXPLICIT DE CRISTI (2026-08-29)**: `update.json`
e comun Mac+Windows (un singur câmp `version`). Windows n-a primit NICIUNA
din cele 9 etape (rămâne la 1.5.0 local, fără build azi) — userii Windows
vor vedea "update disponibil" la 1.13.2, dar descărcarea `download_url.windows`
va da 404 până se construiește și urcă un build Windows nou în release.
**TODO următor**: implementare completă a celor 9 etape pe
`GDCPluginManagerWin` (display-only, nu are Furnizor) + build + upload
`GDCPluginManager-Windows.zip` în release-ul v1.13.2 existent (`gh release
upload v1.13.2 ...`), ca 404-ul să dispară.

## [SESIUNE 2026-08-29] Trei cerințe Cristi: social pe toate rubricile, selector de temă, bibliotecă de filigrane

Trei cereri explicite, implementate ca trei commit-uri separate. `swift build`
(Core + Client + Furnizor) — 0 erori după fiecare.
Versiuni finale: **Client 1.13.2 → 1.16.0**, **Furnizor 1.12.2 → 1.15.0**
(câte un MINOR per cerință, Regula 14). `docs/update.json` NEATINS —
rămâne decizia lui Cristi, separat. `docs/sw.js`: CACHE_VERSION v12 → v14.

### 1. Rețele sociale pe TOATE rubricile + LinkedIn

`SocialLinks` exista, dar era câmp doar pe 4 modele (PluginItem,
DownloadableResource, PartnerOffer, ProductBundle). Adăugat `socialLinks:
SocialLinks?` pe celelalte 6: `Course`, `EducationalResource`, `Event`,
`PartnerStore`, `ServiceCenter`, `AppLink` — adică toate rubricile din
grupurile COMUNITATE & EDUCAȚIE și ECOSISTEM GDC.

**LinkedIn adăugat** pe `SocialLinks` (întrebare directă a lui Cristi: da).

**Decizie de retrocompatibilitate**: cele 6 structuri folosesc Codable
SINTETIZAT, nu custom `CodingKeys` ca `PluginItem`. Pentru o proprietate
Optional, Swift tratează o cheie lipsă ca nil la decodare și o omite la
encodare — deci nu e nevoie de `decodeIfPresent` scris de mână, exact
tiparul deja folosit pentru `scheduling` pe aceleași structuri. Verificat
pe `docs/catalog.json` REAL: toate cursurile/materialele vechi decodează cu
`socialLinks == nil`, restul colecțiilor rămân intacte.

**Iconița LinkedIn (Client)**: SF Symbols NU are glif de brand LinkedIn
(Apple nu livrează logo-uri de terți) → `link.circle`, varianta propusă de
Cristi, cu tooltip "LinkedIn". Pe PWA există `LI_ICON` (SVG monocrom
propriu, în stilul `PIN_ICON`/`WA_ICON`/`YT_ICON`).

**Zero cod duplicat**: `SocialLinksRow(_:)` (Client) e un wrapper subțire
peste `ExtraLinksRow` deja existent. În Furnizor, `SocialLinksEditor.swift`
(nou) aduce `SocialLinksFormState` + `SocialLinksFields` +
`SocialLinksSection` — un singur `@State` per formular în loc de 5 câmpuri
separate; cele 4 formulare care aveau deja social au fost REFACTORIZATE pe
componenta nouă (nu lăsate divergente), iar cele 6 care nu aveau au primit
`SocialLinksSection`.

**PWA**: `socialMiniLinks` e apelată acum și la Cursuri/Materiale,
Evenimente, Pachete, Magazine, Servicii, Aplicații. Pitfall prins la
implementare: cardul de Aplicații era un `<a>`, iar linkurile sociale sunt
tot ancore — ancore imbricate = HTML invalid. Cardul devine `<div>` în
coloană cu rândul principal ca ancoră separată, DOAR când există linkuri
sociale (altfel rămâne exact ce era).

### 2. Selector explicit de temă Sistem/Light/Dark (lacună față de Regula 18)

Regula 18 (Partea 1) o cere din 2026-08-26; niciuna dintre cele două
aplicații Mac nu o avea. `AppTheme.swift` — port 1:1 al implementării de
referință din MediaFlow Monitor, pus în **Core** ca să fie folosit identic
de amândouă aplicațiile, nu două copii care pot diverge. Persistat în
`UserDefaults` (`GDCPluginManager.appTheme`); cheia e aceeași literal în
ambele, dar domeniile de preferințe sunt separate (bundle ID-uri diferite),
deci alegerile lor nu se calcă reciproc.

**Decizie: `NSApp.appearance`, NU `.preferredColorScheme()`.**
`preferredColorScheme` afectează doar ierarhia SwiftUI a acelei ferestre —
meniurile, panourile native (`NSOpenPanel`/`NSAlert`), popover-ele și
fereastra de Preferences ar fi rămas pe tema sistemului, adică exact
incoerența pe care selectorul trebuie s-o elimine. `applyNow()` e chemat din
`.onAppear`-ul ferestrei principale, fiindcă `ThemeManager` se poate
inițializa înainte ca `NSApp` să existe (atunci `apply()` din init n-are pe
ce scrie).

Client: secțiune nouă "Temă" în `PreferencesView.swift` (Cmd+,), localizată
RO/EN/ES. Furnizor: NU avea niciun ecran de setări — adăugat `Settings`
scene + `FurnizorPreferencesView.swift` (nou). Furnizorul nu e scutit de
standard doar pentru că e instrument intern (același raționament ca Regula
15 despre versiunea vizibilă în UI).

### 3. Filigrane sezoniere: bibliotecă reutilizabilă, cu perioadă și poziție

Etapa 6 avea `Catalog.seasonalBackground: String?` — UN SINGUR slot global,
fără perioadă proprie, mereu jos-dreapta, iar o imagine proprie încărcată
era folosită o dată și pierdută la următoarea. Cristi a cerut explicit: (a)
din ce dată până în ce dată apare, (b) unde apare pe ecran, (c) ca fișierele
proprii încărcate să rămână SALVATE și reutilizabile.

**Model nou (Core)**: `SeasonalBackgroundConfig` (`id`, `label`,
`imagePath`, `scheduling: Scheduling?` — reutilizat, nu unul nou —,
`position: SeasonalPosition`, `isEnabled`) + `SeasonalPosition`
(bottomTrailing/bottomLeading/topTrailing/topLeading/center, implicit
bottomTrailing). `Catalog.seasonalBackground` devine
`seasonalBackgrounds: [SeasonalBackgroundConfig]` — o BIBLIOTECĂ, nu un slot.

**Retrocompatibilitate (verificată pe catalogul LIVE, nu presupusă)**:
`Catalog.init(from:)` încearcă întâi cheia nouă; dacă lipsește și există
cea veche (`seasonalBackground`, String), o migrează silențios într-o
intrare unică — fără scheduling (mereu activă), poziție `.bottomTrailing`,
adică EXACT ce arăta înainte. Testat pe `docs/catalog.json` real
(`covers/seasonal/background.png?v=3a8a64dc`): migrează corect, round-trip-ul
nu mai scrie niciodată cheia veche, restul colecțiilor rămân intacte.

**DECIZIE DE COLIZIUNE (deliberată, documentată)**: dacă mai multe filigrane
active cad pe ACEEAȘI poziție, câștigă **ULTIMUL din listă** (ultimul
adăugat/editat în Furnizor). Suprapunerea a două imagini în același colț ar
da o pată ilizibilă; alegerea e stabilă și previzibilă, nu aleatorie, și nu
aruncă niciodată eroare. Filigranele pe poziții DIFERITE se randează toate.
Logica trăiește într-un singur loc — `[SeasonalBackgroundConfig]
.activeNowDeduplicated` (Core) — folosit și de Client, și portat 1:1 în JS
pentru PWA.

**RECOMANDARE PNG vs SVG (întrebare directă a lui Cristi): SVG.** Vectorial
(nepixelat la orice rezoluție/DPI, inclusiv Retina), fișier mult mai mic,
ușor de recolorat/editat ulterior, și e deja tehnologia celor 7 presetări
din `SeasonalPresets`. PNG rămâne perfect acceptabil pentru poze reale (un
logo fotografic complex), dar pentru orice grafică sau text desenat, SVG e
alegerea corectă. **AMBELE rămân suportate la upload** — doar recomandarea
implicită e SVG (scrisă și în UI-ul Furnizorului, nu doar aici).

**Furnizor**: `SeasonalBackgroundStore` scrie acum un fișier PER INTRARE
(`docs/covers/seasonal/<id>.<ext>`), nu un `background.<ext>` global —
încărcarea unei imagini noi ADAUGĂ, nu înlocuiește; `removeFiles(id:)`
curăță fișierul la ștergerea din bibliotecă (altfel ar rămâne orfan în repo,
exact pitfall-ul deja documentat la coperți). `SeasonalBackgroundView` e o
listă: nume + thumbnail + stare/perioadă + toggle Activ + Picker de poziție
(5 opțiuni) + `SchedulingPicker` (REUTILIZAT, cel de la Etapa 4) + buton
Șterge; adăugare din galeria predefinită sau din fișier propriu. ID-urile
sunt slug-uri unice (`uniqueID`/`slug`) — `id`-ul e și numele fișierului
public, și cheia de cache din Client, deci două intrări cu același id ar
suprascrie aceeași imagine.

**Client**: `SeasonalBackgroundsLayer` iterează biblioteca activă și randează
fiecare filigran la `config.position.alignment`. Păstrat fix-ul din
2026-08-29: NU `AsyncImage` (nu randează fiabil SVG pe macOS) — descărcare
manuală + `NSImage(data:)`. **Cache-ul pe disc e acum cheiat per filigran**
(`seasonal-cache/<id>`) — era un singur fișier global, ceea ce cu o
bibliotecă ar fi însemnat că ultimul descărcat suprascrie cache-ul tuturor
celorlalte (offline, toate ar fi arătat aceeași imagine).

**PWA**: `.seasonal-bg` nu mai e ancorat fix jos-dreapta — clase `.pos-*`
per poziție; `renderSeasonalBackground()` randează toate filigranele active,
cu aceeași migrare a cheii vechi și aceeași regulă de coliziune ca în Swift.

### TODO paritate Windows (NU implementat aici — repo separat, lucrat în paralel)

`GDCPluginManagerWin` (Client Windows, display-only, nu are Furnizor) ar
trebui să primească, pentru paritate:
1. `SocialLinks.LinkedinURL` + `SocialLinks` pe Course/EducationalResource/
   Event/PartnerStore/ServiceCenter/AppLink în modelul C#, plus afișarea
   rândului de iconițe pe cardurile respective.
2. Selector de temă System/Light/Dark (Regula 18) — echivalentul WPF
   (`ThemeManager`/`ApplicationThemeManager` din Wpf.Ui), persistat în
   Registry/settings, aplicat fără repornire.
3. `SeasonalBackgroundConfig`/`SeasonalPosition` + citirea
   `seasonalBackgrounds` cu migrarea cheii vechi + randarea filigranelor la
   poziția lor. **Notă**: Windows nu are încă NICIUN filigran sezonier
   implementat (vezi TODO Etapa 6), deci acolo e implementare de la zero,
   nu doar o actualizare de model.

## [FIX 2026-08-29] Sidebar "urca peste meniu" la redimensionare rapidă + setare Mărime Text

**Bug real, raportat direct de Cristi**: la redimensionarea RAPIDĂ a
ferestrei (tras de colț, în special micșorare), blocul de profil din
sidebar (`ProfileSidebarBlock` + numărul de versiune) rămânea temporar
suprapus peste ultimele rânduri din `List` în loc să fie sub ele. Cauza:
`.safeAreaInset(edge: .bottom)` era atașat DIRECT pe `List` — `List` e
un `NSScrollView` sub capotă, iar la resize rapid pe macOS content-insetul
lui nu se resincronizează mereu instant cu safe-area-ul suprapus. **Fix**:
`List` și blocul de profil sunt acum FRAȚI într-un `VStack` simplu (cu
`Divider()` între ele) — layout calculat direct de VStack la fiecare
cadru, fără nicio dependență de sincronizarea internă List/safe-area.

**Cerință nouă, implementată în același commit**: setare explicită
"Mărime text" (Mic/Normal/Mare/Foarte mare) în Preferences —
`TextScalePreference`/`TextScaleManager` (Core, nou), aplicată prin
`.dynamicTypeSize()` la rădăcina `WindowGroup`. Deliberat pe infrastructura
NATIVĂ de accesibilitate SwiftUI, nu un multiplicator brut de font — tot
textul din aplicație e deja `.font(.headline)`/`.caption`/etc (tipuri
semantice), deci reflow-ul e garantat corect de SwiftUI, fără riscul unui
text tăiat într-un frame fix pe care l-ar avea o scalare custom.

**TODO paritate Windows**: nu portat încă — `GDCPluginManagerWin` nu are
verificat același bug de layout la resize (WPF are alt model de layout,
posibil să nu fie afectat), și nu are încă o setare de mărime text.

Versiune: Client `1.17.0`→`1.18.0` (MINOR — feature nouă vizibilă).
**Verificat**: `swift build` — 0 erori.

## [FIX 2026-08-29] Formularul de Produse (Furnizor) nu se golea după publicare

**Bug real, raportat de Cristi**: după ce publica un produs, trebuia să
închidă și să redeschidă Furnizorul ca să poată adăuga alt produs — toate
câmpurile rămâneau completate. **Cauză, verificată prin comparație directă
cu celelalte 9 formulare de publicare** (`PublishAppView`, `PublishAudioView`,
`PublishBundleView`, `PublishCourseView`, `PublishDownloadableResourceView`,
`PublishEducationalResourceView`, `PublishEventView`,
`PublishPartnerOfferView`, `PublishPartnerStoreView`,
`PublishServiceCenterView` — TOATE apelau deja `clearForm()` imediat după
`successMessage`): DOAR `PublishView.swift` (Produse — formularul cel mai
folosit) omitea acest apel, apelând în schimb `loadExistingIfNeeded()`
necondiționat, care repopulează formularul dacă ID-ul introdus se
potrivește cu un produs existent — util la actualizare, dar greșit la
creare de produs nou. **Fix**: `clearForm()` apelat după o publicare NOUĂ
(`!isUpdate`); la o actualizare (`isUpdate == true`) comportamentul rămâne
neschimbat (`loadExistingIfNeeded()`), fiindcă acolo repopularea e utilă.
**Regulă practică de reținut**: orice formular NOU de Furnizor trebuie să
apeleze `clearForm()` după publicare reușită (cazul de creare) — verifică
prin comparație cu formularele existente înainte de a considera un
formular nou "gata".
Versiune Furnizor: `1.15.0`→`1.15.1` (PATCH — fix, nu funcționalitate nouă).
**Verificat**: `swift build` — 0 erori.

## [BUG MAJOR GĂSIT ȘI REPARAT 2026-08-29] Decodorul SVG de pe macOS NU randează `<text>` — filigranul sezonier era gol

**Raportat de Cristi**: "filigranul nu se vede" — persistent, chiar și după
recompilare la ultima versiune. **Diagnostic real, nu presupunere**:
verificat direct cu un test izolat (`NSImage(data:)` pe un SVG minimal cu
`<rect><text>HI</text></svg>`) — pixelul din centrul textului rămâne
`alpha=0` (complet transparent), indiferent de `font-family` folosit.
**ImageIO (decodorul SVG nativ macOS 12+) randează corect `<path>`/
`<circle>`/`<rect>`/gradienți, dar NU randează DELOC elementul `<text>`.**
Asta explică retroactiv de ce toate cele 7 preseturi predefinite (Black
Friday, Crăciun, Revelion, Primăvară, Paște, Vară, Ofertă Flash) — refăcute
complet pe 2026-08-29 tocmai ca să includă text explicit ("Sărbători
Fericite", "LA MULȚI ANI!" etc.) — aveau tot timpul textul invizibil în
Client, fără nicio eroare, de la prima lor publicare.

**Fix ales, la cererea explicită a lui Cristi** ("dacă crezi că SVG face
probleme, lasă doar PNG, dar să fim siguri că-i 100% funcțional, nu
riscăm"): cele 7 preseturi predefinite au trecut de la SVG generat inline
la **PNG randat o singură dată, offline** — textul original a fost
convertit în path-uri vectoriale REALE folosind CoreText
(`CTFontCreatePathForGlyph`, glif cu glif, cu suport corect pentru
diacritice — verificat vizual, "Sărbători Fericite" randează corect ă/ș),
apoi totul rasterizat la 960×960 cu fundal TRANSPARENT (nu opac — filigranul
se suprapune la opacitate mică peste UI). PNG-urile trăiesc acum ca resurse
bundle-uite în Furnizor (`Sources/GDCPluginManagerFurnizor/Resources/
SeasonalPresets/`, `.copy(...)` în `Package.swift`, încărcate prin
`Bundle.module` — vezi `SeasonalPresets.resourceURL(for:)`).
`SeasonalPreset` a pierdut câmpul `svg: String`; `commitPreset` copiază
acum bytes-ii PNG-ului bundle-uit, nu mai scrie un fișier temporar SVG.

**Recomandarea PNG vs SVG s-a INVERSAT** (era "SVG mai bun", acum "PNG
implicit") — documentat explicit în cod și în UI-ul Furnizorului. SVG
rămâne acceptat la upload propriu (util pentru forme PURE, fără text —
gradienți, iconițe vectoriale simple), dar Furnizorul avertizează acum
EXPLICIT (mesaj de succes cu ATENȚIE, nu doar silențios) dacă fișierul SVG
ales conține `<text>` — detectat prin citirea conținutului
(`content.contains("<text")`), nu doar extensia fișierului.

**Fix live imediat, în afara fluxului normal de Furnizor** (asset deja
publicat și activ, risc de așteptare): `docs/covers/seasonal/black-friday.svg`
și `black-friday-2.svg` (acesta din urmă activ chiar acum în catalogul live)
au fost înlocuite direct cu echivalentele PNG corect randate, `catalog.json`
actualizat manual cu noile căi + hash de cache-busting — verificat cu un
diff semantic (JSON parsat, nu text brut) că NIMIC altceva din catalog nu
s-a schimbat accidental.

**Feature nou, cerut în aceeași conversație**: intensitate (opacitate)
reglabilă PER filigran, nu mai o constantă globală (0.07) hardcodată în
Client. `SeasonalBackgroundConfig.opacity: Double` (nou, retrocompatibil —
lipsă în JSON vechi decodează la 0.07, exact valoarea de dinainte, zero
schimbare vizuală pentru bibliotecile deja publicate). Slider în Furnizor
(0.03–0.20), publicat o singură dată la eliberare (`onEditingChanged`), nu
la fiecare pixel de mișcare a slider-ului.

**TODO paritate Windows**: `GDCPluginManagerWin` a primit deja `SharpVectors`
(librărie de randare SVG) special pentru filigranul sezonier — dacă acel
randor ARE suport de `<text>` (SharpVectors se bazează pe alt motor decât
ImageIO, posibil să nu aibă aceeași limitare), problema ar putea fi
DOAR pe macOS. NEVERIFICAT încă — necesită un test real pe Windows înainte
de a trage o concluzie. Indiferent de rezultat, bibliotecile PNG publicate
acum (Mac) funcționează identic pe Windows (PNG e universal suportat,
`BitmapImage` nativ WPF, fără nicio dependință specială).

Versiune: Client `1.18.0`→`1.19.0`, Furnizor `1.15.1`→`1.16.0` (MINOR —
schimbare de arhitectură a preseturilor + feature nou de intensitate).
**Verificat**: `swift build` (Core + Client + Furnizor) — 0 erori. Toate 7
PNG-uri verificate vizual (randate cu text corect, inclusiv diacritice).

## [FIX 2026-08-29] Furnizor: fiecare control al filigranului publica INSTANT — cerut buton explicit de "Trimite"

**Raportat direct de Cristi, în timp real**: "când reglez intensitatea se
blochează... când apăs activ, el deja o urcă... nu să tot trimită, să am
buton de push să pot controla". Confirmat exact în `git log` — fiecare
Toggle/Picker/Slider din `SeasonalBackgroundView.entryRow` apela `update()`
imediat, care făcea un `git pull` + `commit` + `push` COMPLET la fiecare
atingere de control (commit-uri repetate "Filigrane sezoniere actualizate",
zeci în șir în timp ce Cristi doar regla un slider). Pe lângă lent, asta
explică și senzația de „se blochează": UI-ul aștepta rețeaua la fiecare
mișcare de slider.

**Fix**: toate modificările unei intrări (Activ/Poziție/Intensitate/
Perioadă) se țin acum STRICT LOCAL, într-un `@State private var drafts:
[String: SeasonalBackgroundConfig]`, cheiat după id — ZERO activitate de
rețea la atingerea unui control. Un banner portocaliu ("Modificări
nepublicate încă") + două butoane explicite ("Anulează" / "Trimite
modificările") apar DOAR când intrarea are un draft diferit de ce e deja
publicat. Apăsarea "Trimite modificările" face UN SINGUR
`pull`+`commit`+`push`, cu toate câmpurile schimbate deodată.

`SeasonalBackgroundConfig.with(isEnabled:position:opacity:scheduling:)`
(Core, nou) — helper de copiere imutabilă (câmpurile modelului rămân `let`,
neschimbat), evită reconstruirea manuală a tuturor celor 7 câmpuri la
fiecare editare de UI.

**Regulă practică nouă, de reținut pentru orice panou viitor de bibliotecă
similar** (ex. dacă apare o a doua bibliotecă de conținut reglabil):
NICIODATĂ un control legat direct la o acțiune de rețea (`Task { await
update(...) }` pe `set:` al unui Binding) — separă întotdeauna starea
LOCALĂ (draft) de acțiunea explicită de publicare.
Versiune Furnizor: `1.16.0`→`1.16.1` (PATCH — fix de comportament, nu
funcționalitate nouă).
**Verificat**: `swift build` (Core + Furnizor) — 0 erori.

## [DIAGNOSTIC 2026-08-29] Filigranul tot nu apărea în Client, deși datele erau corecte

Verificat direct pe acest Mac: `catalog-cache.json` local (Application
Support) arăta corect toate cele 3 filigrane din bibliotecă — dar
`isEnabled` se schimba la fiecare câteva secunde, în timp real, cât Cristi
încerca combinații diferite din Furnizor (confirmă exact bug-ul de mai sus:
fiecare click chiar AJUNGEA la server, doar prea des și fără control).
Nu s-a găsit alt bug de decodare/randare în afară de cel deja documentat
(`<text>` invizibil, reparat separat). Suspiciune principală rămasă
NECONFIRMATĂ: aplicația Client de testat de pe acest Mac putea rula o
instanță VECHE, deschisă înainte de reinstalare (`Cmd+Q` complet necesar,
nu doar închiderea ferestrei — un simplu `cp` peste bundle nu afectează un
proces deja pornit din memorie). De verificat direct de Cristi la
următorul test: numărul de versiune afișat în aplicație (Preferences) TREBUIE
să arate ultima versiune înainte de a concluziona că filigranul tot nu merge.

## [BUG REAL GĂSIT ȘI REPARAT 2026-08-29] Filigranul sezonier NU pornea niciodată fetch-ul de imagine — `.task` neatașat corect

**Cauza reală a lui "nu apare filigranul", diagnosticată cu print-uri
temporare, nu presupusă**: `SeasonalBackgroundLayer.body` avea `.task(id:)`
atașat pe `Group { if let nsImage {...} }`. La primul randaj, `nsImage`
e `nil`, deci acel `Group` nu are NICIUN copil concret. Confirmat direct,
rulând Client-ul din Terminal cu `NSUnbufferedIO=YES` (altfel `print`-urile
rămân blocate în bufferul stdio al unei aplicații GUI, niciodată scrise —
notă utilă pentru orice diagnostic viitor similar): `SeasonalBackgroundsLayer.body`
se evalua corect, cu exact 1 config activ, dar print-ul din INTERIORUL
`.task` NU apărea NICIODATĂ — deci fetch-ul de rețea nu pornea deloc,
indiferent ce filigran era activ, ce poziție sau ce opacitate avea.
Explică retroactiv TOATE testele anterioare din această conversație:
datele erau mereu corecte (verificat obsesiv, catalog.json, HTTP 200 pe
imagine, decodare SVG/PNG confirmată izolat) — problema era 100% în
Client, în punctul unde ar fi trebuit să CEARĂ imaginea, care pur și simplu
nu se declanșa niciodată.

**Fix**: `.task` mutat pe un container CONCRET, mereu prezent —
`Color.clear.frame(width: 480, height: 480).overlay { if let nsImage {...} }`
— în loc de `Group { if let nsImage {...} }`. Un `Group` al cărui unic
conținut e un `if` fără ramură `else` poate să nu fie tratat de SwiftUI ca
prezent stabil în ierarhie la prima evaluare (când condiția e falsă),
riscând ca modificatori ca `.task`/`.onAppear` atașați pe acel Group să nu
se declanșeze fiabil. **Regulă practică nouă, de reținut pentru orice view
viitor cu încărcare asincronă condiționată de o stare opțională**:
NICIODATĂ `.task`/`.onAppear` pe un `Group`/`ZStack` al cărui SINGUR
conținut e un `if let` — atașează-l pe un container necondiționat
(`Color.clear`, un `Rectangle`, sau un `VStack` cu alt conținut garantat),
cu conținutul condițional doar ca `overlay`/copil intern.

Versiune Client: `1.19.0`→`1.19.1` (PATCH — fix critic).
**Verificat, nu presupus**: rulat direct din Terminal, cu print-uri de
diagnostic (eliminate după verificare) — confirmat că fetch-ul pornește,
HTTP 200, 59827 bytes, decodare reușită (2000×1025). Filigranul
`black-friday-seeklogo` era activ la acel moment (Cristi testa live),
opacitate 12% (dovadă că sliderul de intensitate din Furnizor funcționează
și el corect, publică valoarea aleasă).

## [ROBUSTEȚE 2026-08-29] Log de Diagnostic permanent extins la filigran + CHANGELOG.md adus la zi

`DiagnosticLog.swift` mutat din `GDCPluginManager` (Client) în
`GDCPluginManagerCore`, ca să fie reutilizat și de Furnizor (era doar
pentru `UpdateChecker` până acum). Adăugat logging permanent pe:
- Client: `SeasonalBackgroundLayer.task` (fetch filigran — pornire, URL nil,
  succes cu HTTP status + bytes, fallback pe cache, eșec total).
- Furnizor: `SeasonalThumbnail.task` (fetch miniatură) + `run()` (pull/
  commit/push — start, succes, eroare).

Motiv direct (Regula 25, Partea 1): bug-ul de azi cu filigranul care nu se
încărca a fost găsit DOAR adăugând print-uri temporare și rulând din
Terminal cu `NSUnbufferedIO=YES` — cu log-ul permanent deja acolo, un
raport viitor similar ("nu apare imaginea") se diagnostichează citind
`%TEMP%/gdcpm-crash.log`, fără nicio reproducere manuală.

`CHANGELOG.md` (repo) adus la zi cu tot ce s-a livrat azi (fix critic
filigran, iconițe colorate, tooltips, temă, mărime text, sidebar, fix
Furnizor). Create fișiere `CHANGELOG.md` noi (goale, gata de completat) în
cele 5 repo-uri din `~/Developer/` care nu aveau încă unul.

Versiune: Client `1.19.2`→`1.19.3`, Furnizor `1.16.1`→`1.16.2` (PATCH).
**Verificat**: `swift build` — 0 erori.

## [BUG REAL GĂSIT ȘI REPARAT 2026-08-29] Draft orfan corupea calea imaginii la reutilizarea unui id

**Diagnosticat direct din `%TEMP%/gdcpm-crash.log`** (Regula 25, log de
diagnostic permanent — a funcționat exact cum trebuia, prima oară folosit
real): Cristi raporta "unele PNG-uri nu merg deloc, altele da". Logul a
arătat clar: `catalog.json` avea `imagePath` cu extensia `.jpg` pentru o
intrare, dar fișierul REAL de pe disc/server era `.png` — HTTP 404 permanent,
nu o întârziere de propagare (verificat separat: alte 2 fișiere "noi" ERAU
doar întârziate de CDN și s-au rezolvat singure în ~1 minut — fals pozitiv
parțial în raportul inițial, corect diagnosticat prin re-testare).

**Cauza reală**: `drafts` (dicționarul local de modificări nepublicate,
introdus la fix-ul anterior "nu mai trimite instant") e cheiat după `id`.
Dacă o intrare era ȘTEARSĂ cât timp avea un draft nepublicat (ex. Cristi
reglase intensitatea dar nu apăsase încă "Trimite"), draftul rămânea
"orfan" — `remove()` nu-l curăța. La o reutilizare ulterioară a ACELUIAȘI
`id` (posibil dacă un fișier nou are un nume care generează același slug),
`uniqueID()` nu mai vedea nicio coliziune (intrarea veche nu mai există în
`library`), deci noua intrare primea id-ul liber — dar draftul orfan, cu
`imagePath`-ul VECHI (către fișierul deja șters), rămânea legat de acel id.
Prima apăsare pe "Trimite modificările" pe intrarea nouă publica draftul
VECHI, suprascriind calea corectă cu una moartă.

**Fix**: `drafts[id] = nil` explicit în `remove()` ȘI defensiv la
începutul lui `addPreset()`/`addCustom()` (înainte de a crea intrarea nouă)
— dublă gardă, ca niciun draft vechi să nu mai poată supraviețui unui id
reutilizat.

**Fix live imediat**: intrarea deja stricată din producție
(`wide-169-cinematic-...`) a fost corectată direct în `catalog.json`
(imagePath → extensia reală `.png`, hash recalculat) — verificat cu HTTP
200 după corectare.

Versiune Furnizor: `1.16.2`→`1.16.3` (PATCH — fix critic).
**Verificat**: `swift build` — 0 erori.

## [BUG REAL GĂSIT ȘI REPARAT 2026-08-29] Preview-ul de catalog de pe index.html lipsea 4 rubrici noi

**Raportat de Cristi**: "pe pagina de Android, iPhone, nu-mi apar toate
rubricile noi care le-am adăugat". **Diagnostic real**: două pagini
diferite servesc conținut de catalog pe `gordas.dev` — `app.html`
(aplicația interactivă reală, cu tabbar-ul complet) și `index.html`
(pagina de prezentare/vânzare, cu un preview STATIC de catalog, cod
separat, propriile funcții `xCard()` + array `CATEGORIES`). `app.html` era
la zi; `index.html` avea `CATEGORIES` cu doar 7 din 11 colecții —
`downloadableResources`, `partnerOffers`, `serviceCenters`,
`productBundles` (toate patru din etapele mai recente) nu fuseseră
adăugate NICIODATĂ acolo, de la publicarea lor inițială.

**Fix**: 4 funcții noi de card (`downloadResourceCard`, `offerCard`,
`serviceCard`, `bundleCard`, port 1:1 al stilului celorlalte) + 4 intrări
noi în `CATEGORIES` + traduceri complete RO/EN/ES (`cat.X.name`/`cat.X.lead`)
+ stil nou `.cc-badge.discount` pentru badge-ul de reducere pe Ofertele
Parteneri. Verificat DIRECT, nu presupus: rulat local cu `http.server`,
catalogul live decodat corect, toate 3 categorii noi (Ofertă Parteneri,
Service & Reparații, Pachete) apar cu numărul real de intrări
("Partner Offers1", "Service & Repair1", "Bundles1") — a patra
(`downloadableResources`) nu apare încă DELIBERAT (zero resurse publicate
în acea categorie momentan — comportamentul corect e s-o ascundă, nu o
regresie).

**Regulă practică nouă, de reținut**: `index.html` și `app.html` au
sisteme de randare SEPARATE, care nu se sincronizează automat — orice
colecție nouă din `Catalog` (Core) trebuie adăugată manual în AMBELE, nu
doar în `app.html`. `docs/sw.js` CACHE_VERSION v16→v17.

## [FIX ROBUSTEȚE 2026-08-29] Fetch filigran — retry automat + eroare reală în log (Mac + Windows)

**Raportat live de Cristi, diagnosticat direct din log**: un filigran
(Black Friday) eșua consecvent la încărcare în timp ce altul (Crăciun),
publicat în același minut, se încărca perfect. Verificat DIRECT (nu
presupus): fișierul era disponibil pe server exact în acel moment
(`curl` → HTTP 200), deci NU exista o problemă reală de disponibilitate —
`try?`/`catch` generic ascundea eroarea REALĂ (timeout? DNS? TLS?),
raportând mereu doar "fetch eșuat", fără detalii utile.

**Concluzie**: `gordas.dev` trece prin DOUĂ straturi de CDN (Cloudflare +
Fastly/GitHub Pages) — un nod de edge poate rata tranzitoriu o cerere, fără
ca alta, la milisecunde distanță, s-o rateze. Nu e un bug de cod, dar
aplicația poate — și trebuie — să reziste la un asemenea blip.

**Fix, pe AMBELE platforme**: fiecare fetch de filigran încearcă acum de
**2 ori** (a doua încercare, la 0.8s după prima), și logul înregistrează
eroarea REALĂ (`Error`/`Exception` completă), nu doar "a eșuat" — un
raport viitor similar se diagnostichează direct din log, fără presupuneri.
Windows: `DiagnosticLog` (Core) trecut din `internal` în `public`, ca să
poată fi folosit și din `SeasonalBackgroundLoader.cs` (Client) — până acum
doar `PowerGradeImporter` îl folosea.

**Bonus, găsit în timpul investigației**: ferestrele Windows noi
(`SettingsWindow`/`ProfileEditorWindow`/`DependencyPanelWindow`/
`UpdateProgressWindow`) foloseau `SizeToContent="Height"` FĂRĂ `MinHeight`
— pe o mașină mai lentă (Parallels/VM), fereastra se putea desena o clipă
înainte ca WPF să termine calculul înălțimii, arătând goală (confirmat de
o captură trimisă de Cristi). Adăugat `MinHeight` explicit la toate 4.

Versiune: Client `1.19.4`→`1.19.5` (PATCH).
**Verificat**: `swift build` — 0 erori.

## [BUG REAL GĂSIT ȘI REPARAT 2026-08-29, val 2] Retry-ul de filigran nu reîncerca la 404 — găsit direct din log-ul de diagnostic

**Diagnosticat exclusiv din `%TEMP%/gdcpm-crash.log`** (Regula 25 — a
funcționat exact cum trebuia): Cristi raporta filigranul invizibil, deși
`curl` direct pe `blackfriday.png` răspundea HTTP 200, 1MB, imagine validă
(verificat cu PIL: RGBA, ~34% pixeli cu conținut, nu corupt). Logul a arătat
exact secvența: `fetch OK (9115 bytes) dar NSImage nu a decodat`, repetat
de multe ori, fără al doilea retry vizibil pentru acest caz.

**Cauza reală**: `URLSession.shared.data(from:)` (Swift) **NU aruncă la un
status HTTP de eroare** (404/500) — aruncă DOAR la eșec de rețea propriu-zis
(DNS/TLS/timeout). Un 404 tranzitoriu de CDN edge (imediat după un
republish — coliziunea Cloudflare+Fastly deja documentată) trecea deci prin
ramura de "succes" a lui `do/catch`, primea corpul paginii de eroare a
GitHub Pages (9115 bytes — identic pe toate filigranele afectate din log),
eșua la `NSImage(data:)`, și codul făcea `break` — ieșea din buclă FĂRĂ al
doilea retry, exact eșecul pe care retry-ul exista să-l repare.

**Fix**: statusul HTTP (`HTTPURLResponse.statusCode`) se verifică EXPLICIT
înainte de a încerca decodarea; orice non-200, sau eșec de decodare a unui
răspuns 200 (date corupte), continuă bucla de retry (`continue`), nu mai
iese (`break`). Windows (`SeasonalBackgroundLoader.cs`) NU avea acest bug —
`HttpClient.GetByteArrayAsync` ARUNCĂ automat `HttpRequestException` pe
status non-2xx, deci acolo un 404 mergea deja pe ramura corectă de retry.

**Regulă practică nouă**: `URLSession.shared.data(from:)` NICIODATĂ fără
verificare explicită a `HTTPURLResponse.statusCode` — spre deosebire de
`HttpClient` (.NET), NU aruncă pe status HTTP de eroare, doar pe eșec de
transport. Orice fetch nou pe Mac trebuie să verifice statusul manual.

Versiune: Client `1.19.6`→`1.19.7`→`1.19.8` (PATCH — al doilea bump, doar
sincronizare cu Windows, care a primit un fix suplimentar de logging SSL
în aceeași fereastră de timp — vezi `GDCPluginManagerWin/CLAUDE.md`).
**Verificat**: `swift build` — 0 erori.
