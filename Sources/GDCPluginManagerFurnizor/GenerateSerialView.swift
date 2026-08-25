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
]

struct GenerateSerialView: View {
    @State private var items: [PluginItem] = []
    @State private var selectedID = ""
    @State private var customerName = ""
    @State private var email = ""
    @State private var machineID = ""
    @State private var expiresDays = "0" // 0 = never
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
                            TextField("Zile până expiră (0 = pe viață)", text: $expiresDays)
                                .textFieldStyle(.roundedBorder)
                            TextField("Preț încasat (EUR)", text: $priceText)
                                .textFieldStyle(.roundedBorder)
                        }
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
            && Int(expiresDays) != nil
            && Double(priceText) != nil
    }

    private func loadItems() {
        if let catalog = try? CatalogEditor.load() {
            // Free items need no license at all - nothing to generate.
            items = catalog.items.filter { !$0.isFree }.sorted { $0.name < $1.name }
        }
    }

    private func generate() {
        errorMessage = nil
        generatedCode = nil
        justCopied = false

        guard let days = Int(expiresDays), let price = Double(priceText) else { return }
        let expiresAt: Int64
        let expiresDisplay: String
        if days == 0 {
            expiresAt = 0
            expiresDisplay = "nu expira"
        } else {
            expiresAt = Int64(Date().timeIntervalSince1970) + Int64(days) * 86400
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            expiresDisplay = formatter.string(from: Date(timeIntervalSince1970: TimeInterval(expiresAt)))
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
