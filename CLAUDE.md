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

**17. Orice fișier descărcabil TREBUIE să poarte numărul versiunii în NUMELE
fișierului (2026-08-26).** Nu doar în interiorul aplicației (Regula 14) —
în numele fizic al pachetului: `DataMover-2.5.5.pkg`, nu `DataMover.pkg`;
`GDCPluginManagerSetup-1.2.8.exe`, nu `GDCPluginManagerSetup.exe`. Motiv
direct de la Cristi: probele/build-urile de test se acumulează local (în
`~/Downloads`, `/tmp`, trimise pentru testare) și devin de nerecunoscut
fără versiune în nume — "am o grămadă de descărcări și nu știu ce versiune
sunt, care, ce și cum sunt".
- **Excepție, NU o contrazicere**: mecanismul `releases/latest/download/
  <nume-stabil>` (site-ul, self-updater-ul) are nevoie STRUCTURAL de un
  nume care nu se schimbă niciodată între release-uri — vezi Regula
  Domeniului & Download. Copia asta stabilă (`DataMover.pkg`,
  `GDCPluginManager.pkg`) tot trebuie publicată, DAR ALĂTURI de copia
  versionată, niciodată singură. `build_installer.sh`/`build_app.sh` din
  fiecare repo produc deja ambele — regula asta cere doar ca ambele să
  ajungă mereu pe release, nu doar cea stabilă.
- **Orice fișier construit/descărcat/trimis lui Cristi în afara acestui
  mecanism** (build local de test, artefact de CI descărcat manual,
  fișier trimis prin `SendUserFile`, copie pusă în `/tmp` pentru
  verificare) TREBUIE redenumit explicit cu versiunea înainte de a fi
  oferit — niciodată livrat cu numele generic/stabil, care are sens doar
  ca țintă a unui link fix, nu ca fișier de sine stătător pe disc.

**18. Standard UX/Arhitectură obligatoriu pentru orice aplicație desktop
NOUĂ, de la primul release (2026-08-26).** Stabilit după MediaFlow Monitor
v1.3.0 — patru cerințe care nu mai sunt opționale pentru nicio aplicație
GDC viitoare (Mac și, unde tehnologia o permite, Windows):
- **Mutare automată în `/Applications` (Mac)** — la lansare, dacă bundle-ul
  rulează în afara `/Applications` sau `~/Applications` (tipic: extras
  direct din `.zip`/Downloads, sub App Translocation), aplicația arată un
  prompt nativ ("Doriți să mutați X în Aplicații?") și, la confirmare,
  copiază bundle-ul, relansează din noua locație și mută originalul la
  Coșul de gunoi. Vezi implementarea de referință `AppMover.swift`
  (MediaFlow Monitor) — fără dependință externă (PFMoveToApplicationsFolder
  nu are un port SPM întreținut), doar `NSAlert` + `FileManager`.
- **Fereastră principală redimensionabilă liber**, cu o dimensiune minimă
  de siguranță (`minSize`/`minWidth`+`minHeight`) sub care conținutul nu
  mai e lizibil — nu ferestre cu dimensiune fixă hardcodată.
- **Selector explicit de temă System/Dark/Light**, independent de setarea
  macOS/Windows — unii clienți vor Light chiar și noaptea, alții Dark
  permanent; NU e suficient să urmezi orbește `prefers-color-scheme`/tema
  sistemului. Persistat local (`UserDefaults`/Registry), aplicat imediat
  fără repornire. Vezi `AppTheme.swift`/`ThemeManager` (MediaFlow Monitor).
- **Protocolul de semnare, notarizare, auto-update și integrare GDC
  Manager rămâne cel deja documentat în Regulile 3, 5, 6, 13, 14, 17** —
  regula asta nu introduce un protocol nou, doar reconfirmă că orice
  aplicație nouă îl respectă de la prima versiune publicată, nu "adăugat
  ulterior quando there's time".

**19. Regulă Legală & Packaging (UE/Global) (2026-08-27).**
- **Pagini Web.** Orice landing page nouă sau actualizare de site publicată
  pe `gordas.dev` (sau pe orice site GDC, inclusiv paginile de proiect
  `gordasgdc.github.io/<repo>`) TREBUIE să conțină în footer link-uri către
  `https://gordas.dev/termeni` (Termeni și Condiții),
  `https://gordas.dev/confidentialitate` (Politică de Confidențialitate
  GDPR) și, unde e relevant, `https://gordas.dev/cookie` (Cookie-uri),
  plus o notă scurtă de statut: *"gordas.dev este o platformă administrată
  de dezvoltatori independenți. Aplicațiile și resursele sunt furnizate ca
  atare (AS IS), iar susținerea proiectului se bazează pe contribuții
  opționale de sprijin și donații."* Sursa canonică a acestor 3 pagini
  legale trăiește în `gdc-plugin-manager-catalog-vendor/docs/` — orice alt
  site GDC linkuiește către ele (absolut), nu le duplică.
- **Installere (.pkg macOS / .exe Windows).** Începând cu următoarele
  versiuni/build-uri (NU retroactiv — fără rebuild al aplicațiilor deja
  publicate doar pentru asta), scripturile de instalare
  (`build_installer.sh`/`productbuild` pe Mac, `installer.iss`/Inno Setup
  pe Windows) TREBUIE să includă un pas de acceptare a licenței (License
  Agreement/SLA), bazat pe un fișier `license.rtf`/`license.txt` cu un
  extras din Termeni și Condiții (statut de proiect independent,
  licențiere legată de Machine ID, natura de donație a susținerii,
  limitarea răspunderii "as is"). Utilizatorul trebuie să apese explicit
  "Agree"/"I accept" înainte ca instalarea să se finalizeze.

  **[COMPLETARE 2026-08-27] Consimțământ obligatoriu (Consent Gate), nu
  doar text afișat.** Nu e suficient ca licența să apară — pasul trebuie
  să blocheze efectiv avansarea fără acceptare explicită:
  - **macOS (`productbuild`/Distribution.xml).** Elementul `<license
    file="License.txt" mime-type="text/plain"/>` din `Distribution.xml`
    (deja folosit de `build_installer.sh` în `gdc-plugin-manager-catalog-vendor`
    și `gdc-vault-mac`) e SUFICIENT — pagina nativă de licență a
    installer-ului macOS oferă mereu doar "Agree"/"Disagree", iar
    "Continue" nu apare fără "Agree" apăsat; nu există flag care s-o
    ocolească. Regula practică: orice `Distribution.xml` nou generat
    TREBUIE să păstreze elementul `<license>` — omiterea lui (ex. un
    installer simplificat fără pas de licență) NU e acceptabilă.
  - **Windows (Inno Setup).** Secțiunea `[Setup]` din `installer.iss`
    TREBUIE să seteze `LicenseFile=license.txt` (sau `.rtf`) — Inno Setup
    arată atunci nativ o pagină cu opțiunile radio "I accept the
    agreement" / "I do not accept", cu butonul "Next" dezactivat până la
    alegerea explicită "I accept". (Dacă vreun installer Windows ar trece
    vreodată pe NSIS în loc de Inno Setup, echivalentul e
    `!insertmacro MUI_PAGE_LICENSE` cu `MUI_LICENSEPAGE_CHECKBOX` definit,
    pentru varianta cu bifă explicită.)
  - Fișierul `license.txt`/`.rtf` folosit la acest pas trebuie să conțină
    (măcar rezumat) cele 4 puncte cheie din Termeni: statut independent
    (non-comercial), licențiere Machine ID, natura de donație a
    susținerii, garanție "as is"/limitarea răspunderii — nu doar un MIT
    License generic.

**20. Self-Updater real — obligatoriu, niciodată deschidere de browser/
GitHub (2026-08-27).** Descoperit ca bug real, repetat, pe GDC Vault (Mac
și Windows): un simplu link `releases/latest/download/...` deschis în
browser NU e suficient — utilizatorul tot ajunge pe un tab de
browser/GitHub, ceea ce Cristi consideră inacceptabil ("clientul niciodată
nu trebuie să vadă GitHub"). Orice aplicație desktop GDC (Mac/Windows) cu
proces propriu de rulat TREBUIE să implementeze un Self-Updater REAL, nu
doar un link:
- **Mac.** Descarcă `.pkg`-ul cu `URLSession.download`, cu URL-ul citit
  direct din `assets[]` al ultimului release GitHub (nu hardcodat), apoi
  îl instalează printr-un script bash elevat cu `osascript ... with
  administrator privileges` (promptul NATIV de parolă admin macOS —
  NICIODATĂ `sudo` interactiv sau Terminal vizibil), care rulează
  `installer -pkg ... -target /` și relansează aplicația singur. Vezi
  implementarea de referință `SelfUpdater.swift` (DataMover,
  `gdc-plugin-manager-catalog-vendor`, `GDCVault`).
- **Windows.** Descarcă installer-ul (`.exe`) cu `HttpClient` direct pe
  disc, redenumit cu versiunea (Regula 17), apoi îl lansează
  (`Process.Start(UseShellExecute:true)`) — fereastra NATIVĂ Inno Setup
  apare, NICIODATĂ browserul. Aplicația curentă se închide
  (`Application.Current.Shutdown()`) înainte ca userul să ajungă la pasul
  de copiere din wizard; `[Run] ... Flags: nowait postinstall
  skipifsilent` din `installer.iss` relansează aplicația după instalare —
  nu e nevoie de `AppMutex`/`CloseApplications` suplimentar. Vezi
  `SelfUpdater.cs` (`GDCPluginManagerWin`, `GDCVaultWin`).
- O fereastră minimală de progres (`UpdateProgressWindow`, text + spinner
  indeterminat) e obligatorie cât timp durează descărcarea/instalarea —
  userul nu trebuie să creadă că aplicația a înghețat.
- **WARNING permanent**: pasul efectiv de instalare (promptul de parolă
  admin pe Mac, wizardul Inno pe Windows) NU poate fi verificat automat de
  Claude — cere interacțiune fizică reală cu fereastra de sistem.
  Verificarea automată se oprește la "fișierul s-a descărcat integru,
  HTTP 200" — instalarea + relansarea efectivă TREBUIE confirmată manual,
  o dată, de Cristi, înainte ca fluxul să fie declarat complet dovedit.
- **Excepție arhitecturală, nu o abatere**: aplicații FĂRĂ proces propriu
  de rulat (plugin-uri încărcate de o gazdă terță, ex. un IOPlugin
  DaVinci Resolve) nu pot avea un "self-updater" în acest sens — rămân la
  reinstalare manuală ghidată de PDF (Regula 8), fără relansare automată.
- **Regula 13 (Update Checker) rămâne valabilă pentru DETECTAREA
  versiunii noi** (pop-up, texte, dismissal) — doar acțiunea butonului
  principal se schimbă: NU mai deschide un link, cheamă Self-Updater-ul.

**Status acest repo (2026-08-27): IMPLEMENTAT (Mac).** `Sources/GDCPluginManager/SelfUpdater.swift`. Perechea Windows trăiește în `GDCPluginManagerWin`.


**21. Memory & I/O Performance — obligatoriu pentru orice aplicatie care
proceseaza date/fisiere/fluxuri mari (2026-08-27).** Descoperit ca bug real
pe DataMover: un transfer de 3 TB (SSD -> HDD) umplea RAM + swap pana la
eroarea nativa macOS "Your system has run out of application memory".
Cauza radacina reala pe Mac (Swift/DataMoverMac): bucla de citire/scriere
in bucati (`FileHandle.read(upToCount:)`) rula pe un thread de fundal FARA
`autoreleasepool` per iteratie — obiectele Objective-C (`NSData`) din
spatele fiecarui `Data` bridge-uit nu se eliberau decat la finalul
INTREGULUI job (GCD creeaza un autorelease pool per bloc dispatch-uit, nu
per iteratie de bucla), deci memoria temporara se acumula neintrerupt pe
toata durata copierii unui fisier urias sau a unui transfer intreg.
Regula, valabila pentru orice aplicatie GDC (Mac/Windows) care citeste,
scrie, copiaza sau proceseaza fisiere/fluxuri de retea/date mari:

- **Zero acumulare in memorie / streaming intai.** Interzisa incarcarea
  completa a unui fisier/array/raspuns de retea mare in RAM (fara
  `Data(contentsOf:)`, `file.read()` fara argument, `shutil.copy2` pe
  fisiere mari, liste Python/array-uri Swift care colecteaza TOATE
  intrarile unei scanari mari). Orice citire/scriere/procesare foloseste
  un buffer FIX, mic (8-32 MB implicit, configurabil - vezi mai jos), care
  se citeste, se scrie si se elibereaza pe rand.
- **Backpressure.** Daca rata de citire/procesare depaseste rata de
  scriere/iesire (SSD -> HDD, retea lenta etc.), cititorul TREBUIE sa se
  incetineasca (citire sincrona, secvential cu scrierea - fara buffer de
  "read-ahead" care ar acumula date nescrise in RAM), NU sa stocheze
  diferenta in memorie/swap. Daca aplicatia are un plafon de memorie
  configurat (vezi mai jos) si il depaseste, face o pauza scurta intre
  fisiere/blocuri pana cand memoria scade, in loc sa continue orbeste.
- **UI & State Throttling.** Interzisa pastrarea in starea aplicatiei
  (RAM) a TUTUROR obiectelor procesate pentru afisare — un istoric/log de
  sute de mii de intrari intr-un `tk.Text`/`NSTextView`/array `@Published`
  neplafonat e o scurgere de memorie reala, nu doar o "UI mare". UI-ul
  primeste doar: contoare agregate (fisiere procesate, bytes transferati,
  viteza curenta) si o fereastra plafonata cu ultimele N evenimente (ex.
  200 de linii) — restul, daca trebuie pastrat, se scrie INCREMENTAL pe
  disc (CSV/log file), nu se tine intr-o lista in memorie pana la final.
  La fel, un raport final (PDF/CSV) nu tine in RAM randul fiecarui fisier
  dintr-un transfer urias doar ca sa-l scrie o singura data la sfarsit -
  CSV-ul se scrie incremental, iar un PDF/raport vizual pastreaza doar un
  esantion plafonat (plus toate erorile).
- **Scanare/recursivitate fara memorie acumulata.** La enumerarea
  recursiva a unui folder mare, nu se construieste o lista/array cu TOATE
  intrarile deodata daca sursa poate avea sute de mii/milioane de fisiere
  — se foloseste un iterator/generator sau o scriere incrementala pe disc
  (manifest), citit apoi in loturi (batch de 500-1000), ca memoria de varf
  sa ramana plafonata indiferent de dimensiunea sursei.
- **Auto-Release & eliberare explicita in bucle mari.** Pe macOS/Swift,
  orice bucla `while`/`for` care citeste/scrie/proceseaza fisiere mari pe
  un thread de fundal (`DispatchQueue.global`) foloseste `autoreleasepool { }`
  EXPLICIT per iteratie — GCD NU dreneaza automat un pool intre iteratiile
  unei bucle sincrone in interiorul unui singur bloc dispatch-uit. Pe
  Python/alte platforme, echivalentul e eliberarea explicita a
  buffer-elor/resurselor unmanaged (context manageri `with`, `close()`
  explicit) - nu te baza pe garbage collection amanata pentru resurse care
  cresc proportional cu volumul de date procesat.
- **Resource Limits & configurabilitate.** Orice aplicatie care proceseaza
  volume mari de date expune in Setari: (a) dimensiunea buffer-ului de
  citire/scriere (ex. 4/8/16/32/64 MB, implicit 8 MB), si (b) un plafon
  orientativ de memorie a aplicatiei (ex. 512 MB / 1 GB / 2 GB / 4 GB /
  fara limita), peste care se aplica backpressure-ul descris mai sus.
  Plafonul e o limita ORIENTATIVA la nivel de proces (nu un cgroup impus
  de OS) - scopul e sa incetineasca sursa cand memoria creste anormal, nu
  sa garanteze un maxim absolut.
- **Implementare de referinta**: `DataMover` — `IOSettings.swift` +
  fix-ul de `autoreleasepool` din `copyFileCancelable`/`genericHash`
  (`OffloadEngine.swift`, Mac), si `core/io_settings.py` +
  `scan_files_streaming`/`iter_manifest_batches` + raport CSV incremental
  (`core/offload_engine.py`, Windows/Python). Orice aplicatie GDC noua sau
  modificata care atinge fisiere/fluxuri mari respecta acest standard de
  la urmatoarea ei actualizare, nu doar DataMover.

**Status acest repo (2026-08-28, verificat partial): DE VERIFICAT LA URMATOAREA MODIFICARE, nu urgent acum.** Auditat la cererea lui Cristi — `ImageProcessor.swift` proceseaza thumbnail-uri (probabil imagini mici), iar catalogul de LUT/DCTL/PowerGrade presupune upload/download de fisiere care NU au fost confirmate ca raman mereu mici. Nu s-a gasit cod de streaming manual (nici bun, nici problematic) de citire/scriere in bucati pentru aceste fisiere - daca vreun asset din catalog ajunge vreodata la zeci de MB+ (ex. un LUT 3D foarte mare sau un pachet ZIP), aplica Regula 21 (buffer fix, streaming) dupa modelul DataMover.

**22. `PlatformTarget` explicit obligatoriu pentru orice proiect .NET/WPF cu
pachete NuGet native (2026-08-28).** Gasit pe DataMover (client WPF): un
`.csproj` implicit "Any CPU" ruleaza, pe host-ul Windows al lui Cristi
(Parallels pe Mac Apple Silicon), ca `win-arm64` - iar biblioteci cu
binare native (QuestPDF/Skia, si potential altele similare) NU au build
pentru arhitectura asta, cazand tacut cu `DllNotFoundException`/
`TypeInitializationException` doar la runtime, niciodata la `dotnet build`.
Orice `.csproj` nou (sau existent, la prima dependinta nativa adaugata) din
`GDCVaultWin`/`GDCPluginManagerWin`/`DataMover`/orice client Windows viitor
seteaza explicit `<PlatformTarget>x64</PlatformTarget>` - Windows 11 ARM
ruleaza procesul x64 prin emulatie nativa a OS-ului, deci functioneaza
identic pe Windows x64 real si pe ARM64/Parallels. Nu te baza pe "Any CPU"
doar pentru ca merge la compilare.

**23. Garda obligatorie impotriva `dist/` detinut de root, in orice
`build_app.sh` Mac (2026-08-28).** Bug real, repetat de mai multe ori pe
DataMover in aceeasi sesiune (cauza exacta neconfirmata - posibil o
instalare de test cu `sudo installer -pkg ... -target /` care a atins
accidental folderul local): `dist/<App>.app` ramas detinut de `root:wheel`
dintr-un build anterior face ca `rm -rf "dist"` de la inceputul scriptului
sa esueze partial, tacut, cu o gramada de "Permission denied" greu de
gasit in mijlocul unui log lung. Orice `build_app.sh` din ecosistem
(DataMover, GDCVault, CursorPro, gdc-plugin-manager-catalog-vendor, orice
build Mac viitor) verifica ACEST lucru explicit INAINTE de `rm -rf`, cu un
mesaj clar si actionabil (`sudo rm -rf $(pwd)/dist`, de rulat manual O
SINGURA DATA de Cristi - Claude nu poate rula `sudo`), in loc sa lase
`rm -rf` sa esueze criptic:
\`\`\`bash
if [ -d "dist" ] && ! [ -w "dist" ] || find dist -maxdepth 2 -user root -print -quit 2>/dev/null | grep -q .; then
    echo "EROARE: 'dist/' contine fisiere detinute de root. Ruleaza manual:" >&2
    echo "    sudo rm -rf \$(pwd)/dist" >&2
    exit 1
fi
\`\`\`
Practic, inaintea oricarui `release.sh`: `ls -la mac-native/dist` (listare
COMPLETA, nu trunchiata cu `head`) - o listare trunchiata poate rata
`<App>.app` daca sorteaza dupa alte fisiere (`.pkg`/`.zip`), dand o
verificare falsa de "curat".

**24. Standard UI obligatoriu: Setare explicită "Mărime Text" + Layout
robust la redimensionare (2026-08-29).** Completare la Regula 18 — găsit pe
GDC Plugin Manager (Mac): un bug real de layout la resize RAPID al
ferestrei (blocul de profil/footer din sidebar rămânea temporar suprapus
peste conținutul de deasupra) cauzat de `.safeAreaInset(edge:)` atașat
DIRECT pe un `List`/`ScrollView` — la resize rapid pe macOS, content-insetul
intern al listei nu se resincronizează mereu instant cu safe-area-ul
suprapus (bug de sincronizare AppKit/SwiftUI, nu o presupunere). Regulă
practică, valabilă pentru orice fereastră GDC (Mac/Windows) cu o zonă
fixă (footer/header) lângă o listă/grid scrollabilă:
- **Niciodată `.safeAreaInset` direct pe un `List`/`ScrollView` pentru un
  element care trebuie să rămână mereu vizibil și nesuprapus** — pune
  lista și elementul fix ca FRAȚI într-un `VStack`/`Grid` simplu (cu
  `Divider()` între ele, dacă are sens vizual). Layout-ul calculat direct
  de container e mereu sincron, cadru cu cadru, spre deosebire de
  safe-area-ul suprapus peste scroll.
- **Fereastra principală rămâne liber redimensionabilă** (Regula 18), dar
  cu `minWidth`/`minHeight` verificate să nu lase conținutul ilizibil sub
  acel prag — nu doar prezente, ci suficient de generoase pentru sidebar-ul
  cu cele mai multe secțiuni al aplicației respective.
- **Setare explicită "Mărime Text" (Mic/Normal/Mare/Foarte mare) e acum
  standard**, alături de selectorul de temă din Regula 18 — pe SwiftUI/Mac,
  prin infrastructura NATIVĂ de accesibilitate (`dynamicTypeSize()` aplicat
  la rădăcina ferestrei principale, NU un multiplicator brut de font — text
  semantic (`.font(.headline)`/`.caption`/etc) + `dynamicTypeSize` garantează
  reflow corect, spre deosebire de o scalare custom care poate tăia conținut
  în frame-uri fixe). Pe Windows/WPF, echivalentul e un `FontSizeConverter`/
  resursă de `FontSize` global legată de o setare persistată (`Registry`/JSON),
  aplicată la nivelul `Application.Resources`. Persistat local, aplicat
  imediat, fără repornire — la fel ca selectorul de temă.
- Referință de implementare: `TextScalePreference`/`TextScaleManager`
  (`Sources/GDCPluginManagerCore/AppTheme.swift`, `gdc-plugin-manager-catalog-vendor`)
  + restructurarea `NavigationSplitView`/`List` din `ContentView.swift`
  (același repo) — port-ul pe orice altă aplicație GDC (Mac/Windows) cu
  panou lateral fix trebuie verificat la fel pentru acest pattern.

**25. `CHANGELOG.md` obligatoriu la fiecare bump de versiune + Log de
Diagnostic permanent, nu print-uri temporare (2026-08-29).**
- **`CHANGELOG.md`** (rădăcina fiecărui repo) — separat de jurnalul tehnic
  detaliat din acest fișier (CLAUDE.md păstrează deciziile/motivele/
  pitfall-urile complete; `CHANGELOG.md` e un rezumat SCURT, orientat spre
  ce s-a schimbat pentru utilizator, o intrare per versiune/dată, ușor de
  scanat rapid fără să citești tot jurnalul). Actualizează-l în ACELAȘI
  commit ca bump-ul de versiune — la fel de obligatoriu ca bump-ul însuși.
  Dacă repo-ul nu are încă `CHANGELOG.md`, creează-l la prima actualizare
  viitoare (nu aștepta o cerere explicită).
- **Log de Diagnostic PERMANENT** (`DiagnosticLog.write(tag:, message:)` —
  Mac: `GDCPluginManagerCore/DiagnosticLog.swift`, `%TEMP%/gdcpm-crash.log`;
  Windows: `DiagnosticLog.cs`, echivalent) — pentru orice flux nou cu
  potențial de eșec silențios (fetch de rețea, decodare, publicare/commit
  git, încărcare de imagine/resursă asincronă): adaugă apeluri de log DE LA
  ÎNCEPUT, nu abia când apare un bug de investigat. Motiv real, găsit chiar
  în această sesiune: bug-ul cu filigranul sezonier care nu se încărca
  niciodată a fost diagnosticat DOAR după ce am adăugat manual print-uri
  temporare și am rulat aplicația din Terminal — cu logul permanent deja
  acolo, diagnosticul ar fi durat un fișier citit, nu o sesiune de
  reproducere manuală. Un singur fișier de log, comun tuturor componentelor
  aceleiași aplicații (Client + Furnizor, dacă există) — userul trimite UN
  fișier, nu trebuie să știe care componentă a scris eroarea.

**26. Instalare pas-cu-pas (buton roșu/verde per componentă) + Panou
„Terminal Live” obligatoriu pentru orice comandă externă (2026-08-30).**
Stabilit după Master Control Studio Pro (Mac + Windows) — două cerințe
care devin standard pentru orice aplicație GDC nouă sau modificată, de la
următoarea ei actualizare:
- **Niciodată un buton „Instalează tot ce lipsește"/instalare în masă
  fără control explicit.** Orice componentă instalabilă (dependență,
  pachet, plugin) are propriul buton de acțiune, colorat după stare:
  **roșu** = neinstalat/apăsabil, **verde** = instalat (dezactivat, doar
  informativ). Motiv direct de la Cristi: o instalare în masă, silențioasă,
  a mai multor pachete deodată poate bloca sistemul clientului — pas cu
  pas, userul vede exact ce se instalează și când.
- **Panou „Terminal Live" obligatoriu** pentru orice acțiune care rulează
  o comandă externă (instalare pachet, ștergere fișiere/cache, montare
  cloud, orice `Shell.run`/`Process.Start` cu potențial de durată sau
  eșec): un panou tip terminal (fundal închis, text monospace, auto-scroll)
  afișează LINIE CU LINIE ce se execută și rezultatul — niciodată doar un
  text static „Se instalează…"/"✔ Gata" fără detalii. Motiv real, găsit
  2026-08-30: ștergerea de cache pe Windows eșua silențios pe primul fișier
  blocat (catch înfășura toată bucla, nu fiecare fișier), iar userul nu
  avea NICIO indicație că ceva nu a mers — cu panoul de-al doilea rând, nu
  doar bug-ul devine vizibil imediat, ci și comportamentul normal (ce se
  întâmplă „în fundal") devine transparent pentru client.
- **Implementare de referință**: `TerminalLogView.swift` (SwiftUI, Mac) +
  `Controls/TerminalLogView.xaml`/`.cs` (WPF, Windows) — ambele din
  `MacMasterControlPro`/`MacMasterControlProWin`; `DependenciesModuleView.swift`/
  `DependenciesPage.xaml.cs` din același repo arată tiparul de buton
  roșu/verde per element. Portul pe orice altă aplicație GDC (Mac/Windows)
  cu un flux de instalare/dependențe sau operații pe fișiere/rețea trebuie
  verificat la fel pentru acest pattern.
- **Regula 25 (Log de Diagnostic permanent) rămâne complementară, nu
  înlocuită**: `DiagnosticLog` scrie pe disc pentru diagnosticare de la
  distanță (Cristi citește fișierul), panoul „Terminal Live" arată userul
  ÎN TIMP REAL ce se întâmplă, direct în UI — cele două servesc scopuri
  diferite și rămân ambele obligatorii.

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
