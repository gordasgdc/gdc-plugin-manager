# Strategia de localizare — GDC Plugin Manager

Stare: 2026-09-25. Separă ARHITECTURA (cum ajunge textul în UI) de POLITICA DE TRADUCERE (ce limbi, pentru cine).

## 1. Starea măsurată

| Aplicație | Mecanism | Limbi | Verificat automat |
|---|---|---|---|
| Client macOS | `L.t("cheie")` → tabel `[cheie: [.ro, .en, .es]]` în `Localization.swift`, schimbare live prin `LanguageStore`; fallback RO → cheia | RO/EN/ES | `scripts/check_localization.py` (CI: chei lipsă blochează; Regula 3 = avertisment tranzitoriu) |
| Client Windows | texte în XAML/C#, fără selector de limbă | **doar RO** | nu |
| Furnizor (intern) | ~270 de texte literale românești în `Text("…")` | RO | nu |
| Conținutul catalogului | câmpuri mono-lingve (`name`, `description`) | limba în care publică furnizorul | nu |

`check_localization.py` pe client (2026-09-25): 305 chei, 0 chei lipsă, 0 limbi lipsă.
**22 de încălcări ale Regulii 3** în 8 chei (`card.trustMessage`, `bundles.buy`, `license.status.none.body`,
`license.machineID.body`, `license.buy.price`, `help.buy.body`, `help.community.body`, `help.machine.body`):
„preț/cumpără”, „price/buy”, „precio/comprar”. Textul corect cere o formulare de donație aprobată →
decizie de conținut + release, nu corectură automată. Până atunci, CI-ul rulează cu `--forbidden-as-warning`.

Alte goluri găsite: `DeveloperShelf` („Scripturi & Automation”, „SDK & Resurse Dev”) e text literal,
nelocalizat; 9 chei sunt compuse dinamic (`sidebar.download.\(category)`) — neverificabile static.

## 2. Arhitectura (decizie: se păstrează mecanismul existent)

`L.t` + tabel e simplu, testabil și deja folosit de 288 de apeluri. Migrarea la String Catalogs (`.xcstrings`)
nu aduce nimic ce lipsește azi și ar rupe build-ul SPM + scriptul de verificare. Se completează cu:

1. **Chei dinamice** → funcții tipizate (`L.downloadCategory(_:)`) cu `switch` exhaustiv, ca o categorie nouă
   să nu poată rămâne netradusă fără eroare de compilare.
2. **Text literal în UI = eroare** în `check_localization.py`, după ce `DeveloperShelf` e trecut prin `L.t`.
3. **Pluralizare**: azi inexistentă; când apare prima nevoie, `L.plural(cheie, n)` cu forme RO (1 / 2–19 / 20+ „de”).
4. **Layout**: fiecare ecran redesenat se verifică în toate trei limbile (spaniola e de obicei cea mai lungă).
5. **Windows** folosește aceleași chei și aceleași texte (export din `Localization.swift` într-un `.resx`/JSON
   generat), ca cele două platforme să nu se despartă.

## 3. Politica pentru Furnizor — decizie de produs, deschisă

| Opțiune | Ce înseamnă | Cost | Când are sens |
|---|---|---|---|
| **A. doar RO** | textele rămân în română, dar trec prin `F.t("cheie")` (un singur loc) | mic: extragere mecanică, fără traducere | Furnizor rămâne o unealtă internă cu un singur operator |
| **B. RO/EN** | A + traducere EN | mediu: ~270 texte, un tabel în plus de întreținut la fiecare ecran nou | colaboratori/operatori care nu citesc română |
| **C. RO/EN/ES** | ca B + ES | cel mai mare; fiecare ecran nou de admin cere 3 texte | Furnizor devine produs distribuit altor furnizori |

**Recomandare:** A acum. Extragerea textelor e necesară oricum (separă textul de UI, permite verificarea
Regulii 3 și a cuvintelor interzise); traducerea se poate adăuga oricând peste aceeași structură.
Până la decizie, nimic nu se traduce.

## 4. Politica pentru clientul Windows

RO/EN/ES e cerință de paritate (clientul Windows e public). Recomandat în Faza 6: aceleași chei ca pe Mac,
selector de limbă în Setări, verificare automată în CI-ul Windows. **REQUIRES PHYSICAL WINDOWS VALIDATION**
pentru lungimea textelor în layout-ul WPF (CI nu poate randa UI-ul).
