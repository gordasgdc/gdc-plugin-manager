import XCTest
import CryptoKit
@testable import GDCPluginManagerFurnizor
import GDCPluginManagerCore

/// 1.52.4: staging și producția nu se pot amesteca — nici la publicare, ștergere, reluare sau curățare,
/// nici la scrierile către servicii (Supabase, secrete, registrul de vânzări).
final class EnvironmentSeparationTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("env-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        RepoCheckoutPaths.testRoot = root
        PublishJournal.directory = root.appendingPathComponent("journal")
    }

    override func tearDownWithError() throws {
        FurnizorEnvironment.override = nil
        RepoCheckoutPaths.testRoot = nil
        PublishJournal.directoryOverride = nil
        try? FileManager.default.removeItem(at: root)
    }

    @discardableResult
    private func git(_ args: String..., at dir: URL) throws -> String {
        try GitOps.run(["-c", "user.name=Test", "-c", "user.email=test@example.com"] + args, at: dir)
    }

    private func sha(_ text: String) -> String { SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined() }

    /// Server bare `server/gordasgdc/<name>.git` + clonă în `checkout`.
    @discardableResult
    private func makeRepo(serverName: String, checkout: URL, seed: [String: String]) throws -> URL {
        let server = root.appendingPathComponent("server/gordasgdc/\(serverName).git")
        try FileManager.default.createDirectory(at: server, withIntermediateDirectories: true)
        try git("init", "--bare", "--initial-branch=main", at: server)
        let seedDir = root.appendingPathComponent("seed-\(UUID().uuidString)")
        try git("clone", server.path, seedDir.path, at: root)
        try git("checkout", "-B", "main", at: seedDir)
        for (path, text) in seed {
            let url = seedDir.appendingPathComponent(path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try text.write(to: url, atomically: true, encoding: .utf8)
        }
        try git("add", "-A", at: seedDir); try git("commit", "-m", "seed", at: seedDir); try git("push", "origin", "main", at: seedDir)
        try FileManager.default.createDirectory(at: checkout.deletingLastPathComponent(), withIntermediateDirectories: true)
        try git("clone", "--branch", "main", server.path, checkout.path, at: root)
        return server
    }

    private func realCatalogText() throws -> String {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("docs/catalog.json")
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func item(_ id: String, file: PublishTransaction.FileRef) throws -> PluginItem {
        var obj = (try JSONSerialization.jsonObject(with: Data(try realCatalogText().utf8)) as! [String: Any])["items"] as! [[String: Any]]
        var o = obj.removeFirst()
        o["id"] = id; o["name"] = id; o["version"] = "0.0.1"; o["type"] = "lut"
        o.removeValue(forKey: "coverImage"); o.removeValue(forKey: "bundleFolderName")
        o["files"] = [["path": file.path, "sha256": file.sha256, "repo": file.repoKey]]
        return try JSONDecoder().decode(PluginItem.self, from: JSONSerialization.data(withJSONObject: o))
    }

    private func head(_ server: URL) throws -> String { try git("rev-parse", "main", at: server).trimmingCharacters(in: .whitespacesAndNewlines) }

    // MARK: - activare și căi

    func testStagingOnlyByExplicitValueAndUnknownValuesFailClosed() {
        XCTAssertEqual(FurnizorEnvironment.resolve(nil), .production)
        XCTAssertEqual(FurnizorEnvironment.resolve(""), .production)
        XCTAssertEqual(FurnizorEnvironment.resolve("production"), .production)
        XCTAssertEqual(FurnizorEnvironment.resolve("staging"), .staging)
        XCTAssertEqual(FurnizorEnvironment.resolve("stagin"), .staging, "valoare greșită → NU producție")
        XCTAssertEqual(FurnizorEnvironment.resolve("PRODUCTION"), .staging)
    }

    func testCheckoutsSlugsAndJournalAreSeparate() {
        PublishJournal.directoryOverride = nil
        FurnizorEnvironment.override = .production
        let prod = (RepoCheckoutPaths.publicCatalogRepo, RepoCheckoutPaths.privateFilesRepo, RepoCheckoutPaths.publicCatalogSlug, PublishJournal.directory)
        FurnizorEnvironment.override = .staging
        XCTAssertEqual(RepoCheckoutPaths.publicCatalogSlug, "gordasgdc/gdc-plugin-manager-staging")
        XCTAssertEqual(RepoCheckoutPaths.publishTarget(for: RepoCheckoutPaths.privateFilesRepo)?.repoSlug, "gordasgdc/gdc-plugin-manager-files-staging")
        XCTAssertTrue(RepoCheckoutPaths.publicCatalogRepo.path.contains("_gdc-publish-staging"))
        XCTAssertNotEqual(RepoCheckoutPaths.publicCatalogRepo, prod.0)
        XCTAssertNotEqual(RepoCheckoutPaths.privateFilesRepo, prod.1)
        XCTAssertNotEqual(PublishJournal.directory, prod.3)
        XCTAssertTrue(PublishJournal.directory.lastPathComponent.hasSuffix("-staging"))
        XCTAssertNil(RepoCheckoutPaths.publishTarget(for: prod.0), "în staging, checkout-ul de producție nu e țintă de publicare")
        XCTAssertEqual(prod.2, "gordasgdc/gdc-plugin-manager")
    }

    func testRepoWriteMatrix() {
        FurnizorEnvironment.override = .staging
        XCTAssertNoThrow(try FurnizorEnvironment.assertRepoWritable("gordasgdc/gdc-plugin-manager-staging"))
        XCTAssertThrowsError(try FurnizorEnvironment.assertRepoWritable("gordasgdc/gdc-plugin-manager"))
        XCTAssertThrowsError(try FurnizorEnvironment.assertRepoWritable("gordasgdc/gdc-plugin-manager-files"))
        FurnizorEnvironment.override = .production
        XCTAssertNoThrow(try FurnizorEnvironment.assertRepoWritable("gordasgdc/gdc-plugin-manager"))
        XCTAssertThrowsError(try FurnizorEnvironment.assertRepoWritable("gordasgdc/gdc-plugin-manager-files-staging"))
    }

    func testProductionServiceWritesAreBlockedInStaging() async throws {
        FurnizorEnvironment.override = .staging
        XCTAssertThrowsError(try SalesLog.append(productID: "x", productName: "x", customer: "x", email: "x", priceEUR: 0,
                                                 expiresDisplay: "x", machineID: "x", serial: "TEST-STAGING")) {
            XCTAssertTrue($0 is FurnizorEnvironment.WriteRefused)
        }
        XCTAssertThrowsError(try SalesLog.delete(serial: "TEST-STAGING")) { XCTAssertTrue($0 is FurnizorEnvironment.WriteRefused) }
        do {
            try await RevocationAdminClient.revoke(machineID: "AAAAAAAAAA", productID: "x", reason: "test staging")
            XCTFail("revocarea trebuia blocată")
        } catch { XCTAssertTrue(error is FurnizorEnvironment.WriteRefused, "\(error)") }
        XCTAssertThrowsError(try FurnizorEnvironment.assertProductionWriteAllowed("x"))
        XCTAssertThrowsError(try LicenseGenerator.generate(privateKeyBase64: "AAAA", productID: "x")) {
            XCTAssertTrue($0 is FurnizorEnvironment.WriteRefused, "serialele nu se emit în staging")
        }
        XCTAssertThrowsError(try BackupArchive.restore(archive: URL(fileURLWithPath: "/nonexistent"), password: "x", progress: { _, _ in })) {
            XCTAssertTrue($0 is FurnizorEnvironment.WriteRefused)
        }
        // Notele și jurnalul de licențe: fișierele reale nu se ating (nicio scriere în staging).
        let notes = ClientNotesStore.fileURL, log = LicenseActionLog.fileURL
        let before = (try? Data(contentsOf: notes), try? Data(contentsOf: log))
        ClientNotesStore.setNote("TEST STAGING", for: "test-staging-key")
        LicenseActionLog.record(machineID: "AAAAAAAAAA", productID: "x", productName: "x", action: .extended, detail: "test staging")
        XCTAssertEqual(try? Data(contentsOf: notes), before.0)
        XCTAssertEqual(try? Data(contentsOf: log), before.1)
    }

    // MARK: - git: publicare corectă în staging

    private func stagingSetup(catalogServerName: String = "gdc-plugin-manager-staging",
                              filesServerName: String = "gdc-plugin-manager-files-staging") throws -> (catalog: URL, files: URL) {
        FurnizorEnvironment.override = .staging
        let files = try makeRepo(serverName: filesServerName, checkout: RepoCheckoutPaths.privateFilesRepo, seed: ["README": "staging"])
        let catalog = try makeRepo(serverName: catalogServerName, checkout: RepoCheckoutPaths.publicCatalogRepo,
                                   seed: ["docs/catalog.json": try realCatalogText()])
        return (catalog, files)
    }

    private func stagedSource() throws -> (URL, PublishTransaction.FileRef) {
        let local = root.appendingPathComponent("local/t.cube")
        try FileManager.default.createDirectory(at: local.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "LUT test".write(to: local, atomically: true, encoding: .utf8)
        return (local, .init(repoKey: "files", path: "test-staging/0.0.1/t.cube", sha256: sha("LUT test")))
    }

    func testStagingPublishReachesStagingRepos() throws {
        let servers = try stagingSetup()
        try PublishTransaction.preflight(repoKeys: ["files"])
        let src = try stagedSource()
        try PublishTransaction.publish(label: "test", sources: [src], files: [src.1], catalog: .upsertItems([try item("test-staging", file: src.1)]),
                                       catalogMessage: "test", catalogPaths: ["docs/catalog.json"])
        XCTAssertNoThrow(try git("cat-file", "-e", "main:test-staging/0.0.1/t.cube", at: servers.files))
        XCTAssertTrue(try git("show", "main:docs/catalog.json", at: servers.catalog).contains("test-staging"))
    }

    // MARK: - git: mediul greșit e refuzat în TOATE operațiile

    func testStagingRefusesCheckoutsPointingToProductionRepos() throws {
        // Folderele de staging, dar clonate din repo-uri cu nume de PRODUCȚIE (ex. clonare greșită).
        let servers = try stagingSetup(catalogServerName: "gdc-plugin-manager", filesServerName: "gdc-plugin-manager-files")
        let heads = (try head(servers.catalog), try head(servers.files))
        let src = try stagedSource()
        XCTAssertThrowsError(try PublishTransaction.preflight(repoKeys: ["files"]))
        XCTAssertThrowsError(try PublishTransaction.publish(label: "x", sources: [src], files: [src.1],
                                                            catalog: .upsertItems([try item("x", file: src.1)]), catalogMessage: "x",
                                                            catalogPaths: ["docs/catalog.json"]))
        XCTAssertThrowsError(try PublishTransaction.delete(label: "x", folders: [.init(repoKey: "files", folder: "x/")],
                                                           catalog: .removeItems(ids: ["x"], covers: [:]), catalogMessage: "x",
                                                           catalogPaths: ["docs/catalog.json"], expectedDeletions: []))
        let record = PublishTransaction.Record(id: UUID(), kind: .publish, createdAt: Date(), label: "x", files: [src.1], deleteFolders: [],
                                               catalog: .upsertItems([]), catalogMessage: "x", catalogPaths: [], expectedDeletions: [])
        try PublishJournal.save(record)
        XCTAssertThrowsError(try PublishTransaction.resume(record))
        XCTAssertThrowsError(try PublishTransaction.cleanupOrphans(record))
        XCTAssertEqual(try head(servers.catalog), heads.0, "repo-urile „de producție” neatinse")
        XCTAssertEqual(try head(servers.files), heads.1)
    }

    func testProductionRefusesStagingRepos() throws {
        FurnizorEnvironment.override = .production
        // Checkout-ul de producție clonat, din greșeală, din repo-ul de staging.
        let server = try makeRepo(serverName: "gdc-plugin-manager-files-staging", checkout: RepoCheckoutPaths.privateFilesRepo, seed: ["a": "b"])
        let before = try head(server)
        XCTAssertThrowsError(try GitOps.pull(at: RepoCheckoutPaths.privateFilesRepo))
        XCTAssertThrowsError(try GitOps.commitAndPush(at: RepoCheckoutPaths.privateFilesRepo, message: "x"))
        XCTAssertEqual(try head(server), before)
    }

    func testPushURLIsCheckedNotOnlyFetchURL() throws {
        let servers = try stagingSetup()
        // Fetch = staging, dar PUSH = un repo de producție → refuzat înaintea oricărei scrieri.
        let prodServer = root.appendingPathComponent("server/gordasgdc/gdc-plugin-manager.git")
        try FileManager.default.createDirectory(at: prodServer, withIntermediateDirectories: true)
        try git("init", "--bare", "--initial-branch=main", at: prodServer)
        try git("remote", "set-url", "--push", "origin", prodServer.path, at: RepoCheckoutPaths.publicCatalogRepo)
        XCTAssertThrowsError(try PublishTransaction.preflight(repoKeys: ["files"])) {
            XCTAssertTrue($0.localizedDescription.contains("push"), $0.localizedDescription)
        }
        XCTAssertThrowsError(try git("rev-parse", "main", at: prodServer), "nimic împins în „producție”")
        _ = servers
    }

    func testRemoteHostParsing() {
        XCTAssertEqual(GitOps.remoteHost("https://github.com/gordasgdc/x.git"), "github.com")
        XCTAssertEqual(GitOps.remoteHost("git@github.com:gordasgdc/x.git"), "github.com")
        XCTAssertEqual(GitOps.remoteHost("https://evil.example/gordasgdc/x.git"), "evil.example")
        XCTAssertNil(GitOps.remoteHost("/tmp/server/gordasgdc/x.git"))
    }
}
