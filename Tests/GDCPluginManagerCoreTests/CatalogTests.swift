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
        // Un catalog fără produse e o stare validă (ex. toate demo-urile retrase);
        // contractul e că decodează și că nu e complet gol.
        let catalog = try JSONDecoder().decode(Catalog.self, from: try realCatalogData())
        let total = catalog.items.count + catalog.scriptItems.count + catalog.apps.count
            + catalog.downloadableResources.count + catalog.pdfResources.count
        XCTAssertGreaterThan(total, 0, "catalogul publicat e complet gol")
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

    // MARK: - Regulile catalogului ca funcție pură + dovada că verificarea chiar prinde defecte

    /// Aceleași reguli pe care le aplică testele catalogului real, aplicabile și pe fixture-uri: un catalog real FĂRĂ produse (stare validă) face testele de mai sus să treacă
    /// pe o colecție goală, deci nu dovedesc nimic despre reguli — `testCatalogRulesHaveTeeth` le demonstrează pe fixture-uri cu defecte cunoscute.
    private func catalogProblems(_ catalog: Catalog) -> [String] {
        var out: [String] = []
        let products = catalog.items + catalog.scriptItems
        if products.contains(where: { $0.type == .unknown }) { out.append("tip de produs necunoscut") }
        let ids = products.map(\.id)
        if ids.count != Set(ids).count { out.append("ID-uri de produs duplicate") }
        let hex = CharacterSet(charactersIn: "0123456789abcdef")
        for product in products {
            if product.files.isEmpty { out.append("\(product.id): fără fișiere") }
            if product.version.range(of: #"^\d+(\.\d+){1,3}$"#, options: .regularExpression) == nil { out.append("\(product.id): versiune invalidă") }
            var paths = Set<String>()
            for file in product.files {
                if file.sha256.count != 64 { out.append("\(product.id): SHA-256 cu lungime greșită") }
                if !file.sha256.unicodeScalars.allSatisfy(hex.contains) { out.append("\(product.id): SHA-256 nu e hex minuscul") }
                if file.path.hasPrefix("/") || file.path.split(separator: "/").contains("..") { out.append("\(product.id): cale nesigură") }
                if !paths.insert(file.path).inserted { out.append("\(product.id): cale duplicată") }
                if let repo = file.repo, !["files", "pdfs", "scripts"].contains(repo) { out.append("\(product.id): repo necunoscut") }
            }
            for raw in [product.youtubeURL, product.purchaseURL, product.demoURL].compactMap({ $0 }) where !raw.isEmpty && URL(string: raw)?.scheme != "https" { out.append("\(product.id): URL non-https") }
        }
        return out
    }

    func testRealCatalogFollowsTheRules() throws {
        let catalog = try JSONDecoder().decode(Catalog.self, from: try realCatalogData())
        XCTAssertEqual(catalogProblems(catalog), [])
        if (catalog.items + catalog.scriptItems).isEmpty {
            throw XCTSkip("catalogul publicat nu are produse: regulile nu sunt exersate pe el; vezi testCatalogRulesHaveTeeth (fixture-uri cu defecte)")
        }
    }

    func testCatalogRulesHaveTeeth() throws {
        XCTAssertEqual(catalogProblems(try decode(#"{"items": [\#(item())]}"#)), [], "fixture-ul corect nu are probleme")
        let sha = String(repeating: "a", count: 64)
        let defects: [(String, String)] = [
            ("tip necunoscut", #"{"items": [\#(item(type: "tip-inventat"))]}"#),
            ("ID-uri duplicate", #"{"items": [\#(item(id: "dup")), \#(item(id: "dup"))]}"#),
            ("SHA-256 scurt", #"{"items": [\#(item().replacingOccurrences(of: sha, with: String(sha.dropLast())))]}"#),
            ("SHA-256 nehex", #"{"items": [\#(item().replacingOccurrences(of: sha, with: String(repeating: "Z", count: 64)))]}"#),
            ("cale nesigură", #"{"items": [\#(item().replacingOccurrences(of: "p1/1.0.0/a.dctl", with: "../a.dctl"))]}"#),
            ("fără fișiere", #"{"items": [\#(item().replacingOccurrences(of: #""files": [{"path": "p1/1.0.0/a.dctl", "sha256": "\#(sha)", "repo": "files"}]"#, with: #""files": []"#))]}"#),
            ("versiune invalidă", #"{"items": [\#(item().replacingOccurrences(of: #""version": "1.0.0""#, with: #""version": "v-ceva""#))]}"#),
            ("URL non-https", #"{"items": [\#(item(#", "demoURL": "http://exemplu.test/demo""#))]}"#),
        ]
        for (name, json) in defects {
            XCTAssertFalse(catalogProblems(try decode(json)).isEmpty, "verificarea nu a prins defectul: \(name)")
        }
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
