import XCTest
@testable import GDCPluginManagerCore

final class UpdateManifestTests: XCTestCase {
    private func realData() throws -> Data {
        try Data(contentsOf: repoRoot.appendingPathComponent("docs/update.json"))
    }

    func testRealManifestDecodesForCurrentClients() throws {
        let manifest = try JSONDecoder().decode(UpdateManifest.self, from: try realData())
        for (name, info) in [("mac", manifest.mac), ("windows", manifest.windows)] {
            let info = try XCTUnwrap(info, "secțiunea \(name) lipsește")
            XCTAssertNotNil(info.version.range(of: #"^\d+\.\d+\.\d+$"#, options: .regularExpression), "\(name): versiune invalidă")
            let url = try XCTUnwrap(URL(string: info.download_url))
            XCTAssertEqual(url.scheme, "https", "\(name): download_url non-https")
            XCTAssertEqual(url.host, "github.com", "\(name): download_url în afara GitHub Releases")
            if let min = info.min_version {
                XCTAssertFalse(AppVersion.isNewer(min, than: info.version), "\(name): min_version > version")
            }
        }
    }

    /// Regula 35: blocul de la rădăcină e contractul clienților <= 1.27.1, care
    /// decodează `version: String` + `download_url: [String: String]` OBLIGATORII.
    private struct LegacyRoot: Decodable {
        let version: String
        let download_url: [String: String]
        let mandatory: Bool?
    }

    func testLegacyRootBlockStillDecodes() throws {
        let legacy = try JSONDecoder().decode(LegacyRoot.self, from: try realData())
        XCTAssertNotNil(legacy.download_url["mac"])
        XCTAssertNotNil(legacy.download_url["windows"])
    }

    func testLegacyRootVersionIsMinimumOfPlatforms() throws {
        let legacy = try JSONDecoder().decode(LegacyRoot.self, from: try realData())
        let manifest = try JSONDecoder().decode(UpdateManifest.self, from: try realData())
        let mac = try XCTUnwrap(manifest.mac?.version), win = try XCTUnwrap(manifest.windows?.version)
        let minimum = AppVersion.isNewer(mac, than: win) ? win : mac
        XCTAssertEqual(legacy.version, minimum, "versiunea de la rădăcină trebuie să fie MINIMUL mac/windows")
    }

    func testMissingPlatformSectionIsNilNotError() throws {
        let m = try JSONDecoder().decode(UpdateManifest.self, from: Data(#"{"version": "1.0.0"}"#.utf8))
        XCTAssertNil(m.mac)
    }

    func testMalformedSectionFails() {
        // download_url lipsă într-o secțiune => eroare, raportată de UpdateChecker ca „nu am putut verifica”.
        XCTAssertThrowsError(try JSONDecoder().decode(UpdateManifest.self, from: Data(#"{"mac": {"version": "2.0.0"}}"#.utf8)))
        XCTAssertThrowsError(try JSONDecoder().decode(UpdateManifest.self, from: Data("nu e json".utf8)))
    }

    func testVersionComparison() {
        XCTAssertTrue(AppVersion.isNewer("1.10.0", than: "1.9.9"))
        XCTAssertTrue(AppVersion.isNewer("2.0", than: "1.99.99"))
        XCTAssertFalse(AppVersion.isNewer("1.2", than: "1.2.0"))
        XCTAssertFalse(AppVersion.isNewer("1.2.0", than: "1.2.0"))
        XCTAssertFalse(AppVersion.isNewer("1.2.0", than: "1.2.1"))
        XCTAssertTrue(AppVersion.isNewer("1.2.1", than: "1.2"))
        // Segment nenumeric = 0: „1.x” nu e mai nou decât „1.0”.
        XCTAssertFalse(AppVersion.isNewer("1.x", than: "1.0"))
    }

    func testInstalledVersionMatchesManifest() throws {
        // Versiunea din Info.plist nu trebuie să fie mai nouă decât cea anunțată
        // (ar însemna un build nepublicat) — e permis să fie egală sau mai veche.
        let plist = try XCTUnwrap(NSDictionary(contentsOf: repoRoot.appendingPathComponent("Info.plist")))
        let local = try XCTUnwrap(plist["CFBundleShortVersionString"] as? String)
        let published = try XCTUnwrap(try JSONDecoder().decode(UpdateManifest.self, from: try realData()).mac?.version)
        XCTAssertFalse(AppVersion.isNewer(local, than: published),
                       "Info.plist (\(local)) e mai nou decât update.json mac (\(published)) — release nepublicat?")
    }
}
