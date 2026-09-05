import SwiftUI
import GDCPluginManagerCore

/// Manages the "Magazine partenere" catalog section — photo/video gear
/// shops. Just name, description, direct link; no files, no license,
/// only ever touches docs/catalog.json in the public repo checkout.
struct PublishPartnerStoreView: View {
    @State private var existingStores: [PartnerStore] = []
    @State private var editingID: String?

    @State private var id = ""
    @State private var name = ""
    @State private var description = ""
    @State private var url = ""
    // Etapa 5 (2026-08-29) — adresă fizică opțională, buton Google Maps în Client.
    @State private var address = ""
    /// Logo-ul magazinului. Preset `.icon` — un logo se recunoaște după
    /// formă, nu după detaliu, iar pătratul ține grila de carduri aliniată.
    @State private var coverSelection: CoverImageSelection = .none
    @State private var scheduling: Scheduling?
    // Rețele sociale opționale (2026-08-29) — vezi SocialLinksEditor.swift.
    @State private var socialForm = SocialLinksFormState()
    // Multi-Locație (2026-09-05) — magazine/sedii suplimentare, opționale.
    @State private var additionalAddresses: [String] = []

    @State private var isBusy = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var pendingDelete: PartnerStore?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Magazine partenere").font(.title2).fontWeight(.semibold)

                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        TextField("ID (ex. magazin-fotovideo-x, nu se mai poate schimba)", text: $id)
                            .textFieldStyle(.roundedBorder)
                            .disabled(editingID != nil)
                        TextField("Nume magazin", text: $name).textFieldStyle(.roundedBorder)
                        TextField("Descriere", text: $description).textFieldStyle(.roundedBorder)
                        TextField("Link direct", text: $url).textFieldStyle(.roundedBorder)
                        AutocompleteTextField(placeholder: "Adresă fizică (opțional — apare buton Google Maps în Client)", text: $address,
                                               existingValues: existingStores.compactMap(\.address))
                    }
                    .padding(8)
                }

                CoverImagePicker(preset: .icon, selection: $coverSelection)
                SchedulingPicker(scheduling: $scheduling)
                    .id(editingID ?? "new")
                AdditionalAddressesEditor(addresses: $additionalAddresses,
                                           existingValues: existingStores.compactMap(\.address))
                SocialLinksSection(state: $socialForm)

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
                        Button("Magazin nou") { clearForm() }
                    }
                }
                if !isFormValid && !isBusy {
                    Text(validationHint).font(.caption).foregroundStyle(.orange)
                }

                if !existingStores.isEmpty {
                    Divider()
                    Text("Magazine publicate").font(.headline)
                    ForEach(existingStores) { store in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(store.name).fontWeight(.medium)
                                Text(store.url).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Editează") { load(store) }
                            Button("Șterge", role: .destructive) { pendingDelete = store }
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
            "Ștergi definitiv magazinul „\(pendingDelete?.name ?? "")”?",
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
            && !url.trimmingCharacters(in: .whitespaces).isEmpty
            && URL(string: url.trimmingCharacters(in: .whitespaces)) != nil
    }

    private var validationHint: String {
        var missing: [String] = []
        if id.trimmingCharacters(in: .whitespaces).isEmpty { missing.append("ID") }
        if name.trimmingCharacters(in: .whitespaces).isEmpty { missing.append("Nume") }
        let trimmedURL = url.trimmingCharacters(in: .whitespaces)
        if trimmedURL.isEmpty {
            missing.append("Link magazin")
        } else if URL(string: trimmedURL) == nil {
            missing.append("Link magazin (format invalid)")
        }
        return "Lipsește: " + missing.joined(separator: ", ")
    }

    private func loadExisting() {
        if let catalog = try? CatalogEditor.load() {
            existingStores = catalog.partnerStores.sorted { $0.name < $1.name }
        }
    }

    private func load(_ store: PartnerStore) {
        editingID = store.id
        id = store.id
        name = store.name
        description = store.description
        url = store.url
        address = store.address ?? ""
        // `.existing`: logo-ul e deja publicat, nu se rescrie dacă
        // furnizorul nu-l atinge.
        coverSelection = store.coverImage.map { .existing($0) } ?? .none
        scheduling = store.scheduling
        socialForm = SocialLinksFormState(store.socialLinks)
        additionalAddresses = store.additionalAddresses
        successMessage = nil
        errorMessage = nil
    }

    private func clearForm() {
        editingID = nil
        id = ""
        name = ""
        description = ""
        url = ""
        address = ""
        coverSelection = .none
        scheduling = nil
        socialForm.reset()
        additionalAddresses = []
    }

    private func publish() async {
        errorMessage = nil
        successMessage = nil
        isBusy = true
        defer { isBusy = false }

        let storeID = id.trimmingCharacters(in: .whitespaces)

        do {
            // Pull ÎNAINTE de a scrie logo-ul pe disc, ca fișierul nou să nu
            // fie prins într-un merge cu ce s-a publicat între timp.
            try GitOps.pull(at: RepoCheckoutPaths.publicCatalogRepo)

            // Logo-ul se scrie în docs/covers/ ÎNAINTE de commit, altfel
            // catalogul ar referi o imagine încă nepublicată (404 la clienți
            // până la următorul push) — vezi WARNING în CoverImageStore.
            let previousCover = existingStores.first { $0.id == storeID }?.coverImage
            let coverImage = try CoverImageStore.commit(coverSelection, id: storeID, previous: previousCover)

            let trimmedAddress = address.trimmingCharacters(in: .whitespaces)
            let store = PartnerStore(
                id: storeID, name: name,
                description: description, url: url.trimmingCharacters(in: .whitespaces),
                coverImage: coverImage, scheduling: scheduling,
                address: trimmedAddress.isEmpty ? nil : trimmedAddress,
                socialLinks: socialForm.model, additionalAddresses: additionalAddresses
            )

            try CatalogEditor.upsertPartnerStore(store)
            try GitOps.commitAndPush(at: RepoCheckoutPaths.publicCatalogRepo, message: "Magazin partener: \(store.name)", paths: ["docs/catalog.json", "docs/covers"])
            successMessage = "„\(store.name)” e publicat — apare la clienți la următorul refresh de catalog."
            clearForm()
            loadExisting()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // PITFALL FIXED 2026-08-24: elementul de sters vine ca PARAMETRU,
    // capturat sincron in butonul dialogului — NU se mai citeste
    // pendingDelete aici. SwiftUI goleste pendingDelete (prin binding-ul
    // custom de mai jos, la inchiderea dialogului) in paralel cu pornirea
    // acestui Task; cine citea pendingDelete direct in delete() risca sa-l
    // gaseasca deja nil si sa iasa fara sa faca nimic — fara eroare, fara
    // mesaj, exact simptomul "apas Sterge si nu se intampla nimic".
    private func delete(_ store: PartnerStore?) async {
        guard let store else { return }
        pendingDelete = nil
        errorMessage = nil
        successMessage = nil
        isBusy = true
        defer { isBusy = false }

        do {
            try GitOps.pull(at: RepoCheckoutPaths.publicCatalogRepo)
            // Ștergem și logo-ul, altfel ar rămâne orfan în repo pentru
            // totdeauna (nimic nu-l mai referă după ce iese din catalog).
            try CoverImageStore.commit(.none, id: store.id, previous: store.coverImage)
            try CatalogEditor.removePartnerStore(id: store.id)
            try GitOps.commitAndPush(at: RepoCheckoutPaths.publicCatalogRepo, message: "Sterg magazinul: \(store.name)", paths: ["docs/catalog.json", "docs/covers"])
            successMessage = "„\(store.name)” a fost șters."
            if editingID == store.id { clearForm() }
            loadExisting()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
