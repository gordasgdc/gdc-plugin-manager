import Foundation

/// Contractul `docs/update.json` (servit la gordas.dev) — mutat din
/// `UpdateChecker.swift` în Core (2026-09-25) ca să fie testabil
/// (`Tests/GDCPluginManagerCoreTests/UpdateManifestTests.swift`). Numele
/// câmpurilor rămân cele din JSON, neschimbate: orice redenumire ar rupe
/// clienții deja instalați (Regula 35).
public struct UpdateInfo: Decodable {
    public let version: String
    public let release_date: String?
    public let changes: String?
    public let download_url: String
    public let mandatory: Bool?
    public let min_version: String?
    /// Opțional (2026-09-25): SHA-256 al arhivei de la `download_url`. Dacă e
    /// prezent, SelfUpdater refuză o arhivă diferită. Absența lui nu rupe nimic.
    public let sha256: String?
}

/// Secțiunile per platformă (clienți >= 1.27.2). Blocul de la rădăcină
/// (`version` + `download_url` ca dicționar) există doar pentru clienții
/// <= 1.27.1 și nu e decodat aici — îl verifică testele.
public struct UpdateManifest: Decodable {
    public let mac: UpdateInfo?
    public let windows: UpdateInfo?
}

public enum AppVersion {
    /// Comparație numerică pe segmente („1.10.0” > „1.2.0”); un segment
    /// nenumeric contează ca 0, iar segmentele lipsă ca 0 („1.2” == „1.2.0”).
    public static func isNewer(_ a: String, than b: String) -> Bool {
        let partsA = a.split(separator: ".").map { Int($0) ?? 0 }
        let partsB = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(partsA.count, partsB.count) {
            let x = i < partsA.count ? partsA[i] : 0
            let y = i < partsB.count ? partsB[i] : 0
            if x != y { return x > y }
        }
        return false
    }
}
