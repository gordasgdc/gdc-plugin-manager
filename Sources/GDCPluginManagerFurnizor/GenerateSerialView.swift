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

    @State private var showConfirm = false
    @State private var generatedCode: String?
    @State private var justCopied = false
    @State private var errorMessage: String?

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
                        TextField("Nume client", text: $customerName).textFieldStyle(.roundedBorder)
                        TextField("Email (opțional)", text: $email).textFieldStyle(.roundedBorder)
                        TextField("ID calculator (opțional — lipit de la client)", text: $machineID)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                        HStack {
                            TextField("Zile până expiră (0 = pe viață)", text: $expiresDays)
                                .textFieldStyle(.roundedBorder)
                            TextField("Preț încasat (EUR)", text: $priceText)
                                .textFieldStyle(.roundedBorder)
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
        .task { loadItems() }
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
                machineIDBase32: trimmedMachineID.isEmpty ? nil : trimmedMachineID
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
