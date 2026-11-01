import XCTest
@testable import GDCPluginManagerCore

/// Contractul SADROG în platformă: catalog ↔ „Aplicațiile mele” ↔ canalul public de actualizare ↔ pagina.
/// Lista „Aplicațiile mele” e în ținta executabilă, deci se verifică sursa, ca în MyAppsStyleClientTests.
final class MyAppsSadrogTests: XCTestCase {
    private func launcherSource() throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent("Sources/GDCPluginManager/MyAppsLauncher.swift"), encoding: .utf8)
    }
    private func catalogApp() throws -> [String: Any] {
        let data = try Data(contentsOf: repoRoot.appendingPathComponent("docs/catalog.json"))
        let apps = ((try JSONSerialization.jsonObject(with: data)) as? [String: Any])?["apps"] as? [[String: Any]] ?? []
        return try XCTUnwrap(apps.first { $0["id"] as? String == "sadrog" }, "sadrog lipsește din catalog (apps[])")
    }

    func testListedWithBundleIdentifierTeamAndPublicChannel() throws {
        let src = try launcherSource()
        let start = try XCTUnwrap(src.range(of: #"MyAppEntry(id: "sadrog""#), "intrarea sadrog lipsește din knownGDCApps")
        let entry = String(src[start.lowerBound...].prefix(600))
        XCTAssertTrue(entry.contains(#"bundleIdentifier: "dev.gordas.sadrog""#))
        XCTAssertTrue(entry.contains(#"teamIdentifier: "8AR6XP8MG7""#), "fără Team ID, o copie de test ar fi luată drept instalare")
        XCTAssertTrue(entry.contains(".updateJSON") && entry.contains("https://gordas.dev/sadrog/update.json"))
        XCTAssertTrue(entry.contains("https://gordas.dev/sadrog/"), "acțiunea Actualizează trebuie să deschidă pagina produsului")
    }

    func testCatalogEntryIsAnIndependentMacOSAppNotAPlugin() throws {
        let app = try catalogApp()
        XCTAssertEqual(app["supportedOS"] as? String, "macOS", "SADROG nu este disponibil pe Windows")
        XCTAssertEqual(app["url"] as? String, "https://gordas.dev/sadrog/")
        XCTAssertEqual(app["downloadURL"] as? String, "https://github.com/gordasgdc/sadrog/releases/latest/download/SADROG.dmg")
        XCTAssertNil(app["pricingProductID"], "prețul SADROG rămâne în aplicație")
        let data = try Data(contentsOf: repoRoot.appendingPathComponent("docs/catalog.json"))
        let items = ((try JSONSerialization.jsonObject(with: data)) as? [String: Any])?["items"] as? [[String: Any]] ?? []
        XCTAssertFalse(items.contains { $0["id"] as? String == "sadrog" }, "SADROG nu este plugin")
    }

    func testCatalogHasNoPublicAmountAndCoverExists() throws {
        let app = try catalogApp()
        let text = String(data: try JSONSerialization.data(withJSONObject: app), encoding: .utf8) ?? ""
        XCTAssertNil(text.range(of: #"\d\s?(EUR|€|euro|lei|RON)"#, options: [.regularExpression, .caseInsensitive]), "sumă în intrarea publică")
        let cover = try XCTUnwrap(app["coverImage"] as? String)
        let rel = String(cover.split(separator: "?")[0])
        XCTAssertTrue(FileManager.default.fileExists(atPath: repoRoot.appendingPathComponent("docs/" + rel).path), "copertă lipsă: \(rel)")
    }

    func testPublicUpdateManifestStaysDecodableByInstalledClients() throws {
        let data = try Data(contentsOf: repoRoot.appendingPathComponent("docs/sadrog/update.json"))
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertNotNil(json["version"] as? String, "câmpul `version` (String) e citit de „Aplicațiile mele”")
        XCTAssertTrue(json["build"] is String, "`build` trebuie să rămână text (clienții instalați îl decodează ca String)")
        XCTAssertNotNil((json["download_url"] as? [String: Any])?["mac"] as? String)
        XCTAssertNil((json["download_url"] as? [String: Any])?["windows"], "SADROG nu are variantă Windows")
    }
}
