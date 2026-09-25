import XCTest
@testable import GDCPluginManagerFurnizor

/// D2: publicarea din Furnizor ajunge DOAR pe `main`, în repo-ul corect, fără modificări străine
/// și fără pierderi. Repo-uri git locale, temporare: „serverul” e un repo bare `…/gordasgdc/<repo>.git`.
final class PublishCheckoutGuardTests: XCTestCase {
    private var root: URL!
    private let catalog = GitOps.PublishTarget(repoSlug: "gordasgdc/gdc-plugin-manager", allowedDirtyPrefixes: ["docs/"])

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("d2-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    // MARK: - utilitare

    @discardableResult
    private func git(_ args: String..., at dir: URL) throws -> String {
        try GitOps.run(["-c", "user.name=Test", "-c", "user.email=test@example.com"] + args, at: dir)
    }

    /// Server bare + clonă de publicare pe `main`, cu un commit inițial (docs/catalog.json + un fișier sursă).
    private func makeRemoteAndClone(slug: String = "gordasgdc/gdc-plugin-manager") throws -> (remote: URL, clone: URL) {
        let remote = root.appendingPathComponent("server/\(slug).git")
        try FileManager.default.createDirectory(at: remote, withIntermediateDirectories: true)
        try git("init", "--bare", "--initial-branch=main", at: remote)
        let seed = root.appendingPathComponent("seed")
        try git("clone", remote.path, seed.path, at: root)
        try git("checkout", "-B", "main", at: seed)
        try write("docs/catalog.json", "{\"v\":1}", in: seed)
        try write("Sources/App.swift", "// cod", in: seed)
        try git("add", "-A", at: seed)
        try git("commit", "-m", "initial", at: seed)
        try git("push", "origin", "main", at: seed)
        let clone = root.appendingPathComponent("publish")
        try git("clone", "--branch", "main", remote.path, clone.path, at: root)
        return (remote, clone)
    }

    private func write(_ rel: String, _ text: String, in dir: URL) throws {
        let url = dir.appendingPathComponent(rel)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    private func head(_ ref: String, at dir: URL) throws -> String {
        try git("rev-parse", ref, at: dir).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func assertGuard(_ expression: () throws -> Void, contains fragment: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertThrowsError(try expression(), file: file, line: line) { error in
            XCTAssertTrue(error is GitOps.PublishGuardError, "eroare neașteptată: \(error)", file: file, line: line)
            XCTAssertTrue(error.localizedDescription.contains(fragment), "mesaj: \(error.localizedDescription)", file: file, line: line)
        }
    }

    // MARK: - scenarii

    func testNormalPublishReachesMain() throws {
        let (remote, clone) = try makeRemoteAndClone()
        try GitOps.pull(at: clone, target: catalog)
        try write("docs/catalog.json", "{\"v\":2}", in: clone)
        try GitOps.commitAndPush(at: clone, message: "Catalog: test", paths: ["docs/catalog.json"], target: catalog)
        XCTAssertEqual(try head("main", at: remote), try head("HEAD", at: clone))
    }

    func testWrongBranchIsRefusedAndNothingIsPushed() throws {
        let (remote, clone) = try makeRemoteAndClone()
        let before = try head("main", at: remote)
        try git("checkout", "-b", "release/9.9.9", at: clone)
        try write("docs/catalog.json", "{\"v\":3}", in: clone)
        assertGuard({ try GitOps.pull(at: clone, target: catalog) }, contains: "release/9.9.9")
        assertGuard({ try GitOps.commitAndPush(at: clone, message: "x", paths: ["docs/catalog.json"], target: catalog) }, contains: "nu pe „main”")
        XCTAssertEqual(try head("main", at: remote), before, "serverul nu trebuie atins")
        XCTAssertEqual(try git("log", "-1", "--format=%s", at: clone).trimmingCharacters(in: .whitespacesAndNewlines), "initial", "niciun commit local")
    }

    func testUncommittedDevelopmentChangesAreRefusedAndKept() throws {
        let (remote, clone) = try makeRemoteAndClone()
        let before = try head("main", at: remote)
        try write("Sources/App.swift", "// modificare în lucru", in: clone)      // fișier urmărit, modificat
        try write("Sources/Nou.swift", "// fișier nou", in: clone)               // fișier neurmărit
        try write("docs/catalog.json", "{\"v\":4}", in: clone)
        assertGuard({ try GitOps.pull(at: clone, target: catalog) }, contains: "Sources/App.swift")
        assertGuard({ try GitOps.commitAndPush(at: clone, message: "x", paths: ["docs/catalog.json"], target: catalog) }, contains: "Sources/Nou.swift")
        XCTAssertEqual(try head("main", at: remote), before)
        XCTAssertEqual(try String(contentsOf: clone.appendingPathComponent("Sources/App.swift"), encoding: .utf8), "// modificare în lucru", "nimic nu se pierde")
    }

    func testDivergedHistoryStopsWithoutLosingTheLocalCommit() throws {
        let (remote, clone) = try makeRemoteAndClone()
        // Altcineva publică între timp.
        let other = root.appendingPathComponent("other")
        try git("clone", "--branch", "main", remote.path, other.path, at: root)
        try write("docs/catalog.json", "{\"v\":\"altul\"}", in: other)
        try git("commit", "-am", "publicare de pe alt Mac", at: other)
        try git("push", "origin", "main", at: other)
        let serverHead = try head("main", at: remote)
        // Local: un commit de catalog nepublicat, pe aceeași bază veche.
        try write("docs/catalog.json", "{\"v\":\"local\"}", in: clone)
        try git("commit", "-am", "publicare locală", at: clone)
        let localHead = try head("HEAD", at: clone)

        assertGuard({ try GitOps.commitAndPush(at: clone, message: "x", paths: ["docs/catalog.json"], target: catalog) }, contains: "respins")
        assertGuard({ try GitOps.pull(at: clone, target: catalog) }, contains: "conflict de sincronizare")
        XCTAssertEqual(try head("main", at: remote), serverHead, "fără force-push")
        XCTAssertEqual(try head("HEAD", at: clone), localHead, "commit-ul local rămâne")
    }

    func testWrongRemoteIsRefused() throws {
        let (_, clone) = try makeRemoteAndClone(slug: "gordasgdc/alt-repo")
        assertGuard({ try GitOps.pull(at: clone, target: catalog) }, contains: "alt repo")
    }

    func testUnknownCheckoutIsRefused() throws {
        let (_, clone) = try makeRemoteAndClone()
        assertGuard({ try GitOps.pull(at: clone) }, contains: "nu e un checkout de publicare cunoscut")
    }

    func testPrivateRepoAllowsProductFilesButStillRequiresMain() throws {
        let files = GitOps.PublishTarget(repoSlug: "gordasgdc/gdc-plugin-manager-files", allowedDirtyPrefixes: nil)
        let (remote, clone) = try makeRemoteAndClone(slug: "gordasgdc/gdc-plugin-manager-files")
        try GitOps.pull(at: clone, target: files)
        try write("produs/1.0.0/a.cube", "LUT", in: clone)
        try GitOps.commitAndPush(at: clone, message: "produs 1.0.0", target: files)
        XCTAssertEqual(try head("main", at: remote), try head("HEAD", at: clone))
        try git("checkout", "-b", "lucru", at: clone)
        assertGuard({ try GitOps.pull(at: clone, target: files) }, contains: "„lucru”")
    }

    func testMergeInProgressIsRefused() throws {
        let (_, clone) = try makeRemoteAndClone()
        let mergeHead = try git("rev-parse", "--git-path", "MERGE_HEAD", at: clone).trimmingCharacters(in: .whitespacesAndNewlines)
        try (try head("HEAD", at: clone)).write(to: clone.appendingPathComponent(mergeHead), atomically: true, encoding: .utf8)
        assertGuard({ try GitOps.pull(at: clone, target: catalog) }, contains: "MERGE_HEAD")
    }

    func testRealPathsMapToTheExpectedRepos() {
        XCTAssertEqual(RepoCheckoutPaths.publishTarget(for: RepoCheckoutPaths.publicCatalogRepo),
                       .init(repoSlug: "gordasgdc/gdc-plugin-manager", allowedDirtyPrefixes: ["docs/"]))
        XCTAssertEqual(RepoCheckoutPaths.publishTarget(for: RepoCheckoutPaths.privateFilesRepo)?.repoSlug, "gordasgdc/gdc-plugin-manager-files")
        XCTAssertFalse(RepoCheckoutPaths.publicCatalogRepo.path.hasSuffix("gdc-plugin-manager-catalog-vendor"), "catalogul nu se mai publică din repo-ul de dezvoltare")
        let dev = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Developer/gdc-plugin-manager-catalog-vendor")
        XCTAssertNil(RepoCheckoutPaths.publishTarget(for: dev), "repo-ul de dezvoltare nu e checkout de publicare")
        XCTAssertEqual(GitOps.repoSlug(fromRemoteURL: "git@github.com:GordasGDC/gdc-plugin-manager.git\n"), "gordasgdc/gdc-plugin-manager")
        XCTAssertEqual(GitOps.repoSlug(fromRemoteURL: "https://github.com/gordasgdc/gdc-plugin-manager-files"), "gordasgdc/gdc-plugin-manager-files")
    }
}
