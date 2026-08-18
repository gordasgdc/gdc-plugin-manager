import Foundation

/// Reads the Ed25519 private key already used across every GDC product
/// (CursorPro, GDC Production Manager, DataMover, this app's own client)
/// — generated once by gdc-license-system's keygen.py / GDC License
/// Manager, never regenerated here. Vendor-target only; never linked
/// into the client executable.
enum VendorKeyStore {
    enum KeyError: Error, LocalizedError {
        case notFound(String)
        case malformed

        var errorDescription: String? {
            switch self {
            case .notFound(let path):
                return "Nu am găsit cheia privată la \(path) — pornește GDC License Manager o dată ca să genereze una."
            case .malformed:
                return "Cheia privată de pe disc nu are formatul așteptat."
            }
        }
    }

    private static var privateKeyURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("GDC License Manager", isDirectory: true)
            .appendingPathComponent("private_key.txt")
    }

    /// Base64 of the raw 32-byte Ed25519 seed — same format
    /// `generate_serial_compact`/`LicenseCore` expect.
    static func loadPrivateKeyBase64() throws -> String {
        let url = privateKeyURL
        guard let raw = try? String(contentsOf: url, encoding: .utf8) else {
            throw KeyError.notFound(url.path)
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw KeyError.malformed }
        return trimmed
    }
}
