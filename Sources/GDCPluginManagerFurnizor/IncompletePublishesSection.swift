import SwiftUI
import GDCPluginManagerCore

/// D2b: operațiile de publicare neterminate (din `PublishJournal`), cu „Reia” și „Curăță orfanii”.
/// Ambele reverifică și resincronizează toate repo-urile înainte de orice scriere; curățarea cere
/// confirmare și șterge doar fișierele pe care catalogul de pe server nu le mai referă.
struct IncompletePublishesSection: View {
    @Binding var records: [PublishTransaction.Record]
    @Binding var isBusy: Bool
    var log: (String) -> Void
    var onFinished: (String?, String?) -> Void   // (succes, eroare)

    @State private var cleanupTarget: PublishTransaction.Record?

    var body: some View {
        if !records.isEmpty {
            GroupBox {
                VStack(alignment: .leading, spacing: GDCTokens.Space.s) {
                    Label("Publicări incomplete (\(records.count))", systemImage: "exclamationmark.triangle")
                        .fontWeight(.semibold)
                    Text("Catalogul nu referă fișiere lipsă. „Reia” continuă de la pasul neconfirmat; „Curăță orfanii” șterge fișierele urcate de o publicare al cărei catalog n-a ajuns pe server.")
                        .font(.caption).foregroundStyle(.secondary)
                    ForEach(records) { record in
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: GDCTokens.Space.xxs) {
                                Text(record.label)
                                Text("\(record.kind == .publish ? "Publicare" : "Ștergere") · pași: \(record.completed.map(\.rawValue).joined(separator: ", ").isEmpty ? "niciunul" : record.completed.map(\.rawValue).joined(separator: ", "))")
                                    .font(.caption2).foregroundStyle(.secondary)
                                if let error = record.lastError {
                                    Text(error).font(.caption2).foregroundStyle(GDCTokens.Palette.error).lineLimit(3)
                                }
                            }
                            Spacer()
                            Button("Reia") { Task { await run { try PublishTransaction.resume(record, log: log); return "„\(record.label)” a fost finalizată." } } }
                                .disabled(isBusy)
                            if record.kind == .publish && !record.has(.catalogPushed) {
                                Button("Curăță orfanii", role: .destructive) { cleanupTarget = record }
                                    .disabled(isBusy)
                            }
                        }
                    }
                }
                .padding(GDCTokens.Space.s)
            }
            .confirmationDialog("Ștergi fișierele urcate de „\(cleanupTarget?.label ?? "")”?",
                                isPresented: Binding(get: { cleanupTarget != nil }, set: { if !$0 { cleanupTarget = nil } }),
                                titleVisibility: .visible) {
                Button("Șterge fișierele nereferite", role: .destructive) {
                    guard let record = cleanupTarget else { return }
                    Task { await run { "Șterse \(try PublishTransaction.cleanupOrphans(record, log: log)) fișiere orfane." } }
                }
                Button("Anulează", role: .cancel) {}
            } message: {
                Text("Se șterg doar fișierele acestei publicări pe care catalogul de pe server nu le referă. Fișierele folosite de alte produse rămân.")
            }
        }
    }

    private func run(_ action: () throws -> String) async {
        isBusy = true
        defer { isBusy = false; records = PublishJournal.pending() }
        do { onFinished(try action(), nil) } catch { onFinished(nil, error.localizedDescription) }
    }
}
