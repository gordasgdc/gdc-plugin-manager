import SwiftUI
import AppKit
import CryptoKit
import GDCPluginManagerCore

/// Whether a product needs a purchased license, is genuinely free, or is
/// a watermarked trial of a paid sibling (published as its own separate
/// catalog entry — the watermark itself lives inside the file, prepared
/// by hand before publishing; the app only needs to know which badge to
/// show and, either way, that no license is required to install it).
enum AccessMode: String, CaseIterable, Identifiable {
    case paid, free, trial
    var id: String { rawValue }
    var label: String {
        switch self {
        case .paid: return "Plătit"
        case .free: return "Gratuit"
        case .trial: return "Probă (watermark)"
        }
    }
}

struct PublishView: View {
    @State private var pickedURL: URL?
    @State private var isUpdate = false
    @State private var existingItems: [PluginItem] = []

    @State private var id = ""
    @State private var name = ""
    @State private var description = ""
    @State private var type: PluginType = .dctl
    @State private var version = "1.0.0"
    @State private var priceText = "0"
    @State private var accessMode: AccessMode = .paid
    @State private var iconSymbol = "wand.and.stars"
    @State private var youtubeURL = ""
    @State private var supportedOS: SupportedOS = .crossPlatform
    /// Coperta produsului. Preset `.icon` (pătrat 512×512) — accentul e pe
    /// simbol/recunoaștere rapidă în grilă, nu pe detaliu.
    @State private var coverSelection: CoverImageSelection = .none
    /// Files of the product being updated, kept so a metadata-only edit
    /// (e.g. adding/changing the YouTube link) doesn't force re-picking
    /// and re-uploading the files — only used when `isUpdate` is true and
    /// no new file/folder was picked.
    @State private var existingFiles: [PluginFile] = []
    /// OFX only: the existing product's exact bundle folder name, kept
    /// for the same metadata-only-edit reason as `existingFiles` above.
    @State private var existingBundleFolderName: String?

    @State private var isBusy = false
    @State private var statusLines: [String] = []
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var showDeleteConfirm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Publică produs").font(.title2).fontWeight(.semibold)

                Picker("", selection: $isUpdate) {
                    Text("Produs nou").tag(false)
                    Text("Actualizare versiune existentă").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 360)
                .onChange(of: isUpdate) {
                    loadExistingIfNeeded()
                    if !isUpdate { clearForm() }
                }

                if isUpdate {
                    Picker("Produs existent", selection: $id) {
                        Text("Alege…").tag("")
                        ForEach(existingItems) { item in
                            Text(item.name).tag(item.id)
                        }
                    }
                    .onChange(of: id) { fillFromExisting() }

                    if !id.trimmingCharacters(in: .whitespaces).isEmpty {
                        Button("Șterge acest produs definitiv", role: .destructive) {
                            showDeleteConfirm = true
                        }
                        .disabled(isBusy)
                        .confirmationDialog(
                            "Ștergi definitiv „\(name)”?",
                            isPresented: $showDeleteConfirm, titleVisibility: .visible
                        ) {
                            Button("Șterge definitiv", role: .destructive) { Task { await deleteProduct() } }
                            Button("Anulează", role: .cancel) {}
                        } message: {
                            Text("Fișierele sunt eliminate din repo-ul privat și produsul dispare din catalog la clienți. Nu poate fi anulat.")
                        }
                    }
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        fileRow

                        if !isUpdate {
                            TextField("ID produs (ex. lut-wedding-style, nu se mai poate schimba)", text: $id)
                                .textFieldStyle(.roundedBorder)
                        }
                        TextField("Nume", text: $name).textFieldStyle(.roundedBorder)
                        TextField("Descriere", text: $description).textFieldStyle(.roundedBorder)

                        Picker("Categorie", selection: $type) {
                            ForEach(PluginType.allCases) { t in
                                Text(t.label).tag(t)
                            }
                        }
                        .disabled(isUpdate)
                        .onChange(of: type) { iconSymbol = type.defaultSymbol }

                        if type == .ofx {
                            Text("Alege folderul întreg „NumePlugin.ofx.bundle” (nu doar fișierul din interior) — Resolve identifică plugin-ul după numele exact al acelui folder.")
                                .font(.caption).foregroundStyle(.secondary)
                        }

                        TextField("Versiune", text: $version).textFieldStyle(.roundedBorder)

                        Picker("Acces", selection: $accessMode) {
                            ForEach(AccessMode.allCases) { mode in
                                Text(mode.label).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)

                        switch accessMode {
                        case .paid:
                            TextField("Preț (EUR, donație)", text: $priceText).textFieldStyle(.roundedBorder)
                        case .free:
                            Text("Clientul instalează direct, fără cod de activare.")
                                .font(.caption).foregroundStyle(.secondary)
                        case .trial:
                            Text("Clientul instalează direct, fără cod — apare pe card cu eticheta „Probă”. Include watermark-ul direct în fișier înainte de publicare; publică-l separat de versiunea plătită (ex. „Nume Produs (Probă)”).")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        TextField("Icon (SF Symbol, opțional)", text: $iconSymbol).textFieldStyle(.roundedBorder)
                        TextField("Link tutorial YouTube (opțional, nelistat)", text: $youtubeURL).textFieldStyle(.roundedBorder)

                        Picker("Compatibilitate", selection: $supportedOS) {
                            Text("🍎 Doar Mac").tag(SupportedOS.macOS)
                            Text("🪟 Doar Windows").tag(SupportedOS.windows)
                            Text("🔄 Ambele platforme").tag(SupportedOS.crossPlatform)
                        }
                        .pickerStyle(.segmented)
                        if isUpdate {
                            Text("Poți edita doar linkul YouTube (sau alte câmpuri) fără să alegi din nou fișierele — cele existente rămân neschimbate dacă nu alegi altele.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(8)
                }

                CoverImagePicker(preset: .icon, selection: $coverSelection)

                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
                if let successMessage {
                    Label(successMessage, systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                }
                if !statusLines.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(statusLines, id: \.self) { line in
                            Text(line).font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
                        }
                    }
                }

                HStack {
                    if isBusy { ProgressView().controlSize(.small) }
                    Button("Publică") { Task { await publish() } }
                        .disabled(isBusy || !isFormValid)
                }
            }
            .padding(24)
            .frame(maxWidth: 640, alignment: .leading)
        }
        .task { loadExistingIfNeeded() }
    }

    private var fileRow: some View {
        HStack {
            Text(fileRowLabel)
                .foregroundStyle(pickedURL == nil && existingFiles.isEmpty ? .secondary : .primary)
            Spacer()
            Button("Alege fișier sau folder…") { pickFileOrFolder() }
        }
    }

    private var fileRowLabel: String {
        if let url = pickedURL {
            if isDirectory(url) {
                let count = (try? collectFiles(under: url).count) ?? 0
                return "Folder „\(url.lastPathComponent)” — \(count) fișier(e)"
            }
            return url.lastPathComponent
        }
        if isUpdate && !existingFiles.isEmpty {
            return "Păstrez fișierele existente (\(existingFiles.count)) — alege altele doar dacă vrei să le înlocuiești"
        }
        return "Niciun fișier sau folder ales"
    }

    private var isFormValid: Bool {
        !id.trimmingCharacters(in: .whitespaces).isEmpty
            && !name.trimmingCharacters(in: .whitespaces).isEmpty
            && !version.trimmingCharacters(in: .whitespaces).isEmpty
            && (accessMode != .paid || Double(priceText) != nil)
            && (pickedURL != nil || (isUpdate && !existingFiles.isEmpty))
            && (type != .ofx || pickedURL == nil || isDirectory(pickedURL!))
    }

    /// Lets the vendor pick either ONE file (a single DCTL/LUT) or a
    /// whole FOLDER (a pack — e.g. a folder of several LUTs made
    /// together) — both publish as one product, a folder just becomes a
    /// multi-file product that installs into its own subfolder in
    /// Resolve, keeping the pack grouped instead of scattering loose
    /// files at the root.
    private func pickFileOrFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK {
            pickedURL = panel.url
        }
    }

    private func isDirectory(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        return isDir.boolValue
    }

    /// Returns every file under `root` with its path relative to `root`
    /// (e.g. "WeddingStyle1.cube", or "warm/Sunset.cube" for a nested
    /// subfolder) — or just `[(root, root.lastPathComponent)]` if `root`
    /// is itself a single file, so callers don't need to branch.
    // ARCHITECTURE NOTE: this already preserves full nested subfolder structure
    // (relativePath, not just basename) — required for OFX bundles to keep their
    // Contents/MacOS/, Contents/Resources/ layout intact. If you ever "simplify"
    // this to just filenames, InstallManager.swift's relativeInstallPath(for:in:)
    // depends on file.path staying "id/version/full/relative/path" — sync any
    // change here with InstallManager.swift AND the Windows port (InstallManager.cs).
    private func collectFiles(under root: URL) throws -> [(fileURL: URL, relativePath: String)] {
        guard isDirectory(root) else {
            return [(root, root.lastPathComponent)]
        }
        guard let enumerator = FileManager.default.enumerator(
            at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]
        ) else { return [] }

        var results: [(URL, String)] = []
        let rootPathLength = root.path.count
        for case let fileURL as URL in enumerator {
            let values = try fileURL.resourceValues(forKeys: [.isDirectoryKey])
            if values.isDirectory == true { continue }
            let relativePath = String(fileURL.path.dropFirst(rootPathLength + 1))
            results.append((fileURL, relativePath))
        }
        return results.sorted { $0.1 < $1.1 }
    }

    private func loadExistingIfNeeded() {
        guard let catalog = try? CatalogEditor.load() else { return }
        existingItems = catalog.items.sorted { $0.name < $1.name }
    }

    private func fillFromExisting() {
        guard let item = existingItems.first(where: { $0.id == id }) else { return }
        name = item.name
        description = item.description
        type = item.type
        accessMode = item.isTrial ? .trial : (item.isFree ? .free : .paid)
        priceText = String(item.priceEUR)
        iconSymbol = item.iconSymbol ?? ""
        youtubeURL = item.youtubeURL ?? ""
        supportedOS = item.supportedOS
        existingFiles = item.files
        existingBundleFolderName = item.bundleFolderName
        // `.existing`: coperta e deja publicată, nu se rescrie dacă
        // furnizorul n-o atinge (la fel ca fișierele, mai sus).
        coverSelection = item.coverImage.map { .existing($0) } ?? .none
        pickedURL = nil
        // version left for the user to bump if they're also replacing
        // files; a metadata-only edit (e.g. just the YouTube link) can
        // leave it as-is and skip picking a file entirely.
    }

    private func publish() async {
        errorMessage = nil
        successMessage = nil
        statusLines = []
        isBusy = true
        defer { isBusy = false }

        guard pickedURL != nil || (isUpdate && !existingFiles.isEmpty) else { return }
        let isFreeFlag = accessMode != .paid
        let isTrialFlag = accessMode == .trial
        let price = isFreeFlag ? 0 : (Double(priceText) ?? 0)
        let trimmedID = id.trimmingCharacters(in: .whitespaces)
        let trimmedYouTube = youtubeURL.trimmingCharacters(in: .whitespaces)

        // OFX only: the exact bundle folder name Resolve will look for.
        // A newly-picked folder wins; otherwise (metadata-only edit)
        // reuse whatever the existing product was published with.
        let bundleFolderName: String? = {
            guard type == .ofx else { return nil }
            if let pickedURL { return pickedURL.lastPathComponent }
            return existingBundleFolderName
        }()

        do {
            var pluginFiles: [PluginFile]
            if let pickedURL {
                // New files picked (new product, or replacing an
                // existing product's files) — copy + push to the
                // private repo as before.
                let picked = try collectFiles(under: pickedURL)
                guard !picked.isEmpty else {
                    errorMessage = "Folderul ales nu conține niciun fișier."
                    return
                }

                log("Actualizez repo-ul privat (pull)…")
                try GitOps.pull(at: RepoCheckoutPaths.privateFilesRepo)

                pluginFiles = []
                for (localURL, relativePath) in picked {
                    let data = try Data(contentsOf: localURL)
                    let sha = SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()

                    let repoRelativePath = "\(trimmedID)/\(version)/\(relativePath)"
                    let destURL = RepoCheckoutPaths.privateFilesRepo.appendingPathComponent(repoRelativePath)
                    try FileManager.default.createDirectory(at: destURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                    if FileManager.default.fileExists(atPath: destURL.path) {
                        try FileManager.default.removeItem(at: destURL)
                    }
                    try FileManager.default.copyItem(at: localURL, to: destURL)
                    pluginFiles.append(PluginFile(path: repoRelativePath, sha256: sha))
                    log("Fișier copiat în \(repoRelativePath)")
                }

                log("Trimit fișierele (commit + push, repo privat)…")
                try GitOps.commitAndPush(at: RepoCheckoutPaths.privateFilesRepo, message: "\(trimmedID) \(version)")
            } else {
                // Metadata-only update (e.g. just the YouTube link) — no
                // new files, so the private files repo isn't touched at all.
                pluginFiles = existingFiles
                log("Fără fișiere noi — păstrez cele \(existingFiles.count) existente.")
            }

            log("Actualizez catalogul (pull, repo public)…")
            try GitOps.pull(at: RepoCheckoutPaths.publicCatalogRepo)

            // Coperta se scrie în docs/covers/ ÎNAINTE de commit-ul de mai
            // jos, altfel catalogul ar referi o imagine încă nepublicată
            // (404 la clienți până la următorul push) — vezi WARNING în
            // CoverImageStore.
            let previousCover = existingItems.first { $0.id == trimmedID }?.coverImage
            let coverImage = try CoverImageStore.commit(coverSelection, id: trimmedID, previous: previousCover)
            if coverImage != nil { log("Imagine de prezentare pregătită") }

            let item = PluginItem(
                id: trimmedID, name: name, type: type, description: description,
                version: version, files: pluginFiles,
                iconSymbol: iconSymbol.isEmpty ? nil : iconSymbol, priceEUR: price,
                isFree: isFreeFlag, isTrial: isTrialFlag,
                youtubeURL: trimmedYouTube.isEmpty ? nil : trimmedYouTube,
                bundleFolderName: bundleFolderName,
                coverImage: coverImage,
                supportedOS: supportedOS
            )
            try CatalogEditor.upsert(item)
            log("Catalog actualizat local")

            log("Public catalogul (commit + push, repo public)…")
            try GitOps.commitAndPush(at: RepoCheckoutPaths.publicCatalogRepo, message: "Catalog: \(name) \(version)", paths: ["docs/catalog.json", "docs/covers"])

            let fileWord = pluginFiles.count > 1 ? "\(pluginFiles.count) fișiere" : "1 fișier"
            successMessage = "„\(name)” e publicat (\(fileWord)) — apare la clienți la următorul refresh de catalog."
            loadExistingIfNeeded()
        } catch {
            errorMessage = error.localizedDescription
            log("EROARE: \(error.localizedDescription)")
        }
    }

    /// Removes a product entirely — for something published by mistake.
    /// Deletes its whole folder (every version) from the private files
    /// repo AND its entry from the public catalog, so it's gone both as
    /// a downloadable file and as a storefront listing.
    private func deleteProduct() async {
        errorMessage = nil
        successMessage = nil
        statusLines = []
        isBusy = true
        defer { isBusy = false }

        guard let item = existingItems.first(where: { $0.id == id }) else { return }
        let deletedName = item.name
        let deletedID = item.id
        let deletedCover = item.coverImage

        do {
            log("Actualizez repo-ul privat (pull)…")
            try GitOps.pull(at: RepoCheckoutPaths.privateFilesRepo)

            let productFolder = RepoCheckoutPaths.privateFilesRepo.appendingPathComponent(deletedID)
            if FileManager.default.fileExists(atPath: productFolder.path) {
                try FileManager.default.removeItem(at: productFolder)
                log("Șters folderul \(deletedID)/ (toate versiunile)")
            }
            log("Trimit ștergerea (commit + push, repo privat)…")
            try GitOps.commitAndPush(at: RepoCheckoutPaths.privateFilesRepo, message: "Sterg \(deletedID)")

            log("Actualizez catalogul (pull, repo public)…")
            try GitOps.pull(at: RepoCheckoutPaths.publicCatalogRepo)
            // Ștergem și coperta, altfel ar rămâne orfană în repo pentru
            // totdeauna (nimic n-o mai referă după ce iese din catalog).
            try CoverImageStore.commit(.none, id: deletedID, previous: deletedCover)
            try CatalogEditor.remove(id: deletedID)
            log("Eliminat din catalog local")

            log("Public catalogul (commit + push, repo public)…")
            try GitOps.commitAndPush(at: RepoCheckoutPaths.publicCatalogRepo, message: "Sterg din catalog: \(deletedName)", paths: ["docs/catalog.json", "docs/covers"])

            successMessage = "„\(deletedName)” a fost șters complet — dispare la următorul refresh de catalog."
            clearForm()
            loadExistingIfNeeded()
        } catch {
            errorMessage = error.localizedDescription
            log("EROARE: \(error.localizedDescription)")
        }
    }

    private func clearForm() {
        id = ""
        name = ""
        description = ""
        type = .dctl
        version = "1.0.0"
        priceText = "0"
        accessMode = .paid
        iconSymbol = "wand.and.stars"
        youtubeURL = ""
        existingFiles = []
        existingBundleFolderName = nil
        coverSelection = .none
        pickedURL = nil
    }

    private func log(_ line: String) {
        statusLines.append(line)
    }
}
