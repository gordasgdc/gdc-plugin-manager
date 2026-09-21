import SwiftUI
import AppKit
import GDCPluginManagerCore

enum SidebarSection: Hashable {
    case all
    case type(PluginType)
    case audio
    case download(DownloadCategory)
    case courses
    case educationalResources
    case tutorials
    case events
    case partnerOffers
    case bundles
    case partnerStores
    case serviceCenters
    case apps
    case myApps
    case android
    case license
    case help
    case community
    case developer(DeveloperShelf)
}

/// Secțiunea DEVELOPER (2026-09-19). Maparea e prin etichete din catalog
/// (`access.tags`), editabile din Furnizor — nicio listă fixă de produse:
/// aplicațiile cu eticheta „Developer” ajung la „Aplicații & Utilitare”
/// (și ies din lista generală a Ecosistemului), resursele descărcabile cu
/// eticheta raftului lor ajung la „Scripturi & Automation” / „SDK & Resurse Dev”.
enum DeveloperShelf: String, Hashable, CaseIterable {
    case apps, scripts, sdk

    static let appsTag = "Developer"

    var tag: String {
        switch self {
        case .apps: return Self.appsTag
        case .scripts: return "Scripturi & Automation"
        case .sdk: return "SDK & Resurse Dev"
        }
    }

    var titleKey: String { "sidebar.developer.\(rawValue)" }

    var symbol: String {
        switch self {
        case .apps: return "hammer"
        case .scripts: return "terminal"
        case .sdk: return "shippingbox"
        }
    }
}

/// Filigran sezonier — Etapa 6 (2026-08-29). O imagine MARE (nu o
/// iconiță), la opacitate mică, "gravată" în fundalul ferestrei: ocupă o
/// porțiune generoasă din colțul dreapta-jos, non-interactivă
/// (`allowsHitTesting(false)`), fără să concureze cu conținutul din
/// prim-plan. `nil` => nimic randat, fundalul Shift normal rămâne
/// neschimbat.
private extension SeasonalPosition {
    var alignment: Alignment {
        switch self {
        case .bottomTrailing: return .bottomTrailing
        case .bottomLeading: return .bottomLeading
        case .topTrailing: return .topTrailing
        case .topLeading: return .topLeading
        case .center: return .center
        }
    }
}

/// Toate filigranele active acum, fiecare la poziția lui configurată —
/// 2026-08-29. `Catalog.activeSeasonalBackgrounds` a filtrat deja după
/// `isActiveNow` și a rezolvat coliziunile de poziție (ultimul adăugat
/// câștigă, vezi comentariul de acolo), deci aici doar randăm.
private struct SeasonalBackgroundsLayer: View {
    let configs: [SeasonalBackgroundConfig]

    var body: some View {
        ZStack {
            ForEach(configs) { config in
                SeasonalBackgroundLayer(config: config)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: config.position.alignment)
            }
        }
        .allowsHitTesting(false)
    }
}

private struct SeasonalBackgroundLayer: View {
    let config: SeasonalBackgroundConfig
    @State private var nsImage: NSImage?

    /// Cache local pe disc (Etapa 8) — la fel ca `catalog-cache.json`, ca
    /// filigranul să rămână vizibil offline / la eșec de rețea.
    ///
    /// CHEIAT PER FILIGRAN (2026-08-29): era un singur fișier global
    /// `seasonal-background-cache`, ceea ce cu o bibliotecă de mai multe
    /// filigrane ar fi însemnat că ultimul descărcat suprascrie cache-ul
    /// tuturor celorlalte (offline, toate ar fi arătat aceeași imagine).
    private var cacheFileURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("GDCPluginManager")
            .appendingPathComponent("seasonal-cache", isDirectory: true)
            // `id` e slug de catalog (litere mici/cifre/cratime), dar
            // filtrăm oricum ce ar putea deveni cale ("/", "..").
            .appendingPathComponent(config.id.replacingOccurrences(of: "/", with: "_"))
    }

    var body: some View {
        // [2026-08-29, BUG REAL găsit și reparat] `.task` era atașat pe un
        // `Group { if let nsImage {...} }` — la primul randaj (`nsImage`
        // încă `nil`), acel Group nu are NICIUN copil concret, iar SwiftUI
        // pare să NU garanteze `.task`/`onAppear` pe un asemenea "gol
        // condițional" (confirmat printr-un print de diagnostic care
        // NICIODATĂ nu apărea — task-ul pur și simplu nu pornea, deci
        // fetch-ul de imagine nu se declanșa NICIODATĂ, indiferent ce era
        // publicat sau ce opacitate avea). Fix: `.task` atașat pe un
        // container CONCRET, mereu prezent (`Color.clear` cu `frame` fix),
        // cu imaginea suprapusă DOAR când există — containerul de bază nu
        // mai depinde de starea condițională.
        Color.clear
            .frame(width: 480, height: 480)
            .overlay {
                if let nsImage {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        // [2026-08-29] Intensitate per-filigran, nu mai o
                        // constantă globală - vezi SeasonalBackgroundConfig.opacity.
                        .opacity(config.opacity)
                }
            }
            // [2026-08-29, corectat la cererea lui Cristi] Padding NEGATIV
            // aici împingea imaginea în afara ferestrei și îi tăia efectiv
            // o bucată vizibilă din colț ("îmi mănâncă din imagine"). Acum
            // inset POZITIV — filigranul rămâne întreg, doar cu puțin
            // spațiu față de margine.
            // [2026-08-29, mărit la cererea lui Cristi] 24pt încă îl lipea
            // prea aproape de margine ("ca și cum l-ar tăia") — 48pt (dublu)
            // lasă o distanță vizibilă, clară, pe orice latură.
            .padding(config.position == .center ? 0 : 48)
        .task(id: config.imagePath) {
            // Log de diagnostic PERMANENT (nu print-uri temporare) — vezi
            // DiagnosticLog.swift. Motiv direct: bug-ul real de azi (task
            // neatașat corect, fetch-ul nu pornea niciodată) a fost gasit
            // DOAR adăugând print-uri temporare, rulând din Terminal cu
            // NSUnbufferedIO=YES. Cu logul permanent, un raport viitor de
            // gen "nu apare filigranul" se diagnostichează direct din
            // %TEMP%/gdcpm-crash.log, fără să mai reproducem manual bug-ul.
            DiagnosticLog.write("SeasonalBackground", "task pornit pt. id=\(config.id) imagePath=\(config.imagePath)")
            guard let url = config.imageURL else {
                DiagnosticLog.write("SeasonalBackground", "id=\(config.id): imageURL NIL")
                nsImage = nil
                return
            }
            // NU AsyncImage: decodorul lui SwiftUI nu randează fiabil SVG
            // pe macOS (2026-08-29, filigran Black Friday invizibil în
            // Client — cauza reală). `NSImage(data:)` ȘTIE nativ SVG
            // (suport adăugat în macOS 12+), la fel ca orice raster.
            //
            // [2026-08-29] RETRY + eroare reală în log — găsit live (raportat
            // de Cristi): un filigran eșua consecvent la fetch în timp ce
            // altul, publicat în același minut, mergea perfect — verificat
            // direct că fișierul era disponibil pe server (HTTP 200, `curl`)
            // exact cât timp aplicația raporta eșec. Concluzie: nu era un
            // bug de cod, ci un blip TRANZITORIU de rețea/CDN (gordas.dev
            // trece prin Cloudflare ȘI Fastly/GitHub Pages — un nod de edge
            // poate rata o cerere fără ca alta, milisecunde mai târziu, s-o
            // rateze). `try?` ascundea eroarea REALĂ (timeout? DNS? TLS?) —
            // acum se loghează explicit. Un singur retry, cu pauză scurtă,
            // rezolvă marea majoritate a acestor blip-uri fără interacțiune
            // manuală (fără "Reîmprospătează" apăsat de 10 ori).
            // [2026-08-29, val 2 — BUG REAL găsit din log-ul de diagnostic]
            // `URLSession.shared.data(from:)` NU aruncă la un status HTTP de
            // eroare (404/500) — aruncă DOAR la eșec de rețea (DNS/TLS/
            // timeout). Un 404 tranzitoriu de CDN (edge stale, imediat după
            // republish — vezi comentariul de mai sus) trecea deci prin
            // ramura de "succes", primea corpul paginii de eroare a
            // GitHub Pages (9115 bytes, identic pe toate filigranele
            // afectate), eșua la `NSImage(data:)`, și IEȘEA din buclă cu
            // `break` — fără al doilea retry, exact eșecul pe care retry-ul
            // exista să-l repare. Fix: statusul HTTP se verifică EXPLICIT
            // înainte de decodare; orice non-200 (sau eșec de decodare a
            // unui răspuns 200, date corupte) se tratează ca eșec real, care
            // CONTINUĂ bucla de retry, nu `break`.
            var lastError: Error?
            var loaded = false
            for attempt in 1...2 {
                do {
                    let (data, response) = try await URLSession.shared.data(from: url)
                    let status = (response as? HTTPURLResponse)?.statusCode ?? -1
                    guard status == 200 else {
                        DiagnosticLog.write("SeasonalBackground", "id=\(config.id): HTTP \(status) (\(data.count) bytes) la încercarea \(attempt)")
                        lastError = nil
                        if attempt == 1 { try? await Task.sleep(nanoseconds: 800_000_000) }
                        continue
                    }
                    guard let image = NSImage(data: data) else {
                        DiagnosticLog.write("SeasonalBackground", "id=\(config.id): HTTP 200 (\(data.count) bytes) dar NSImage nu a decodat (încercarea \(attempt))")
                        lastError = nil
                        if attempt == 1 { try? await Task.sleep(nanoseconds: 800_000_000) }
                        continue
                    }
                    DiagnosticLog.write("SeasonalBackground", "id=\(config.id): OK, \(data.count) bytes, HTTP 200 (încercarea \(attempt))")
                    nsImage = image
                    saveToCache(data: data)
                    loaded = true
                    break
                } catch {
                    lastError = error
                    DiagnosticLog.write("SeasonalBackground", "id=\(config.id): fetch EȘUAT la încercarea \(attempt): \(error)")
                    if attempt == 1 {
                        try? await Task.sleep(nanoseconds: 800_000_000) // 0.8s, apoi reîncearcă o dată
                    }
                }
            }
            if !loaded {
                if let cached = try? Data(contentsOf: cacheFileURL), let image = NSImage(data: cached) {
                    DiagnosticLog.write("SeasonalBackground", "id=\(config.id): fetch eșuat de 2 ori (\(String(describing: lastError))), fallback pe cache local reușit")
                    nsImage = image
                } else {
                    DiagnosticLog.write("SeasonalBackground", "id=\(config.id): fetch eșuat de 2 ori (\(String(describing: lastError))) ȘI niciun cache local disponibil")
                }
            }
        }
    }

    private func saveToCache(data: Data) {
        try? FileManager.default.createDirectory(at: cacheFileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: cacheFileURL)
    }
}

struct ContentView: View {
    @StateObject private var catalog = CatalogService.shared
    @StateObject private var installs = InstallManager.shared
    @ObservedObject private var license = LicenseManager.shared
    @StateObject private var updateChecker = UpdateChecker.shared
    // Observed here (the root view) so a language switch, made from
    // LicensePane's picker, redraws the entire app — not just that pane.
    @ObservedObject private var languageStore = LanguageStore.shared

    @State private var selection: SidebarSection? = .all

    /// Deschide secțiunea din care face parte rubrica dată. Nu strânge
    /// niciodată altceva: o secțiune deschisă manual de utilizator rămâne
    /// deschisă, fiindcă a deschis-o el.
    private func expandSection(containing section: SidebarSection?) {
        guard let section else { return }
        switch section {
        case .all, .type:
            expandResolveInstall = true
        case .audio, .download:
            expandDownloadResources = true
        case .courses, .educationalResources, .tutorials, .events,
             .partnerOffers, .bundles, .partnerStores, .serviceCenters, .community:
            expandCommunity = true
        case .apps, .android, .myApps:
            expandEcosystem = true
        case .license, .help:
            expandAccount = true
        case .developer:
            expandDeveloper = true
        }
    }

    // Secțiuni pliabile în bara laterală (2026-09-14). @AppStorage, nu @State:
    // preferința trebuie să supraviețuiască repornirii — altfel fiecare
    // pornire ar reface aceleași click-uri de restrângere.
    //
    // Implicit doar prima e deschisă: meniul pornește compact, dar niciodată
    // complet gol — un sidebar în care nu se vede nimic la pornire pare stricat.
    @AppStorage("sidebar.expanded.resolveInstall") private var expandResolveInstall = true
    @AppStorage("sidebar.expanded.downloadResources") private var expandDownloadResources = false
    @AppStorage("sidebar.expanded.community") private var expandCommunity = false
    @AppStorage("sidebar.expanded.ecosystem") private var expandEcosystem = false
    @AppStorage("sidebar.expanded.account") private var expandAccount = false
    @AppStorage("sidebar.expanded.developer") private var expandDeveloper = false
    @State private var showOnboarding = false
    @State private var missingDependencies: [SystemDependency] = []
    @State private var allDependencies: [SystemDependency] = []
    @State private var showDependencyPanel = false
    @State private var showManualUpdateCheckAlert = false
    @State private var manualUpdateCheckMessage = ""
    @State private var globalSearchText = ""

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    /// Nume din TOATE categoriile — folosit ca sugestii live pentru bara
    /// de căutare globală (istoricul recent se adaugă separat, în SearchBar).
    /// Fiecare categorie nouă își are cheia ei de catalog — vezi
    /// `Catalog.pdfResources` / `Catalog.scriptResources` pentru motiv.
    private func resourcesFor(_ category: DownloadCategory) -> [DownloadableResource] {
        switch category {
        case .pdf: return catalog.pdfResources
        case .script: return catalog.scriptResources
        default: return catalog.downloadableResources
        }
    }

    /// Toate produsele instalabile, indiferent în ce cheie de catalog stau.
    /// Scripturile au cheia lor (`scriptItems`) din motive de
    /// retrocompatibilitate, dar pentru UI sunt produse ca oricare altele.
    private var allInstallableItems: [PluginItem] { catalog.items + catalog.scriptItems }

    private var globalSearchSuggestions: [String] {
        // Acumulator, nu un lung lanț de `+` (Swift a depășit timeout-ul de
        // type-check pe expresia unică după adăugarea celui de-al 12-lea
        // termen — vezi comentariul de mai jos despre `detailContent`).
        var names: [String] = allInstallableItems.map(\.name)
        names += catalog.apps.map(\.name)
        names += catalog.courses.map(\.name)
        names += catalog.audioTracks.map(\.name)
        names += catalog.events.map(\.title)
        names += catalog.educationalResources.map(\.name)
        names += catalog.tutorials.map(\.title)
        names += catalog.partnerStores.map(\.name)
        names += catalog.serviceCenters.map(\.name)
        names += catalog.downloadableResources.map(\.name)
        names += catalog.pdfResources.map(\.name)
        names += catalog.scriptResources.map(\.name)
        names += catalog.partnerOffers.map(\.brandName)
        names += catalog.productBundles.map(\.name)
        return names
    }

    // Extras din body — switch cu multe cazuri inline facea type-check-ul
    // Swift sa depaseasca timeout-ul ("unable to type-check in reasonable
    // time") dupa adaugarea cazului .serviceCenters.
    @ViewBuilder
    private var detailContent: some View {
        switch selection {
        case .license:
            LicensePane()
        case .help:
            HelpView()
        case .courses:
            // Etapa 4 (2026-08-29): filtrat pe valabilitate temporală —
            // conținut nescheduled (nil) rămâne mereu vizibil, identic cu
            // înainte.
            CoursesGrid(courses: catalog.courses.filter { $0.scheduling?.isActiveNow ?? true })
        case .educationalResources:
            EducationalResourcesGrid(resources: catalog.educationalResources.filter { $0.scheduling?.isActiveNow ?? true })
        case .community:
            CommunityGrid(channels: catalog.communityChannels.publishedSorted)
        case .tutorials:
            TutorialsGrid(tutorials: catalog.tutorials.filter { $0.scheduling?.isActiveNow ?? true })
        case .events:
            EventsGrid(events: catalog.events.filter { $0.scheduling?.isActiveNow ?? true })
        case .partnerOffers:
            PartnerOffersGrid(offers: catalog.partnerOffers.filter { $0.scheduling?.isActiveNow ?? true })
        case .bundles:
            BundleGrid(bundles: catalog.productBundles.filter { $0.scheduling?.isActiveNow ?? true }, catalog: catalog)
        case .partnerStores:
            PartnerStoresGrid(stores: catalog.partnerStores.filter { $0.scheduling?.isActiveNow ?? true })
        case .serviceCenters:
            ServiceCentersGrid(centers: catalog.serviceCenters.filter { $0.scheduling?.isActiveNow ?? true })
        case .apps:
            AppsGrid(apps: catalog.apps.filter {
                ($0.scheduling?.isActiveNow ?? true) && !$0.resolvedAccess.tags.contains(DeveloperShelf.appsTag)
            })
        case .developer(let shelf):
            switch shelf {
            case .apps:
                AppsGrid(apps: catalog.apps.filter {
                    ($0.scheduling?.isActiveNow ?? true) && $0.resolvedAccess.tags.contains(DeveloperShelf.appsTag)
                })
            case .scripts, .sdk:
                DownloadResourceGrid(resources: (catalog.downloadableResources + catalog.scriptResources + catalog.pdfResources)
                    .filter { ($0.scheduling?.isActiveNow ?? true) && $0.resolvedAccess.tags.contains(shelf.tag) })
            }
        case .myApps:
            MyAppsGrid()
        case .audio:
            AudioGrid(tracks: catalog.audioTracks.filter { $0.scheduling?.isActiveNow ?? true })
        case .download(let category):
            // PDF-urile stau intr-o cheie separata de catalog (vezi
            // Catalog.pdfResources) — nu se filtreaza din lista comuna.
            DownloadResourceGrid(resources: resourcesFor(category)
                .filter { $0.category == category && ($0.scheduling?.isActiveNow ?? true) })
        case .android:
            MobileAppPane()
        case .all, .none:
            CatalogGrid(items: allInstallableItems.filter { $0.scheduling?.isActiveNow ?? true })
        case .type(let type):
            // Scripturile vin din cheia LOR de catalog — vezi
            // Catalog.scriptItems pentru motivul retrocompatibilitatii.
            CatalogGrid(items: (type == .scripts ? catalog.scriptItems : catalog.items)
                .filter { $0.type == type && ($0.scheduling?.isActiveNow ?? true) })
        }
    }

    var body: some View {
        NavigationSplitView {
            // [2026-08-29, corectat] Profilul era atasat cu `.safeAreaInset`
            // DIRECT pe `List` — la redimensionare RAPIDA a ferestrei (tras
            // de colt), List-ul (un NSScrollView sub capota) nu-si recalcula
            // mereu la timp content-inset-ul fata de safe-area-ul suprapus,
            // asa ca profilul putea sa ramana temporar "suspendat" peste
            // ultimele randuri din sidebar in loc sa fie sub ele. Fix:
            // List si blocul de profil sunt acum FRATI intr-un VStack simplu
            // — layout-ul e calculat direct de VStack la fiecare cadru, fara
            // sa depinda de sincronizarea safe-area/scroll-inset a List-ului.
            VStack(spacing: 0) {
            List(selection: $selection) {
                // Grup 1: instalare AUTOMATĂ, exclusiv DaVinci Resolve
                // (Scripting API / foldere native Resolve). Separat vizual
                // explicit de grupul de mai jos — cerut de Cristi 2026-08-29:
                // "să nu se încurce lumea" cu resursele de download direct.
                Section(isExpanded: $expandResolveInstall) {
                    Label(L.t("sidebar.all"), systemImage: "square.grid.2x2")
                        .tag(SidebarSection.all)
                    ForEach(PluginType.allCases) { type in
                        Label {
                            Text(type.label)
                        } icon: {
                            Image(systemName: type.defaultSymbol).foregroundStyle(type.tintColor)
                        }
                        .tag(SidebarSection.type(type))
                    }
                } header: {
                    Text(L.t("sidebar.section.resolveInstall"))
                }

                // Grup 2: RESURSE DE DOWNLOAD DIRECT — Premiere Pro/Final Cut/
                // DaVinci Resolve, NU se instalează automat nicăieri (userul
                // descarcă și importă manual). Include Audio (deja exista) +
                // cele 4 categorii noi din Etapa 2 (2026-08-29).
                Section(isExpanded: $expandDownloadResources) {
                    Label {
                        Text(L.t("sidebar.audio"))
                    } icon: {
                        Image(systemName: "waveform").foregroundStyle(Color.indigo)
                    }
                    .tag(SidebarSection.audio)
                    ForEach(DownloadCategory.allCases) { category in
                        Label {
                            Text(L.t("sidebar.download.\(category.rawValue)"))
                        } icon: {
                            Image(systemName: category.defaultSymbol).foregroundStyle(category.tintColor)
                        }
                        .tag(SidebarSection.download(category))
                    }
                } header: {
                    Text(L.t("sidebar.section.downloadResources"))
                }

                // Grup 3: comunitate & educație — conținut informativ, fără
                // fișiere/instalare, doar link-uri externe (Cursuri/Materiale/
                // Evenimente) sau contact (Magazine/Service).
                Section(isExpanded: $expandCommunity) {
                    Label(L.t("sidebar.courses"), systemImage: "graduationcap")
                        .tag(SidebarSection.courses)
                    Label(L.t("sidebar.educationalResources"), systemImage: "book")
                        .tag(SidebarSection.educationalResources)
                    Label(L.t("sidebar.tutorials"), systemImage: "play.rectangle")
                        .tag(SidebarSection.tutorials)
                    Label(L.t("sidebar.events"), systemImage: "calendar")
                        .tag(SidebarSection.events)
                    // Etapa 4 (2026-08-29) — Oferte Parteneri.
                    Label(L.t("sidebar.partnerOffers"), systemImage: "tag")
                        .tag(SidebarSection.partnerOffers)
                    // Etapa 9 (2026-08-29) — Pachete/Bundle-uri.
                    Label(L.t("sidebar.bundles"), systemImage: "shippingbox")
                        .tag(SidebarSection.bundles)
                    Label(L.t("sidebar.partnerStores"), systemImage: "storefront")
                        .tag(SidebarSection.partnerStores)
                    Label(L.t("sidebar.serviceCenters"), systemImage: "wrench.and.screwdriver")
                        .tag(SidebarSection.serviceCenters)
                    // [2026-09-14] Hub de grupuri și canale de suport.
                    Label(L.t("sidebar.community"), systemImage: "person.2.wave.2")
                        .tag(SidebarSection.community)
                } header: {
                    Text(L.t("sidebar.section.community"))
                }

                // Grup 4: ecosistemul GDC — alte aplicații ale lui Cristi.
                Section(isExpanded: $expandEcosystem) {
                    Label(L.t("sidebar.apps"), systemImage: "app.badge")
                        .tag(SidebarSection.apps)
                    // Aplicatia mobila companion (PWA, gordas.dev/app.html —
                    // fost APK/TWA, retras 2026-08-24) — vezi AndroidPane.swift.
                    Label(L.t("sidebar.mobileApp"), systemImage: "iphone.gen3")
                        .tag(SidebarSection.android)
                    // Etapa 3 (2026-08-29) — lansator rapid, vezi MyAppsLauncher.swift.
                    Label(L.t("sidebar.myApps"), systemImage: "square.grid.3x1.folder.badge.plus")
                        .tag(SidebarSection.myApps)
                } header: {
                    Text(L.t("sidebar.section.ecosystem"))
                }

                // Grup 4b: DEVELOPER — unelte pentru dezvoltatori (GDC LUT Lab etc.).
                Section(isExpanded: $expandDeveloper) {
                    ForEach(DeveloperShelf.allCases, id: \.self) { shelf in
                        Label(L.t(shelf.titleKey), systemImage: shelf.symbol)
                            .tag(SidebarSection.developer(shelf))
                    }
                } header: {
                    Text(L.t("sidebar.section.developer"))
                }

                // Grup 5: contul tău — licență + ajutor, mereu ultimul.
                Section(isExpanded: $expandAccount) {
                    Label(L.t("sidebar.license"), systemImage: "key.fill")
                        .tag(SidebarSection.license)
                    Label(L.t("sidebar.help"), systemImage: "questionmark.circle")
                        .tag(SidebarSection.help)
                } header: {
                    Text(L.t("sidebar.section.account"))
                }
            }
            // Secțiunea care conține rubrica selectată se deschide singură.
            // Fără asta, o navigare venită din altă parte (butonul de licență,
            // o restaurare de selecție la pornire) ar lăsa lista pe o rubrică
            // invizibilă, într-o secțiune strânsă — ar părea că aplicația nu
            // a reacționat la click.
            .onChange(of: selection) { _, newValue in
                expandSection(containing: newValue)
            }
            .onAppear { expandSection(containing: selection) }
            // BUG REAL gasit 2026-08-26: navigationSplitViewColumnWidth(180)
            // (valoare unica) FIXEAZA latimea coloanei, nu o seteaza doar ca
            // implicita - sidebar-ul nu era deloc redimensionabil prin
            // tragere de mouse, desi NavigationSplitView suporta asta nativ.
            // Fix: supraincarcarea min/ideal/max, care lasa AppKit sa
            // deseneze diviziunea trasabila intre coloane.
            Divider()
            VStack(spacing: 6) {
                ProfileSidebarBlock()
                HStack(spacing: 6) {
                    Text("v\(appVersion)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    SidebarUpdateButton()
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 8)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 380)
        } detail: {
            // LaunchOfferBanner e FRATE cu conținutul scrollabil, nu
            // `.safeAreaInset` direct pe listă — vezi Regula 24
            // (CLAUDE.md): safeAreaInset atașat direct pe un List/ScrollView
            // nu se resincronizează mereu instant la resize rapid.
            VStack(spacing: 0) {
            VStack(spacing: 0) {
                if !missingDependencies.isEmpty {
                    DependencyBanner(missing: missingDependencies)
                }
                if let update = updateChecker.availableUpdate {
                    UpdateBanner(update: update)
                } else if updateChecker.checkFailed {
                    CheckFailedBanner()
                }
                // Bară de căutare GLOBALĂ (Etapa 1, extinsă 2026-08-29 —
                // cerut explicit: "trebuie să cuprindă tot ce există în
                // aplicație"). Vizibilă pe ORICE rubrică, indiferent de
                // secțiunea aleasă în sidebar — cât timp userul tastează
                // ceva, rezultatele unificate din TOATE categoriile
                // (Produse/Aplicații/Cursuri/Audio/Evenimente/Materiale/
                // Magazine/Service) înlocuiesc conținutul rubricii curente;
                // câmp gol → se revine exact la rubrica selectată, ca înainte.
                SearchBar(text: $globalSearchText, historyKey: "gdcpm_search_history_global",
                          liveSuggestions: globalSearchSuggestions)
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                if globalSearchText.trimmingCharacters(in: .whitespaces).isEmpty {
                    detailContent
                } else {
                    GlobalSearchResults(catalog: catalog, query: globalSearchText)
                }
            }
            // Etapa 6 (2026-08-29) — filigran sezonier. Clarificare
            // EXPLICITĂ de la Cristi: "nu neapărat numai banner... să
            // apară ca o imagine mai mare... ca și cum ar fi sculptat/
            // imprimat în fundal" — deci NU un icon mic suprapus, ci un
            // strat mare, discret, ÎN SPATELE conținutului (opacitate
            // mică, non-interactiv), nu deasupra lui.
            // Fără `alignment:` fix aici: fiecare filigran își poartă
            // propria poziție (2026-08-29) — vezi SeasonalBackgroundsLayer.
            .background { SeasonalBackgroundsLayer(configs: catalog.seasonalBackgrounds.activeNowDeduplicated) }
            LaunchOfferBanner()
            }
        }
        .navigationTitle(L.t("app.name"))
        .toolbar {
            ToolbarItem {
                DependencyBadge(dependencies: allDependencies, showPanel: $showDependencyPanel)
            }
            ToolbarItem {
                Button {
                    Task {
                        await catalog.refresh()
                        await updateChecker.check()
                    }
                } label: {
                    Label(L.t("catalog.refresh"), systemImage: "arrow.clockwise")
                }
            }
        }
        .environmentObject(catalog)
        .environmentObject(installs)
        .task {
            await catalog.refresh()
            await updateChecker.check()
            await license.refreshRevocations()
            allDependencies = SystemDependencyChecker.checkAll()
            missingDependencies = allDependencies.filter { !$0.isPresent && !$0.isOptional }
            if !UserDefaults.standard.bool(forKey: "gdcpm_onboarded") {
                showOnboarding = true
            }
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView(isPresented: $showOnboarding)
        }
        .sheet(isPresented: $showDependencyPanel) {
            DependencyPanel(isPresented: $showDependencyPanel, dependencies: allDependencies)
        }
        // "Check for Updates..." din meniul nativ (vezi GDCPluginManagerApp.swift)
        // — separat de check-ul automat de la lansare, mereu urmat de un
        // rezultat vizibil (pop-up nativ), niciodata silentios.
        .onReceive(NotificationCenter.default.publisher(for: .gdcCheckForUpdatesRequested)) { _ in
            Task {
                await updateChecker.check()
                // PITFALL FIXED 2026-08-26: citea availableUpdate (filtrat
                // de dismissal) — o versiune respinsa candva facea
                // verificarea manuala sa minta "esti la zi". latestInfo nu
                // e filtrat — vezi comentariul din UpdateChecker.swift.
                // [2026-09-03] Adaugat checkFailed: fara el, o verificare
                // esuata (retea/parsare) minea la fel "esti la zi" ca un
                // caz de succes real — vezi UpdateChecker.checkFailed.
                if updateChecker.checkFailed {
                    manualUpdateCheckMessage = L.t("update.check.failed")
                } else if let update = updateChecker.latestInfo {
                    manualUpdateCheckMessage = String(format: L.t("update.check.available"), update.version)
                } else {
                    manualUpdateCheckMessage = L.t("update.check.upToDate")
                }
                showManualUpdateCheckAlert = true
            }
        }
        .alert(L.t("update.check.title"), isPresented: $showManualUpdateCheckAlert) {
            Button(L.t("common.ok"), role: .cancel) {}
        } message: {
            Text(manualUpdateCheckMessage)
        }
        // Pop-up modal, pe langa bannerul din header (nu in locul lui):
        // bannerul e discret si poate fi ratat; pop-up-ul intrerupe o
        // singura data, la aparitia unei versiuni noi, si explica raspicat
        // ca nu e self-update automat — vezi WARNING din UpdateChecker.swift.
        // isPresented citeste `availableUpdate != nil` direct, deci apare
        // o singura data per versiune (UpdateChecker.dismiss() persista
        // versiunea inchisa in UserDefaults, la fel ca bannerul).
        .alert(
            L.t("update.popup.title"),
            isPresented: Binding(
                get: { updateChecker.availableUpdate != nil },
                set: { if !$0 { updateChecker.dismiss() } }
            ),
            presenting: updateChecker.availableUpdate
        ) { info in
            // "Actualizeaza acum" (Faza 4, vezi CLAUDE.md Partea 1 Regula 13):
            // deschide direct link-ul de descarcare (releases/latest/download/...)
            // — tot NU e self-update silentios (vezi WARNING din
            // UpdateChecker.swift), dar butonul e explicit denumit ca actiune
            // 1-click, nu doar "Descarca" generic. Inchide popup-ul dupa click
            // — userul si-a luat deja actiunea.
            // Nu mai deschide browserul — vezi SelfUpdater.swift. Nu mai
            // apelam dismiss() imediat: daca instalarea esueaza si userul
            // mai are nevoie sa vada popup-ul din nou, availableUpdate
            // ramane populat (SelfUpdater arata propria alerta de eroare).
            // Garda pe download_url pastrata ca inainte — butonul nu apare
            // deloc daca update.json n-are link pentru Mac.
            if !info.download_url.isEmpty {
                Button(L.t("update.popup.now")) {
                    Task { await SelfUpdater.downloadAndInstall(info: info) }
                }
            }
            // Update marcat mandatory (docs/update.json): fara "Mai tarziu"
            // — vezi UpdateChecker.dismiss(), nu se mai persista inchiderea
            // pentru mandatory, deci butonul ar fi oricum inutil aici.
            if info.mandatory != true {
                Button(L.t("update.popup.later"), role: .cancel) { updateChecker.dismiss() }
            }
        } message: { info in
            // Rezumatul modificarilor (Release Notes), din update.json
            // (`changes`) - camp optional, degradeaza elegant daca lipseste.
            if let changes = info.changes, !changes.isEmpty {
                Text(L.t("update.popup.message") + " (v\(info.version))\n\n" + L.t("update.popup.changes") + ":\n" + changes)
            } else {
                Text(L.t("update.popup.message") + " (v\(info.version))")
            }
        }
    }

}

/// [2026-09-03] Port 1:1 al bannerului de pe Windows — vezi
/// UpdateChecker.checkFailed. Aratat DOAR cand nu exista deja un
/// UpdateBanner normal de aratat (else-branch in body), ca sa nu se
/// suprapuna doua bannere de update.
private struct CheckFailedBanner: View {
    @ObservedObject private var updateChecker = UpdateChecker.shared

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            Text(L.t("update.check.failed"))
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button(L.t("update.check.openWebsite")) {
                NSWorkspace.shared.open(URL(string: "https://gordas.dev/")!)
            }
            Button(L.t("update.dismiss")) { updateChecker.dismissCheckFailedBanner() }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color.orange.opacity(0.10))
    }
}

private struct UpdateBanner: View {
    let update: UpdateInfo
    @ObservedObject private var updateChecker = UpdateChecker.shared

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.down.circle.fill").foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(L.t("update.title")).font(.subheadline).fontWeight(.semibold)
                Text("v\(update.version)" + (update.changes.map { " — \($0)" } ?? ""))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            // Nu mai deschide browserul — vezi SelfUpdater.swift.
            if !update.download_url.isEmpty {
                Button(L.t("update.download")) {
                    Task { await SelfUpdater.downloadAndInstall(info: update) }
                }
            }
            Button(L.t("update.dismiss")) { updateChecker.dismiss() }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color.accentColor.opacity(0.12))
    }
}

/// Banner de avertisment pentru dependinte de sistem lipsa (ex. DaVinci
/// Resolve neinstalat) — vezi SystemDependencyChecker. Status complet
/// (toate dependintele, nu doar cele lipsa) e in Preferences.
private struct DependencyBanner: View {
    let missing: [SystemDependency]

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(L.t("dependency.missing.title")).font(.subheadline).fontWeight(.semibold)
                Text(missing.map(\.name).joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            ForEach(missing) { dep in
                if let url = dep.downloadURL {
                    Button(String(format: L.t("dependency.install.button"), dep.name)) { NSWorkspace.shared.open(url) }
                }
            }
        }
        .padding(12)
        .background(Color.orange.opacity(0.12))
    }
}

/// [ÎNLOCUIT 2026-09-11] `PriceFilter`/`OSFilter` traiau aici si erau
/// copiate, cu propriul `@State` si propriile `Picker`-e, in fiecare
/// sectiune. Au fost unificate in `CatalogFilterBar.swift`
/// (`AccessPriceFilter`/`AccessOSFilter`/`CatalogFilterState`), care
/// filtreaza pe `ResolvedAccess` — deci regula „ce inseamna gratuit" e
/// aplicata o singura data, in Core, nu reinterpretata per sectiune.

/// Rezultate unificate ale căutării globale — combină toate cele 8
/// colecții din catalog, fiecare filtrată cu `FuzzySearch` pe câmpurile ei
/// relevante. O secțiune nu se afișează deloc dacă n-are niciun rezultat.
private struct GlobalSearchResults: View {
    @ObservedObject var catalog: CatalogService
    let query: String

    // Etapa 4 extinsă (2026-08-29): rezultatele de căutare respectă
    // valabilitatea temporală în TOATE colecțiile, nu doar Cursuri/
    // Evenimente/Materiale/Oferte — un produs/aplicație/resursă expirată
    // sau neînceput încă nu trebuie să apară nici prin căutare globală.
    private var matchedItems: [PluginItem] {
        (catalog.items + catalog.scriptItems).filter { ($0.scheduling?.isActiveNow ?? true) && FuzzySearch.matches(query: query, inAny: [$0.name, $0.description, $0.id, $0.type.label]) }
    }
    private var matchedApps: [AppLink] {
        catalog.apps.filter { ($0.scheduling?.isActiveNow ?? true) && FuzzySearch.matches(query: query, inAny: [$0.name, $0.id]) }
    }
    private var matchedCourses: [Course] {
        catalog.courses.filter { ($0.scheduling?.isActiveNow ?? true) && FuzzySearch.matches(query: query, inAny: [$0.name, $0.description, $0.id]) }
    }
    private var matchedAudio: [AudioTrack] {
        catalog.audioTracks.filter { ($0.scheduling?.isActiveNow ?? true) && FuzzySearch.matches(query: query, inAny: [$0.name, $0.description, $0.id]) }
    }
    private var matchedEvents: [Event] {
        catalog.events.filter { ($0.scheduling?.isActiveNow ?? true) && FuzzySearch.matches(query: query, inAny: [$0.title, $0.description, $0.location, $0.id]) }
    }
    private var matchedResources: [EducationalResource] {
        catalog.educationalResources.filter { ($0.scheduling?.isActiveNow ?? true) && FuzzySearch.matches(query: query, inAny: [$0.name, $0.description, $0.kind.label, $0.id]) }
    }
    private var matchedTutorials: [Tutorial] {
        catalog.tutorials.filter { ($0.scheduling?.isActiveNow ?? true) && FuzzySearch.matches(query: query, inAny: [$0.title, $0.description, $0.category, $0.id] + $0.tags) }
    }
    private var matchedOffers: [PartnerOffer] {
        catalog.partnerOffers.filter { ($0.scheduling?.isActiveNow ?? true) && FuzzySearch.matches(query: query, inAny: [$0.brandName, $0.description, $0.id, $0.couponCode]) }
    }
    private var matchedStores: [PartnerStore] {
        catalog.partnerStores.filter { ($0.scheduling?.isActiveNow ?? true) && FuzzySearch.matches(query: query, inAny: [$0.name, $0.description, $0.id]) }
    }
    private var matchedCenters: [ServiceCenter] {
        catalog.serviceCenters.filter { ($0.scheduling?.isActiveNow ?? true) && FuzzySearch.matches(query: query, inAny: [$0.name, $0.specialization, serviceCategoryLabel($0.category), $0.id]) }
    }
    private var matchedDownloads: [DownloadableResource] {
        (catalog.downloadableResources + catalog.pdfResources + catalog.scriptResources).filter { ($0.scheduling?.isActiveNow ?? true) && FuzzySearch.matches(query: query, inAny: [$0.name, $0.description, $0.id, $0.category.rawValue]) }
    }
    private var matchedBundles: [ProductBundle] {
        catalog.productBundles.filter { ($0.scheduling?.isActiveNow ?? true) && FuzzySearch.matches(query: query, inAny: [$0.name, $0.description, $0.id]) }
    }

    private var totalMatches: Int {
        matchedItems.count + matchedApps.count + matchedCourses.count + matchedAudio.count
            + matchedEvents.count + matchedResources.count + matchedTutorials.count + matchedStores.count + matchedCenters.count
            + matchedDownloads.count + matchedOffers.count + matchedBundles.count
    }

    private let productColumns = [GridItem(.adaptive(minimum: 240, maximum: 300), spacing: 14)]
    private let wideColumns = [GridItem(.adaptive(minimum: 260, maximum: 340), spacing: 14)]

    var body: some View {
        ScrollView {
            if totalMatches == 0 {
                Text(L.t("search.noResults")).foregroundStyle(.secondary).padding(40)
            } else {
                VStack(alignment: .leading, spacing: 20) {
                    section(title: L.t("sidebar.all"), isEmpty: matchedItems.isEmpty) {
                        LazyVGrid(columns: productColumns, spacing: 14) {
                            ForEach(matchedItems) { PluginCard(item: $0) }
                        }
                    }
                    section(title: L.t("sidebar.apps"), isEmpty: matchedApps.isEmpty) {
                        LazyVGrid(columns: wideColumns, spacing: 14) {
                            ForEach(matchedApps) { AppCard(app: $0) }
                        }
                    }
                    section(title: L.t("sidebar.audio"), isEmpty: matchedAudio.isEmpty) {
                        LazyVGrid(columns: wideColumns, spacing: 14) {
                            ForEach(matchedAudio) { AudioCard(track: $0) }
                        }
                    }
                    section(title: L.t("sidebar.courses"), isEmpty: matchedCourses.isEmpty) {
                        LazyVGrid(columns: wideColumns, spacing: 14) {
                            ForEach(matchedCourses) { CourseCard(course: $0) }
                        }
                    }
                    section(title: L.t("sidebar.educationalResources"), isEmpty: matchedResources.isEmpty) {
                        LazyVGrid(columns: wideColumns, spacing: 14) {
                            ForEach(matchedResources) { EducationalResourceCard(resource: $0) }
                        }
                    }
                    section(title: L.t("sidebar.tutorials"), isEmpty: matchedTutorials.isEmpty) {
                        LazyVGrid(columns: wideColumns, spacing: 14) {
                            ForEach(matchedTutorials) { TutorialCard(tutorial: $0) }
                        }
                    }
                    section(title: L.t("sidebar.events"), isEmpty: matchedEvents.isEmpty) {
                        LazyVGrid(columns: wideColumns, spacing: 14) {
                            ForEach(matchedEvents) { EventCard(event: $0) }
                        }
                    }
                    section(title: L.t("sidebar.partnerOffers"), isEmpty: matchedOffers.isEmpty) {
                        LazyVGrid(columns: wideColumns, spacing: 14) {
                            ForEach(matchedOffers) { PartnerOfferCard(offer: $0) }
                        }
                    }
                    section(title: L.t("sidebar.bundles"), isEmpty: matchedBundles.isEmpty) {
                        LazyVGrid(columns: wideColumns, spacing: 14) {
                            ForEach(matchedBundles) { BundleCard(bundle: $0, catalog: catalog) }
                        }
                    }
                    section(title: L.t("sidebar.partnerStores"), isEmpty: matchedStores.isEmpty) {
                        LazyVGrid(columns: wideColumns, spacing: 14) {
                            ForEach(matchedStores) { PartnerStoreCard(store: $0) }
                        }
                    }
                    section(title: L.t("sidebar.serviceCenters"), isEmpty: matchedCenters.isEmpty) {
                        LazyVGrid(columns: wideColumns, spacing: 14) {
                            ForEach(matchedCenters) { ServiceCenterCard(center: $0) }
                        }
                    }
                    ForEach(DownloadCategory.allCases) { category in
                        let matches = matchedDownloads.filter { $0.category == category }
                        section(title: L.t("sidebar.download.\(category.rawValue)"), isEmpty: matches.isEmpty) {
                            LazyVGrid(columns: wideColumns, spacing: 14) {
                                ForEach(matches) { DownloadResourceCard(resource: $0) }
                            }
                        }
                    }
                }
                .padding(16)
            }
        }
    }

    @ViewBuilder
    private func section<Content: View>(title: String, isEmpty: Bool, @ViewBuilder content: () -> Content) -> some View {
        if !isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(.headline).foregroundStyle(.secondary)
                content()
            }
        }
    }
}

private struct CatalogGrid: View {
    let items: [PluginItem]
    @EnvironmentObject private var catalog: CatalogService

    // Filtrele locale (priceFilter/osFilter, copiate si in celelalte
    // sectiuni) au fost inlocuite 2026-09-11 cu bara COMUNA — pentru
    // plugin-uri, `isFree`/`supportedOS` raman sursa de adevar, derivate
    // prin `resolvedAccess` (pasul 1 al precedentei), deci filtrarea da
    // exact aceleasi rezultate ca inainte, dar dintr-un singur loc.
    @StateObject private var filters = CatalogFilterState()

    // 240 (de la 220): cardul are acum și copertă, iar descrierea urcă la
    // 5 rânduri — sub 240 textul se rupe urât.
    private let columns = [GridItem(.adaptive(minimum: 240, maximum: 300), spacing: 14)]

    private var filteredItems: [PluginItem] { filters.filter(items) }

    var body: some View {
        VStack(spacing: 0) {
            if !items.isEmpty {
                CatalogFilterBar(
                    state: filters,
                    options: .product,
                    availableTags: CatalogFacets.tags(items),
                    availableGroups: CatalogFacets.groups(items)
                )
            }

            ScrollView {
                if catalog.isLoading && items.isEmpty {
                    ProgressView(L.t("catalog.loading")).padding(40)
                } else if let error = catalog.loadError, items.isEmpty {
                    Text(error).foregroundStyle(.secondary).padding(40)
                } else if items.isEmpty {
                    Text(L.t("catalog.empty")).foregroundStyle(.secondary).padding(40)
                } else if filteredItems.isEmpty {
                    Text(L.t("filter.price.empty")).foregroundStyle(.secondary).padding(40)
                } else {
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(filteredItems) { item in
                            PluginCard(item: item)
                        }
                    }
                    .padding(16)
                }
            }
        }
    }
}

/// Rând de iconițe pentru linkurile opționale ale unei resurse (Achiziție/
/// Demo/rețele sociale) — Etapa 2 (2026-08-29). Shared între `PluginCard`
/// și `DownloadResourceCard`, ca să nu dubleze aceeași logică. Nu se
/// randă deloc dacă niciun link nu e completat.
@ViewBuilder
func ExtraLinksRow(purchaseURL: String?, demoURL: String?, social: SocialLinks?) -> some View {
    let hasAny = purchaseURL != nil || demoURL != nil || !(social?.isEmpty ?? true)
    if hasAny {
        HStack(spacing: 10) {
            if let purchaseURL, let url = URL(string: purchaseURL) {
                LinkIconButton(systemImage: "cart", tooltip: L.t("card.purchaseLink"), url: url)
            }
            if let demoURL, let url = URL(string: demoURL) {
                LinkIconButton(systemImage: "play.circle", tooltip: L.t("card.demoLink"), url: url)
            }
            if let social {
                if let s = social.facebookURL, let url = URL(string: s) {
                    SocialIconButton(kind: .facebook, tooltip: L.t("social.facebook"), url: url)
                }
                if let s = social.youtubeURL, let url = URL(string: s) {
                    SocialIconButton(kind: .youtube, tooltip: L.t("social.youtube"), url: url)
                }
                if let s = social.instagramURL, let url = URL(string: s) {
                    SocialIconButton(kind: .instagram, tooltip: L.t("social.instagram"), url: url)
                }
                if let s = social.tiktokURL, let url = URL(string: s) {
                    SocialIconButton(kind: .tiktok, tooltip: L.t("social.tiktok"), url: url)
                }
                if let s = social.linkedinURL, let url = URL(string: s) {
                    SocialIconButton(kind: .linkedin, tooltip: L.t("social.linkedin"), url: url)
                }
            }
            Spacer()
        }
    }
}

/// Variantă doar-social a lui `ExtraLinksRow` — 2026-08-29, cerut explicit
/// ("rețelele sociale la toate rubricile", grupurile Comunitate & Educație
/// + Ecosistem GDC). NU dublează logica: e strict un wrapper peste
/// `ExtraLinksRow` pentru rubricile care nu au linkuri de achiziție/demo
/// (Cursuri, Materiale, Evenimente, Magazine, Service, Aplicații).
@ViewBuilder
func SocialLinksRow(_ social: SocialLinks?) -> some View {
    ExtraLinksRow(purchaseURL: nil, demoURL: nil, social: social)
}

private func LinkIconButton(systemImage: String, tooltip: String, url: URL) -> some View {
    Button {
        NSWorkspace.shared.open(url)
    } label: {
        Image(systemName: systemImage)
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
    }
    .buttonStyle(.plain)
    .help(tooltip)
}

/// Iconițe reale de brand, colorate (Facebook/YouTube/Instagram/TikTok/
/// LinkedIn) — 2026-08-29, cerut explicit ("SF Symbols alb-negru sunt greu
/// de identificat, vreau culorile oficiale de brand"). SF Symbols n-are
/// glife de brand pentru terți (Apple nu livrează logo-uri), deci desenăm
/// SVG-uri proprii, mici, cu paleta oficială — decodate prin `NSImage(data:)`,
/// aceeași tehnică deja verificată pe filigranul sezonier (`ImageIO` are
/// suport SVG pe macOS 12+, INCLUSIV gradienți liniari — verificat direct
/// cu un test izolat înainte de a alege această cale pentru Instagram).
// `SocialIconKind` a fost mutat în BrandIcon.swift (2026-09-14): îl
// folosesc acum două ecrane — cardurile de produs și secțiunea Comunitate.

private func SocialIconButton(kind: SocialIconKind, tooltip: String, url: URL) -> some View {
    Button {
        NSWorkspace.shared.open(url)
    } label: {
        Group {
            if let nsImage = NSImage(data: Data(kind.svg.utf8)) {
                Image(nsImage: nsImage).resizable().aspectRatio(contentMode: .fit)
            } else {
                // Fallback defensiv — n-ar trebui să se întâmple niciodată
                // (SVG-urile de mai sus sunt statice, testate), dar un card
                // nu trebuie să lase un gol/crash dacă decodarea eșuează.
                Image(systemName: "link.circle").foregroundStyle(.secondary)
            }
        }
        .frame(width: 16, height: 16)
    }
    .buttonStyle(.plain)
    .help(tooltip)
}

/// Buton compact "deschide în Google Maps" — Etapa 5 (2026-08-29). Nu se
/// randă deloc dacă `mapsURL` e nil (adresă lipsă/goală).
@ViewBuilder
func MapButton(mapsURL: URL?) -> some View {
    if let mapsURL {
        Button {
            NSWorkspace.shared.open(mapsURL)
        } label: {
            Label(L.t("maps.open"), systemImage: "map")
        }
        .controlSize(.small)
    }
}

/// Etichetă compactă tip "pill" — GRATUIT (verde) / LICENȚĂ (portocaliu) /
/// PROBĂ (albastru). Un fundal plin + text alb, nu doar text colorat, ca
/// sa citeasca clar ca un badge, nu ca o simpla nota de pret.
/// Ceas live opțional pentru conținut cu ofertă cu termen (2026-08-31,
/// cerut explicit de Cristi - vezi `Scheduling.showCountdown`/`countdownText`).
/// Nu arată nimic dacă nu se aplică (countdown dezactivat de Furnizor, fără
/// termen, sau expirat) - `Group` gol nu ocupă spațiu în layout.
/// Se auto-actualizează la 60s - suficient pentru "live" fără cost UI de
/// a reface un `Text` in fiecare card la fiecare secundă.
/// Buton vizibil în sidebar, lângă versiune: „Caută actualizări” când nu e
/// nimic nou, ecuson verde „Actualizare disponibilă vX” când există — la
/// apăsare pornește direct Self-Updater-ul (fără meniul din bara de sus).
private struct SidebarUpdateButton: View {
    @ObservedObject private var updateChecker = UpdateChecker.shared
    @State private var isChecking = false

    var body: some View {
        if let info = updateChecker.availableUpdate, !info.download_url.isEmpty {
            Button {
                Task { await SelfUpdater.downloadAndInstall(info: info) }
            } label: {
                Label("\(L.t("update.popup.title")) v\(info.version)", systemImage: "arrow.down.circle.fill")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(Color.green))
            }
            .buttonStyle(.plain)
            .help(L.t("update.popup.now"))
        } else {
            Button {
                isChecking = true
                NotificationCenter.default.post(name: .gdcCheckForUpdatesRequested, object: nil)
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { isChecking = false }
            } label: {
                if isChecking {
                    ProgressView().controlSize(.mini)
                } else {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 11, weight: .semibold))
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help(L.t("menu.checkForUpdates"))
        }
    }
}

private struct CountdownBadge: View {
    let scheduling: Scheduling?
    @State private var text: String?
    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            if let text {
                BadgePill(text: text, color: .orange)
            }
        }
        .onAppear { text = scheduling?.countdownText }
        .onReceive(timer) { _ in text = scheduling?.countdownText }
    }
}

private struct BadgePill: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color)
            .clipShape(Capsule())
    }
}

private struct PluginCard: View {
    let item: PluginItem
    @EnvironmentObject private var installs: InstallManager
    @ObservedObject private var license = LicenseManager.shared

    @State private var isBusy = false
    @State private var errorMessage: String?
    @State private var statusMessage: String?
    /// Caile REALE unde a ajuns produsul, verificate dupa instalare.
    @State private var installedPaths: [URL] = []
    @State private var showResolveWarning = false
    /// Eșec de instalare pentru o resursă PLĂTITĂ (vezi InstallError.
    /// paidResourceInstallFailed / InstallManager.swift) — mesaj generic +
    /// buton WhatsApp în loc de fișiere/instrucțiuni de instalare manuală.
    @State private var showPaidResourceSupportError = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                typeBadge
                // Badge vizibil pentru TOATE cele 3 stari, inclusiv
                // crossPlatform (2026-08-25, cerere explicita: "Ambele"
                // trebuie sa se vada, nu doar sa fie absenta unui badge —
                // decizia anterioara de a-l ascunde pentru starea implicita
                // a fost o presupunere gresita despre asteptarile UX).
                // SF Symbols vectoriale, nu emoji color (2026-08-29, cerut
                // explicit — "impecabil, profesionist") — chip circular
                // discret, ton neutru, la fel ca stilul de badge din
                // `typeBadge` de mai jos.
                Image(systemName: item.supportedOS.badgeSymbol)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(Color.secondary.opacity(0.12)))
                    .help(osBadgeTooltip)
            }
            // Coperta produsului (preset .icon, pătrat 512×512). Dacă
            // produsul n-are una, cade pe simbolul SF — cardul păstrează
            // aceeași înălțime, deci grila rămâne aliniată.
            CoverThumbnail(
                url: item.coverImageURL,
                fallbackSymbol: item.iconSymbol ?? item.type.defaultSymbol,
                tint: item.type.tintColor,
                height: 128,
                lightboxTitle: item.name
            )
            .frame(height: 128)
            .clipped()
            .overlay(alignment: .topTrailing) { priceBadges.padding(6) }
            .overlay(alignment: .topLeading) { CountdownBadge(scheduling: item.scheduling).padding(6) }
            Text(item.name)
                .font(.system(.headline, design: .rounded))
                .lineLimit(1)
            Text(item.description)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, minHeight: 30, alignment: .topLeading)
                .help(item.description)
            HStack(spacing: 6) {
                Text("\(L.t("card.version")) \(item.version)")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.tertiary)
                Spacer(minLength: 0)
                infoButton
            }
            extraLinksRow

            if let errorMessage {
                Text(errorMessage).font(.caption2).foregroundStyle(.red)
                    .lineLimit(1).help(errorMessage)
            }
            if let statusMessage {
                Text(statusMessage).font(.caption2).foregroundStyle(.blue)
                    .lineLimit(1).help(statusMessage)
                if let first = installedPaths.first {
                    Button(L.t("install.revealInFinder")) {
                        NSWorkspace.shared.activateFileViewerSelecting([first])
                    }
                    .buttonStyle(.link)
                    .font(.caption2)
                }
            }
            if showPaidResourceSupportError {
                Button {
                    NSWorkspace.shared.open(supportContactURL)
                } label: {
                    Label(L.t("install.contact.support"), systemImage: "message.fill")
                        .font(.caption2)
                        .lineLimit(1)
                }
                .buttonStyle(.bordered)
                .tint(.green)
            }

            Spacer(minLength: 0)
            actionButton
                .frame(height: 28)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: cardHeight, maxHeight: cardHeight, alignment: .topLeading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.2), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 4)
        .alert(resolveWarningTitle, isPresented: $showResolveWarning) {
            Button(L.t("resolve.running.ok")) {}
        } message: {
            Text(resolveWarningBody)
        }
    }

    /// Înălțime fixă pentru TOATE cardurile din grilă: butonul de jos cade
    /// pe aceeași linie indiferent de descriere/preț/mesaje.
    private let cardHeight: CGFloat = 340

    /// Ecusoane uniforme, colț dreapta-sus al imaginii: stare (GRATUIT /
    /// TRIAL / LICENȚĂ / PROMO) + suma de susținere, dacă e cazul.
    @ViewBuilder
    private var priceBadges: some View {
        VStack(alignment: .trailing, spacing: 4) {
            if item.isFree && item.isTrial {
                BadgePill(text: L.t("card.trial"), color: .blue)
            } else if item.isFree {
                BadgePill(text: L.t("card.free"), color: .green)
            } else {
                if item.isPromoActive {
                    BadgePill(text: L.t("card.promo"), color: .red)
                } else {
                    BadgePill(text: L.t("card.paid"), color: .orange)
                        .help(L.t("card.trustMessage"))
                }
                HStack(spacing: 4) {
                    if item.isPromoActive {
                        Text(item.priceDisplay).strikethrough().foregroundStyle(.secondary)
                    }
                    Text(item.effectivePriceEUR.formatted(.currency(code: "EUR")))
                        .fontWeight(.semibold)
                }
                .font(.system(size: 10, design: .rounded))
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(.ultraThinMaterial, in: Capsule())
            }
        }
    }

    private var extraLinksRow: some View {
        ExtraLinksRow(purchaseURL: item.purchaseURL, demoURL: item.demoURL, social: item.socialLinks)
    }

    /// Centered tag at the top of the card naming the product's type
    /// (LUT / DCTL / Fuse / PowerGrade / OFX) — a quick, consistent way
    /// to tell categories apart in a mixed grid.
    private var typeBadge: some View {
        Text(item.type.label.uppercased())
            .font(.system(size: 9, weight: .bold))
            .tracking(0.5)
            .foregroundStyle(item.type.tintColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(item.type.tintColor.opacity(0.15)))
            .frame(maxWidth: .infinity, alignment: .center)
    }

    /// Tutorial link, editable anytime from Furnizor without touching the
    /// product's files — hidden entirely (not disabled) until one exists,
    /// so a not-yet-recorded tutorial doesn't clutter every card.
    @ViewBuilder
    private var infoButton: some View {
        if let urlString = item.youtubeURL, let url = URL(string: urlString) {
            Button { NSWorkspace.shared.open(url) } label: {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help(L.t("card.youtubeLink"))
            .help(L.t("card.tutorial"))
        }
    }

    private var osBadgeTooltip: String {
        switch item.supportedOS {
        case .macOS: return "Doar macOS"
        case .windows: return "Doar Windows"
        case .crossPlatform: return "Compatibil Mac + Windows"
        }
    }

    private var resolveWarningTitle: String {
        item.type == .powerGrade ? L.t("resolve.notrunning.title") : L.t("resolve.running.title")
    }

    private var resolveWarningBody: String {
        item.type == .powerGrade ? L.t("resolve.notrunning.body") : L.t("resolve.running.body")
    }

    @ViewBuilder
    private var actionButton: some View {
        if !item.supportedOS.allows(current: .current) {
            Text(L.t("card.incompatibleOS"))
                .font(.caption)
                .foregroundStyle(.red)
        } else if !license.isUnlocked(for: item) {
            Button(L.t("card.buy")) { NSWorkspace.shared.open(buyURL) }
        } else if isBusy {
            ProgressView().controlSize(.small)
        } else if installs.hasUpdate(item) {
            HStack {
                Button(L.t("card.update")) { runGuarded { install() } }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                Button(L.t("card.remove"), role: .destructive) { runGuarded { remove() } }
            }
        } else if installs.isInstalled(item) {
            HStack {
                Label(L.t("card.installed"), systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
                Spacer()
                Button(L.t("card.remove"), role: .destructive) { runGuarded { remove() } }
            }
        } else {
            Button(L.t("card.install")) { runGuarded { install() } }
        }
    }

    private var buyURL: URL {
        // Suma promoțională activă (dacă e cazul) — vezi effectivePriceEUR.
        let priceText = item.effectivePriceEUR.formatted(.currency(code: "EUR"))
        let text = "Salut! Vreau să deblochez \(item.name) cu o donație de \(priceText). ID calculator: \(MachineID.display)"
        return WhatsAppLink.url(text: text)
    }

    private var supportContactURL: URL {
        let text = "Salut! A apărut o eroare la instalarea \(item.name) — mă poți ajuta să o instalez manual? ID calculator: \(MachineID.display)"
        return WhatsAppLink.url(text: text)
    }

    private func runGuarded(_ action: @escaping () -> Void) {
        // Every other type must be closed (it only reads its plugin
        // folder at launch); PowerGrade is the opposite — it needs a
        // running, scriptable Resolve to import into (see
        // PowerGradeImporter.swift). Without Resolve running, the action
        // still proceeds for PowerGrade — it just falls back to staging
        // the files with a manual-import message instead of failing.
        if item.type != .powerGrade && ResolveProcessCheck.isRunning {
            showResolveWarning = true
            return
        }
        if item.type == .powerGrade && !ResolveProcessCheck.isRunning {
            showResolveWarning = true
        }
        action()
    }

    private func install() {
        errorMessage = nil
        statusMessage = nil
        installedPaths = []
        showPaidResourceSupportError = false
        isBusy = true
        Task {
            do {
                let outcome = try await installs.install(item)
                AnalyticsClient.logDownload(productID: item.id, productName: item.name)
                switch outcome {
                case .installedToGallery(let albumName):
                    statusMessage = String(format: L.t("powergrade.imported"), albumName)
                case .installedNeedsManualStep(let folder):
                    statusMessage = String(format: L.t("powergrade.manualstep"), folder.path)
                case .installed(let paths):
                    // [2026-09-14] Pana acum o instalare reusita nu spunea
                    // NIMIC. Acum arata unde a ajuns efectiv fisierul, verificat
                    // pe disc, si ofera un buton care il deschide in Finder.
                    // OFX: clientul nu vede folderul și nu are „Arată în Finder” (cerință explicită) — doar „Instalat”.
                    installedPaths = item.type == .ofx ? [] : paths
                    if item.type == .ofx {
                        statusMessage = L.t("install.doneShort")
                    } else if let first = paths.first {
                        let folder = first.deletingLastPathComponent().path
                            .replacingOccurrences(of: NSHomeDirectory(), with: "~")
                        statusMessage = String(format: L.t("install.done"), folder)
                    } else {
                        statusMessage = L.t("install.doneShort")
                    }
                }
            } catch InstallError.paidResourceInstallFailed {
                // Mesaj generic, fără cale de fișier/instrucțiuni — vezi
                // InstallManager.swift. Butonul de contact apare separat,
                // mai jos în card (showPaidResourceSupportError).
                errorMessage = L.t("install.paidresource.error")
                showPaidResourceSupportError = true
            } catch {
                errorMessage = error.localizedDescription
            }
            isBusy = false
        }
    }

    private func remove() {
        errorMessage = nil
        statusMessage = nil
        showPaidResourceSupportError = false
        do {
            let outcome = try installs.remove(item)
            if item.type == .powerGrade, outcome == .removedNeedsManualGalleryCleanup {
                statusMessage = L.t("powergrade.manualremove")
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct CoursesGrid: View {
    let courses: [Course]

    // Mai lat decât înainte (260→300): cardurile au acum copertă și
    // descrierea se vede întreagă, deci au nevoie de spațiu ca să nu se
    // înghesuie textul pe rânduri de 3 cuvinte.
    private let columns = [GridItem(.adaptive(minimum: 300, maximum: 400), spacing: 16)]

    var body: some View {
        // Bara de filtre comuna (2026-09-11) — shadowing pe `courses`,
        // deci corpul de mai jos ramane neschimbat, dar primeste lista
        // deja filtrata. Vezi CatalogFilterBar.swift.
        FilteredCatalogSection(items: courses, options: .content) { courses in
        ScrollView {
            if courses.isEmpty {
                Text(L.t("courses.empty")).foregroundStyle(.secondary).padding(40)
            } else {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(courses) { course in
                        CourseCard(course: course)
                    }
                }
                .padding(16)
            }
        }
        }
    }
}

private struct CourseCard: View {
    let course: Course

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            CoverThumbnail(
                url: course.coverImageURL,
                fallbackSymbol: "graduationcap.fill",
                tint: .accentColor,
                height: 150,
                lightboxTitle: course.name
            )
            HStack(alignment: .top, spacing: 6) {
                Text(course.name).font(.headline)
                Spacer(minLength: 4)
                BadgePill(text: L.t(accessTypeKey), color: accessTypeColor)
            }
            HStack(spacing: 8) {
                CountdownBadge(scheduling: course.scheduling)
                if let formatLabel = course.formatLabel, !formatLabel.trimmingCharacters(in: .whitespaces).isEmpty {
                    Label(formatLabel, systemImage: "clock").font(.caption2).foregroundStyle(.secondary)
                }
            }
            Text(validityText).font(.caption2).foregroundStyle(.secondary)
            CollapsibleDescription(text: course.description)

            if let accessLink = course.accessLink,
               !accessLink.trimmingCharacters(in: .whitespaces).isEmpty,
               let url = URL(string: accessLink) {
                Button {
                    NSWorkspace.shared.open(url)
                } label: {
                    Label(L.t("courses.access.link"), systemImage: "link")
                }
                .controlSize(.small)
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(course.options) { option in
                    HStack {
                        Text(option.label).font(.caption)
                        Spacer()
                        Text(option.priceDisplay).font(.caption).foregroundStyle(.secondary)
                        Button(L.t("courses.contact")) { NSWorkspace.shared.open(contactURL(for: option)) }
                            .controlSize(.small)
                    }
                }
            }
            SocialLinksRow(course.socialLinks)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCardBackground()
    }

    private var accessTypeKey: String { "courses.access.\(course.accessType.rawValue)" }

    private var accessTypeColor: Color {
        switch course.accessType {
        case .free: return .green
        case .oneTime: return .accentColor
        case .subscription: return .purple
        case .liveMentoring: return .orange
        }
    }

    private var validityText: String {
        switch course.validity {
        case .lifetime: return L.t("courses.validity.lifetime")
        case .days(let d): return String(format: L.t("courses.validity.days"), d)
        }
    }

    private func contactURL(for option: CourseOption) -> URL {
        let text = String(format: L.t("courses.contact.message"), course.name, option.label, option.priceDisplay)
        return WhatsAppLink.url(text: text)
    }
}

/// Secțiunea "Tutoriale" — cerință directă (2026-09-01): căutare + grupare
/// pe categorie (liberă, aleasă de Furnizor) + carduri compacte în grilă
/// largă (nu listă lungă), cu descriere expandabilă la cerere.
private struct TutorialsGrid: View {
    let tutorials: [Tutorial]
    @State private var searchText = ""
    @State private var selectedCategory: String?

    private var categories: [String] {
        Array(Set(tutorials.map(\.category))).sorted()
    }

    private var filtered: [Tutorial] {
        tutorials.filter { tutorial in
            let matchesCategory = selectedCategory == nil || tutorial.category == selectedCategory
            let matchesSearch = searchText.isEmpty
                || FuzzySearch.matches(query: searchText, inAny: [tutorial.title, tutorial.description, tutorial.category] + tutorial.tags)
            return matchesCategory && matchesSearch
        }
    }

    private let columns = [GridItem(.adaptive(minimum: 280, maximum: 340), spacing: 16)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField(L.t("tutorials.search"), text: $searchText)
                        .textFieldStyle(.plain)
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: { Image(systemName: "xmark.circle.fill") }
                            .buttonStyle(.plain).foregroundStyle(.secondary)
                    }
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8).fill(.background.secondary))

                if categories.count > 1 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            categoryChip(nil, label: L.t("tutorials.allCategories"))
                            ForEach(categories, id: \.self) { cat in categoryChip(cat, label: cat) }
                        }
                    }
                }

                if filtered.isEmpty {
                    Text(L.t("search.noResults")).foregroundStyle(.secondary).padding(40)
                } else {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(filtered) { TutorialCard(tutorial: $0) }
                    }
                }
            }
            .padding(24)
        }
    }

    @ViewBuilder
    private func categoryChip(_ value: String?, label: String) -> some View {
        Button {
            selectedCategory = value
        } label: {
            Text(label).font(.caption).fontWeight(selectedCategory == value ? .bold : .regular)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Capsule().fill(selectedCategory == value ? Color.accentColor.opacity(0.3) : Color.gray.opacity(0.15)))
        }
        .buttonStyle(.plain)
    }
}

private struct TutorialCard: View {
    let tutorial: Tutorial
    @State private var showTags = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                if let url = tutorial.thumbnail {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().aspectRatio(16/9, contentMode: .fill)
                        } else {
                            Rectangle().fill(Color.gray.opacity(0.2))
                        }
                    }
                } else {
                    Rectangle().fill(Color.gray.opacity(0.2))
                }
                if let watch = tutorial.watchURL {
                    Button { NSWorkspace.shared.open(watch) } label: {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 34))
                            .foregroundStyle(.white)
                            .shadow(radius: 4)
                    }
                    .buttonStyle(.plain)
                    .help(L.t("card.youtubeLink"))
                }
            }
            .frame(height: 160)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .clipped()

            HStack {
                Text(tutorial.category).font(.caption2).fontWeight(.semibold)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(.tint.opacity(0.18)))
                Spacer()
                CountdownBadge(scheduling: tutorial.scheduling)
            }

            Text(tutorial.title).font(.headline).lineLimit(2)

            if !tutorial.tags.isEmpty {
                DisclosureGroup(isExpanded: $showTags) {
                    FlowLayout(spacing: 6) {
                        ForEach(tutorial.tags, id: \.self) { tag in
                            Text(tag).font(.caption2).foregroundStyle(.secondary)
                                .padding(.horizontal, 7).padding(.vertical, 2)
                                .background(Capsule().fill(Color.gray.opacity(0.15)))
                        }
                    }
                    .padding(.top, 4)
                } label: {
                    Text(String(format: L.t("tutorials.showTags"), tutorial.tags.count)).font(.caption).foregroundStyle(.secondary)
                }
            }

            CollapsibleDescription(text: tutorial.description)
        }
        .padding(12)
        .glassCardBackground()
    }
}

/// Layout simplu de tip "flow" (wrap la lățime) pentru chip-uri de taguri —
/// spre deosebire de un HStack, nu taie/ascunde tagurile care nu încap pe
/// un singur rând, le trece pe rândul următor.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0, rowHeight: CGFloat = 0, totalHeight: CGFloat = 0, totalWidth: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth, rowWidth > 0 {
                totalHeight += rowHeight + spacing
                totalWidth = max(totalWidth, rowWidth)
                rowWidth = 0; rowHeight = 0
            }
            rowWidth += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        totalHeight += rowHeight
        totalWidth = max(totalWidth, rowWidth)
        return CGSize(width: min(totalWidth, maxWidth), height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

/// Descriere colapsabilă, reutilizabilă în ORICE card din catalog —
/// cerință directă (2026-09-01): "la tot unde am tema de descriere ...
/// să se poată desfășura", generalizarea disclosure-ului deja făcut la
/// Tutoriale peste toate celelalte 8 tipuri de card (Produse/Cursuri/
/// Materiale/Evenimente/Pachete/Oferte/Magazine/Resurse Download/Audio).
/// Colapsat implicit — text ascuns complet, doar eticheta "Descriere" —
/// apasă săgeata ca să se desfacă. Nimic randat dacă textul e gol.
private struct CollapsibleDescription: View {
    let text: String
    @State private var expanded = false

    var body: some View {
        if !text.isEmpty {
            DisclosureGroup(isExpanded: $expanded) {
                Text(text)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            } label: {
                Text(L.t("card.showDescription")).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

private struct EducationalResourcesGrid: View {
    let resources: [EducationalResource]

    // Mai lat decât înainte (260→300): cardurile au acum copertă și
    // descrierea se vede întreagă, deci au nevoie de spațiu ca să nu se
    // înghesuie textul pe rânduri de 3 cuvinte.
    private let columns = [GridItem(.adaptive(minimum: 300, maximum: 400), spacing: 16)]

    var body: some View {
        // Bara de filtre comuna (2026-09-11) — shadowing pe `resources`,
        // deci corpul de mai jos ramane neschimbat, dar primeste lista
        // deja filtrata. Vezi CatalogFilterBar.swift.
        FilteredCatalogSection(items: resources, options: .content) { resources in
        ScrollView {
            if resources.isEmpty {
                Text(L.t("resources.empty")).foregroundStyle(.secondary).padding(40)
            } else {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(resources) { resource in
                        EducationalResourceCard(resource: resource)
                    }
                }
                .padding(16)
            }
        }
        }
    }
}

private struct EducationalResourceCard: View {
    let resource: EducationalResource

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            CoverThumbnail(
                url: resource.coverImageURL,
                fallbackSymbol: "book.fill",
                tint: .accentColor,
                height: 170,
                lightboxTitle: resource.name
            )
            HStack {
                Spacer()
                Text(resource.kind.label)
                    .font(.caption2).fontWeight(.semibold)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(.tint.opacity(0.18)))
                if let urlString = resource.youtubeURL, let url = URL(string: urlString) {
                    Button { NSWorkspace.shared.open(url) } label: {
                        Image(systemName: "play.circle")
                    }
                    .buttonStyle(.plain)
                    .help(L.t("card.youtubeLink"))
                }
            }
            Text(resource.name).font(.headline)
            CountdownBadge(scheduling: resource.scheduling)
            CollapsibleDescription(text: resource.description)
            Spacer(minLength: 0)
            if let url = URL(string: resource.externalURL) {
                Button(L.t("resources.buy")) { NSWorkspace.shared.open(url) }
                    .controlSize(.small)
            }
            SocialLinksRow(resource.socialLinks)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 200, alignment: .leading)
        .glassCardBackground()
    }
}

private struct EventsGrid: View {
    let events: [Event]

    // Mai lat decât înainte (260→300): cardurile au acum copertă și
    // descrierea se vede întreagă, deci au nevoie de spațiu ca să nu se
    // înghesuie textul pe rânduri de 3 cuvinte.
    private let columns = [GridItem(.adaptive(minimum: 300, maximum: 400), spacing: 16)]

    var body: some View {
        // Bara de filtre comuna (2026-09-11) — shadowing pe `events`,
        // deci corpul de mai jos ramane neschimbat, dar primeste lista
        // deja filtrata. Vezi CatalogFilterBar.swift.
        FilteredCatalogSection(items: events, options: .content) { events in
        ScrollView {
            if events.isEmpty {
                Text(L.t("events.empty")).foregroundStyle(.secondary).padding(40)
            } else {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(events) { event in
                        EventCard(event: event)
                    }
                }
                .padding(16)
            }
        }
        }
    }
}

private struct EventCard: View {
    let event: Event

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Afișul evenimentului. Mai înalt decât la restul cardurilor:
            // afișul chiar poartă informație (dată, program, invitați), deci
            // merită spațiu — și e cazul în care lightbox-ul contează cel
            // mai mult.
            CoverThumbnail(
                url: event.coverImageURL,
                fallbackSymbol: "calendar",
                tint: .accentColor,
                height: 190,
                lightboxTitle: event.title
            )
            HStack {
                Spacer()
                if let urlString = event.youtubeURL, let url = URL(string: urlString) {
                    Button { NSWorkspace.shared.open(url) } label: {
                        Image(systemName: "play.circle")
                    }
                    .buttonStyle(.plain)
                    .help(L.t("card.youtubeLink"))
                }
            }
            Text(event.title).font(.headline)
            CountdownBadge(scheduling: event.scheduling)
            HStack(spacing: 6) {
                Text("\(event.dateDisplay) · \(event.location)")
                    .font(.caption).foregroundStyle(.secondary)
                MapButton(mapsURL: event.mapsURL)
            }
            // Multi-Locație (2026-09-05) — locații/perioade/prețuri
            // suplimentare, câte un rând per ocurență. Un eveniment fără
            // nicio ocurență suplimentară arată identic ca înainte.
            ForEach(event.occurrences) { occurrence in
                HStack(spacing: 6) {
                    Text([occurrence.dateDisplay, occurrence.location]
                        .filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.caption).foregroundStyle(.secondary)
                    MapButton(mapsURL: occurrence.mapsURL)
                    if let priceDisplay = occurrence.priceDisplay {
                        Text(priceDisplay)
                            .font(.caption2).fontWeight(.medium)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(.background.tertiary))
                    }
                }
            }
            CollapsibleDescription(text: event.description)
            Spacer(minLength: 0)
            if let url = URL(string: event.externalURL) {
                Button(L.t("events.details")) { NSWorkspace.shared.open(url) }
                    .controlSize(.small)
            }
            SocialLinksRow(event.socialLinks)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 220, alignment: .leading)
        .glassCardBackground()
    }
}

/// Grid pentru Oferte Parteneri — Etapa 4 (2026-08-29). Discount afișat ca
/// badge grafic pe card, generat automat din `discountText` (dacă e setat).
/// Grid pentru Pachete/Bundle-uri — Etapa 9 (2026-08-29). Fiecare card
/// listează produsele incluse (rezolvate din catalog după `BundleItemRef`),
/// suma individuală tăiată + prețul total al pachetului, buton WhatsApp
/// (achiziția, ca la orice produs — licențele individuale rămân un pas
/// manual separat al Furnizorului, neschimbat).
private struct BundleGrid: View {
    let bundles: [ProductBundle]
    @ObservedObject var catalog: CatalogService

    private let columns = [GridItem(.adaptive(minimum: 300, maximum: 400), spacing: 16)]

    var body: some View {
        // Bara de filtre comuna (2026-09-11) — shadowing pe `bundles`,
        // deci corpul de mai jos ramane neschimbat, dar primeste lista
        // deja filtrata. Vezi CatalogFilterBar.swift.
        FilteredCatalogSection(items: bundles, options: .content) { bundles in
        ScrollView {
            if bundles.isEmpty {
                Text(L.t("bundles.empty")).foregroundStyle(.secondary).padding(40)
            } else {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(bundles) { bundle in
                        BundleCard(bundle: bundle, catalog: catalog)
                    }
                }
                .padding(16)
            }
        }
        }
    }
}

private struct BundleCard: View {
    let bundle: ProductBundle
    @ObservedObject var catalog: CatalogService

    /// Nume + preț individual pentru fiecare produs inclus, rezolvate
    /// după tip (produs/resursă download/curs) — un ID care nu se mai
    /// găsește (produs șters ulterior) e omis silențios, nu crapă cardul.
    private var resolvedItems: [(name: String, priceEUR: Double?)] {
        bundle.items.compactMap { ref in
            switch ref.kind {
            case .product:
                guard let item = (catalog.items + catalog.scriptItems).first(where: { $0.id == ref.id }) else { return nil }
                return (item.name, item.priceEUR)
            case .download:
                guard let resource = (catalog.downloadableResources + catalog.pdfResources).first(where: { $0.id == ref.id }) else { return nil }
                return (resource.name, resource.priceEUR)
            case .course:
                guard let course = catalog.courses.first(where: { $0.id == ref.id }) else { return nil }
                return (course.name, nil)
            case .audio:
                guard let track = catalog.audioTracks.first(where: { $0.id == ref.id }) else { return nil }
                return (track.name, nil)
            case .app:
                guard let app = catalog.apps.first(where: { $0.id == ref.id }) else { return nil }
                return (app.name, nil)
            case .material:
                guard let resource = catalog.educationalResources.first(where: { $0.id == ref.id }) else { return nil }
                return (resource.name, nil)
            }
        }
    }

    private var individualTotal: Double {
        resolvedItems.compactMap(\.priceEUR).reduce(0, +)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            CoverThumbnail(
                url: bundle.coverImageURL,
                fallbackSymbol: "shippingbox.fill",
                tint: .purple,
                height: 130,
                lightboxTitle: bundle.name
            )
            Text(bundle.name).font(.headline)
            CountdownBadge(scheduling: bundle.scheduling)
            CollapsibleDescription(text: bundle.description)

            VStack(alignment: .leading, spacing: 3) {
                Text(L.t("bundles.includes")).font(.caption2).foregroundStyle(.secondary)
                ForEach(resolvedItems, id: \.name) { entry in
                    Text("• \(entry.name)").font(.caption2).foregroundStyle(.secondary)
                }
            }

            HStack(alignment: .lastTextBaseline, spacing: 8) {
                if individualTotal > bundle.bundlePriceEUR {
                    Text(individualTotal.formatted(.currency(code: "EUR")))
                        .font(.caption)
                        .strikethrough()
                        .foregroundStyle(.tertiary)
                }
                Text(bundle.bundlePriceDisplay)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.orange)
            }

            ExtraLinksRow(purchaseURL: nil, demoURL: nil, social: bundle.socialLinks)
            Button(L.t("bundles.buy")) { NSWorkspace.shared.open(buyURL) }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCardBackground()
        .overlay(alignment: .topTrailing) {
            if let urlString = bundle.youtubeURL, let url = URL(string: urlString) {
                Button { NSWorkspace.shared.open(url) } label: {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                        .background(Circle().fill(.background).frame(width: 16, height: 16))
                }
                .buttonStyle(.plain)
                .help(L.t("card.youtubeLink"))
                .padding(8)
                .help(L.t("card.tutorial"))
            }
        }
    }

    private var buyURL: URL {
        let itemsList = resolvedItems.map(\.name).joined(separator: ", ")
        let text = "Salut! Vreau să cumpăr pachetul „\(bundle.name)” (\(itemsList)) la \(bundle.bundlePriceDisplay). ID calculator: \(MachineID.display)"
        return WhatsAppLink.url(text: text)
    }
}

private struct PartnerOffersGrid: View {
    let offers: [PartnerOffer]

    private let columns = [GridItem(.adaptive(minimum: 300, maximum: 400), spacing: 16)]

    var body: some View {
        // Bara de filtre comuna (2026-09-11) — shadowing pe `offers`,
        // deci corpul de mai jos ramane neschimbat, dar primeste lista
        // deja filtrata. Vezi CatalogFilterBar.swift.
        FilteredCatalogSection(items: offers, options: .content) { offers in
        ScrollView {
            if offers.isEmpty {
                Text(L.t("partnerOffers.empty")).foregroundStyle(.secondary).padding(40)
            } else {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(offers) { offer in
                        PartnerOfferCard(offer: offer)
                    }
                }
                .padding(16)
            }
        }
        }
    }
}

private struct PartnerOfferCard: View {
    let offer: PartnerOffer

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                CoverThumbnail(
                    url: offer.coverImageURL,
                    fallbackSymbol: "tag.fill",
                    tint: .red,
                    height: 150,
                    lightboxTitle: offer.brandName
                )
                // Badge de discount, generat automat din `discountText` —
                // permis aici (brand PARTENER, nu produs propriu GDC).
                if let discountText = offer.discountText {
                    Text(discountText.uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Capsule().fill(Color.red))
                        .padding(8)
                }
            }
            Text(offer.brandName).font(.headline)
            CountdownBadge(scheduling: offer.scheduling)
            CollapsibleDescription(text: offer.description)
            if let coupon = offer.couponCode {
                HStack(spacing: 4) {
                    Text(L.t("partnerOffers.coupon")).font(.caption2).foregroundStyle(.secondary)
                    Text(coupon).font(.caption2.monospaced()).fontWeight(.bold)
                }
            }
            ExtraLinksRow(purchaseURL: nil, demoURL: nil, social: offer.socialLinks)
            if let url = URL(string: offer.url) {
                Button(L.t("partnerOffers.open")) { NSWorkspace.shared.open(url) }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCardBackground()
        .overlay(alignment: .topLeading) {
            if let urlString = offer.youtubeURL, let url = URL(string: urlString) {
                Button { NSWorkspace.shared.open(url) } label: {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                        .background(Circle().fill(.background).frame(width: 16, height: 16))
                }
                .buttonStyle(.plain)
                .help(L.t("card.youtubeLink"))
                .padding(8)
                .help(L.t("card.tutorial"))
            }
        }
    }
}

private struct PartnerStoresGrid: View {
    let stores: [PartnerStore]

    // Mai lat decât înainte (260→300): cardurile au acum copertă și
    // descrierea se vede întreagă, deci au nevoie de spațiu ca să nu se
    // înghesuie textul pe rânduri de 3 cuvinte.
    private let columns = [GridItem(.adaptive(minimum: 300, maximum: 400), spacing: 16)]

    var body: some View {
        // Bara de filtre comuna (2026-09-11) — shadowing pe `stores`,
        // deci corpul de mai jos ramane neschimbat, dar primeste lista
        // deja filtrata. Vezi CatalogFilterBar.swift.
        FilteredCatalogSection(items: stores, options: .content) { stores in
        ScrollView {
            if stores.isEmpty {
                Text(L.t("stores.empty")).foregroundStyle(.secondary).padding(40)
            } else {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(stores) { store in
                        PartnerStoreCard(store: store)
                    }
                }
                .padding(16)
            }
        }
        }
    }
}

private struct PartnerStoreCard: View {
    let store: PartnerStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            CoverThumbnail(
                url: store.coverImageURL,
                fallbackSymbol: "storefront.fill",
                tint: .accentColor,
                height: 130,
                lightboxTitle: store.name
            )
            Text(store.name).font(.headline)
            CountdownBadge(scheduling: store.scheduling)
            CollapsibleDescription(text: store.description)
            Spacer(minLength: 0)
            HStack {
                if let url = URL(string: store.url) {
                    Button(L.t("stores.visit")) { NSWorkspace.shared.open(url) }
                        .controlSize(.small)
                }
                MapButton(mapsURL: store.mapsURL)
            }
            // Multi-Locație (2026-09-05) — sedii suplimentare, câte un rând.
            ForEach(store.additionalAddresses, id: \.self) { addr in
                HStack(spacing: 6) {
                    Text(addr).font(.caption).foregroundStyle(.secondary)
                    MapButton(mapsURL: MapsLink.url(for: addr))
                }
            }
            SocialLinksRow(store.socialLinks)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 180, alignment: .leading)
        .glassCardBackground()
    }
}

private func serviceCategoryLabel(_ category: ServiceCategory) -> String {
    L.t("servicecategory.\(category.rawValue)")
}

private struct ServiceCentersGrid: View {
    let centers: [ServiceCenter]

    private let columns = [GridItem(.adaptive(minimum: 280, maximum: 380), spacing: 16)]

    var body: some View {
        // Bara de filtre comuna (2026-09-11) — shadowing pe `centers`,
        // deci corpul de mai jos ramane neschimbat, dar primeste lista
        // deja filtrata. Vezi CatalogFilterBar.swift.
        FilteredCatalogSection(items: centers, options: .content) { centers in
        ScrollView {
            if centers.isEmpty {
                Text(L.t("servicecenters.empty")).foregroundStyle(.secondary).padding(40)
            } else {
                // Grup pe categorie, fiecare cu propriul grid — nu o singura
                // grila cu header "spanned" (nu se poate garanta latimea
                // completa intr-un LazyVGrid cu coloane adaptive).
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(ServiceCategory.allCases) { category in
                        let group = centers.filter { $0.category == category }
                        if !group.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Label(serviceCategoryLabel(category), systemImage: category.symbol)
                                    .font(.headline)
                                LazyVGrid(columns: columns, spacing: 14) {
                                    ForEach(group) { center in
                                        ServiceCenterCard(center: center)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }
        }
        }
    }
}

private struct ServiceCenterCard: View {
    let center: ServiceCenter

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            CoverThumbnail(
                url: center.coverImageURL,
                fallbackSymbol: center.category.symbol,
                tint: .accentColor,
                height: 110,
                lightboxTitle: center.name
            )
            Text(center.name).font(.headline)
            CountdownBadge(scheduling: center.scheduling)
            CollapsibleDescription(text: center.specialization)
            Spacer(minLength: 0)
            HStack {
                if let url = URL(string: center.contactURL) {
                    Button(L.t("servicecenters.contact")) { NSWorkspace.shared.open(url) }
                        .controlSize(.small)
                }
                if let websiteString = center.websiteURL, let url = URL(string: websiteString) {
                    Button(L.t("servicecenters.website")) { NSWorkspace.shared.open(url) }
                        .controlSize(.small)
                }
                MapButton(mapsURL: center.mapsURL)
            }
            // Multi-Locație (2026-09-05) — sedii suplimentare, câte un rând.
            ForEach(center.additionalAddresses, id: \.self) { addr in
                HStack(spacing: 6) {
                    Text(addr).font(.caption).foregroundStyle(.secondary)
                    MapButton(mapsURL: MapsLink.url(for: addr))
                }
            }
            SocialLinksRow(center.socialLinks)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 170, alignment: .leading)
        .glassCardBackground()
    }
}

private struct AppsGrid: View {
    let apps: [AppLink]

    // Bara de filtre si badge-urile vin din componentele COMUNE
    // (CatalogFilterBar.swift) — aceleasi in toate sectiunile.
    @StateObject private var filters = CatalogFilterState()

    private let columns = [GridItem(.adaptive(minimum: 220, maximum: 280), spacing: 14)]

    private var filtered: [AppLink] { filters.filter(apps) }

    var body: some View {
        VStack(spacing: 0) {
            CatalogFilterBar(
                state: filters,
                options: .product,
                availableTags: CatalogFacets.tags(apps),
                availableGroups: CatalogFacets.groups(apps)
            )
            Divider()
            ScrollView {
                if apps.isEmpty {
                    Text(L.t("apps.empty")).foregroundStyle(.secondary).padding(40)
                } else if filtered.isEmpty {
                    Text(L.t("access.filter.none")).foregroundStyle(.secondary).padding(40)
                } else {
                    LazyVGrid(columns: columns, spacing: 14) {
                        // Preț dinamic (Regula 27) - un singur fetch pentru
                        // tot grid-ul, nu unul per card.
                        ForEach(filtered) { app in
                            AppCard(app: app)
                        }
                    }
                    .padding(16)
                }
            }
            // Atasat pe ScrollView (mereu prezent), nu pe LazyVGrid din
            // ramura `else` - acelasi bug de `.task` pe conditional gol deja
            // documentat la SeasonalBackgroundLayer/LaunchOfferBanner.
            .task { await AppPricingFetcher.shared.refresh() }
        }
    }
}


private struct AppCard: View {
    let app: AppLink
    @ObservedObject private var downloader = AppDirectDownload.shared

    /// Apps aren't a `PluginType` case, so they get their own fixed tint
    /// here instead of `PluginType.tintColor` — matches the blue Cristi
    /// asked for, distinct from every plugin category's color.
    private let tint = Color.blue

    // Preț dinamic (Regula 27, 2026-08-31) - vezi AppPricingFetcher. Un
    // card fara `pricingProductID` (Clapperboard Digital, GDC Metadata
    // View Premium etc.) sau fara raspuns de la gordas.dev ramane
    // NESCHIMBAT - fail-open, nu un card gol/eronat.
    @ObservedObject private var pricingFetcher = AppPricingFetcher.shared
    private var pricing: ProductPricing? {
        guard let id = app.pricingProductID else { return nil }
        return pricingFetcher.catalog?.products[id]
    }
    private func formattedPrice(_ value: Double) -> String {
        let isWhole = value.truncatingRemainder(dividingBy: 1) == 0
        return "\(isWhole ? String(Int(value)) : String(value)) €"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(L.t("apps.badge"))
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(tint)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(tint.opacity(0.15)))
                // Badge de status comun (GRATUIT/TRIAL/EXTERN) — nu apare
                // deloc daca furnizorul n-a declarat un tip de acces.
                AccessBadge(access: app.resolvedAccess)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            // Coperta, daca aplicatia are una — altfel cade pe simbolul
            // "app.badge" de mai jos, la aceeasi inaltime (CoverThumbnail
            // face fallback-ul singur, vezi CoverImageViews.swift).
            CoverThumbnail(
                url: app.coverImageURL,
                fallbackSymbol: "app.badge",
                tint: tint,
                height: 56,
                lightboxTitle: app.name
            )
            Text(app.name).font(.headline)
            if let pricing {
                if let promo = pricing.activePromo {
                    HStack(spacing: 4) {
                        Text(formattedPrice(promo.price))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.orange)
                        Text(formattedPrice(pricing.basePrice))
                            .font(.caption2).strikethrough().foregroundStyle(.tertiary)
                    }
                    CountdownBadge(scheduling: promo.asScheduling)
                } else {
                    Text(formattedPrice(pricing.basePrice))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            } else {
                // Fara pret dinamic din Pricing Manager, `resolvedAccess`
                // aplica pasul 2 al precedentei (pret de referinta + aviz).
                AccessPriceLabel(access: app.resolvedAccess)
                CountdownBadge(scheduling: app.scheduling)
            }
            AccessTagsRow(tags: app.resolvedAccess.tags)
            Spacer(minLength: 0)
            if let raw = app.downloadURL, let file = URL(string: raw) {
                let busy = downloader.active.contains(app.id)
                Button(busy ? L.t("apps.downloading") : L.t("apps.download")) { downloader.start(appID: app.id, url: file) }
                    .disabled(busy)
                if let reason = downloader.failed[app.id] {
                    Text(L.t("apps.downloadFailed")).font(.caption).foregroundStyle(.secondary).help(reason)
                }
            }
            if let url = URL(string: app.url) {
                Button(L.t("apps.open")) { NSWorkspace.shared.open(url) }
            }
            SocialLinksRow(app.socialLinks)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
        .glassCardBackground()
        .overlay(alignment: .topTrailing) { infoButton }
    }

    @ViewBuilder
    private var infoButton: some View {
        if let urlString = app.youtubeURL, let url = URL(string: urlString) {
            Button { NSWorkspace.shared.open(url) } label: {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                    .background(Circle().fill(.background).frame(width: 16, height: 16))
            }
            .buttonStyle(.plain)
            .help(L.t("card.youtubeLink"))
            .padding(8)
            .help(L.t("card.tutorial"))
        }
    }
}

/// Grid pentru o categorie de resurse de download direct (LUT/SFX/VFX/
/// Plugin) — Etapa 2 (2026-08-29). Filtru OS (Toate/Mac/Windows), la fel
/// ca `CatalogGrid` — unele resurse (ex. un plugin Premiere) pot fi
/// specifice unei singure platforme.
private struct DownloadResourceGrid: View {
    let resources: [DownloadableResource]

    // Filtru OS local inlocuit 2026-09-11 cu bara COMUNA, care aduce si
    // pret/grup/etichete. `isFree`/`supportedOS` proprii resursei raman
    // sursa de adevar (pasul 1 al precedentei).
    @StateObject private var filters = CatalogFilterState()

    private let columns = [GridItem(.adaptive(minimum: 220, maximum: 280), spacing: 14)]

    private var filteredResources: [DownloadableResource] { filters.filter(resources) }

    var body: some View {
        VStack(spacing: 0) {
            if !resources.isEmpty {
                CatalogFilterBar(
                    state: filters,
                    options: .product,
                    availableTags: CatalogFacets.tags(resources),
                    availableGroups: CatalogFacets.groups(resources)
                )
            }
            ScrollView {
                if resources.isEmpty {
                    Text(L.t("download.empty")).foregroundStyle(.secondary).padding(40)
                } else if filteredResources.isEmpty {
                    Text(L.t("filter.price.empty")).foregroundStyle(.secondary).padding(40)
                } else {
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(filteredResources) { resource in
                            DownloadResourceCard(resource: resource)
                        }
                    }
                    .padding(16)
                }
            }
        }
    }
}

private struct DownloadResourceCard: View {
    let resource: DownloadableResource
    @State private var isDownloading = false
    @State private var downloadError: String?
    @ObservedObject private var locations = DownloadLocationStore.shared
    // Licențiere adăugată 2026-08-29 (cerut explicit) — port 1:1 al
    // fluxului de pe `PluginCard` (Gratuit/Probă/Licență + WhatsApp).
    @ObservedObject private var license = LicenseManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    Image(systemName: resource.supportedOS.badgeSymbol)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 20, height: 20)
                        .background(Circle().fill(Color.secondary.opacity(0.12)))
                        .help(resource.supportedOS.badgeLabel)
                    licenseBadge
                }
            }
            CoverThumbnail(
                url: resource.coverImageURL,
                fallbackSymbol: resource.category.defaultSymbol,
                tint: resource.category.tintColor,
                height: 100,
                lightboxTitle: resource.name
            )
            Text(resource.name).font(.headline)
            if let kind = resource.pdfKind {
                BadgePill(text: L.t("pdfKind.\(kind.rawValue)"), color: .red)
            }
            CountdownBadge(scheduling: resource.scheduling)
            CollapsibleDescription(text: resource.description)
            ExtraLinksRow(purchaseURL: resource.purchaseURL, demoURL: resource.demoURL, social: resource.socialLinks)
            // Etapa 5+ (2026-08-29, cerut explicit): "să aibă posibilitatea
            // să își pună path-ul... ca să știe tot timpul unde l-a
            // descărcat" — stare 100% locală (DownloadLocationStore), nu
            // parte din catalog. Doar dacă e deblocată (n-are sens sa
            // memorezi o cale pentru ceva ce inca nu poti descarca).
            if license.isUnlocked(for: resource) {
                downloadLocationRow
            }
            Spacer(minLength: 0)
            actionButton
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
        .glassCardBackground()
        .overlay(alignment: .topLeading) { infoButton }
    }

    @ViewBuilder
    private var licenseBadge: some View {
        if resource.isFree && resource.isTrial {
            BadgePill(text: L.t("card.trial"), color: .blue)
        } else if resource.isFree {
            BadgePill(text: L.t("card.free"), color: .green)
        } else {
            VStack(alignment: .trailing, spacing: 3) {
                if resource.isPromoActive {
                    Text(resource.priceDisplay).font(.caption2).strikethrough().foregroundStyle(.tertiary)
                }
                Text(resource.effectivePriceEUR.formatted(.currency(code: "EUR")))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                if resource.isPromoActive {
                    BadgePill(text: L.t("card.promo"), color: .red)
                } else {
                    BadgePill(text: L.t("card.paid"), color: .orange)
                        .help(L.t("card.trustMessage"))
                }
            }
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        if !resource.supportedOS.allows(current: .current) {
            Text(L.t("card.incompatibleOS")).font(.caption).foregroundStyle(.red)
        } else if !license.isUnlocked(for: resource) {
            Button(L.t("card.buy")) { NSWorkspace.shared.open(buyURL) }
        } else if resource.hasDirectFile {
            // [2026-09-14] Fișier încărcat direct pe server: se descarcă din
            // aplicație și se arată în Finder. Fără browser — vezi Regula 20.
            HStack(spacing: 8) {
                Button(isDownloading ? L.t("resource.downloading") : L.t("resource.download")) {
                    Task { await downloadDirect() }
                }
                .disabled(isDownloading)
                if isDownloading { ProgressView().controlSize(.small) }
            }
            if let downloadError {
                Text(downloadError).font(.caption).foregroundStyle(.red)
            }
        } else if let url = URL(string: resource.url) {
            Button(L.t("audio.open")) { NSWorkspace.shared.open(url) }
        }
    }

    private func downloadDirect() async {
        downloadError = nil
        isDownloading = true
        defer { isDownloading = false }
        do {
            let saved = try await InstallManager.shared.downloadResourceFile(resource)
            NSWorkspace.shared.activateFileViewerSelecting([saved])
        } catch {
            downloadError = error.localizedDescription
        }
    }

    private var buyURL: URL {
        let priceText = resource.effectivePriceEUR.formatted(.currency(code: "EUR"))
        let text = "Salut! Vreau să deblochez \(resource.name) cu o donație de \(priceText). ID calculator: \(MachineID.display)"
        return WhatsAppLink.url(text: text)
    }

    @ViewBuilder
    private var downloadLocationRow: some View {
        if let path = locations.path(for: resource.id) {
            HStack(spacing: 6) {
                Image(systemName: "folder.fill").font(.system(size: 10)).foregroundStyle(.secondary)
                Text(path)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Button {
                    locations.openFolder(for: resource.id)
                } label: {
                    Image(systemName: "arrow.up.forward.square")
                }
                .buttonStyle(.plain)
                .help(L.t("download.location.open"))
                Button {
                    locations.pickFolder(for: resource.id)
                } label: {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.plain)
                .help(L.t("download.location.change"))
            }
        } else {
            Button {
                locations.pickFolder(for: resource.id)
            } label: {
                Label(L.t("download.location.set"), systemImage: "folder.badge.plus")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var infoButton: some View {
        if let urlString = resource.youtubeURL, let url = URL(string: urlString) {
            Button { NSWorkspace.shared.open(url) } label: {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                    .background(Circle().fill(.background).frame(width: 16, height: 16))
            }
            .buttonStyle(.plain)
            .help(L.t("card.youtubeLink"))
            .padding(8)
            .help(L.t("card.tutorial"))
        }
    }
}

private struct AudioGrid: View {
    let tracks: [AudioTrack]

    private let columns = [GridItem(.adaptive(minimum: 220, maximum: 280), spacing: 14)]

    var body: some View {
        // Bara de filtre comuna (2026-09-11) — shadowing pe `tracks`,
        // deci corpul de mai jos ramane neschimbat, dar primeste lista
        // deja filtrata. Vezi CatalogFilterBar.swift.
        FilteredCatalogSection(items: tracks, options: .content) { tracks in
        ScrollView {
            if tracks.isEmpty {
                Text(L.t("audio.empty")).foregroundStyle(.secondary).padding(40)
            } else {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(tracks) { track in
                        AudioCard(track: track)
                    }
                }
                .padding(16)
            }
        }
        }
    }
}

private struct AudioCard: View {
    let track: AudioTrack

    /// Nu e un `PluginType`, la fel ca Aplicații — culoare proprie,
    /// distinctă de tot ce e deja folosit (dctl=galben, lut=verde,
    /// fuse=roz, powerGrade=mov, ofx=cyan, apps=albastru).
    private let tint = Color.indigo

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L.t("audio.badge"))
                .font(.system(size: 9, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(tint)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(tint.opacity(0.15)))
                .frame(maxWidth: .infinity, alignment: .center)
            CoverThumbnail(
                url: track.coverImageURL,
                fallbackSymbol: "waveform",
                tint: tint,
                height: 56,
                lightboxTitle: track.name
            )
            Text(track.name).font(.headline)
            CountdownBadge(scheduling: track.scheduling)
            CollapsibleDescription(text: track.description)
            Spacer(minLength: 0)
            if let url = URL(string: track.url) {
                Button(L.t("audio.open")) { NSWorkspace.shared.open(url) }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
        .glassCardBackground()
        .overlay(alignment: .topTrailing) { infoButton }
    }

    @ViewBuilder
    private var infoButton: some View {
        if let urlString = track.youtubeURL, let url = URL(string: urlString) {
            Button { NSWorkspace.shared.open(url) } label: {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                    .background(Circle().fill(.background).frame(width: 16, height: 16))
            }
            .buttonStyle(.plain)
            .help(L.t("card.youtubeLink"))
            .padding(8)
            .help(L.t("card.tutorial"))
        }
    }
}
