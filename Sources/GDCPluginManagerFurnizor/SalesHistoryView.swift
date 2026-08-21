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
    @State private var editingEntry: SalesLog.Entry?

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
                            Button("Editează") {
                                editingEntry = entry
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
        .sheet(item: $editingEntry) { entry in
            EditSalesEntryView(entry: entry) {
                loadEntries()
                editingEntry = nil
            } onCancel: {
                editingEntry = nil
            }
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

/// Corrects a bookkeeping mistake (wrong name / email / price typed in
/// at generation time). Editable: customer, email, price, "expiră"
/// display text. NOT editable: dateUTC, productID/Name, machineID,
/// serial — changing those would desync the row from the actual signed
/// code (see SalesLog.update's doc comment).
private struct EditSalesEntryView: View {
    let entry: SalesLog.Entry
    let onSaved: () -> Void
    let onCancel: () -> Void

    @State private var customer: String
    @State private var email: String
    @State private var priceText: String
    @State private var expiresDisplay: String
    @State private var errorMessage: String?

    init(entry: SalesLog.Entry, onSaved: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.entry = entry
        self.onSaved = onSaved
        self.onCancel = onCancel
        _customer = State(initialValue: entry.customer)
        _email = State(initialValue: entry.email)
        _priceText = State(initialValue: String(format: "%.2f", entry.priceEUR))
        _expiresDisplay = State(initialValue: entry.expiresDisplay)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Editează „\(entry.productName)”").font(.title3).fontWeight(.semibold)

            Text("Produs, dată, ID mașină și cod serial nu se pot schimba de aici — doar datele de client de mai jos.")
                .font(.caption).foregroundStyle(.secondary)

            TextField("Client", text: $customer).textFieldStyle(.roundedBorder)
            TextField("Email", text: $email).textFieldStyle(.roundedBorder)
            TextField("Preț (EUR)", text: $priceText).textFieldStyle(.roundedBorder)
            TextField("Expiră (text afișat)", text: $expiresDisplay).textFieldStyle(.roundedBorder)

            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red).font(.caption)
            }

            HStack {
                Spacer()
                Button("Anulează") { onCancel() }
                Button("Salvează") { save() }
                    .buttonStyle(.borderedProminent)
                    .disabled(customer.trimmingCharacters(in: .whitespaces).isEmpty || Double(priceText) == nil)
            }
        }
        .padding(24)
        .frame(width: 420)
    }

    private func save() {
        guard let price = Double(priceText) else {
            errorMessage = "Prețul trebuie să fie un număr."
            return
        }
        let updated = SalesLog.Entry(
            dateUTC: entry.dateUTC, productID: entry.productID, productName: entry.productName,
            customer: customer.trimmingCharacters(in: .whitespaces),
            email: email.trimmingCharacters(in: .whitespaces),
            priceEUR: price, expiresDisplay: expiresDisplay,
            machineID: entry.machineID, serial: entry.serial
        )
        do {
            try SalesLog.update(serial: entry.serial, with: updated)
            onSaved()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
