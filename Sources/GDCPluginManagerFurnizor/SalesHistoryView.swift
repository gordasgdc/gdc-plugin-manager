import SwiftUI
import AppKit
import GDCPluginManagerCore

/// Read-only view over SalesLog — every code ever generated, who it was
/// for, and what they paid. Deleting a row only tidies the log; it does
/// NOT revoke the license (the serial is verified purely from its own
/// signed bytes, never against this file — see LicenseCore.validate).
///
/// UPGRADE CRM (2026-08-26, cerut explicit) — panoul era un log rigid,
/// doar cautare+editare+stergere. Adaugat: filtru rapid pe produs, export
/// email-uri/HWID-uri (clipboard), copiere rapida per-rand, si Licentiere
/// in Masa (BulkImportView) - lipeste o lista de email-uri/machine ID-uri,
/// genereaza si ataseaza automat cate o licenta fiecarei linii, pentru un
/// singur produs/durata alese o singura data pentru tot lotul.
struct SalesHistoryView: View {
    @State private var entries: [SalesLog.Entry] = []
    @State private var searchText = ""
    @State private var pendingDelete: SalesLog.Entry?
    @State private var justCopiedSerial: String?
    @State private var justCopiedField: String?
    @State private var editingEntry: SalesLog.Entry?
    @State private var showDuplicates = false
    @State private var showBulkImport = false
    @State private var selectedProductFilter: String = "Toate"
    @State private var exportStatus: String?

    // MARK: - Sincronizare cu Tracker-ul (cerut explicit 2026-08-24: Tracker-ul,
    // completat de client la onboarding, e sursa de adevăr pentru nume/email).
    @State private var isSyncing = false
    @State private var syncStatus: String?
    @State private var trackerOnlyClients: [ClientRecord] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Clienți").font(.title2).fontWeight(.semibold)
                Spacer()
                if isSyncing {
                    ProgressView().controlSize(.small)
                }
                // Licentiere in masa (cerut explicit 2026-08-26): lipeste o
                // lista de email-uri/machine ID-uri, genereaza automat cate
                // o licenta pentru fiecare, pt. un produs/durata alese o
                // singura data.
                Button {
                    showBulkImport = true
                } label: {
                    Label("Licențiere în masă", systemImage: "person.3.sequence")
                }
                // Curățare duplicate (cerut explicit 2026-08-24): ID-uri de
                // mașină cu mai multe nume/email-uri asociate (typo-uri la
                // introducere manuală) — vezi DuplicateClientsView.swift.
                Button {
                    showDuplicates = true
                } label: {
                    Label("Curăță duplicate", systemImage: "person.crop.circle.badge.exclamationmark")
                }
                Button {
                    Task { await syncWithTracker() }
                } label: {
                    Label("Sincronizează cu Tracker", systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(isSyncing)
                Button {
                    loadEntries()
                } label: {
                    Label("Reîmprospătează", systemImage: "arrow.clockwise")
                }
            }
            .padding([.horizontal, .top], 24)
            .padding(.bottom, 12)

            if let syncStatus {
                Text(syncStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)
            }

            HStack(spacing: 10) {
                TextField("Caută (client, produs, email)…", text: $searchText)
                    .textFieldStyle(.roundedBorder)

                // Filtru rapid pe produs (cerut explicit 2026-08-26) - lista
                // dinamica din produsele deja aparute in jurnal, nu hardcodata.
                Picker("", selection: $selectedProductFilter) {
                    Text("Toate produsele").tag("Toate")
                    ForEach(productNamesInLog, id: \.self) { name in
                        Text(name).tag(name)
                    }
                }
                .frame(width: 220)

                Menu {
                    Button("Exportă e-mailuri (clipboard)") { exportField(\.email, label: "e-mailuri") }
                    Button("Exportă HWID-uri (clipboard)") { exportField(\.machineID, label: "ID-uri de mașină") }
                } label: {
                    Label("Exportă", systemImage: "square.and.arrow.up")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 6)

            if let exportStatus {
                Text(exportStatus)
                    .font(.caption)
                    .foregroundStyle(.green)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 6)
            }

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
                    // Copiere rapida (cerut explicit 2026-08-26) - direct din
                    // randul tabelului, fara sa deschizi editarea.
                    TableColumn("Email") { entry in copyableCell(entry.email, key: "email:\(entry.serial)") }
                    TableColumn("Preț") { entry in Text(entry.priceDisplay) }
                    TableColumn("Expiră") { entry in Text(entry.expiresDisplay) }
                    TableColumn("ID Mașină") { entry in
                        copyableCell(entry.machineID.isEmpty ? "—" : entry.machineID, key: "hwid:\(entry.serial)", monospaced: true)
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

            // Clienți din Tracker fără nicio licență generată încă (cerut
            // explicit 2026-08-24) — clientul chiar a instalat și și-a lăsat
            // datele, doar că nu i s-a generat încă un serial. Afișați DOAR
            // aici, niciodată ca rând fals în SalesLog (n-au produs/preț/serial).
            if !trackerOnlyClients.isEmpty {
                Divider().padding(.top, 8)
                Text("Din Tracker, fără licență generată încă (\(trackerOnlyClients.count))")
                    .font(.caption).fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(trackerOnlyClients) { client in
                            HStack {
                                Text(client.name)
                                Text(client.email).foregroundStyle(.secondary)
                                Spacer()
                                Text(client.machineID)
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundStyle(.tertiary)
                            }
                            .font(.caption)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 24)
                        }
                    }
                }
                .frame(maxHeight: 140)
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
        .sheet(isPresented: $showDuplicates) {
            DuplicateClientsView {
                loadEntries()
            } onClose: {
                showDuplicates = false
            }
        }
        .sheet(isPresented: $showBulkImport) {
            BulkImportView {
                loadEntries()
                showBulkImport = false
            } onCancel: {
                showBulkImport = false
            }
        }
        .task {
            loadEntries()
            // Sincronizare automată la fiecare deschidere a panoului — Tracker-ul
            // e sursa de adevăr (cerut explicit 2026-08-24), deci corectăm
            // singuri orice nume/email vechi/greșit fără să ceară Cristi manual.
            await syncWithTracker()
        }
    }

    /// Corectează SalesLog cu datele reale din Tracker (vezi TrackerSync.swift)
    /// și reîmprospătează lista de clienți „doar din tracker, fără vânzare
    /// încă". Rulează atât automat la deschidere, cât și la apăsarea manuală
    /// a butonului „Sincronizează cu Tracker".
    private func syncWithTracker() async {
        isSyncing = true
        let result = await TrackerSync.syncSalesLogFromTracker()
        if result.rowsCorrected > 0 {
            loadEntries()
        }
        let existingMachineIDs = Set(entries.map { $0.machineID.trimmingCharacters(in: .whitespacesAndNewlines) })
        trackerOnlyClients = await TrackerSync.devicesWithoutSale(existingMachineIDs: existingMachineIDs)
        syncStatus = result.devicesChecked == 0
            ? "Tracker indisponibil sau fără date — nimic de sincronizat acum."
            : "Tracker: \(result.devicesChecked) clienți verificați, \(result.rowsCorrected) corectați."
        isSyncing = false
    }

    /// Lista de produse aparute in jurnal, pentru dropdown-ul de filtrare
    /// (dinamica, nu hardcodata - reflecta orice produs/aplicatie noua
    /// aparuta automat in SalesLog).
    private var productNamesInLog: [String] {
        Array(Set(entries.map(\.productName))).sorted()
    }

    private var filteredEntries: [SalesLog.Entry] {
        var result = entries
        if selectedProductFilter != "Toate" {
            result = result.filter { $0.productName == selectedProductFilter }
        }
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return result }
        return result.filter {
            $0.customer.localizedCaseInsensitiveContains(trimmed)
                || $0.productName.localizedCaseInsensitiveContains(trimmed)
                || $0.email.localizedCaseInsensitiveContains(trimmed)
        }
    }

    /// Export 1-click (cerut explicit 2026-08-26) - copiaza in clipboard,
    /// cate un email/HWID pe linie, din setul curent FILTRAT (respecta
    /// filtrul de produs + cautarea active) - util ex. pt. acces YouTube
    /// Private pe un curs anume, fara sa exporti tot jurnalul.
    private func exportField(_ keyPath: KeyPath<SalesLog.Entry, String>, label: String) {
        let values = filteredEntries.map { $0[keyPath: keyPath] }.filter { !$0.isEmpty }
        guard !values.isEmpty else {
            exportStatus = "Niciun \(label) de exportat în selecția curentă."
            return
        }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(values.joined(separator: "\n"), forType: .string)
        exportStatus = "\(values.count) \(label) copiate în clipboard."
    }

    /// Celulă de tabel cu buton de copiere rapidă (cerut explicit
    /// 2026-08-26) - Email și ID Mașină, fără să deschizi editarea.
    @ViewBuilder
    private func copyableCell(_ value: String, key: String, monospaced: Bool = false) -> some View {
        HStack(spacing: 4) {
            Text(value)
                .font(monospaced ? .system(.caption, design: .monospaced) : .body)
                .lineLimit(1)
            if !value.isEmpty, value != "—" {
                Button {
                    let pb = NSPasteboard.general
                    pb.clearContents()
                    pb.setString(value, forType: .string)
                    justCopiedField = key
                } label: {
                    Image(systemName: justCopiedField == key ? "checkmark" : "doc.on.doc")
                        .foregroundStyle(justCopiedField == key ? .green : .secondary)
                }
                .buttonStyle(.plain)
            }
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

/// Licențiere în masă (cerut explicit 2026-08-26): lipești o listă de
/// email-uri sau perechi "email,machineID" (o linie per client), alegi UN
/// produs și O durată pentru tot lotul, și fiecare linie primește propria
/// licență Ed25519 semnată, adăugată în SalesLog — exact ca la generarea
/// individuală din GenerateSerialView, doar în buclă. Machine ID e opțional
/// per linie (poate rămâne necompletat, licențiat doar cu email — la fel
/// ca fluxul individual, unde câmpul de mașină poate fi gol).
private struct BulkImportView: View {
    let onDone: () -> Void
    let onCancel: () -> Void

    @State private var rawInput = ""
    @State private var selectedID = ""
    @State private var priceText = "23"
    @State private var durationUnit: DurationUnit = .lifetime
    @State private var durationValue = "1"
    @State private var items: [PluginItem] = []
    @State private var isRunning = false
    @State private var resultSummary: String?
    @State private var errorMessage: String?

    private enum DurationUnit: String, CaseIterable, Identifiable {
        case days = "Zile", months = "Luni", years = "Ani", lifetime = "Pe viață (Lifetime)"
        var id: String { rawValue }
        var dayMultiplier: Int {
            switch self {
            case .days: return 1
            case .months: return 30
            case .years: return 365
            case .lifetime: return 0
            }
        }
    }

    private var allProducts: [(id: String, name: String)] {
        gdcStandaloneProducts.map { ($0.id, $0.name) } + items.map { ($0.id, $0.name) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Licențiere în masă").font(.title3).fontWeight(.semibold)
            Text("O linie per client: „email” sau „email,machineID”. Fiecare linie primește propria licență, pentru produsul și durata alese mai jos.")
                .font(.caption).foregroundStyle(.secondary)

            TextEditor(text: $rawInput)
                .font(.system(.body, design: .monospaced))
                .frame(height: 140)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.separator))

            Picker("Produs", selection: $selectedID) {
                Text("Alege…").tag("")
                ForEach(allProducts, id: \.id) { p in Text(p.name).tag(p.id) }
            }

            HStack {
                Picker("Durată", selection: $durationUnit) {
                    ForEach(DurationUnit.allCases) { Text($0.rawValue).tag($0) }
                }
                if durationUnit != .lifetime {
                    TextField("Nr.", text: $durationValue).textFieldStyle(.roundedBorder).frame(width: 60)
                }
                TextField("Donație (EUR)", text: $priceText).textFieldStyle(.roundedBorder).frame(width: 100)
            }

            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red).font(.caption)
            }
            if let resultSummary {
                Text(resultSummary).foregroundStyle(.green).font(.caption)
            }

            HStack {
                Spacer()
                Button("Anulează") { onCancel() }
                Button(isRunning ? "Se generează…" : "Generează licențe") { run() }
                    .buttonStyle(.borderedProminent)
                    .disabled(isRunning || selectedID.isEmpty || parsedLines.isEmpty || Double(priceText) == nil)
            }
        }
        .padding(24)
        .frame(width: 480)
        .task { loadItems() }
    }

    private func loadItems() {
        if let catalog = try? CatalogEditor.load() {
            items = catalog.items.filter { !$0.isFree }.sorted { $0.name < $1.name }
        }
    }

    /// Fiecare linie: "email" sau "email,machineID" (virgulă sau tab),
    /// spații ignorate, linii goale sarite.
    private var parsedLines: [(email: String, machineID: String)] {
        rawInput
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .map { line -> (String, String) in
                let parts = line.split(whereSeparator: { $0 == "," || $0 == "\t" })
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                return (parts.first ?? line, parts.count > 1 ? parts[1] : "")
            }
    }

    private func run() {
        guard let price = Double(priceText) else { return }
        isRunning = true
        errorMessage = nil
        resultSummary = nil

        let productName = allProducts.first(where: { $0.id == selectedID })?.name ?? selectedID
        let expiresAt: Int64
        var expiresDisplay: String
        if durationUnit == .lifetime {
            expiresAt = 0
            expiresDisplay = "nu expira"
        } else {
            let quantity = Int(durationValue) ?? 1
            let totalDays = quantity * durationUnit.dayMultiplier
            expiresAt = Int64(Date().timeIntervalSince1970) + Int64(totalDays) * 86400
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            expiresDisplay = formatter.string(from: Date(timeIntervalSince1970: TimeInterval(expiresAt)))
        }

        var succeeded = 0
        var failed = 0
        do {
            let key = try VendorKeyStore.loadPrivateKeyBase64()
            for line in parsedLines {
                do {
                    let code = try LicenseGenerator.generate(
                        privateKeyBase64: key, productID: selectedID, expiresAt: expiresAt,
                        machineIDBase32: line.machineID.isEmpty ? nil : line.machineID,
                        platform: .any
                    )
                    try SalesLog.append(
                        productID: selectedID, productName: productName, customer: line.email,
                        email: line.email, priceEUR: price, expiresDisplay: expiresDisplay,
                        machineID: line.machineID, serial: code
                    )
                    succeeded += 1
                } catch {
                    failed += 1
                }
            }
        } catch {
            errorMessage = "Cheia de semnare nu a putut fi încărcată: \(error.localizedDescription)"
            isRunning = false
            return
        }

        resultSummary = failed == 0
            ? "\(succeeded) licențe generate cu succes."
            : "\(succeeded) reușite, \(failed) eșuate."
        isRunning = false
        if succeeded > 0 { onDone() }
    }
}
