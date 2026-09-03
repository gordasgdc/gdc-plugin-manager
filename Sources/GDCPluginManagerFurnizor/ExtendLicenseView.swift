import SwiftUI
import GDCPluginManagerCore

/// [2026-09-03] Prelungirea unei licențe — Faza 2 CRM, deschisă din
/// ClientDetailView (buton "Prelungește…" pe orice achiziție).
///
/// DE CE nu se poate doar "muta data" pe codul vechi: un serial GDC e o
/// secvență de octeți SEMNATĂ Ed25519 (vezi LicenseGenerator) — data de
/// expirare face parte din payload-ul semnat, deci nu poate fi schimbată
/// fără să rupă semnătura. Singura cale reală e să emiți un cod NOU,
/// pentru ACELAȘI produs și ACELAȘI ID de mașină, cu noua expirare — codul
/// vechi rămâne valid așa cum a fost livrat (nu se revocă automat aici;
/// dacă trebuie invalidat, se folosește separat "Blochează").
struct ExtendLicenseView: View {
    let purchase: SalesLog.Entry
    var onGenerated: (_ detail: String) -> Void
    var onCancel: () -> Void

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

    @State private var durationUnit: DurationUnit = .years
    @State private var durationValue = "1"
    @State private var newCode: String?
    @State private var errorMessage: String?
    @State private var isGenerating = false
    @State private var justCopied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Prelungește licența").font(.title3).fontWeight(.semibold)
            Text("\(purchase.productName) — \(purchase.customer.isEmpty ? purchase.email : purchase.customer)")
                .font(.callout).foregroundStyle(.secondary)
            Text("Cod curent: \(purchase.serial)")
                .font(.caption).foregroundStyle(.tertiary)
                .textSelection(.enabled)

            if let newCode {
                Divider()
                Text("Cod nou generat").font(.headline)
                Text(newCode)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(8)
                    .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
                Button(justCopied ? "Copiat" : "Copiază codul nou") {
                    let pb = NSPasteboard.general
                    pb.clearContents()
                    pb.setString(newCode, forType: .string)
                    justCopied = true
                }
                Text("Trimite acest cod clientului — vechiul cod rămâne valabil neschimbat, dacă preferi să nu-l blochezi.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Spacer()
                    Button("Închide") { onCancel() }
                }
            } else {
                HStack {
                    Picker("Durată nouă", selection: $durationUnit) {
                        ForEach(DurationUnit.allCases) { Text($0.rawValue).tag($0) }
                    }
                    if durationUnit != .lifetime {
                        TextField("Cantitate", text: $durationValue)
                            .frame(width: 60)
                    }
                }
                if let errorMessage {
                    Text(errorMessage).font(.caption).foregroundStyle(.red)
                }
                HStack {
                    Button("Anulează") { onCancel() }
                    Spacer()
                    Button("Generează codul nou") { generate() }
                        .buttonStyle(.borderedProminent)
                        .disabled(isGenerating || (durationUnit != .lifetime && Int(durationValue) == nil))
                }
            }
        }
        .padding(20)
        .frame(width: 420)
    }

    private func generate() {
        errorMessage = nil
        isGenerating = true
        defer { isGenerating = false }

        let expiresAt: Int64
        var expiresDisplay: String
        if durationUnit == .lifetime {
            expiresAt = 0
            expiresDisplay = "nu expira"
        } else {
            guard let quantity = Int(durationValue), quantity > 0 else {
                errorMessage = "Cantitatea trebuie să fie un număr pozitiv."
                return
            }
            let totalDays = quantity * durationUnit.dayMultiplier
            expiresAt = Int64(Date().timeIntervalSince1970) + Int64(totalDays) * 86400
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            expiresDisplay = formatter.string(from: Date(timeIntervalSince1970: TimeInterval(expiresAt)))
        }

        do {
            let privateKey = try VendorKeyStore.loadPrivateKeyBase64()
            let code = try LicenseGenerator.generate(
                privateKeyBase64: privateKey, productID: purchase.productID,
                expiresAt: expiresAt, machineIDBase32: purchase.machineID
            )
            try SalesLog.append(
                productID: purchase.productID, productName: purchase.productName,
                customer: purchase.customer, email: purchase.email,
                priceEUR: 0, expiresDisplay: expiresDisplay + " (prelungire)",
                machineID: purchase.machineID, serial: code
            )
            newCode = code
            onGenerated("Nou cod, expiră \(expiresDisplay). Cod vechi: \(purchase.serial.prefix(9))…")
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
