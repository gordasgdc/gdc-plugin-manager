import SwiftUI
import AppKit

/// [2026-09-03] Ecranul de Backup & Restaurare — vezi BackupArchive.swift
/// pentru motorul de criptare si pentru motivul pentru care acest modul e
/// cel mai important din aplicatia Furnizor.
struct BackupView: View {
    @State private var components: [BackupArchive.Component] = []
    @State private var selected: Set<String> = []
    @State private var password = ""
    @State private var passwordConfirm = ""
    @State private var isWorking = false
    @State private var statusText = ""
    @State private var progress: Double = 0
    @State private var resultMessage: String?
    @State private var resultIsError = false

    // Restaurare
    @State private var restoreArchive: URL?
    @State private var restoreInfo: BackupArchive.ArchiveInfo?
    @State private var restorePassword = ""
    @State private var showRestoreConfirm = false

    private var criticalMissing: Bool {
        components.contains { $0.isCritical && !selected.contains($0.id) }
    }
    private var passwordProblem: String? {
        if password.count < 12 {
            return "Parola trebuie să aibă cel puțin 12 caractere — ea este singura protecție a cheii de semnare."
        }
        if password != passwordConfirm { return "Cele două parole nu coincid." }
        return nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                Divider()
                exportSection
                Divider()
                restoreSection
            }
            .padding(22)
            .frame(maxWidth: 820, alignment: .leading)
        }
        .onAppear(perform: reload)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Backup & Restaurare").font(.title2).fontWeight(.semibold)
            Text("Un singur fișier criptat care conține tot ce ține de Furnizor pe acest Mac. "
                 + "Îl duci pe alt Mac, îl imporți, și aplicația pornește exact în starea de aici.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // Avertismentul care justifica existenta modulului. Nu e decor:
            // la auditul din 2026-09-03 cheia privata exista intr-un singur
            // exemplar, fara Time Machine si fara nicio alta copie.
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 3) {
                    Text("De ce contează").fontWeight(.semibold)
                    Text("Cheia privată de semnare există într-un singur exemplar, pe acest Mac. "
                         + "Cu ea se emit licențele pentru toate aplicațiile GDC. Dacă discul cedează, "
                         + "licențele deja vândute continuă să funcționeze, dar nu se mai poate emite "
                         + "niciuna nouă — pentru niciun produs, niciodată. Ține un backup în afara "
                         + "acestui Mac.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(12)
            .background(Color.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: - Export

    private var exportSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Generează backup criptat").font(.headline)

            if components.isEmpty {
                Text("Nu am găsit nicio componentă de salvat pe acest Mac.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(components) { component in
                    Toggle(isOn: Binding(
                        get: { selected.contains(component.id) },
                        set: { on in
                            if on { selected.insert(component.id) } else { selected.remove(component.id) }
                        })) {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(component.label)
                                if component.isCritical {
                                    Text("ESENȚIAL")
                                        .font(.caption2).fontWeight(.bold)
                                        .padding(.horizontal, 5).padding(.vertical, 1)
                                        .background(Color.red.opacity(0.15), in: Capsule())
                                        .foregroundStyle(.red)
                                }
                                if component.isOptional {
                                    Text("mare").font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                            Text(component.detail).font(.caption).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                if criticalMissing {
                    Label("Ai debifat o componentă esențială. Backup-ul va fi incomplet.",
                          systemImage: "exclamationmark.triangle")
                        .font(.callout).foregroundStyle(.orange)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Parola master").font(.subheadline).fontWeight(.medium)
                    SecureField("Minim 12 caractere", text: $password)
                    SecureField("Confirmă parola", text: $passwordConfirm)
                    Text("Fără această parolă, arhiva nu poate fi decriptată de nimeni — nici de mine. "
                         + "Notează-o undeva sigur, separat de fișierul de backup.")
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let problem = passwordProblem, !password.isEmpty {
                        Text(problem).font(.caption).foregroundStyle(.red)
                    }
                }
                .frame(maxWidth: 420)

                Button {
                    chooseDestinationAndExport()
                } label: {
                    Label("Generează Backup Criptat…", systemImage: "lock.doc")
                }
                .disabled(isWorking || selected.isEmpty || passwordProblem != nil)
            }
        }
    }

    // MARK: - Restaurare

    private var restoreSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Importă backup / Restaurare").font(.headline)
            Text("Pe un Mac nou: alege fișierul de backup, introdu parola, iar aplicația își recreează "
                 + "singură folderele și își pune fișierele exact unde trebuie.")
                .font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                chooseArchive()
            } label: {
                Label("Alege fișierul de backup…", systemImage: "folder")
            }
            .disabled(isWorking)

            if let info = restoreInfo, let url = restoreArchive {
                VStack(alignment: .leading, spacing: 4) {
                    Text(url.lastPathComponent).fontWeight(.medium)
                    Text("Creat: \(info.createdAt.formatted(date: .abbreviated, time: .shortened)) "
                         + "pe „\(info.machineName)\" (Furnizor v\(info.appVersion))")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("Conține: " + info.contents.joined(separator: ", "))
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(10)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))

                SecureField("Parola backup-ului", text: $restorePassword)
                    .frame(maxWidth: 420)

                Button(role: .destructive) {
                    showRestoreConfirm = true
                } label: {
                    Label("Restaurează pe acest Mac", systemImage: "arrow.down.doc")
                }
                .disabled(isWorking || restorePassword.isEmpty)
                .confirmationDialog("Restaurez starea din backup?",
                                    isPresented: $showRestoreConfirm, titleVisibility: .visible) {
                    Button("Restaurează", role: .destructive) { performRestore() }
                    Button("Renunță", role: .cancel) {}
                } message: {
                    Text("Fișierele existente cu același nume sunt păstrate alături, cu sufixul "
                         + "„.inainte-de-restaurare\" — nu se șterge nimic definitiv.")
                }
            }

            if isWorking {
                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(value: progress).frame(maxWidth: 420)
                    Text(statusText).font(.caption).foregroundStyle(.secondary)
                }
            }
            if let message = resultMessage {
                Label(message, systemImage: resultIsError ? "xmark.circle" : "checkmark.circle")
                    .foregroundStyle(resultIsError ? .red : .green)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Actiuni

    private func reload() {
        components = BackupArchive.availableComponents()
        // Implicit: tot ce nu e optional (adica tot ce nu se poate recupera
        // dintr-un git clone).
        selected = Set(components.filter { !$0.isOptional }.map(\.id))
    }

    private func chooseDestinationAndExport() {
        let panel = NSSavePanel()
        panel.title = "Salvează backup-ul criptat"
        panel.nameFieldStringValue = "GDC-Furnizor-Backup-\(Self.stamp()).gdcbk"
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }

        let chosen = components.filter { selected.contains($0.id) }
        let pass = password
        isWorking = true
        resultMessage = nil
        progress = 0
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try BackupArchive.create(components: chosen, password: pass, destination: url) { text, value in
                    DispatchQueue.main.async { statusText = text; progress = value }
                }
                let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? nil
                DispatchQueue.main.async {
                    isWorking = false
                    resultIsError = false
                    let sizeText = size.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) } ?? ""
                    resultMessage = "Backup salvat: \(url.lastPathComponent) (\(sizeText)). "
                        + "Pune-l în afara acestui Mac — pe un disc extern sau într-un cloud."
                    password = ""; passwordConfirm = ""
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
            } catch {
                DispatchQueue.main.async {
                    isWorking = false
                    resultIsError = true
                    resultMessage = error.localizedDescription
                }
            }
        }
    }

    private func chooseArchive() {
        let panel = NSOpenPanel()
        panel.title = "Alege backup-ul"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        restoreArchive = url
        resultMessage = nil
        do {
            restoreInfo = try BackupArchive.inspect(archive: url)
        } catch {
            restoreInfo = nil
            resultIsError = true
            resultMessage = error.localizedDescription
        }
    }

    private func performRestore() {
        guard let url = restoreArchive else { return }
        let pass = restorePassword
        isWorking = true
        resultMessage = nil
        progress = 0
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let restored = try BackupArchive.restore(archive: url, password: pass) { text, value in
                    DispatchQueue.main.async { statusText = text; progress = value }
                }
                DispatchQueue.main.async {
                    isWorking = false
                    resultIsError = false
                    resultMessage = "Restaurare completă — \(restored.count) componente puse la loc. "
                        + "Repornește aplicația ca să încarce noua stare."
                    restorePassword = ""
                    reload()
                }
            } catch {
                DispatchQueue.main.async {
                    isWorking = false
                    resultIsError = true
                    resultMessage = error.localizedDescription
                }
            }
        }
    }

    private static func stamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd_HH-mm"
        return f.string(from: Date())
    }
}
