import SwiftUI
import GDCPluginManagerCore

/// Panoul "Interfață Client" — filigran/fundal sezonier — Etapa 6
/// (2026-08-29). Cristi, clarificare explicită: NU un banner mic, ci o
/// imagine MARE, discretă, "gravată" în fundalul ferestrei — Client-ul
/// randează asta la opacitate mică, ocupând o porțiune generoasă a
/// ferestrei (colț dreapta-jos), nu ca un sticker suprapus.
struct SeasonalBackgroundView: View {
    @State private var current: String?
    @State private var isBusy = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    private let columns = [GridItem(.adaptive(minimum: 140, maximum: 180), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Interfață Client — Filigran Sezonier").font(.title2).fontWeight(.semibold)
                Text("O imagine mare, discretă (nu un banner mic), afișată în fundalul ferestrei Client-ului — util pentru tematizare rapidă (Black Friday, Crăciun, Paște etc.). Un singur filigran activ deodată, pentru toți clienții.")
                    .font(.caption).foregroundStyle(.secondary)

                if let current {
                    GroupBox("Filigran activ acum") {
                        HStack {
                            Text(current).font(.caption.monospaced()).foregroundStyle(.secondary).lineLimit(1)
                            Spacer()
                            Button("Șterge filigranul", role: .destructive) { Task { await clear() } }
                        }
                        .padding(8)
                    }
                } else {
                    Text("Niciun filigran activ — fundalul Shift normal.").font(.caption).foregroundStyle(.secondary)
                }

                GroupBox("Galerie predefinită (SVG, gata de folosit)") {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(SeasonalPresets.all) { preset in
                            Button {
                                Task { await applyPreset(preset) }
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
                    .padding(8)
                }

                GroupBox("Sau încarcă propria imagine / SVG") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Fișierul e copiat NEALTERAT (fără compresie) — un SVG rămâne vectorial, perfect scalabil.")
                            .font(.caption2).foregroundStyle(.secondary)
                        Button("Alege fișier…") {
                            guard let url = SeasonalBackgroundStore.pickFile() else { return }
                            Task { await applyCustom(url) }
                        }
                    }
                    .padding(8)
                }

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
            .frame(maxWidth: 640, alignment: .leading)
        }
        .task { loadCurrent() }
    }

    private func loadCurrent() {
        current = (try? CatalogEditor.load())?.seasonalBackground
    }

    private func applyPreset(_ preset: SeasonalPreset) async {
        await run {
            let value = try SeasonalBackgroundStore.commitPreset(preset)
            try CatalogEditor.setSeasonalBackground(value)
            successMessage = "Filigran „\(preset.label)” activat — apare la clienți la următorul refresh de catalog."
        }
    }

    private func applyCustom(_ url: URL) async {
        await run {
            let value = try SeasonalBackgroundStore.commit(source: url)
            try CatalogEditor.setSeasonalBackground(value)
            successMessage = "Filigran personalizat activat — apare la clienți la următorul refresh de catalog."
        }
    }

    private func clear() async {
        await run {
            _ = try SeasonalBackgroundStore.commit(source: nil)
            try CatalogEditor.setSeasonalBackground(nil)
            successMessage = "Filigran șters — fundalul revine la Shift normal."
        }
    }

    private func run(_ work: () throws -> Void) async {
        errorMessage = nil
        successMessage = nil
        isBusy = true
        defer { isBusy = false }
        do {
            try GitOps.pull(at: RepoCheckoutPaths.publicCatalogRepo)
            try work()
            try GitOps.commitAndPush(at: RepoCheckoutPaths.publicCatalogRepo, message: "Filigran sezonier actualizat", paths: ["docs/catalog.json", "docs/covers"])
            loadCurrent()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
