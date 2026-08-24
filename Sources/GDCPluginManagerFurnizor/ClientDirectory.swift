import Foundation

/// Un profil de client unificat, indiferent de sursă — folosit pentru
/// autocompletare în GenerateSerialView: cauți după ID mașină SAU nume,
/// celelalte câmpuri se completează singure.
struct ClientRecord: Identifiable, Hashable {
    let name: String
    let email: String
    let machineID: String
    var id: String { machineID.isEmpty ? "\(name)|\(email)" : machineID }
}

/// Combină DOUĂ surse existente, ca Cristi să nu mai tasteze de mână
/// date deja știute undeva în sistem (cerut explicit 2026-08-24):
///
/// 1. `devices` (Supabase, vezi AnalyticsAdminClient.fetchDevices) — nume +
///    email completate chiar de CLIENT, o singură dată, la primul onboarding
///    (OnboardingView.swift → AnalyticsClient.registerDevice), legate de
///    ID-ul lui de mașină. Cea mai de încredere sursă (vine direct de la
///    client), dar nu există pentru vânzări mai vechi/manuale.
/// 2. `furnizor_sales.csv` (SalesLog) — istoricul codurilor generate manual
///    de Cristi în GenerateSerialView, inclusiv vânzări fără ID de mașină.
///
/// Deduplicat după `machineID`: dacă există ambele surse pentru același
/// ID, câștigă (a) `devices`, pentru nume/email — vine direct de la client;
/// (b) intrarea cea mai RECENTĂ din sales log, dacă `devices` nu are acel
/// ID deloc — presupunerea fiind că ultima vânzare are datele corectate,
/// nu prima (typo-urile vechi sunt de obicei cele greșite).
@MainActor
final class ClientDirectory: ObservableObject {
    static let shared = ClientDirectory()

    @Published private(set) var records: [ClientRecord] = []
    @Published private(set) var isLoaded = false

    private init() {}

    func loadIfNeeded() async {
        guard !isLoaded else { return }
        await reload()
    }

    func reload() async {
        var byMachineID: [String: ClientRecord] = [:]
        var withoutMachineID: [ClientRecord] = []

        // Sales log, în ordine CRONOLOGICĂ (readAll() dă cel mai nou primul —
        // .reversed() aici ca o intrare mai nouă să suprascrie una mai veche
        // în dicționar, nu invers).
        for entry in SalesLog.readAll().reversed() {
            let mid = entry.machineID.trimmingCharacters(in: .whitespacesAndNewlines)
            let name = entry.customer.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { continue }
            let record = ClientRecord(name: name, email: entry.email.trimmingCharacters(in: .whitespacesAndNewlines), machineID: mid)
            if mid.isEmpty {
                withoutMachineID.append(record)
            } else {
                byMachineID[mid] = record
            }
        }

        // Tracking (devices) — suprascrie sales log-ul pentru același
        // machineID, vine direct de la client. Eșec silențios (fără
        // conexiune, cheie service_role necompletată etc.) — autocompletarea
        // cade pur și simplu pe ce a găsit deja în sales log, nu blochează
        // nimic din formularul de generare.
        if let devices = try? await AnalyticsAdminClient.fetchDevices() {
            for device in devices {
                let mid = device.machine_id.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !mid.isEmpty else { continue }
                let name = device.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let email = device.email?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard !name.isEmpty else { continue }
                byMachineID[mid] = ClientRecord(name: name, email: email, machineID: mid)
            }
        }

        records = (Array(byMachineID.values) + withoutMachineID)
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        isLoaded = true
    }

    /// Potrivire EXACTĂ pe ID de mașină — folosită la autocompletare
    /// automată în GenerateSerialView.
    func lookup(machineID: String) -> ClientRecord? {
        let trimmed = machineID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return records.first { $0.machineID == trimmed }
    }

    /// Sugestii de nume, pt. dropdown-ul de autocompletare — minim 2
    /// caractere, ca să nu apară o listă imensă la fiecare literă tastată.
    func suggestions(forNamePrefix text: String) -> [ClientRecord] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return [] }
        return records.filter { $0.name.localizedCaseInsensitiveContains(trimmed) }.prefix(6).map { $0 }
    }
}
