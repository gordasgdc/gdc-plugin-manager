# UI Architecture — GDC Plugin Manager (macOS client)

Stare: plan de decompoziție (Faza 2, 2026-09-25). Nimic din `ContentView.swift` nu a fost mutat încă.
Principiu: fiecare extracție are o responsabilitate, păstrează comportamentul, se face într-un commit separat
și e urmată de `swift build` + pornirea aplicației + verificarea ecranului atins.

## 1. Starea actuală (măsurată)

`Sources/GDCPluginManager/ContentView.swift` — 2789 linii, 38 de tipuri, toate `private` în același fișier:

| Linii | Tip | Rol real |
|---|---|---|
| 5–61 | `SidebarSection`, `DeveloperShelf` | modelul de navigație (19 secțiuni) |
| 62–236 | `SeasonalBackground(s)Layer` | filigranul sezonier din fundal |
| 237–707 | `ContentView` (471) | shell: `NavigationSplitView`, bara laterală, toolbar, 2 sheet-uri, 2 alerte, routing pe `selection` |
| 708–796 | `CheckFailedBanner`, `UpdateBanner`, `DependencyBanner` | bannere de stare |
| 797–936 | `GlobalSearchResults` | căutare globală |
| 937–1102 | `CatalogGrid` | lista de produse + filtre |
| 1103–1171 | `SidebarUpdateButton`, `CountdownBadge`, `BadgePill` | controale mici |
| 1172–1492 | `PluginCard` (321) | cardul de produs: prezentare + instalare + licență + erori |
| 1493–2789 | 12 perechi Grid/Card | cursuri, tutoriale, resurse, evenimente, pachete, oferte, magazine, service-uri, aplicații, descărcări, audio |
| 1741–1803 | `FlowLayout`, `CollapsibleDescription` | primitive de layout |

Alte fișiere deja separate: `CatalogFilterBar`, `CoverImageViews`, `SearchBar`, `LicensePane`, `PreferencesView`,
`DependencyPanel`, `ProfileSidebarBlock`, `LaunchOfferBanner`, `CommunityView`, `AndroidPane`, `HelpView`, `OnboardingView`, `GlassCard`.

### Probleme de arhitectură (nu de stil)
1. **Starea instalării e locală cardului.** `PluginCard` ține `isBusy`, `errorMessage`, `statusMessage`,
   `installedPaths` în `@State`. Nu există progres de descărcare, nici stare „în pauză”, iar starea se pierde
   când cardul iese din ecran (grilă leneșă). → Stările cerute (DOWNLOADING, PAUSED, UPDATING, FAILED) nu au model.
2. **`@StateObject` pe singleton-uri** (`CatalogService.shared`, `InstallManager.shared`, `UpdateChecker.shared`):
   `@StateObject` presupune că view-ul deține obiectul. Funcționează, dar ascunde cine e proprietarul.
   → Proprietarul devine `GDCPluginManagerApp`, injectat cu `.environmentObject`.
3. **12 perechi Grid/Card aproape identice** (titlu, copertă, descriere pliabilă, butoane) — fiecare își repetă
   layout-ul și valorile vizuale.
4. **Texte de navigație nelocalizate** în `DeveloperShelf` („Scripturi & Automation”, „SDK & Resurse Dev”).
5. Routing-ul e un `switch` mare în `ContentView.body`; adăugarea unei secțiuni atinge shell-ul.

## 2. Ținta (straturi)

```
App shell        GDCPluginManagerApp → MainWindow (NavigationSplitView, toolbar, sheets, alerts)
Navigation       SidebarSection (model) + SidebarView + SectionRouter (selection → ecran)
Screens          CatalogScreen, CoursesScreen, … (câte unul per secțiune; fără logică de rețea)
Components       ProductCard, ContentCard (generic pentru cele 12 tipuri), StatusBadge, StateView, Banner
State models     ProductActionState (per produs, în InstallManager), CatalogLoadState, UpdateState, LicenseState
Primitives       GDCTokens (Core) + glassCardBackground + FlowLayout
```

Fișiere țintă (în `Sources/GDCPluginManager/`):

| Grup | Fișier | Conținut mutat |
|---|---|---|
| Shell | `Shell/MainWindow.swift` | `ContentView.body` (sheet-uri, alerte, toolbar) |
| Navigație | `Navigation/SidebarSection.swift`, `Navigation/SidebarView.swift`, `Navigation/SectionRouter.swift` | modelul + bara laterală + `switch` |
| Catalog | `Catalog/CatalogGrid.swift`, `Catalog/GlobalSearchResults.swift` | lista și căutarea |
| Card produs | `Catalog/ProductCard.swift` (+ `ProductCardActions.swift`) | `PluginCard` împărțit: prezentare vs acțiuni |
| Conținut | `Content/ContentCard.swift` + `Content/<Tip>Grid.swift` | cele 12 perechi, pe o primitivă comună |
| Stări | `States/StateView.swift` (loading/empty/error/offline), `States/Banners.swift` | bannere + stări goale/eroare |
| Fundal | `Chrome/SeasonalBackgroundLayer.swift` | filigranul |
| Controale | `Components/BadgePill.swift`, `Components/CountdownBadge.swift`, `Components/FlowLayout.swift`, `Components/CollapsibleDescription.swift` | primitive |

`Settings`, `License`, `Dependencies`, `Help` rămân în fișierele existente (sunt deja separate).
**Window management**: dimensiunea minimă și restaurarea rămân în `GDCPluginManagerApp`; se documentează în `MainWindow`.

## 3. Modelul de stare al unui produs (de introdus înainte de redesign-ul cardului)

```swift
enum ProductActionState {           // derivat, nu stocat în view
    case unavailable(reason)         // incompatibil OS, catalog offline
    case licenseRequired, licenseInvalid(reason)
    case notInstalled                // → „Instalează” / „Donează”
    case downloading(progress: Double?), paused(progress)
    case installing
    case installed(version)          // → „Elimină”
    case updateAvailable(from, to)   // → „Actualizează”
    case updating(progress: Double?)
    case failed(message, retry: Bool)
}
```

Sursa: `InstallManager` (`installedVersions`, operația în curs per `item.id`) + `LicenseManager` + `SupportedOS`.
Cardul primește starea și trimite intenții (`install`, `update`, `remove`, `retry`) — nu mai ține logică.
PAUSED cere suport de reluare în `InstallManager` (azi descărcarea nu e reluabilă) — marcat ca lucru nou, nu refactorizare.

## 4. Ordinea extracțiilor (fiecare = un commit, comportament identic)

1. Primitive fără stare: `BadgePill`, `CountdownBadge`, `FlowLayout`, `CollapsibleDescription` (risc zero).
2. `SeasonalBackgroundLayer` + bannerele (au deja stare proprie, izolată).
3. `SidebarSection`/`DeveloperShelf` în `Navigation/` (+ texte prin `L.t`).
4. Cele 12 perechi Grid/Card, fiecare mutată întâi neschimbată, apoi trecută pe `ContentCard`.
5. `CatalogGrid` + `GlobalSearchResults`.
6. `ProductActionState` în `InstallManager` + teste, apoi `PluginCard` → `ProductCard`.
7. Shell: `MainWindow` + `SectionRouter`; `@StateObject` pe singleton-uri → `environmentObject` din App.

Validare per pas: `swift build`, `swift test`, `scripts/check_localization.py`, pornirea aplicației,
secțiunea atinsă verificată în RO/EN/ES și Light/Dark. „Compilează” nu e validare de UI.
