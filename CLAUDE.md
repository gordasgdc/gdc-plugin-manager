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

## [PARTEA 1: REGULI GLOBALE ECOSISTEM GDC — identică în toate proiectele GDC]

> Acest bloc e sincronizat manual în `CLAUDE.md`-ul TUTUROR proiectelor din
> `~/Developer/` (CGConvertor, CursorPro, DataMover, GDCPluginManager,
> GDCPluginManagerWin, GDCVault, GDCVaultWin, gdc-plugin-manager-catalog-vendor,
> gdc-plugin-manager-files, gdc-production-manager, gdc-resolve-encoder, și
> orice proiect GDC nou). Dacă modifici o regulă aici, propag-o manual și în
> celelalte 10 fișiere — nu există un fișier partajat/include, fiecare
> `CLAUDE.md` e citit independent per-repo. Vezi jurnalul "Sincronizare
> CLAUDE.md" din secțiunea Partea 2 a fiecărui repo pentru data ultimei
> unificări.

**1. Directoare & structură.** Toate proiectele GDC trăiesc exclusiv în
`~/Developer/<NumeProiect>/`, niciodată în `~/Downloads` sau `~/Desktop`
(curățate automat de CleanMyMac/Hazel pe acest Mac — au șters repo-uri de
sursă în trecut). Niciun repo nou nu se creează/clonează în afara
`~/Developer/`. Certificatele Apple (`.p12`/`.cer`) și orice cheie privată
(`.p8`/`.key`/`.pem`/`.mobileprovision`) stau EXCLUSIV în
`~/Developer/Certificates/` (folder în afara oricărui repo git) — niciodată
comise, indiferent de `.gitignore`.

**2. Securitate — zero secrete în git.** `.git/config` nu conține niciodată
un token în clar în URL-ul remote-ului (`https://user:TOKEN@github.com/...`)
— autentificare exclusiv prin `gh` (credential helper) sau SSH. Orice token
găsit expus se elimină din config imediat; revocarea efectivă din GitHub
Settings e un pas manual al lui Cristi (Claude nu poate revoca un token).
Un secret comis vreodată în istoricul git (verificat cu
`git log --all -p | grep` sau echivalent) trebuie semnalat explicit, nu doar
curățat din starea curentă.

**3. Licențiere & Donație (GDC Plugin Manager / Furnizor).** Toate
aplicațiile standalone GDC folosesc `LicenseCore`/`MachineID` (Ed25519,
aceeași cheie publică hardcodată în tot ecosistemul — copiată byte-for-byte,
NU printr-o dependință de pachet între repo-uri). Probă gratuită implicită:
**15 zile**. Activare manuală prin WhatsApp (ID de mașină pre-completat) →
cod generat din `GenerateSerialView.swift` (Furnizor, `gdcStandaloneProducts`
trebuie să includă `productID`-ul noii aplicații). Valoarea susținerii
aplicației se exprimă EXCLUSIV ca **donație** — sumă implicită de referință
**23 €** dacă nu există alt preț promoțional documentat pentru acea
aplicație — NICIODATĂ cu cuvintele „preț", „cumpără" sau „vânzare" (RO/EN/ES:
niciodată „price"/„buy"/"sale" nici în engleză/spaniolă). Formularea trebuie
să apară clar în: UI-ul aplicației (ecran/pop-up de licență), ghidul PDF, și
orice pagină web dedicată.

**[COMPLETARE 2026-08-26, închide o lacună de scop reală]** Interdicția de
mai sus se aplică ACUM și produselor din catalogul GDC Plugin Manager
(LUT/DCTL/PowerGrade vândute prin marketplace-ul gratuit) — găsit la audit
un card cu buton „Cumpără" și sume afișate brut („378,00 €"). Butonul
devine „Donează" peste tot (RO/EN/ES); suma documentată de furnizor pentru
acel produs (promoția specifică lui, nu neapărat 23 €) rămâne vizibilă, dar
NICIODATĂ lângă cuvântul „preț"/„cumpără"/„vânzare" — decizia anterioară de
scop (marketplace = "relație comercială diferită, nu se aplică") e
INVALIDATĂ explicit. Excepție: tabelele interne ale Furnizorului (ex.
`SalesHistoryView`, coloana „Preț" din registrul de vânzări al lui Cristi)
nu sunt UI orientat spre client — rămân neatinse.

**15. CRM Furnizor — set minim de funcționalități administrative
(2026-08-26).** Panoul de Clienți al Furnizorului (`SalesHistoryView.swift`)
nu rămâne un log rigid — trebuie să ofere: filtrare rapidă pe produs
(dropdown dinamic, nu hardcodat), export 1-click (clipboard sau fișier) al
email-urilor/HWID-urilor din selecția curentă (filtrată), copiere rapidă
per-câmp direct din tabel (fără să deschizi editarea), Licențiere în Masă
(paste o listă de email-uri/machine ID-uri → generează automat câte o
licență per linie, pentru un produs/durată alese o singură dată), și
editare liberă a duratei unei licențe deja generate (Zile/Luni/Ani/
Lifetime). Furnizorul arată versiunea curentă în UI, la fel ca orice
aplicație client — nu e scutit de Regula 7 doar pentru că e un instrument
intern.

**16. Design Web "Shift" — compact, fără spații goale (2026-08-26).**
Completare la Regula 12: paginile de prezentare NU doar adoptă paleta
amber/cupru — trebuie și dense/aerisite corect, nu găunoase. `min-height:
100svh` pe un hero cu conținut scurt lasă spațiu gol enorm pe orice ecran
mai mare — evită-l sau limitează-l (ex. `78svh`); padding-ul secțiunilor
(`section`) rămâne generos dar nu excesiv (60px, nu 90px+). Orice accent
vechi (verde/teal/albastru folosit ca accent PRIMAR, nu ca stare
semantică precum "verificat cu succes") se înlocuiește cu amber/cupru —
o variabilă CSS poate păstra alt NUME istoric (`--scope`, `--accent-copy`)
atât timp cât VALOAREA ei devine amber, ca să nu rescrii zeci de
apariții `var(--x)` din foaia de stil.

**4. Manager de Dependențe (Standard GDC, opt-in).** Aplicația de bază
rămâne lightweight — orice dependință externă opțională/grea (ex. FFmpeg
static) se descarcă LA CERERE, nu bundle-uită implicit dacă poate fi evitat.
Indicator global 🔴/🟢 vizibil în header/meniu: verde doar dacă TOATE
componentele obligatorii (non-opționale) sunt OK; componentele opționale
(ex. Homebrew pe Mac) nu blochează starea verde. Click pe indicator deschide
un panou dedicat ("Verificare & Dependențe Sistem") cu o listă modulară de
componente (model generic `DependencyItem` — id, nume, opțional/obligatoriu,
verificare headless, acțiune, niciodată câmpuri hardcodate per-dependință),
fiecare cu propriul status + buton de acțiune (descărcare automată a unui
binar static, sau copiere comandă de instalare). Verificarea rulează headless
la fiecare deschidere a panoului/meniului, actualizând starea instant.

**5. Instalare Autonomă.** Mac: `.pkg` semnat Developer ID Application +
Installer, notarizat, stapled, cu `pkgbuild --install-location "/"` și
payload la `Applications/<App>.app` — instalare DIRECTĂ în `/Applications`
la dublu-click, fără drag-and-drop manual (verificabil cu
`pkgutil --payload-files`). Windows: installer Inno Setup cu
`DefaultDirName={autopf}\GDC\<App>` (Program Files) sau varianta x86,
scurtături automate Desktop + Start Menu, dezinstalare nativă prin
"Apps & Features" (fără script separat necesar dacă Inno Setup o acoperă).

**6. Packaging Mac — arhivă cu STRICT 3 fișiere.** Orice
`<App>-Mac.zip` livrat clientului conține la rădăcină EXACT: (1)
executabilul/`.pkg`-ul semnat+notarizat+stapled, (2)
`Dezinstalare_<App>.command` (dezinstalare completă: procese, TCC dacă
relevant, `~/Library/Application Support`, `Caches`, `Preferences`,
`Saved Application State`, `Logs`, orice item Keychain scris de aplicație),
(3) `Instructiuni_Utilizare.pdf` (RO/EN/ES). NICIODATĂ hack-uri
`xattr -dr com.apple.quarantine` sau launchere `Instalare_*.command` —
pachetul stapled e acceptat nativ de Gatekeeper. Curățarea unei instalări
vechi se face în `installer/scripts/preinstall` (`pkgbuild --scripts`,
pkill + `rm -rf`), niciodată legat de quarantine.

**7. UI Standard — varianta "Shift".** Temă dark, profesională, inspirată de
paginile de Color din DaVinci Resolve (fundal `#14161A`/`#1A1D22`, accent
cald cupru/amber sau altă culoare distinctă per-aplicație, text `#EDEFF2`).
Număr de versiune vizibil în UI (About/Meniu/Settings/Footer), fără excepție.
Update Checker automat la lansare + verificare manuală, conectat la
`update.json`/GitHub Releases API, cu notificare atât banner discrét CÂT ȘI
pop-up modal (o singură dată per versiune nouă, stare de dismissal comună
între cele două) — un simplu banner nu e suficient. `mandatory: true` în
`update.json` ignoră dismissal-ul anterior.

**8. Documentație PDF — standard ultra-detaliat.** Orice
`Instructiuni_Utilizare.pdf` (RO/EN/ES) se redactează pentru un utilizator
complet începător, zero presupuneri, cu secțiunile relevante aplicației:
(a) Panoul de Dependențe — ce înseamnă 🔴/🟢, pas-cu-pas ce face userul la
roșu (unde dă clic, ce se deschide, ce buton apasă); (b) Homebrew (Mac,
dacă aplicabil) — pași la nivel de acțiune: copiază comanda din aplicație,
deschide Terminal (Spotlight, `⌘+Space`), lipește (`⌘+V`), Enter, apoi
explică parola de Mac cerută (invizibilă la tastare) + Enter din nou;
(c) Fluxul de utilizare + acțiuni post-proces — cum se adaugă
fișiere/date, ce face fiecare buton rezultat; (d) Licență & Donație — trial
gratuit explicit (zile), suma exactă ca donație (niciodată "preț"/"vânzare");
(e) Cum funcționează actualizarea automată — ce înseamnă pop-up-ul de
versiune nouă, ce face butonul „Actualizează acum" vs „Mai târziu", și că
instalarea noii versiuni rămâne un pas asistat (descărcare + reinstalare),
nu un update silențios în fundal.

**9. Checklist obligatoriu la FIECARE release** (păstrat identic cu
"DIRECTIVĂ PERMANENTĂ SUPREMĂ" din jurnalul fiecărui proiect — punctele
1-4 de acolo sunt subsumate integral de punctele 5-8 de mai sus). Site-ul
public al fiecărei aplicații trebuie să pointeze mereu la
`releases/latest/download/...` (HTTP 200 verificat, nu presupus), niciodată
un tag fix.

**10. Comunicare & jurnal.** Fiecare `CLAUDE.md` rămâne un jurnal
append-only (regulile vechi nu se șterg, doar se marchează
**[ÎNVECHIT]** cu motivul dacă sunt explicit invalidate). Răspunsurile
Claude rămân ultra-concise: fără explicații de proces, direct codul/
diff-ul/comenzile și statusul. La orice modificare de cod, comanda exactă
de rebuild local se include la finalul răspunsului.

**11. Sincronizare dinamică a Standardului Master (CONTINUOUS UPDATE,
2026-08-26).** Orice adăugare/modificare/optimizare a unei reguli globale
din ACEASTĂ Partea 1 — indiferent din ce proiect pornește — devine automat
noul Standard Master și TREBUIE propagată manual, în ACELAȘI commit sau
imediat următorul, în `CLAUDE.md`-ul tuturor celorlalte proiecte din
`~/Developer/` (nu doar notată "pentru mai târziu"). Orice aplicație NOUĂ
creată în `~/Developer/` primește Partea 1 (versiunea curentă, completă)
încă din primul `CLAUDE.md` scris pentru ea — nu se pornește niciodată de
la un fișier gol sau parțial. Regula 1 de mai sus ("Dacă modifici o regulă
aici, propag-o manual...") descrie mecanismul; aceasta îl declară
obligatoriu, nu opțional.

**12. Profil Utilizator/HWID în Sidebar, Sistem de Revocare Licențe &
Standard Design Web Mobile/Desktop "Shift" (2026-08-26).**
- **Profil Utilizator opțional, vizibil în sidebar-ul UI** (Mac + Windows,
  pe toate aplicațiile cu licențiere GDC): Nume (sau „Anonim" dacă nu e
  completat), Email, și Machine ID (HWID) — afișate clar, nu ascunse
  într-un submeniu. Portat din modulul Tracker existent (Mac,
  `AnalyticsClient.registerDevice` → Supabase `devices`) — Windows trebuie
  aliniat la aceeași infrastructură, nu una separată.
- **Revocare/blacklist de licențe, prin Supabase** (ACEEAȘI bază de date
  deja folosită de Tracker — niciun backend nou de construit). O licență
  Ed25519 rămâne verificată local (offline-first, nicio schimbare la
  activarea inițială), dar clientul verifică periodic + la lansare (dacă
  există conexiune) un tabel de revocări după `machineID`/serial. **Fail
  OPEN, nu fail closed**: fără conexiune la internet, o licență deja
  activată local CONTINUĂ să funcționeze (nu bricuim un user legitim offline)
  — revocarea se aplică abia la următoarea verificare online reușită.
  Furnizor capătă unelte de revocare instant + editare a perioadei de
  valabilitate a unei licențe existente deja generate.
- **Generare flexibilă de licențe** (Furnizor): selector explicit al
  duratei — Zile / Luni / Ani / Forever (Lifetime) / Valabil până la
  versiunea X — nu doar trial fix + activare permanentă binară.
- **Standard Design Web "Shift"** — orice pagină de prezentare/descărcare
  GDC (`gordas.dev` și paginile dedicate per-aplicație) adoptă design-ul
  dark, minimalist, accent amber/cupru consacrat de CG Convertor
  (`gordas.dev/cg-convertor`) — niciun accent verde vechi sau stil
  nealiniat. Toate paginile trebuie optimizate explicit pentru mobil
  (iOS Safari + Android Chrome), verificat vizual la lățimi de telefon,
  nu doar "responsive by CSS framework".

**13. Update Checker — specificație UX obligatorie (2026-08-26).** La
lansare, aplicația verifică `update.json`/GitHub Releases; dacă versiunea
locală e mai veche, arată un pop-up/modal Shift (nu doar bannerul discret
din Regula 7) cu: numărul noii versiuni, un rezumat scurt al noutăților
(Release Notes, dacă `update.json` le are — câmp opțional, degradează
elegant dacă lipsește), și DOUĂ butoane explicite — **„Actualizează acum"**
(deschide direct link-ul de descărcare a installer-ului/pachetului nou,
`releases/latest/download/...`, și arată userului că trebuie să
instaleze peste versiunea curentă + repornească aplicația — NU e un
self-update silențios, niciun helper nu înlocuiește bundle-ul/exe-ul în
fundal, vezi WARNING-ul deja existent din `UpdateChecker.swift`/`.cs`) și
**„Mai târziu"** (închide fereastra, aceeași stare de dismissal ca
bannerul). Popup-ul apare o singură dată per versiune nouă, cu excepția
`mandatory: true` (reapare la fiecare lansare). Ghidul PDF (Regula 8(e))
trebuie să explice acest flux exact.

**14. Versionare semantică obligatorie la FIECARE schimbare (2026-08-26).**
Orice modificare de cod livrată clientului — oricât de mică — incrementează
numărul de versiune, sincron în TOATE punctele care îl țin (Info.plist Mac,
`.csproj`/`installer.iss` Windows, `docs/update.json`, orice altă constantă
de versiune din acel repo). Format `MAJOR.MINOR.PATCH` (ex. `2.3.1`):
- **PATCH** (ultima cifră, `2.3.0`→`2.3.1`) — orice fix, ajustare, adăugare
  mică sau schimbare care nu rupe compatibilitatea. Cazul implicit, cel mai
  frecvent.
- **MINOR** (cifra din mijloc, `2.3.x`→`2.4.0`) — funcționalitate nouă
  vizibilă (ex. o fază/etapă întreagă ca Panoul de Dependențe sau Profilul
  HWID), fără schimbări radicale de arhitectură.
- **MAJOR** (prima cifră, `2.x.x`→`3.0.0`) — schimbare radicală: rebranding,
  redesign complet de UI, schimbare de arhitectură (ex. sistem nou de
  licențiere), sau orice prag pe care Cristi îl declară explicit "versiune
  majoră".
**De ce**: `UpdateChecker`/`.cs` compară STRICT numărul de versiune din
`update.json` cu cel instalat (`IsNewer`) — înlocuirea unui binar pe un
release existent, PE ACEEAȘI versiune, nu declanșează nicio notificare la
clienții deja instalați (bug real, găsit și reparat 2026-08-26: Windows
Shift UI + Faza 1/3/4 livrate silențios sub `v1.2.22`, fără niciun bump).
Un bump de versiune fără schimbare reală de cod e la fel de greșit ca
schimbarea de cod fără bump — cele două merg mereu împreună, în același
commit.

## [PARTEA 2: SPECIFICAȚII TEHNICE PROIECT]

## Structura repo-ului
- `Sources/GDCPluginManagerCore/` — model de date comun (`CatalogModel.swift`), folosit și de Client și de Furnizor.
- `Sources/GDCPluginManager/` — aplicația **Client** (ce descarcă/instalează utilizatorul final).
- `Sources/GDCPluginManagerFurnizor/` — aplicația **Furnizor** (ce publică produse noi, doar pentru tine).
- `docs/` — site-ul static (GitHub Pages, domeniu `gordas.dev` prin CNAME) + `catalog.json` (catalogul public) + `update.json` (self-update).
- Fișierele fizice ale produselor (LUT/DCTL/Fuse/OFX/PowerGrade) **nu** stau în acest repo — ele merg în repo-ul privat separat `gdc-plugin-manager-files`, prin push direct din Furnizor.

## Reguli de aur

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
