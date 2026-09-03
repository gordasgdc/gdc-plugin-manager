import Foundation

/// [2026-09-03] Jurnalul acțiunilor pe licențe — Faza 2 din CRM (cerut
/// explicit: "prelungire, revocare, suspendare... din fișă"). Fișier NOU,
/// separat de `furnizor_sales.csv`, tocmai ca să NU riscăm formatul CSV
/// existent — `SalesLog.readAll()` respinge orice rând cu alt număr de
/// coloane decât cel original, iar acel fișier e citit din multe locuri
/// (TrackerSync, ClientDirectory, DuplicateClientsView, export-urile de
/// email). Un jurnal separat elimină orice risc de coruperie a lui.
///
/// IMPORTANT — de ce nu există un "Suspendă" DIFERIT de "Revocă": o
/// licență Ed25519 e verificată local, offline-first (Regula 12) — clientul
/// nu are conceptul de "suspendat temporar" vs. "revocat definitiv", doar
/// un singur RPC boolean (`is_license_revoked`). A construi o etichetă
/// "Suspendă" care în spate face EXACT ce face "Revocă" ar fi UI care
/// pretinde mai mult decât face — genul de bug deja documentat (Regula 28:
/// un banner fără consecință reală nu e gating, e doar UI). De-aceea
/// acțiunile expuse aici sunt DOAR cele pe care backend-ul le poate face
/// cu adevărat: blochează / deblochează / prelungește.
enum LicenseAction: String, Codable {
    case blocked = "Blocată"
    case unblocked = "Deblocată"
    case extended = "Prelungită"
}

struct LicenseActionRecord: Codable, Identifiable {
    let id: String
    let dateUTC: String
    let machineID: String
    let productID: String
    let productName: String
    let action: LicenseAction
    let detail: String
}

enum LicenseActionLog {
    private static var fileURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("GDC License Manager", isDirectory: true)
            .appendingPathComponent("license_actions.json")
    }

    static func readAll() -> [LicenseActionRecord] {
        guard let data = try? Data(contentsOf: fileURL),
              let records = try? JSONDecoder().decode([LicenseActionRecord].self, from: data) else { return [] }
        return records
    }

    /// Pentru un client anume (machineID) — folosit de fișă, ca să nu
    /// încarce/afișeze jurnalul altor clienți.
    static func entries(forMachineID machineID: String) -> [LicenseActionRecord] {
        readAll().filter { $0.machineID == machineID }.sorted { $0.dateUTC > $1.dateUTC }
    }

    static func record(machineID: String, productID: String, productName: String, action: LicenseAction, detail: String) {
        var all = readAll()
        let formatter = ISO8601DateFormatter()
        all.append(LicenseActionRecord(
            id: UUID().uuidString, dateUTC: formatter.string(from: Date()),
            machineID: machineID, productID: productID, productName: productName,
            action: action, detail: detail
        ))
        guard let data = try? JSONEncoder().encode(all) else { return }
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: fileURL)
    }
}
