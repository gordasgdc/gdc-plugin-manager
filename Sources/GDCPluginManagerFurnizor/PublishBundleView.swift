import SwiftUI
import GDCPluginManagerCore

/// Gestionează secțiunea "Pachete/Bundle-uri" — Etapa 9 din Planul
/// Integrat de Upgrade v2.0 (2026-08-29, idee a lui Cristi: "combin
/// produse, unul sau mai multe, să le vând la bulk, la super ofertă").
/// Bifezi produse existente (din Produse/Resurse Download/Cursuri),
/// alegi un preț total pentru pachet — nimic de instalat/comprimat aici.
struct PublishBundleView: View {
    @State private var existingBundles: [ProductBundle] = []
    @State private var editingID: String?

    @State private var id = ""
    @State private var name = ""
    @State private var description = ""
    @State private var bundlePriceText = ""
    @State private var selectedItems: Set<BundleItemRef> = []
    @State private var youtubeURL = ""
    @State private var facebookURL = ""
    @State private var instagramURL = ""
    @State private var tiktokURL = ""
    @State private var socialYoutubeURL = ""
    @State private var scheduling: Scheduling?
    @State private var coverSelection: CoverImageSelection = .none

    // Sursă pentru bifare — toate produsele/resursele/cursurile publicate.
    @State private var catalogItems: [PluginItem] = []
    @State private var downloadResources: [DownloadableResource] = []
    @State private var courses: [Course] = []
    @State private var audioTracks: [AudioTrack] = []
    @State private var apps: [AppLink] = []
    @State private var educationalResources: [EducationalResource] = []

    @State private var isBusy = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var pendingDelete: ProductBundle?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Pachete / Bundle-uri").font(.title2).fontWeight(.semibold)
                Text("Grupează produse existente (Produse, Resurse Download, Cursuri) sub un singur preț total. Achiziția rămâne prin WhatsApp, ca la orice produs — licențele individuale se generează în continuare separat, per produs inclus.")
                    .font(.caption).foregroundStyle(.secondary)

                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        TextField("ID pachet (ex. pachet-black-friday-2026, nu se mai poate schimba)", text: $id)
                            .textFieldStyle(.roundedBorder)
                            .disabled(editingID != nil)
                        TextField("Nume pachet", text: $name).textFieldStyle(.roundedBorder)
                        TextEditor(text: $description)
                            .frame(minHeight: 70)
                            .overlay(alignment: .topLeading) {
                                if description.isEmpty {
                                    Text("Descrierea pachetului…")
                                        .foregroundStyle(.secondary)
                                        .padding(.top, 8).padding(.leading, 5)
                                        .allowsHitTesting(false)
                                }
                            }
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(.separator))
                        TextField("Preț TOTAL pachet (EUR)", text: $bundlePriceText).textFieldStyle(.roundedBorder)
                        if individualTotal > 0 {
                            Text("Sumă individuală (dacă s-ar cumpăra separat): \(individualTotal.formatted(.currency(code: "EUR")))")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        TextField("Link tutorial YouTube (opțional)", text: $youtubeURL).textFieldStyle(.roundedBorder)

                        Divider()
                        Text("Produse incluse (bifează)").font(.subheadline).fontWeight(.medium)
                        itemChecklist(title: "Produse", refs: catalogItems.map { BundleItemRef(kind: .product, id: $0.id) },
                                      labels: Dictionary(uniqueKeysWithValues: catalogItems.map { ($0.id, "\($0.name) — \($0.priceDisplay)") }))
                        itemChecklist(title: "Resurse Download", refs: downloadResources.map { BundleItemRef(kind: .download, id: $0.id) },
                                      labels: Dictionary(uniqueKeysWithValues: downloadResources.map { ($0.id, "\($0.name) — \($0.priceDisplay)") }))
                        itemChecklist(title: "Cursuri", refs: courses.map { BundleItemRef(kind: .course, id: $0.id) },
                                      labels: Dictionary(uniqueKeysWithValues: courses.map { ($0.id, $0.name) }))
                        itemChecklist(title: "Audio", refs: audioTracks.map { BundleItemRef(kind: .audio, id: $0.id) },
                                      labels: Dictionary(uniqueKeysWithValues: audioTracks.map { ($0.id, $0.name) }))
                        // Aplicații/Materiale — confirmat explicit 2026-08-29:
                        // "toate aplicații sunt făcute de mine, materiale la
                        // fel" (spre deosebire de Oferte Parteneri/Evenimente,
                        // conținut al unor terți/informativ, excluse deliberat).
                        itemChecklist(title: "Aplicații", refs: apps.map { BundleItemRef(kind: .app, id: $0.id) },
                                      labels: Dictionary(uniqueKeysWithValues: apps.map { ($0.id, $0.name) }))
                        itemChecklist(title: "Materiale", refs: educationalResources.map { BundleItemRef(kind: .material, id: $0.id) },
                                      labels: Dictionary(uniqueKeysWithValues: educationalResources.map { ($0.id, $0.name) }))

                        DisclosureGroup("Rețele sociale (opțional)") {
                            VStack(alignment: .leading, spacing: 8) {
                                TextField("Facebook", text: $facebookURL).textFieldStyle(.roundedBorder)
                                TextField("YouTube", text: $socialYoutubeURL).textFieldStyle(.roundedBorder)
                                TextField("Instagram", text: $instagramURL).textFieldStyle(.roundedBorder)
                                TextField("TikTok", text: $tiktokURL).textFieldStyle(.roundedBorder)
                            }
                            .padding(.top, 6)
                        }
                    }
                    .padding(8)
                }

                CoverImagePicker(preset: .cover, selection: $coverSelection)
                SchedulingPicker(scheduling: $scheduling)

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                if let successMessage {
                    Label(successMessage, systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                }

                HStack {
                    if isBusy { ProgressView().controlSize(.small) }
                    Button(editingID == nil ? "Publică" : "Actualizează") { Task { await publish() } }
                        .disabled(isBusy || !isFormValid)
                    if editingID != nil {
                        Button("Pachet nou") { clearForm() }
                    }
                }
                if !isFormValid && !isBusy {
                    Text(validationHint).font(.caption).foregroundStyle(.orange)
                }

                if !existingBundles.isEmpty {
                    Divider()
                    Text("Pachete publicate").font(.headline)
                    ForEach(existingBundles) { bundle in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(bundle.name).fontWeight(.medium)
                                Text("\(bundle.items.count) produse — \(bundle.bundlePriceDisplay)")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Editează") { load(bundle) }
                            Button("Șterge", role: .destructive) { pendingDelete = bundle }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(24)
            .frame(maxWidth: 640, alignment: .leading)
        }
        .confirmationDialog(
            "Ștergi definitiv pachetul „\(pendingDelete?.name ?? "")”?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Șterge definitiv", role: .destructive) {
                let toDelete = pendingDelete
                Task { await delete(toDelete) }
            }
            Button("Anulează", role: .cancel) { pendingDelete = nil }
        }
        .task { loadExisting() }
    }

    @ViewBuilder
    private func itemChecklist(title: String, refs: [BundleItemRef], labels: [String: String]) -> some View {
        if !refs.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                ForEach(refs, id: \.self) { ref in
                    Toggle(labels[ref.id] ?? ref.id, isOn: Binding(
                        get: { selectedItems.contains(ref) },
                        set: { isOn in
                            if isOn { selectedItems.insert(ref) } else { selectedItems.remove(ref) }
                        }
                    ))
                    .toggleStyle(.checkbox)
                    .font(.caption)
                }
            }
        }
    }

    private var individualTotal: Double {
        var total: Double = 0
        for ref in selectedItems {
            switch ref.kind {
            case .product: total += catalogItems.first { $0.id == ref.id }?.priceEUR ?? 0
            case .download: total += downloadResources.first { $0.id == ref.id }?.priceEUR ?? 0
            case .course: break // cursurile au preț pe opțiune, nu unul singur — nu intră în sumă
            case .audio: break // audio-ul (Etapa 2) e mereu download simplu, fără preț propriu
            case .app, .material: break // fără preț propriu în model
            }
        }
        return total
    }

    private var isFormValid: Bool {
        !id.trimmingCharacters(in: .whitespaces).isEmpty
            && !name.trimmingCharacters(in: .whitespaces).isEmpty
            && Double(bundlePriceText) != nil
            && selectedItems.count >= 2
    }

    private var validationHint: String {
        var missing: [String] = []
        if id.trimmingCharacters(in: .whitespaces).isEmpty { missing.append("ID pachet") }
        if name.trimmingCharacters(in: .whitespaces).isEmpty { missing.append("Nume") }
        if Double(bundlePriceText) == nil { missing.append("Preț total (număr valid)") }
        if selectedItems.count < 2 { missing.append("cel puțin 2 produse bifate") }
        return "Lipsește: " + missing.joined(separator: ", ")
    }

    private func loadExisting() {
        if let catalog = try? CatalogEditor.load() {
            existingBundles = catalog.productBundles.sorted { $0.name < $1.name }
            catalogItems = catalog.items.sorted { $0.name < $1.name }
            downloadResources = catalog.downloadableResources.sorted { $0.name < $1.name }
            courses = catalog.courses.sorted { $0.name < $1.name }
            audioTracks = catalog.audioTracks.sorted { $0.name < $1.name }
            apps = catalog.apps.sorted { $0.name < $1.name }
            educationalResources = catalog.educationalResources.sorted { $0.name < $1.name }
        }
    }

    private func load(_ bundle: ProductBundle) {
        editingID = bundle.id
        id = bundle.id
        name = bundle.name
        description = bundle.description
        bundlePriceText = String(bundle.bundlePriceEUR)
        selectedItems = Set(bundle.items)
        youtubeURL = bundle.youtubeURL ?? ""
        facebookURL = bundle.socialLinks?.facebookURL ?? ""
        instagramURL = bundle.socialLinks?.instagramURL ?? ""
        tiktokURL = bundle.socialLinks?.tiktokURL ?? ""
        socialYoutubeURL = bundle.socialLinks?.youtubeURL ?? ""
        scheduling = bundle.scheduling
        coverSelection = bundle.coverImage.map { .existing($0) } ?? .none
        successMessage = nil
        errorMessage = nil
    }

    private func clearForm() {
        editingID = nil
        id = ""
        name = ""
        description = ""
        bundlePriceText = ""
        selectedItems = []
        youtubeURL = ""
        facebookURL = ""
        instagramURL = ""
        tiktokURL = ""
        socialYoutubeURL = ""
        scheduling = nil
        coverSelection = .none
    }

    private func publish() async {
        errorMessage = nil
        successMessage = nil
        isBusy = true
        defer { isBusy = false }

        func nilIfEmpty(_ s: String) -> String? {
            let t = s.trimmingCharacters(in: .whitespaces)
            return t.isEmpty ? nil : t
        }
        let bundleID = id.trimmingCharacters(in: .whitespaces)
        guard let price = Double(bundlePriceText) else { return }

        do {
            try GitOps.pull(at: RepoCheckoutPaths.publicCatalogRepo)

            let previousCover = existingBundles.first { $0.id == bundleID }?.coverImage
            let coverImage = try CoverImageStore.commit(coverSelection, id: bundleID, previous: previousCover)

            let social = SocialLinks(
                facebookURL: nilIfEmpty(facebookURL), youtubeURL: nilIfEmpty(socialYoutubeURL),
                instagramURL: nilIfEmpty(instagramURL), tiktokURL: nilIfEmpty(tiktokURL)
            )
            let bundle = ProductBundle(
                id: bundleID, name: name, description: description, items: Array(selectedItems),
                bundlePriceEUR: price, coverImage: coverImage, youtubeURL: nilIfEmpty(youtubeURL),
                socialLinks: social.isEmpty ? nil : social, scheduling: scheduling
            )
            try CatalogEditor.upsertBundle(bundle)
            try GitOps.commitAndPush(at: RepoCheckoutPaths.publicCatalogRepo, message: "Pachet: \(bundle.name)", paths: ["docs/catalog.json", "docs/covers"])
            successMessage = "„\(bundle.name)” e publicat — apare la clienți la următorul refresh de catalog."
            clearForm()
            loadExisting()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func delete(_ bundle: ProductBundle?) async {
        guard let bundle else { return }
        pendingDelete = nil
        errorMessage = nil
        successMessage = nil
        isBusy = true
        defer { isBusy = false }

        do {
            try GitOps.pull(at: RepoCheckoutPaths.publicCatalogRepo)
            try CoverImageStore.commit(.none, id: bundle.id, previous: bundle.coverImage)
            try CatalogEditor.removeBundle(id: bundle.id)
            try GitOps.commitAndPush(at: RepoCheckoutPaths.publicCatalogRepo, message: "Sterg pachetul: \(bundle.name)", paths: ["docs/catalog.json", "docs/covers"])
            successMessage = "„\(bundle.name)” a fost șters."
            if editingID == bundle.id { clearForm() }
            loadExisting()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
