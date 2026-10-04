import XCTest
@testable import GDCPluginManagerFurnizor
import GDCPluginManagerCore

/// Cap-coadă pe release-urile REALE generate de GDC STYLE Lab (`scripts/build_rc_releases.sh`): manifest → item de catalog (Furnizor) →
/// plan de instalare (Plugin Manager) aplicat pe un folder OFX temporar, cu fișierele copiate exact cum le-ar scrie instalatorul după descărcare.
/// Rulează doar cu `GDC_V3_RELEASES=<folderul cu „GDC <Nume> <versiune>”>` (altfel sărit — pachetele nu stau în acest repo).
final class StyleLabRealReleaseE2ETests: XCTestCase {
    private func releases() throws -> [URL] {
        guard let dir = ProcessInfo.processInfo.environment["GDC_V3_RELEASES"] else { throw XCTSkip("GDC_V3_RELEASES nesetat") }
        let all = try FileManager.default.contentsOfDirectory(at: URL(fileURLWithPath: dir), includingPropertiesForKeys: nil)
        return all.filter { FileManager.default.fileExists(atPath: $0.appendingPathComponent("manifest.json").path) }.sorted { $0.path < $1.path }
    }

    /// „Descarcă” (copiază din sursa release-ului) fișierele pachetelor de scris și aplică planul, ca InstallManager.installOFXProduct.
    private func apply(_ plan: OFXProductInstall.Plan, files: [(source: URL, repoPath: String)], root: URL) throws {
        for rel in plan.removals { try? FileManager.default.removeItem(at: root.appendingPathComponent(rel)) }
        for d in plan.writes {
            let dir = root.appendingPathComponent(d.package.folder)
            try? FileManager.default.removeItem(at: dir)
            let prefix = d.package.root + "/"
            for f in files where f.repoPath.hasPrefix(prefix) {
                let dst = dir.appendingPathComponent(String(f.repoPath.dropFirst(prefix.count)))
                try FileManager.default.createDirectory(at: dst.deletingLastPathComponent(), withIntermediateDirectories: true)
                try FileManager.default.copyItem(at: f.source, to: dst)
            }
        }
    }

    func testRealReleasesInstallDemoUpgradeFullRemove() throws {
        let rels = try releases()
        XCTAssertGreaterThanOrEqual(rels.count, 1)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("gdc-e2e-ofx-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        // un pachet străin și o copie veche redenumită a unui produs: primul nu se atinge, a doua se curăță
        let foreign = root.appendingPathComponent("Other Vendor.ofx.bundle/Contents")
        try FileManager.default.createDirectory(at: foreign, withIntermediateDirectories: true)
        XCTAssertTrue((["CFBundleIdentifier": "com.other.vendor", "CFBundleShortVersionString": "1.0"] as NSDictionary).write(to: foreign.appendingPathComponent("Info.plist"), atomically: true))

        var prepared: [(StyleLabProductPublisher.Prepared, PluginItem)] = []
        for r in rels {
            let p = try StyleLabProductPublisher.prepare(manifest: Data(contentsOf: r.appendingPathComponent("manifest.json")), releaseFolder: r)
            let item = StyleLabProductPublisher.item(p, files: p.files.map { PluginFile(path: $0.repoPath, sha256: "x", repo: "files") }, existing: nil, description: "", defaultDonationEUR: 23)
            XCTAssertNil(item.ofxProduct?.validate(itemID: item.id, itemVersion: item.version), item.id)
            XCTAssertFalse(item.isFree)
            // catalogul se codează/decodează fără pierderi (ce vede clientul)
            let back = try JSONDecoder().decode(PluginItem.self, from: JSONEncoder().encode(item))
            XCTAssertEqual(back.ofxProduct, item.ofxProduct)
            // toate fișierele Demo sunt gratuite, niciunul Full
            for f in p.files { XCTAssertEqual(item.ofxProduct!.isDemoPath(f.repoPath), f.repoPath.contains("/Demo/"), f.repoPath) }
            prepared.append((p, item))
        }
        // copie veche redenumită (Full) a primului produs, cu versiune mai mică — trebuie înlocuită, nu dublată
        if let first = prepared.first, let v0 = first.1.ofxProduct?.variants.first, let full = v0.package(.full) {
            let old = root.appendingPathComponent("Old Renamed.ofx.bundle/Contents")
            try FileManager.default.createDirectory(at: old, withIntermediateDirectories: true)
            XCTAssertTrue((["CFBundleIdentifier": full.identifier, "CFBundleShortVersionString": "0.9.0"] as NSDictionary).write(to: old.appendingPathComponent("Info.plist"), atomically: true))
        }

        for (p, item) in prepared {
            let r = item.ofxProduct!
            // 1) client fără serial → Demo pe toate variantele (sau Full, dacă există deja un Full: niciodată degradare)
            var installed = OFXIdentity.scanInstalled(root: root)
            let ed = OFXProductInstall.edition(hasSerial: false, r: r, installed: installed)
            let already = OFXProductInstall.installedVariants(r, installed: installed)
            var plan = try OFXProductInstall.install(r, edition: ed, selection: already.isEmpty ? .all : .variants(already), installed: installed).get()
            try apply(plan, files: p.files, root: root)
            // 2) serial primit → Full pe aceleași sloturi, Demo înlocuit
            installed = OFXIdentity.scanInstalled(root: root)
            plan = try OFXProductInstall.install(r, edition: .full, installed: installed).get()
            XCTAssertTrue(plan.refusals.isEmpty, item.id)
            try apply(plan, files: p.files, root: root)
            // 3) un singur ocupant per slot, ediția Full, versiunea produsului, identitate = manifest
            installed = OFXIdentity.scanInstalled(root: root)
            let mine = installed.filter { OFXIdentity.parse($0.identifier).product == r.instrument && OFXIdentity.parse($0.identifier).generation == .v3 }
            XCTAssertEqual(mine.count, r.variants.count, item.id)
            XCTAssertEqual(Set(mine.map { OFXIdentity.parse($0.identifier).slot }), Set(r.variants.map(\.slot)), item.id)
            XCTAssertTrue(mine.allSatisfy { OFXIdentity.parse($0.identifier).edition == .full && $0.version == r.version }, item.id)
            XCTAssertEqual(Set(mine.map(\.folder)), Set(r.variants.compactMap { $0.package(.full)?.folder }), item.id)
            // 4) Demo peste Full = refuz, nimic de scris
            XCTAssertEqual(try OFXProductInstall.install(r, edition: .demo, installed: installed).get().writes.count, 0, item.id)
            // 5) reinstalare identică = keep
            XCTAssertTrue(try OFXProductInstall.install(r, edition: .full, installed: installed).get().isNoop, item.id)
        }
        // 6) scoaterea fiecărui produs atinge doar sloturile lui; pachetul străin rămâne
        for (_, item) in prepared {
            for rel in OFXProductInstall.removal(item.ofxProduct!, installed: OFXIdentity.scanInstalled(root: root)) { try FileManager.default.removeItem(at: root.appendingPathComponent(rel)) }
        }
        XCTAssertEqual(OFXIdentity.scanInstalled(root: root).map(\.identifier), ["com.other.vendor"])
    }
}
