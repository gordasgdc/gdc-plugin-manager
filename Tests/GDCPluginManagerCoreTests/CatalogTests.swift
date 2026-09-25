import XCTest
@testable import GDCPluginManagerCore

/// Rădăcina repo-ului, derivată din locația acestui fișier.
let repoRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

final class CatalogTests: XCTestCase {
    private func decode(_ json: String) throws -> Catalog {
        try JSONDecoder().decode(Catalog.self, from: Data(json.utf8))
    }

    private func item(_ extra: String = "", id: String = "p1", type: String = "dctl", os: String? = nil) -> String {
        let osField = os.map { #", "supportedOS": "\#($0)""# } ?? ""
        return #"{"id": "\#(id)", "name": "N", "type": "\#(type)", "description": "D", "version": "1.0.0", "priceEUR": 0, "files": [{"path": "\#(id)/1.0.0/a.dctl", "sha256": "\#(String(repeating: "a", count: 64))", "repo": "files"}]\#(osField)\#(extra)}"#
    }

    // MARK: - Catalogul real publicat

    private func realCatalogData() throws -> Data {
        try Data(contentsOf: repoRoot.appendingPathComponent("docs/catalog.json"))
    }

    func testRealCatalogDecodes() throws {
        let catalog = try JSONDecoder().decode(Catalog.self, from: try realCatalogData())
        XCTAssertFalse(catalog.items.isEmpty, "catalogul publicat nu are niciun produs")
    }

    func testRealCatalogHasNoUnknownTypesOrDuplicateIDs() throws {
        let catalog = try JSONDecoder().decode(Catalog.self, from: try realCatalogData())
        let products = catalog.items + catalog.scriptItems
        XCTAssertFalse(products.contains { $0.type == .unknown }, "tip de produs necunoscut în catalogul publicat")
        let ids = products.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count, "ID-uri de produs duplicate: \(ids)")
    }

    func testRealCatalogFileEntriesAreWellFormed() throws {
        let catalog = try JSONDecoder().decode(Catalog.self, from: try realCatalogData())
        let hex = CharacterSet(charactersIn: "0123456789abcdef")
        for product in catalog.items + catalog.scriptItems {
            XCTAssertFalse(product.files.isEmpty, "\(product.id): fără fișiere")
            XCTAssertNotNil(product.version.range(of: #"^\d+(\.\d+){1,3}$"#, options: .regularExpression),
                            "\(product.id): versiune invalidă \(product.version)")
            var paths = Set<String>()
            for file in product.files {
                XCTAssertEqual(file.sha256.count, 64, "\(product.id): SHA-256 cu lungime greșită")
                XCTAssertTrue(file.sha256.unicodeScalars.allSatisfy(hex.contains), "\(product.id): SHA-256 nu e hex minuscul")
                XCTAssertFalse(file.path.hasPrefix("/") || file.path.split(separator: "/").contains(".."),
                               "\(product.id): cale nesigură \(file.path)")
                XCTAssertTrue(paths.insert(file.path).inserted, "\(product.id): cale duplicată \(file.path)")
                if let repo = file.repo { XCTAssertTrue(["files", "pdfs", "scripts"].contains(repo), "\(product.id): repo necunoscut \(repo)") }
            }
        }
    }

    func testRealCatalogURLsAreHTTPS() throws {
        let catalog = try JSONDecoder().decode(Catalog.self, from: try realCatalogData())
        for product in catalog.items + catalog.scriptItems {
            for raw in [product.youtubeURL, product.purchaseURL, product.demoURL].compactMap({ $0 }) where !raw.isEmpty {
                XCTAssertEqual(URL(string: raw)?.scheme, "https", "\(product.id): URL non-https \(raw)")
            }
        }
    }

    func testRealCatalogParsingIsDeterministic() throws {
        let data = try realCatalogData()
        let a = try JSONDecoder().decode(Catalog.self, from: data)
        let b = try JSONDecoder().decode(Catalog.self, from: data)
        XCTAssertEqual(a.items, b.items)
        let raw = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let fileOrder = (raw?["items"] as? [[String: Any]])?.compactMap { $0["id"] as? String }
        XCTAssertEqual(a.items.map(\.id), fileOrder, "ordinea produselor trebuie să fie cea din fișier")
    }

    // MARK: - Compatibilitate și intrări invalide

    func testEmptyAndMinimalCatalog() throws {
        XCTAssertTrue(try decode("{}").items.isEmpty)
        let c = try decode(#"{"items": [\#(item())]}"#)
        XCTAssertEqual(c.items.first?.supportedOS, .crossPlatform, "lipsa supportedOS = ambele platforme (compatibilitate)")
        XCTAssertEqual(c.items.first?.isFree, false)
    }

    func testUnknownTopLevelKeyIsIgnored() throws {
        // Regula de evoluție a catalogului: cheile noi de nivel superior nu rup clienții vechi.
        XCTAssertEqual(try decode(#"{"items": [\#(item())], "cheieViitoare": [1, 2]}"#).items.count, 1)
    }

    func testUnknownProductTypeDecodesAsUnknown() throws {
        XCTAssertEqual(try decode(#"{"items": [\#(item(type: "tipViitor"))]}"#).items.first?.type, .unknown)
    }

    func testUnknownSupportedOSBreaksWholeCatalog() {
        // RISC DOCUMENTAT (nu comportament dorit): o valoare nouă de supportedOS
        // face ÎNTREG catalogul nedecodabil pe clienții instalați. Validatorul
        // (scripts/validate_catalog.py) blochează publicarea unei asemenea valori.
        XCTAssertThrowsError(try decode(#"{"items": [\#(item(os: "linux"))]}"#))
    }

    func testMissingRequiredFieldFailsDecoding() {
        let noName = item().replacingOccurrences(of: #""name": "N", "#, with: "")
        XCTAssertThrowsError(try decode(#"{"items": [\#(noName)]}"#))
        let noPrice = item().replacingOccurrences(of: #", "priceEUR": 0"#, with: "")
        XCTAssertThrowsError(try decode(#"{"items": [\#(noPrice)]}"#))
    }

    func testMalformedJSONFails() {
        XCTAssertThrowsError(try decode(#"{"items": [{"id": "x""#))
        XCTAssertThrowsError(try decode(#"{"items": {"id": "x"}}"#))
    }

    func testLegacySingleFileEntry() throws {
        let legacy = #"{"items": [{"id": "old", "name": "N", "type": "lut", "description": "D", "version": "1.0", "priceEUR": 23, "filePath": "old.cube", "sha256": "\#(String(repeating: "b", count: 64))"}]}"#
        let file = try XCTUnwrap(try decode(legacy).items.first?.files.first)
        XCTAssertEqual(file.path, "old.cube")
        XCTAssertNil(file.repo)
    }

    func testSupportedOSAllows() {
        XCTAssertTrue(SupportedOS.crossPlatform.allows(current: .macOS))
        XCTAssertTrue(SupportedOS.macOS.allows(current: .macOS))
        XCTAssertFalse(SupportedOS.windows.allows(current: .macOS))
    }
}
