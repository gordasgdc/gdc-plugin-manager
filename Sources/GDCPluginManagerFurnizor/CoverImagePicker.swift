import SwiftUI
import AppKit
import GDCPluginManagerCore

/// Selectorul de coperta, refolosit de toate ecranele de publicare
/// (plugin-uri, cursuri, materiale, evenimente, magazine partenere).
///
/// Trei moduri, exclusive intre ele (vezi `CoverImageSelection`):
///   - Fara imagine    -> cardul clientului cade pe `iconSymbol`
///   - Fisier local    -> comprimat pe loc, preview din fisierul REAL care
///                        va ajunge la clienti, cu cat s-a castigat
///   - Link extern     -> preview live din retea, fara compresie
///
/// ARCHITECTURE NOTE: componenta nu scrie nimic in repo. Doar pregateste
/// selectia; scrierea in `docs/covers/` se face la publicare, prin
/// `CoverImageStore.commit` — vezi WARNING-ul de acolo despre ordinea fata
/// de commit-ul git.
struct CoverImagePicker: View {
    /// Presetul de compresie potrivit contextului: `.icon` pentru lucruri
    /// mici si patrate (plugin-uri, logo-uri de magazin), `.cover` pentru
    /// materiale/cursuri/evenimente, unde conteaza detaliul.
    let preset: ImageProcessor.Preset

    @Binding var selection: CoverImageSelection

    /// Textul din campul de URL. Tinut separat de `selection` ca sa nu
    /// reconstruim selectia la fiecare tasta apasata (si sa nu declansam
    /// un fetch de preview pe fiecare caracter — vezi debounce-ul de jos).
    @State private var urlText = ""
    /// URL-ul pentru care chiar cerem preview — actualizat abia dupa ce
    /// tastarea s-a oprit.
    @State private var debouncedURL: URL?
    @State private var mode: Mode = .none
    @State private var errorMessage: String?
    /// Biblioteca de imagini deja publicate (2026-08-31) — cerință directă
    /// a lui Cristi: "odată ce ai urcat, poți să o selectezi și să o
    /// folosești în mai multe locuri". Încărcată la deschiderea foii, nu
    /// la fiecare randare — `docs/covers/` nu se schimbă în timp ce
    /// formularul e deschis.
    @State private var showingLibrary = false
    @State private var libraryEntries: [CoverImageStore.LibraryEntry] = []

    private enum Mode: String, CaseIterable, Identifiable {
        case none, local, external
        var id: String { rawValue }
        var label: String {
            switch self {
            case .none: return "Fără imagine"
            case .local: return "Fișier local"
            case .external: return "Link extern"
            }
        }
    }

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Imagine de prezentare").font(.headline)
                    Spacer()
                    Text(presetHint).font(.caption).foregroundStyle(.secondary)
                }

                Picker("", selection: $mode) {
                    ForEach(Mode.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .onChange(of: mode) { _, newMode in modeChanged(to: newMode) }

                switch mode {
                case .none:
                    Text("Produsul va folosi iconița (simbolul) în loc de imagine.")
                        .font(.caption).foregroundStyle(.secondary)

                case .local:
                    localSection

                case .external:
                    externalSection
                }

                if let errorMessage {
                    Text(errorMessage).font(.caption).foregroundStyle(.red)
                }
            }
            .padding(8)
        }
        .task { syncModeFromSelection() }
        .sheet(isPresented: $showingLibrary) { libraryPicker }
    }

    // MARK: - Sheet "Bibliotecă imagini"

    private static let libraryColumns = [GridItem(.adaptive(minimum: 96), spacing: 12)]

    @ViewBuilder
    private var libraryPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Bibliotecă imagini").font(.title3).fontWeight(.semibold)
            Text("Imagini deja publicate — alege una ca să o refolosești aici, fără reîncărcare.")
                .font(.caption).foregroundStyle(.secondary)

            if libraryEntries.isEmpty {
                Text("Nicio imagine publicată încă.")
                    .font(.callout).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                ScrollView {
                    LazyVGrid(columns: Self.libraryColumns, spacing: 12) {
                        ForEach(libraryEntries) { entry in
                            Button {
                                selection = .existing(entry.catalogValue)
                                mode = .local
                                showingLibrary = false
                            } label: {
                                VStack(spacing: 4) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.1))
                                        if let image = NSImage(contentsOf: entry.fileURL) {
                                            Image(nsImage: image).resizable().scaledToFill()
                                        } else {
                                            Image(systemName: "photo").font(.system(size: 24)).foregroundStyle(.secondary)
                                        }
                                    }
                                    .frame(width: 80, height: 80)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    Text(entry.id).font(.caption2).lineLimit(1).truncationMode(.middle)
                                }
                                .frame(width: 96)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 360)
            }

            HStack {
                Spacer()
                Button("Anulează") { showingLibrary = false }
            }
        }
        .padding(20)
        .frame(width: 480)
    }

    // MARK: - Sectiunea "Fisier local"

    @ViewBuilder
    private var localSection: some View {
        HStack(alignment: .top, spacing: 14) {
            preview

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Button("Alege imagine…") { pickLocal() }
                    Button("Din bibliotecă…") {
                        libraryEntries = CoverImageStore.libraryEntries()
                        showingLibrary = true
                    }
                }

                if case .local(_, let savings) = selection {
                    // Aratam castigul concret ("5,4 MB -> 529 KB (90% mai
                    // mic)"), nu doar un checkmark — furnizorul vede imediat
                    // daca a urcat din greseala un export urias.
                    Label(savings, systemImage: "arrow.down.circle")
                        .font(.caption).foregroundStyle(.green)
                } else if case .existing(let value) = selection, !CatalogAssets.isExternal(value) {
                    Text("Publicată: \(value)").font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("Se comprimă automat la alegere.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Sectiunea "Link extern"

    @ViewBuilder
    private var externalSection: some View {
        HStack(alignment: .top, spacing: 14) {
            preview

            VStack(alignment: .leading, spacing: 8) {
                TextField("https://cdn.exemplu.com/imagine.jpg", text: $urlText)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: urlText) { _, newValue in
                        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                        selection = trimmed.isEmpty ? .none : .external(trimmed)
                    }

                Text("Nu se comprimă și nu ocupă spațiu în repo.")
                    .font(.caption).foregroundStyle(.secondary)

                // WARNING pentru furnizor, nu doar pentru noi in cod: o
                // imagine externa poate disparea fara ca aplicatia sa afle.
                Label(
                    "Dacă ștergi imaginea de pe server, dispare și din aplicație.",
                    systemImage: "exclamationmark.triangle"
                )
                .font(.caption).foregroundStyle(.orange)
            }
        }
        // Debounce: asteptam 500 ms de liniste inainte sa cerem imaginea,
        // altfel am porni un request pe fiecare caracter tastat din URL.
        .task(id: urlText) {
            let trimmed = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { debouncedURL = nil; return }
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            debouncedURL = URL(string: trimmed)
        }
    }

    // MARK: - Preview

    private static let previewSide: CGFloat = 120

    @ViewBuilder
    private var preview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.1))

            switch selection {
            case .local(let processed, _):
                // Citim de pe disc fisierul deja comprimat — exact ce vor
                // vedea clientii, nu imaginea sursa.
                if let image = NSImage(contentsOf: processed) {
                    Image(nsImage: image).resizable().scaledToFit()
                } else {
                    placeholder("photo")
                }

            case .existing(let value):
                remoteImage(CatalogAssets.imageURL(for: value))

            case .external:
                remoteImage(debouncedURL)

            case .none:
                placeholder("photo.on.rectangle.angled")
            }
        }
        .frame(width: Self.previewSide, height: Self.previewSide)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private func remoteImage(_ url: URL?) -> some View {
        if let url {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFit()
                case .failure:
                    // Nu e o eroare dura: poate userul inca tasteaza URL-ul.
                    placeholder("exclamationmark.triangle")
                case .empty:
                    ProgressView().controlSize(.small)
                @unknown default:
                    placeholder("photo")
                }
            }
        } else {
            placeholder("photo")
        }
    }

    private func placeholder(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 28))
            .foregroundStyle(.secondary)
    }

    private var presetHint: String {
        switch preset {
        case .icon: return "pătrat 512×512"
        case .cover: return "max 1600px"
        }
    }

    // MARK: - Actiuni

    private func pickLocal() {
        errorMessage = nil
        guard let source = CoverImageStore.pickFile() else { return }
        do {
            selection = try CoverImageStore.prepareLocal(source: source, preset: preset)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// La schimbarea manuala a modului, resetam selectia — trecerea pe
    /// "Fără imagine" trebuie sa insemne chiar nimic, nu sa lase in urma
    /// valoarea veche.
    private func modeChanged(to newMode: Mode) {
        errorMessage = nil
        switch newMode {
        case .none:
            selection = .none
        case .local:
            // Daca produsul avea deja o imagine locala publicata, o pastram
            // (nu obligam furnizorul sa o realeaga doar ca a atins tab-ul).
            if case .existing(let value) = selection, !CatalogAssets.isExternal(value) { return }
            if case .local = selection { return }
            selection = .none
        case .external:
            if case .existing(let value) = selection, CatalogAssets.isExternal(value) {
                urlText = value
                return
            }
            if case .external(let value) = selection {
                urlText = value
                return
            }
            selection = .none
        }
    }

    /// La deschiderea formularului (sau la incarcarea unui produs existent
    /// pentru editare), pozitionam tab-ul pe modul corect.
    private func syncModeFromSelection() {
        switch selection {
        case .none:
            mode = .none
        case .existing(let value):
            mode = CatalogAssets.isExternal(value) ? .external : .local
            if CatalogAssets.isExternal(value) { urlText = value }
        case .external(let value):
            mode = .external
            urlText = value
        case .local:
            mode = .local
        }
    }
}
