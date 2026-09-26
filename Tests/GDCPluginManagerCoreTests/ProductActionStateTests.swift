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

    func testFailedAndOffline() {
        let f = { (i: String?, failed: Bool, offline: Bool) in
            ProductActionState.derive(isCompatible: true, isUnlocked: true, isBusy: false, installedVersion: i,
                                      catalogVersion: "1.0", lastInstallFailed: failed, isOffline: offline)
        }
        XCTAssertEqual(f(nil, true, false), .failed(isUpdate: false))
        XCTAssertEqual(f("0.9", true, false), .failed(isUpdate: true))
        // Eroare la „Elimină” pe un produs la zi: rămâne instalat (mesajul apare separat).
        XCTAssertEqual(f("1.0", true, false), .installed(version: "1.0"))
        XCTAssertEqual(f(nil, false, true), .offline)
        XCTAssertEqual(f("1.0", false, true), .installed(version: "1.0"))
        XCTAssertEqual(ProductActionState.derive(isCompatible: true, isUnlocked: true, isBusy: true, installedVersion: nil,
                                                 catalogVersion: "1.0", lastInstallFailed: true, isOffline: true), .installing)
    }
}
