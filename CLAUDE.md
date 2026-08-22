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

**6. Bundle-ul `.command`.**
Wrapper-ul de lansare de pe Mac (`Instalare_GDCPluginManager.command`) rulează `close front window` la final (nu tot Terminal-ul) și pointează exact spre `.app`-ul din `Aplicatie/` — vezi pattern-ul identic în `datamover`.

## Unde se rulează testele reale
Testarea Windows depinde de disponibilitatea unui prieten (sesiune AnyDesk la distanță) — poate dura ore/zile între ferestre de test. Nu bloca alt lucru așteptând un retest.

## Technical Decisions & Known Pitfalls

Jurnal append-only. Un rând nou de fiecare dată când găsim/rezolvăm un bug real — nu o presupunere, ceva confirmat live sau prin citirea codului.

- **2026-08-22 — Pitfall: `file.filename` (doar basename) apla­tiza orice pack cu subfoldere la instalare.** Un `.ofx.bundle` publicat corect de Furnizor (cu `Contents/MacOS/`, `Contents/Resources/` păstrate — `collectFiles` niciodată nu a aplatizat la publicare) se scria PLAT pe disc la instalare, pierzând structura pe care Resolve o cere pentru a recunoaște bundle-ul. **Soluție**: `relativeInstallPath(for:in:)` (Mac) / `RelativeInstallPath` (Windows) reconstruiesc calea relativă la rădăcina produsului din `file.path` (format `id/versiune/rest...`) și o păstrează integral la scriere. Fără schimbare de comportament pentru pack-urile deja publicate, plate.
- **2026-08-22 — Pitfall: DCTL și LUT împărțeau exact același folder de instalare.** Fără subfolderul `DCTL/` dedicat, un `.dctl` nu apare corect ca nod DCTL în pagina Color a Resolve. **Soluție**: `installDirectory` separă acum cazurile `.dctl`/`.lut` — DCTL merge în `.../LUT/DCTL/`. Instalările vechi rămân orfane în `LUT/` până la un reinstall/update.
- **2026-08-22 — Pitfall: `chmod -R 777` pe folderul OFX ar fi rezolvat "un singur prompt de parolă", dar world-writable pe o mașină multi-user.** **Soluție**: `chown` pe rădăcina `/Library/OFX/Plugins` către userul curent, în același script deja elevat (un singur `osascript ... with administrator privileges`) — instalările OFX următoare scriu direct, fără elevare, fără riscul de securitate.
- **2026-08-22 — Pitfall: presupunerea că PowerGrade pe Windows are nevoie de scriere directă în `%APPDATA%\...\Gallery\index.xml`.** Verificat live cu README-ul oficial Blackmagic (Scripting API): nu există un asemenea format documentat, pe nicio platformă. **Soluție**: rămas exclusiv pe Scripting API (`PowerGradeImporter`), niciodată scriere directă în baza de date de Gallery — vezi și `gdc-plugin-manager-win/CLAUDE.md` pentru pitfall-urile specifice Windows (token gol în CI, Python 3.12 incompatibil cu `fusionscript.dll`).
