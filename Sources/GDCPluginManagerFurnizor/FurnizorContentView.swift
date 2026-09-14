import SwiftUI

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
    @State private var selection: FurnizorSection? = .publish

    // Secțiuni pliabile, la fel ca în client (2026-09-14). @AppStorage, nu
    // @State: preferința trebuie să supraviețuiască repornirii.
    //
    // Implicit doar CATALOG e deschisă — acolo cade și selecția implicită
    // („Publică produs"), deci meniul pornește compact fără să ascundă
    // rubrica pe care ești.
    @AppStorage("furnizor.sidebar.catalog") private var expandCatalog = true
    @AppStorage("furnizor.sidebar.sales") private var expandSales = false
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
        case .generateSerial, .revocations, .salesHistory, .analytics, .pricing:
            expandSales = true
        case .launchBanner, .seasonalBackground, .imageLibrary:
            expandClientUI = true
        case .backup, .secrets, .repoStorage:
            expandMaintenance = true
        }
    }
    @StateObject private var tokenStatus = GitHubTokenStatus.shared
    @State private var showTokenPopover = false
    @State private var showRenewalGuide = false
    @State private var bannerDismissed = false

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                // Gruparea urmeaza ce FACI, nu cum e scris codul: tot ce
                // ajunge in catalogul clientilor intr-un grup, tot ce tine de
                // bani si licente in altul, aspectul clientului in al treilea,
                // iar uneltele de intretinere la urma — ele se deschid rar,
                // dar cand se deschid conteaza sa fie toate la un loc.
                Section(isExpanded: $expandCatalog) {
                    Label("Publică produs", systemImage: "arrow.up.doc").tag(FurnizorSection.publish)
                    Label("Cursuri", systemImage: "graduationcap").tag(FurnizorSection.courses)
                    Label("Materiale", systemImage: "book").tag(FurnizorSection.educationalResources)
                    Label("Tutoriale", systemImage: "play.rectangle").tag(FurnizorSection.tutorials)
                    Label("Evenimente", systemImage: "calendar").tag(FurnizorSection.events)
                    Label("Magazine partenere", systemImage: "storefront").tag(FurnizorSection.partnerStores)
                    Label("Service & Reparații", systemImage: "wrench.and.screwdriver").tag(FurnizorSection.serviceCenters)
                    Label("Aplicații", systemImage: "square.grid.2x2").tag(FurnizorSection.apps)
                    Label("Audio", systemImage: "waveform").tag(FurnizorSection.audio)
                    Label("Resurse Download (LUT/SFX/VFX/Plugin)", systemImage: "arrow.down.circle").tag(FurnizorSection.downloadResources)
                    Label("Oferte Parteneri", systemImage: "tag").tag(FurnizorSection.partnerOffers)
                    Label("Pachete / Bundle-uri", systemImage: "shippingbox").tag(FurnizorSection.bundles)
                    Label("Comunitate", systemImage: "person.2.wave.2").tag(FurnizorSection.communityChannels)
                } header: {
                    Text("CATALOG")
                }

                Section(isExpanded: $expandSales) {
                    Label("Generează serial", systemImage: "key").tag(FurnizorSection.generateSerial)
                    Label("Revocări licențe", systemImage: "xmark.shield").tag(FurnizorSection.revocations)
                    Label("Clienți", systemImage: "person.2").tag(FurnizorSection.salesHistory)
                    Label("Statistici", systemImage: "chart.bar").tag(FurnizorSection.analytics)
                    Label("Prețuri & Oferte", systemImage: "eurosign.circle").tag(FurnizorSection.pricing)
                } header: {
                    Text("VÂNZĂRI & LICENȚE")
                }

                Section(isExpanded: $expandClientUI) {
                    Label("Banner Lansare", systemImage: "megaphone").tag(FurnizorSection.launchBanner)
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
                    .padding(.bottom, 8)
            }
        } detail: {
            VStack(spacing: 0) {
                if !bannerDismissed, tokenStatus.severity == .warning || tokenStatus.severity == .critical {
                    tokenBanner
                }
                switch selection {
                case .publish, .none:
                    PublishView()
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
                    PublishCourseView()
                case .educationalResources:
                    PublishEducationalResourceView()
                case .tutorials:
                    PublishTutorialView()
                case .events:
                    PublishEventView()
                case .partnerStores:
                    PublishPartnerStoreView()
                case .serviceCenters:
                    PublishServiceCenterView()
                case .apps:
                    PublishAppView()
                case .audio:
                    PublishAudioView()
                case .downloadResources:
                    PublishDownloadableResourceView()
                case .partnerOffers:
                    PublishPartnerOfferView()
                case .bundles:
                    PublishBundleView()
                case .communityChannels:
                    PublishCommunityChannelView()
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
        .toolbar {
            ToolbarItem {
                Button { showTokenPopover = true } label: {
                    Label(tokenLabel, systemImage: "key.fill")
                        .foregroundStyle(tokenColor)
                }
                .popover(isPresented: $showTokenPopover) {
                    tokenPopover
                }
            }
        }
        .sheet(isPresented: $showRenewalGuide) {
            // Înlocuiește vechiul `TokenRenewalGuideView` (șters în 1.40.0):
            // acela descria un singur repo privat și rămăsese în urmă față de
            // arhitectura multi-repo. Wizardul își ia pașii din `SecretRegistry`,
            // deci nu mai poate rămâne în urmă față de realitate.
            if let pat = SecretRegistry.shared.secrets.first(where: { $0.id == "github-pat" }) {
                SecretRenewalWizardView(secret: pat)
            }
        }
        .task {
            await tokenStatus.check()
        }
    }

    private var tokenLabel: String {
        if let days = tokenStatus.daysRemaining {
            return days >= 0 ? "Token GitHub: \(days) zile" : "Token GitHub: EXPIRAT"
        }
        return "Token GitHub"
    }

    private var tokenColor: Color {
        switch tokenStatus.severity {
        case .critical: return .red
        case .warning: return .orange
        case .ok: return .secondary
        case .unknown: return .secondary
        }
    }

    private var tokenPopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let expiresAt = tokenStatus.expiresAt {
                let days = tokenStatus.daysRemaining ?? 0
                Text(days >= 0 ? "Token-ul GitHub expiră în \(days) zile" : "Token-ul GitHub a EXPIRAT")
                    .font(.headline)
                    .foregroundStyle(tokenColor)
                Text("Data exactă: \(expiresAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption).foregroundStyle(.secondary)
            } else if tokenStatus.checkFailed {
                Text("Nu am putut verifica data de expirare acum.")
                    .font(.callout).foregroundStyle(.secondary)
            } else {
                ProgressView().controlSize(.small)
            }
            Button("Cum reînnoiesc token-ul?") {
                showTokenPopover = false
                showRenewalGuide = true
            }
            Button("Reverifică") { Task { await tokenStatus.check() } }
                .controlSize(.small)
        }
        .padding(16)
        .frame(width: 280)
    }

    private var tokenBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: tokenStatus.severity == .critical ? "exclamationmark.triangle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(tokenColor)
            VStack(alignment: .leading, spacing: 2) {
                Text("Atenție: token-ul GitHub expiră în \(tokenStatus.daysRemaining ?? 0) zile")
                    .font(.subheadline).fontWeight(.semibold)
                Text("După expirare, clienții nu mai pot descărca produse.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Cum reînnoiesc?") { showRenewalGuide = true }
            Button("Am înțeles") { bannerDismissed = true }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background((tokenStatus.severity == .critical ? Color.red : Color.orange).opacity(0.12))
    }
}
