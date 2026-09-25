import Foundation
import CryptoKit

/// S1 (2026-09-25): descărcarea unui fișier de produs prin funcția
/// `authorize-download` (supabase/functions/authorize-download/CONTRACT.md).
/// Clientul NU are niciun credential de stocare: cere autorizare pentru UN
/// fișier, primește un URL temporar, descarcă fără antet de autentificare și
/// verifică SHA-256 din catalog. Autorizarea și verificarea integrității sunt
/// controale separate: un URL autorizat nu scutește fișierul de verificare.
public struct DownloadAuthorizer {
    public enum Failure: Error, Equatable {
        case invalidLicense, revokedLicense, unauthorizedPlatform, unauthorizedArtifact
        case unknownProduct, artifactUnavailable, rateLimited, malformedRequest
        case server(Int), network, checksumMismatch
    }

    public struct Authorization: Decodable, Equatable {
        public let url: String
        public let productID: String
        public let path: String
        public let sha256: String?
        public let size: Int?
    }

    public let endpoint: URL
    public let apiKey: String
    public let session: URLSession
    public let machineID: String
    public let platform: String
    public let clientVersion: String?

    public init(endpoint: URL = URL(string: SupabaseConfig.projectURL)!.appendingPathComponent("functions/v1/authorize-download"),
                apiKey: String = SupabaseConfig.anonKey, session: URLSession = .shared,
                machineID: String = MachineID.display, platform: String = "mac", clientVersion: String? = nil) {
        self.endpoint = endpoint
        self.apiKey = apiKey
        self.session = session
        self.machineID = machineID
        self.platform = platform
        self.clientVersion = clientVersion
    }

    public func authorize(productID: String, path: String, serial: String?) async throws -> Authorization {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        var body: [String: String] = ["productID": productID, "path": path, "machineID": machineID, "platform": platform]
        if let serial, !serial.isEmpty { body["serial"] = serial }
        if let clientVersion { body["clientVersion"] = clientVersion }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data: Data, response: URLResponse
        do { (data, response) = try await session.data(for: request) } catch { throw Failure.network }
        guard let http = response as? HTTPURLResponse else { throw Failure.network }
        guard http.statusCode == 200 else { throw Self.failure(status: http.statusCode, body: data) }
        guard let auth = try? JSONDecoder().decode(Authorization.self, from: data),
              auth.productID == productID, auth.path == path,
              let url = URL(string: auth.url), url.scheme == "https" else {
            throw Failure.server(http.statusCode)
        }
        return auth
    }

    /// Autorizare → descărcare → SHA-256. Dacă URL-ul temporar a expirat între
    /// emitere și folosire (403/404), se cere O singură autorizare nouă.
    public func fetch(productID: String, path: String, expectedSHA256: String?, serial: String?) async throws -> Data {
        for attempt in 0..<2 {
            let auth = try await authorize(productID: productID, path: path, serial: serial)
            var request = URLRequest(url: URL(string: auth.url)!)
            request.timeoutInterval = 120
            let data: Data, response: URLResponse
            do { (data, response) = try await session.data(for: request) } catch { throw Failure.network }
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            if (status == 403 || status == 404) && attempt == 0 { continue }
            guard (200...299).contains(status) else { throw Failure.artifactUnavailable }
            // Hash-ul din catalogul local are prioritate; cel de la server e rezerva.
            if let expected = [expectedSHA256, auth.sha256].compactMap({ $0?.lowercased() }).first(where: { !$0.isEmpty }) {
                let actual = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
                guard actual == expected else { throw Failure.checksumMismatch }
            }
            return data
        }
        throw Failure.artifactUnavailable
    }

    static func failure(status: Int, body: Data) -> Failure {
        let code = (try? JSONSerialization.jsonObject(with: body) as? [String: Any])?["error"] as? String
        switch code {
        case "invalid_license": return .invalidLicense
        case "revoked_license": return .revokedLicense
        case "unauthorized_platform": return .unauthorizedPlatform
        case "unauthorized_artifact": return .unauthorizedArtifact
        case "unknown_product": return .unknownProduct
        case "artifact_unavailable": return .artifactUnavailable
        case "rate_limited": return .rateLimited
        case "malformed_request": return .malformedRequest
        default: return .server(status)
        }
    }
}
