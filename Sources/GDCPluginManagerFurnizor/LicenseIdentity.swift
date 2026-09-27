import Foundation
import GDCPluginManagerCore

/// Identitatea comercială vs. identitatea criptografică a licențelor (2026-09-27).
///
/// DataMover a migrat la licențele generația 2: produsul rămâne „gdc-datamover” în catalog,
/// preț, registrul de vânzări, revocare și raportare, dar codurile noi se SEMNEAZĂ pentru
/// „gdc-datamover-license-v2”. DataMover 2.17+ refuză explicit codurile semnate cu ID-ul vechi
/// (LEGACY), deci Furnizor nu mai poate emite astfel de coduri. Cheia Ed25519 comună nu se
/// schimbă, iar celelalte produse GDC semnează în continuare cu propriul ID.
enum LicenseIdentity {
    static let dataMoverCanonicalID = "gdc-datamover"
    static let dataMoverSigningIDv2 = "gdc-datamover-license-v2"

    /// ID-ul folosit la semnare pentru un produs din catalog.
    static func signingProductID(for canonicalID: String) -> String {
        canonicalID == dataMoverCanonicalID ? dataMoverSigningIDv2 : canonicalID
    }

    /// DataMover generația 2 cere cod legat de un calculator.
    static func requiresMachineID(_ canonicalID: String) -> Bool { canonicalID == dataMoverCanonicalID }

    /// ID-uri care nu pot fi tastate manual (ar ocoli maparea de mai sus).
    static func isReservedCustomID(_ id: String) -> Bool { id.lowercased().hasPrefix(dataMoverCanonicalID) }

    enum Generation: Equatable { case legacyV1, v2, unknown }

    /// Generația unui serial DataMover din registru, după hash-ul de produs din payload
    /// (fără verificarea semnăturii și fără a afișa serialul).
    static func dataMoverGeneration(ofSerial serial: String) -> Generation {
        // Rândurile vechi importate pot avea terminații CRLF: „\r” rămâne în ultimul câmp (serialul).
        let cleaned = serial.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let packed = LicenseCore.base32Decode(cleaned), packed.count >= 4 else { return .unknown }
        let hash = Array(packed.prefix(4))
        if hash == LicenseCore.productHash(for: dataMoverSigningIDv2) { return .v2 }
        if hash == LicenseCore.productHash(for: dataMoverCanonicalID) { return .legacyV1 }
        return .unknown
    }
}
