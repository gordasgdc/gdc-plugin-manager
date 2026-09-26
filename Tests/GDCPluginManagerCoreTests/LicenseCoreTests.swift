import XCTest
import CryptoKit
@testable import GDCPluginManagerCore

/// Serialele sunt semnate cu o cheie Ed25519 GENERATĂ în test — cheia privată
/// reală nu există pe această mașină/în CI și nu trebuie să existe.
final class LicenseCoreTests: XCTestCase {
    private let key = Curve25519.Signing.PrivateKey()
    private var publicKeyBase64: String { key.publicKey.rawRepresentation.base64EncodedString() }
    private let product = "gdc-style-test-product"
    private let thisMachine: [UInt8] = [1, 2, 3, 4, 5, 6]
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func makeSerial(product: String? = nil, expiresAt: Int64 = 0, machine: [UInt8] = [0, 0, 0, 0, 0, 0],
                            platform: LicenseCore.LicensePlatform? = nil, signer: Curve25519.Signing.PrivateKey? = nil) -> String {
        var payload = LicenseCore.productHash(for: product ?? self.product)
        for shift in stride(from: 56, through: 0, by: -8) { payload.append(UInt8((expiresAt >> Int64(shift)) & 0xFF)) }
        payload += [9, 9, 9, 9] + machine
        if let platform { payload.append(platform.rawValue) }
        let signature = try! (signer ?? key).signature(for: Data(payload))
        let raw = LicenseCore.base32Encode(Data(payload) + signature)
        // Grupare cu cratime, ca serialele reale.
        return stride(from: 0, to: raw.count, by: 5).map { i in
            String(raw.dropFirst(i).prefix(5))
        }.joined(separator: "-")
    }

    private func validate(_ serial: String, product: String? = nil, hwid: Bool = true) -> Result<LicenseCore.Payload, LicenseCore.ValidationError> {
        LicenseCore.validate(serial: serial, expectedProductID: product ?? self.product, hwidAvailable: hwid,
                             publicKeyBase64: publicKeyBase64, machineHash: { self.thisMachine }, now: now)
    }

    func testValidPerpetualV1Serial() throws {
        let payload = try validate(makeSerial()).get()
        XCTAssertEqual(payload.expiresAt, 0)
        XCTAssertFalse(payload.machineLocked)
        XCTAssertEqual(payload.platform, .any)
    }

    func testValidMachineLockedV2Serial() throws {
        let payload = try validate(makeSerial(machine: thisMachine, platform: .crossPlatform)).get()
        XCTAssertTrue(payload.machineLocked)
        XCTAssertEqual(payload.platform, .crossPlatform)
    }

    func testSerialIsCaseAndSeparatorInsensitive() throws {
        let serial = makeSerial().lowercased().replacingOccurrences(of: "-", with: " ")
        XCTAssertNoThrow(try validate(serial).get())
    }

    func testFutureExpiryIsValidPastExpiryIsExpired() {
        let future = Int64(now.timeIntervalSince1970) + 86_400
        let past = Int64(now.timeIntervalSince1970) - 1
        XCTAssertNoThrow(try validate(makeSerial(expiresAt: future)).get())
        guard case .failure(.expired(let at, _)) = validate(makeSerial(expiresAt: past)) else {
            return XCTFail("un serial expirat trebuie respins ca .expired")
        }
        XCTAssertEqual(at, past)
    }

    func testProductMismatchIsRejected() {
        guard case .failure(.wrongProduct) = validate(makeSerial(), product: "alt-produs") else {
            return XCTFail("serialul unui produs nu trebuie să deblocheze alt produs (Regula 49)")
        }
    }

    func testForeignSignatureIsRejected() {
        let serial = makeSerial(signer: Curve25519.Signing.PrivateKey())
        guard case .failure(.badSignature) = validate(serial) else { return XCTFail("semnătură străină acceptată") }
    }

    func testTestKeySerialFailsAgainstProductionKey() {
        // Garda inversă: cheia de producție nu acceptă nimic semnat în teste.
        guard case .failure(.badSignature) = LicenseCore.validate(serial: makeSerial(), expectedProductID: product) else {
            return XCTFail("cheia publică de producție a acceptat un serial de test")
        }
    }

    func testTamperedPayloadIsRejected() {
        var raw = Array(LicenseCore.base32Decode(makeSerial())!)
        raw[6] ^= 0xFF // modifică data de expirare după semnare
        guard case .failure(.badSignature) = validate(LicenseCore.base32Encode(Data(raw))) else {
            return XCTFail("payload modificat acceptat")
        }
    }

    func testMalformedInputs() {
        for input in ["", "!!!!", "ABC", String(repeating: "A", count: 200), "GDC-1234-😀"] {
            guard case .failure(.malformedCode) = validate(input) else {
                return XCTFail("intrare invalidă neclasificată ca malformedCode: \(input)")
            }
        }
    }

    func testWrongMachine() {
        guard case .failure(.wrongMachine(let p)) = validate(makeSerial(machine: [7, 7, 7, 7, 7, 7])) else {
            return XCTFail("serial legat de alt Mac acceptat")
        }
        XCTAssertTrue(p.machineLocked)
    }

    func testHWIDUnavailableIsDistinctFromWrongMachine() {
        // Un eșec IOKit tranzitoriu nu trebuie tratat ca „alt Mac”.
        guard case .failure(.hwidUnavailable) = validate(makeSerial(machine: thisMachine), hwid: false) else {
            return XCTFail("HWID indisponibil trebuie raportat separat")
        }
        XCTAssertNoThrow(try validate(makeSerial(), hwid: false).get(), "serialele nelegate de mașină nu depind de HWID")
    }

    func testWindowsOnlySerialRejectedOnMac() {
        guard case .failure(.wrongPlatform) = validate(makeSerial(platform: .windowsOnly)) else {
            return XCTFail("serial windows_only acceptat pe Mac")
        }
        XCTAssertNoThrow(try validate(makeSerial(platform: .macOnly)).get())
    }

    func testUnknownPlatformByteFallsBackToAny() throws {
        // Comportament existent, documentat: un octet de platformă necunoscut => .any.
        var payload = LicenseCore.productHash(for: product) + [UInt8](repeating: 0, count: 8) + [9, 9, 9, 9] + [0, 0, 0, 0, 0, 0] + [42]
        let sig = try key.signature(for: Data(payload))
        payload += Array(sig)
        XCTAssertEqual(try validate(LicenseCore.base32Encode(Data(payload))).get().platform, .any)
    }

    func testBase32RoundTrip() {
        let data = Data((0..<87).map { UInt8($0 * 3 & 0xFF) })
        XCTAssertEqual(LicenseCore.base32Decode(LicenseCore.base32Encode(data)), data)
    }

    func testProductHashIsStable() {
        // Compatibil byte cu byte cu license_core.py: SHA-512(id)[:4].
        XCTAssertEqual(LicenseCore.productHash(for: "abc"), [0xDD, 0xAF, 0x35, 0xA1])
    }
}

/// Vector comun Mac/Windows (Faza 6): serial semnat în C# (BouncyCastle, cheie de TEST cu seed 1…32),
/// validat aici cu implementarea Swift — dovada că formatul licenței e identic pe ambele platforme.
final class LicenseCrossPlatformVectorTests: XCTestCase {
    func testSerialSignedOnWindowsValidatesOnMac() throws {
        let pub = "ebVWLo/mVPlAeLES6KmLp5AfhTrmlb7X4OORC60ElmQ="
        let serial = "CQ26R-ZYAAA-AAAAA-AAAAA-SCIJB-EAAAA-AAAAA-AGUZA-MQILW-MHG2I-DH3R5-YPTKF-HBVQU-ELR3W-VZARQ-D35JX-BLNWO-RAOA7-SYTHJ-FLINB-LQHXR-GYRAP-ALEK4-UCINV-F6OZL-O6M2V-DE7KQ-PTAGA"
        let payload = try LicenseCore.validate(serial: serial, expectedProductID: "gdc-parity-vector", hwidAvailable: true,
                                               publicKeyBase64: pub, machineHash: { [0, 0, 0, 0, 0, 0] }, now: Date()).get()
        XCTAssertEqual(payload.platform, .crossPlatform)
        XCTAssertEqual(payload.expiresAt, 0)
        XCTAssertFalse(payload.machineLocked)
    }
}
