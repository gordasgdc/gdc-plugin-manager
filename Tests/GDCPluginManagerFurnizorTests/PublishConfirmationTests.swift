import XCTest
@testable import GDCPluginManagerFurnizor

/// Faza 5: foaia de confirmare se adaugă PESTE siguranța existentă, nu o înlocuiește.
@MainActor
final class PublishConfirmationTests: XCTestCase {
    func testProductionRequiresExplicitConfirmation() {
        XCTAssertFalse(PublishConfirmationSheet.canPublish(isProduction: true, confirmed: false))
        XCTAssertTrue(PublishConfirmationSheet.canPublish(isProduction: true, confirmed: true))
        XCTAssertTrue(PublishConfirmationSheet.canPublish(isProduction: false, confirmed: false))
    }

    func testWorkspaceGateDefersActionUntilConfirmed() async {
        var ran = false
        var pending: PendingPublish?
        let gate = PublishGate { title, action in pending = PendingPublish(title: title, action: action) }
        gate.request("Produs") { ran = true }
        XCTAssertFalse(ran, "cererea doar deschide foaia; nimic nu rulează fără confirmare")
        XCTAssertEqual(pending?.title, "Produs")
        await pending?.action()
        XCTAssertTrue(ran)
    }

    func testUnconfirmedProductionStillRefusesWritesAfterSheet() throws {
        // Chiar dacă foaia ar fi confirmată, o PRODUCȚIE neconfirmată după STAGING refuză orice scriere.
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("pc-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent("session.json")
        try #"{"environment":"staging"}"#.write(to: file, atomically: true, encoding: .utf8)
        let savedFile = FurnizorEnvironment.sessionFileOverride, savedEnv = FurnizorEnvironment.override
        defer { FurnizorEnvironment.sessionFileOverride = savedFile; FurnizorEnvironment.override = savedEnv }
        FurnizorEnvironment.sessionFileOverride = file
        FurnizorEnvironment.override = .production
        FurnizorEnvironment.bootstrapSession()
        XCTAssertFalse(FurnizorEnvironment.productionWritesUnlocked)
        XCTAssertThrowsError(try FurnizorEnvironment.assertRepoWritable("gordasgdc/gdc-plugin-manager"))
    }
}
