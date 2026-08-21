import SwiftUI
import GDCPluginManagerCore

/// Manages the "Materiale" catalog section — books, online courses, and
/// guides sold by a third party. Unlike `Course`, not bookable via
/// WhatsApp: the client just links straight out to `externalURL` to buy.
/// No files, no license, no private repo involved at all; this only
/// ever touches docs/catalog.json in the public repo checkout.
struct PublishEducationalResourceView: View {
    @State private var existingResources: [EducationalResource] = []
    @State private var editingID: String?

    @State private var id = ""
    @State private var name = ""
    @State private var description = ""
    @State private var kind: EducationalResource.Kind = .course
    @State private var externalURL = ""
    @State private var youtubeURL = ""

    @State private var isBusy = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var pendingDelete: EducationalResource?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Materiale (cursuri online, cărți, ghiduri)").font(.title2).fontWeight(.semibold)

                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        TextField("ID (ex. carte-color-grading, nu se mai poate schimba)", text: $id)
                            .textFieldStyle(.roundedBorder)
                            .disabled(editingID != nil)
                        TextField("Nume", text: $name).textFieldStyle(.roundedBorder)
                        TextField("Descriere", text: $description).textFieldStyle(.roundedBorder)

                        Picker("Tip", selection: $kind) {
                            ForEach(EducationalResource.Kind.allCases) { k in
                                Text(k.label).tag(k)
                            }
                        }
                        .pickerStyle(.segmented)

                        TextField("Link extern de cumpărare (Amazon, Gumroad, Udemy…)", text: $externalURL)
                            .textFieldStyle(.roundedBorder)
                        TextField("Link YouTube/Vimeo (opțional, prezentare)", text: $youtubeURL)
                            .textFieldStyle(.roundedBorder)
                    }
                    .padding(8)
                }

                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
                if let successMessage {
                    Label(successMessage, systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                }

                HStack {
                    if isBusy { ProgressView().controlSize(.small) }
                    Button(editingID == nil ? "Publică" : "Actualizează") { Task { await publish() } }
                        .disabled(isBusy || !isFormValid)
                    if editingID != nil {
                        Button("Material nou") { clearForm() }
                    }
                }

                if !existingResources.isEmpty {
                    Divider()
                    Text("Materiale publicate").font(.headline)
                    ForEach(existingResources) { resource in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(resource.name).fontWeight(.medium)
                                Text(resource.kind.label).font(.caption).foregroundStyle(.secondary)
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
            Button("Șterge definitiv", role: .destructive) { Task { await delete() } }
            Button("Anulează", role: .cancel) { pendingDelete = nil }
        }
        .task { loadExisting() }
    }

    private var isFormValid: Bool {
        !id.trimmingCharacters(in: .whitespaces).isEmpty
            && !name.trimmingCharacters(in: .whitespaces).isEmpty
            && URL(string: externalURL.trimmingCharacters(in: .whitespaces)) != nil
            && !externalURL.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func loadExisting() {
        if let catalog = try? CatalogEditor.load() {
            existingResources = catalog.educationalResources.sorted { $0.name < $1.name }
        }
    }

    private func load(_ resource: EducationalResource) {
        editingID = resource.id
        id = resource.id
        name = resource.name
        description = resource.description
        kind = resource.kind
        externalURL = resource.externalURL
        youtubeURL = resource.youtubeURL ?? ""
        successMessage = nil
        errorMessage = nil
    }

    private func clearForm() {
        editingID = nil
        id = ""
        name = ""
        description = ""
        kind = .course
        externalURL = ""
        youtubeURL = ""
    }

    private func publish() async {
        errorMessage = nil
        successMessage = nil
        isBusy = true
        defer { isBusy = false }

        let trimmedYouTube = youtubeURL.trimmingCharacters(in: .whitespaces)
        let resource = EducationalResource(
            id: id.trimmingCharacters(in: .whitespaces), name: name,
            description: description, kind: kind,
            externalURL: externalURL.trimmingCharacters(in: .whitespaces),
            youtubeURL: trimmedYouTube.isEmpty ? nil : trimmedYouTube
        )

        do {
            try GitOps.pull(at: RepoCheckoutPaths.publicCatalogRepo)
            try CatalogEditor.upsertEducationalResource(resource)
            try GitOps.commitAndPush(at: RepoCheckoutPaths.publicCatalogRepo, message: "Material: \(resource.name)")
            successMessage = "„\(resource.name)” e publicat — apare la clienți la următorul refresh de catalog."
            clearForm()
            loadExisting()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func delete() async {
        guard let resource = pendingDelete else { return }
        pendingDelete = nil
        errorMessage = nil
        successMessage = nil
        isBusy = true
        defer { isBusy = false }

        do {
            try GitOps.pull(at: RepoCheckoutPaths.publicCatalogRepo)
            try CatalogEditor.removeEducationalResource(id: resource.id)
            try GitOps.commitAndPush(at: RepoCheckoutPaths.publicCatalogRepo, message: "Sterg materialul: \(resource.name)")
            successMessage = "„\(resource.name)” a fost șters."
            if editingID == resource.id { clearForm() }
            loadExisting()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
