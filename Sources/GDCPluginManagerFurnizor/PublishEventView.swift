import SwiftUI
import GDCPluginManagerCore

/// Manages the "Evenimente" catalog section — workshops, course
/// cohorts, festivals. Purely informational: title, free-text date,
/// location, and an outbound link. No files, no license, no private
/// repo involved; only ever touches docs/catalog.json in the public
/// repo checkout.
struct PublishEventView: View {
    @State private var existingEvents: [Event] = []
    @State private var editingID: String?

    @State private var id = ""
    @State private var title = ""
    @State private var description = ""
    @State private var dateDisplay = ""
    @State private var location = ""
    @State private var externalURL = ""
    @State private var youtubeURL = ""
    /// Afișul evenimentului. Preset `.cover` — aici imaginea chiar poartă
    /// informație (dată, program, invitați), deci vrem rezoluție de citit.
    @State private var coverSelection: CoverImageSelection = .none
    // Etapa 4 (2026-08-29) — valabilitate temporală opțională.
    @State private var scheduling: Scheduling?

    @State private var isBusy = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var pendingDelete: Event?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Evenimente (workshop-uri, cursuri, festivaluri)").font(.title2).fontWeight(.semibold)

                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        TextField("ID (ex. workshop-color-2026, nu se mai poate schimba)", text: $id)
                            .textFieldStyle(.roundedBorder)
                            .disabled(editingID != nil)
                        TextField("Titlu", text: $title).textFieldStyle(.roundedBorder)
                        TextField("Descriere", text: $description).textFieldStyle(.roundedBorder)
                        TextField("Dată (text liber, ex. 15-17 martie 2026)", text: $dateDisplay)
                            .textFieldStyle(.roundedBorder)
                        // Autocomplete (2026-08-29, cerut explicit): multe
                        // evenimente sunt "Online" — sugerează valorile deja
                        // folosite, ca să nu retastezi de fiecare dată.
                        AutocompleteTextField(placeholder: "Locație (ex. Online, sau adresa fizică)", text: $location,
                                               existingValues: existingEvents.map(\.location))
                        TextField("Link detalii/înscriere", text: $externalURL)
                            .textFieldStyle(.roundedBorder)
                        TextField("Link YouTube/Vimeo (opțional)", text: $youtubeURL)
                            .textFieldStyle(.roundedBorder)
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
                        Button("Eveniment nou") { clearForm() }
                    }
                }
                if !isFormValid && !isBusy {
                    Text(validationHint).font(.caption).foregroundStyle(.orange)
                }

                if !existingEvents.isEmpty {
                    Divider()
                    Text("Evenimente publicate").font(.headline)
                    ForEach(existingEvents) { event in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(event.title).fontWeight(.medium)
                                Text("\(event.dateDisplay) · \(event.location)").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Editează") { load(event) }
                            Button("Șterge", role: .destructive) { pendingDelete = event }
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
            "Ștergi definitiv evenimentul „\(pendingDelete?.title ?? "")”?",
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
            && !title.trimmingCharacters(in: .whitespaces).isEmpty
            && !externalURL.trimmingCharacters(in: .whitespaces).isEmpty
            && URL(string: externalURL.trimmingCharacters(in: .whitespaces)) != nil
    }

    private var validationHint: String {
        var missing: [String] = []
        if id.trimmingCharacters(in: .whitespaces).isEmpty { missing.append("ID") }
        if title.trimmingCharacters(in: .whitespaces).isEmpty { missing.append("Titlu") }
        let trimmedURL = externalURL.trimmingCharacters(in: .whitespaces)
        if trimmedURL.isEmpty {
            missing.append("Link înscriere")
        } else if URL(string: trimmedURL) == nil {
            missing.append("Link înscriere (format invalid)")
        }
        return "Lipsește: " + missing.joined(separator: ", ")
    }

    private func loadExisting() {
        if let catalog = try? CatalogEditor.load() {
            existingEvents = catalog.events.sorted { $0.title < $1.title }
        }
    }

    private func load(_ event: Event) {
        editingID = event.id
        id = event.id
        title = event.title
        description = event.description
        dateDisplay = event.dateDisplay
        location = event.location
        externalURL = event.externalURL
        youtubeURL = event.youtubeURL ?? ""
        // `.existing` (nu `.local`/`.external`): marcheaza ca imaginea e deja
        // publicata si nu trebuie rescrisă dacă furnizorul n-o atinge.
        coverSelection = event.coverImage.map { .existing($0) } ?? .none
        scheduling = event.scheduling
        successMessage = nil
        errorMessage = nil
    }

    private func clearForm() {
        editingID = nil
        id = ""
        title = ""
        description = ""
        dateDisplay = ""
        location = ""
        externalURL = ""
        youtubeURL = ""
        coverSelection = .none
        scheduling = nil
    }

    private func publish() async {
        errorMessage = nil
        successMessage = nil
        isBusy = true
        defer { isBusy = false }

        let trimmedYouTube = youtubeURL.trimmingCharacters(in: .whitespaces)
        let eventID = id.trimmingCharacters(in: .whitespaces)

        do {
            // Pull ÎNAINTE de a scrie coperta pe disc, ca fișierul nou să nu
            // fie prins într-un merge cu ce s-a publicat între timp.
            try GitOps.pull(at: RepoCheckoutPaths.publicCatalogRepo)

            // Coperta se scrie în docs/covers/ ÎNAINTE de commit, altfel
            // catalogul ar referi o imagine încă nepublicată (404 la clienți
            // până la următorul push) — vezi WARNING în CoverImageStore.
            let previousCover = existingEvents.first { $0.id == eventID }?.coverImage
            let coverImage = try CoverImageStore.commit(coverSelection, id: eventID, previous: previousCover)

            let event = Event(
                id: eventID, title: title,
                description: description, dateDisplay: dateDisplay, location: location,
                externalURL: externalURL.trimmingCharacters(in: .whitespaces),
                youtubeURL: trimmedYouTube.isEmpty ? nil : trimmedYouTube,
                coverImage: coverImage, scheduling: scheduling
            )

            try CatalogEditor.upsertEvent(event)
            try GitOps.commitAndPush(at: RepoCheckoutPaths.publicCatalogRepo, message: "Eveniment: \(event.title)", paths: ["docs/catalog.json", "docs/covers"])
            successMessage = "„\(event.title)” e publicat — apare la clienți la următorul refresh de catalog."
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
    private func delete(_ event: Event?) async {
        guard let event else { return }
        pendingDelete = nil
        errorMessage = nil
        successMessage = nil
        isBusy = true
        defer { isBusy = false }

        do {
            try GitOps.pull(at: RepoCheckoutPaths.publicCatalogRepo)
            // Ștergem și afișul, altfel ar rămâne orfan în repo pentru
            // totdeauna (nimic nu-l mai referă după ce iese din catalog).
            try CoverImageStore.commit(.none, id: event.id, previous: event.coverImage)
            try CatalogEditor.removeEvent(id: event.id)
            try GitOps.commitAndPush(at: RepoCheckoutPaths.publicCatalogRepo, message: "Sterg evenimentul: \(event.title)", paths: ["docs/catalog.json", "docs/covers"])
            successMessage = "„\(event.title)” a fost șters."
            if editingID == event.id { clearForm() }
            loadExisting()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
