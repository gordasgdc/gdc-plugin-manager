import XCTest
@testable import GDCPluginManagerCore

/// Contractul Scaner GDC în platformă: catalog ↔ „Aplicațiile mele” ↔ manifestul propriu (GitHub Pages) ↔ pagina platformei.
final class MyAppsScanerTests: XCTestCase {
    private func catalogApp() throws -> [String: Any] {
        let data = try Data(contentsOf: repoRoot.appendingPathComponent("docs/catalog.json"))
        let apps = ((try JSONSerialization.jsonObject(with: data)) as? [String: Any])?["apps"] as? [[String: Any]] ?? []
        return try XCTUnwrap(apps.first { $0["id"] as? String == "scaner-gdc" }, "scaner-gdc lipsește din catalog (apps[])")
    }

    func testListedWithBundleIdentifierTeamAndOwnManifest() throws {
        let src = try String(contentsOf: repoRoot.appendingPathComponent("Sources/GDCPluginManager/MyAppsLauncher.swift"), encoding: .utf8)
        let start = try XCTUnwrap(src.range(of: #"MyAppEntry(id: "scaner-gdc""#), "intrarea scaner-gdc lipsește din knownGDCApps")
        let entry = String(src[start.lowerBound...].prefix(700))
        XCTAssertTrue(entry.contains(#"bundleIdentifier: "dev.gordas.GDCEffectsLibrary""#))
        XCTAssertTrue(entry.contains(#"teamIdentifier: "8AR6XP8MG7""#), "fără Team ID, o copie de test ar fi luată drept instalare")
        XCTAssertTrue(entry.contains("https://gordasgdc.github.io/scaner-gdc/update.json"), "versiunea vine doar din manifestul produsului")
        XCTAssertTrue(entry.contains("pageURL: URL(string: \"https://gordasgdc.github.io/scaner-gdc/\")"))
    }

    func testCatalogEntryIsAnIndependentFreeMacApp() throws {
        let app = try catalogApp()
        XCTAssertEqual(app["supportedOS"] as? String, "macOS")
        XCTAssertEqual(app["url"] as? String, "https://gordasgdc.github.io/scaner-gdc/")
        XCTAssertEqual(app["downloadURL"] as? String, "https://github.com/gordasgdc/scaner-gdc/releases/latest/download/ScanerGDC-macOS.dmg")
        XCTAssertNil(app["pricingProductID"])
        XCTAssertNil(app["files"], "aplicațiile nu au `files` (contract de plugin)")
        let text = String(data: try JSONSerialization.data(withJSONObject: app), encoding: .utf8) ?? ""
        XCTAssertNil(text.range(of: #"\d\s?(EUR|€|euro|lei|RON)"#, options: [.regularExpression, .caseInsensitive]))
        let cover = try XCTUnwrap(app["coverImage"] as? String)
        XCTAssertTrue(FileManager.default.fileExists(atPath: repoRoot.appendingPathComponent("docs/" + String(cover.split(separator: "?")[0])).path))
    }
}
