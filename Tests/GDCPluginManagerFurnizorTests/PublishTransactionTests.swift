import XCTest
import CryptoKit
@testable import GDCPluginManagerFurnizor
import GDCPluginManagerCore

/// D2b: publicări pe mai multe repo-uri, pe servere git locale (bare) sub `RepoCheckoutPaths.testRoot`.
/// Structura e cea reală: `_gdc-publish/gdc-plugin-manager` (catalog) + `gdc-plugin-manager-files`.
final class PublishTransactionTests: XCTestCase {
    private var root: URL!
    private var catalogServer: URL { root.appendingPathComponent("server/gordasgdc/gdc-plugin-manager.git") }
    private var filesServer: URL { root.appendingPathComponent("server/gordasgdc/gdc-plugin-manager-files.git") }
    private var catalogCheckout: URL { RepoCheckoutPaths.publicCatalogRepo }
    private var filesCheckout: URL { RepoCheckoutPaths.privateFilesRepo }

    // MARK: - mediu

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("d2b-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        RepoCheckoutPaths.testRoot = root
        PublishJournal.directory = root.appendingPathComponent("journal")

        // Repo privat: produsul „prod-a” cu două versiuni.
        try makeServer(filesServer, seed: [
            "prod-a/1.0.0/x.cube": "LUT x",
            "prod-a/0.9.0/old.cube": "LUT vechi",
        ])
        // Catalog: „prod-a” (1.0.0) + o resursă care refolosește fișierul prod-a/1.0.0/x.cube.
        try makeServer(catalogServer, seed: ["docs/catalog.json": try seedCatalog(), "Sources/App.swift": "// cod"])
        try git("clone", "--branch", "main", catalogServer.path, catalogCheckout.path, at: root)
        try git("clone", "--branch", "main", filesServer.path, filesCheckout.path, at: root)
    }

    override func tearDownWithError() throws {
        RepoCheckoutPaths.testRoot = nil
        try? FileManager.default.removeItem(at: root)
    }

    @discardableResult
    private func git(_ args: String..., at dir: URL) throws -> String {
        try GitOps.run(["-c", "user.name=Test", "-c", "user.email=test@example.com"] + args, at: dir)
    }

    private func makeServer(_ server: URL, seed: [String: String]) throws {
        try FileManager.default.createDirectory(at: server, withIntermediateDirectories: true)
        try git("init", "--bare", "--initial-branch=main", at: server)
        let seedDir = root.appendingPathComponent("seed-\(UUID().uuidString)")
        try git("clone", server.path, seedDir.path, at: root)
        try git("checkout", "-B", "main", at: seedDir)
        for (path, text) in seed { try write(path, text, in: seedDir) }
        try git("add", "-A", at: seedDir)
        try git("commit", "-m", "seed", at: seedDir)
        try git("push", "origin", "main", at: seedDir)
    }

    private func write(_ rel: String, _ text: String, in dir: URL) throws {
        let url = dir.appendingPathComponent(rel)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    private func sha(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    /// Șabloanele vin din catalogul real (docs/catalog.json al repo-ului), ca decodarea să fie cea reală.
    private func realCatalog() throws -> [String: Any] {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("docs/catalog.json")
        return try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
    }

    private func itemJSON(id: String, version: String, files: [(String, String)]) throws -> [String: Any] {
        var item = (try realCatalog()["items"] as! [[String: Any]])[0]
        item["id"] = id; item["name"] = "Test \(id)"; item["version"] = version
        item["type"] = "lut"
        item.removeValue(forKey: "coverImage"); item.removeValue(forKey: "bundleFolderName")
        item["files"] = files.map { ["path": $0.0, "sha256": $0.1, "repo": "files"] }
        return item
    }

    private func seedCatalog() throws -> String {
        var cat = try realCatalog()
        cat["items"] = [try itemJSON(id: "prod-a", version: "1.0.0", files: [("prod-a/1.0.0/x.cube", sha("LUT x"))])]
        var res = (cat["downloadableResources"] as! [[String: Any]])[0]
        res["id"] = "res-r"; res["name"] = "Resursa R"
        res.removeValue(forKey: "coverImage"); res.removeValue(forKey: "filePath"); res.removeValue(forKey: "fileSHA256")
        res["fileRepo"] = "files"
        res["files"] = [["path": "prod-a/1.0.0/x.cube", "sha256": sha("LUT x"), "repo": "files"]]
        cat["downloadableResources"] = [res]
        let data = try JSONSerialization.data(withJSONObject: cat, options: [.prettyPrinted, .sortedKeys])
        return String(decoding: data, as: UTF8.self)
    }

    private func pluginItem(id: String, version: String, files: [PublishTransaction.FileRef]) throws -> PluginItem {
        let json = try itemJSON(id: id, version: version, files: files.map { ($0.path, $0.sha256) })
        return try JSONDecoder().decode(PluginItem.self, from: JSONSerialization.data(withJSONObject: json))
    }

    private func head(_ dir: URL) throws -> String {
        try git("rev-parse", "main", at: dir).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func serverHasFile(_ path: String) throws -> Bool {
        (try? git("cat-file", "-e", "main:\(path)", at: filesServer)) != nil
    }

    private func serverCatalogIDs() throws -> Set<String> {
        let text = try git("show", "main:docs/catalog.json", at: catalogServer)
        let root = try JSONSerialization.jsonObject(with: Data(text.utf8)) as! [String: Any]
        var ids = Set<String>()
        for case let array as [[String: Any]] in root.values { for o in array { if let id = o["id"] as? String { ids.insert(id) } } }
        return ids
    }

    /// „Alt Mac” publică între timp în repo-ul dat.
    private func concurrentPush(to server: URL, path: String, text: String) throws {
        let other = root.appendingPathComponent("other-\(UUID().uuidString)")
        try git("clone", "--branch", "main", server.path, other.path, at: root)
        try write(path, text, in: other)
        try git("add", "-A", at: other)
        try git("commit", "-m", "publicare concurentă", at: other)
        try git("push", "origin", "main", at: other)
    }

    private func newProductSource(_ text: String, id: String = "prod-b") throws -> (URL, PublishTransaction.FileRef) {
        let local = root.appendingPathComponent("local/\(id).cube")
        try write("local/\(id).cube", text, in: root)
        return (local, .init(repoKey: "files", path: "\(id)/1.0.0/\(id).cube", sha256: sha(text)))
    }

    private func publishProduct(_ source: (URL, PublishTransaction.FileRef), id: String = "prod-b") throws {
        let item = try pluginItem(id: id, version: "1.0.0", files: [source.1])
        try PublishTransaction.publish(label: "\(id) 1.0.0", sources: [source], files: [source.1], catalog: .upsertItems([item]),
                                       catalogMessage: "Catalog: \(id)", catalogPaths: ["docs/catalog.json", "docs/covers"])
    }

    // MARK: - scenarii

    func testPublishPushesFilesVerifiesThenCatalog() throws {
        try PublishTransaction.preflight(repoKeys: ["files"])
        try publishProduct(try newProductSource("LUT b"))
        XCTAssertTrue(try serverHasFile("prod-b/1.0.0/prod-b.cube"))
        XCTAssertTrue(try serverCatalogIDs().contains("prod-b"))
        XCTAssertTrue(PublishJournal.pending().isEmpty, "operație încheiată → jurnal gol")
    }

    func testPreflightFailureWritesNothing() throws {
        try git("checkout", "-b", "lucru", at: filesCheckout)   // repo-ul privat pe ramura greșită
        let (catalogBefore, filesBefore) = (try head(catalogServer), try head(filesServer))
        XCTAssertThrowsError(try PublishTransaction.preflight(repoKeys: ["files"]))
        XCTAssertEqual(try head(catalogServer), catalogBefore)
        XCTAssertEqual(try head(filesServer), filesBefore)
        XCTAssertTrue(PublishJournal.pending().isEmpty)
        XCTAssertEqual(try git("status", "--porcelain", at: catalogCheckout), "", "nicio scriere în catalog")
    }

    func testSecondPushRejectedLeavesSafeStateAndResumeCompletes() throws {
        try PublishTransaction.preflight(repoKeys: ["files"])
        try concurrentPush(to: catalogServer, path: "docs/alt.txt", text: "publicat de pe alt Mac")   // după preflight
        let source = try newProductSource("LUT b")
        XCTAssertThrowsError(try publishProduct(source)) { XCTAssertTrue($0 is PublishTransaction.IncompleteError) }

        // Stare sigură: fișierul e pe server, catalogul de pe server NU îl referă.
        XCTAssertTrue(try serverHasFile("prod-b/1.0.0/prod-b.cube"))
        XCTAssertFalse(try serverCatalogIDs().contains("prod-b"))
        let pending = PublishJournal.pending()
        XCTAssertEqual(pending.count, 1)
        XCTAssertEqual(pending[0].completed, [.filesPushed, .filesVerified])
        XCTAssertEqual(try git("rev-list", "--count", "origin/main..main", at: catalogCheckout).trimmingCharacters(in: .whitespacesAndNewlines), "0",
                       "commit-ul respins e desfăcut local → reluarea nu găsește istorie divergentă")

        try PublishTransaction.resume(pending[0])
        XCTAssertTrue(try serverCatalogIDs().contains("prod-b"))
        XCTAssertNoThrow(try git("cat-file", "-e", "main:docs/alt.txt", at: catalogServer), "publicarea concurentă e păstrată")
        XCTAssertTrue(PublishJournal.pending().isEmpty)
    }

    func testFileMismatchStopsBeforeCatalogAndCleanupRemovesOnlyOrphans() throws {
        try PublishTransaction.preflight(repoKeys: ["files"])
        let (local, good) = try newProductSource("LUT b")
        let wrong = PublishTransaction.FileRef(repoKey: good.repoKey, path: good.path, sha256: sha("alt conținut"))
        let shared = PublishTransaction.FileRef(repoKey: "files", path: "prod-a/1.0.0/x.cube", sha256: sha("LUT x"))
        let item = try pluginItem(id: "prod-b", version: "1.0.0", files: [wrong])
        XCTAssertThrowsError(try PublishTransaction.publish(label: "prod-b 1.0.0", sources: [(local, wrong)], files: [wrong, shared],
                                                            catalog: .upsertItems([item]), catalogMessage: "Catalog: prod-b",
                                                            catalogPaths: ["docs/catalog.json"]))
        XCTAssertFalse(try serverCatalogIDs().contains("prod-b"), "catalogul nu a fost atins")
        let record = try XCTUnwrap(PublishJournal.pending().first)
        XCTAssertEqual(record.completed, [.filesPushed])

        XCTAssertEqual(try PublishTransaction.cleanupOrphans(record), 1)
        XCTAssertFalse(try serverHasFile("prod-b/1.0.0/prod-b.cube"), "orfanul e șters")
        XCTAssertTrue(try serverHasFile("prod-a/1.0.0/x.cube"), "fișierul încă referit rămâne")
        XCTAssertTrue(PublishJournal.pending().isEmpty)
    }

    func testDeleteRemovesCatalogFirstAndKeepsSharedFiles() throws {
        try PublishTransaction.preflight(repoKeys: ["files"])
        try PublishTransaction.delete(label: "Sterg prod-a", folders: [.init(repoKey: "files", folder: "prod-a/")],
                                      catalog: .removeItems(ids: ["prod-a"], covers: ["prod-a": nil]),
                                      catalogMessage: "Sterg din catalog: prod-a", catalogPaths: ["docs/catalog.json", "docs/covers"],
                                      expectedDeletions: [])
        XCTAssertFalse(try serverCatalogIDs().contains("prod-a"))
        XCTAssertTrue(try serverHasFile("prod-a/1.0.0/x.cube"), "referit de resursa R → rămâne")
        XCTAssertFalse(try serverHasFile("prod-a/0.9.0/old.cube"), "versiunea veche, nereferită → ștearsă")
        XCTAssertTrue(PublishJournal.pending().isEmpty)
    }

    func testPartialDeleteIsSafeAndResumeRemovesFiles() throws {
        try PublishTransaction.preflight(repoKeys: ["files"])
        try concurrentPush(to: filesServer, path: "prod-c/1.0.0/c.cube", text: "alt produs")   // push-ul de fișiere va fi respins
        XCTAssertThrowsError(try PublishTransaction.delete(
            label: "Sterg prod-a", folders: [.init(repoKey: "files", folder: "prod-a/")],
            catalog: .removeItems(ids: ["prod-a"], covers: ["prod-a": nil]), catalogMessage: "Sterg din catalog: prod-a",
            catalogPaths: ["docs/catalog.json", "docs/covers"], expectedDeletions: []))
        // Stare sigură: produsul nu mai e în catalog; fișierele lui sunt încă pe server (orfane, invizibile).
        XCTAssertFalse(try serverCatalogIDs().contains("prod-a"))
        XCTAssertTrue(try serverHasFile("prod-a/0.9.0/old.cube"))
        let record = try XCTUnwrap(PublishJournal.pending().first)
        XCTAssertEqual(record.completed, [.catalogPushed, .catalogVerified])

        try PublishTransaction.resume(record)
        XCTAssertFalse(try serverHasFile("prod-a/0.9.0/old.cube"))
        XCTAssertTrue(try serverHasFile("prod-a/1.0.0/x.cube"), "fișierul partajat rămâne și după reluare")
        XCTAssertTrue(try serverHasFile("prod-c/1.0.0/c.cube"), "publicarea concurentă e păstrată")
        XCTAssertTrue(PublishJournal.pending().isEmpty)
    }

    func testResumeIsIdempotentAfterCompletion() throws {
        try PublishTransaction.preflight(repoKeys: ["files"])
        try concurrentPush(to: catalogServer, path: "docs/alt.txt", text: "x")
        XCTAssertThrowsError(try publishProduct(try newProductSource("LUT b")))
        let record = try XCTUnwrap(PublishJournal.pending().first)
        try PublishTransaction.resume(record)
        let heads = (try head(catalogServer), try head(filesServer))
        try PublishTransaction.resume(record)   // a doua reluare (ex. dublu-click): nimic nou
        XCTAssertEqual(try head(catalogServer), heads.0)
        XCTAssertEqual(try head(filesServer), heads.1)
    }

    func testJournalHoldsNoSecrets() throws {
        try PublishTransaction.preflight(repoKeys: ["files"])
        try concurrentPush(to: catalogServer, path: "docs/alt.txt", text: "x")
        XCTAssertThrowsError(try publishProduct(try newProductSource("LUT b")))
        let files = try FileManager.default.contentsOfDirectory(at: PublishJournal.directory, includingPropertiesForKeys: nil)
        let text = try files.map { try String(contentsOf: $0, encoding: .utf8) }.joined()
        XCTAssertFalse(text.contains(PrivateCatalogAuth.token), "jurnalul nu conține tokenul")
        XCTAssertNil(text.range(of: #"github_pat_|ghp_|x-access-token"#, options: .regularExpression))
    }
}
