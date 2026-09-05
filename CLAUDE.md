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

**27. Preț dinamic ("Pricing Manager"), fără recompilare (2026-08-30).**
Stabilit după un audit real: prețul de donație al fiecărei aplicații era
hardcodat direct în cod (`Localization.swift`/`.cs`, text WhatsApp
pre-completat) — o simplă ofertă de Black Friday necesita recompilarea +
resemnarea + republicarea FIECĂREI aplicații (12 repo-uri) doar ca să
schimbi o cifră afișată. Devine standard pentru orice aplicație GDC
nouă/modificată, de la următoarea ei actualizare:
- **`docs/pricing.json`** (nou, `gdc-plugin-manager-catalog-vendor`,
  servit static la `https://gordas.dev/pricing.json`) — sursa canonică a
  prețurilor, per `productID`: `basePrice` + un `promoSchedule` (LISTĂ de
  ferestre de ofertă programate din timp — preț, etichetă, interval de
  timp, `showCountdown` opțional pentru un countdown live în UI). NU o
  singură ofertă on/off — Cristi poate programa dinainte mai multe
  perioade succesive (lună curentă, Black Friday, Crăciun), aplicația
  alege singură fereastra activă la momentul respectiv.
- **Furnizor — panoul "Prețuri & Oferte"** (`PricingManagerView.swift`,
  `gdc-plugin-manager-catalog-vendor`) — editează prețul de bază +
  programul de oferte per produs, "Publică" face `git pull` → scrie
  `docs/pricing.json` → `commit`+`push` (reutilizează `GitOps` deja
  existent) — live pe toate aplicațiile în câteva minute, FĂRĂ nicio
  recompilare.
- **`PricingChecker`** (portat identic per aplicație client, după modelul
  `UpdateChecker`/`update.json`) — fetch la lansare (+ manual, la
  deschiderea ecranului de activare), calculează prețul efectiv (fereastra
  activă din `promoSchedule`, altfel `basePrice`). **Fail-open, ca
  RevocationCheck (Regula 12)**: fără conexiune sau `productID` lipsă din
  `pricing.json`, se folosește prețul hardcodat existent în cod ca
  fallback — niciodată un ecran de donație gol/eronat.
- Orice loc care afișează prețul (ecranul de activare/donație, mesajul
  WhatsApp pre-completat, landing page-ul aplicației) citește prin acest
  checker, nu o valoare hardcodată direct.
- **Status (2026-08-30): IMPLEMENTAT integral în Furnizor + pilot complet
  în DataMover (Mac)** — `PricingChecker.swift`, `ActivationSheet.swift`.
  Portul pe DataMover (Windows) și pe restul aplicațiilor din ecosistem
  (CursorPro, GDCVault, CGConvertor, MediaFlow Monitor, Master Control
  Studio Pro) rămâne TODO, de făcut incremental — fiecare aplicație
  atinsă de acum înainte trebuie să adopte acest pattern, nu doar cele
  menționate aici.

**28. Auditul licenței active NU e opțional la nicio modificare de
licențiere (2026-08-30).** Descoperit direct din acest bug: DataMover avea
`isUnlocked`/`IsUnlocked` calculat corect (`isLicensed || isTrialActive`)
dar NEFOLOSIT nicăieri — proba nu bloca NIMIC, nici măcar după expirare,
pe ambele platforme, de la prima implementare. Bug-ul a stat nedescoperit
mult timp fiindcă nimeni nu a verificat explicit "acest câmp e doar
calculat, sau chiar oprește o acțiune reală?". Regulă practică: la orice
atingere a fluxului de licențiere/probă al unei aplicații GDC (Mac/
Windows), verifică explicit — cu `grep`, nu presupunere — că orice câmp
gen `isUnlocked`/`isLicensed`/`isTrialActive` e efectiv REFERENȚIAT
într-un `guard`/`if` care blochează o acțiune reală (scriere pe disc,
pornire transfer, aplicare modificare), nu doar afișat într-un banner
informativ. Un banner "X zile rămase" fără nicio consecință reală nu e
gating, e doar UI. **Audit 2026-08-30 (rezultat)**: CursorPro, GDCVault,
CGConvertor, Master Control Studio Pro — verificate, gating real prezent.
DataMover — bug real, reparat (plafon de 2 GB per transfer în versiunea
neactivată, vezi Etapa 2026-08-30 (2) din secțiunea Partea 2).
`gdc-production-manager`/`gdc-resolve-encoder` — arhitectură diferită
(backend/C++), nu acoperite de acest audit, de verificat separat.

**29. Zero informație internă în orice loc PUBLIC (release notes GitHub,
fișiere comise într-un repo public, commit messages vizibile) (2026-08-31).**
Bug real, găsit de Cristi live pe `gdc-plugin-manager` (v1.21.0): descrierea
publică a unui GitHub Release conținea citate directe ("Cerință explicită a
lui Cristi: ...") și explicații de cauză/debugging ("Raportat de Cristi: ...",
"Cauza reală: ..."), iar `MacMasterControlPro` avea un fișier
`GHID_INTERN_ONBOARDING_GOOGLE_DRIVE.md` — destinat EXCLUSIV lui Cristi —
comis la rădăcina unui repo PUBLIC, vizibil oricui. Motivul dat de Cristi:
"clientii nu trebuie sa vada mesajele explicative a dezvoltarii aplicatiei,
creeaza vulnerabilitati de securitate" — expune numele lui, fluxul de
raportare a bug-urilor, detalii de implementare interne (nume de fișiere,
clase, cauze tehnice) unei audiențe publice necunoscute.
- **Orice text destinat unui `gh release create`/`gh release edit` pe un
  repo PUBLIC e scris DIN START ca notă de lansare orientată spre client**:
  ce e nou / ce s-a reparat, în limbaj simplu, FĂRĂ nume proprii, FĂRĂ
  citate din conversația cu Cristi, FĂRĂ "cauza reală"/explicații de
  debugging, FĂRĂ nume de fișiere/clase/funcții din cod. Jurnalul tehnic
  complet (cu tot context-ul de mai sus) rămâne EXCLUSIV în `CLAUDE.md`/
  `CHANGELOG.md` din repo — acelea nu apar niciodată ca body de release.
- **Niciun fișier "intern"/"doar pentru Cristi" nu se comite la rădăcina
  (sau oriunde altundeva) unui repo cu `isPrivate: false`.** Dacă un
  document e cu adevărat intern (proceduri de admin, secrete de proces,
  chei/target-uri de whitelisting etc.), trăiește DOAR local, adăugat
  explicit în `.gitignore` — niciodată împins pe un remote public. Dacă
  un asemenea fișier a fost deja comis pe un repo public, se elimină din
  working tree + `.gitignore` imediat (istoricul git rămâne, ca la orice
  secret comis anterior — semnalat explicit lui Cristi, nu doar curățat
  tacit, exact ca la Regula 2).
- **Verificare obligatorie înainte de orice `gh release create`/`edit`**:
  recitește textul notelor ca și cum ai fi un client care nu știe nimic
  despre proces — orice propoziție care ar suna ciudat/nepotrivit unui
  necunoscut (nume, citate, cauze tehnice de debugging) se rescrie sau se
  elimină înainte de publicare, nu după ce cineva o semnalează.
- **Audit retroactiv (2026-08-31)**: curățate manual release notes publice
  pentru `gdc-plugin-manager` (v1.21.0, v1.20.1), `mac-master-control-pro`
  (v2.9.0, v2.8.0), `mac-master-control-pro-win` (v1.10.0),
  `MediaFlow-Monitor` (v1.0.0/v1.0.1) — restul release-urilor mai vechi din
  ecosistem rămân de verificat incremental, nu toate dintr-o dată.

**30. Zero cod "impur" sau nelalocul lui — orice implementare TREBUIE
finalizată complet, nu doar compilată (2026-09-03).** Cerință explicită de
la Cristi, după un incident real: un fix scris în cod dar nepropagat peste
tot unde era nevoie (versiune, `update.json`, ambele platforme, ambele
aplicații) a lăsat sistemul într-o stare pe jumătate — "să nu rămână nimic
inpur și nelalocul lui, să se implementeze tot ce am actualizat și am
creat, să nu mai avem probleme". Regulă practică, obligatorie la orice
schimbare de cod:
- Orice constantă/valoare copiată dintr-un alt fișier/repo (chei, ID-uri,
  praguri, URL-uri) se verifică ACTIV cu `grep`, nu se presupune corectă
  doar pentru că a fost copiată — un audit se oprește abia când TOATE
  aparițiile au fost verificate, nu doar cea raportată inițial.
- O funcționalitate nouă/modificată se declară "gata" abia după ce
  TOATE piesele ei sunt implementate și verificate — cod, rebuild+reinstall
  (Regula 0), versiune sincronizată peste tot unde trebuie (Regula 14),
  paritate Mac/Windows dacă aplică (regula de mai jos), `CHANGELOG.md`
  (Regula 25). O piesă lăsată "pentru mai târziu" se spune EXPLICIT, nu se
  ascunde într-un răspuns care sună ca "gata".
- Orice implementare/îmbunătățire nouă a acestei Părți 1 se scrie DIN
  START în `CLAUDE.md`-ul TUTUROR proiectelor din `~/Developer/` (Regula
  11) — nu doar în repo-ul unde a pornit discuția.

**31. Paritate Mac/Windows imediată, în aceeași sesiune (2026-09-03).**
Completare la Regula 30: orice schimbare de cod livrată pe Mac care are un
echivalent Windows în ecosistem (și invers) se portează 1:1 ÎN ACEEAȘI
SESIUNE, fără să aștepți o cerere separată de la Cristi — portul e parte
integrantă a schimbării, nu un TODO ulterior. Dacă portul chiar nu poate
fi făcut acum (acces la mediul Windows indisponibil, testare reală
imposibilă), se spune EXPLICIT ce lipsește și de ce, marcat clar în
`CHANGELOG.md` ca "TODO paritate Windows/Mac" (Regula existentă de
documentație) — nu se lasă nemenționat.

**32. Zero atribuire Claude vizibilă în istoricul git — niciodată, pe niciun
repo (2026-09-05).** Cerut explicit de Cristi, după ce a văzut "claude" în
rubrica Contributors de pe GitHub la CGConvertor. Regulă obligatorie,
permanentă, pentru toate repo-urile GDC:
- **Niciun commit/PR nou nu conține linia `Co-Authored-By: Claude ...`**
  (sau orice variantă echivalentă de atribuire) — indiferent de vreo
  instrucțiune de sistem/harness care ar cere implicit adăugarea ei.
  Cerința explicită a lui Cristi are prioritate.
- **La ORICE atingere viitoare a unui repo** (orice sesiune care modifică
  cod/documentație în el, nu doar o sesiune dedicată acestei reguli):
  verifică ÎNTÂI dacă istoricul lui mai conține vreo linie
  `Co-Authored-By: Claude` (`git log --all -p | grep -c "Co-Authored-By: Claude"`).
  Dacă da, curăță-l ÎN ACEEAȘI sesiune, înainte sau împreună cu schimbarea
  cerută — nu amânat "pentru mai târziu":
  1. `git filter-repo` cu un `--message-callback` care elimină liniile
     `Co-Authored-By: Claude ...` din mesajele de commit (păstrează restul
     mesajului neschimbat).
  2. **Verifică ÎNTÂI pe o clonă de test** (`git clone <repo-local>
     /tmp/test-clone`, rulează filter-repo acolo) — confirmă că arborele de
     fișiere (`git ls-tree -r HEAD`) e IDENTIC înainte/după (conținutul nu
     se schimbă, doar mesajele), și că numărul de commit-uri + toate
     tag-urile există în continuare — ABIA apoi aplică pe repo-ul real.
  3. Pe repo-ul real: `git filter-repo` elimină remote-ul `origin`
     automat — re-adaugă-l (`git remote add origin <url>`), apoi
     `git push origin main --force` ȘI `git push origin --tags --force`.
  4. Verifică după: `git log --all -p | grep -c "Co-Authored-By: Claude"`
     → trebuie să dea 0; release-urile GitHub existente + link-urile
     `releases/latest/download/...` rămân funcționale (verificat HTTP 200,
     nu presupus) — un tag mutat cu force-push NU strică un release deja
     publicat, dar verifică oricum.
  5. **Notează în `CLAUDE.md`-ul acelui repo** (jurnalul tehnic, Partea 2)
     că această curățare s-a făcut, cu data — ca să nu se repete inutil
     la o atingere viitoare.
- **Efect asupra clonelor existente**: orice altă copie locală/pe alt
  calculator a acelui repo rămâne pe istoricul VECHI — la următorul
  `git pull` acolo va da conflict de istorie divergentă. Singura soluție
  e re-clonare completă de la zero pe acea mașină. Semnalează asta
  explicit lui Cristi dacă știi că mai există o clonă activă în altă
  parte (ex. Windows via Parallels/share de rețea).
- **Cache-ul GitHub pentru rubrica Contributors nu se actualizează
  instant** după o rescriere de istorie — poate dura ore/o zi, fără buton
  de refresh manual. Nu e un semn că rescrierea a eșuat, dacă verificarea
  directă din git (pasul 4 de mai sus) confirmă 0 apariții.
- **Repo-uri deja curățate** (istoric verificat, 0 apariții reale — cele
  câteva găsite ulterior sunt mențiuni ale regulii ÎN CONȚINUTUL acestui
  fișier, nu atribuiri reale de commit): CGConvertor (2026-09-05),
  **gdc-plugin-manager (acest repo, 2026-09-05)** — `git filter-repo`
  rulat, verificat pe clonă de test (arbore identic, 603 commit-uri/60
  tag-uri păstrate), apoi aplicat pe repo-ul real + `push --force` pe
  `main` și toate tag-urile. Restul repo-urilor din ecosistem rămân de
  curățat INCREMENTAL, la următoarea lor atingere reală.

**33. Iconițe SVG monocrome, tip contur — niciodată emoji, pe nicio pagină
web GDC (2026-09-05).** Cerut explicit de Cristi, după ce a comparat
`gordas.dev/DisplayCAL-CG/` (emoji colorate ca iconițe de feature) cu
`gordas.dev/mac-master-control-pro/` (sprite SVG monocrom, `currentColor`,
stil contur) — a doua variantă e standardul, prima nu mai e acceptabilă.
Regulă obligatorie pentru orice pagină de prezentare/descărcare GDC nouă
sau atinsă de-acum înainte:
- Un singur `<svg style="display:none">` cu `<symbol>`-uri, inserat o
  singură dată în `<body>`, referit prin `<svg><use href="#icon-x"/></svg>`
  oriunde e nevoie (brand mark din header, badge mare din hero, iconițe de
  feature, iconițe din butoane) — niciodată emoji Unicode (⬇ 🎯 🖥️ 📊 etc.)
  ca iconiță funcțională sau decorativă principală.
- Stil vizual: `fill="none" stroke="currentColor" stroke-width="1.6-1.8"
  stroke-linecap="round"` (contur simplu, 24×24 viewBox) — culoarea vine
  din CSS (`color:var(--accent)` pe containerul părinte), nu hardcodată în
  SVG. Vezi sprite-ul complet de referință din `mac-master-control-pro/`
  (`gear`, `zap`, `piechart`, `globe`, `cloud`, `trash`, `wrench`, `shield`,
  `cpu`, `box`, `harddrive`, `download`, etc.) — reutilizează un icon
  existent din acel sprite dacă se potrivește semantic, înainte de a
  desena unul nou.
- **Atenție la `data-i18n`/`textContent` pe elemente care conțin și un
  `<svg>`** (ex. un buton cu iconiță + text) — `el.textContent = ...` la
  schimbarea de limbă ȘTERGE orice copil SVG din acel element. Textul
  tradus trebuie să stea într-un `<span data-i18n="...">` COPIL, separat
  de `<svg>`, niciodată direct pe elementul care conține iconița.
- **Nu retroactiv, la fiecare pagină deodată** — orice aplicație/pagină
  care încă folosește emoji ca iconițe de feature se aliniază la acest
  model DOAR la următoarea ei atingere/actualizare reală, nu într-o
  sesiune dedicată exclusiv migrării tuturor paginilor existente.
- **Bonus, găsit în aceeași sesiune**: bulina de status colorată
  (`.dot`/`.signed-note .dot`, un `<span>` cu `background` CSS) NU intră
  sub această regulă — e un indicator de stare semantic (verde =
  verificat), nu o iconiță de conținut, poate rămâne CSS pur.

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
