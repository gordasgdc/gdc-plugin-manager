import Foundation

/// [2026-09-03] Fișa unui client — Faza 1 din auditul CRM (cerut explicit
/// de Cristi: "începe cu fișa clientului"). Panoul de Clienți (SalesHistoryView)
/// arăta doar TRANZACȚII (un rând per serial generat) — utile, dar nu
/// răspund la "cine e clientul ăsta, ce a mai cumpărat, câte dispozitive
/// are, ce a descărcat". `ClientProfile` agregă TOT ce știm deja despre
/// un client, din sursele deja existente — nicio schemă nouă de date:
///   - `SalesLog` (furnizor_sales.csv) — istoricul complet de achiziții.
///   - `devices` (Supabase, prin AnalyticsAdminClient) — dispozitivele
///     asociate email-ului (un client poate avea mai multe ID-uri de mașină).
///   - `download_events` (Supabase) — ce a descărcat, de pe oricare din
///     dispozitivele lui.
///   - Note libere, PERSISTATE LOCAL (singurul lucru nou de stocat).
///
/// Cheia de agregare e EMAIL-ul (normalizat: trim + lowercase) — nu ID-ul
/// de mașină, care e per-DISPOZITIV, nu per-persoană. O vânzare veche fără
/// email deloc devine propriul ei "client" (cheie = ID de mașină, sau
/// numele dacă lipsește și el) — mai bine izolată decât amestecată greșit
/// cu alt client omonim.
struct ClientProfile: Identifiable {
    let key: String
    let displayName: String
    let email: String
    let purchases: [SalesLog.Entry]
    let devices: [DeviceRecord]
    let downloads: [DownloadEventRecord]

    var id: String { key }

    var totalSpentEUR: Double { purchases.reduce(0) { $0 + $1.priceEUR } }
    var licenseCount: Int { purchases.count }
    var deviceCount: Int { devices.count }
    var downloadCount: Int { downloads.count }

    /// Cea mai recentă achiziție — util pentru sortarea listei de clienți
    /// (cei activi recent primii) fără să recalculezi la fiecare randare.
    var lastPurchaseDate: String? { purchases.map(\.dateUTC).max() }

    /// Activ = are cel puțin o licență fără expirare sau cu expirare viitoare.
    var hasActiveLicense: Bool { purchases.contains { $0.isActive } }

    var allMachineIDs: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for p in purchases where !p.machineID.isEmpty {
            if seen.insert(p.machineID).inserted { result.append(p.machineID) }
        }
        for d in devices where !seen.contains(d.machine_id) {
            seen.insert(d.machine_id)
            result.append(d.machine_id)
        }
        return result
    }
}

enum ClientProfileBuilder {
    private static func normalizedEmail(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// Construiește toate fișele din sursele deja încărcate — pur, fără
    /// I/O propriu, ca să poată fi apelat sincron din view după ce
    /// apelantul a adus deja `devices`/`events` (posibil eșuat/gol, ex.
    /// fără conexiune — fișele de achiziții tot se construiesc, doar
    /// secțiunile de dispozitive/descărcări rămân goale).
    static func buildAll(purchases: [SalesLog.Entry], devices: [DeviceRecord], events: [DownloadEventRecord]) -> [ClientProfile] {
        var devicesByEmail: [String: [DeviceRecord]] = [:]
        for d in devices {
            let email = normalizedEmail(d.email ?? "")
            guard !email.isEmpty else { continue }
            devicesByEmail[email, default: []].append(d)
        }
        var machineIDsByEmail: [String: Set<String>] = [:]
        for (email, list) in devicesByEmail {
            machineIDsByEmail[email] = Set(list.map(\.machine_id))
        }

        var purchasesByKey: [String: [SalesLog.Entry]] = [:]
        var displayNameByKey: [String: String] = [:]
        var emailByKey: [String: String] = [:]
        for entry in purchases {
            let normalized = normalizedEmail(entry.email)
            let key = normalized.isEmpty
                ? (entry.machineID.isEmpty ? "name:\(entry.customer)" : "hwid:\(entry.machineID)")
                : "email:\(normalized)"
            purchasesByKey[key, default: []].append(entry)
            // Numele cel mai recent câștigă — la fel ca ClientDirectory,
            // presupunerea fiind că ultima intrare corectează typo-uri vechi.
            if displayNameByKey[key] == nil || entry.dateUTC > (purchasesByKey[key]!.first?.dateUTC ?? "") {
                displayNameByKey[key] = entry.customer.isEmpty ? "Anonim" : entry.customer
            }
            emailByKey[key] = entry.email
        }

        // Includem și clienții care au device/descărcări dar ÎNCĂ nicio
        // achiziție (SalesHistoryView îi arăta deja separat, ca
        // "trackerOnlyClients" — aici îi tratăm identic, o singură fișă).
        for (email, list) in devicesByEmail {
            let key = "email:\(email)"
            if purchasesByKey[key] == nil {
                purchasesByKey[key] = []
                emailByKey[key] = email
                displayNameByKey[key] = list.first(where: { $0.name?.isEmpty == false })?.name ?? "Anonim"
            }
        }

        var eventsByMachineID: [String: [DownloadEventRecord]] = [:]
        for e in events {
            guard let mid = e.machine_id else { continue }
            eventsByMachineID[mid, default: []].append(e)
        }

        return purchasesByKey.map { key, entries in
            let email = emailByKey[key] ?? ""
            let normalized = normalizedEmail(email)
            let ownDevices = devicesByEmail[normalized] ?? []
            let machineIDs = Set(entries.map(\.machineID).filter { !$0.isEmpty })
                .union(machineIDsByEmail[normalized] ?? [])
            let ownEvents = machineIDs.flatMap { eventsByMachineID[$0] ?? [] }
                .sorted { $0.downloaded_at > $1.downloaded_at }
            return ClientProfile(
                key: key,
                displayName: displayNameByKey[key] ?? "Anonim",
                email: email,
                purchases: entries.sorted { $0.dateUTC > $1.dateUTC },
                devices: ownDevices,
                downloads: ownEvents
            )
        }.sorted { ($0.lastPurchaseDate ?? "") > ($1.lastPurchaseDate ?? "") }
    }
}

/// Note libere per client — SINGURUL lucru nou de persistat pentru Faza 1.
/// Fișier JSON simplu, cheie = `ClientProfile.key` (stabil: email normalizat,
/// sau ID de mașină/nume dacă email lipsește) — același tipar de stocare ca
/// `SalesLog`/`VendorKeyStore` (Application Support, sub "GDC License Manager").
enum ClientNotesStore {
    private static var fileURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("GDC License Manager", isDirectory: true)
            .appendingPathComponent("client_notes.json")
    }

    private static func loadAll() -> [String: String] {
        guard let data = try? Data(contentsOf: fileURL),
              let dict = try? JSONDecoder().decode([String: String].self, from: data) else { return [:] }
        return dict
    }

    static func note(for key: String) -> String {
        loadAll()[key] ?? ""
    }

    static func setNote(_ text: String, for key: String) {
        var all = loadAll()
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            all.removeValue(forKey: key)
        } else {
            all[key] = text
        }
        guard let data = try? JSONEncoder().encode(all) else { return }
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: fileURL)
    }
}
