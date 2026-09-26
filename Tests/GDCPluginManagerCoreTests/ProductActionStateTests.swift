import XCTest
@testable import GDCPluginManagerCore

final class ProductActionStateTests: XCTestCase {
    private func d(_ c: Bool = true, _ u: Bool = true, _ b: Bool = false, _ i0: String? = nil, i: String? = nil, v: String = "1.0") -> ProductActionState {
        .derive(isCompatible: c, isUnlocked: u, isBusy: b, installedVersion: i ?? i0, catalogVersion: v)
    }

    func testPriorityOrderMatchesPreviousCardLogic() {
        XCTAssertEqual(d(false, false, true, "0.9"), .incompatible)
        XCTAssertEqual(d(true, false, true, "0.9"), .licenseRequired)
        XCTAssertEqual(d(true, true, true, "0.9"), .installing)
    }

    func testInstallStates() {
        XCTAssertEqual(d(), .notInstalled)
        XCTAssertEqual(d(i: "1.0"), .installed(version: "1.0"))
        XCTAssertEqual(d(i: "0.9", v: "1.0"), .updateAvailable(installed: "0.9", latest: "1.0"))
        // Ca înainte: orice diferență (și o versiune locală mai nouă) = actualizare disponibilă.
        XCTAssertEqual(d(i: "2.0", v: "1.0"), .updateAvailable(installed: "2.0", latest: "1.0"))
    }
}
