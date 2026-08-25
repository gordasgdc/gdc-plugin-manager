import SwiftUI
import AppKit
import GDCPluginManagerCore

enum SidebarSection: Hashable {
    case all
    case type(PluginType)
    case courses
    case educationalResources
    case events
    case partnerStores
    case serviceCenters
    case apps
    case android
    case license
    case help
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
    @State private var resolveWarningVisible = false
    @State private var showOnboarding = false
    @State private var missingDependencies: [SystemDependency] = []
    @State private var showManualUpdateCheckAlert = false
    @State private var manualUpdateCheckMessage = ""

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
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
            CoursesGrid(courses: catalog.courses)
        case .educationalResources:
            EducationalResourcesGrid(resources: catalog.educationalResources)
        case .events:
            EventsGrid(events: catalog.events)
        case .partnerStores:
            PartnerStoresGrid(stores: catalog.partnerStores)
        case .serviceCenters:
            ServiceCentersGrid(centers: catalog.serviceCenters)
        case .apps:
            AppsGrid(apps: catalog.apps)
        case .android:
            MobileAppPane()
        case .all, .none:
            CatalogGrid(items: catalog.items)
        case .type(let type):
            CatalogGrid(items: catalog.items.filter { $0.type == type })
        }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
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
                Divider()
                Label(L.t("sidebar.courses"), systemImage: "graduationcap")
                    .tag(SidebarSection.courses)
                Label(L.t("sidebar.educationalResources"), systemImage: "book")
                    .tag(SidebarSection.educationalResources)
                Label(L.t("sidebar.events"), systemImage: "calendar")
                    .tag(SidebarSection.events)
                Label(L.t("sidebar.partnerStores"), systemImage: "storefront")
                    .tag(SidebarSection.partnerStores)
                Label(L.t("sidebar.serviceCenters"), systemImage: "wrench.and.screwdriver")
                    .tag(SidebarSection.serviceCenters)
                Label(L.t("sidebar.apps"), systemImage: "app.badge")
                    .tag(SidebarSection.apps)
                // Aplicatia mobila companion (PWA, gordas.dev/app.html — fost
                // APK/TWA, retras 2026-08-24) — vezi AndroidPane.swift.
                Label(L.t("sidebar.mobileApp"), systemImage: "iphone.gen3")
                    .tag(SidebarSection.android)
                Divider()
                Label(L.t("sidebar.license"), systemImage: "key.fill")
                    .tag(SidebarSection.license)
                Label(L.t("sidebar.help"), systemImage: "questionmark.circle")
                    .tag(SidebarSection.help)
            }
            .navigationSplitViewColumnWidth(180)
            .safeAreaInset(edge: .bottom) {
                Text("v\(appVersion)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            }
        } detail: {
            VStack(spacing: 0) {
                if !missingDependencies.isEmpty {
                    DependencyBanner(missing: missingDependencies)
                }
                if let update = updateChecker.availableUpdate {
                    UpdateBanner(update: update)
                }
                detailContent
            }
        }
        .navigationTitle(L.t("app.name"))
        .toolbar {
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
            missingDependencies = SystemDependencyChecker.checkAll().filter { !$0.isPresent }
            if !UserDefaults.standard.bool(forKey: "gdcpm_onboarded") {
                showOnboarding = true
            }
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView(isPresented: $showOnboarding)
        }
        // "Check for Updates..." din meniul nativ (vezi GDCPluginManagerApp.swift)
        // — separat de check-ul automat de la lansare, mereu urmat de un
        // rezultat vizibil (pop-up nativ), niciodata silentios.
        .onReceive(NotificationCenter.default.publisher(for: .gdcCheckForUpdatesRequested)) { _ in
            Task {
                await updateChecker.check()
                if let update = updateChecker.availableUpdate {
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
            if let urlString = info.download_url["mac"], let url = URL(string: urlString) {
                Button(L.t("update.download")) { NSWorkspace.shared.open(url) }
            }
            // Update marcat mandatory (docs/update.json): fara "Mai tarziu"
            // — vezi UpdateChecker.dismiss(), nu se mai persista inchiderea
            // pentru mandatory, deci butonul ar fi oricum inutil aici.
            if info.mandatory != true {
                Button(L.t("update.popup.later"), role: .cancel) { updateChecker.dismiss() }
            }
        } message: { info in
            Text(L.t("update.popup.message") + " (v\(info.version))")
        }
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
            if let urlString = update.download_url["mac"], let url = URL(string: urlString) {
                Button(L.t("update.download")) { NSWorkspace.shared.open(url) }
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

/// Filtru rapid Toate/Gratuite/Premium — cerut explicit 2026-08-24, ca
/// cine vrea doar uneltele gratuite sa le gaseasca instant, fara sa
/// citeasca fiecare card in parte.
private enum PriceFilter: String, CaseIterable, Identifiable {
    case all, free, paid
    var id: String { rawValue }
    var label: String {
        switch self {
        case .all: return L.t("filter.price.all")
        case .free: return L.t("filter.price.free")
        case .paid: return L.t("filter.price.paid")
        }
    }
    func matches(_ item: PluginItem) -> Bool {
        switch self {
        case .all: return true
        case .free: return item.isFree
        case .paid: return !item.isFree
        }
    }
}

private struct CatalogGrid: View {
    let items: [PluginItem]
    @EnvironmentObject private var catalog: CatalogService
    @State private var priceFilter: PriceFilter = .all

    // 240 (de la 220): cardul are acum și copertă, iar descrierea urcă la
    // 5 rânduri — sub 240 textul se rupe urât.
    private let columns = [GridItem(.adaptive(minimum: 240, maximum: 300), spacing: 14)]

    private var filteredItems: [PluginItem] {
        items.filter { priceFilter.matches($0) }
    }

    var body: some View {
        VStack(spacing: 0) {
            if !items.isEmpty {
                Picker("", selection: $priceFilter) {
                    ForEach(PriceFilter.allCases) { filter in
                        Text(filter.label).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 280)
                .padding(.horizontal, 16)
                .padding(.top, 12)
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

/// Etichetă compactă tip "pill" — GRATUIT (verde) / LICENȚĂ (portocaliu) /
/// PROBĂ (albastru). Un fundal plin + text alb, nu doar text colorat, ca
/// sa citeasca clar ca un badge, nu ca o simpla nota de pret.
private struct BadgePill: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .bold))
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
                Text(item.supportedOS.badgeEmoji)
                    .font(.system(size: 12))
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
            HStack(alignment: .top) {
                Spacer()
                // Stacked vertically (info button above the price/status
                // badge, not on top of it) — an absolute corner overlay
                // here used to land right on top of the badge.
                VStack(alignment: .trailing, spacing: 6) {
                    infoButton
                    if item.isFree && item.isTrial {
                        BadgePill(text: L.t("card.trial"), color: .blue)
                    } else if item.isFree {
                        BadgePill(text: L.t("card.free"), color: .green)
                    } else {
                        VStack(alignment: .trailing, spacing: 3) {
                            Text(item.priceDisplay)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                            // Badge "LICENȚĂ" — inlocuieste vechea eticheta
                            // "donație" (2026-08-24, cerere explicita: fara
                            // ton de "reclama agresiva", comunicare
                            // transparenta). Mesajul complet de incredere
                            // apare la hover (.help), cardul ramane compact.
                            BadgePill(text: L.t("card.paid"), color: .orange)
                                .help(L.t("card.trustMessage"))
                        }
                    }
                }
            }
            Text(item.name).font(.headline)
            Text(item.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                // 5 rânduri, nu 3: descrierile reale de produs erau tăiate
                // la jumătate de frază.
                .lineLimit(5)
                .fixedSize(horizontal: false, vertical: true)
            Text("\(L.t("card.version")) \(item.version)")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            if let errorMessage {
                Text(errorMessage).font(.caption2).foregroundStyle(.red)
            }
            if let statusMessage {
                Text(statusMessage).font(.caption2).foregroundStyle(.blue)
            }
            if showPaidResourceSupportError {
                Button {
                    NSWorkspace.shared.open(supportContactURL)
                } label: {
                    Label(L.t("install.contact.support"), systemImage: "message.fill")
                        .font(.caption2)
                }
                .buttonStyle(.bordered)
                .tint(.green)
            }

            actionButton
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(.background.secondary))
        .alert(resolveWarningTitle, isPresented: $showResolveWarning) {
            Button(L.t("resolve.running.ok")) {}
        } message: {
            Text(resolveWarningBody)
        }
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
        let text = "Salut! Vreau să deblochez \(item.name) cu o donație de \(item.priceDisplay). ID calculator: \(MachineID.display)"
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
                case .installed:
                    break
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
            Text(course.name).font(.headline)
            Text(course.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                // Fără limită de rânduri + fixedSize: descrierea se vede
                // întreagă, nu trunchiată de layout.
                .fixedSize(horizontal: false, vertical: true)

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
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(.background.secondary))
    }

    private func contactURL(for option: CourseOption) -> URL {
        let text = String(format: L.t("courses.contact.message"), course.name, option.label, option.priceDisplay)
        return WhatsAppLink.url(text: text)
    }
}

private struct EducationalResourcesGrid: View {
    let resources: [EducationalResource]

    // Mai lat decât înainte (260→300): cardurile au acum copertă și
    // descrierea se vede întreagă, deci au nevoie de spațiu ca să nu se
    // înghesuie textul pe rânduri de 3 cuvinte.
    private let columns = [GridItem(.adaptive(minimum: 300, maximum: 400), spacing: 16)]

    var body: some View {
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
                }
            }
            Text(resource.name).font(.headline)
            Text(resource.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            if let url = URL(string: resource.externalURL) {
                Button(L.t("resources.buy")) { NSWorkspace.shared.open(url) }
                    .controlSize(.small)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 200, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(.background.secondary))
    }
}

private struct EventsGrid: View {
    let events: [Event]

    // Mai lat decât înainte (260→300): cardurile au acum copertă și
    // descrierea se vede întreagă, deci au nevoie de spațiu ca să nu se
    // înghesuie textul pe rânduri de 3 cuvinte.
    private let columns = [GridItem(.adaptive(minimum: 300, maximum: 400), spacing: 16)]

    var body: some View {
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
                }
            }
            Text(event.title).font(.headline)
            Text("\(event.dateDisplay) · \(event.location)")
                .font(.caption).foregroundStyle(.secondary)
            Text(event.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            if let url = URL(string: event.externalURL) {
                Button(L.t("events.details")) { NSWorkspace.shared.open(url) }
                    .controlSize(.small)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 220, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(.background.secondary))
    }
}

private struct PartnerStoresGrid: View {
    let stores: [PartnerStore]

    // Mai lat decât înainte (260→300): cardurile au acum copertă și
    // descrierea se vede întreagă, deci au nevoie de spațiu ca să nu se
    // înghesuie textul pe rânduri de 3 cuvinte.
    private let columns = [GridItem(.adaptive(minimum: 300, maximum: 400), spacing: 16)]

    var body: some View {
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
            Text(store.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            if let url = URL(string: store.url) {
                Button(L.t("stores.visit")) { NSWorkspace.shared.open(url) }
                    .controlSize(.small)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 180, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(.background.secondary))
    }
}

private func serviceCategoryLabel(_ category: ServiceCategory) -> String {
    L.t("servicecategory.\(category.rawValue)")
}

private struct ServiceCentersGrid: View {
    let centers: [ServiceCenter]

    private let columns = [GridItem(.adaptive(minimum: 280, maximum: 380), spacing: 16)]

    var body: some View {
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
            Text(center.specialization)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
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
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 170, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(.background.secondary))
    }
}

private struct AppsGrid: View {
    let apps: [AppLink]

    private let columns = [GridItem(.adaptive(minimum: 220, maximum: 280), spacing: 14)]

    var body: some View {
        ScrollView {
            if apps.isEmpty {
                Text(L.t("apps.empty")).foregroundStyle(.secondary).padding(40)
            } else {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(apps) { app in
                        AppCard(app: app)
                    }
                }
                .padding(16)
            }
        }
    }
}

private struct AppCard: View {
    let app: AppLink

    /// Apps aren't a `PluginType` case, so they get their own fixed tint
    /// here instead of `PluginType.tintColor` — matches the blue Cristi
    /// asked for, distinct from every plugin category's color.
    private let tint = Color.blue

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L.t("apps.badge"))
                .font(.system(size: 9, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(tint)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(tint.opacity(0.15)))
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
            Spacer(minLength: 0)
            if let url = URL(string: app.url) {
                Button(L.t("apps.open")) { NSWorkspace.shared.open(url) }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(.background.secondary))
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
            .padding(8)
            .help(L.t("card.tutorial"))
        }
    }
}
