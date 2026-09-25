import Foundation

/// Mediul în care rulează Furnizorul (1.52.4). Producția e implicită; staging se activează DOAR explicit,
/// la pornire: `open -b com.gordasgdc.pluginmanager.furnizor --env GDC_FURNIZOR_ENV=staging`.
///
/// Reguli (verificate în `GitOps.verifyPublishCheckout` și la scrierile către servicii):
/// - staging: se scrie DOAR în repo-urile `gordasgdc/*-staging`; Supabase (revocări), secretele și
///   registrul local de vânzări sunt blocate;
/// - producție: orice scriere într-un repo `*-staging` e refuzată.
/// O valoare necunoscută a variabilei NU înseamnă producție: pornește în staging (eșec închis).
enum FurnizorEnvironment: String {
    case production, staging

    static let variableName = "GDC_FURNIZOR_ENV"

    /// Doar pentru teste.
    static var override: FurnizorEnvironment?

    static let fromLaunch: FurnizorEnvironment = resolve(ProcessInfo.processInfo.environment[variableName])

    static var active: FurnizorEnvironment { override ?? fromLaunch }

    static func resolve(_ value: String?) -> FurnizorEnvironment {
        guard let value, !value.isEmpty else { return .production }
        return value == "production" ? .production : .staging
    }

    static let stagingSuffix = "-staging"

    static func isStagingSlug(_ slug: String) -> Bool { slug.lowercased().hasSuffix(stagingSuffix) }

    struct WriteRefused: Error, LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    // MARK: 1.52.5 — sesiunea anterioară: producția după staging cere confirmare

    /// Ultimul mediu pornit (comun ambelor medii). Doar metadate: mediul și data.
    static var sessionFileOverride: URL?
    static var sessionFile: URL {
        sessionFileOverride ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("GDC License Manager", isDirectory: true)
            .appendingPathComponent("last-environment.json")
    }

    /// true = pornire în PRODUCȚIE după o sesiune STAGING, neconfirmată încă → TOATE scrierile blocate.
    static private(set) var productionConfirmationPending = false

    static func lastSessionEnvironment() -> FurnizorEnvironment? {
        guard let data = try? Data(contentsOf: sessionFile),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let raw = obj["environment"] as? String else { return nil }
        return FurnizorEnvironment(rawValue: raw)
    }

    private static func recordSession(_ env: FurnizorEnvironment) {
        let obj: [String: Any] = ["environment": env.rawValue, "at": ISO8601DateFormatter().string(from: Date())]
        guard let data = try? JSONSerialization.data(withJSONObject: obj, options: [.sortedKeys]) else { return }
        try? FileManager.default.createDirectory(at: sessionFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: sessionFile, options: .atomic)
    }

    /// Apelat o singură dată, la pornire (înaintea oricărei operații). Staging se notează imediat;
    /// producția după staging rămâne blocată la scriere până la `confirmProduction()`.
    static func bootstrapSession() {
        switch active {
        case .staging:
            productionConfirmationPending = false
            recordSession(.staging)
        case .production:
            productionConfirmationPending = lastSessionEnvironment() == .staging
            if !productionConfirmationPending { recordSession(.production) }
        }
    }

    /// Confirmarea explicită din dialog: deblochează scrierile în producție.
    static func confirmProduction() {
        guard active == .production else { return }
        productionConfirmationPending = false
        recordSession(.production)
    }

    /// Scrierile în producție sunt permise doar după confirmare (când ultima sesiune a fost staging).
    static var productionWritesUnlocked: Bool { active == .production && !productionConfirmationPending }

    private static func assertProductionConfirmed() throws {
        guard !productionConfirmationPending else {
            throw WriteRefused(message: "PRODUCȚIE neconfirmată: ultima sesiune a fost STAGING. Confirmă „Continuă în PRODUCȚIE” din bannerul de sus înainte de orice scriere. Nimic nu s-a modificat.")
        }
    }

    /// Repo-ul în care urmează o scriere git trebuie să aparțină mediului activ.
    static func assertRepoWritable(_ slug: String) throws {
        if active == .production { try assertProductionConfirmed() }
        switch active {
        case .staging where !isStagingSlug(slug):
            throw WriteRefused(message: "MEDIU DE TEST — STAGING: scrierea în repo-ul de producție \(slug) e refuzată. Nimic nu s-a modificat.")
        case .production where isStagingSlug(slug):
            throw WriteRefused(message: "Producție: scrierea în repo-ul de test \(slug) e refuzată. Pornește Furnizorul în modul staging pentru teste.")
        default:
            break
        }
    }

    /// Scrieri către servicii / date de producție care nu trec prin git (Supabase, secrete, registrul de vânzări).
    static func assertProductionWriteAllowed(_ what: String) throws {
        guard active == .production else {
            throw WriteRefused(message: "MEDIU DE TEST — STAGING: \(what) e blocat(ă) în staging (ar modifica producția).")
        }
        try assertProductionConfirmed()
    }

    /// Doar pentru teste.
    static func resetSessionStateForTests() { productionConfirmationPending = false }
}
