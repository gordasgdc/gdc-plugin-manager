import SwiftUI
import Charts
import GDCPluginManagerCore

/// Ce ocupă fiecare repo privat, cine trimite spre el și ce nu e în regulă.
/// Datele vin din `RepoStorageScanner` — vezi acolo de ce scanarea e locală
/// și de ce cele două dimensiuni (conținut vs. GitHub) se afișează separat.
@MainActor
final class RepoStorageModel: ObservableObject {
    @Published var usages: [RepoStorageScanner.RepoUsage] = []
    @Published var duplicates: [RepoStorageScanner.DuplicateGroup] = []
    @Published var isLoading = false
    @Published var loadError: String?
    @Published var lastScan: Date?

    func scan() async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }

        let catalog: Catalog?
        do { catalog = try CatalogEditor.load() }
        catch {
            catalog = nil
            loadError = "Nu am putut citi catalogul: \(error.localizedDescription). Dimensiunile sunt corecte, dar maparea pe resurse lipsește."
        }

        var scanned = RepoStorageScanner.scanAll(catalog: catalog)
        // Dimensiunea de pe GitHub și starea git se completează după: prima
        // cere rețea, a doua pornește procese. Lista se vede imediat, fără
        // să aștepte nici una.
        usages = scanned
        duplicates = RepoStorageScanner.duplicates(across: scanned)

        for index in scanned.indices {
            scanned[index].remoteBytes = await RepoStorageScanner.remoteSize(repoName: scanned[index].repoName)
            scanned[index].gitState = RepoStorageScanner.gitState(at: scanned[index].localPath)
        }
        usages = scanned
        lastScan = Date()
    }

    var totalBytes: Int64 { usages.reduce(0) { $0 + $1.totalBytes } }
    var totalFiles: Int { usages.reduce(0) { $0 + $1.fileCount } }
    var wastedBytes: Int64 { duplicates.reduce(0) { $0 + $1.wastedBytes } }
}

struct RepoStorageView: View {
    @StateObject private var model = RepoStorageModel()
    @State private var expandedRepo: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                if let error = model.loadError { warning(error) }
                chart
                ForEach(model.usages) { usage in repoCard(usage) }
                if !model.duplicates.isEmpty { duplicatesSection }
            }
            .padding(20)
            .frame(maxWidth: 860, alignment: .leading)
        }
        .task { if model.lastScan == nil { await model.scan() } }
    }

    // MARK: Antet

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Stocare pe repo-uri").font(.title2).fontWeight(.semibold)
                Text("\(model.totalFiles) fișiere · \(RepoStorageScanner.formatted(model.totalBytes)) de conținut publicat")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Button {
                    Task { await model.scan() }
                } label: {
                    if model.isLoading { ProgressView().controlSize(.small) }
                    else { Label("Rescanează", systemImage: "arrow.clockwise") }
                }
                .disabled(model.isLoading)
                if let last = model.lastScan {
                    Text("Scanat \(SecretRegistry.relative(last))")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: Graficul

    private var chart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Conținut per repo").font(.headline)
            Chart(model.usages) { usage in
                BarMark(
                    x: .value("Octeți", usage.totalBytes),
                    y: .value("Repo", usage.key)
                )
                .foregroundStyle(by: .value("Repo", usage.key))
                .annotation(position: .trailing) {
                    Text("\(RepoStorageScanner.formatted(usage.totalBytes)) · \(usage.fileCount) fișiere")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            .chartLegend(.hidden)
            .chartXAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let bytes = value.as(Int64.self) {
                            Text(RepoStorageScanner.formatted(bytes))
                        }
                    }
                }
            }
            // Spațiu la dreapta pentru etichetele de lângă bare: fără el,
            // cea mai lungă e tăiată exact pe repo-ul cel mai mare. Domeniul
            // pleacă de la cea mai mare bară, nu de la total — altfel un
            // singur repo dominant ar ieși din grafic.
            .chartXScale(domain: 0...chartUpperBound)
            .frame(height: CGFloat(max(model.usages.count, 1) * 46 + 30))
        }
    }

    /// 40% peste cea mai mare bară — destul pentru eticheta de lângă ea la
    /// orice repartizare a dimensiunilor. `1` când nu e nimic scanat încă,
    /// fiindcă un domeniu 0...0 nu se poate desena.
    private var chartUpperBound: Int64 {
        let largest = model.usages.map(\.totalBytes).max() ?? 0
        return largest > 0 ? Int64(Double(largest) * 1.4) : 1
    }

    // MARK: Cardul unui repo

    @ViewBuilder
    private func repoCard(_ usage: RepoStorageScanner.RepoUsage) -> some View {
        let isOpen = expandedRepo == usage.key

        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(usage.repoName).font(.headline)
                    Text("cheia „\(usage.key)” · \(usage.references.count) trimiteri din catalog")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(RepoStorageScanner.formatted(usage.totalBytes))
                        .font(.title3).monospacedDigit()
                    Text("\(usage.fileCount) fișiere").font(.caption).foregroundStyle(.secondary)
                }
            }

            if !usage.isCloned {
                warning("Repo-ul nu e clonat local. Publicarea spre el va eșua până îl clonezi în \(usage.localPath.path).")
            }

            HStack(spacing: 18) {
                metric("Pe GitHub (cu istoric)",
                       usage.remoteBytes.map { RepoStorageScanner.formatted($0) } ?? "—")
                if let state = usage.gitState {
                    metric("Checkout local", state, highlighted: true)
                }
            }

            if usage.totalBytes > RepoStorageScanner.softRepoLimitBytes {
                warning("Peste 1 GB — GitHub recomandă păstrarea repo-urilor sub această dimensiune.")
            }
            if let biggest = usage.largestFiles.first, biggest.bytes > RepoStorageScanner.hardFileLimitBytes {
                warning("„\(biggest.relativePath)” depășește 100 MB — GitHub va refuza push-ul.")
            }
            if !usage.missingFiles.isEmpty {
                warning("\(usage.missingFiles.count) fișiere sunt în catalog, dar lipsesc de pe disc. Clienții primesc eroare la instalare.")
            }
            if !usage.orphanFiles.isEmpty {
                let bytes = usage.orphanFiles.reduce(0) { $0 + $1.bytes }
                Text("\(usage.orphanFiles.count) fișiere nereferite de nimeni din catalog (\(RepoStorageScanner.formatted(bytes)))")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Button(isOpen ? "Ascunde detaliile" : "Ce e stocat aici") {
                expandedRepo = isOpen ? nil : usage.key
            }
            .buttonStyle(.link)

            if isOpen { repoDetail(usage) }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.07)))
    }

    @ViewBuilder
    private func repoDetail(_ usage: RepoStorageScanner.RepoUsage) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if !usage.references.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Resurse care trimit aici").font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
                    // Grupat pe proprietar: interesează „ce produs", nu 55 de
                    // căi de fișiere una sub alta.
                    ForEach(groupedOwners(usage.references), id: \.0) { owner, references in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(owner).font(.callout)
                            Text("\(references.count) fișiere · \(references[0].section)")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if !usage.largestFiles.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Cele mai mari fișiere").font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
                    ForEach(usage.largestFiles) { file in
                        HStack {
                            Text(file.relativePath).font(.system(.caption, design: .monospaced)).lineLimit(1).truncationMode(.middle)
                            Spacer()
                            Text(RepoStorageScanner.formatted(file.bytes)).font(.caption).monospacedDigit().foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if !usage.missingFiles.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("În catalog, dar lipsă pe disc").font(.caption).fontWeight(.semibold).foregroundStyle(.red)
                    ForEach(usage.missingFiles) { reference in
                        Text("\(reference.ownerName) — \(reference.path)")
                            .font(.system(.caption, design: .monospaced))
                    }
                }
            }

            if !usage.orphanFiles.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Pe disc, dar nereferite").font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
                    ForEach(usage.orphanFiles.prefix(20)) { file in
                        HStack {
                            Text(file.relativePath).font(.system(.caption, design: .monospaced)).lineLimit(1).truncationMode(.middle)
                            Spacer()
                            Text(RepoStorageScanner.formatted(file.bytes)).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Text("Nu se șterg automat: un fișier poate fi urcat înaintea produsului care îl va folosi.")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.top, 4)
    }

    private func groupedOwners(_ references: [RepoStorageScanner.CatalogReference]) -> [(String, [RepoStorageScanner.CatalogReference])] {
        Dictionary(grouping: references, by: \.ownerName)
            .map { ($0.key, $0.value) }
            .sorted { $0.1.count > $1.1.count }
    }

    // MARK: Duplicate

    private var duplicatesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Același conținut în mai multe repo-uri").font(.headline)
            Text("\(model.duplicates.count) fișiere apar identic în mai multe locuri — \(RepoStorageScanner.formatted(model.wastedBytes)) ocupați de copiile în plus. Nu e neapărat o greșeală: un pachet oferit și ca produs, și ca resursă descărcabilă, ajunge legitim în două repo-uri.")
                .font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(model.duplicates.prefix(12)) { group in
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(group.filename).font(.callout)
                        Spacer()
                        Text("\(RepoStorageScanner.formatted(group.bytes)) × \(group.locations.count)")
                            .font(.caption).monospacedDigit().foregroundStyle(.secondary)
                    }
                    ForEach(group.locations, id: \.self) { location in
                        Text(location).font(.system(.caption2, design: .monospaced)).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.07)))
    }

    // MARK: Elemente comune

    private func metric(_ label: String, _ value: String, highlighted: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.callout).foregroundStyle(highlighted ? Color.orange : Color.primary)
        }
    }

    private func warning(_ text: String) -> some View {
        Label(text, systemImage: "exclamationmark.triangle.fill")
            .font(.caption)
            .foregroundStyle(.orange)
            .fixedSize(horizontal: false, vertical: true)
    }
}
