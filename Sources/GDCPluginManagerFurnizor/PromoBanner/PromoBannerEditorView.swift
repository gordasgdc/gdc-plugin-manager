import SwiftUI
import AppKit
import UniformTypeIdentifiers
import GDCPluginManagerCore

/// Prețuri & Oferte → Bannere (Faza 5): campanii programate cu trei moduri, texte RO/EN/ES,
/// imagini Light/Dark validate local și previzualizare cu randarea reală din client.
/// „Banner clasic” = editorul vechi, neschimbat (bannerul existent rămâne compatibil).
struct PromoBannerEditorView: View {
    enum Tab: String, CaseIterable { case campaigns = "Campanii", classic = "Banner clasic" }
    @State private var tab: Tab = .campaigns

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $tab) { ForEach(Tab.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                .pickerStyle(.segmented).labelsHidden().frame(maxWidth: 320)
                .padding(GDCTokens.Space.s)
            Divider()
            switch tab {
            case .campaigns: CampaignsEditor()
            case .classic: LaunchBannerManagerView()
            }
        }
    }
}

/// O imagine aleasă local, validată și optimizată, încă nepublicată.
private struct PendingImage {
    let output: BannerImageProcessor.Output
    let image: NSImage
}

private enum ImageSlot: String, CaseIterable, Identifiable {
    case light, dark, wideLight, wideDark
    var id: String { rawValue }
    var title: String {
        switch self {
        case .light: "Imagine Light"
        case .dark: "Imagine Dark (opțional)"
        case .wideLight: "Lată Light (opțional, ≥ 900 pt)"
        case .wideDark: "Lată Dark (opțional)"
        }
    }
    func spec(for mode: PromoBannerMode) -> PromoBannerSpec.Slot {
        switch self {
        case .light, .dark: mode == .imageText ? .split : .standard
        case .wideLight, .wideDark: .wide
        }
    }
    func path(in c: PromoBannerCampaign) -> String? {
        switch self { case .light: c.imagePath; case .dark: c.imagePathDark; case .wideLight: c.imagePathWide; case .wideDark: c.imagePathWideDark }
    }
    func set(_ v: String?, in c: inout PromoBannerCampaign) {
        switch self { case .light: c.imagePath = v; case .dark: c.imagePathDark = v; case .wideLight: c.imagePathWide = v; case .wideDark: c.imagePathWideDark = v }
    }
}

private struct CampaignsEditor: View {
    @State private var config = LaunchBannerConfig()
    @State private var campaigns: [PromoBannerCampaign] = []
    @State private var selectedID: String?
    @State private var language = "ro"
    @State private var pending: [String: PendingImage] = [:]         // "<campanie>/<slot>"
    @State private var remote: [String: NSImage] = [:]               // cale → imagine publicată (previzualizare)
    @State private var slotErrors: [String: String] = [:]
    @State private var previewWidth: CGFloat = 760
    @State private var previewDark = true
    @State private var loadError: String?
    @State private var status: String?
    @State private var isBusy = false
    @State private var pendingPublish: PendingPublish?

    private var index: Int? { campaigns.firstIndex { $0.id == selectedID } }
    private var overlaps: [(PromoBannerCampaign, PromoBannerCampaign)] { LaunchBannerConfig.overlappingCampaigns(campaigns) }
    private var incomplete: [PromoBannerCampaign] {
        campaigns.filter { c in !completeWithPending(c) }
    }

    var body: some View {
        HSplitView {
            list.frame(minWidth: 220, idealWidth: 250, maxWidth: 320)
            form.frame(minWidth: 400, idealWidth: 440)
            preview.frame(minWidth: 380)
        }
        .onAppear(perform: reload)
        .sheet(item: $pendingPublish) { p in PublishConfirmationSheet(pending: p) { pendingPublish = nil } }
    }

    // MARK: Lista

    private var list: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Campanii").font(GDCTokens.Typography.sectionTitle)
                Spacer()
                Button { addCampaign() } label: { Label("Campanie nouă", systemImage: "plus") }
                    .labelStyle(.iconOnly).help("Campanie nouă")
            }
            .padding(GDCTokens.Space.m)
            Divider()
            List(selection: $selectedID) {
                ForEach(campaigns) { c in
                    VStack(alignment: .leading, spacing: GDCTokens.Space.xxs) {
                        Text(c.name.isEmpty ? "Fără nume" : c.name).fontWeight(.medium)
                        HStack(spacing: GDCTokens.Space.xs) {
                            StatusPill(text: statusText(c), color: statusColor(c))
                            Text(modeTitle(c.mode)).font(GDCTokens.Typography.caption).foregroundStyle(GDCTokens.Palette.textSecondary)
                        }
                    }
                    .tag(c.id)
                    .contextMenu { Button("Șterge campania", role: .destructive) { remove(c.id) } }
                }
            }
            Divider()
            Toggle("Bannerul e activ la clienți", isOn: $config.enabled).padding(GDCTokens.Space.m)
        }
        .background(GDCTokens.Palette.surface)
    }

    // MARK: Formular

    @ViewBuilder private var form: some View {
        if let i = index {
            ScrollView {
                VStack(alignment: .leading, spacing: GDCTokens.Space.l) {
                    TextField("Numele campaniei (intern, ex. Crăciun 2026)", text: $campaigns[i].name).textFieldStyle(.roundedBorder)
                    labeled("Mod") {
                        Picker("", selection: $campaigns[i].mode) {
                            Text("Doar text").tag(PromoBannerMode.text)
                            Text("Imagine + text").tag(PromoBannerMode.imageText)
                            Text("Doar imagine").tag(PromoBannerMode.image)
                        }.pickerStyle(.segmented).labelsHidden()
                    }
                    labeled(campaigns[i].mode == .image ? "Descriere accesibilă (VoiceOver)" : "Text") {
                        Picker("", selection: $language) { Text("RO").tag("ro"); Text("EN").tag("en"); Text("ES").tag("es") }
                            .pickerStyle(.segmented).labelsHidden().frame(maxWidth: 180)
                        TextField("Rând sus, scurt (ex. CRĂCIUN)", text: textBinding(i, \.top)).textFieldStyle(.roundedBorder)
                        TextField("Mesaj principal", text: textBinding(i, \.main)).textFieldStyle(.roundedBorder)
                        Text(language == "ro" ? "RO e obligatoriu la modurile cu text; EN/ES cad pe RO dacă lipsesc."
                                              : "Opțional — gol = se afișează textul RO.")
                            .font(GDCTokens.Typography.caption).foregroundStyle(GDCTokens.Palette.textSecondary)
                    }
                    if campaigns[i].mode != .text {
                        labeled("Imagini") {
                            ForEach(slots(for: campaigns[i].mode)) { slot in slotRow(slot, campaignIndex: i) }
                        }
                    }
                    labeled("Program") { SchedulingPicker(scheduling: $campaigns[i].scheduling).id(campaigns[i].id) }
                    TextField("Link la clic (opțional, https://…)", text: Binding(get: { campaigns[i].linkURL ?? "" },
                                                                                   set: { campaigns[i].linkURL = $0.isEmpty ? nil : $0 }))
                        .textFieldStyle(.roundedBorder)
                    validationBox
                    HStack {
                        if isBusy { ProgressView().controlSize(.small) }
                        if let status { Text(status).font(GDCTokens.Typography.metadata).foregroundStyle(GDCTokens.Palette.textSecondary) }
                        Spacer()
                        Button("Publică…") { pendingPublish = PendingPublish(title: "Bannere promoționale (\(campaigns.count) campanii)") { await publish() } }
                            .buttonStyle(GDCButtonStyle(role: .primary))
                            .disabled(isBusy || !overlaps.isEmpty || !incomplete.isEmpty)
                    }
                }
                .padding(GDCTokens.Space.l)
            }
        } else {
            VStack(spacing: GDCTokens.Space.s) {
                if let loadError { Text(loadError).foregroundStyle(GDCTokens.Palette.error) }
                Text(campaigns.isEmpty ? "Nicio campanie. Fără campanii, clienții văd bannerul clasic." : "Alege o campanie din listă.")
                    .foregroundStyle(GDCTokens.Palette.textSecondary)
                Button("Campanie nouă") { addCampaign() }.buttonStyle(GDCButtonStyle(role: .secondary))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func slotRow(_ slot: ImageSlot, campaignIndex i: Int) -> some View {
        let c = campaigns[i], key = "\(c.id)/\(slot.rawValue)", spec = slot.spec(for: c.mode)
        return VStack(alignment: .leading, spacing: GDCTokens.Space.xxs) {
            HStack {
                Text(slot.title).font(GDCTokens.Typography.label)
                Text("\(Int(spec.recommended.width))×\(Int(spec.recommended.height)) (\(Int(spec.aspect)):1)")
                    .font(GDCTokens.Typography.caption).foregroundStyle(GDCTokens.Palette.textTertiary)
                Spacer()
                Button("Alege PNG/JPEG/SVG…") { pick(slot, campaignIndex: i) }.buttonStyle(GDCButtonStyle(role: .secondary))
                if pending[key] != nil || slot.path(in: c) != nil {
                    Button("Scoate") { pending[key] = nil; slotErrors[key] = nil; slot.set(nil, in: &campaigns[i]) }
                        .buttonStyle(GDCButtonStyle(role: .plain))
                }
            }
            if let p = pending[key] {
                Text("✓ \(Int(p.output.pixelSize.width))×\(Int(p.output.pixelSize.height)) px · \(p.output.bytes / 1000) KB (nepublicată)")
                    .font(GDCTokens.Typography.caption).foregroundStyle(GDCTokens.Palette.success)
            } else if let path = slot.path(in: c) {
                Text("Publicată: \(path)").font(GDCTokens.Typography.caption).foregroundStyle(GDCTokens.Palette.textSecondary).lineLimit(1)
            }
            if let err = slotErrors[key] {
                Text(err).font(GDCTokens.Typography.caption).foregroundStyle(GDCTokens.Palette.error)
            }
        }
    }

    @ViewBuilder private var validationBox: some View {
        if !overlaps.isEmpty || !incomplete.isEmpty {
            VStack(alignment: .leading, spacing: GDCTokens.Space.xs) {
                ForEach(overlaps.indices, id: \.self) { k in
                    Label("„\(overlaps[k].0.name)” și „\(overlaps[k].1.name)” se suprapun în timp — ajustează programul.",
                          systemImage: "exclamationmark.triangle")
                }
                ForEach(incomplete) { c in
                    Label("„\(c.name.isEmpty ? "Fără nume" : c.name)” e incompletă pentru modul ales (text RO și/sau imagine).",
                          systemImage: "exclamationmark.triangle")
                }
            }
            .font(GDCTokens.Typography.metadata)
            .foregroundStyle(GDCTokens.Palette.warning)
        }
    }

    // MARK: Previzualizare

    private var preview: some View {
        VStack(alignment: .leading, spacing: GDCTokens.Space.m) {
            HStack {
                Text("Previzualizare client").font(GDCTokens.Typography.sectionTitle)
                Spacer()
                Picker("", selection: $previewWidth) {
                    Text("470").tag(CGFloat(470)); Text("760").tag(CGFloat(760)); Text("1150").tag(CGFloat(1150))
                }.pickerStyle(.segmented).labelsHidden().frame(maxWidth: 200)
                .help("Lățimea zonei de conținut: fereastra minimă (470), medie (760), lată (1150) — în puncte")
                Toggle("Dark", isOn: $previewDark).toggleStyle(.switch)
            }
            if let i = index {
                ScrollView(.horizontal) {
                    VStack(spacing: 0) {
                        Color.clear.frame(height: 80)
                        PromoBannerView(campaign: campaigns[i], language: language, images: images(for: campaigns[i]))
                    }
                    .frame(width: previewWidth)
                    .background(.background)  // fundalul ferestrei, după tema forțată mai jos
                    .environment(\.colorScheme, previewDark ? .dark : .light)
                    .clipShape(RoundedRectangle(cornerRadius: GDCTokens.Radius.inset))
                    .overlay(RoundedRectangle(cornerRadius: GDCTokens.Radius.inset).strokeBorder(GDCTokens.Palette.separator))
                }
                Text(previewNote(campaigns[i]))
                    .font(GDCTokens.Typography.caption).foregroundStyle(GDCTokens.Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(GDCTokens.Space.l)
    }

    private func previewNote(_ c: PromoBannerCampaign) -> String {
        switch c.mode {
        case .text: return "Bandă de text, înălțime fixă \(Int(PromoBannerSpec.textBandHeight)) pt."
        case .imageText: return "Imaginea (3:1) umple panoul din stânga cu decupare centrală; textul rămâne separat."
        case .image:
            let l = PromoBannerSpec.imageOnlyLayout(width: previewWidth, hasWide: images(for: c).wideLight != nil)
            return "Imaginea e afișată integral (fără decupare): \(l.useWide ? "varianta lată 12:1" : "varianta standard 6:1"), înălțime \(Int(l.height)) pt la \(Int(previewWidth)) pt. Clienții ≤ 1.40 nu văd acest mod."
        }
    }

    // MARK: Acțiuni

    private func slots(for mode: PromoBannerMode) -> [ImageSlot] { mode == .image ? ImageSlot.allCases : [.light, .dark] }

    private func textBinding(_ i: Int, _ kp: WritableKeyPath<PromoBannerText, String>) -> Binding<String> {
        Binding(get: { campaigns[i].texts[language]?[keyPath: kp] ?? "" },
                set: { var t = campaigns[i].texts[language] ?? PromoBannerText(); t[keyPath: kp] = $0; campaigns[i].texts[language] = t })
    }

    private func images(for c: PromoBannerCampaign) -> PromoBannerImages {
        func img(_ slot: ImageSlot) -> NSImage? {
            pending["\(c.id)/\(slot.rawValue)"]?.image ?? slot.path(in: c).flatMap { remote[$0] }
        }
        return PromoBannerImages(light: img(.light), dark: img(.dark), wideLight: img(.wideLight), wideDark: img(.wideDark))
    }

    private func completeWithPending(_ c: PromoBannerCampaign) -> Bool {
        var probe = c
        if pending["\(c.id)/light"] != nil { probe.imagePath = "pending" }
        return probe.hasRequiredContent
    }

    private func addCampaign() {
        let c = PromoBannerCampaign(id: "c-\(Int(Date().timeIntervalSince1970))", name: "Campanie nouă")
        campaigns.append(c)
        selectedID = c.id
    }

    private func remove(_ id: String) {
        campaigns.removeAll { $0.id == id }
        pending = pending.filter { !$0.key.hasPrefix("\(id)/") }
        if selectedID == id { selectedID = campaigns.first?.id }
    }

    private func pick(_ slot: ImageSlot, campaignIndex i: Int) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .svg]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let c = campaigns[i], key = "\(c.id)/\(slot.rawValue)"
        do {
            let out = try BannerImageProcessor.process(url, slot: slot.spec(for: c.mode))
            guard let image = NSImage(contentsOf: out.url) else { throw BannerImageProcessor.Failure.unreadable }
            pending[key] = PendingImage(output: out, image: image)
            slotErrors[key] = nil
        } catch {
            slotErrors[key] = error.localizedDescription
            DiagnosticLog.write("PromoBanner", "imagine respinsă (\(slot.rawValue)): \(error)")
        }
    }

    private func reload() {
        #if DEBUG
        // `-PromoBannerFixture YES`: trei campanii de test cu imagini generate, trecute prin validarea reală.
        if UserDefaults.standard.bool(forKey: "PromoBannerFixture") { loadFixtures(); return }
        #endif
        do {
            config = try LaunchBannerEditor.load()
            campaigns = config.campaigns ?? []
            selectedID = campaigns.first?.id
            loadError = nil
            Task { await loadRemoteImages() }
        } catch {
            loadError = "Nu am putut citi launch-banner.json: \(error.localizedDescription)"
        }
    }

    /// Imaginile deja publicate, doar pentru previzualizare (asincron, o singură dată per cale).
    private func loadRemoteImages() async {
        let paths = Set(campaigns.flatMap { c in ImageSlot.allCases.compactMap { $0.path(in: c) } })
        for path in paths where remote[path] == nil {
            guard let url = CatalogAssets.imageURL(for: path),
                  let (data, _) = try? await URLSession.shared.data(from: url), let img = NSImage(data: data) else { continue }
            remote[path] = img
        }
    }

    private func publish() async {
        isBusy = true
        status = nil
        defer { isBusy = false }
        var updated = campaigns
        let pendingNow = pending
        let base = config
        do {
            let result: LaunchBannerConfig = try await Task.detached {
                for (ci, c) in updated.enumerated() {
                    for slot in ImageSlot.allCases {
                        guard let p = pendingNow["\(c.id)/\(slot.rawValue)"] else { continue }
                        let path = try CoverImageStore.commit(.local(processed: p.output.url, savings: ""),
                                                              id: "banner-\(c.id)-\(slot.rawValue)", previous: slot.path(in: c))
                        slot.set(path, in: &updated[ci])
                    }
                }
                var cfg = base
                cfg.campaigns = updated
                cfg = cfg.withLegacyFallback()
                try LaunchBannerEditor.publish(cfg, message: "Bannere promoționale: \(updated.count) campanii")
                return cfg
            }.value
            config = result
            campaigns = result.campaigns ?? []
            pending = [:]
            status = "Publicat."
            await loadRemoteImages()
        } catch {
            status = "Publicarea a eșuat: \(error.localizedDescription)"
            DiagnosticLog.write("PromoBanner", "publicare eșuată: \(error)")
        }
    }

    #if DEBUG
    private func loadFixtures() {
        campaigns = PromoBannerMode.allCases.map { mode in
            var c = PromoBannerFixtures.campaign(mode)
            c.imagePath = nil
            let day: TimeInterval = 86_400, base = Date().addingTimeInterval(-day)
            let k = Double(PromoBannerMode.allCases.firstIndex(of: mode)!)
            c.scheduling = Scheduling(startDate: base.addingTimeInterval(k * 10 * day), endDate: base.addingTimeInterval((k * 10 + 9) * day))
            return c
        }
        for c in campaigns where c.mode != .text {
            let specs: [(ImageSlot, PromoBannerSpec.Slot, Bool)] = c.mode == .image
                ? [(.light, .standard, false), (.dark, .standard, true), (.wideLight, .wide, false), (.wideDark, .wide, true)]
                : [(.light, .split, false), (.dark, .split, true)]
            for (slot, spec, dark) in specs {
                let img = PromoBannerFixtures.image(slot: spec, dark: dark, withText: c.mode == .image)
                let url = FileManager.default.temporaryDirectory.appendingPathComponent("fixture-\(c.id)-\(slot.rawValue).png")
                if let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff), let png = rep.representation(using: .png, properties: [:]) {
                    try? png.write(to: url)
                }
                do {
                    let out = try BannerImageProcessor.process(url, slot: spec)
                    if let image = NSImage(contentsOf: out.url) { pending["\(c.id)/\(slot.rawValue)"] = PendingImage(output: out, image: image) }
                } catch {
                    slotErrors["\(c.id)/\(slot.rawValue)"] = error.localizedDescription
                }
            }
        }
        selectedID = UserDefaults.standard.string(forKey: "PromoBannerFixtureSelect").map { "fixture-\($0)" } ?? campaigns.last?.id
        config.enabled = true
    }
    #endif

    // MARK: Ajutoare

    private func labeled<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: GDCTokens.Space.xs) {
            Text(title).font(GDCTokens.Typography.label).foregroundStyle(GDCTokens.Palette.textSecondary)
            content()
        }
    }

    private func modeTitle(_ m: PromoBannerMode) -> String {
        switch m { case .text: "Doar text"; case .imageText: "Imagine + text"; case .image: "Doar imagine" }
    }

    private func statusText(_ c: PromoBannerCampaign) -> String {
        let now = Date()
        if let end = c.scheduling?.endDate, end < now { return "Expirată" }
        if let start = c.scheduling?.startDate, start > now { return "Programată" }
        return "Activă"
    }

    private func statusColor(_ c: PromoBannerCampaign) -> Color {
        switch statusText(c) { case "Activă": GDCTokens.Palette.success; case "Programată": GDCTokens.Palette.warning; default: GDCTokens.Palette.textSecondary }
    }
}
