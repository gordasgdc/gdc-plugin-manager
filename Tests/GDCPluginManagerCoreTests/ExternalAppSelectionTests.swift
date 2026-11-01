import XCTest
@testable import GDCPluginManagerCore

final class ExternalAppSelectionTests: XCTestCase {
    private func u(_ p: String) -> URL { URL(fileURLWithPath: p) }
    private let all: (URL) -> Bool = { _ in true }

    func testPrefersApplicationsOverEveryOtherCopy() {
        let urls = [u("/Volumes/SADROG 1.3.0/SADROG.app"), u("/Users/x/Applications/SADROG.app"), u("/Applications/SADROG.app")]
        XCTAssertEqual(ExternalAppSelection.choose(from: urls, home: "/Users/x", exists: all, isTrusted: all)?.path, "/Applications/SADROG.app")
    }

    func testMountedDiskImageAndBuildCopiesAreNeverTheUserInstall() {
        let urls = [u("/Volumes/SADROG 1.3.0/SADROG.app"),
                    u("/Users/x/Library/Developer/Xcode/DerivedData/a/Build/SADROG.app"),
                    u("/private/var/folders/ab/T/AppTranslocation/X/d/SADROG.app"),
                    u("/Users/x/Developer/sadrog/.build/release/SADROG.app")]
        XCTAssertNil(ExternalAppSelection.choose(from: urls, home: "/Users/x", exists: all, isTrusted: all))
    }

    func testExternalVolumeWithApplicationsFolderIsAccepted() {
        XCTAssertEqual(ExternalAppSelection.choose(from: [u("/Volumes/Work/Applications/SADROG.app")], home: "/Users/x", exists: all, isTrusted: all)?.path,
                       "/Volumes/Work/Applications/SADROG.app")
    }

    func testUntrustedSignatureIsSkippedEvenInApplications() {
        let urls = [u("/Applications/SADROG.app"), u("/Users/x/Applications/SADROG.app")]
        let chosen = ExternalAppSelection.choose(from: urls, home: "/Users/x", exists: all) { $0.path.hasPrefix("/Users/x/") }
        XCTAssertEqual(chosen?.path, "/Users/x/Applications/SADROG.app")
    }

    func testMissingPathsAreIgnored() {
        XCTAssertNil(ExternalAppSelection.choose(from: [u("/Applications/SADROG.app")], home: "/Users/x", exists: { _ in false }, isTrusted: all))
    }
}
