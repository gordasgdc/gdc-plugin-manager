import SwiftUI
import AppKit

/// Read-only view over SalesLog — every code ever generated, who it was
/// for, and what they paid. Deleting a row only tidies the log; it does
/// NOT revoke the license (the serial is verified purely from its own
/// signed bytes, never against this file — see LicenseCore.validate).
struct SalesHistoryView: View {
    @State private var entries: [SalesLog.Entry] = []
    @State private var searchText = ""
    @State private var pendingDelete: SalesLog.Entry?
    @State private var justCopiedSerial: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Clienți").font(.title2).fontWeight(.semibold)
                Spacer()
                Button {
                    loadEntries()
                } label: {
                    Label("Reîmprospătează", systemImage: "arrow.clockwise")
                }
            }
            .padding([.horizontal, .top], 24)
            .padding(.bottom, 12)

            TextField("Caută (client, produs, email)…", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 24)
                .padding(.bottom, 12)

            if filteredEntries.isEmpty {
                Text(entries.isEmpty ? "Niciun cod generat încă." : "Niciun rezultat pentru „\(searchText)”.")
                    .foregroundStyle(.secondary)
                    .padding(24)
                Spacer()
            } else {
                Table(filteredEntries) {
                    TableColumn("Dată") { entry in Text(shortDate(entry.dateUTC)) }
                    TableColumn("Produs") { entry in Text(entry.productName) }
                    TableColumn("Client") { entry in Text(entry.customer) }
                    TableColumn("Email") { entry in Text(entry.email) }
                    TableColumn("Preț") { entry in Text(entry.priceDisplay) }
                    TableColumn("Expiră") { entry in Text(entry.expiresDisplay) }
                    TableColumn("ID Mașină") { entry in
                        Text(entry.machineID.isEmpty ? "—" : entry.machineID)
                            .font(.system(.caption, design: .monospaced))
                    }
                    TableColumn("") { entry in
                        HStack(spacing: 8) {
                            Button(justCopiedSerial == entry.serial ? "Copiat" : "Copiază cod") {
                                let pb = NSPasteboard.general
                                pb.clearContents()
                                pb.setString(entry.serial, forType: .string)
                                justCopiedSerial = entry.serial
                            }
                            .controlSize(.small)
                            Button("Șterge", role: .destructive) {
                                pendingDelete = entry
                            }
                            .controlSize(.small)
                        }
                    }
                }
            }
        }
        .confirmationDialog(
            "Ștergi din istoric codul pentru „\(pendingDelete?.customer ?? "")”?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Șterge din istoric", role: .destructive) {
                if let entry = pendingDelete {
                    try? SalesLog.delete(serial: entry.serial)
                    loadEntries()
                }
                pendingDelete = nil
            }
            Button("Anulează", role: .cancel) { pendingDelete = nil }
        } message: {
            Text("Elimină doar rândul din jurnal — codul rămâne activ dacă a fost deja folosit de client.")
        }
        .task { loadEntries() }
    }

    private var filteredEntries: [SalesLog.Entry] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return entries }
        return entries.filter {
            $0.customer.localizedCaseInsensitiveContains(trimmed)
                || $0.productName.localizedCaseInsensitiveContains(trimmed)
                || $0.email.localizedCaseInsensitiveContains(trimmed)
        }
    }

    private func loadEntries() {
        entries = SalesLog.readAll()
    }

    private func shortDate(_ isoUTC: String) -> String {
        guard let date = ISO8601DateFormatter().date(from: isoUTC) else { return isoUTC }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }
}
