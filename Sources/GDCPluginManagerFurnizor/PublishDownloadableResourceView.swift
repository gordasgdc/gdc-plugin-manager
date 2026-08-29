import SwiftUI
import GDCPluginManagerCore

/// Gestionează secțiunile "Resurse Download" (LUT/SFX/VFX/Plugin) — Etapa 2
/// din Planul Integrat de Upgrade v2.0 (2026-08-29, confirmat explicit de
/// Cristi: "produse noi, separate, cu simplu link de download, ca Audio").
/// Modelat 1:1 pe `PublishAudioView`: niciun fișier în
/// `gdc-plugin-manager-files`, nicio licență — doar un link + descriere,
/// scrise direct în `docs/catalog.json`. Diferă de Audio prin selectorul
/// de categorie (LUT/SFX/VFX/Plugin) și câmpurile din Etapa 2
/// (compatibilitate OS, Achiziție/Demo, rețele sociale).
struct PublishDownloadableResourceView: View {
    @State private var existingResources: [DownloadableResource] = []
    @State private var editingID: String?

    @State private var id = ""
    @State private var name = ""
    @State private var description = ""
    @State private var category: DownloadCategory = .lut
    @State private var url = ""
    @State private var youtubeURL = ""
    @State private var supportedOS: SupportedOS = .crossPlatform
    // Licențiere adăugată 2026-08-29 (cerut explicit: "nu am varianta aia
    // de gratuit, plătit, trimite ID mașină, cumpără produsul, WhatsApp").
    // Reutilizează `AccessMode`, definit deja în PublishView.swift.
    @State private var accessMode: AccessMode = .free
    @State private var priceText = "0"
    @State private var promoPriceText = ""
    @State private var purchaseURL = ""
    @State private var demoURL = ""
    @State private var socialForm = SocialLinksFormState()
    /// Coperta resursei. Preset `.icon` — la fel ca la Aplicații/Audio.
    @State private var coverSelection: CoverImageSelection = .none
    @State private var scheduling: Scheduling?

    @State private var isBusy = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var pendingDelete: DownloadableResource?

    private func categoryLabel(_ c: DownloadCategory) -> String {
        switch c {
        case .lut: return "LUT"
        case .sfx: return "Efecte Audio / SFX"
        case .vfx: return "VFX / Overlays"
        case .plugin: return "Plugin"
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Resurse Download (LUT/SFX/VFX/Plugin)").font(.title2).fontWeight(.semibold)
                Text("Download direct — pentru Premiere Pro, Final Cut Pro sau DaVinci Resolve. Nu se auto-instalează nicăieri; clientul descarcă fișierul și îl importă manual.")
                    .font(.caption).foregroundStyle(.secondary)

                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        TextField("ID (ex. lut-wedding-pack, nu se mai poate schimba)", text: $id)
                            .textFieldStyle(.roundedBorder)
                            .disabled(editingID != nil)
                        TextField("Nume", text: $name).textFieldStyle(.roundedBorder)
                        Picker("Categorie", selection: $category) {
                            ForEach(DownloadCategory.allCases) { c in
                                Text(categoryLabel(c)).tag(c)
                            }
                        }
                        .pickerStyle(.segmented)
                        TextField("Link fișier de descărcare (https://…)", text: $url).textFieldStyle(.roundedBorder)
                        TextEditor(text: $description)
                            .frame(minHeight: 80)
                            .overlay(alignment: .topLeading) {
                                if description.isEmpty {
                                    Text("Informații / descriere (format, compatibilitate host, conținut pachet…)")
                                        .foregroundStyle(.secondary)
                                        .padding(.top, 8).padding(.leading, 5)
                                        .allowsHitTesting(false)
                                }
                            }
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(.separator))
                        TextField("Link tutorial YouTube (opțional, nelistat)", text: $youtubeURL).textFieldStyle(.roundedBorder)

                        Picker("Acces", selection: $accessMode) {
                            ForEach(AccessMode.allCases) { mode in
                                Text(mode.label).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        switch accessMode {
                        case .paid:
                            TextField("Preț (EUR, donație)", text: $priceText).textFieldStyle(.roundedBorder)
                            TextField("Sumă promoțională temporară (EUR, opțional — activă doar în intervalul de mai jos)", text: $promoPriceText)
                                .textFieldStyle(.roundedBorder)
                        case .free:
                            Text("Clientul descarcă direct, fără cod de activare.")
                                .font(.caption).foregroundStyle(.secondary)
                        case .trial:
                            Text("Clientul descarcă direct, fără cod — apare cu eticheta „Probă”. Include watermark-ul direct în fișier înainte de publicare.")
                                .font(.caption).foregroundStyle(.secondary)
                        }

                        Picker("Compatibilitate", selection: $supportedOS) {
                            Label("Doar Mac", systemImage: SupportedOS.macOS.badgeSymbol).tag(SupportedOS.macOS)
                            Label("Doar Windows", systemImage: SupportedOS.windows.badgeSymbol).tag(SupportedOS.windows)
                            Label("Ambele platforme", systemImage: SupportedOS.crossPlatform.badgeSymbol).tag(SupportedOS.crossPlatform)
                        }
                        .pickerStyle(.segmented)

                        DisclosureGroup("Linkuri suplimentare & rețele sociale (opțional)") {
                            VStack(alignment: .leading, spacing: 8) {
                                TextField("Link Achiziție/Magazin extern", text: $purchaseURL).textFieldStyle(.roundedBorder)
                                TextField("Link Demo/Preview", text: $demoURL).textFieldStyle(.roundedBorder)
                                SocialLinksFields(state: $socialForm, youtubeLabel: "YouTube (canal, nu tutorialul de mai sus)")
                            }
                            .padding(.top, 6)
                        }
                    }
                    .padding(8)
                }

                CoverImagePicker(preset: .icon, selection: $coverSelection)
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
                        Button("Resursă nouă") { clearForm() }
                    }
                }
                if !isFormValid && !isBusy {
                    Text(validationHint).font(.caption).foregroundStyle(.orange)
                }

                if !existingResources.isEmpty {
                    Divider()
                    Text("Resurse publicate").font(.headline)
                    ForEach(existingResources) { resource in
                        HStack {
                            VStack(alignment: .leading) {
                                HStack(spacing: 6) {
                                    Text(resource.name).fontWeight(.medium)
                                    Text(categoryLabel(resource.category).uppercased())
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(resource.category.tintColor)
                                        .padding(.horizontal, 6).padding(.vertical, 2)
                                        .background(Capsule().fill(resource.category.tintColor.opacity(0.15)))
                                }
                                Text(resource.url).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                            Spacer()
                            Button("Editează") { load(resource) }
                            Button("Șterge", role: .destructive) { pendingDelete = resource }
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
            "Ștergi definitiv „\(pendingDelete?.name ?? "")”?",
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

    private var isFormValid: Bool {
        !id.trimmingCharacters(in: .whitespaces).isEmpty
            && !name.trimmingCharacters(in: .whitespaces).isEmpty
            && URL(string: url) != nil
            && (url.hasPrefix("http://") || url.hasPrefix("https://"))
            && (accessMode != .paid || Double(priceText) != nil)
    }

    /// Explică EXACT ce lipseste — cerut explicit 2026-08-29, dupa ce
    /// butonul "Publică" a ramas dezactivat fara mesaj pe formularul de
    /// Oferte Parteneri (acelasi risc exista si aici).
    private var validationHint: String {
        var missing: [String] = []
        if id.trimmingCharacters(in: .whitespaces).isEmpty { missing.append("ID") }
        if name.trimmingCharacters(in: .whitespaces).isEmpty { missing.append("Nume") }
        if !url.hasPrefix("http://") && !url.hasPrefix("https://") {
            missing.append("Link descărcare (trebuie să înceapă cu http:// sau https://)")
        } else if URL(string: url) == nil {
            missing.append("Link descărcare (format invalid)")
        }
        if accessMode == .paid && Double(priceText) == nil { missing.append("Preț (număr valid)") }
        return "Lipsește: " + missing.joined(separator: ", ")
    }

    private func loadExisting() {
        if let catalog = try? CatalogEditor.load() {
            existingResources = catalog.downloadableResources.sorted { $0.name < $1.name }
        }
    }

    private func load(_ resource: DownloadableResource) {
        editingID = resource.id
        id = resource.id
        name = resource.name
        description = resource.description
        category = resource.category
        url = resource.url
        youtubeURL = resource.youtubeURL ?? ""
        supportedOS = resource.supportedOS
        purchaseURL = resource.purchaseURL ?? ""
        demoURL = resource.demoURL ?? ""
        socialForm = SocialLinksFormState(resource.socialLinks)
        coverSelection = resource.coverImage.map { .existing($0) } ?? .none
        scheduling = resource.scheduling
        accessMode = resource.isTrial ? .trial : (resource.isFree ? .free : .paid)
        priceText = String(resource.priceEUR)
        promoPriceText = resource.promoPriceEUR.map { String($0) } ?? ""
        successMessage = nil
        errorMessage = nil
    }

    private func clearForm() {
        editingID = nil
        id = ""
        name = ""
        description = ""
        category = .lut
        url = ""
        youtubeURL = ""
        supportedOS = .crossPlatform
        purchaseURL = ""
        demoURL = ""
        socialForm.reset()
        coverSelection = .none
        scheduling = nil
        accessMode = .free
        priceText = "0"
        promoPriceText = ""
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
        let resourceID = id.trimmingCharacters(in: .whitespaces)

        do {
            try GitOps.pull(at: RepoCheckoutPaths.publicCatalogRepo)

            let previousCover = existingResources.first { $0.id == resourceID }?.coverImage
            let coverImage = try CoverImageStore.commit(coverSelection, id: resourceID, previous: previousCover)

            let isFreeFlag = accessMode != .paid
            let isTrialFlag = accessMode == .trial
            let price = isFreeFlag ? 0 : (Double(priceText) ?? 0)
            let resource = DownloadableResource(
                id: resourceID, name: name, description: description, category: category, url: url,
                youtubeURL: nilIfEmpty(youtubeURL), coverImage: coverImage, supportedOS: supportedOS,
                purchaseURL: nilIfEmpty(purchaseURL), demoURL: nilIfEmpty(demoURL),
                socialLinks: socialForm.model, scheduling: scheduling,
                isFree: isFreeFlag, isTrial: isTrialFlag, priceEUR: price,
                promoPriceEUR: Double(promoPriceText.trimmingCharacters(in: .whitespaces))
            )
            try CatalogEditor.upsertDownloadableResource(resource)
            try GitOps.commitAndPush(at: RepoCheckoutPaths.publicCatalogRepo, message: "Resursă download: \(resource.name)", paths: ["docs/catalog.json", "docs/covers"])
            successMessage = "„\(resource.name)” e publicat — apare la clienți la următorul refresh de catalog."
            clearForm()
            loadExisting()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func delete(_ resource: DownloadableResource?) async {
        guard let resource else { return }
        pendingDelete = nil
        errorMessage = nil
        successMessage = nil
        isBusy = true
        defer { isBusy = false }

        do {
            try GitOps.pull(at: RepoCheckoutPaths.publicCatalogRepo)
            try CoverImageStore.commit(.none, id: resource.id, previous: resource.coverImage)
            try CatalogEditor.removeDownloadableResource(id: resource.id)
            try GitOps.commitAndPush(at: RepoCheckoutPaths.publicCatalogRepo, message: "Sterg resursă download: \(resource.name)", paths: ["docs/catalog.json", "docs/covers"])
            successMessage = "„\(resource.name)” a fost șters."
            if editingID == resource.id { clearForm() }
            loadExisting()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
