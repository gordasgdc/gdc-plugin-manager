import XCTest
@testable import GDCPluginManagerCore

/// Produse OFX GDC STYLE Lab V3: conformanța regulilor de slot cu vectorii referinței (copiați din STYLE Lab,
/// Engine/tests/vectors/ofx_install_identity.v1.json), validarea câmpului de catalog, planul de instalare și scanarea reală a discului.
final class OFXProductReleaseTests: XCTestCase {
    private var work: URL!
    override func setUpWithError() throws {
        work = FileManager.default.temporaryDirectory.appendingPathComponent("gdcpm-ofxproduct-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: work) }

    // MARK: - vectori de conformanță (aceiași ca STYLE Lab)

    private func pkg(_ o: [String: Any]) -> OFXIdentity.Package {
        OFXIdentity.Package(identifier: o["identifier"] as! String, folder: o["folder"] as! String, version: o["version"] as? String)
    }

    func testDecisionVectorsMatchReference() throws {
        let data = try Data(contentsOf: repoRoot.appendingPathComponent("Tests/GDCPluginManagerCoreTests/Fixtures/ofx_install_identity.v1.json"))
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(root["schema"] as? String, "gdc-ofx-install-identity-vectors@1")
        let vectors = try XCTUnwrap(root["vectors"] as? [[String: Any]])
        XCTAssertGreaterThanOrEqual(vectors.count, 51)
        for v in vectors {
            let name = v["name"] as! String
            let mode = OFXIdentity.Mode(rawValue: v["mode"] as! String)!
            let installed = (v["installed"] as! [[String: Any]]).map(pkg)
            let d = OFXIdentity.decide(incoming: pkg(v["incoming"] as! [String: Any]), installed: installed, mode: mode)
            let e = v["expect"] as! [String: Any]
            XCTAssertEqual(d.action.code, e["action"] as? String, name)
            XCTAssertEqual(d.write, e["write"] as? String, name)
            XCTAssertEqual(d.remove, e["remove"] as? [String] ?? [], name)
        }
        for r in try XCTUnwrap(root["removals"] as? [[String: Any]]) {
            let got = OFXIdentity.removal(generation: OFXIdentity.Generation(rawValue: r["generation"] as! String)!, product: r["product"] as! String,
                                          variants: r["variants"] as? [String], installed: (r["installed"] as! [[String: Any]]).map(pkg))
            XCTAssertEqual(got, r["expect"] as? [String], r["name"] as? String ?? "")
        }
    }

    // MARK: - model de catalog

    private func release(_ version: String = "1.1.0", product: String = "look") -> OFXProductRelease {
        let fams = [("ap1-acescct", "ACES"), ("dwg-davinci-intermediate", "DaVinci")]
        let pid = "gdc-style-v3-\(product)"
        let name = "GDC " + product.capitalized
        let variants = fams.map { (vid, fam) -> OFXProductRelease.Variant in
            func ed(_ e: String, _ suffix: String) -> OFXProductRelease.EditionPackage {
                let folder = "\(name) — \(fam)\(suffix).ofx.bundle"
                return .init(folder: folder, identifier: "dev.gordas.style.v3.\(product).\(vid).\(e)", root: "\(pid)/\(version)/\(e == "full" ? "Full" : "Demo")/\(folder)")
            }
            return .init(variantId: vid, family: fam, label: fam, slot: "dev.gordas.style.v3.\(product).\(vid)", editions: ["full": ed("full", ""), "demo": ed("demo", " (Demo)")])
        }
        return OFXProductRelease(productId: pid, instrument: product, version: version, variants: variants, placement: .init(orderKey: 232, stage: "log"))
    }

    func testValidationAcceptsCanonicalAndRejectsDivergence() {
        let r = release()
        XCTAssertNil(r.validate(itemID: "gdc-style-v3-look", itemVersion: "1.1.0"))
        XCTAssertNotNil(r.validate(itemID: "gdc-style-v3-film", itemVersion: "1.1.0"))
        XCTAssertNotNil(r.validate(itemID: "gdc-style-v3-look", itemVersion: "1.1.1"))
        // identificator al altei variante sub aceeași variantă
        var vs = r.variants
        let bad = OFXProductRelease.EditionPackage(folder: "X.ofx.bundle", identifier: "dev.gordas.style.v3.look.awg4-logc4.full", root: "gdc-style-v3-look/1.1.0/Full/X.ofx.bundle")
        vs[0] = .init(variantId: vs[0].variantId, family: vs[0].family, label: vs[0].label, slot: vs[0].slot, editions: ["full": bad])
        XCTAssertNotNil(OFXProductRelease(productId: r.productId, instrument: r.instrument, version: r.version, variants: vs, placement: nil).validate(itemID: r.productId, itemVersion: r.version))
        // folder cu cale (ar scrie în afara /Library/OFX/Plugins)
        let escape = OFXProductRelease.EditionPackage(folder: "../evil.ofx.bundle", identifier: "dev.gordas.style.v3.look.ap1-acescct.full", root: "gdc-style-v3-look/1.1.0/Full/../evil.ofx.bundle")
        vs = r.variants; vs[0] = .init(variantId: vs[0].variantId, family: vs[0].family, label: vs[0].label, slot: vs[0].slot, editions: ["full": escape])
        XCTAssertNotNil(OFXProductRelease(productId: r.productId, instrument: r.instrument, version: r.version, variants: vs, placement: nil).validate(itemID: r.productId, itemVersion: r.version))
    }

    func testDemoPathsAreOnlyDemoRoots() {
        let r = release()
        XCTAssertTrue(r.isDemoPath("gdc-style-v3-look/1.1.0/Demo/GDC Look — ACES (Demo).ofx.bundle/Contents/Info.plist"))
        XCTAssertFalse(r.isDemoPath("gdc-style-v3-look/1.1.0/Full/GDC Look — ACES.ofx.bundle/Contents/Info.plist"))
        XCTAssertFalse(r.isDemoPath("gdc-style-v3-look/1.1.0/Demo/../Full/GDC Look — ACES.ofx.bundle/x"))
    }

    func testCatalogRoundTripKeepsProductAndOldItemsDecode() throws {
        let item = PluginItem(id: "gdc-style-v3-look", name: "GDC Look", type: .ofx, description: "", version: "1.1.0", files: [], iconSymbol: nil, priceEUR: 23,
                              ofxProduct: release())
        let back = try JSONDecoder().decode(PluginItem.self, from: JSONEncoder().encode(item))
        XCTAssertEqual(back.ofxProduct, item.ofxProduct)
        let legacy = #"{"id":"x","name":"X","type":"ofx","description":"","version":"1.0.0","files":[],"priceEUR":0}"#
        XCTAssertNil(try JSONDecoder().decode(PluginItem.self, from: Data(legacy.utf8)).ofxProduct)
    }

    // MARK: - plan

    func testPlanEditionAndSlotRules() throws {
        let r = release()
        // nimic instalat, fără serial → Demo pe toate variantele
        XCTAssertEqual(OFXProductInstall.edition(hasSerial: false, r: r, installed: []), .demo)
        var plan = try OFXProductInstall.install(r, edition: .demo, installed: []).get()
        XCTAssertEqual(plan.writes.map(\.package.folder), ["GDC Look — ACES (Demo).ofx.bundle", "GDC Look — DaVinci (Demo).ofx.bundle"])
        // Demo instalat + serial → Full înlocuiește Demo în același slot
        let demo = r.variants.map { OFXIdentity.Package(identifier: $0.package(.demo)!.identifier, folder: $0.package(.demo)!.folder, version: "1.1.0") }
        XCTAssertEqual(OFXProductInstall.edition(hasSerial: true, r: r, installed: demo), .full)
        plan = try OFXProductInstall.install(r, edition: .full, installed: demo).get()
        XCTAssertEqual(plan.decisions.map(\.decision.action.code), ["replace", "replace"])
        XCTAssertEqual(plan.removals, demo.map(\.folder))
        // Full instalat, fără serial → rămâne Full (nicio degradare); Demo peste Full refuzat
        let full = r.variants.map { OFXIdentity.Package(identifier: $0.package(.full)!.identifier, folder: $0.package(.full)!.folder, version: "1.0.2") }
        XCTAssertEqual(OFXProductInstall.edition(hasSerial: false, r: r, installed: full), .full)
        XCTAssertEqual(try OFXProductInstall.install(r, edition: .demo, installed: full).get().refusals.count, 2)
        XCTAssertEqual(try OFXProductInstall.install(r, edition: .full, installed: full).get().decisions.map(\.decision.action.code), ["upgrade", "upgrade"])
        XCTAssertEqual(OFXProductInstall.installedVersion(r, installed: full), "1.0.2")
        // versiune mai veche din catalog → refuz (distribuția nu coboară versiunea)
        let newer = full.map { OFXIdentity.Package(identifier: $0.identifier, folder: $0.folder, version: "9.0.0") }
        XCTAssertEqual(try OFXProductInstall.install(r, edition: .full, installed: newer).get().refusals.count, 2)
        // subset + variantă necunoscută
        XCTAssertEqual(try OFXProductInstall.install(r, edition: .full, selection: .variants(["dwg-davinci-intermediate"]), installed: []).get().writes.count, 1)
        XCTAssertEqual(OFXProductInstall.install(r, edition: .full, selection: .variants(["nope"]), installed: []), .failure(.unknownVariant("nope")))
        // alte produse nu se ating la scoatere
        let other = OFXIdentity.Package(identifier: "dev.gordas.style.v3.film.ap1-acescct.full", folder: "GDC Film — ACES.ofx.bundle", version: "1.0.2")
        XCTAssertEqual(OFXProductInstall.removal(r, installed: full + [other]), full.map(\.folder).sorted())
    }

    // MARK: - scanare reală

    private func makeBundle(_ rel: String, id: String?, version: String) throws {
        let dir = work.appendingPathComponent(rel).appendingPathComponent("Contents")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var d: [String: Any] = ["CFBundleShortVersionString": version]
        if let id { d["CFBundleIdentifier"] = id }
        XCTAssertTrue((d as NSDictionary).write(to: dir.appendingPathComponent("Info.plist"), atomically: true))
    }

    func testScanReadsIdentityFromPlistNotFolderName() throws {
        try makeBundle("Renamed Old.ofx.bundle", id: "dev.gordas.style.v3.look.ap1-acescct.demo", version: "1.0.0")
        try makeBundle("GDC Release 1.0/GDC Look — DaVinci.ofx.bundle", id: "dev.gordas.style.v3.look.dwg-davinci-intermediate.full", version: "1.0.2")
        try makeBundle("Other Vendor.ofx.bundle", id: "com.other.plugin", version: "3.0")
        try makeBundle("No Id.ofx.bundle", id: nil, version: "1.0")
        let found = OFXIdentity.scanInstalled(root: work)
        XCTAssertEqual(found.map(\.folder), ["GDC Release 1.0/GDC Look — DaVinci.ofx.bundle", "Other Vendor.ofx.bundle", "Renamed Old.ofx.bundle"])
        let plan = try OFXProductInstall.install(release(), edition: .full, installed: found).get()
        XCTAssertEqual(plan.decisions.map(\.decision.action.code), ["replace", "replace"])
        XCTAssertEqual(Set(plan.removals), ["Renamed Old.ofx.bundle", "GDC Release 1.0/GDC Look — DaVinci.ofx.bundle"])
        XCTAssertFalse(plan.removals.contains("Other Vendor.ofx.bundle"))
    }
}
