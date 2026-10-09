import XCTest
@testable import GDCPluginManagerCore

/// Contractul intrării „GDC STYLE Client” din „Aplicațiile mele”: lista e în ținta executabilă
/// (`MyAppsLauncher.swift`, netestabilă direct), deci se verifică sursa față de catalog și de
/// canalul public de actualizare.
final class MyAppsStyleClientTests: XCTestCase {
    private func launcherSource() throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent("Sources/GDCPluginManager/MyAppsLauncher.swift"), encoding: .utf8)
    }

    func testStyleClientIsListedWithItsBundleIdentifierAndPublicChannel() throws {
        let src = try launcherSource()
        let start = try XCTUnwrap(src.range(of: #"MyAppEntry(id: "gdc-style-client""#), "intrarea gdc-style-client lipsește din knownGDCApps")
        let entry = String(src[start.lowerBound...].prefix(400))
        XCTAssertTrue(entry.contains(#"bundleIdentifier: "dev.gordas.GDCStyleClient""#), "bundle ID greșit")
        XCTAssertTrue(entry.contains(#"https://gordas.dev/gdc-style-client/update.json"#), "versiunea nu vine din update.json-ul Clientului")
        XCTAssertTrue(entry.contains(".updateJSON"), "sursa de versiune trebuie să fie update.json, nu GitHub Releases")
    }

    func testStyleClientIsNotConfusedWithTheDevelopmentTool() throws {
        // GDC STYLE Lab (`dev.gordas.GDCLUTLab`) e instrument de dezvoltare și nu apare aici.
        XCTAssertFalse(try launcherSource().contains(#"bundleIdentifier: "dev.gordas.GDCLUTLab""#))
    }

    func testCatalogHasTheSameProductPage() throws {
        let data = try Data(contentsOf: repoRoot.appendingPathComponent("docs/catalog.json"))
        let json = try JSONSerialization.jsonObject(with: data)
        let apps = (json as? [String: Any])?["apps"] as? [[String: Any]] ?? (json as? [[String: Any]]) ?? []
        let client = try XCTUnwrap(apps.first { $0["id"] as? String == "gdc-style-client" }, "gdc-style-client lipsește din catalog")
        XCTAssertEqual(client["url"] as? String, "https://gordas.dev/gdc-style-client/")
    }
}
