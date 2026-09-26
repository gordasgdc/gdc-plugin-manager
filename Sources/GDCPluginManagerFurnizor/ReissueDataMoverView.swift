import SwiftUI
import AppKit
import GDCPluginManagerCore

/// Reemiterea controlată a unei licențe DataMover LEGACY (generația 1) ca cod generația 2,
/// pentru ACELAȘI ID de calculator, cu confirmare pentru fiecare client în parte. Rândul vechi
/// din registru nu se modifică; se adaugă un rând nou și o intrare în LicenseActionLog.
struct ReissueDataMoverView: View {
    let entry: SalesLog.Entry
    let onDone: () -> Void

    private enum Duration: String, CaseIterable, Identifiable {
        case days30 = "30 de zile (recomandat pentru testeri)", days90 = "90 de zile", year = "1 an", lifetime = "Pe viață"
        var id: String { rawValue }
        var seconds: Int64 { switch self { case .days30: 30 * 86400; case .days90: 90 * 86400; case .year: 365 * 86400; case .lifetime: 0 } }
    }
    @State private var duration: Duration = .days30
    @State private var confirmed = false
    @State private var code: String?
    @State private var error: String?
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reemite licența DataMover (generația 2)").font(.title3).bold()
            Text("Codul vechi al acestui client nu mai activează DataMover 2.17+. Noul cod se emite pentru același calculator; rândul vechi din registru rămâne neschimbat.")
                .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            LabeledContent("Client", value: entry.customer)
            LabeledContent("ID calculator", value: entry.machineID).font(.system(.body, design: .monospaced))
            LabeledContent("Licența veche", value: "\(String(entry.dateUTC.prefix(10))) · \(entry.expiresDisplay)")
            Picker("Durata codului nou", selection: $duration) { ForEach(Duration.allCases) { Text($0.rawValue).tag($0) } }
                .disabled(code != nil)
            if let code {
                HStack {
                    Text(code).font(.system(.caption, design: .monospaced)).textSelection(.enabled).lineLimit(1).truncationMode(.middle)
                    Button(copied ? "Copiat" : "Copiază cod") {
                        NSPasteboard.general.clearContents(); NSPasteboard.general.setString(code, forType: .string); copied = true
                    }
                }
            } else {
                Toggle("Confirm reemiterea pentru acest client și acest ID de calculator", isOn: $confirmed)
            }
            if let error { Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red).font(.callout) }
            HStack {
                Spacer()
                Button(code == nil ? "Anulează" : "Închide") { onDone() }
                if code == nil {
                    Button("Emite codul v2") { reissue() }
                        .buttonStyle(.borderedProminent)
                        .disabled(!confirmed || entry.machineID.isEmpty)
                }
            }
        }
        .padding(20)
        .frame(width: 520)
    }

    private func reissue() {
        error = nil
        guard !entry.machineID.isEmpty else { error = "Rândul nu are ID de calculator."; return }
        let expiresAt: Int64 = duration == .lifetime ? 0 : Int64(Date().timeIntervalSince1970) + duration.seconds
        let formatter = DateFormatter(); formatter.dateFormat = "yyyy-MM-dd HH:mm"
        let expiresDisplay = expiresAt == 0 ? "nu expira" : formatter.string(from: Date(timeIntervalSince1970: TimeInterval(expiresAt)))
        do {
            let key = try VendorKeyStore.loadPrivateKeyBase64()
            let newCode = try LicenseGenerator.generate(
                privateKeyBase64: key, productID: LicenseIdentity.signingProductID(for: LicenseIdentity.dataMoverCanonicalID),
                expiresAt: expiresAt, machineIDBase32: entry.machineID, platform: .any)
            try SalesLog.append(productID: LicenseIdentity.dataMoverCanonicalID, productName: "DataMover · reemis v2",
                                customer: entry.customer, email: entry.email, priceEUR: 0,
                                expiresDisplay: expiresDisplay, machineID: entry.machineID, serial: newCode)
            LicenseActionLog.record(machineID: entry.machineID, productID: LicenseIdentity.dataMoverCanonicalID,
                                    productName: "DataMover", action: .reissued,
                                    detail: "Cod generația 2 emis în locul licenței legacy din \(entry.dateUTC.prefix(10)); expiră: \(expiresDisplay)")
            code = newCode
        } catch {
            self.error = error.localizedDescription
        }
    }
}
