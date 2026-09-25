import XCTest
@testable import GDCPluginManagerFurnizor

/// 1.52.5: o pornire normală (producție) după o sesiune STAGING nu poate scrie nimic până la
/// confirmarea explicită; anularea lasă totul blocat, inclusiv după o nouă repornire.
final class ProductionConfirmationTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("confirm-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        FurnizorEnvironment.sessionFileOverride = root.appendingPathComponent("last-environment.json")
        FurnizorEnvironment.resetSessionStateForTests()
    }

    override func tearDownWithError() throws {
        FurnizorEnvironment.override = nil
        FurnizorEnvironment.sessionFileOverride = nil
        FurnizorEnvironment.resetSessionStateForTests()
        RepoCheckoutPaths.testRoot = nil
        try? FileManager.default.removeItem(at: root)
    }

    /// Simulează o pornire a aplicației în mediul dat.
    private func launch(_ env: FurnizorEnvironment) {
        FurnizorEnvironment.override = env
        FurnizorEnvironment.bootstrapSession()
    }

    private let prodRepo = "gordasgdc/gdc-plugin-manager"

    func testFirstLaunchWithoutHistoryIsProductionUnlocked() {
        launch(.production)
        XCTAssertFalse(FurnizorEnvironment.productionConfirmationPending)
        XCTAssertNoThrow(try FurnizorEnvironment.assertRepoWritable(prodRepo))
        XCTAssertEqual(FurnizorEnvironment.lastSessionEnvironment(), .production)
    }

    func testNormalRestartAfterStagingBlocksEveryWrite() throws {
        launch(.staging)
        XCTAssertEqual(FurnizorEnvironment.lastSessionEnvironment(), .staging)
        launch(.production)   // repornire normală, fără scriptul de staging
        XCTAssertTrue(FurnizorEnvironment.productionConfirmationPending)
        XCTAssertFalse(FurnizorEnvironment.productionWritesUnlocked)
        XCTAssertThrowsError(try FurnizorEnvironment.assertRepoWritable(prodRepo)) {
            XCTAssertTrue($0.localizedDescription.contains("PRODUCȚIE neconfirmată"))
        }
        XCTAssertThrowsError(try FurnizorEnvironment.assertProductionWriteAllowed("Generarea serialelor"))
        XCTAssertThrowsError(try LicenseGenerator.generate(privateKeyBase64: "AAAA", productID: "x"))
    }

    func testCancelKeepsWritesBlockedAlsoForGitAndAfterAnotherRestart() throws {
        launch(.staging)
        launch(.production)
        // „Anulează” = nu se apelează confirmProduction(). Git (prin garda comună) rămâne blocat.
        RepoCheckoutPaths.testRoot = root
        let server = root.appendingPathComponent("server/gordasgdc/gdc-plugin-manager.git")
        try FileManager.default.createDirectory(at: server, withIntermediateDirectories: true)
        try GitOps.run(["init", "--bare", "--initial-branch=main"], at: server)
        let checkout = RepoCheckoutPaths.publicCatalogRepo
        try FileManager.default.createDirectory(at: checkout.deletingLastPathComponent(), withIntermediateDirectories: true)
        try GitOps.run(["clone", server.path, checkout.path], at: root)
        XCTAssertThrowsError(try GitOps.verifyPublishCheckout(at: checkout)) {
            XCTAssertTrue($0.localizedDescription.contains("PRODUCȚIE neconfirmată"), $0.localizedDescription)
        }
        XCTAssertThrowsError(try PublishTransaction.preflight(repoKeys: []))
        // O nouă pornire normală fără confirmare: tot blocat (sesiunea rămâne „staging”).
        launch(.production)
        XCTAssertTrue(FurnizorEnvironment.productionConfirmationPending)
        XCTAssertEqual(FurnizorEnvironment.lastSessionEnvironment(), .staging)
    }

    func testConfirmationUnlocksAndPersists() {
        launch(.staging)
        launch(.production)
        FurnizorEnvironment.confirmProduction()
        XCTAssertFalse(FurnizorEnvironment.productionConfirmationPending)
        XCTAssertNoThrow(try FurnizorEnvironment.assertRepoWritable(prodRepo))
        XCTAssertEqual(FurnizorEnvironment.lastSessionEnvironment(), .production)
        launch(.production)   // următoarea pornire normală nu mai cere confirmare
        XCTAssertFalse(FurnizorEnvironment.productionConfirmationPending)
        // Protecțiile existente rămân: producția tot nu scrie în repo-urile de test.
        XCTAssertThrowsError(try FurnizorEnvironment.assertRepoWritable("gordasgdc/gdc-plugin-manager-staging"))
    }

    func testStagingLaunchIsNeverBlockedByConfirmationButKeepsItsOwnRules() {
        launch(.staging)
        XCTAssertFalse(FurnizorEnvironment.productionConfirmationPending)
        XCTAssertNoThrow(try FurnizorEnvironment.assertRepoWritable("gordasgdc/gdc-plugin-manager-staging"))
        XCTAssertThrowsError(try FurnizorEnvironment.assertRepoWritable(prodRepo))
        FurnizorEnvironment.confirmProduction()   // fără efect în staging
        XCTAssertEqual(FurnizorEnvironment.lastSessionEnvironment(), .staging)
    }
}
