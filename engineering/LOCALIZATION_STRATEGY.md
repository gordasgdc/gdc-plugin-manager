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

## 5. Regula 3 — cele 8 texte (22 potriviri), clasificate

Clase: A funcțional · B comercial/cumpărare · C donație/susținere · D licențiere · E marketing · F excepție acceptabilă.
Nimic nu e aplicat. Textele candidate sunt propuneri; decizia e a proprietarului produsului (REQUIRES PRODUCT DECISION pentru toate).

| Cheie | Ecran | Clasă | CURRENT (RO) | PROBLEM | CANDIDATE WORDING (RO) | RATIONALE |
|---|---|---|---|---|---|---|
| `card.trustMessage` | tooltip card produs + card resursă | E | „…Licență Lifetime la preț promoțional de lansare.” | „preț” | „…Licență Lifetime, cu donație promoțională de lansare.” | păstrează mesajul promo, fără „preț” |
| `bundles.buy` | buton card pachet | B | „Cumpără pachetul” | „cumpără” pe butonul principal | „Donează pentru pachet” | aliniat cu butonul „Donează” de pe produse |
| `license.status.none.body` | Licență, fără licență | B | „…răsfoiește catalogul și cumpără doar ce vrei să folosești.” | „cumpără” | „…răsfoiește catalogul și susține doar produsele pe care le folosești.” | „susține” = modelul de donație |
| `license.machineID.body` (EN/ES) | Licență, ID mașină | D | EN „…when you buy the license…”; ES „…comprar…” (RO e corect) | „buy/comprar” | EN „…when you request your license…”; ES „…al solicitar tu licencia…” | RO folosește deja formularea neutră |
| `license.buy.price` | Licență, explicație sumă | C | „Prețul de pe fiecare card e o donație…” | „preț” | „Suma de pe fiecare card e o donație…” | identic cu formularea din `help.buy.body` |
| `help.buy.body` | Ajutor | C/F | „…o donație… — nu un preț de vânzare, nu un abonament.” | negație care conține „preț de vânzare” | „…o donație unică, nu un abonament.” | negația e corectă ca sens, dar Regula 3 interzice cuvintele; fraza rămâne clară fără ele |
| `help.community.body` | Ajutor | E | „…„Pachete” (produse GDC combinate la un preț total avantajos).” | „preț” | „…„Pachete” (produse GDC combinate, cu o donație totală avantajoasă).” | consecvent cu pachetele |
| `help.machine.body` (EN/ES) | Ajutor | D | EN „…when buying…”; ES „…comprar…” | „buying/comprar” | EN „…when requesting your code…”; ES „…al solicitar tu código…” | idem `license.machineID.body` |

Ecranele afectate: grilă produse (tooltip), grilă pachete (buton), `LicensePane`, `HelpView`.
După decizie: textele se schimbă în `Localization.swift`, `check_localization.py` rulează strict (fără `--forbidden-as-warning`),
versiune PATCH nouă (Regula 14).

## 6. Furnizor — opțiunile detaliate

Arhitectura comună tuturor opțiunilor: `F.t("cheie")` + tabel (același tipar ca `L.t`), verificat de o variantă a
`check_localization.py`. Adăugarea unei limbi = o coloană în tabel, fără schimbări de UI. Clientul public și Furnizorul
împart tokenii de design, NU textele sau fluxurile: terminologia admin („serial”, „revocare”, „publicare”) nu apare în client.

| Criteriu | A — RO | B — RO+EN | C — RO+EN+ES |
|---|---|---|---|
| Utilizatori | un operator (vânzătorul) | + colaboratori non-RO | + furnizori terți vorbitori de ES |
| Suprafață de traducere | 0 (doar extragere ~270 texte) | ~270 texte + fiecare ecran nou | ~540 texte + fiecare ecran nou |
| Cost de întreținere | minim | fiecare ecran nou cere EN | fiecare ecran nou cere EN+ES |
| QA | o limbă | layout verificat în 2 limbi | 3 limbi |
| Documentație / capturi | ghidurile PDF actuale (RO) | ghiduri EN | ghiduri EN+ES |
| Release | fără impact | selector de limbă în Preferințe | idem |
| Extensibilitate | completă (arhitectura e aceeași) | completă | completă |
| Consistență terminologică | glosar RO | glosar RO↔EN obligatoriu | glosar trilingv obligatoriu |

Recomandare neschimbată: A + extragerea textelor; B/C se adaugă ulterior fără rescriere.
