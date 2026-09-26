import SwiftUI
import GDCPluginManagerCore

/// Manages "Service & Reparații Echipament" — parteneri de service
/// (drone/camere/optică/urgențe). Oglindă la PublishPartnerStoreView.
struct PublishServiceCenterView: View {
    @State private var existingCenters: [ServiceCenter] = []
    @State private var editingID: String?

    @State private var id = ""
    @State private var name = ""
    @State private var category: ServiceCategory = .camera
    @State private var specialization = ""
    @State private var contactURL = ""
    @State private var websiteURL = ""
    // Etapa 5 (2026-08-29) — adresă fizică opțională, buton Google Maps în Client.
    @State private var address = ""
    @State private var coverSelection: CoverImageSelection = .none
    @State private var scheduling: Scheduling?
    // Rețele sociale opționale (2026-08-29) — vezi SocialLinksEditor.swift.
    @State private var socialForm = SocialLinksFormState()
    // Multi-Locație (2026-09-05) — sedii suplimentare, opționale.
    @State private var additionalAddresses: [String] = []

    // Acces/grup/etichete — editor COMUN (2026-09-11), vezi AccessEditorSection.swift

    @State private var accessForm = AccessFormState()


    @State private var isBusy = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var pendingDelete: ServiceCenter?

    /// Selecția din tabelul spațiului de lucru (Faza 5). `nil` = formular gol („+ Nou”).
    /// Editorul rămâne cel existent: aceleași câmpuri, aceeași publicare.
    @Binding var workspaceSelection: String?
    /// În spațiul de lucru lista proprie a editorului se ascunde (dublură cu tabelul);
    /// ștergerea intrării selectate rămâne aici, cu aceeași confirmare.
    private let embedded: Bool
    @Environment(\.publishGate) private var publishGate

    init(workspaceSelection: Binding<String?>? = nil) {
        _workspaceSelection = workspaceSelection ?? .constant(nil)
        embedded = workspaceSelection != nil
    }

    var body: some View {
        editorBody
            .onChange(of: workspaceSelection) { _, id in applyWorkspaceSelection(id) }
            .onAppear { if workspaceSelection != nil { applyWorkspaceSelection(workspaceSelection) } }
    }

    private func applyWorkspaceSelection(_ id: String?) {
        guard let id else { clearForm(); return }
        if let entry = existingCenters.first(where: { $0.id == id }) { load(entry) }
    }

    private var editorBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Service & Reparații Echipament").font(.title2).fontWeight(.semibold)

                GroupBox {
                    VStack(alignment: .leading, spacing: GDCTokens.Space.m) {
                        TextField("ID (ex. service-drone-x, nu se mai poate schimba)", text: $id)
                            .textFieldStyle(.roundedBorder)
                            .disabled(editingID != nil)
                        TextField("Nume service", text: $name).textFieldStyle(.roundedBorder)
                        Picker("Categorie", selection: $category) {
                            ForEach(ServiceCategory.allCases) { cat in
                                Text(cat.rawValue).tag(cat)
                            }
                        }
                        AutocompleteTextField(placeholder: "Specializare (ex. reparații gimbal, senzori DJI)", text: $specialization,
                                               existingValues: existingCenters.map(\.specialization))
                        TextField("Link contact rapid (tel:, wa.me, mailto:)", text: $contactURL)
                            .textFieldStyle(.roundedBorder)
                        TextField("Website (opțional)", text: $websiteURL)
                            .textFieldStyle(.roundedBorder)
                        AutocompleteTextField(placeholder: "Adresă fizică (opțional — apare buton Google Maps în Client)", text: $address,
                                               existingValues: existingCenters.compactMap(\.address))
                    }
                    .padding(GDCTokens.Space.s)
                }

                AccessEditorSection(

                    state: $accessForm,

                    showsKind: true,

                    showsReferencePrice: true,

                    tagSuggestions: AccessTagSuggestions.apps

                )


                CoverImagePicker(preset: .icon, selection: $coverSelection)
                SchedulingPicker(scheduling: $scheduling)
                    .id(editingID ?? "new")
                AdditionalAddressesEditor(addresses: $additionalAddresses,
                                           existingValues: existingCenters.compactMap(\.address))
                SocialLinksSection(state: $socialForm)

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(GDCTokens.Palette.error)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(GDCTokens.Palette.error.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: GDCTokens.Radius.control))
                }
                if let successMessage {
                    Label(successMessage, systemImage: "checkmark.circle.fill").foregroundStyle(GDCTokens.Palette.success)
                }

                HStack {
                    if isBusy { ProgressView().controlSize(.small) }
                    Button(editingID == nil ? "Publică" : "Actualizează") { publishGate.request(name) { await publish() } }
                        .disabled(isBusy || !isFormValid)
                    if editingID != nil {
                        Button("Service nou") { clearForm() }
                    }
                }
                if !isFormValid && !isBusy {
                    Text(validationHint).font(.caption).foregroundStyle(GDCTokens.Palette.warning)
                }

                if embedded, let selectedID = editingID, let entry = existingCenters.first(where: { $0.id == selectedID }) {

                    Button("Șterge…", role: .destructive) { pendingDelete = entry }

                }

                if !embedded && !existingCenters.isEmpty {
                    Divider()
                    Text("Servicii publicate").font(.headline)
                    ForEach(existingCenters) { center in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(center.name).fontWeight(.medium)
                                Text("\(center.category.rawValue) — \(center.specialization)")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Editează") { load(center) }
                            Button("Șterge", role: .destructive) { pendingDelete = center }
                        }
                        .padding(.vertical, GDCTokens.Space.xs)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(GDCTokens.Space.xl)
            .frame(maxWidth: 640, alignment: .leading)
        }
        .confirmationDialog(
            "Ștergi definitiv service-ul „\(pendingDelete?.name ?? "")”?",
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
            && !contactURL.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var validationHint: String {
        var missing: [String] = []
        if id.trimmingCharacters(in: .whitespaces).isEmpty { missing.append("ID") }
        if name.trimmingCharacters(in: .whitespaces).isEmpty { missing.append("Nume") }
        if contactURL.trimmingCharacters(in: .whitespaces).isEmpty { missing.append("Link contact") }
        return "Lipsește: " + missing.joined(separator: ", ")
    }

    private func loadExisting() {
        defer { NotificationCenter.default.post(name: .furnizorCatalogChanged, object: nil) }
        if let catalog = try? CatalogEditor.load() {
            existingCenters = catalog.serviceCenters.sorted { $0.name < $1.name }
        }
    }

    private func load(_ center: ServiceCenter) {
        editingID = center.id
        id = center.id
        name = center.name
        category = center.category
        specialization = center.specialization
        contactURL = center.contactURL
        websiteURL = center.websiteURL ?? ""
        address = center.address ?? ""
        coverSelection = center.coverImage.map { .existing($0) } ?? .none
        scheduling = center.scheduling
        accessForm = AccessFormState(center.access)
        socialForm = SocialLinksFormState(center.socialLinks)
        additionalAddresses = center.additionalAddresses
        successMessage = nil
        errorMessage = nil
    }

    private func clearForm() {
        editingID = nil
        id = ""
        name = ""
        category = .camera
        specialization = ""
        contactURL = ""
        websiteURL = ""
        address = ""
        coverSelection = .none
        scheduling = nil
        accessForm.reset()
        socialForm.reset()
        additionalAddresses = []
    }

    private func publish() async {
        errorMessage = nil
        successMessage = nil
        isBusy = true
        defer { isBusy = false }

        let centerID = id.trimmingCharacters(in: .whitespaces)

        do {
            try GitOps.pull(at: RepoCheckoutPaths.publicCatalogRepo)

            let previousCover = existingCenters.first { $0.id == centerID }?.coverImage
            let coverImage = try CoverImageStore.commit(coverSelection, id: centerID, previous: previousCover)

            let center = ServiceCenter(
                id: centerID, name: name, category: category,
                specialization: specialization,
                contactURL: contactURL.trimmingCharacters(in: .whitespaces),
                websiteURL: websiteURL.trimmingCharacters(in: .whitespaces).isEmpty ? nil : websiteURL.trimmingCharacters(in: .whitespaces),
                coverImage: coverImage, scheduling: scheduling,
                address: address.trimmingCharacters(in: .whitespaces).isEmpty ? nil : address.trimmingCharacters(in: .whitespaces),
                socialLinks: socialForm.model, additionalAddresses: additionalAddresses
            , access: accessForm.model)

            try CatalogEditor.upsertServiceCenter(center)
            try GitOps.commitAndPush(at: RepoCheckoutPaths.publicCatalogRepo, message: "Service partener: \(center.name)", paths: ["docs/catalog.json", "docs/covers"])
            successMessage = "„\(center.name)” e publicat — apare la clienți la următorul refresh de catalog."
            clearForm()
            loadExisting()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func delete(_ center: ServiceCenter?) async {
        guard let center else { return }
        pendingDelete = nil
        errorMessage = nil
        successMessage = nil
        isBusy = true
        defer { isBusy = false }

        do {
            try GitOps.pull(at: RepoCheckoutPaths.publicCatalogRepo)
            try CoverImageStore.commit(.none, id: center.id, previous: center.coverImage)
            try CatalogEditor.removeServiceCenter(id: center.id)
            try GitOps.commitAndPush(at: RepoCheckoutPaths.publicCatalogRepo, message: "Sterg service-ul: \(center.name)", paths: ["docs/catalog.json", "docs/covers"])
            successMessage = "„\(center.name)” a fost șters."
            if editingID == center.id { clearForm() }
            loadExisting()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
