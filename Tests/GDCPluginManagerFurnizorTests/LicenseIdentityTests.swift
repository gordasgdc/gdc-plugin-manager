import XCTest
import CryptoKit
@testable import GDCPluginManagerFurnizor
@testable import GDCPluginManagerCore

/// Migrarea DataMover la licențele generația 2 (cheie de TEST; cheia reală nu e atinsă).
final class LicenseIdentityTests: XCTestCase {
    let key = Curve25519.Signing.PrivateKey()
    let machine = LicenseCore.base32Encode(Data([1, 2, 3, 4, 5, 6]))

    func testSigningIDMapping() {
        XCTAssertEqual(LicenseIdentity.signingProductID(for: "gdc-datamover"), "gdc-datamover-license-v2")
        for other in ["cursorpro", "gdc-vault", "cgconvertor", "media-flow-monitor", "gdc-lut-lab"] {
            XCTAssertEqual(LicenseIdentity.signingProductID(for: other), other, "celelalte produse nu se schimbă")
        }
        XCTAssertTrue(LicenseIdentity.requiresMachineID("gdc-datamover"))
        XCTAssertFalse(LicenseIdentity.requiresMachineID("cursorpro"))
        XCTAssertTrue(LicenseIdentity.isReservedCustomID("gdc-datamover"))
        XCTAssertTrue(LicenseIdentity.isReservedCustomID("GDC-DataMover-license-v2"))
        XCTAssertFalse(LicenseIdentity.isReservedCustomID("gdc-style-01-grain"))
    }

    func testDataMoverV2SerialLayoutAndGeneration() throws {
        let v2 = try LicenseGenerator.sign(privateKey: key, productID: LicenseIdentity.signingProductID(for: "gdc-datamover"),
                                           expiresAt: 1_900_000_000, machineIDBase32: machine)
        let packed = try XCTUnwrap(LicenseCore.base32Decode(v2))
        XCTAssertEqual(packed.count, 22 + 64, "DataMover citește payload-ul de 22 de octeți")
        XCTAssertEqual(Array(packed.prefix(4)), LicenseCore.productHash(for: "gdc-datamover-license-v2"))
        XCTAssertEqual(Array(packed[16..<22]), [1, 2, 3, 4, 5, 6])
        XCTAssertTrue(key.publicKey.isValidSignature(packed.suffix(64), for: packed.prefix(22)))
        XCTAssertEqual(LicenseIdentity.dataMoverGeneration(ofSerial: v2), .v2)
    }

    func testLegacyDetectionInRegistry() throws {
        let legacy = try LicenseGenerator.sign(privateKey: key, productID: "gdc-datamover", machineIDBase32: machine)
        XCTAssertEqual(LicenseIdentity.dataMoverGeneration(ofSerial: legacy), .legacyV1)
        XCTAssertEqual(LicenseIdentity.dataMoverGeneration(ofSerial: legacy + "\r"), .legacyV1, "rânduri CRLF din registru")
        let other = try LicenseGenerator.sign(privateKey: key, productID: "cursorpro", machineIDBase32: machine)
        XCTAssertEqual(LicenseIdentity.dataMoverGeneration(ofSerial: other), .unknown)
        XCTAssertEqual(LicenseIdentity.dataMoverGeneration(ofSerial: "nu-e-un-cod"), .unknown)
    }
}
