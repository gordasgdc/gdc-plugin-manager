import Foundation

/// Sincronizare Tracker → Bază de date locală (cerut explicit 2026-08-24):
/// Tracker-ul (Supabase `devices`, completat de CLIENT la onboarding — vezi
/// AnalyticsClient.registerDevice) e declarat SURSA DE ADEVĂR pentru
/// nume/email, fiindcă vine direct de la client, nu tastat manual de
/// Cristi. `furnizor_sales.csv` (SalesLog) e „baza de date" locală, unde
/// Cristi introduce manual clientul la fiecare generare de serial.
enum TrackerSync {
    struct Result {
        let devicesChecked: Int
        let rowsCorrected: Int
    }

    /// Trece prin FIECARE rând din SalesLog care are un ID de mașină ce
    /// există și în tracker — dacă numele/email-ul diferă, SUPRASCRIE
    /// rândul cu varianta din tracker (nu invers: tracker-ul câștigă
    /// mereu, e sursa de adevăr). NU adaugă rânduri noi aici — un client
    /// din tracker fără nicio vânzare încă nu poate deveni un rând de
    /// SalesLog (schema aia e per-vânzare: produs/preț/serial), vezi
    /// `devicesWithoutSale(existingMachineIDs:)` mai jos pentru cum apar
    /// aceia, separat, în panoul Clienți — fără să murdărească CSV-ul de
    /// vânzări reale cu rânduri fabricate, fără produs/preț.
    static func syncSalesLogFromTracker() async -> Result {
        guard let devices = try? await AnalyticsAdminClient.fetchDevices() else {
            return Result(devicesChecked: 0, rowsCorrected: 0)
        }
        let truth = truthByMachineID(devices)

        var corrected = 0
        for entry in SalesLog.readAll() {
            let mid = entry.machineID.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !mid.isEmpty, let real = truth[mid] else { continue }
            guard entry.customer != real.name || entry.email != real.email else { continue }
            let updated = SalesLog.Entry(
                dateUTC: entry.dateUTC, productID: entry.productID, productName: entry.productName,
                customer: real.name, email: real.email, priceEUR: entry.priceEUR,
                expiresDisplay: entry.expiresDisplay, machineID: entry.machineID, serial: entry.serial
            )
            try? SalesLog.update(serial: entry.serial, with: updated)
            corrected += 1
        }
        return Result(devicesChecked: truth.count, rowsCorrected: corrected)
    }

    /// Clienți din tracker care NU au încă nicio vânzare în SalesLog —
    /// tot niște profile de client "reale" (clientul chiar a instalat și
    /// și-a lăsat datele), doar că fără licență generată încă. Afișați
    /// separat în UI, niciodată scrise ca rând de SalesLog.
    static func devicesWithoutSale(existingMachineIDs: Set<String>) async -> [ClientRecord] {
        guard let devices = try? await AnalyticsAdminClient.fetchDevices() else { return [] }
        return truthByMachineID(devices)
            .filter { !existingMachineIDs.contains($0.key) }
            .map { ClientRecord(name: $0.value.name, email: $0.value.email, machineID: $0.key) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private static func truthByMachineID(_ devices: [DeviceRecord]) -> [String: (name: String, email: String)] {
        var result: [String: (name: String, email: String)] = [:]
        for device in devices {
            let mid = device.machine_id.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !mid.isEmpty else { continue }
            let name = device.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !name.isEmpty else { continue } // fara nume introdus, nimic de sincronizat
            let email = device.email?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            result[mid] = (name, email)
        }
        return result
    }
}
