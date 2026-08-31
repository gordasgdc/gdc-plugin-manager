import Foundation
import GDCPluginManagerCore

/// Reads/writes docs/launch-banner.json - port 1:1 al tiparului din
/// PricingEditor.swift (pull -> write -> commit+push).
enum LaunchBannerEditor {
    private static var decoder: JSONDecoder { JSONDecoder() }
    private static var encoder: JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return e
    }

    static func load() throws -> LaunchBannerConfig {
        let data = try Data(contentsOf: RepoCheckoutPaths.launchBannerJSONURL)
        return try decoder.decode(LaunchBannerConfig.self, from: data)
    }

    static func save(_ config: LaunchBannerConfig) throws {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        var updated = config
        updated.updatedAt = formatter.string(from: Date())
        let data = try encoder.encode(updated)
        try data.write(to: RepoCheckoutPaths.launchBannerJSONURL)
    }

    /// Salvează local ȘI publică (git pull -> commit -> push). `paths`
    /// include și `docs/covers` — imaginea (dacă a fost înlocuită de
    /// `CoverImageStore.commit`, cu id-ul fix `launch-banner`) trebuie să
    /// ajungă în ACELAȘI commit ca JSON-ul, altfel clienții ar primi un
    /// `imagePath` care încă nu există pe server (404 tranzitoriu).
    static func publish(_ config: LaunchBannerConfig, message: String) throws {
        try GitOps.pull(at: RepoCheckoutPaths.publicCatalogRepo)
        try save(config)
        try GitOps.commitAndPush(
            at: RepoCheckoutPaths.publicCatalogRepo,
            message: message,
            paths: ["docs/launch-banner.json", "docs/covers"]
        )
    }
}
