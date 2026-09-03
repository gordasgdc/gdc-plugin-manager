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
]

struct GenerateSerialView: View {
    @State private var items: [PluginItem] = []
    // Etapa 2 extinsă (2026-08-29) — Resursele Download (LUT/SFX/VFX/
    // Plugin) pot fi acum plătite la fel ca produsele din catalog.
    @State private var downloadResources: [DownloadableResource] = []
    @State private var selectedID = ""
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
    @State private var durationUnit: DurationUnit = .lifetime
    @State private var durationValue = "1"
    @State private var validUntilVersionNote = ""
    @State private var priceText = ""
    @State private var licensePlatform: LicenseCore.LicensePlatform = .any

    @State private var showConfirm = false
    @State private var generatedCode: String?
    @State private var justCopied = false
    @State private var errorMessage: String?

    // MARK: - Autocompletare client (cerut explicit 2026-08-24)
    @ObservedObject private var clientDirectory = ClientDirectory.shared
    /// Potrivire găsită după ID de mașină — afișată ca bănuț "date preluate
    /// automat", chiar și când userul a suprascris manual câmpurile după.
    @State private var autofilledFrom: ClientRecord?
    @State private var nameSuggestions: [ClientRecord] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Generează serial").font(.title2).fontWeight(.semibold)

                Picker("Produs", selection: $selectedID) {
                    Text("Alege…").tag("")
                    Section("Din catalog (LUT / DCTL / PowerGrade)") {
                        ForEach(items) { item in
                            Text("\(item.name) — \(item.priceDisplay)").tag(item.id)
                        }
                    }
                    Section("Resurse Download (LUT/SFX/VFX/Plugin)") {
                        ForEach(downloadResources) { resource in
                            Text("\(resource.name) — \(resource.priceDisplay)").tag(resource.id)
                        }
                    }
                    Section("Aplicații standalone") {
                        ForEach(gdcStandaloneProducts) { app in
                            Text(app.name).tag(app.id)
                        }
                    }
                }
                .onChange(of: selectedID) {
                    // Doar produsele din catalog au un preț cunoscut dinainte —
                    // aplicațiile standalone au prețuri variabile per vânzare
                    // (vezi memoria de proces: DataMover ~gratuit prin extindere
                    // de trial, CursorPro 9€, etc.), deci prețul rămâne gol,
                    // completat manual la fiecare generare.
                    if let item = items.first(where: { $0.id == selectedID }) {
                        priceText = String(item.priceEUR)
                    } else if let resource = downloadResources.first(where: { $0.id == selectedID }) {
                        priceText = String(resource.priceEUR)
                    } else if gdcStandaloneProducts.contains(where: { $0.id == selectedID }) {
                        priceText = ""
                    }
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
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
                                        .padding(.vertical, 4)
                                        .padding(.horizontal, 8)
                                    }
                                }
                                .background(Color.gray.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                        }
                        TextField("Email (opțional)", text: $email).textFieldStyle(.roundedBorder)
                        TextField("ID calculator (opțional — lipit de la client)", text: $machineID)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                            .onChange(of: machineID) {
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
                                .foregroundStyle(.green)
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

                Button("Generează…") { showConfirm = true }
                    .disabled(!isFormValid)
                    .confirmationDialog(
                        "Generezi un cod pentru \(selectedItemName) — \(customerName)?",
                        isPresented: $showConfirm, titleVisibility: .visible
                    ) {
                        Button("Generează") { generate() }
                        Button("Anulează", role: .cancel) {}
                    }

                if let generatedCode {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(generatedCode)
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                            Button(justCopied ? "Copiat." : "Copiază") {
                                let pb = NSPasteboard.general
                                pb.clearContents()
                                pb.setString(generatedCode, forType: .string)
                                justCopied = true
                            }
                        }
                        .padding(8)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(24)
            .frame(maxWidth: 640, alignment: .leading)
        }
        .task {
            loadItems()
            await clientDirectory.loadIfNeeded()
        }
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

    private var selectedItemName: String {
        if let item = items.first(where: { $0.id == selectedID }) { return item.name }
        if let app = gdcStandaloneProducts.first(where: { $0.id == selectedID }) { return app.name }
        return selectedID
    }

    private var isFormValid: Bool {
        !selectedID.isEmpty
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
        generatedCode = nil
        justCopied = false

        guard let price = Double(priceText) else { return }
        let expiresAt: Int64
        var expiresDisplay: String
        if durationUnit == .lifetime {
            expiresAt = 0
            expiresDisplay = "nu expira"
        } else {
            guard let quantity = Int(durationValue), quantity > 0 else { return }
            let totalDays = quantity * durationUnit.dayMultiplier
            expiresAt = Int64(Date().timeIntervalSince1970) + Int64(totalDays) * 86400
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            expiresDisplay = formatter.string(from: Date(timeIntervalSince1970: TimeInterval(expiresAt)))
        }
        let trimmedVersionNote = validUntilVersionNote.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedVersionNote.isEmpty {
            expiresDisplay += " (valabil manual până la versiunea \(trimmedVersionNote) — aplicat prin revocare)"
        }

        let trimmedMachineID = machineID.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            let key = try VendorKeyStore.loadPrivateKeyBase64()
            let code = try LicenseGenerator.generate(
                privateKeyBase64: key, productID: selectedID, expiresAt: expiresAt,
                machineIDBase32: trimmedMachineID.isEmpty ? nil : trimmedMachineID,
                platform: licensePlatform
            )
            generatedCode = code

            try? SalesLog.append(
                productID: selectedID, productName: selectedItemName, customer: customerName,
                email: email, priceEUR: price, expiresDisplay: expiresDisplay,
                machineID: trimmedMachineID, serial: code
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
