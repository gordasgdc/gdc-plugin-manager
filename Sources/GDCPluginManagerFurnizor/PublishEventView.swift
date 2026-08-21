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
                        TextField("Locație", text: $location).textFieldStyle(.roundedBorder)
                        TextField("Link detalii/înscriere", text: $externalURL)
                            .textFieldStyle(.roundedBorder)
                        TextField("Link YouTube/Vimeo (opțional)", text: $youtubeURL)
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
                        Button("Eveniment nou") { clearForm() }
                    }
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
            Button("Șterge definitiv", role: .destructive) { Task { await delete() } }
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
    }

    private func publish() async {
        errorMessage = nil
        successMessage = nil
        isBusy = true
        defer { isBusy = false }

        let trimmedYouTube = youtubeURL.trimmingCharacters(in: .whitespaces)
        let event = Event(
            id: id.trimmingCharacters(in: .whitespaces), title: title,
            description: description, dateDisplay: dateDisplay, location: location,
            externalURL: externalURL.trimmingCharacters(in: .whitespaces),
            youtubeURL: trimmedYouTube.isEmpty ? nil : trimmedYouTube
        )

        do {
            try GitOps.pull(at: RepoCheckoutPaths.publicCatalogRepo)
            try CatalogEditor.upsertEvent(event)
            try GitOps.commitAndPush(at: RepoCheckoutPaths.publicCatalogRepo, message: "Eveniment: \(event.title)")
            successMessage = "„\(event.title)” e publicat — apare la clienți la următorul refresh de catalog."
            clearForm()
            loadExisting()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func delete() async {
        guard let event = pendingDelete else { return }
        pendingDelete = nil
        errorMessage = nil
        successMessage = nil
        isBusy = true
        defer { isBusy = false }

        do {
            try GitOps.pull(at: RepoCheckoutPaths.publicCatalogRepo)
            try CatalogEditor.removeEvent(id: event.id)
            try GitOps.commitAndPush(at: RepoCheckoutPaths.publicCatalogRepo, message: "Sterg evenimentul: \(event.title)")
            successMessage = "„\(event.title)” a fost șters."
            if editingID == event.id { clearForm() }
            loadExisting()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
