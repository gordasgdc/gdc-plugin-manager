import XCTest
@testable import GDCPluginManagerFurnizor
import GDCPluginManagerCore

/// Release de produs GDC STYLE Lab V3 → item de catalog: identitățile vin din manifest și sunt verificate pe disc (Info.plist).
final class StyleLabProductPublisherTests: XCTestCase {
    private var work: URL!
    override func setUpWithError() throws {
        work = FileManager.default.temporaryDirectory.appendingPathComponent("furnizor-v3-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: work) }

    private func bundle(_ rel: String, id: String, version: String) throws {
        let c = work.appendingPathComponent(rel).appendingPathComponent("Contents")
        try FileManager.default.createDirectory(at: c.appendingPathComponent("MacOS"), withIntermediateDirectories: true)
        XCTAssertTrue((["CFBundleIdentifier": id, "CFBundleShortVersionString": version] as NSDictionary).write(to: c.appendingPathComponent("Info.plist"), atomically: true))
        try Data("bin".utf8).write(to: c.appendingPathComponent("MacOS/plugin"))
    }

    private func manifest(version: String = "1.1.0", licence: String = "gdc-style-v3-look") -> Data {
        func ed(_ e: String, _ folder: String, _ vid: String) -> [String: Any] { ["package": ["folder": folder, "identifier": "dev.gordas.style.v3.look.\(vid).\(e)", "version": version]] }
        let o: [String: Any] = [
            "schema": "gdc-product-release@1",
            "product": ["productId": "gdc-style-v3-look", "instrument": "look", "name": "GDC Look", "version": version, "workflow": ["orderKey": 232, "stage": "log"]],
            "licence": ["identity": licence, "scope": "product"],
            "variants": [["variantId": "ap1-acescct", "family": "ACES", "label": "ACES", "slot": "dev.gordas.style.v3.look.ap1-acescct",
                          "editions": ["full": ed("full", "Full/GDC Look — ACES.ofx.bundle", "ap1-acescct"), "demo": ed("demo", "Demo/GDC Look — ACES (Demo).ofx.bundle", "ap1-acescct")]]],
        ]
        return try! JSONSerialization.data(withJSONObject: o)
    }

    func testPrepareBuildsOneProductWithBothEditions() throws {
        try bundle("Full/GDC Look — ACES.ofx.bundle", id: "dev.gordas.style.v3.look.ap1-acescct.full", version: "1.1.0")
        try bundle("Demo/GDC Look — ACES (Demo).ofx.bundle", id: "dev.gordas.style.v3.look.ap1-acescct.demo", version: "1.1.0")
        let p = try StyleLabProductPublisher.prepare(manifest: manifest(), releaseFolder: work)
        XCTAssertEqual(p.release.productId, "gdc-style-v3-look")
        XCTAssertEqual(p.release.placement?.orderKey, 232)
        XCTAssertEqual(p.files.count, 4)
        XCTAssertTrue(p.files.allSatisfy { $0.repoPath.hasPrefix("gdc-style-v3-look/1.1.0/") })
        let item = StyleLabProductPublisher.item(p, files: p.files.map { PluginFile(path: $0.repoPath, sha256: "x", repo: "files") }, existing: nil, description: "", defaultDonationEUR: 23)
        XCTAssertFalse(item.isFree)
        XCTAssertNil(item.ofxProduct?.validate(itemID: item.id, itemVersion: item.version))
        XCTAssertTrue(item.ofxProduct!.isDemoPath("gdc-style-v3-look/1.1.0/Demo/GDC Look — ACES (Demo).ofx.bundle/Contents/Info.plist"))
    }

    func testPrepareRejectsDiskThatDisagreesWithManifest() throws {
        try bundle("Full/GDC Look — ACES.ofx.bundle", id: "dev.gordas.style.v3.look.ap1-acescct.full", version: "1.0.2")   // versiune veche pe disc
        try bundle("Demo/GDC Look — ACES (Demo).ofx.bundle", id: "dev.gordas.style.v3.look.ap1-acescct.demo", version: "1.1.0")
        XCTAssertThrowsError(try StyleLabProductPublisher.prepare(manifest: manifest(), releaseFolder: work))
    }

    func testPrepareRejectsForeignLicenceIdentity() throws {
        try bundle("Full/GDC Look — ACES.ofx.bundle", id: "dev.gordas.style.v3.look.ap1-acescct.full", version: "1.1.0")
        try bundle("Demo/GDC Look — ACES (Demo).ofx.bundle", id: "dev.gordas.style.v3.look.ap1-acescct.demo", version: "1.1.0")
        XCTAssertThrowsError(try StyleLabProductPublisher.prepare(manifest: manifest(licence: "gdc-style-v3-film"), releaseFolder: work))
    }

    func testV3RegistryHasOnlyCanonicalProductIDs() {
        XCTAssertEqual(Set(gdcStyleLabV3Products.map(\.id)).count, gdcStyleLabV3Products.count)
        XCTAssertTrue(gdcStyleLabV3Products.allSatisfy { $0.id.hasPrefix("gdc-style-v3-") })
        XCTAssertTrue(Set(gdcStandaloneProducts.map(\.id)).isDisjoint(with: gdcStyleLabV3Products.map(\.id)))
    }
}
