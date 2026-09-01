import SwiftUI
import AppKit
import GDCPluginManagerCore

/// Manages the "Tutoriale" catalog section — embedded YouTube videos.
/// Cerință directă (2026-09-01): link YouTube → preluare automată de
/// titlu/imagine/descriere/taguri, toate editabile manual după aceea.
struct PublishTutorialView: View {
    @State private var existingTutorials: [Tutorial] = []
    @State private var editingID: String?

    @State private var youtubeURLInput = ""
    @State private var videoID = ""
    @State private var title = ""
    @State private var description = ""
    @State private var thumbnailURL = ""
    @State private var tags: [String] = []
    @State private var newTag = ""
    @State private var category = "General"
    @State private var scheduling: Scheduling?
    @State private var originalAddedAt: String?

    @State private var isFetching = false
    @State private var isBusy = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var pendingDelete: Tutorial?
    @State private var apiKeyInput = YouTubeMetadataFetcher.dataAPIKey
    @State private var showApiKeyGuide = false
    @State private var isTestingApiKey = false
    @State private var apiKeyTestResult: String?
    @State private var apiKeyTestSucceeded = false

    /// Categoriile deja folosite — Cristi le controlează pe măsură ce
    /// adaugă tutoriale, nu un enum fix predefinit de noi.
    private var existingCategories: [String] {
        Array(Set(existingTutorials.map(\.category))).sorted()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Tutoriale (video-uri YouTube embedded)").font(.title2).fontWeight(.semibold)

                GroupBox("Cheie YouTube Data API v3 (opțional)") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Fără ea vin automat doar titlul și imaginea. Cu o cheie (gratuită) vin automat și descrierea + tagurile.")
                            .font(.caption).foregroundStyle(.secondary)

                        Button(showApiKeyGuide ? "▾ Ascunde pașii" : "▸ Cum obțin o cheie? (ghid pas cu pas)") {
                            showApiKeyGuide.toggle()
                        }
                        .font(.caption)

                        if showApiKeyGuide {
                            VStack(alignment: .leading, spacing: 10) {
                                apiKeyStep(
                                    number: 1,
                                    text: "Deschide Google Cloud Console și creează un proiect nou (sau alege unul existent).",
                                    buttonLabel: "Deschide Google Cloud Console",
                                    url: "https://console.cloud.google.com/projectcreate"
                                )
                                apiKeyStep(
                                    number: 2,
                                    text: "Activează „YouTube Data API v3” pentru acel proiect — apasă butonul albastru „Enable” de pe pagina care se deschide.",
                                    buttonLabel: "Deschide pagina YouTube Data API v3",
                                    url: "https://console.cloud.google.com/apis/library/youtube.googleapis.com"
                                )
                                apiKeyStep(
                                    number: 3,
                                    text: "Creează o cheie: „+ CREATE CREDENTIALS” → „API key”. Google generează cheia instant, o afișează pe ecran.",
                                    buttonLabel: "Deschide pagina de Credentials",
                                    url: "https://console.cloud.google.com/apis/credentials"
                                )
                                Text("4. Copiază cheia generată și lipește-o mai jos, apoi apasă „Salvează”.")
                                    .font(.caption)
                            }
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.08)))
                        }

                        HStack {
                            SecureField("Cheie API", text: $apiKeyInput).textFieldStyle(.roundedBorder)
                            Button("Salvează") {
                                YouTubeMetadataFetcher.dataAPIKey = apiKeyInput
                                apiKeyTestResult = nil
                            }
                            if isTestingApiKey { ProgressView().controlSize(.small) }
                            Button("Testează cheia") { Task { await testApiKey() } }
                                .disabled(apiKeyInput.trimmingCharacters(in: .whitespaces).isEmpty || isTestingApiKey)
                        }
                        if let apiKeyTestResult {
                            Label(apiKeyTestResult, systemImage: apiKeyTestSucceeded ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(apiKeyTestSucceeded ? .green : .red)
                        }
                    }
                    .padding(8)
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            TextField("Link YouTube (youtube.com/watch?v=... sau youtu.be/...)", text: $youtubeURLInput)
                                .textFieldStyle(.roundedBorder)
                            if isFetching { ProgressView().controlSize(.small) }
                            Button("Preia informații") { Task { await fetchMetadata() } }
                                .disabled(isFetching || youtubeURLInput.trimmingCharacters(in: .whitespaces).isEmpty)
                        }

                        if !thumbnailURL.isEmpty, let url = URL(string: thumbnailURL) {
                            AsyncImage(url: url) { image in
                                image.resizable().aspectRatio(16/9, contentMode: .fit)
                            } placeholder: { ProgressView() }
                            .frame(maxWidth: 320)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }

                        TextField("Titlu", text: $title).textFieldStyle(.roundedBorder)

                        Text("Descriere").font(.caption).foregroundStyle(.secondary)
                        TextEditor(text: $description)
                            .frame(minHeight: 100)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(.separator))

                        HStack {
                            TextField("Categorie (ex. Color Grading, Instalare)", text: $category)
                                .textFieldStyle(.roundedBorder)
                            if !existingCategories.isEmpty {
                                Menu("Existente") {
                                    ForEach(existingCategories, id: \.self) { cat in
                                        Button(cat) { category = cat }
                                    }
                                }
                            }
                        }

                        Text("Taguri").font(.caption).foregroundStyle(.secondary)
                        TagChipsFlow(tags: tags, onRemove: { tag in tags.removeAll { $0 == tag } })
                        HStack {
                            TextField("Adaugă tag și apasă Enter", text: $newTag)
                                .textFieldStyle(.roundedBorder)
                                .onSubmit { addTag() }
                            Button("Adaugă") { addTag() }
                                .disabled(newTag.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
                    .padding(8)
                }

                SchedulingPicker(scheduling: $scheduling)
                    .id(editingID ?? "new")

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
                        Button("Tutorial nou") { clearForm() }
                    }
                }
                if !isFormValid && !isBusy {
                    Text("Lipsește: link YouTube valid și titlu.").font(.caption).foregroundStyle(.orange)
                }

                if !existingTutorials.isEmpty {
                    Divider()
                    Text("Tutoriale publicate").font(.headline)
                    ForEach(existingTutorials) { tutorial in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(tutorial.title).fontWeight(.medium)
                                Text(tutorial.category).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Editează") { load(tutorial) }
                            Button("Șterge", role: .destructive) { pendingDelete = tutorial }
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
            "Ștergi definitiv „\(pendingDelete?.title ?? "")”?",
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
        !videoID.trimmingCharacters(in: .whitespaces).isEmpty && !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    @ViewBuilder
    private func apiKeyStep(number: Int, text: String, buttonLabel: String, url: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(number). \(text)").font(.caption)
            if let link = URL(string: url) {
                Button(buttonLabel) { NSWorkspace.shared.open(link) }
                    .controlSize(.small)
            }
        }
    }

    private func testApiKey() async {
        apiKeyTestResult = nil
        isTestingApiKey = true
        defer { isTestingApiKey = false }
        YouTubeMetadataFetcher.dataAPIKey = apiKeyInput
        // "dQw4w9WgXcQ" - orice video public real, folosit doar ca sa
        // verificam ca cheia intoarce un raspuns valid, nu ca sa afisam
        // continutul lui.
        do {
            let meta = try await YouTubeMetadataFetcher.fetch(youtubeURL: "https://www.youtube.com/watch?v=dQw4w9WgXcQ")
            if meta.description.isEmpty {
                apiKeyTestSucceeded = false
                apiKeyTestResult = "Cheia nu a adus descriere/taguri — verifică pașii 2-3 de mai sus (API-ul trebuie activat pentru acest proiect)."
            } else {
                apiKeyTestSucceeded = true
                apiKeyTestResult = "Cheia funcționează — descrierea și tagurile vor veni automat de acum."
            }
        } catch {
            apiKeyTestSucceeded = false
            apiKeyTestResult = "Eroare la testare: \(error.localizedDescription)"
        }
    }

    private func addTag() {
        let trimmed = newTag.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !tags.contains(trimmed) else { return }
        tags.append(trimmed)
        newTag = ""
    }

    private func fetchMetadata() async {
        errorMessage = nil
        isFetching = true
        defer { isFetching = false }
        do {
            let meta = try await YouTubeMetadataFetcher.fetch(youtubeURL: youtubeURLInput)
            videoID = meta.videoID
            title = meta.title
            thumbnailURL = meta.thumbnailURL
            if description.isEmpty { description = meta.description }
            if tags.isEmpty { tags = meta.tags }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadExisting() {
        if let catalog = try? CatalogEditor.load() {
            existingTutorials = catalog.tutorials.sorted { ($0.addedAt ?? "") > ($1.addedAt ?? "") }
        }
    }

    private func load(_ tutorial: Tutorial) {
        editingID = tutorial.id
        youtubeURLInput = tutorial.youtubeURL
        videoID = tutorial.videoID
        title = tutorial.title
        description = tutorial.description
        thumbnailURL = tutorial.thumbnailURL
        tags = tutorial.tags
        category = tutorial.category
        scheduling = tutorial.scheduling
        originalAddedAt = tutorial.addedAt
        successMessage = nil
        errorMessage = nil
    }

    private func clearForm() {
        editingID = nil
        youtubeURLInput = ""
        videoID = ""
        title = ""
        description = ""
        thumbnailURL = ""
        tags = []
        newTag = ""
        category = "General"
        scheduling = nil
        originalAddedAt = nil
    }

    private func publish() async {
        errorMessage = nil
        successMessage = nil
        isBusy = true
        defer { isBusy = false }

        let formatter = ISO8601DateFormatter()
        let tutorial = Tutorial(
            id: editingID ?? videoID,
            youtubeURL: youtubeURLInput.trimmingCharacters(in: .whitespaces),
            videoID: videoID,
            title: title.trimmingCharacters(in: .whitespaces),
            description: description,
            thumbnailURL: thumbnailURL,
            tags: tags,
            category: category.trimmingCharacters(in: .whitespaces).isEmpty ? "General" : category.trimmingCharacters(in: .whitespaces),
            addedAt: originalAddedAt ?? formatter.string(from: Date()),
            scheduling: scheduling
        )

        do {
            try GitOps.pull(at: RepoCheckoutPaths.publicCatalogRepo)
            try CatalogEditor.upsertTutorial(tutorial)
            try GitOps.commitAndPush(at: RepoCheckoutPaths.publicCatalogRepo, message: "Tutorial: \(tutorial.title)", paths: ["docs/catalog.json"])
            successMessage = "„\(tutorial.title)” e publicat — apare la clienți la următorul refresh de catalog."
            clearForm()
            loadExisting()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func delete(_ tutorial: Tutorial?) async {
        guard let tutorial else { return }
        pendingDelete = nil
        errorMessage = nil
        successMessage = nil
        isBusy = true
        defer { isBusy = false }

        do {
            try GitOps.pull(at: RepoCheckoutPaths.publicCatalogRepo)
            try CatalogEditor.removeTutorial(id: tutorial.id)
            try GitOps.commitAndPush(at: RepoCheckoutPaths.publicCatalogRepo, message: "Sterg tutorialul: \(tutorial.title)", paths: ["docs/catalog.json"])
            successMessage = "„\(tutorial.title)” a fost șters."
            if editingID == tutorial.id { clearForm() }
            loadExisting()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// Randare simplă de "chip"-uri pentru taguri, cu buton de eliminare pe
/// fiecare — reutilizabilă, fără nicio dependință externă.
private struct TagChipsFlow: View {
    let tags: [String]
    let onRemove: (String) -> Void

    var body: some View {
        if tags.isEmpty {
            Text("Niciun tag încă.").font(.caption).foregroundStyle(.secondary)
        } else {
            HStack {
                ForEach(tags, id: \.self) { tag in
                    HStack(spacing: 4) {
                        Text(tag).font(.caption)
                        Button {
                            onRemove(tag)
                        } label: {
                            Image(systemName: "xmark.circle.fill").font(.caption2)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(.tint.opacity(0.18)))
                }
                Spacer()
            }
        }
    }
}
