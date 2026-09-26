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
    /// Versiunea deja publicată a produsului editat (nil la un produs nou): afișată lângă câmp, iar noua versiune se sugerează automat (+1 la patch).
    @State private var previousVersion: String?
    @State private var inbox: [StyleLabSubmission] = []
    /// Trimiterea din STYLE Lab aplicată în formular (se scoate din căsuță după publicare).
    @State private var appliedSubmissionID: String?
    @State private var skipClear = false
    @State private var priceText = "0"
    @State private var promoPriceText = ""
    @State private var accessMode: AccessMode = .paid
    @State private var iconSymbol = "wand.and.stars"
    @State private var youtubeURL = ""
    @State private var supportedOS: SupportedOS = .crossPlatform
    @State private var scheduling: Scheduling?
    // Etapa 2 (2026-08-29) — linkuri multiple + social, toate opționale.
    @State private var purchaseURL = ""
    @State private var demoURL = ""
    @State private var socialForm = SocialLinksFormState()
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

    // Acces/grup/etichete — editor COMUN (2026-09-11), vezi AccessEditorSection.swift

    @State private var accessForm = AccessFormState()


    @State private var scriptFolder: ScriptFolder = .default
    @State private var isBusy = false
    @State private var statusLines: [String] = []
    @State private var pendingPublishes: [PublishTransaction.Record] = PublishJournal.pending()
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var showDeleteConfirm = false
    /// Ștergere multiplă: produsele bifate în lista de mai jos.
    @State private var batchSelection: Set<String> = []
    @State private var showBatchDeleteConfirm = false

    /// Selecția din tabelul spațiului de lucru (Faza 5). `nil` = formular gol („+ Nou”).
    /// Editorul rămâne cel existent: aceleași câmpuri, aceeași publicare.
    @Binding var workspaceSelection: String?

    init(workspaceSelection: Binding<String?> = .constant(nil)) {
        _workspaceSelection = workspaceSelection
    }

    var body: some View {
        editorBody
            .onChange(of: workspaceSelection) { _, id in applyWorkspaceSelection(id) }
            .onAppear { if workspaceSelection != nil { applyWorkspaceSelection(workspaceSelection) } }
    }

    private func applyWorkspaceSelection(_ id: String?) {
        guard let id else { isUpdate = false; return }
        loadExistingIfNeeded()
        skipClear = true
        isUpdate = true
        self.id = id
        fillFromExisting()
    }

    private var editorBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Publică produs").font(.title2).fontWeight(.semibold)

                IncompletePublishesSection(records: $pendingPublishes, isBusy: $isBusy, log: { log($0) }) { ok, err in
                    successMessage = ok; errorMessage = err
                    loadExistingIfNeeded()
                }

                if !inbox.isEmpty {
                    Menu {
                        ForEach(inbox) { sub in
                            Button("\(sub.name) — v\(sub.version) (\(sub.id))") { applySubmission(sub) }
                        }
                    } label: {
                        Label("Din STYLE Lab (\(inbox.count))", systemImage: "tray.and.arrow.down")
                    }
                    .frame(maxWidth: 360, alignment: .leading)
                    .help("Pachete OFX validate și trimise de GDC STYLE Lab: completează singure ID-ul, numele, versiunea și fișierele")
                }

                Picker("", selection: $isUpdate) {
                    Text("Produs nou").tag(false)
                    Text("Actualizare versiune existentă").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 360)
                .onChange(of: isUpdate) {
                    loadExistingIfNeeded()
                    if !isUpdate && !skipClear { clearForm() }
                    skipClear = false
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
                            Button("Șterge definitiv", role: .destructive) { Task { await deleteProducts([id]) } }
                            Button("Anulează", role: .cancel) {}
                        } message: {
                            Text("Fișierele sunt eliminate din repo-ul privat și produsul dispare din catalog la clienți. Nu poate fi anulat.")
                        }
                    }

                    batchDeleteBox
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: GDCTokens.Space.m) {
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

                        if type == .scripts {
                            Picker("Subfolder Scripts", selection: $scriptFolder) {
                                ForEach(ScriptFolder.allCases) { f in
                                    Text(f.rawValue).tag(f)
                                }
                            }
                            Text("Scriptul se instalează în Fusion/Scripts/\(scriptFolder.rawValue)/ — la nivel de utilizator, deci FĂRĂ parolă de administrator. Un pachet care are deja subfoldere proprii și le păstrează.")
                                .font(.caption).foregroundStyle(.secondary)
                        }

                        if type == .ofx {
                            Text("Alege folderul întreg „NumePlugin.ofx.bundle” (nu doar fișierul din interior) — Resolve identifică plugin-ul după numele exact al acelui folder.")
                                .font(.caption).foregroundStyle(.secondary)
                        }

                        TextField("Versiune", text: $version).textFieldStyle(.roundedBorder)
                        if let previousVersion {
                            HStack(spacing: 6) {
                                Text("Publicată acum: v\(previousVersion)").foregroundStyle(.secondary)
                                Image(systemName: "arrow.right").foregroundStyle(.secondary)
                                Text("nouă: v\(version.trimmingCharacters(in: .whitespaces))")
                                    .foregroundStyle(version.trimmingCharacters(in: .whitespaces) == previousVersion && pickedURL != nil ? .red : .primary)
                                if version.trimmingCharacters(in: .whitespaces) == previousVersion && pickedURL != nil {
                                    Text("— la fișiere noi versiunea trebuie schimbată").foregroundStyle(GDCTokens.Palette.error)
                                }
                            }
                            .font(.caption)
                        }

                        Picker("Acces", selection: $accessMode) {
                            ForEach(AccessMode.allCases) { mode in
                                Text(mode.label).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)

                        switch accessMode {
                        case .paid:
                            TextField("Preț (EUR, donație)", text: $priceText).textFieldStyle(.roundedBorder)
                            // Etapa 4 extinsă (2026-08-29) — sumă de
                            // SUSȚINERE promoțională, temporară (ex. Black
                            // Friday). Rămâne donație (Regula 3) — NICIODATĂ
                            // etichetată "reducere"/"discount"/"preț redus"
                            // în UI-ul clientului, doar "susținere promoțională".
                            TextField("Sumă promoțională temporară (EUR, opțional — activă doar în intervalul de mai jos)", text: $promoPriceText)
                                .textFieldStyle(.roundedBorder)
                        case .free:
                            Text("Clientul instalează direct, fără cod de activare.")
                                .font(.caption).foregroundStyle(.secondary)
                        case .trial:
                            Text("Clientul instalează direct, fără cod — apare pe card cu eticheta „Probă”. Include watermark-ul direct în fișier înainte de publicare; publică-l separat de versiunea plătită (ex. „Nume Produs (Probă)”).")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        TextField("Icon (SF Symbol, opțional)", text: $iconSymbol).textFieldStyle(.roundedBorder)
                        TextField("Link tutorial YouTube (opțional, nelistat)", text: $youtubeURL).textFieldStyle(.roundedBorder)

                        // Etapa 2 (2026-08-29) — linkuri multiple, 100% opționale.
                        DisclosureGroup("Linkuri suplimentare & rețele sociale (opțional)") {
                            VStack(alignment: .leading, spacing: GDCTokens.Space.s) {
                                TextField("Link Achiziție/Magazin extern", text: $purchaseURL).textFieldStyle(.roundedBorder)
                                TextField("Link Demo/Preview", text: $demoURL).textFieldStyle(.roundedBorder)
                                SocialLinksFields(state: $socialForm, youtubeLabel: "YouTube (canal, nu tutorialul de mai sus)")
                            }
                            .padding(.top, 6)
                        }

                        Picker("Compatibilitate", selection: $supportedOS) {
                            Label("Doar Mac", systemImage: SupportedOS.macOS.badgeSymbol).tag(SupportedOS.macOS)
                            Label("Doar Windows", systemImage: SupportedOS.windows.badgeSymbol).tag(SupportedOS.windows)
                            Label("Ambele platforme", systemImage: SupportedOS.crossPlatform.badgeSymbol).tag(SupportedOS.crossPlatform)
                        }
                        .pickerStyle(.segmented)
                        if isUpdate {
                            Text("Poți edita doar linkul YouTube (sau alte câmpuri) fără să alegi din nou fișierele — cele existente rămân neschimbate dacă nu alegi altele.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(GDCTokens.Space.s)
                }

                AccessEditorSection(

                    state: $accessForm,

                    // showsKind: false — aceasta sectiune are DEJA un camp nativ de

                    // gratuit/pret; un al doilea selector ar crea a doua sursa de adevar.

                    showsKind: false,

                    showsReferencePrice: false,

                    tagSuggestions: AccessTagSuggestions.plugins

                )


                CoverImagePicker(preset: .icon, selection: $coverSelection)
                SchedulingPicker(scheduling: $scheduling)

                if let errorMessage {
                    Text(errorMessage).foregroundStyle(GDCTokens.Palette.error)
                }
                if let successMessage {
                    Label(successMessage, systemImage: "checkmark.circle.fill").foregroundStyle(GDCTokens.Palette.success)
                }
                if !statusLines.isEmpty {
                    VStack(alignment: .leading, spacing: GDCTokens.Space.xxs) {
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
                if !isFormValid && !isBusy {
                    Text(validationHint).font(.caption).foregroundStyle(GDCTokens.Palette.warning)
                }
            }
            .padding(GDCTokens.Space.xl)
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
            && !(pickedURL != nil && previousVersion != nil && version.trimmingCharacters(in: .whitespaces) == previousVersion)   // fișiere noi sub aceeași versiune = clienții n-ar primi actualizarea (Regula 14)
            && (accessMode != .paid || Double(priceText) != nil)
            && (pickedURL != nil || (isUpdate && !existingFiles.isEmpty))
            && (type != .ofx || pickedURL == nil || isDirectory(pickedURL!))
    }

    private var validationHint: String {
        var missing: [String] = []
        if id.trimmingCharacters(in: .whitespaces).isEmpty { missing.append("ID") }
        if name.trimmingCharacters(in: .whitespaces).isEmpty { missing.append("Nume") }
        if version.trimmingCharacters(in: .whitespaces).isEmpty { missing.append("Versiune") }
        if pickedURL != nil, let pv = previousVersion, version.trimmingCharacters(in: .whitespaces) == pv { missing.append("Versiune diferită de cea publicată (v\(pv))") }
        if accessMode == .paid && Double(priceText) == nil { missing.append("Preț (număr valid)") }
        if pickedURL == nil && !(isUpdate && !existingFiles.isEmpty) { missing.append("Fișier sau folder") }
        if type == .ofx, let url = pickedURL, !isDirectory(url) {
            missing.append("Pentru OFX trebuie ales un folder, nu un fișier")
        }
        return "Lipsește: " + missing.joined(separator: ", ")
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

    /// „1.2.3” → „1.2.4”; „2” → „2.0.1”; nenumeric → aceeași valoare cu „.1” (ex. „beta” → „beta.1”).
    static func nextVersion(after v: String) -> String {
        let parts = v.trimmingCharacters(in: .whitespaces).split(separator: ".").map(String.init)
        guard !parts.isEmpty, parts.allSatisfy({ Int($0) != nil }) else { return v + ".1" }
        var nums = parts.compactMap(Int.init)
        while nums.count < 3 { nums.append(0) }
        nums[nums.count - 1] += 1
        return nums.map(String.init).joined(separator: ".")
    }

    /// Completează formularul din trimiterea STYLE Lab: produs existent (același cod intern) → actualizare cu versiunea nouă; altfel produs nou.
    private func applySubmission(_ sub: StyleLabSubmission) {
        loadExistingIfNeeded()
        if existingItems.contains(where: { $0.id == sub.id }) {
            isUpdate = true
            id = sub.id
            fillFromExisting()
            version = sub.version
        } else {
            skipClear = isUpdate
            isUpdate = false
            clearForm()
            id = sub.id
            name = sub.name
            description = sub.description
            type = .ofx
            version = sub.version
            previousVersion = nil
        }
        pickedURL = URL(fileURLWithPath: sub.bundlePath)
        appliedSubmissionID = sub.id
        // Coperta cardului (iconița liniară din STYLE Lab): doar dacă produsul nu are deja una; se copiază în temporar (se mută la publicare).
        if let cover = sub.coverFile, FileManager.default.fileExists(atPath: cover) {
            if case .existing = coverSelection {} else {
                let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("stylelab-cover-\(sub.id).png")
                try? FileManager.default.removeItem(at: tmp)
                if (try? FileManager.default.copyItem(at: URL(fileURLWithPath: cover), to: tmp)) != nil { coverSelection = .local(processed: tmp, savings: "din STYLE Lab") }
            }
        }
    }

    private func loadExistingIfNeeded() {
        defer { NotificationCenter.default.post(name: .furnizorCatalogChanged, object: nil) }
        inbox = StyleLabInbox.pending()
        guard let catalog = try? CatalogEditor.load() else { return }
        existingItems = (catalog.items + catalog.scriptItems).sorted { $0.name < $1.name }
    }

    private func fillFromExisting() {
        guard let item = existingItems.first(where: { $0.id == id }) else { return }
        name = item.name
        description = item.description
        type = item.type
        previousVersion = item.version
        version = Self.nextVersion(after: item.version)   // sugestie: +1 la patch (editabilă); cea publicată rămâne vizibilă lângă câmp
        accessMode = item.isTrial ? .trial : (item.isFree ? .free : .paid)
        priceText = String(item.priceEUR)
        iconSymbol = item.iconSymbol ?? ""
        youtubeURL = item.youtubeURL ?? ""
        supportedOS = item.supportedOS
        purchaseURL = item.purchaseURL ?? ""
        demoURL = item.demoURL ?? ""
        socialForm = SocialLinksFormState(item.socialLinks)
        scheduling = item.scheduling
        accessForm = AccessFormState(item.access)
        promoPriceText = item.promoPriceEUR.map { String($0) } ?? ""
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
            // D2b: fișierele se pregătesc local (SHA-256), TOATE repo-urile implicate trec prin preflight
            // înainte de prima scriere, apoi PublishTransaction: fișiere → verificare pe server → catalog.
            var pluginFiles: [PluginFile]
            var sources: [(URL, PublishTransaction.FileRef)] = []
            if let pickedURL {
                let picked = try collectFiles(under: pickedURL)
                guard !picked.isEmpty else {
                    errorMessage = "Folderul ales nu conține niciun fișier."
                    return
                }
                // Repo-ul de destinatie depinde de tipul produsului
                // (arhitectura multi-repo) — scripturile au repo-ul lor.
                let repoKey = type == .scripts ? "scripts" : "files"
                for (localURL, relativePath) in picked {
                    let ref = PublishTransaction.FileRef(repoKey: repoKey, path: "\(trimmedID)/\(version)/\(relativePath)",
                                                         sha256: try PublishTransaction.sha256(of: localURL))
                    sources.append((localURL, ref))
                }
                pluginFiles = sources.map { PluginFile(path: $0.1.path, sha256: $0.1.sha256, repo: $0.1.repoKey) }
            } else {
                // Metadata-only update (e.g. just the YouTube link) — fișierele existente se reverifică pe server.
                pluginFiles = existingFiles
                log("Fără fișiere noi — păstrez cele \(existingFiles.count) existente.")
            }
            let fileRefs = pluginFiles.map {
                PublishTransaction.FileRef(repoKey: $0.repo ?? ResourceRepos.defaultRepoKey, path: $0.path, sha256: $0.sha256)
            }

            log("Verific și sincronizez toate repo-urile implicate (preflight)…")
            try PublishTransaction.preflight(repoKeys: fileRefs.map(\.repoKey))

            // Coperta se scrie în docs/covers/ ÎNAINTE de commit-ul catalogului, altfel
            // catalogul ar referi o imagine încă nepublicată (404 la clienți până la
            // următorul push) — vezi WARNING în CoverImageStore.
            let previousCover = existingItems.first { $0.id == trimmedID }?.coverImage
            let coverImage = try CoverImageStore.commit(coverSelection, id: trimmedID, previous: previousCover)
            if coverImage != nil { log("Imagine de prezentare pregătită") }

            func nilIfEmpty(_ s: String) -> String? {
                let t = s.trimmingCharacters(in: .whitespaces)
                return t.isEmpty ? nil : t
            }
            let item = PluginItem(
                id: trimmedID, name: name, type: type, description: description,
                version: version, files: pluginFiles,
                iconSymbol: iconSymbol.isEmpty ? nil : iconSymbol, priceEUR: price,
                isFree: isFreeFlag, isTrial: isTrialFlag,
                youtubeURL: trimmedYouTube.isEmpty ? nil : trimmedYouTube,
                bundleFolderName: bundleFolderName,
                scriptFolder: type == .scripts ? scriptFolder : nil,
                coverImage: coverImage,
                supportedOS: supportedOS,
                purchaseURL: nilIfEmpty(purchaseURL),
                demoURL: nilIfEmpty(demoURL),
                socialLinks: socialForm.model,
                scheduling: scheduling,
                promoPriceEUR: Double(promoPriceText.trimmingCharacters(in: .whitespaces))
            , access: accessForm.model)

            try PublishTransaction.publish(label: "\(trimmedID) \(version)", sources: sources, files: fileRefs,
                                           catalog: .upsertItems([item]), catalogMessage: "Catalog: \(name) \(version)",
                                           catalogPaths: ["docs/catalog.json", "docs/covers"], log: { log($0) })
            pendingPublishes = PublishJournal.pending()

            let fileWord = pluginFiles.count > 1 ? "\(pluginFiles.count) fișiere" : "1 fișier"
            let publishedName = name
            successMessage = "„\(publishedName)” e publicat (\(fileWord)) — apare la clienți la următorul refresh de catalog."
            if let sid = appliedSubmissionID { StyleLabInbox.remove(id: sid); appliedSubmissionID = nil; inbox = StyleLabInbox.pending() }
            if isUpdate {
                loadExistingIfNeeded()
                // Următoarea actualizare pornește deja de la versiunea următoare, cu cea publicată acum vizibilă lângă câmp (nu rămâne aceeași versiune).
                previousVersion = version
                version = Self.nextVersion(after: version)
                pickedURL = nil
            } else {
                // [2026-08-29, fix real, raportat de Cristi] Formularul
                // rămânea complet populat după publicare — trebuia să
                // închidă și să redeschidă aplicația ca să poată adăuga
                // UN ALT produs nou, fiindcă altfel risca să suprascrie
                // accidental același ID. La publicarea unui produs NOU
                // (nu o actualizare), golim formularul automat — mesajul
                // de succes rămâne vizibil, ca să știe ce tocmai a publicat.
                clearForm()
                successMessage = "„\(publishedName)” e publicat (\(fileWord)) — apare la clienți la următorul refresh de catalog. Formularul e gol, poți adăuga alt produs."
            }
        } catch {
            errorMessage = error.localizedDescription
            log("EROARE: \(error.localizedDescription)")
            pendingPublishes = PublishJournal.pending()
        }
    }

    /// Removes a product entirely — for something published by mistake.
    /// Deletes its whole folder (every version) from the private files
    /// repo AND its entry from the public catalog, so it's gone both as
    /// a downloadable file and as a storefront listing.
    /// Listă cu bife pentru ștergerea mai multor produse deodată (un singur pull/commit/push per repo).
    private var batchDeleteBox: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Ștergere multiplă").fontWeight(.semibold)
                    Text("\(batchSelection.count) bifate din \(existingItems.count)").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button(batchSelection.count == existingItems.count && !existingItems.isEmpty ? "Deselectează tot" : "Selectează tot") {
                        batchSelection = batchSelection.count == existingItems.count ? [] : Set(existingItems.map(\.id))
                    }
                    .disabled(existingItems.isEmpty || isBusy)
                    Button("Șterge bifate (\(batchSelection.count))", role: .destructive) { showBatchDeleteConfirm = true }
                        .disabled(batchSelection.isEmpty || isBusy)
                        .confirmationDialog("Ștergi definitiv \(batchSelection.count) produse?", isPresented: $showBatchDeleteConfirm, titleVisibility: .visible) {
                            Button("Șterge definitiv \(batchSelection.count) produse", role: .destructive) {
                                let ids = Array(batchSelection)
                                Task { await deleteProducts(ids) }
                            }
                            Button("Anulează", role: .cancel) {}
                        } message: {
                            Text(existingItems.filter { batchSelection.contains($0.id) }.map(\.name).sorted().joined(separator: ", ")
                                 + "\n\nFișierele sunt eliminate din repo-ul privat și produsele dispar din catalog la clienți. Nu poate fi anulat.")
                        }
                }
                ScrollView {
                    VStack(alignment: .leading, spacing: GDCTokens.Space.xxs) {
                        ForEach(existingItems) { item in
                            Toggle(isOn: Binding(get: { batchSelection.contains(item.id) },
                                                 set: { if $0 { batchSelection.insert(item.id) } else { batchSelection.remove(item.id) } })) {
                                HStack {
                                    Text(item.name)
                                    Text(item.id).font(.system(.caption2, design: .monospaced)).foregroundStyle(.tertiary)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 220)
            }
            .padding(GDCTokens.Space.s)
        }
    }

    /// Șterge unul sau mai multe produse: fișierele din repo-ul privat (doar dacă nu le folosește o resursă),
    /// coperta și intrarea din catalog; un singur commit + push per repo pentru tot lotul.
    private func deleteProducts(_ ids: [String]) async {
        errorMessage = nil
        successMessage = nil
        statusLines = []
        isBusy = true
        defer { isBusy = false }

        let items = existingItems.filter { ids.contains($0.id) }
        guard !items.isEmpty else { return }

        do {
            // D2b: catalogul întâi (confirmat pe server), apoi DOAR fișierele pe care nu le mai referă
            // nimic din catalog (alt produs, altă versiune, o resursă descărcabilă legată de ele).
            let folders = items.flatMap { item -> [PublishTransaction.FolderRef] in
                let repos = Set(item.files.map { $0.repo ?? ResourceRepos.defaultRepoKey })
                return (repos.isEmpty ? [ResourceRepos.defaultRepoKey] : Array(repos)).sorted()
                    .map { PublishTransaction.FolderRef(repoKey: $0, folder: "\(item.id)/") }
            }
            log("Verific și sincronizez toate repo-urile implicate (preflight)…")
            try PublishTransaction.preflight(repoKeys: folders.map(\.repoKey))

            // Copertele produselor din lot sunt ștergeri intenționate: garda anti-ștergere (max. 2) le ignoră doar pe ele.
            let coverPaths = Set(items.flatMap { item -> [String] in
                var names = [item.coverImage].compactMap { $0 }.map { "docs/" + $0 }
                for ext in ["png", "jpg", "jpeg", "webp", "heic"] { names.append("docs/\(CatalogAssets.coversFolderName)/\(item.id).\(ext)") }
                return names
            })
            try PublishTransaction.delete(
                label: items.count == 1 ? "Sterg \(items[0].id)" : "Sterg \(items.count) produse",
                folders: folders,
                catalog: .removeItems(ids: items.map(\.id), covers: Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0.coverImage) })),
                catalogMessage: items.count == 1 ? "Sterg din catalog: \(items[0].name)" : "Sterg din catalog: \(items.count) produse",
                catalogPaths: ["docs/catalog.json", "docs/covers"], expectedDeletions: Array(coverPaths), log: { log($0) })
            pendingPublishes = PublishJournal.pending()

            successMessage = items.count == 1
                ? "„\(items[0].name)” a fost șters complet — dispare la următorul refresh de catalog."
                : "\(items.count) produse au fost șterse complet — dispar la următorul refresh de catalog."
            batchSelection.subtract(ids)
            clearForm()
            loadExistingIfNeeded()
        } catch {
            errorMessage = error.localizedDescription
            log("EROARE: \(error.localizedDescription)")
            pendingPublishes = PublishJournal.pending()
        }
    }

    private func clearForm() {
        id = ""
        name = ""
        description = ""
        type = .dctl
        version = "1.0.0"
        previousVersion = nil
        priceText = "0"
        accessMode = .paid
        iconSymbol = "wand.and.stars"
        youtubeURL = ""
        purchaseURL = ""
        demoURL = ""
        socialForm.reset()
        scheduling = nil
        accessForm.reset()
        promoPriceText = ""
        existingFiles = []
        existingBundleFolderName = nil
        coverSelection = .none
        pickedURL = nil
    }

    private func log(_ line: String) {
        statusLines.append(line)
    }
}
