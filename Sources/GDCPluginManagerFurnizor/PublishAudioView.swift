import SwiftUI
import GDCPluginManagerCore

/// Manages the "Audio" catalog section — modelată 1:1 pe PublishAppView
/// ("Aplicații"): niciun fișier în `gdc-plugin-manager-files`, nicio
/// licență — doar un link (descărcare/stocare) și o descriere, scrise
/// direct în `docs/catalog.json`.
struct PublishAudioView: View {
    @State private var existingTracks: [AudioTrack] = []
    @State private var editingID: String?

    @State private var id = ""
    @State private var name = ""
    @State private var description = ""
    @State private var url = ""
    @State private var youtubeURL = ""
    /// Coperta elementului audio. Preset `.icon` — la fel ca la Aplicații.
    @State private var coverSelection: CoverImageSelection = .none
    @State private var scheduling: Scheduling?

    @State private var isBusy = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var pendingDelete: AudioTrack?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Audio").font(.title2).fontWeight(.semibold)

                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        TextField("ID (ex. ambient-pack-1, nu se mai poate schimba)", text: $id)
                            .textFieldStyle(.roundedBorder)
                            .disabled(editingID != nil)
                        TextField("Nume", text: $name).textFieldStyle(.roundedBorder)
                        TextField("Link fișier audio (https://…)", text: $url).textFieldStyle(.roundedBorder)
                        TextEditor(text: $description)
                            .frame(minHeight: 80)
                            .overlay(alignment: .topLeading) {
                                if description.isEmpty {
                                    Text("Informații / descriere (format, metadate, conținut pachet…)")
                                        .foregroundStyle(.secondary)
                                        .padding(.top, 8).padding(.leading, 5)
                                        .allowsHitTesting(false)
                                }
                            }
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(.separator))
                        TextField("Link tutorial YouTube (opțional, nelistat)", text: $youtubeURL).textFieldStyle(.roundedBorder)
                    }
                    .padding(8)
                }

                CoverImagePicker(preset: .icon, selection: $coverSelection)
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
                        Button("Element audio nou") { clearForm() }
                    }
                }
                if !isFormValid && !isBusy {
                    Text(validationHint).font(.caption).foregroundStyle(.orange)
                }

                if !existingTracks.isEmpty {
                    Divider()
                    Text("Elemente audio publicate").font(.headline)
                    ForEach(existingTracks) { track in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(track.name).fontWeight(.medium)
                                Text(track.url).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                            Spacer()
                            Button("Editează") { load(track) }
                            Button("Șterge", role: .destructive) { pendingDelete = track }
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
            "Ștergi definitiv „\(pendingDelete?.name ?? "")” din Audio?",
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
    }

    private var validationHint: String {
        var missing: [String] = []
        if id.trimmingCharacters(in: .whitespaces).isEmpty { missing.append("ID") }
        if name.trimmingCharacters(in: .whitespaces).isEmpty { missing.append("Nume") }
        if !url.hasPrefix("http://") && !url.hasPrefix("https://") {
            missing.append("Link (trebuie să înceapă cu http:// sau https://)")
        } else if URL(string: url) == nil {
            missing.append("Link (format invalid)")
        }
        return "Lipsește: " + missing.joined(separator: ", ")
    }

    private func loadExisting() {
        if let catalog = try? CatalogEditor.load() {
            existingTracks = catalog.audioTracks.sorted { $0.name < $1.name }
        }
    }

    private func load(_ track: AudioTrack) {
        editingID = track.id
        id = track.id
        name = track.name
        description = track.description
        url = track.url
        youtubeURL = track.youtubeURL ?? ""
        // `.existing`: coperta e deja publicată, nu se rescrie dacă
        // furnizorul n-o atinge.
        coverSelection = track.coverImage.map { .existing($0) } ?? .none
        scheduling = track.scheduling
        successMessage = nil
        errorMessage = nil
    }

    private func clearForm() {
        editingID = nil
        id = ""
        name = ""
        description = ""
        url = ""
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
        let trackID = id.trimmingCharacters(in: .whitespaces)

        do {
            // Pull ÎNAINTE de a scrie coperta pe disc, ca fișierul nou să nu
            // fie prins într-un merge cu ce s-a publicat între timp.
            try GitOps.pull(at: RepoCheckoutPaths.publicCatalogRepo)

            // Coperta se scrie în docs/covers/ ÎNAINTE de commit, altfel
            // catalogul ar referi o imagine încă nepublicată.
            let previousCover = existingTracks.first { $0.id == trackID }?.coverImage
            let coverImage = try CoverImageStore.commit(coverSelection, id: trackID, previous: previousCover)

            let track = AudioTrack(id: trackID, name: name, description: description, url: url,
                                    youtubeURL: trimmedYouTube.isEmpty ? nil : trimmedYouTube,
                                    coverImage: coverImage, scheduling: scheduling)
            try CatalogEditor.upsertAudioTrack(track)
            try GitOps.commitAndPush(at: RepoCheckoutPaths.publicCatalogRepo, message: "Audio: \(track.name)", paths: ["docs/catalog.json", "docs/covers"])
            successMessage = "„\(track.name)” e publicat — apare la clienți la următorul refresh de catalog."
            clearForm()
            loadExisting()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func delete(_ track: AudioTrack?) async {
        guard let track else { return }
        pendingDelete = nil
        errorMessage = nil
        successMessage = nil
        isBusy = true
        defer { isBusy = false }

        do {
            try GitOps.pull(at: RepoCheckoutPaths.publicCatalogRepo)
            // Ștergem și coperta, altfel ar rămâne orfană în repo pentru
            // totdeauna (nimic n-o mai referă după ce iese din catalog).
            try CoverImageStore.commit(.none, id: track.id, previous: track.coverImage)
            try CatalogEditor.removeAudioTrack(id: track.id)
            try GitOps.commitAndPush(at: RepoCheckoutPaths.publicCatalogRepo, message: "Sterg audio: \(track.name)", paths: ["docs/catalog.json", "docs/covers"])
            successMessage = "„\(track.name)” a fost șters."
            if editingID == track.id { clearForm() }
            loadExisting()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
