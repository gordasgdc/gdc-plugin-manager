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
