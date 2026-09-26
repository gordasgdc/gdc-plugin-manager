# Inventar pentru adaptarea Windows (Faza 6–7) — doar analiză, nimic implementat

Referință Mac: `main` + ramura `furnizor-faza5` (client 1.40.0, Furnizor 1.53.0). Windows: `GDCPluginManagerWin` (WPF, client 1.37.2).
Furnizorul există doar pe Mac → pe Windows se portează DOAR clientul.

| Mac (sursă) | Ce face | Echivalent Windows existent | Diferență de portat |
|---|---|---|---|
| `Core/DesignSystem/GDCDesignTokens.swift` | spațiere, raze, tipografie, culori, elevație, mișcare | `Styles/Theme.xaml`, `Theme.Dark/Light.xaml`, `BrandColors.xaml` | resurse `Space.*`, `Radius.*`, `Finish.*` (reflex, muchie) cu aceleași valori; regula 37 deja respectată |
| `Core/DesignSystem/GDCButtonStyle.swift` | primar amber (text închis), secundar, distructiv, plain; hover/pressed/disabled; Reduce Motion | stiluri WPF-UI implicite | `Style` dedicat per rol; animații oprite la `SystemParameters.ClientAreaAnimation == false` |
| `Components/StatusBadge.swift` | insignă culoare + iconiță + text, variantă „pe imagine” | text simplu în card | `UserControl` StatusBadge; în Light culoarea textului închisă cu 40% |
| `Components/ContentCard.swift`, `CoverImageViews.swift` (finisaj) | card comun (material, muchie de lumină, hover fără scalare); imagine 156 pt cu reflex | carduri în `MainWindow.xaml` (2614 linii) | un `ContentCard` `ControlTemplate`; întâi spargerea `MainWindow.xaml` (analog F4) |
| `Catalog/ProductCard.swift` + `Core/State/ProductActionState.swift` | 8 stări derivate, testate | logică în code-behind | portarea `ProductActionState` în `GDCPluginManager.Core` (C#) + teste; UI citește starea |
| `States/StateView.swift` | loading (schelet fără pulsație la Reduce Motion), empty, error | text simplu | `StateView` `UserControl`; anunț Narrator o singură dată (`AutomationProperties.LiveSetting`) |
| `States/Banner.swift` | banner unificat (update, dependență, verificare eșuată, offline) | bannere separate în `MainWindow.xaml` | un singur `Banner` control; offline = `isShowingCachedCatalog` în `CatalogService` |
| `Core/PromoBanner.swift` + `LaunchBannerChecker` | campanii, 3 moduri, RO/EN/ES, Light/Dark, 6:1/12:1/3:1, cache SHA-256, decodare unică | `Services/LaunchBannerChecker.cs`, `Core/Models/LaunchBannerModel.cs` (clasic) | modelul `campaigns` (decodare tolerantă), `activeCampaign`, `PromoBannerView` în WPF; fără campanii → bannerul clasic |
| `Shell/SectionRouter.swift` | rutare secțiuni | `MainWindow.xaml.cs` | extragere router + ecrane separate |

Neportabil / nu se aplică pe Windows: Furnizorul (domenii, tabele, inspector, editorul de bannere), galeriile și capturile DEBUG.
Riscuri: `MainWindow.xaml` monolitic (2614 linii) — spargerea lui e premisa; testarea vizuală cere VM-ul din `WINDOWS_LAB.md`.
Ordine propusă: 1) tokeni + stiluri, 2) ProductActionState (Core C#, teste), 3) spargerea MainWindow, 4) componente, 5) bannere promoționale.
