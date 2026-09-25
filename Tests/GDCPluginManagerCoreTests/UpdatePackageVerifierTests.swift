import XCTest
@testable import GDCPluginManagerCore

/// S2: instalarea privilegiată nu poate continua dacă verificarea eșuează.
/// Scriptul root e rulat REAL (bash), ca utilizator curent, cu `installer`
/// înlocuit de un marcaj — marcajul apare doar dacă toate porțile trec.
final class UpdatePackageVerifierTests: XCTestCase {
    private let marker = "INSTALL-EXECUTED"
    private var work: URL!

    override func setUpWithError() throws {
        work = FileManager.default.temporaryDirectory.appendingPathComponent("gdcpm-verifier-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: work) }

    private var validOutput: String {
        get throws { try String(contentsOf: repoRoot.appendingPathComponent("Tests/GDCPluginManagerCoreTests/Fixtures/pkgutil-valid.txt"), encoding: .utf8) }
    }

    /// Pachet signed real (build local de release), dacă există pe această mașină. În CI lipsește.
    private var realSignedPkg: URL? {
        let dist = repoRoot.appendingPathComponent("dist")
        let pkgs = (try? FileManager.default.contentsOfDirectory(at: dist, includingPropertiesForKeys: nil)) ?? []
        return pkgs.first { $0.lastPathComponent.hasPrefix("GDCPluginManager-") && $0.pathExtension == "pkg" }
    }

    private func makeUnsignedPkg() throws -> URL {
        let root = work.appendingPathComponent("payload/Applications")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data("x".utf8).write(to: root.appendingPathComponent("gdc-test.txt"))
        let pkg = work.appendingPathComponent("unsigned.pkg")
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/pkgbuild")
        p.arguments = ["--root", work.appendingPathComponent("payload").path, "--identifier", "dev.gordas.test",
                       "--version", "1.0", "--install-location", "/", pkg.path]
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        try p.run(); p.waitUntilExit()
        XCTAssertEqual(p.terminationStatus, 0, "pkgbuild a eșuat")
        return pkg
    }

    /// Rulează scriptul root ca utilizator curent; întoarce (cod ieșire, log).
    private func runRootScript(pkg: URL, sha: String, team: String = UpdatePackageVerifier.trustedTeamID,
                               beforeRun: (() throws -> Void)? = nil) throws -> (Int32, String) {
        let log = work.appendingPathComponent("install-\(UUID().uuidString).log")
        var script = try UpdatePackageVerifier.rootInstallScript(
            pkg: pkg, expectedSHA256: sha, relaunchApp: "/usr/bin/true", logFile: log, expectedTeamID: team,
            installCommand: "echo \(marker)", workParent: work.path)
        script = script.replacingOccurrences(of: "sleep 2", with: ":")
            .replacingOccurrences(of: "/usr/bin/open '/usr/bin/true'", with: ":")
        try beforeRun?()
        // Același drum ca în producție (osascript + argv), fără elevare.
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        p.arguments = UpdatePackageVerifier.osascriptArguments(script: script, elevated: false)
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        try p.run(); p.waitUntilExit()
        return (p.terminationStatus, (try? String(contentsOf: log, encoding: .utf8)) ?? "")
    }

    // MARK: - Interpretarea semnăturii

    func testValidDeveloperIDInstallerWithTrustedTeamIsAccepted() throws {
        let sig = try UpdatePackageVerifier.parse(pkgutilOutput: try validOutput, exitStatus: 0).get()
        XCTAssertEqual(sig.teamID, "8AR6XP8MG7")
        XCTAssertTrue(sig.notarized)
    }

    func testWrongTeamIsRejected() throws {
        let other = try validOutput.replacingOccurrences(of: "(8AR6XP8MG7)", with: "(ZZZZZZZZZZ)")
        XCTAssertEqual(UpdatePackageVerifier.parse(pkgutilOutput: other, exitStatus: 0), .failure(.wrongTeam("ZZZZZZZZZZ")))
    }

    func testUnsignedIsRejected() {
        XCTAssertEqual(UpdatePackageVerifier.parse(pkgutilOutput: "Package \"x.pkg\":\n   Status: no signature\n", exitStatus: 1), .failure(.unsigned))
    }

    func testNonInstallerOrNonDistributionCertificateIsRejected() throws {
        let appCert = try validOutput.replacingOccurrences(of: "Developer ID Installer:", with: "Developer ID Application:")
        XCTAssertEqual(UpdatePackageVerifier.parse(pkgutilOutput: appCert, exitStatus: 0), .failure(.notDeveloperIDDistribution))
        let dev = try validOutput.replacingOccurrences(of: "issued by Apple for distribution", with: "issued by Apple for development")
        XCTAssertEqual(UpdatePackageVerifier.parse(pkgutilOutput: dev, exitStatus: 0), .failure(.notDeveloperIDDistribution))
    }

    func testVersionValidationBlocksInjection() {
        XCTAssertNoThrow(try UpdatePackageVerifier.validateVersion("1.39.3"))
        for bad in ["1.39.3\"; rm -rf /", "$(id)", "1.2.3 ", "../1.2", "1", ""] {
            XCTAssertThrowsError(try UpdatePackageVerifier.validateVersion(bad), bad)
        }
    }

    func testUnsafePathsAreRefused() {
        let bad = URL(fileURLWithPath: "/tmp/a'$(id).pkg")
        XCTAssertThrowsError(try UpdatePackageVerifier.rootInstallScript(
            pkg: bad, expectedSHA256: String(repeating: "a", count: 64), relaunchApp: "/Applications/X.app",
            logFile: URL(fileURLWithPath: "/tmp/l.log")))
        XCTAssertThrowsError(try UpdatePackageVerifier.rootInstallScript(
            pkg: URL(fileURLWithPath: "/tmp/a.pkg"), expectedSHA256: "nu-e-hex", relaunchApp: "/Applications/X.app",
            logFile: URL(fileURLWithPath: "/tmp/l.log")))
    }

    // MARK: - Scriptul root, rulat efectiv

    func testUnsignedPackageBlocksInstall() throws {
        let pkg = try makeUnsignedPkg()
        XCTAssertThrowsError(try UpdatePackageVerifier.verify(pkg: pkg)) { XCTAssertEqual($0 as? UpdatePackageVerifier.VerifyError, .unsigned) }
        let (status, log) = try runRootScript(pkg: pkg, sha: try UpdatePackageVerifier.sha256(of: pkg))
        XCTAssertNotEqual(status, 0); XCTAssertTrue(log.contains("pachet nesemnat"), log)
        XCTAssertFalse(log.contains(marker), "installer a rulat pentru un pachet nesemnat")
    }

    func testChecksumMismatchBlocksInstall() throws {
        let pkg = try makeUnsignedPkg()
        let (status, log) = try runRootScript(pkg: pkg, sha: String(repeating: "0", count: 64))
        XCTAssertNotEqual(status, 0); XCTAssertTrue(log.contains("suma de control"), log)
        XCTAssertFalse(log.contains(marker))
    }

    func testArtifactReplacedAfterVerificationBlocksInstall() throws {
        // „Verificat A, instalat B”: fișierul e înlocuit între poarta 1 și poarta root.
        let pkg = try makeUnsignedPkg()
        let verifiedSHA = try UpdatePackageVerifier.sha256(of: pkg)
        let (status, log) = try runRootScript(pkg: pkg, sha: verifiedSHA) {
            try Data("pachet înlocuit".utf8).write(to: pkg)
        }
        XCTAssertNotEqual(status, 0); XCTAssertTrue(log.contains("suma de control"), log)
        XCTAssertFalse(log.contains(marker))
    }

    func testRealSignedPackageInstallsAndWrongTeamOrCorruptionBlocks() throws {
        guard let signed = realSignedPkg else { throw XCTSkip("fără pachet semnat local în dist/ (normal în CI)") }
        let pkg = work.appendingPathComponent("signed.pkg")
        try FileManager.default.copyItem(at: signed, to: pkg)
        let (sig, sha) = try UpdatePackageVerifier.verify(pkg: pkg)
        XCTAssertEqual(sig.teamID, UpdatePackageVerifier.trustedTeamID)

        let ok = try runRootScript(pkg: pkg, sha: sha)
        XCTAssertEqual(ok.0, 0, ok.1)
        XCTAssertTrue(ok.1.contains(marker), "pachetul valid nu a ajuns la instalare")

        let wrongTeam = try runRootScript(pkg: pkg, sha: sha, team: "ZZZZZZZZZZ")
        XCTAssertNotEqual(wrongTeam.0, 0); XCTAssertTrue(wrongTeam.1.contains("Team ID diferit"), wrongTeam.1)
        XCTAssertFalse(wrongTeam.1.contains(marker))

        // Corupție: un octet din mijloc modificat → semnătura nu mai e validă.
        var bytes = try Data(contentsOf: pkg)
        bytes[bytes.count / 2] ^= 0xFF
        try bytes.write(to: pkg)
        XCTAssertThrowsError(try UpdatePackageVerifier.verify(pkg: pkg))
        let corrupted = try runRootScript(pkg: pkg, sha: try UpdatePackageVerifier.sha256(of: pkg))
        XCTAssertNotEqual(corrupted.0, 0)
        XCTAssertFalse(corrupted.1.contains(marker))
    }
}
