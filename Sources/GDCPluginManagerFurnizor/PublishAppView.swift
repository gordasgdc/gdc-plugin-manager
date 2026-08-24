import SwiftUI
import GDCPluginManagerCore

/// Manages the "Aplicații" catalog section — a small portfolio of
/// Cristi's other apps, each just a name and an outbound link. No
/// files, no license, no private repo — only docs/catalog.json.
struct PublishAppView: View {
    @State private var existingApps: [AppLink] = []
    @State private var editingID: String?

    @State private var id = ""
    @State private var name = ""
    @State private var url = ""
    @State private var youtubeURL = ""

    @State private var isBusy = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var pendingDelete: AppLink?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Aplicații").font(.title2).fontWeight(.semibold)

                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        TextField("ID (ex. cursorpro, nu se mai poate schimba)", text: $id)
                            .textFieldStyle(.roundedBorder)
                            .disabled(editingID != nil)
                        TextField("Nume aplicație", text: $name).textFieldStyle(.roundedBorder)
                        TextField("Link (https://…)", text: $url).textFieldStyle(.roundedBorder)
                        TextField("Link tutorial YouTube (opțional, nelistat)", text: $youtubeURL).textFieldStyle(.roundedBorder)
                    }
                    .padding(8)
                }

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
                        Button("Aplicație nouă") { clearForm() }
                    }
                }

                if !existingApps.isEmpty {
                    Divider()
                    Text("Aplicații publicate").font(.headline)
                    ForEach(existingApps) { app in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(app.name).fontWeight(.medium)
                                Text(app.url).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                            Spacer()
                            Button("Editează") { load(app) }
                            Button("Șterge", role: .destructive) { pendingDelete = app }
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
            "Ștergi definitiv „\(pendingDelete?.name ?? "")” din Aplicații?",
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
            && URL(string: url) != nil
            && (url.hasPrefix("http://") || url.hasPrefix("https://"))
    }

    private func loadExisting() {
        if let catalog = try? CatalogEditor.load() {
            existingApps = catalog.apps.sorted { $0.name < $1.name }
        }
    }

    private func load(_ app: AppLink) {
        editingID = app.id
        id = app.id
        name = app.name
        url = app.url
        youtubeURL = app.youtubeURL ?? ""
        successMessage = nil
        errorMessage = nil
    }

    private func clearForm() {
        editingID = nil
        id = ""
        name = ""
        url = ""
        youtubeURL = ""
    }

    private func publish() async {
        errorMessage = nil
        successMessage = nil
        isBusy = true
        defer { isBusy = false }

        let trimmedYouTube = youtubeURL.trimmingCharacters(in: .whitespaces)
        let app = AppLink(id: id.trimmingCharacters(in: .whitespaces), name: name, url: url,
                           youtubeURL: trimmedYouTube.isEmpty ? nil : trimmedYouTube)

        do {
            try GitOps.pull(at: RepoCheckoutPaths.publicCatalogRepo)
            try CatalogEditor.upsertApp(app)
            try GitOps.commitAndPush(at: RepoCheckoutPaths.publicCatalogRepo, message: "Aplicatie: \(app.name)", paths: ["docs/catalog.json", "docs/covers"])
            successMessage = "„\(app.name)” e publicată — apare la clienți la următorul refresh de catalog."
            clearForm()
            loadExisting()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func delete() async {
        guard let app = pendingDelete else { return }
        pendingDelete = nil
        errorMessage = nil
        successMessage = nil
        isBusy = true
        defer { isBusy = false }

        do {
            try GitOps.pull(at: RepoCheckoutPaths.publicCatalogRepo)
            try CatalogEditor.removeApp(id: app.id)
            try GitOps.commitAndPush(at: RepoCheckoutPaths.publicCatalogRepo, message: "Sterg aplicatia: \(app.name)", paths: ["docs/catalog.json", "docs/covers"])
            successMessage = "„\(app.name)” a fost ștearsă."
            if editingID == app.id { clearForm() }
            loadExisting()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
