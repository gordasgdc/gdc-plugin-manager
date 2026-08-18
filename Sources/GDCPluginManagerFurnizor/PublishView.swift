import SwiftUI
import AppKit
import CryptoKit
import GDCPluginManagerCore

struct PublishView: View {
    @State private var pickedFileURL: URL?
    @State private var isUpdate = false
    @State private var existingItems: [PluginItem] = []

    @State private var id = ""
    @State private var name = ""
    @State private var description = ""
    @State private var type: PluginType = .dctl
    @State private var version = "1.0.0"
    @State private var priceText = "0"
    @State private var isFree = false
    @State private var iconSymbol = "wand.and.stars"

    @State private var isBusy = false
    @State private var statusLines: [String] = []
    @State private var errorMessage: String?
    @State private var successMessage: String?

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
                .onChange(of: isUpdate) { loadExistingIfNeeded() }

                if isUpdate {
                    Picker("Produs existent", selection: $id) {
                        Text("Alege…").tag("")
                        ForEach(existingItems) { item in
                            Text(item.name).tag(item.id)
                        }
                    }
                    .onChange(of: id) { fillFromExisting() }
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

                        TextField("Versiune", text: $version).textFieldStyle(.roundedBorder)

                        Toggle("Gratuit — clientul instalează direct, fără cod de activare", isOn: $isFree)

                        if !isFree {
                            TextField("Preț (EUR, donație)", text: $priceText).textFieldStyle(.roundedBorder)
                        }
                        TextField("Icon (SF Symbol, opțional)", text: $iconSymbol).textFieldStyle(.roundedBorder)
                    }
                    .padding(8)
                }

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
            Text(pickedFileURL?.lastPathComponent ?? "Niciun fișier ales")
                .foregroundStyle(pickedFileURL == nil ? .secondary : .primary)
            Spacer()
            Button("Alege fișier…") { pickFile() }
        }
    }

    private var isFormValid: Bool {
        !id.trimmingCharacters(in: .whitespaces).isEmpty
            && !name.trimmingCharacters(in: .whitespaces).isEmpty
            && !version.trimmingCharacters(in: .whitespaces).isEmpty
            && (isFree || Double(priceText) != nil)
            && pickedFileURL != nil
    }

    private func pickFile() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK {
            pickedFileURL = panel.url
        }
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
        isFree = item.isFree
        priceText = String(item.priceEUR)
        iconSymbol = item.iconSymbol ?? ""
        // version left for the user to bump; file must be re-picked either way.
    }

    private func publish() async {
        errorMessage = nil
        successMessage = nil
        statusLines = []
        isBusy = true
        defer { isBusy = false }

        guard let fileURL = pickedFileURL else { return }
        let price = isFree ? 0 : (Double(priceText) ?? 0)
        let trimmedID = id.trimmingCharacters(in: .whitespaces)

        do {
            log("Calculez sha256…")
            let data = try Data(contentsOf: fileURL)
            let sha = SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()

            log("Actualizez repo-ul privat (pull)…")
            try GitOps.pull(at: RepoCheckoutPaths.privateFilesRepo)

            let relativePath = "\(trimmedID)/\(version)/\(fileURL.lastPathComponent)"
            let destURL = RepoCheckoutPaths.privateFilesRepo.appendingPathComponent(relativePath)
            try FileManager.default.createDirectory(at: destURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.removeItem(at: destURL)
            }
            try FileManager.default.copyItem(at: fileURL, to: destURL)
            log("Fișier copiat în \(relativePath)")

            log("Trimit fișierul (commit + push, repo privat)…")
            try GitOps.commitAndPush(at: RepoCheckoutPaths.privateFilesRepo, message: "\(trimmedID) \(version)")

            log("Actualizez catalogul (pull, repo public)…")
            try GitOps.pull(at: RepoCheckoutPaths.publicCatalogRepo)

            let item = PluginItem(
                id: trimmedID, name: name, type: type, description: description,
                version: version, filePath: relativePath, sha256: sha,
                iconSymbol: iconSymbol.isEmpty ? nil : iconSymbol, priceEUR: price, isFree: isFree
            )
            try CatalogEditor.upsert(item)
            log("Catalog actualizat local")

            log("Public catalogul (commit + push, repo public)…")
            try GitOps.commitAndPush(at: RepoCheckoutPaths.publicCatalogRepo, message: "Catalog: \(name) \(version)")

            successMessage = "„\(name)” e publicat — apare la clienți la următorul refresh de catalog."
            loadExistingIfNeeded()
        } catch {
            errorMessage = error.localizedDescription
            log("EROARE: \(error.localizedDescription)")
        }
    }

    private func log(_ line: String) {
        statusLines.append(line)
    }
}
