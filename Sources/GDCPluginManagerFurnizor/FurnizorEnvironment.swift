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

    /// Repo-ul în care urmează o scriere git trebuie să aparțină mediului activ.
    static func assertRepoWritable(_ slug: String) throws {
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
    }
}
