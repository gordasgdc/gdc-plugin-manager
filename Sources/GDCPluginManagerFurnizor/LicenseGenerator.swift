import Foundation
import CryptoKit
import GDCPluginManagerCore

/// The signing counterpart to LicenseCore.validate — builds and signs a
/// new serial. Mirrors gdc-license-system's `generate_serial_compact`
/// exactly (same 22-byte payload, same Ed25519 signature, same Base32 +
/// dash-grouping), so codes from either tool are interchangeable.
/// Vendor-target only: needs the private key, which must never ship in
/// the distributed client app.
enum LicenseGenerator {
    enum GenerationError: Error, LocalizedError {
        case invalidPrivateKey
        case invalidMachineID

        var errorDescription: String? {
            switch self {
            case .invalidPrivateKey: return "Cheia privată de pe disc nu e o cheie Ed25519 validă."
            case .invalidMachineID: return "ID-ul de calculator nu e valid — verifică să fi fost copiat complet."
            }
        }
    }

    /// - Parameters:
    ///   - privateKeyBase64: from VendorKeyStore.loadPrivateKeyBase64()
    ///   - productID: the catalog item's `id` — never stored raw in the
    ///     serial, only its SHA-512[:4] hash (see LicenseCore.productHash)
    ///   - expiresAt: unix seconds, 0 = never expires
    ///   - machineIDBase32: the client's MachineID.display string, or nil
    ///     for an unlocked (any-machine) code
    ///   - platform: GDC-LICENSE-PLATFORM (Etapa 2) — `.any` produce un
    ///     payload v1 (22 octeti, identic byte-cu-byte cu formatul dinainte
    ///     de aceasta schimbare, deci compatibil retroactiv); orice altă
    ///     valoare produce v2 (23 octeti, byte de platforma adaugat la
    ///     final). Alegerea e permanenta pentru codul generat.
    static func generate(privateKeyBase64: String, productID: String,
                          expiresAt: Int64 = 0, machineIDBase32: String? = nil,
                          platform: LicenseCore.LicensePlatform = .any) throws -> String {
        guard let keyData = Data(base64Encoded: privateKeyBase64),
              let privateKey = try? Curve25519.Signing.PrivateKey(rawRepresentation: keyData) else {
            throw GenerationError.invalidPrivateKey
        }

        let productHash = LicenseCore.productHash(for: productID)

        var expiryBytes = [UInt8](repeating: 0, count: 8)
        var value = UInt64(bitPattern: expiresAt)
        for i in stride(from: 7, through: 0, by: -1) {
            expiryBytes[i] = UInt8(value & 0xFF)
            value >>= 8
        }

        let nonce = (0..<4).map { _ in UInt8.random(in: 0...255) }

        let machineHash: [UInt8]
        if let machineIDBase32, !machineIDBase32.isEmpty {
            guard let decoded = LicenseCore.base32Decode(machineIDBase32), decoded.count == 6 else {
                throw GenerationError.invalidMachineID
            }
            machineHash = Array(decoded)
        } else {
            machineHash = [UInt8](repeating: 0, count: 6)
        }

        var payloadBytes = productHash
        payloadBytes.append(contentsOf: expiryBytes)
        payloadBytes.append(contentsOf: nonce)
        payloadBytes.append(contentsOf: machineHash)
        if platform != .any {
            payloadBytes.append(platform.rawValue)
            precondition(payloadBytes.count == LicenseCore.payloadSizeV2, "payload size drifted from LicenseCore")
        } else {
            precondition(payloadBytes.count == LicenseCore.payloadSize, "payload size drifted from LicenseCore")
        }

        let signature = try privateKey.signature(for: Data(payloadBytes))
        var packed = payloadBytes
        packed.append(contentsOf: signature)

        return formatSerial(LicenseCore.base32Encode(Data(packed)))
    }

    /// Groups Base32 output into dash-separated 4-character chunks,
    /// matching Python's `_format_serial` — purely cosmetic, the decoder
    /// strips dashes regardless, but keeps codes from either tool
    /// visually consistent.
    private static func formatSerial(_ base32: String) -> String {
        var groups: [String] = []
        var current = base32.startIndex
        while current < base32.endIndex {
            let end = base32.index(current, offsetBy: 4, limitedBy: base32.endIndex) ?? base32.endIndex
            groups.append(String(base32[current..<end]))
            current = end
        }
        return groups.joined(separator: "-")
    }
}
