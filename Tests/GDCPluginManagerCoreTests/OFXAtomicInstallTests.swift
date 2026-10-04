import XCTest
@testable import GDCPluginManagerCore

/// Scriptul de instalare atomică rulat REAL cu /bin/sh pe un folder temporar (fără administrator): instalare, înlocuire, refuz fără efect, rollback,
/// pachete străine neatinse, rădăcina neschimbată (proprietar / drepturi), fără resturi temporare.
final class OFXAtomicInstallTests: XCTestCase {
    var base: URL!
    var root: URL { base.appendingPathComponent("Plugins") }
    var stage: URL { base.appendingPathComponent("stage") }
    let fm = FileManager.default

    override func setUpWithError() throws {
        base = fm.temporaryDirectory.appendingPathComponent("ofx-atomic-\(UUID().uuidString)")
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        try fm.createDirectory(at: stage, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try? fm.removeItem(at: base) }

    @discardableResult
    func makeBundle(_ dir: URL, id: String, version: String, payload: String) throws -> URL {
        try fm.createDirectory(at: dir.appendingPathComponent("Contents/MacOS"), withIntermediateDirectories: true)
        let plist: [String: Any] = ["CFBundleIdentifier": id, "CFBundleShortVersionString": version]
        try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0).write(to: dir.appendingPathComponent("Contents/Info.plist"))
        try Data(payload.utf8).write(to: dir.appendingPathComponent("Contents/MacOS/plugin"))
        return dir
    }
    func write(_ folder: String, id: String, version: String, payload: String) throws -> OFXAtomicInstall.Write {
        let d = try makeBundle(stage.appendingPathComponent(folder), id: id, version: version, payload: payload)
        return .init(staged: d.path, folder: folder, identifier: id, version: version, treeSHA: try OFXAtomicInstall.treeHash(d.path))
    }
    func run(_ script: String) -> Int32 {
        let p = Process(); p.executableURL = URL(fileURLWithPath: "/bin/sh"); p.arguments = ["-c", script]; p.standardError = Pipe()
        try? p.run(); p.waitUntilExit(); return p.terminationStatus
    }
    func payload(_ folder: String) -> String? { (try? String(contentsOf: root.appendingPathComponent(folder + "/Contents/MacOS/plugin"), encoding: .utf8)) }
    func leftovers() -> [String] { ((try? fm.contentsOfDirectory(atPath: root.path)) ?? []).filter { $0.hasPrefix(".gdc-") } }
    func snapshot() -> [String: String] {
        var m: [String: String] = [:]
        if let en = fm.enumerator(atPath: root.path) { for case let rel as String in en { let p = root.appendingPathComponent(rel).path
            var isDir: ObjCBool = false; fm.fileExists(atPath: p, isDirectory: &isDir); m[rel] = isDir.boolValue ? "dir" : ((try? String(contentsOfFile: p, encoding: .utf8)) ?? "?") } }
        return m
    }

    func testShellTreeHashMatchesSwift() throws {
        let d = try makeBundle(stage.appendingPathComponent("A.ofx.bundle"), id: "dev.gordas.style.v3.look.aces.full", version: "1.1.0", payload: "x")
        try Data("z".utf8).write(to: d.appendingPathComponent("Contents/Resources ă b.txt"))
        let p = Process(); p.executableURL = URL(fileURLWithPath: "/bin/sh")
        p.arguments = ["-c", "cd \"$1\" && LC_ALL=C find . -type f -print0 | LC_ALL=C sort -z | xargs -0 /usr/bin/shasum -a 256 | /usr/bin/shasum -a 256 | cut -d' ' -f1", "sh", d.path]
        let out = Pipe(); p.standardOutput = out; try p.run(); p.waitUntilExit()
        let shell = String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)!.trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertEqual(shell, try OFXAtomicInstall.treeHash(d.path))
    }

    func testInstallReplaceAndForeignUntouched() throws {
        try makeBundle(root.appendingPathComponent("GDC Look — ACES.ofx.bundle"), id: "dev.gordas.style.v3.look.aces.demo", version: "1.0.2", payload: "old")
        try makeBundle(root.appendingPathComponent("Other Vendor.ofx.bundle"), id: "com.vendor.plugin", version: "9.0", payload: "foreign")
        let rootAttrs = try fm.attributesOfItem(atPath: root.path)
        let w1 = try write("GDC Look — ACES.ofx.bundle", id: "dev.gordas.style.v3.look.aces.full", version: "1.1.0", payload: "new-aces")
        let w2 = try write("GDC Look — LogC4.ofx.bundle", id: "dev.gordas.style.v3.look.logc4.full", version: "1.1.0", payload: "new-logc4")
        let s = try XCTUnwrap(OFXAtomicInstall.script(root: root.path, writes: [w1, w2], removals: [], token: "t1"))
        XCTAssertEqual(run(s), 0)
        XCTAssertEqual(payload("GDC Look — ACES.ofx.bundle"), "new-aces")
        XCTAssertEqual(payload("GDC Look — LogC4.ofx.bundle"), "new-logc4")
        XCTAssertEqual(payload("Other Vendor.ofx.bundle"), "foreign", "pachetul altui producător nu se atinge")
        XCTAssertEqual(leftovers(), [])
        let after = try fm.attributesOfItem(atPath: root.path)
        XCTAssertEqual(after[.posixPermissions] as? Int, rootAttrs[.posixPermissions] as? Int, "drepturile folderului de pluginuri nu se schimbă")
        XCTAssertEqual(after[.ownerAccountID] as? Int, rootAttrs[.ownerAccountID] as? Int, "proprietarul folderului de pluginuri nu se schimbă")
        let mode = try fm.attributesOfItem(atPath: root.appendingPathComponent("GDC Look — ACES.ofx.bundle/Contents/MacOS/plugin").path)[.posixPermissions] as? Int
        XCTAssertEqual(mode, 0o644)
    }

    func testTamperedStageChangesNothing() throws {
        try makeBundle(root.appendingPathComponent("GDC Film — ACES.ofx.bundle"), id: "dev.gordas.style.v3.film.aces.full", version: "1.0.2", payload: "old")
        let before = snapshot()
        let w = try write("GDC Film — ACES.ofx.bundle", id: "dev.gordas.style.v3.film.aces.full", version: "1.1.0", payload: "new")
        try Data("evil".utf8).write(to: URL(fileURLWithPath: w.staged).appendingPathComponent("Contents/MacOS/plugin"))   // schimbat după verificare
        let s = try XCTUnwrap(OFXAtomicInstall.script(root: root.path, writes: [w], removals: [], token: "t2"))
        XCTAssertEqual(run(s), 3)
        XCTAssertEqual(snapshot(), before, "refuz înainte de orice schimbare")
        XCTAssertEqual(leftovers(), [])
    }

    func testWrongIdentityRefusedBeforeChange() throws {
        let before = snapshot()
        let d = try makeBundle(stage.appendingPathComponent("X.ofx.bundle"), id: "dev.gordas.style.v3.skin.aces.full", version: "1.0.2", payload: "p")
        let w = OFXAtomicInstall.Write(staged: d.path, folder: "X.ofx.bundle", identifier: "dev.gordas.style.v3.look.aces.full", version: "1.0.2", treeSHA: try OFXAtomicInstall.treeHash(d.path))
        XCTAssertEqual(run(try XCTUnwrap(OFXAtomicInstall.script(root: root.path, writes: [w], removals: [], token: "t3"))), 3)
        XCTAssertEqual(snapshot(), before)
    }

    func testRollbackRestoresEverything() throws {
        try makeBundle(root.appendingPathComponent("GDC Color — ACES.ofx.bundle"), id: "dev.gordas.style.v3.color.aces.demo", version: "1.0.2", payload: "old-color")
        try makeBundle(root.appendingPathComponent("GDC Color — ACES copy.ofx.bundle"), id: "dev.gordas.style.v3.color.aces.demo", version: "1.0.1", payload: "dup")
        try makeBundle(root.appendingPathComponent("Vendor.ofx.bundle"), id: "com.vendor.x", version: "1", payload: "foreign")
        let before = snapshot()
        let w = try write("GDC Color — ACES.ofx.bundle", id: "dev.gordas.style.v3.color.aces.full", version: "1.0.2", payload: "full")
        // a doua ștergere vizează un pachet STRĂIN ⇒ refuz la aplicare ⇒ tot ce s-a mutat revine
        let s = try XCTUnwrap(OFXAtomicInstall.script(root: root.path, writes: [w], removals: ["GDC Color — ACES copy.ofx.bundle", "Vendor.ofx.bundle"], token: "t4"))
        XCTAssertEqual(run(s), 4)
        XCTAssertEqual(snapshot(), before, "rollback complet: pachetul vechi, dublura și pachetul străin exact ca înainte")
        XCTAssertEqual(leftovers(), [])
    }

    func testRemovalsAndDemoToFull() throws {
        try makeBundle(root.appendingPathComponent("GDC Skin — ACES.ofx.bundle"), id: "dev.gordas.style.v3.skin.aces.demo", version: "1.0.2", payload: "demo")
        try fm.createDirectory(at: root.appendingPathComponent("GDC Skin 1.0.2/Full"), withIntermediateDirectories: true)
        try makeBundle(root.appendingPathComponent("GDC Skin 1.0.2/Full/GDC Skin — ACES.ofx.bundle"), id: "dev.gordas.style.v3.skin.aces.full", version: "1.0.2", payload: "nested")
        let w = try write("GDC Skin — ACES.ofx.bundle", id: "dev.gordas.style.v3.skin.aces.full", version: "1.0.2", payload: "full")
        let s = try XCTUnwrap(OFXAtomicInstall.script(root: root.path, writes: [w], removals: ["GDC Skin 1.0.2/Full/GDC Skin — ACES.ofx.bundle"], token: "t5"))
        XCTAssertEqual(run(s), 0)
        XCTAssertEqual(payload("GDC Skin — ACES.ofx.bundle"), "full")
        XCTAssertFalse(fm.fileExists(atPath: root.appendingPathComponent("GDC Skin 1.0.2/Full/GDC Skin — ACES.ofx.bundle").path))
        XCTAssertEqual(leftovers(), [])
    }

    func testSymlinkInRemovalPathRollsBack() throws {
        let outside = base.appendingPathComponent("outside"); try fm.createDirectory(at: outside, withIntermediateDirectories: true)
        try makeBundle(outside.appendingPathComponent("B.ofx.bundle"), id: "dev.gordas.style.v3.look.aces.full", version: "1", payload: "outside")
        try fm.createSymbolicLink(at: root.appendingPathComponent("link"), withDestinationURL: outside)
        let w = try write("N.ofx.bundle", id: "dev.gordas.style.v3.look.aces.full", version: "1.1.0", payload: "n")
        let s = try XCTUnwrap(OFXAtomicInstall.script(root: root.path, writes: [w], removals: ["link/B.ofx.bundle"], token: "t6"))
        XCTAssertEqual(run(s), 4)
        XCTAssertTrue(fm.fileExists(atPath: outside.appendingPathComponent("B.ofx.bundle/Contents/Info.plist").path), "nimic din afara rădăcinii nu se atinge")
        XCTAssertFalse(fm.fileExists(atPath: root.appendingPathComponent("N.ofx.bundle").path), "rollback: pachetul nou scos")
    }

    func testPlanValidation() {
        let ok = OFXAtomicInstall.Write(staged: "/tmp/s/A.ofx.bundle", folder: "A.ofx.bundle", identifier: "", version: "", treeSHA: String(repeating: "a", count: 64))
        XCTAssertNil(OFXAtomicInstall.violation(root: "/Library/OFX/Plugins", writes: [ok], removals: [], token: "abc"))
        for bad in ["../A.ofx.bundle", "x/A.ofx.bundle", "A", ".", "A.ofx.bundle/.."] {
            let w = OFXAtomicInstall.Write(staged: ok.staged, folder: bad, identifier: "", version: "", treeSHA: ok.treeSHA)
            XCTAssertNotNil(OFXAtomicInstall.violation(root: "/Library/OFX/Plugins", writes: [w], removals: [], token: "abc"), bad)
        }
        XCTAssertNotNil(OFXAtomicInstall.violation(root: "/Library/OFX/Plugins", writes: [ok], removals: ["../etc.ofx.bundle"], token: "abc"))
        XCTAssertNotNil(OFXAtomicInstall.violation(root: "/Library/OFX/Plugins", writes: [ok], removals: ["Some Folder"], token: "abc"), "doar pachete .ofx.bundle se scot")
        XCTAssertNotNil(OFXAtomicInstall.violation(root: "/Library/OFX/Plugins", writes: [ok, ok], removals: [], token: "abc"), "destinație dublă")
        XCTAssertNotNil(OFXAtomicInstall.violation(root: "/Library/OFX/Plugins", writes: [ok], removals: ["A.ofx.bundle"], token: "abc"))
        XCTAssertNotNil(OFXAtomicInstall.violation(root: "/Library/OFX/Plugins", writes: [ok], removals: [], token: "A;rm"))
        XCTAssertNil(OFXAtomicInstall.script(root: "relative", writes: [ok], removals: [], token: "abc"))
    }

    func testNoChownOfPluginsRootAnywhereInScript() {
        XCTAssertFalse(OFXAtomicInstall.program.contains("chown -R root:wheel \"$ROOT\""))
        XCTAssertFalse(OFXAtomicInstall.program.contains("chmod -R 755 \"$ROOT\""))
    }
}
