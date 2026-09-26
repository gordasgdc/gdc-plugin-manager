import SwiftUI
import GDCPluginManagerCore

enum FurnizorSection: Hashable {
    case publish
    case generateSerial
    case revocations
    case salesHistory
    case analytics
    case courses
    case educationalResources
    case tutorials
    case events
    case partnerStores
    case serviceCenters
    case apps
    case audio
    case downloadResources
    case partnerOffers
    case bundles
    case seasonalBackground
    case pricing
    case launchBanner
    case backup
    case secrets
    case repoStorage
    case imageLibrary
    case communityChannels
}

struct FurnizorContentView: View {
    @State private var selection: FurnizorSection? = Self.initialSection

    /// DEBUG: `-FurnizorStartSection salesHistory` deschide direct o rubrică (capturi de verificare).
    private static var initialSection: FurnizorSection {
        #if DEBUG
        switch UserDefaults.standard.string(forKey: "FurnizorStartSection") {
        case "salesHistory": return .salesHistory
        case "courses": return .courses
        case "downloadResources": return .downloadResources
        case "secrets": return .secrets
        case "pricing": return .pricing
        default: return .publish
        }
        #else
        return .publish
        #endif
    }

    // Secțiuni pliabile, la fel ca în client (2026-09-14). @AppStorage, nu
    // @State: preferința trebuie să supraviețuiască repornirii.
    //
    // Implicit doar CATALOG e deschisă — acolo cade și selecția implicită
    // („Publică produs"), deci meniul pornește compact fără să ascundă
    // rubrica pe care ești.
    @AppStorage("furnizor.sidebar.catalog") private var expandCatalog = true
    @AppStorage("furnizor.sidebar.sales") private var expandSales = false
    @AppStorage("furnizor.sidebar.pricing") private var expandPricing = false
    @AppStorage("furnizor.sidebar.clientUI") private var expandClientUI = false
    @AppStorage("furnizor.sidebar.maintenance") private var expandMaintenance = false

    /// Deschide secțiunea care conține rubrica dată. Nu strânge niciodată
    /// altceva. Comutatorul e exhaustiv pe `FurnizorSection`: o rubrică nouă
    /// adăugată în viitor nu poate fi uitată aici fără eroare de compilare.
    private func expandSection(containing section: FurnizorSection?) {
        guard let section else { return }
        switch section {
        case .publish, .courses, .educationalResources, .tutorials, .events,
             .partnerStores, .serviceCenters, .apps, .audio, .downloadResources,
             .partnerOffers, .bundles, .communityChannels:
            expandCatalog = true
        case .generateSerial, .revocations, .salesHistory, .analytics:
            expandSales = true
        case .pricing, .launchBanner:
            expandPricing = true
        case .seasonalBackground, .imageLibrary:
            expandClientUI = true
        case .backup, .secrets, .repoStorage:
            expandMaintenance = true
        }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                // Gruparea urmeaza ce FACI, nu cum e scris codul: tot ce
                // ajunge in catalogul clientilor intr-un grup, tot ce tine de
                // bani si licente in altul, aspectul clientului in al treilea,
                // iar uneltele de intretinere la urma — ele se deschid rar,
                // dar cand se deschid conteaza sa fie toate la un loc.
                // Faza 5 (V1 aprobat 2026-09-26): 5 domenii. În Catalog, fiecare tip de conținut
                // deschide același spațiu de lucru (tabel + editor în inspector).
                Section(isExpanded: $expandCatalog) {
                    Label(CatalogContentType.products.title, systemImage: CatalogContentType.products.symbol).tag(FurnizorSection.publish)
                    Label(CatalogContentType.downloads.title, systemImage: CatalogContentType.downloads.symbol).tag(FurnizorSection.downloadResources)
                    Label(CatalogContentType.courses.title, systemImage: CatalogContentType.courses.symbol).tag(FurnizorSection.courses)
                    Label(CatalogContentType.educational.title, systemImage: CatalogContentType.educational.symbol).tag(FurnizorSection.educationalResources)
                    Label(CatalogContentType.tutorials.title, systemImage: CatalogContentType.tutorials.symbol).tag(FurnizorSection.tutorials)
                    Label(CatalogContentType.events.title, systemImage: CatalogContentType.events.symbol).tag(FurnizorSection.events)
                    Label(CatalogContentType.apps.title, systemImage: CatalogContentType.apps.symbol).tag(FurnizorSection.apps)
                    Label(CatalogContentType.audio.title, systemImage: CatalogContentType.audio.symbol).tag(FurnizorSection.audio)
                    Label(CatalogContentType.partnerOffers.title, systemImage: CatalogContentType.partnerOffers.symbol).tag(FurnizorSection.partnerOffers)
                    Label(CatalogContentType.bundles.title, systemImage: CatalogContentType.bundles.symbol).tag(FurnizorSection.bundles)
                    Label(CatalogContentType.partnerStores.title, systemImage: CatalogContentType.partnerStores.symbol).tag(FurnizorSection.partnerStores)
                    Label(CatalogContentType.serviceCenters.title, systemImage: CatalogContentType.serviceCenters.symbol).tag(FurnizorSection.serviceCenters)
                    Label(CatalogContentType.community.title, systemImage: CatalogContentType.community.symbol).tag(FurnizorSection.communityChannels)
                } header: {
                    Text("CATALOG")
                }

                Section(isExpanded: $expandSales) {
                    Label("Clienți", systemImage: "person.2").tag(FurnizorSection.salesHistory)
                    Label("Generează serial", systemImage: "key").tag(FurnizorSection.generateSerial)
                    Label("Revocări licențe", systemImage: "xmark.shield").tag(FurnizorSection.revocations)
                    Label("Statistici", systemImage: "chart.bar").tag(FurnizorSection.analytics)
                } header: {
                    Text("CLIENȚI & LICENȚE")
                }

                Section(isExpanded: $expandPricing) {
                    Label("Prețuri & Oferte", systemImage: "eurosign.circle").tag(FurnizorSection.pricing)
                    Label("Banner Lansare", systemImage: "megaphone").tag(FurnizorSection.launchBanner)
                } header: {
                    Text("PREȚURI & OFERTE")
                }

                Section(isExpanded: $expandClientUI) {
                    Label("Interfață Client (Filigran)", systemImage: "photo.on.rectangle.angled").tag(FurnizorSection.seasonalBackground)
                    Label("Banc de imagini", systemImage: "photo.stack").tag(FurnizorSection.imageLibrary)
                } header: {
                    Text("INTERFAȚA CLIENTULUI")
                }

                Section(isExpanded: $expandMaintenance) {
                    Label("Backup & Restaurare", systemImage: "lock.doc").tag(FurnizorSection.backup)
                    Label("Token-uri & Chei", systemImage: "key.horizontal").tag(FurnizorSection.secrets)
                    Label("Stocare pe repo-uri", systemImage: "internaldrive").tag(FurnizorSection.repoStorage)
                } header: {
                    Text("ÎNTREȚINERE")
                }
            }
            .onChange(of: selection) { _, newValue in
                expandSection(containing: newValue)
            }
            .onAppear { expandSection(containing: selection) }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 340)
            .safeAreaInset(edge: .bottom) {
                // Versiune vizibila in UI, obligatoriu si pe Furnizor
                // (cerut explicit 2026-08-26) - lipsea complet, Info-Furnizor.plist
                // era blocat la 1.0.0 din prima zi, in ciuda a zeci de
                // functionalitati noi adaugate de-atunci (Revocare, Durata
                // flexibila, Clienti/Tracker, etc.).
                Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, GDCTokens.Space.s)
            }
        } detail: {
            VStack(spacing: 0) {
                switch selection {
                case .publish, .none:
                    CatalogWorkspace(type: .products).id(CatalogContentType.products)
                case .generateSerial:
                    GenerateSerialView()
                case .revocations:
                    RevocationsView()
                case .salesHistory:
                    SalesHistoryView()
                case .analytics:
                    AnalyticsView()
                case .pricing:
                    PricingManagerView()
                case .launchBanner:
                    LaunchBannerManagerView()
                case .courses:
                    CatalogWorkspace(type: .courses).id(CatalogContentType.courses)
                case .educationalResources:
                    CatalogWorkspace(type: .educational).id(CatalogContentType.educational)
                case .tutorials:
                    CatalogWorkspace(type: .tutorials).id(CatalogContentType.tutorials)
                case .events:
                    CatalogWorkspace(type: .events).id(CatalogContentType.events)
                case .partnerStores:
                    CatalogWorkspace(type: .partnerStores).id(CatalogContentType.partnerStores)
                case .serviceCenters:
                    CatalogWorkspace(type: .serviceCenters).id(CatalogContentType.serviceCenters)
                case .apps:
                    CatalogWorkspace(type: .apps).id(CatalogContentType.apps)
                case .audio:
                    CatalogWorkspace(type: .audio).id(CatalogContentType.audio)
                case .downloadResources:
                    CatalogWorkspace(type: .downloads).id(CatalogContentType.downloads)
                case .partnerOffers:
                    CatalogWorkspace(type: .partnerOffers).id(CatalogContentType.partnerOffers)
                case .bundles:
                    CatalogWorkspace(type: .bundles).id(CatalogContentType.bundles)
                case .communityChannels:
                    CatalogWorkspace(type: .community).id(CatalogContentType.community)
                case .seasonalBackground:
                    SeasonalBackgroundView()
                case .backup:
                    BackupView()
                case .secrets:
                    SecretsDashboardView()
                case .repoStorage:
                    RepoStorageView()
                case .imageLibrary:
                    ImageLibraryView()
                }
            }
        }
        .navigationTitle("GDC Plugin Manager Furnizor")
    }
}

