import XCTest
@testable import GDCPluginManagerCore

final class ExternalAppUpdateStateTests: XCTestCase {
    private func state(_ i: String?, _ p: String?) -> ExternalAppUpdateState {
        ExternalAppUpdateState.evaluate(installed: i, published: p, isNewer: AppVersion.isNewer)
    }

    func testOlderInstalledOffersUpdate() { XCTAssertEqual(state("1.2.1", "1.3.0"), .updateAvailable) }
    func testSameVersionIsUpToDate() { XCTAssertEqual(state("1.3.0", "1.3.0"), .upToDate) }
    func testNewerInstalledIsNotAnUpdate() { XCTAssertEqual(state("1.4.0", "1.3.0"), .upToDate) }
    func testUnreadInstalledVersionNeverOffersUpdate() { XCTAssertEqual(state(nil, "1.3.0"), .unknown); XCTAssertEqual(state("", "1.3.0"), .unknown) }
    func testUnreachableManifestNeverOffersUpdate() { XCTAssertEqual(state("1.2.1", nil), .unknown) }

    /// Eticheta nu trebuie să sugereze că Managerul instalează: acțiunea doar deschide pagina produsului.
    func testUpdateActionLabelsSayTheyOpenThePage() throws {
        let src = try String(contentsOf: repoRoot.appendingPathComponent("Sources/GDCPluginManager/Localization.swift"), encoding: .utf8)
        let line = try XCTUnwrap(src.split(separator: "\n").first { $0.contains("\"myApps.update\":") })
        XCTAssertTrue(line.contains("Deschide pagina de actualizare…"))
        XCTAssertTrue(line.contains("Open update page…"))
        XCTAssertTrue(line.contains("Abrir página de actualización…"))
    }
}
