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
    /// Coperta cărții/cursului. Preset `.cover` — vrem să se citească
    /// titlul de pe copertă într-un preview mărit.
    @State private var coverSelection: CoverImageSelection = .none

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

                CoverImagePicker(preset: .cover, selection: $coverSelection)

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
        // `.existing`: imaginea e deja publicată, nu se rescrie dacă
        // furnizorul n-o atinge.
        coverSelection = resource.coverImage.map { .existing($0) } ?? .none
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
        coverSelection = .none
    }

    private func publish() async {
        errorMessage = nil
        successMessage = nil
        isBusy = true
        defer { isBusy = false }

        let trimmedYouTube = youtubeURL.trimmingCharacters(in: .whitespaces)
        let resourceID = id.trimmingCharacters(in: .whitespaces)

        do {
            // Pull ÎNAINTE de a scrie coperta pe disc, ca fișierul nou să nu
            // fie prins într-un merge cu ce s-a publicat între timp.
            try GitOps.pull(at: RepoCheckoutPaths.publicCatalogRepo)

            // Coperta se scrie în docs/covers/ ÎNAINTE de commit, altfel
            // catalogul ar referi o imagine încă nepublicată (404 la clienți
            // până la următorul push) — vezi WARNING în CoverImageStore.
            let previousCover = existingResources.first { $0.id == resourceID }?.coverImage
            let coverImage = try CoverImageStore.commit(coverSelection, id: resourceID, previous: previousCover)

            let resource = EducationalResource(
                id: resourceID, name: name,
                description: description, kind: kind,
                externalURL: externalURL.trimmingCharacters(in: .whitespaces),
                youtubeURL: trimmedYouTube.isEmpty ? nil : trimmedYouTube,
                coverImage: coverImage
            )

            try CatalogEditor.upsertEducationalResource(resource)
            try GitOps.commitAndPush(at: RepoCheckoutPaths.publicCatalogRepo, message: "Material: \(resource.name)", paths: ["docs/catalog.json", "docs/covers"])
            successMessage = "„\(resource.name)” e publicat — apare la clienți la următorul refresh de catalog."
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
    private func delete(_ resource: EducationalResource?) async {
        guard let resource else { return }
        pendingDelete = nil
        errorMessage = nil
        successMessage = nil
        isBusy = true
        defer { isBusy = false }

        do {
            try GitOps.pull(at: RepoCheckoutPaths.publicCatalogRepo)
            // Ștergem și coperta, altfel ar rămâne orfană în repo pentru
            // totdeauna (nimic n-o mai referă după ce iese din catalog).
            try CoverImageStore.commit(.none, id: resource.id, previous: resource.coverImage)
            try CatalogEditor.removeEducationalResource(id: resource.id)
            try GitOps.commitAndPush(at: RepoCheckoutPaths.publicCatalogRepo, message: "Sterg materialul: \(resource.name)", paths: ["docs/catalog.json", "docs/covers"])
            successMessage = "„\(resource.name)” a fost șters."
            if editingID == resource.id { clearForm() }
            loadExisting()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
