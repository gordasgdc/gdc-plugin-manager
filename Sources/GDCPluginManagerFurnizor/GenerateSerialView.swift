import SwiftUI
import AppKit
import GDCPluginManagerCore

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
                    ForEach(items) { item in
                        Text("\(item.name) — \(item.priceDisplay)").tag(item.id)
                    }
                }
                .onChange(of: selectedID) {
                    if let item = items.first(where: { $0.id == selectedID }) {
                        priceText = String(item.priceEUR)
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
                    Text(errorMessage).foregroundStyle(.red)
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
        items.first(where: { $0.id == selectedID })?.name ?? selectedID
    }

    private var isFormValid: Bool {
        !selectedID.isEmpty
            && !customerName.trimmingCharacters(in: .whitespaces).isEmpty
            && Int(expiresDays) != nil
            && Double(priceText) != nil
    }

    private func loadItems() {
        if let catalog = try? CatalogEditor.load() {
            items = catalog.items.sorted { $0.name < $1.name }
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

            try? SalesLog.append(SalesLog.Entry(
                productID: selectedID, productName: selectedItemName, customer: customerName,
                email: email, priceEUR: price, expiresDisplay: expiresDisplay,
                machineID: trimmedMachineID, serial: code
            ))
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
