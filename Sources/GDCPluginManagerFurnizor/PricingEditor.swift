import Foundation

/// Reads/writes docs/pricing.json in the local public-repo checkout, then
/// publishes via GitOps (pull -> write -> commit+push) — port 1:1 al
/// tiparului din CatalogEditor.swift, dar pentru un singur fișier mic
/// (nu o colecție de produse marketplace).
enum PricingEditor {
    private static var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    private static var encoder: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return e
    }

    static func load() throws -> PricingCatalog {
        let data = try Data(contentsOf: RepoCheckoutPaths.pricingJSONURL)
        return try decoder.decode(PricingCatalog.self, from: data)
    }

    /// Scrie DOAR local — folosit pentru salvări intermediare fără publish
    /// (Furnizor arată un buton separat "Publică" care face și git push).
    static func save(_ catalog: PricingCatalog) throws {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        var updated = catalog
        updated.updatedAt = formatter.string(from: Date())
        let data = try encoder.encode(updated)
        try data.write(to: RepoCheckoutPaths.pricingJSONURL)
    }

    /// Salvează local ȘI publică (git pull -> commit -> push) — apelat
    /// direct de butonul "Publică" din PricingManagerView. `pull` ÎNTÂI,
    /// ca să nu suprascrie o schimbare făcută de pe alt Mac între timp
    /// (același tipar ca restul editorilor din acest repo).
    static func publish(_ catalog: PricingCatalog, message: String) throws {
        try GitOps.pull(at: RepoCheckoutPaths.publicCatalogRepo)
        try save(catalog)
        try GitOps.commitAndPush(
            at: RepoCheckoutPaths.publicCatalogRepo,
            message: message,
            paths: ["docs/pricing.json"]
        )
    }
}
