import SwiftUI
import CryptoKit
import GDCPluginManagerCore

/// De unde vine fișierul unei resurse: încărcat direct pe server (repo-ul
/// privat de fișiere, ca la produsele Resolve) sau doar un link extern, ca
/// până acum. Cerut explicit 2026-09-14 — ambele variante rămân posibile.
enum ResourceFileSource: String, CaseIterable, Identifiable {
    /// [2026-09-14] `reuseProduct`: aceleași fișiere ca un produs deja
    /// publicat, FĂRĂ să le reîncărcăm. Cerut direct — aceleași LUT-uri se
    /// oferă și auto-instalabile pentru Resolve, și descărcabile pentru
    /// Premiere/Final Cut, iar reîncărcarea le-ar stoca de două ori.
    case upload, reuseProduct, externalLink
    var id: String { rawValue }
    var label: String {
        switch self {
        case .upload: return "Încarcă fișier"
        case .reuseProduct: return "Fișierele unui produs"
        case .externalLink: return "Link extern"
        }
    }
}

/// Gestionează secțiunile "Resurse Download" (LUT/SFX/VFX/Plugin) — Etapa 2
/// din Planul Integrat de Upgrade v2.0 (2026-08-29, confirmat explicit de
/// Cristi: "produse noi, separate, cu simplu link de download, ca Audio").
/// Modelat 1:1 pe `PublishAudioView`: niciun fișier în
/// `gdc-plugin-manager-files`, nicio licență — doar un link + descriere,
/// scrise direct în `docs/catalog.json`. Diferă de Audio prin selectorul
/// de categorie (LUT/SFX/VFX/Plugin) și câmpurile din Etapa 2
/// (compatibilitate OS, Achiziție/Demo, rețele sociale).
struct PublishDownloadableResourceView: View {
    @State private var existingResources: [DownloadableResource] = []
    @State private var editingID: String?

    @State private var id = ""
    @State private var name = ""
    @State private var description = ""
    @State private var category: DownloadCategory = .lut
    @State private var url = ""
    /// Sursa fișierului + fișierul ales (doar pentru upload direct).
    @State private var fileSource: ResourceFileSource = .externalLink
    @State private var pickedURLs: [URL] = []
    @State private var pdfKind: PDFKind = .technicalGuide
    /// La editare: fișierul deja publicat, păstrat dacă nu se alege altul.
    @State private var existingFilePath: String?
    @State private var existingFileSHA: String?
    @State private var existingFileRepo: String?
    @State private var existingFiles: [PluginFile] = []
    /// Produsele deja publicate, din care se pot refolosi fișierele.
    @State private var publishedProducts: [PluginItem] = []
    @State private var sourceProductID: String = ""
    @State private var youtubeURL = ""
    @State private var supportedOS: SupportedOS = .crossPlatform
    // Licențiere adăugată 2026-08-29 (cerut explicit: "nu am varianta aia
    // de gratuit, plătit, trimite ID mașină, cumpără produsul, WhatsApp").
    // Reutilizează `AccessMode`, definit deja în PublishView.swift.
    @State private var accessMode: AccessMode = .free
    @State private var priceText = "0"
    @State private var promoPriceText = ""
    @State private var purchaseURL = ""
    @State private var demoURL = ""
    @State private var socialForm = SocialLinksFormState()
    /// Coperta resursei. Preset `.icon` — la fel ca la Aplicații/Audio.
    @State private var coverSelection: CoverImageSelection = .none
    @State private var scheduling: Scheduling?

    // Acces/grup/etichete — editor COMUN (2026-09-11), vezi AccessEditorSection.swift

    @State private var accessForm = AccessFormState()


    @State private var isBusy = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var pendingDelete: DownloadableResource?

    private func categoryLabel(_ c: DownloadCategory) -> String {
        switch c {
        case .lut: return "LUT"
        case .sfx: return "Efecte Audio / SFX"
        case .vfx: return "VFX / Overlays"
        case .plugin: return "Plugin"
        case .pdf: return "PDF / Ghid / Carte"
        case .script: return "Script (uz general)"
        case .unknown: return "Necunoscut"
        }
    }

    private func pdfKindLabel(_ k: PDFKind) -> String {
        switch k {
        case .audioInstructions: return "Instrucțiuni Audio"
        case .technicalGuide: return "Ghid Tehnic"
        case .book: return "Carte"
        case .manual: return "Manual"
        }
    }

    /// Numele fișierului deja încărcat (pentru afișare la editare).
    private var currentFileName: String? {
        if pickedURLs.count == 1 { return pickedURLs[0].lastPathComponent }
        if pickedURLs.count > 1 { return "\(pickedURLs.count) elemente alese" }
        guard let existingFilePath else { return nil }
        return (existingFilePath as NSString).lastPathComponent
    }

    /// [2026-09-14] Accepta un FISIER, MAI MULTE fisiere sau un FOLDER intreg
    /// (cu subfoldere). Raportat direct: un pachet de LUT-uri trebuia urcat
    /// bucata cu bucata, fiindca selectorul accepta un singur fisier.
    private func pickFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        // Fara filtru de tip nici macar la PDF: un „ghid" poate fi un folder
        // cu PDF-uri si imagini, iar filtrul ar ascunde folderele din dialog.
        panel.message = "Alege un fișier, mai multe fișiere sau un folder întreg."
        panel.prompt = "Alege"
        if panel.runModal() == .OK { pickedURLs = panel.urls }
    }

    /// Fisierele de urcat, cu calea RELATIVA pastrata: un folder ales devine
    /// „<nume folder>/<subfolder>/<fisier>", exact ca la pachetele de produs.
    private func collectPicked() throws -> [(url: URL, relativePath: String)] {
        var out: [(URL, String)] = []
        let fm = FileManager.default
        for url in pickedURLs {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else { continue }
            if isDir.boolValue {
                let root = url.lastPathComponent
                guard let e = fm.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey]) else { continue }
                for case let child as URL in e {
                    guard (try? child.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else { continue }
                    if child.lastPathComponent == ".DS_Store" { continue }
                    let rel = child.path.replacingOccurrences(of: url.path + "/", with: "")
                    out.append((child, "\(root)/\(rel)"))
                }
            } else {
                out.append((url, url.lastPathComponent))
            }
        }
        return out
    }

    /// Repo-ul de destinatie, dupa categorie — PDF-urile au repo-ul lor, restul
    /// resurselor descarcabile pe al lor. Nimic nu mai ajunge in arhiva
    /// principala de produse.
    private var targetRepoKey: String {
        switch category {
        case .pdf: return "pdfs"
        case .script: return "scripts"      // acelasi repo ca scripturile Resolve
        default: return "resources"
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Resurse Download (LUT/SFX/VFX/Plugin)").font(.title2).fontWeight(.semibold)
                Text("Download direct — pentru Premiere Pro, Final Cut Pro sau DaVinci Resolve. Nu se auto-instalează nicăieri; clientul descarcă fișierul și îl importă manual.")
                    .font(.caption).foregroundStyle(.secondary)

                GroupBox {
                    VStack(alignment: .leading, spacing: GDCTokens.Space.m) {
                        TextField("ID (ex. lut-wedding-pack, nu se mai poate schimba)", text: $id)
                            .textFieldStyle(.roundedBorder)
                            .disabled(editingID != nil)
                        TextField("Nume", text: $name).textFieldStyle(.roundedBorder)
                        Picker("Categorie", selection: $category) {
                            ForEach(DownloadCategory.allCases) { c in
                                Text(categoryLabel(c)).tag(c)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: category) { _, newValue in
                            // PDF-urile se încarcă implicit direct pe server —
                            // asta e chiar motivul categoriei. Restul rămân pe
                            // link extern, ca până acum.
                            if newValue == .pdf && existingFilePath == nil && pickedURLs.isEmpty {
                                fileSource = .upload
                            }
                        }

                        if category == .pdf {
                            Picker("Tip", selection: $pdfKind) {
                                ForEach(PDFKind.allCases) { k in
                                    Text(pdfKindLabel(k)).tag(k)
                                }
                            }
                            .pickerStyle(.menu)
                        }

                        Picker("Sursă fișier", selection: $fileSource) {
                            ForEach(ResourceFileSource.allCases) { src in
                                Text(src.label).tag(src)
                            }
                        }
                        .pickerStyle(.segmented)

                        if fileSource == .reuseProduct {
                            Picker("Produs sursă", selection: $sourceProductID) {
                                Text("— alege un produs —").tag("")
                                ForEach(publishedProducts) { p in
                                    Text("\(p.name) (\(p.type.label), \(p.files.count) fișiere)").tag(p.id)
                                }
                            }
                            .pickerStyle(.menu)
                            if let src = publishedProducts.first(where: { $0.id == sourceProductID }) {
                                Text("Se vor lega \(src.files.count) fișiere, exact cele ale produsului. Nu se încarcă nimic — același conținut nu se stochează de două ori.")
                                    .font(.caption).foregroundStyle(.secondary)
                            } else {
                                Text("Alege produsul ale cărui fișiere vor fi oferite și aici.")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }

                        if fileSource == .upload {
                            HStack(spacing: 10) {
                                Button("Alege fișier…") { pickFile() }
                                if let currentFileName {
                                    Text(currentFileName).font(.caption).lineLimit(1).truncationMode(.middle)
                                    if !pickedURLs.isEmpty {
                                        Text("(nou)").font(.caption2).foregroundStyle(GDCTokens.Palette.success)
                                    }
                                } else {
                                    Text("Niciun fișier ales").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Text("Fișierul se încarcă direct pe server. Clientul îl descarcă din aplicație, fără browser.")
                                .font(.caption).foregroundStyle(.secondary)
                        } else {
                            TextField("Link fișier de descărcare (https://…)", text: $url).textFieldStyle(.roundedBorder)
                        }
                        TextEditor(text: $description)
                            .frame(minHeight: 80)
                            .overlay(alignment: .topLeading) {
                                if description.isEmpty {
                                    Text("Informații / descriere (format, compatibilitate host, conținut pachet…)")
                                        .foregroundStyle(.secondary)
                                        .padding(.top, GDCTokens.Space.s).padding(.leading, 5)
                                        .allowsHitTesting(false)
                                }
                            }
                            .overlay(RoundedRectangle(cornerRadius: GDCTokens.Radius.badge).stroke(.separator))
                        TextField("Link tutorial YouTube (opțional, nelistat)", text: $youtubeURL).textFieldStyle(.roundedBorder)

                        Picker("Acces", selection: $accessMode) {
                            ForEach(AccessMode.allCases) { mode in
                                Text(mode.label).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        switch accessMode {
                        case .paid:
                            TextField("Preț (EUR, donație)", text: $priceText).textFieldStyle(.roundedBorder)
                            TextField("Sumă promoțională temporară (EUR, opțional — activă doar în intervalul de mai jos)", text: $promoPriceText)
                                .textFieldStyle(.roundedBorder)
                        case .free:
                            Text("Clientul descarcă direct, fără cod de activare.")
                                .font(.caption).foregroundStyle(.secondary)
                        case .trial:
                            Text("Clientul descarcă direct, fără cod — apare cu eticheta „Probă”. Include watermark-ul direct în fișier înainte de publicare.")
                                .font(.caption).foregroundStyle(.secondary)
                        }

                        Picker("Compatibilitate", selection: $supportedOS) {
                            Label("Doar Mac", systemImage: SupportedOS.macOS.badgeSymbol).tag(SupportedOS.macOS)
                            Label("Doar Windows", systemImage: SupportedOS.windows.badgeSymbol).tag(SupportedOS.windows)
                            Label("Ambele platforme", systemImage: SupportedOS.crossPlatform.badgeSymbol).tag(SupportedOS.crossPlatform)
                        }
                        .pickerStyle(.segmented)

                        DisclosureGroup("Linkuri suplimentare & rețele sociale (opțional)") {
                            VStack(alignment: .leading, spacing: GDCTokens.Space.s) {
                                TextField("Link Achiziție/Magazin extern", text: $purchaseURL).textFieldStyle(.roundedBorder)
                                TextField("Link Demo/Preview", text: $demoURL).textFieldStyle(.roundedBorder)
                                SocialLinksFields(state: $socialForm, youtubeLabel: "YouTube (canal, nu tutorialul de mai sus)")
                            }
                            .padding(.top, 6)
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

                    tagSuggestions: AccessTagSuggestions.audioVFX

                )


                CoverImagePicker(preset: .icon, selection: $coverSelection)
                SchedulingPicker(scheduling: $scheduling)
                    .id(editingID ?? "new")

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
                    Button(editingID == nil ? "Publică" : "Actualizează") { Task { await publish() } }
                        .disabled(isBusy || !isFormValid)
                    if editingID != nil {
                        Button("Resursă nouă") { clearForm() }
                    }
                }
                if !isFormValid && !isBusy {
                    Text(validationHint).font(.caption).foregroundStyle(GDCTokens.Palette.warning)
                }

                if !existingResources.isEmpty {
                    Divider()
                    Text("Resurse publicate").font(.headline)
                    ForEach(existingResources) { resource in
                        HStack {
                            VStack(alignment: .leading) {
                                HStack(spacing: 6) {
                                    Text(resource.name).fontWeight(.medium)
                                    Text(categoryLabel(resource.category).uppercased())
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(resource.category.tintColor)
                                        .padding(.horizontal, 6).padding(.vertical, GDCTokens.Space.xxs)
                                        .background(Capsule().fill(resource.category.tintColor.opacity(0.15)))
                                }
                                if resource.sourceProductID != nil {
                                    Text("🔗").font(.caption2)
                                        .help("Folosește fișierele produsului „\(resource.sourceProductID ?? "")”")
                                }
                                Text(resource.hasDirectFile
                                     ? (resource.directFileCount > 1
                                        ? "⤓ \(resource.directFileCount) fișiere pe server"
                                        : "⤓ \(resource.directFileName ?? "fișier pe server")")
                                     : resource.url)
                                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                            Spacer()
                            Button("Editează") { load(resource) }
                            Button("Șterge", role: .destructive) { pendingDelete = resource }
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
        let hasFile = !pickedURLs.isEmpty || existingFilePath != nil || !existingFiles.isEmpty
        if fileSource == .reuseProduct {
            return !id.trimmingCharacters(in: .whitespaces).isEmpty
                && !name.trimmingCharacters(in: .whitespaces).isEmpty
                && publishedProducts.contains { $0.id == sourceProductID && !$0.files.isEmpty }
                && (accessMode != .paid || Double(priceText) != nil)
        }
        let linkOK = URL(string: url) != nil && (url.hasPrefix("http://") || url.hasPrefix("https://"))
        return !id.trimmingCharacters(in: .whitespaces).isEmpty
            && !name.trimmingCharacters(in: .whitespaces).isEmpty
            && (fileSource == .upload ? hasFile : linkOK)
            && (accessMode != .paid || Double(priceText) != nil)
    }

    /// Explică EXACT ce lipseste — cerut explicit 2026-08-29, dupa ce
    /// butonul "Publică" a ramas dezactivat fara mesaj pe formularul de
    /// Oferte Parteneri (acelasi risc exista si aici).
    private var validationHint: String {
        var missing: [String] = []
        if id.trimmingCharacters(in: .whitespaces).isEmpty { missing.append("ID") }
        if name.trimmingCharacters(in: .whitespaces).isEmpty { missing.append("Nume") }
        if fileSource == .reuseProduct {
            if !publishedProducts.contains(where: { $0.id == sourceProductID && !$0.files.isEmpty }) {
                missing.append("Produsul sursă (unul care are fișiere publicate)")
            }
        } else if fileSource == .upload {
            if pickedURLs.isEmpty && existingFilePath == nil && existingFiles.isEmpty { missing.append("Fișierul sau folderul de încărcat") }
        } else if !url.hasPrefix("http://") && !url.hasPrefix("https://") {
            missing.append("Link descărcare (trebuie să înceapă cu http:// sau https://)")
        } else if URL(string: url) == nil {
            missing.append("Link descărcare (format invalid)")
        }
        if accessMode == .paid && Double(priceText) == nil { missing.append("Preț (număr valid)") }
        return "Lipsește: " + missing.joined(separator: ", ")
    }

    private func loadExisting() {
        if let catalog = try? CatalogEditor.load() {
            existingResources = (catalog.downloadableResources + catalog.pdfResources + catalog.scriptResources)
                .sorted { $0.name < $1.name }
            publishedProducts = (catalog.items + catalog.scriptItems)
                .filter { !$0.files.isEmpty }
                .sorted { $0.name < $1.name }
        }
    }

    private func load(_ resource: DownloadableResource) {
        editingID = resource.id
        id = resource.id
        name = resource.name
        description = resource.description
        category = resource.category
        url = resource.url
        existingFilePath = resource.filePath
        existingFileSHA = resource.fileSHA256
        existingFileRepo = resource.fileRepo
        pickedURLs = []
        existingFiles = resource.files
        sourceProductID = resource.sourceProductID ?? ""
        fileSource = resource.sourceProductID != nil ? .reuseProduct
                   : (resource.hasDirectFile ? .upload : .externalLink)
        pdfKind = resource.pdfKind ?? .technicalGuide
        youtubeURL = resource.youtubeURL ?? ""
        supportedOS = resource.supportedOS
        purchaseURL = resource.purchaseURL ?? ""
        demoURL = resource.demoURL ?? ""
        socialForm = SocialLinksFormState(resource.socialLinks)
        coverSelection = resource.coverImage.map { .existing($0) } ?? .none
        scheduling = resource.scheduling
        accessForm = AccessFormState(resource.access)
        accessMode = resource.isTrial ? .trial : (resource.isFree ? .free : .paid)
        priceText = String(resource.priceEUR)
        promoPriceText = resource.promoPriceEUR.map { String($0) } ?? ""
        successMessage = nil
        errorMessage = nil
    }

    private func clearForm() {
        editingID = nil
        id = ""
        name = ""
        description = ""
        category = .lut
        url = ""
        fileSource = .externalLink
        pickedURLs = []
        existingFiles = []
        sourceProductID = ""
        existingFilePath = nil
        existingFileSHA = nil
        existingFileRepo = nil
        pdfKind = .technicalGuide
        youtubeURL = ""
        supportedOS = .crossPlatform
        purchaseURL = ""
        demoURL = ""
        socialForm.reset()
        coverSelection = .none
        scheduling = nil
        accessForm.reset()
        accessMode = .free
        priceText = "0"
        promoPriceText = ""
    }

    private func publish() async {
        errorMessage = nil
        successMessage = nil
        isBusy = true
        defer { isBusy = false }

        func nilIfEmpty(_ s: String) -> String? {
            let t = s.trimmingCharacters(in: .whitespaces)
            return t.isEmpty ? nil : t
        }
        let resourceID = id.trimmingCharacters(in: .whitespaces)

        do {
            // Fișierul urcă pe server ÎNAINTE de catalog — altfel catalogul ar
            // referi un fișier încă nepublicat (404 la clienți până la
            // următorul push). Aceeași ordine ca la produsele Resolve și la
            // imaginile de copertă.
            var filePath = existingFilePath
            var fileSHA = existingFileSHA
            var fileRepoKey = existingFileRepo
            var resourceFiles = existingFiles
            var sourceID: String? = nil
            var sources: [(URL, PublishTransaction.FileRef)] = []
            if fileSource == .upload, !pickedURLs.isEmpty {
                let picked = try collectPicked()
                guard !picked.isEmpty else {
                    errorMessage = "Selecția nu conține niciun fișier."
                    return
                }
                // BUG REPARAT (2026-09-14): repo-ul era hardcodat pe "pdfs",
                // deci un pachet de LUT-uri urcat aici ajungea in repo-ul de
                // PDF-uri. Acum destinatia se alege dupa categorie.
                let repoKey = targetRepoKey
                fileRepoKey = repoKey
                var uploaded: [PluginFile] = []
                for (localURL, relativePath) in picked {
                    let ref = PublishTransaction.FileRef(repoKey: repoKey, path: "\(resourceID)/\(relativePath)",
                                                         sha256: try PublishTransaction.sha256(of: localURL))
                    sources.append((localURL, ref))
                    uploaded.append(PluginFile(path: ref.path, sha256: ref.sha256, repo: repoKey))
                }
                resourceFiles = uploaded
                sourceID = nil
                // Forma veche (un singur fisier) ramane completata cand chiar
                // e un singur fisier — clientii 1.31/1.32 o citesc pe aia.
                filePath = uploaded.count == 1 ? uploaded[0].path : nil
                fileSHA = uploaded.count == 1 ? uploaded[0].sha256 : nil
            } else if fileSource == .reuseProduct {
                // Nu se urca NIMIC: legam exact fisierele produsului sursa, cu
                // caile si repo-urile lor. Acelasi continut nu ajunge stocat de
                // doua ori, iar daca produsul e sters, fisierele raman in repo
                // (CatalogEditor.remove nu le atinge), deci resursa continua sa
                // functioneze.
                guard let src = publishedProducts.first(where: { $0.id == sourceProductID }) else {
                    errorMessage = "Produsul sursă ales nu mai există în catalog."
                    return
                }
                resourceFiles = src.files
                sourceID = src.id
                fileRepoKey = src.files.first?.repo
                filePath = src.files.count == 1 ? src.files[0].path : nil
                fileSHA = src.files.count == 1 ? src.files[0].sha256 : nil
            } else if fileSource == .externalLink {
                // Trecerea înapoi pe link extern nu trebuie să lase în catalog
                // o referință către un fișier care nu mai e folosit.
                filePath = nil
                fileSHA = nil
                fileRepoKey = nil
                resourceFiles = []
                sourceID = nil
            }

            // D2b: toate repo-urile implicate (catalog + fișierele referite) verificate înainte de prima scriere.
            let fileRefs = resourceFiles.map {
                PublishTransaction.FileRef(repoKey: $0.repo ?? ResourceRepos.defaultRepoKey, path: $0.path, sha256: $0.sha256)
            }
            try PublishTransaction.preflight(repoKeys: fileRefs.map(\.repoKey))

            let previousCover = existingResources.first { $0.id == resourceID }?.coverImage
            let coverImage = try CoverImageStore.commit(coverSelection, id: resourceID, previous: previousCover)

            let isFreeFlag = accessMode != .paid
            let isTrialFlag = accessMode == .trial
            let price = isFreeFlag ? 0 : (Double(priceText) ?? 0)
            let resource = DownloadableResource(
                id: resourceID, name: name, description: description, category: category, url: url,
                youtubeURL: nilIfEmpty(youtubeURL), coverImage: coverImage, supportedOS: supportedOS,
                purchaseURL: nilIfEmpty(purchaseURL), demoURL: nilIfEmpty(demoURL),
                socialLinks: socialForm.model, scheduling: scheduling,
                isFree: isFreeFlag, isTrial: isTrialFlag, priceEUR: price,
                promoPriceEUR: Double(promoPriceText.trimmingCharacters(in: .whitespaces))
            , access: accessForm.model,
                filePath: filePath, fileSHA256: fileSHA, fileRepo: fileRepoKey, files: resourceFiles,
                pdfKind: category == .pdf ? pdfKind : nil,
                sourceProductID: sourceID)
            try PublishTransaction.publish(label: "Resursă \(resourceID)", sources: sources, files: fileRefs,
                                           catalog: .upsertDownloadableResource(resource),
                                           catalogMessage: "Resursă download: \(resource.name)",
                                           catalogPaths: ["docs/catalog.json", "docs/covers"])
            successMessage = "„\(resource.name)” e publicat — apare la clienți la următorul refresh de catalog."
            clearForm()
            loadExisting()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func delete(_ resource: DownloadableResource?) async {
        guard let resource else { return }
        pendingDelete = nil
        errorMessage = nil
        successMessage = nil
        isBusy = true
        defer { isBusy = false }

        do {
            try GitOps.pull(at: RepoCheckoutPaths.publicCatalogRepo)
            try CoverImageStore.commit(.none, id: resource.id, previous: resource.coverImage)
            try CatalogEditor.removeDownloadableResource(id: resource.id)
            try GitOps.commitAndPush(at: RepoCheckoutPaths.publicCatalogRepo, message: "Sterg resursă download: \(resource.name)", paths: ["docs/catalog.json", "docs/covers"])
            successMessage = "„\(resource.name)” a fost șters."
            if editingID == resource.id { clearForm() }
            loadExisting()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
