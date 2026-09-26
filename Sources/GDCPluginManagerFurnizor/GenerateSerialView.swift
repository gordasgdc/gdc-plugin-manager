import SwiftUI
import AppKit
import GDCPluginManagerCore

/// O aplicație standalone GDC (DataMover, CursorPro GDC etc.) — spre
/// deosebire de `PluginItem`, NU trăiește în `catalog.json` (nu are
/// versiune/preț/fișiere de instalat prin Furnizor), dar folosește EXACT
/// același format de licență Ed25519 (`LicenseGenerator`/`LicenseCore`
/// sunt agnostice la ce fel de produs semnează — vezi `productHash`).
///
/// ARHITECTURA (2026-08-24): unificare cu fosta aplicație „GDC License
/// Manager" — aceea genera coduri pentru orice ID de produs tastat liber.
/// Cheia de semnare era deja comună (`VendorKeyStore` citește din
/// `~/Library/Application Support/GDC License Manager/private_key.txt`,
/// exact fișierul generat de aplicația veche), deci NU a fost nevoie de
/// nicio migrare criptografică — doar de acest dropdown, ca Furnizor să
/// acopere și aceste produse, nu doar cele din catalog.
///
/// WARNING: ID-urile de mai jos sunt citite din codul sursă al fiecărei
/// aplicații (`PRODUCT_ID` în Python, `LicenseManager.productID` în
/// Swift), verificate manual 2026-08-24. NU le modifica fără să verifici
/// din nou sursa aplicației respective — un ID greșit aici tot generează
/// un cod (semnătura e validă), dar clientul îl respinge cu
/// `WrongProduct`, fiindcă hash-ul de produs nu se potrivește.
struct StandaloneProduct: Identifiable, Hashable {
    let id: String
    let name: String
}

let gdcStandaloneProducts: [StandaloneProduct] = [
    StandaloneProduct(id: "gdc-datamover", name: "DataMover"),
    StandaloneProduct(id: "cursorpro", name: "CursorPro GDC"),
    StandaloneProduct(id: "gdc-production-manager", name: "GDC Production Manager"),
    StandaloneProduct(id: "gdc-resolve-encoder", name: "GDC Resolve Encoder"),
    // Adaugat 2026-08-24 — verificat in LicenseManager.swift (Mac) si
    // LicenseManager.cs (Windows) ale gdc-vault: productID = "gdc-vault".
    StandaloneProduct(id: "gdc-vault", name: "GDC Vault"),
    // Adaugat 2026-08-26 — verificat in LicenseManager.swift (Mac,
    // CGConvertor/LicenseManager.swift) si license_validator.py (Windows,
    // python/license_validator.py) ale CGConvertor: productID = "cgconvertor".
    StandaloneProduct(id: "cgconvertor", name: "CG Convertor"),
    // Adaugat 2026-08-26 — verificat in LicenseManager.swift (Mac,
    // MediaFlow-Monitor/Sources/MediaFlowMonitor/Licensing/LicenseManager.swift)
    // si LicenseManager.cs (Windows, portat 2026-08-26, verificat cu test
    // izolat de sign/verify Ed25519 + Base32 round-trip): productID =
    // "media-flow-monitor" pe ambele platforme. Machine ID e opac — Mac
    // hasheaza IOPlatformUUID, Windows hasheaza MachineGuid din Registry;
    // clientul lipeste orice string afiseaza `MachineID.Display`/`.display`
    // in campul "ID calculator" de mai jos, indiferent de platforma.
    StandaloneProduct(id: "media-flow-monitor", name: "MediaFlow Monitor"),
    // Adaugat 2026-08-30 — verificat in LicenseState.swift
    // (MacMasterControlPro/Sources/MacMasterControlProCore/LicenseState.swift,
    // constanta macMasterControlProProductID): productID =
    // "mac-master-control-pro". Donatie de referinta 17€ (Regula 3).
    // Redenumit 2026-08-30: "Mac Master Control Pro" -> "Master Control
    // Studio Pro" (nume neutru, pregatit pentru lansarea viitoare pe
    // Windows) - productID ramane neschimbat, doar numele afisat.
    StandaloneProduct(id: "mac-master-control-pro", name: "Master Control Studio Pro"),
    // Adaugat 2026-09-19 — verificat in LicenseManager.swift (GDC LUT Lab,
    // App/Sources/Licensing/LicenseManager.swift): productID = "gdc-lut-lab".
    StandaloneProduct(id: "gdc-lut-lab", name: "GDC STYLE Lab"),
]

struct GenerateSerialView: View {
    @State private var items: [PluginItem] = []
    // Etapa 2 extinsă (2026-08-29) — Resursele Download (LUT/SFX/VFX/
    // Plugin) pot fi acum plătite la fel ca produsele din catalog.
    @State private var downloadResources: [DownloadableResource] = []
    /// Produsele bifate: un serial per produs, pentru același client/ID de mașină, într-o singură generare.
    @State private var selectedIDs: Set<String> = []
    /// Product ID-urile scrise manual (pachete OFX GDC STYLE Lab), memorate + cele găsite în istoricul de vânzări.
    @AppStorage("GDCFurnizor.customProductIDs") private var customIDsStore = ""
    @State private var productFilter = ""
    /// Pachete OFX exportate din GDC STYLE Lab: fiecare are propriul Product ID
    /// (ales la export), deci nu poate fi într-o listă fixă — se scrie aici.
    @State private var customProductID = ""
    @State private var customerName = ""
    @State private var email = ""
    @State private var machineID = ""
    // Generare flexibila (Faza 3, vezi CLAUDE.md Partea 1 Regula 12):
    // acelasi camp `expiresAt` (unix seconds, 0 = pe viata) din LicenseCore
    // - nicio schimbare de format criptografic, doar UI mai clar decat un
    // simplu numar de zile. "Pana la versiunea X" NU e criptografic
    // (payload-ul nu are camp de versiune) - e doar o nota informativa in
    // SalesLog; aplicarea reala se face manual, prin revocare (RevocationsView)
    // cand acea versiune chiar apare.
    private enum DurationUnit: String, CaseIterable, Identifiable {
        case hours = "Ore", days = "Zile", months = "Luni", years = "Ani", lifetime = "Pe viață (lifetime)"
        var id: String { rawValue }

        var secondsMultiplier: Int {
            switch self {
            case .hours: return 3600
            case .days: return 86400
            case .months: return 2592000
            case .years: return 31536000
            case .lifetime: return 0
            }
        }
    }
    @State private var durationUnit: DurationUnit = .lifetime
    @State private var durationValue = "1"
    @State private var validUntilVersionNote = ""
    @State private var priceText = ""
    @State private var licensePlatform: LicenseCore.LicensePlatform = .any

    /// Focalizarea pe campul de ID, ca butonul "Client nou" sa lase cursorul
    /// direct acolo — altfel Cristi trebuie sa dea si un click inainte de a
    /// lipi urmatorul ID.
    @FocusState private var machineIDFocused: Bool

    @State private var showConfirm = false
    /// Licențele generate în sesiunea curentă: rămân în tabel până la „Reset”.
    struct GeneratedLicense: Identifiable {
        let id = UUID()
        let productID, productName, customer, machineID, expires, code: String
    }
    @State private var generated: [GeneratedLicense] = []
    @State private var copiedID: UUID?
    @State private var errorMessage: String?

    // MARK: - Autocompletare client (cerut explicit 2026-08-24)
    @ObservedObject private var clientDirectory = ClientDirectory.shared
    /// Potrivire găsită după ID de mașină — afișată ca bănuț "date preluate
    /// automat", chiar și când userul a suprascris manual câmpurile după.
    @State private var autofilledFrom: ClientRecord?
    @State private var nameSuggestions: [ClientRecord] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GDCTokens.Space.l) {
                Text("Generează serial").font(.title2).fontWeight(.semibold)

                productPicker
                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        VStack(alignment: .leading, spacing: GDCTokens.Space.xs) {
                            TextField("Nume client", text: $customerName).textFieldStyle(.roundedBorder)
                                .onChange(of: customerName) {
                                    autofilledFrom = nil
                                    nameSuggestions = clientDirectory.suggestions(forNamePrefix: customerName)
                                }
                            // Sugestii de client existent, pe măsură ce tastezi numele —
                            // click pe o sugestie completează și email + ID mașină.
                            if !nameSuggestions.isEmpty {
                                VStack(alignment: .leading, spacing: 0) {
                                    ForEach(nameSuggestions) { suggestion in
                                        Button {
                                            applyAutofill(suggestion)
                                            nameSuggestions = []
                                        } label: {
                                            HStack {
                                                Text(suggestion.name)
                                                if !suggestion.email.isEmpty {
                                                    Text(suggestion.email).foregroundStyle(.secondary)
                                                }
                                                Spacer()
                                                if !suggestion.machineID.isEmpty {
                                                    Text(suggestion.machineID)
                                                        .font(.system(.caption2, design: .monospaced))
                                                        .foregroundStyle(.tertiary)
                                                }
                                            }
                                            .font(.caption)
                                            .contentShape(Rectangle())
                                        }
                                        .buttonStyle(.plain)
                                        .padding(.vertical, GDCTokens.Space.xs)
                                        .padding(.horizontal, GDCTokens.Space.s)
                                    }
                                }
                                .background(Color.gray.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: GDCTokens.Radius.badge))
                            }
                        }
                        TextField("Email (opțional)", text: $email).textFieldStyle(.roundedBorder)
                        TextField("ID calculator (opțional — lipit de la client)", text: $machineID)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                            .focused($machineIDFocused)
                            .onChange(of: machineID) {
                                // Codurile generate rămân în tabel, cu ID-ul lor pe fiecare rând.
                                // Autocompletare după ID de mașină (tracking + istoric
                                // vânzări — vezi ClientDirectory.swift). Nu suprascrie
                                // dacă numele e deja completat manual de Cristi — doar
                                // dacă e gol, sau dacă a fost autocompletat anterior de
                                // aceeași potrivire (schimbă ID-ul → schimbă și numele).
                                guard let match = clientDirectory.lookup(machineID: machineID) else {
                                    autofilledFrom = nil
                                    return
                                }
                                if customerName.trimmingCharacters(in: .whitespaces).isEmpty || autofilledFrom != nil {
                                    applyAutofill(match, keepMachineID: true)
                                }
                            }
                        if let autofilledFrom {
                            Label("Date preluate automat pentru „\(autofilledFrom.name)”", systemImage: "checkmark.circle.fill")
                                .font(.caption2)
                                .foregroundStyle(GDCTokens.Palette.success)
                        }
                        HStack {
                            Picker("Durată", selection: $durationUnit) {
                                ForEach(DurationUnit.allCases) { Text($0.rawValue).tag($0) }
                            }
                            .pickerStyle(.menu)
                            if durationUnit != .lifetime {
                                TextField("Cantitate", text: $durationValue)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 80)
                            }
                        }
                        TextField("Preț încasat (EUR)", text: $priceText)
                            .textFieldStyle(.roundedBorder)
                        TextField("Valabil până la versiunea X (opțional, doar notă — se aplică manual prin revocare)", text: $validUntilVersionNote)
                            .textFieldStyle(.roundedBorder)
                        // GDC-LICENSE-PLATFORM (Etapa 2): .any produce un
                        // cod v1 (compatibil retroactiv, nicio restrictie);
                        // celelalte 3 produc un cod v2 cu byte de platforma.
                        Picker("Platformă", selection: $licensePlatform) {
                            Text("Oricare (implicit)").tag(LicenseCore.LicensePlatform.any)
                            Text("Doar Mac").tag(LicenseCore.LicensePlatform.macOnly)
                            Text("Doar Windows").tag(LicenseCore.LicensePlatform.windowsOnly)
                            Text("Combo (Mac + Windows)").tag(LicenseCore.LicensePlatform.crossPlatform)
                        }
                        .pickerStyle(.menu)
                    }
                    .padding(GDCTokens.Space.s)
                }

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(GDCTokens.Palette.error)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(GDCTokens.Palette.error.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: GDCTokens.Radius.control))
                }

                HStack {
                    Button(selectedIDs.count > 1 ? "Generează \(selectedIDs.count) licențe…" : "Generează…") { showConfirm = true }
                        .disabled(!isFormValid)
                        .confirmationDialog(
                            "Generezi \(selectedIDs.count == 1 ? "un cod" : "\(selectedIDs.count) coduri") pentru \(customerName) — \(selectedNames)?",
                            isPresented: $showConfirm, titleVisibility: .visible
                        ) {
                            Button("Generează") { generate() }
                            Button("Anulează", role: .cancel) {}
                        }
                    Button("Reset / Curăță câmpurile") { resetForm() }
                        .help("Golește produsele bifate, clientul, durata, prețul și tabelul de licențe generate")
                }
                if !generated.isEmpty { generatedTable }
                Spacer(minLength: 0)
            }
            .padding(GDCTokens.Space.xl)
            .frame(maxWidth: 820, alignment: .leading)
        }
        .task {
            loadItems()
            await clientDirectory.loadIfNeeded()
        }
    }

    /// Reset complet: produse, client, durată, preț, notă și tabelul de licențe generate.
    private func resetForm() {
        selectedIDs = []
        productFilter = ""
        customProductID = ""
        machineID = ""
        customerName = ""
        email = ""
        autofilledFrom = nil
        nameSuggestions = []
        durationUnit = .lifetime
        durationValue = "1"
        priceText = ""
        validUntilVersionNote = ""
        licensePlatform = .any
        generated = []
        copiedID = nil
        errorMessage = nil
        machineIDFocused = true
    }

    /// Completează nume+email (și, opțional, ID mașină) dintr-o potrivire
    /// găsită — fie prin căutare de nume (click pe sugestie), fie automat
    /// după ID de mașină (vezi onChange(of: machineID) de mai sus).
    private func applyAutofill(_ record: ClientRecord, keepMachineID: Bool = false) {
        customerName = record.name
        if !record.email.isEmpty { email = record.email }
        if !keepMachineID, !record.machineID.isEmpty { machineID = record.machineID }
        autofilledFrom = record
    }

    /// Product ID-urile personalizate: memorate la generare + cele din istoricul de vânzări care nu sunt în alte liste.
    private var customIDs: [String] {
        let known = Set(items.map(\.id) + downloadResources.map(\.id) + gdcStandaloneProducts.map(\.id))
        var ids = customIDsStore.split(separator: "\n").map(String.init)
        for e in SalesLog.readAll() where e.productID.hasPrefix("gdc-style-") && !ids.contains(e.productID) { ids.append(e.productID) }
        return ids.filter { !$0.isEmpty && !known.contains($0) }.sorted()
    }

    private func rememberCustomID(_ id: String) {
        var ids = customIDsStore.split(separator: "\n").map(String.init)
        guard !id.isEmpty, !ids.contains(id) else { return }
        ids.append(id)
        customIDsStore = ids.joined(separator: "\n")
    }

    private func name(of id: String) -> String {
        if let item = items.first(where: { $0.id == id }) { return item.name }
        if let r = downloadResources.first(where: { $0.id == id }) { return r.name }
        if let app = gdcStandaloneProducts.first(where: { $0.id == id }) { return app.name }
        return id
    }

    private var selectedNames: String { selectedIDs.sorted().map(name(of:)).joined(separator: ", ") }

    private func matches(_ text: String) -> Bool {
        productFilter.isEmpty || text.localizedCaseInsensitiveContains(productFilter)
    }

    /// Bifa unui produs; la un singur produs din catalog cu preț cunoscut, prețul se completează singur.
    private func toggle(_ id: String) -> Binding<Bool> {
        Binding(get: { selectedIDs.contains(id) }, set: { on in
            if on { selectedIDs.insert(id) } else { selectedIDs.remove(id) }
            if selectedIDs.count == 1, let only = selectedIDs.first {
                if let item = items.first(where: { $0.id == only }) { priceText = String(item.priceEUR) }
                else if let r = downloadResources.first(where: { $0.id == only }) { priceText = String(r.priceEUR) }
            }
        })
    }

    private struct ProductRow: Identifiable { let id: String; let label: String }

    @ViewBuilder private func productSection(_ title: String, _ rows: [ProductRow]) -> some View {
        let visible = rows.filter { matches($0.label) || matches($0.id) }
        if !visible.isEmpty {
            Text(title).font(.caption).foregroundStyle(.secondary).padding(.top, GDCTokens.Space.xs)
            ForEach(visible) { row in
                Toggle(isOn: toggle(row.id)) {
                    HStack {
                        Text(row.label)
                        if row.label != row.id { Text(row.id).font(.system(.caption2, design: .monospaced)).foregroundStyle(.tertiary) }
                    }
                }
            }
        }
    }

    /// Selecție multiplă: bife pe secțiuni, filtru de căutare, Product ID nou (memorat pentru data viitoare).
    private var productPicker: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: GDCTokens.Space.xs) {
                HStack {
                    Text("Produse").fontWeight(.semibold)
                    Text(selectedIDs.isEmpty ? "niciunul bifat" : "\(selectedIDs.count) bifate").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    TextField("Caută produs…", text: $productFilter).textFieldStyle(.roundedBorder).frame(width: 220)
                }
                ScrollView {
                    VStack(alignment: .leading, spacing: GDCTokens.Space.xxs) {
                        productSection("Aplicații standalone", gdcStandaloneProducts.map { ProductRow(id: $0.id, label: $0.name) })
                        productSection("Pachete OFX (GDC STYLE Lab) — Product ID-uri memorate", customIDs.map { ProductRow(id: $0, label: $0) })
                        productSection("Din catalog (LUT / DCTL / PowerGrade)", items.map { ProductRow(id: $0.id, label: "\($0.name) — \($0.priceDisplay)") })
                        productSection("Resurse Download (LUT/SFX/VFX/Plugin)", downloadResources.map { ProductRow(id: $0.id, label: "\($0.name) — \($0.priceDisplay)") })
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 220)
                HStack {
                    TextField("Product ID nou (exact ca la exportul OFX, ex. gdc-style-kodak)", text: $customProductID)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(addCustomID)
                    Button("Adaugă și bifează", action: addCustomID)
                        .disabled(customProductID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(GDCTokens.Space.s)
        }
    }

    private func addCustomID() {
        let id = customProductID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty else { return }
        rememberCustomID(id)
        selectedIDs.insert(id)
        customProductID = ""
    }

    private func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    /// Tabelul licențelor generate în sesiune, cu copiere rapidă per rând (ca în Clienți).
    private var generatedTable: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Licențe generate (\(generated.count))").fontWeight(.semibold)
                    Spacer()
                    Button("Copiază toate") {
                        copy(generated.map { "\($0.productName): \($0.code)" }.joined(separator: "\n"))
                    }
                }
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                    GridRow {
                        Text("Produs"); Text("Client"); Text("ID mașină"); Text("Expiră"); Text("Cod"); Text("")
                    }
                    .font(.caption).foregroundStyle(.secondary)
                    Divider()
                    ForEach(generated) { g in
                        GridRow {
                            Text(g.productName).lineLimit(1)
                            Text(g.customer).lineLimit(1)
                            Text(g.machineID.isEmpty ? "—" : g.machineID).font(.system(.caption, design: .monospaced))
                            Text(g.expires).font(.caption).lineLimit(1)
                            Text(g.code).font(.system(.caption, design: .monospaced)).lineLimit(1).truncationMode(.middle).textSelection(.enabled)
                            Button(copiedID == g.id ? "Copiat." : "Copiază cod") { copy(g.code); copiedID = g.id }
                        }
                    }
                }
            }
            .padding(GDCTokens.Space.s)
        }
    }

    private var isFormValid: Bool {
        !selectedIDs.isEmpty
            && !customerName.trimmingCharacters(in: .whitespaces).isEmpty
            && (durationUnit == .lifetime || Int(durationValue) != nil)
            && Double(priceText) != nil
    }

    private func loadItems() {
        if let catalog = try? CatalogEditor.load() {
            // Free items need no license at all - nothing to generate.
            items = catalog.items.filter { !$0.isFree }.sorted { $0.name < $1.name }
            downloadResources = catalog.downloadableResources.filter { !$0.isFree }.sorted { $0.name < $1.name }
        }
    }

    private func generate() {
        errorMessage = nil
        copiedID = nil
        guard let price = Double(priceText) else { return }
        let expiresAt: Int64
        var expiresDisplay: String
        if durationUnit == .lifetime {
            expiresAt = 0
            expiresDisplay = "nu expira"
        } else {
            guard let quantity = Int(durationValue), quantity > 0 else { return }
            let totalSeconds = quantity * durationUnit.secondsMultiplier
            expiresAt = Int64(Date().timeIntervalSince1970) + Int64(totalSeconds)
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm"
            expiresDisplay = formatter.string(from: Date(timeIntervalSince1970: TimeInterval(expiresAt)))
        }
        let trimmedVersionNote = validUntilVersionNote.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedVersionNote.isEmpty {
            expiresDisplay += " (valabil manual până la versiunea \(trimmedVersionNote) — aplicat prin revocare)"
        }
        let trimmedMachineID = machineID.trimmingCharacters(in: .whitespacesAndNewlines)
        let customer = customerName.trimmingCharacters(in: .whitespaces)
        let known = Set(items.map(\.id) + downloadResources.map(\.id) + gdcStandaloneProducts.map(\.id))
        do {
            let key = try VendorKeyStore.loadPrivateKeyBase64()
            // Un serial per produs bifat, același client / ID de mașină / durată; fiecare intră în SalesLog.
            for productID in selectedIDs.sorted(by: { name(of: $0) > name(of: $1) }) {
                let code = try LicenseGenerator.generate(
                    privateKeyBase64: key, productID: productID, expiresAt: expiresAt,
                    machineIDBase32: trimmedMachineID.isEmpty ? nil : trimmedMachineID,
                    platform: licensePlatform
                )
                try? SalesLog.append(
                    productID: productID, productName: name(of: productID), customer: customer,
                    email: email, priceEUR: price, expiresDisplay: expiresDisplay,
                    machineID: trimmedMachineID, serial: code
                )
                if !known.contains(productID) { rememberCustomID(productID) }
                generated.insert(GeneratedLicense(productID: productID, productName: name(of: productID), customer: customer,
                                                  machineID: trimmedMachineID, expires: expiresDisplay, code: code), at: 0)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
