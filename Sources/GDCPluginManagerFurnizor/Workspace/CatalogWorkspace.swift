import SwiftUI
import GDCPluginManagerCore

extension Notification.Name {
    /// Un editor de catalog și-a reîncărcat lista (după deschidere, publicare sau ștergere).
    static let furnizorCatalogChanged = Notification.Name("furnizorCatalogChanged")
}

/// Tipurile de conținut din domeniul Catalog (Faza 5, V1): toate folosesc același spațiu de
/// lucru — tabel central + editorul existent în inspectorul lateral.
enum CatalogContentType: String, CaseIterable, Identifiable {
    case products, downloads, courses, educational, tutorials, events, apps, audio,
         partnerOffers, bundles, partnerStores, serviceCenters, community
    var id: String { rawValue }

    var title: String {
        switch self {
        case .products: return "Produse"
        case .downloads: return "Resurse download"
        case .courses: return "Cursuri"
        case .educational: return "Materiale"
        case .tutorials: return "Tutoriale"
        case .events: return "Evenimente"
        case .apps: return "Aplicații"
        case .audio: return "Audio"
        case .partnerOffers: return "Oferte parteneri"
        case .bundles: return "Pachete / Bundle-uri"
        case .partnerStores: return "Magazine partenere"
        case .serviceCenters: return "Service & Reparații"
        case .community: return "Comunitate"
        }
    }

    var symbol: String {
        switch self {
        case .products: return "shippingbox"
        case .downloads: return "arrow.down.circle"
        case .courses: return "graduationcap"
        case .educational: return "book"
        case .tutorials: return "play.rectangle"
        case .events: return "calendar"
        case .apps: return "square.grid.2x2"
        case .audio: return "waveform"
        case .partnerOffers: return "tag"
        case .bundles: return "shippingbox.and.arrow.backward"
        case .partnerStores: return "storefront"
        case .serviceCenters: return "wrench.and.screwdriver"
        case .community: return "person.2.wave.2"
        }
    }
}

/// Un rând din tabel — doar citire; editarea rămâne în editorul tipului.
struct CatalogRow: Identifiable, Hashable {
    let id: String
    let name: String
    let kind: String
    let version: String
    let support: String
    let isActive: Bool

    var status: String { isActive ? "Publicat" : "Programat / expirat" }

    static func rows(for type: CatalogContentType, in c: Catalog) -> [CatalogRow] {
        func row(_ id: String, _ name: String, _ kind: String = "", _ version: String = "", _ support: String = "", _ active: Bool?) -> CatalogRow {
            CatalogRow(id: id, name: name, kind: kind, version: version, support: support, isActive: active ?? true)
        }
        switch type {
        case .products:
            return (c.items + c.scriptItems).map {
                row($0.id, $0.name, $0.type.label, $0.version,
                    $0.isFree ? ($0.isTrial ? "Probă" : "Gratuit") : "Donație \($0.effectivePriceEUR.formatted(.currency(code: "EUR")))",
                    $0.scheduling?.isActiveNow)
            }
        case .downloads:
            return (c.downloadableResources + c.pdfResources + c.scriptResources).map { row($0.id, $0.name, $0.category.rawValue, "", "", $0.scheduling?.isActiveNow) }
        case .courses: return c.courses.map { row($0.id, $0.name, "", "", "", $0.scheduling?.isActiveNow) }
        case .educational: return c.educationalResources.map { row($0.id, $0.name, "", "", "", $0.scheduling?.isActiveNow) }
        case .tutorials: return c.tutorials.map { row($0.id, $0.title, "", "", "", $0.scheduling?.isActiveNow) }
        case .events: return c.events.map { row($0.id, $0.title, "", "", "", $0.scheduling?.isActiveNow) }
        case .apps: return c.apps.map { row($0.id, $0.name, "", "", "", $0.scheduling?.isActiveNow) }
        case .audio: return c.audioTracks.map { row($0.id, $0.name, "", "", "", $0.scheduling?.isActiveNow) }
        case .partnerOffers: return c.partnerOffers.map { row($0.id, $0.brandName, "", "", "", $0.scheduling?.isActiveNow) }
        case .bundles: return c.productBundles.map { row($0.id, $0.name, "", "", "", $0.scheduling?.isActiveNow) }
        case .partnerStores: return c.partnerStores.map { row($0.id, $0.name, "", "", "", $0.scheduling?.isActiveNow) }
        case .serviceCenters: return c.serviceCenters.map { row($0.id, $0.name, "", "", "", $0.scheduling?.isActiveNow) }
        case .community: return c.communityChannels.map { row($0.id, $0.title, $0.kind.rawValue, "", "", nil) }
        }
    }
}

/// Spațiul de lucru al unui tip de conținut: tabel nativ (sortat, căutabil) + editorul
/// existent în inspectorul lateral, redimensionabil. Suprafețe opace (DESIGN_SYSTEM.md, Furnizor).
struct CatalogWorkspace: View {
    let type: CatalogContentType

    @State private var rows: [CatalogRow] = []
    @State private var selection: String?
    @State private var search = ""
    @State private var showEditor = true
    @State private var loadError: String?
    @State private var pendingPublish: PendingPublish?

    private var filtered: [CatalogRow] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        let base = q.isEmpty ? rows : rows.filter { $0.name.lowercased().contains(q) || $0.id.lowercased().contains(q) }
        return base.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        VStack(spacing: 0) {
            if let loadError {
                Text(loadError)
                    .font(GDCTokens.Typography.metadata)
                    .foregroundStyle(GDCTokens.Palette.error)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(GDCTokens.Space.s)
            }
            Table(filtered, selection: $selection) {
                TableColumn("Nume") { Text($0.name).fontWeight(.medium).lineLimit(1) }
                    .width(min: 160, ideal: 260)
                // Coloane fixe (condițiile în Table cer macOS 14.4); rămân goale unde tipul n-are câmpul.
                TableColumn("Tip") { Text($0.kind).foregroundStyle(GDCTokens.Palette.textSecondary) }
                    .width(min: 50, ideal: 80)
                TableColumn("Versiune") { Text($0.version).font(GDCTokens.Typography.numeric).foregroundStyle(GDCTokens.Palette.textSecondary) }
                    .width(min: 50, ideal: 70)
                TableColumn("Susținere") { Text($0.support).foregroundStyle(GDCTokens.Palette.textSecondary) }
                    .width(min: 60, ideal: 110)
                TableColumn("Stare") { row in
                    StatusPill(text: row.status, color: row.isActive ? GDCTokens.Palette.success : GDCTokens.Palette.warning)
                }
                .width(min: 90, ideal: 130)
                TableColumn("ID") { Text($0.id).font(GDCTokens.Typography.code).foregroundStyle(GDCTokens.Palette.textTertiary).lineLimit(1) }
                    .width(min: 80, ideal: 160)
            }
            .overlay {
                if rows.isEmpty && loadError == nil {
                    Text("Nimic publicat încă în „\(type.title)”. Folosește „+ Nou”.")
                        .font(GDCTokens.Typography.secondary)
                        .foregroundStyle(GDCTokens.Palette.textSecondary)
                }
            }
        }
        .searchable(text: $search, placement: .toolbar, prompt: "Caută în \(type.title.lowercased())")
        .navigationTitle("Catalog · \(type.title)")
        .toolbar {
            ToolbarItemGroup {
                Button {
                    selection = nil
                    showEditor = true
                } label: { Label("Nou", systemImage: "plus") }
                .help("Formular gol pentru o intrare nouă")
                Button { showEditor.toggle() } label: { Label("Editor", systemImage: "sidebar.right") }
                    .help(showEditor ? "Ascunde editorul" : "Arată editorul")
            }
        }
        .inspector(isPresented: $showEditor) {
            editor
                .environment(\.publishGate, PublishGate { title, action in pendingPublish = PendingPublish(title: title, action: action) })
                .inspectorColumnWidth(min: 420, ideal: 500, max: 820)
        }
        .sheet(item: $pendingPublish) { pending in
            PublishConfirmationSheet(pending: pending) { pendingPublish = nil }
        }
        .onChange(of: selection) { _, id in if id != nil { showEditor = true } }
        .onAppear {
            reload()
            #if DEBUG
            // `-FurnizorSelectID <id>`: selectează un rând la pornire (verificarea fluxului tabel → editor).
            if let id = UserDefaults.standard.string(forKey: "FurnizorSelectID"), rows.contains(where: { $0.id == id }) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { selection = id }
            }
            // `-FurnizorShowPublishSheet YES`: foaia de confirmare cu o acțiune goală (capturi; nu publică nimic).
            if UserDefaults.standard.bool(forKey: "FurnizorShowPublishSheet") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    pendingPublish = PendingPublish(title: rows.first?.name ?? "Test") { DiagnosticLog.write("workspace", "DEBUG: foaie de publicare închisă fără acțiune") }
                }
            }
            #endif
        }
        .onReceive(NotificationCenter.default.publisher(for: .furnizorCatalogChanged)) { _ in reload() }
    }

    @ViewBuilder
    private var editor: some View {
        switch type {
        case .products: PublishView(workspaceSelection: $selection)
        case .downloads: PublishDownloadableResourceView(workspaceSelection: $selection)
        case .courses: PublishCourseView(workspaceSelection: $selection)
        case .educational: PublishEducationalResourceView(workspaceSelection: $selection)
        case .tutorials: PublishTutorialView(workspaceSelection: $selection)
        case .events: PublishEventView(workspaceSelection: $selection)
        case .apps: PublishAppView(workspaceSelection: $selection)
        case .audio: PublishAudioView(workspaceSelection: $selection)
        case .partnerOffers: PublishPartnerOfferView(workspaceSelection: $selection)
        case .bundles: PublishBundleView(workspaceSelection: $selection)
        case .partnerStores: PublishPartnerStoreView(workspaceSelection: $selection)
        case .serviceCenters: PublishServiceCenterView(workspaceSelection: $selection)
        case .community: PublishCommunityChannelView(workspaceSelection: $selection)
        }
    }

    private func reload() {
        do {
            rows = CatalogRow.rows(for: type, in: try CatalogEditor.load())
            loadError = nil
            // Intrarea selectată a fost ștearsă → formular gol, nu o selecție fantomă.
            if let id = selection, !rows.contains(where: { $0.id == id }) { selection = nil }
        } catch {
            loadError = "Catalogul local nu a putut fi citit: \(error.localizedDescription)"
            DiagnosticLog.write("workspace", "catalog load failed: \(error)")
        }
    }
}

/// Insignă de stare opacă pentru tabele (fără material — DESIGN_SYSTEM.md, Furnizor).
struct StatusPill: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, GDCTokens.Space.s)
            .frame(height: GDCTokens.Size.badgeHeight)
            .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: GDCTokens.Radius.badge))
            .accessibilityLabel(text)
    }
}
