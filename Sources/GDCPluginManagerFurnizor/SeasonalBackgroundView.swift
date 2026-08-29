import SwiftUI
import GDCPluginManagerCore

/// Panoul "Interfață Client" — BIBLIOTECA de filigrane sezoniere.
///
/// Etapa 6 (2026-08-29) avea un singur slot activ: alegeai o imagine, se
/// publica, și gata — o imagine proprie încărcată era folosită o dată și
/// uitată. Cristi a cerut explicit trei lucruri: perioadă de valabilitate,
/// poziție pe ecran, și ca imaginile proprii să rămână SALVATE, reutilizabile
/// mai târziu. De-aia panoul e acum o listă persistată: adaugi din galeria
/// predefinită sau încarci propriul fișier, iar fiecare intrare are perioadă,
/// poziție și comutator activ/inactiv, editabile oricând.
struct SeasonalBackgroundView: View {
    @State private var library: [SeasonalBackgroundConfig] = []
    @State private var isBusy = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var pendingDelete: SeasonalBackgroundConfig?

    private let columns = [GridItem(.adaptive(minimum: 140, maximum: 180), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Interfață Client — Filigrane Sezoniere").font(.title2).fontWeight(.semibold)
                Text("Imagini mari și discrete (nu bannere mici), afișate în fundalul ferestrei Client-ului. Ține aici toate filigranele anului: fiecare are propria perioadă și poziție, deci se aprind și se sting singure la datele lor.")
                    .font(.caption).foregroundStyle(.secondary)

                libraryBox
                addBox

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
                if isBusy { ProgressView().controlSize(.small) }

                Spacer(minLength: 0)
            }
            .padding(24)
            .frame(maxWidth: 680, alignment: .leading)
        }
        .confirmationDialog(
            "Ștergi definitiv „\(pendingDelete?.label ?? "")” din bibliotecă?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible
        ) {
            // PITFALL 2026-08-24 (race SwiftUI): elementul se capturează
            // SINCRON aici și se trece ca parametru — `pendingDelete` e golit
            // în paralel de binding la închiderea dialogului.
            Button("Șterge definitiv", role: .destructive) {
                let toDelete = pendingDelete
                Task { await remove(toDelete) }
            }
            Button("Anulează", role: .cancel) { pendingDelete = nil }
        }
        .task { loadLibrary() }
    }

    // MARK: - Biblioteca

    @ViewBuilder
    private var libraryBox: some View {
        GroupBox("Biblioteca ta de filigrane (\(library.count))") {
            if library.isEmpty {
                Text("Biblioteca e goală — fundalul Shift normal, fără filigran. Adaugă unul mai jos.")
                    .font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            } else {
                VStack(spacing: 14) {
                    ForEach(library) { config in
                        entryRow(config)
                        if config.id != library.last?.id { Divider() }
                    }
                }
                .padding(8)
            }
        }
    }

    @ViewBuilder
    private func entryRow(_ config: SeasonalBackgroundConfig) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                SeasonalThumbnail(url: config.imageURL)
                VStack(alignment: .leading, spacing: 4) {
                    Text(config.label.isEmpty ? config.id : config.label).fontWeight(.medium)
                    Text(config.imagePath).font(.caption2.monospaced()).foregroundStyle(.secondary).lineLimit(1)
                    Text(statusText(config))
                        .font(.caption)
                        .foregroundStyle(config.isActiveNow ? .green : .secondary)
                }
                Spacer()
                Button("Șterge", role: .destructive) { pendingDelete = config }
            }

            Toggle("Activ", isOn: Binding(
                get: { config.isEnabled },
                set: { newValue in Task { await update(config, isEnabled: newValue) } }
            ))

            Picker("Poziție pe ecran", selection: Binding(
                get: { config.position },
                set: { newValue in Task { await update(config, position: newValue) } }
            )) {
                ForEach(SeasonalPosition.allCases) { position in
                    Text(position.label).tag(position)
                }
            }

            // Același component reutilizat de toate rubricile (Etapa 4) —
            // nicio logică de dată duplicată aici.
            SchedulingPicker(scheduling: Binding(
                get: { config.scheduling },
                set: { newValue in Task { await update(config, scheduling: newValue, clearScheduling: newValue == nil) } }
            ))
            .id(config.id) // starea internă a picker-ului e per-intrare
        }
    }

    private func statusText(_ config: SeasonalBackgroundConfig) -> String {
        guard config.isEnabled else { return "Inactiv (comutator oprit)" }
        guard let scheduling = config.scheduling, !scheduling.isEmpty else { return "Activ acum — fără perioadă (mereu vizibil)" }
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        let from = scheduling.startDate.map(formatter.string(from:)) ?? "oricând"
        let to = scheduling.endDate.map(formatter.string(from:)) ?? "nelimitat"
        return (config.isActiveNow ? "Activ acum · " : "Programat · ") + "\(from) → \(to)"
    }

    // MARK: - Adăugare

    @ViewBuilder
    private var addBox: some View {
        GroupBox("Adaugă în bibliotecă") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Din galeria predefinită (SVG, gata de folosit)").font(.caption).foregroundStyle(.secondary)
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(SeasonalPresets.all) { preset in
                        Button {
                            Task { await addPreset(preset) }
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 22))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 60, height: 60)
                                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.15)))
                                Text(preset.label).font(.caption2).multilineTextAlignment(.center)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                Divider()

                Text("Sau încarcă propriul fișier — rămâne salvat în bibliotecă, reutilizabil oricând.")
                    .font(.caption).foregroundStyle(.secondary)
                Text("Recomandat SVG: vectorial (nepixelat la orice rezoluție/Retina), fișier mult mai mic, ușor de recolorat. PNG e potrivit doar pentru poze reale. Fișierul e copiat NEALTERAT, fără compresie.")
                    .font(.caption2).foregroundStyle(.secondary)
                Button("Alege fișier (SVG sau imagine)…") {
                    guard let url = SeasonalBackgroundStore.pickFile() else { return }
                    Task { await addCustom(url) }
                }
            }
            .padding(8)
        }
    }

    // MARK: - Acțiuni

    private func loadLibrary() {
        library = (try? CatalogEditor.load())?.seasonalBackgrounds ?? []
    }

    private func addPreset(_ preset: SeasonalPreset) async {
        let id = uniqueID(base: preset.id)
        await run("Filigran „\(preset.label)” adăugat în bibliotecă.") {
            let path = try SeasonalBackgroundStore.commitPreset(preset, id: id)
            try CatalogEditor.upsertSeasonalBackground(
                SeasonalBackgroundConfig(id: id, label: preset.label, imagePath: path)
            )
        }
    }

    private func addCustom(_ url: URL) async {
        let base = slug(url.deletingPathExtension().lastPathComponent)
        let id = uniqueID(base: base.isEmpty ? "filigran" : base)
        await run("Filigran personalizat adăugat în bibliotecă.") {
            let path = try SeasonalBackgroundStore.commit(source: url, id: id)
            try CatalogEditor.upsertSeasonalBackground(
                SeasonalBackgroundConfig(id: id, label: url.deletingPathExtension().lastPathComponent, imagePath: path)
            )
        }
    }

    private func update(_ config: SeasonalBackgroundConfig,
                        isEnabled: Bool? = nil,
                        position: SeasonalPosition? = nil,
                        scheduling: Scheduling? = nil,
                        clearScheduling: Bool = false) async {
        let updated = SeasonalBackgroundConfig(
            id: config.id,
            label: config.label,
            imagePath: config.imagePath,
            scheduling: clearScheduling ? nil : (scheduling ?? config.scheduling),
            position: position ?? config.position,
            isEnabled: isEnabled ?? config.isEnabled
        )
        guard updated != config else { return }
        await run("Filigran actualizat.") {
            try CatalogEditor.upsertSeasonalBackground(updated)
        }
    }

    private func remove(_ config: SeasonalBackgroundConfig?) async {
        guard let config else { return }
        pendingDelete = nil
        await run("„\(config.label)” a fost șters din bibliotecă.") {
            SeasonalBackgroundStore.removeFiles(id: config.id)
            try CatalogEditor.removeSeasonalBackground(id: config.id)
        }
    }

    /// ID-uri stabile și unice: `id` e și numele fișierului din repo, și
    /// cheia de cache din Client — două intrări cu același id ar suprascrie
    /// aceeași imagine.
    private func uniqueID(base: String) -> String {
        let existing = Set(library.map(\.id))
        if !existing.contains(base) { return base }
        var index = 2
        while existing.contains("\(base)-\(index)") { index += 1 }
        return "\(base)-\(index)"
    }

    /// Slug conform convenției din CLAUDE.md (litere mici, cifre, cratime) —
    /// `id`-ul ajunge într-un nume de fișier și de acolo într-un URL public.
    private func slug(_ raw: String) -> String {
        let folded = raw.folding(options: .diacriticInsensitive, locale: nil).lowercased()
        let cleaned = folded.map { char -> Character in
            (char.isLetter && char.isASCII) || char.isNumber ? char : "-"
        }
        return String(cleaned).split(separator: "-").joined(separator: "-")
    }

    private func run(_ success: String, _ work: () throws -> Void) async {
        errorMessage = nil
        successMessage = nil
        isBusy = true
        defer { isBusy = false }
        do {
            try GitOps.pull(at: RepoCheckoutPaths.publicCatalogRepo)
            try work()
            try GitOps.commitAndPush(at: RepoCheckoutPaths.publicCatalogRepo, message: "Filigrane sezoniere actualizate", paths: ["docs/catalog.json", "docs/covers"])
            successMessage = success
            loadLibrary()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// Miniatura unei intrări din bibliotecă. NU `AsyncImage`: filigranele sunt
/// tipic SVG, iar decodorul intern al SwiftUI nu randează fiabil SVG pe
/// macOS (bug real, 2026-08-29) — `NSImage(data:)` îl știe nativ.
private struct SeasonalThumbnail: View {
    let url: URL?
    @State private var nsImage: NSImage?

    var body: some View {
        Group {
            if let nsImage {
                Image(nsImage: nsImage).resizable().aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "photo").foregroundStyle(.secondary)
            }
        }
        .frame(width: 56, height: 56)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.15)))
        .task(id: url) {
            // `URLSession` async, nu `Data(contentsOf:)` — acesta din urmă
            // ar bloca main thread-ul pe un URL de rețea (miniatura vine de
            // pe gordas.dev, nu de pe disc).
            guard let url, let (data, _) = try? await URLSession.shared.data(from: url) else { return }
            nsImage = NSImage(data: data)
        }
    }
}
