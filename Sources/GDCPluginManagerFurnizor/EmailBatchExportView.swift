import SwiftUI
import AppKit

/// Export de e-mailuri segmentat automat în loturi — Etapa 7 din Planul
/// Integrat de Upgrade v2.0 (2026-08-29). Multe servicii de e-mail (Gmail
/// inclus) limitează numărul de destinatari per trimitere/BCC — în loc să
/// numeri manual și să tai lista, alegi dimensiunea lotului (10/50/100
/// sau altceva) și fiecare lot apare gata de lipit direct în câmpul BCC.
struct EmailBatchExportView: View {
    let emails: [String]
    let onClose: () -> Void

    @State private var batchSizeText = "50"
    @State private var justCopiedBatch: Int?

    private var deduped: [String] {
        var seen = Set<String>()
        return emails.filter { seen.insert($0.lowercased()).inserted }
    }

    private var batchSize: Int {
        max(1, Int(batchSizeText) ?? 50)
    }

    private var batches: [[String]] {
        deduped.isEmpty ? [] : stride(from: 0, to: deduped.count, by: batchSize).map {
            Array(deduped[$0..<min($0 + batchSize, deduped.count)])
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Export e-mailuri pentru BCC (loturi)").font(.title2).fontWeight(.semibold)
            Text("\(deduped.count) e-mailuri unice, în selecția curentă (produs/status/căutare aplicate deja).")
                .font(.caption).foregroundStyle(.secondary)

            HStack {
                Text("Dimensiune lot:")
                Picker("", selection: $batchSizeText) {
                    Text("10").tag("10")
                    Text("50").tag("50")
                    Text("100").tag("100")
                }
                .pickerStyle(.segmented)
                .frame(width: 220)
                TextField("Personalizat", text: $batchSizeText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 90)
            }

            if deduped.isEmpty {
                Text("Niciun e-mail de exportat în selecția curentă.")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 20)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(batches.enumerated()), id: \.offset) { index, batch in
                            GroupBox("Lot \(index + 1) — \(batch.count) e-mailuri") {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(batch.joined(separator: "; "))
                                        .font(.caption.monospaced())
                                        .foregroundStyle(.secondary)
                                        .lineLimit(3)
                                        .textSelection(.enabled)
                                    HStack {
                                        Spacer()
                                        Button {
                                            copy(batch, index: index)
                                        } label: {
                                            Label(justCopiedBatch == index ? "Copiat!" : "Copiază pentru BCC", systemImage: "doc.on.doc")
                                        }
                                    }
                                }
                                .padding(8)
                            }
                        }
                    }
                }
                .frame(maxHeight: 360)
            }

            HStack {
                Spacer()
                Button("Închide") { onClose() }
            }
        }
        .padding(24)
        .frame(width: 560)
    }

    private func copy(_ batch: [String], index: Int) {
        let pb = NSPasteboard.general
        pb.clearContents()
        // `;` — separatorul acceptat de câmpul BCC în majoritatea clienților
        // de email (Gmail, Outlook, Apple Mail) la lipire directă.
        pb.setString(batch.joined(separator: "; "), forType: .string)
        justCopiedBatch = index
    }
}
