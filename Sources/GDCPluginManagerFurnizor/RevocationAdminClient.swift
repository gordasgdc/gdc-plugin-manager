import Foundation
import GDCPluginManagerCore

/// Administrare directă a tabelului `license_revocations` (vezi
/// supabase/migrations/2026-08-26_license_revocations.sql), folosind
/// service_role (bypass RLS) — la fel ca AnalyticsAdminClient.swift.
/// Aceasta e SINGURA suprafață care poate scrie/citi tabelul brut;
/// clienții (aplicațiile GDC) văd doar boolean-ul din RPC-ul
/// `is_license_revoked`, niciodată lista completă.
enum RevocationAdminError: Error, LocalizedError {
    case requestFailed(String)
    var errorDescription: String? {
        switch self {
        case .requestFailed(let detail): return "Cerere eșuată către Supabase: \(detail)"
        }
    }
}

struct RevocationRecord: Codable, Identifiable, Hashable {
    let id: Int
    let machine_id: String
    let product_id: String
    let revoked_at: String
    let reason: String?
}

enum RevocationAdminClient {
    static func fetchAll() async throws -> [RevocationRecord] {
        try await request(table: "license_revocations", method: "GET", query: "select=*&order=revoked_at.desc")
    }

    /// Revocă o licență pentru un `machineID`+`productID` — idempotent
    /// (indexul unic din migrare face un UPSERT sigur, nu duplică rânduri
    /// dacă apeși de două ori din greșeală).
    static func revoke(machineID: String, productID: String, reason: String) async throws {
        let body: [String: Any] = [
            "machine_id": machineID.trimmingCharacters(in: .whitespacesAndNewlines),
            "product_id": productID,
            "reason": reason.trimmingCharacters(in: .whitespacesAndNewlines),
        ]
        _ = try await request(
            table: "license_revocations", method: "POST", query: "on_conflict=machine_id,product_id",
            body: body, prefer: "resolution=merge-duplicates,return=minimal"
        ) as [RevocationRecord]
    }

    /// Anulează o revocare existentă (ex. sabotaj clarificat ulterior ca
    /// fals-pozitiv) — licența redevine validă la următoarea verificare
    /// online a clientului.
    static func unrevoke(id: Int) async throws {
        _ = try await request(table: "license_revocations", method: "DELETE", query: "id=eq.\(id)", prefer: "return=minimal") as [RevocationRecord]
    }

    @discardableResult
    private static func request<T: Decodable>(
        table: String, method: String, query: String,
        body: [String: Any]? = nil, prefer: String? = nil
    ) async throws -> [T] {
        guard SupabaseAdminConfig.serviceRoleKey != "PASTE_SERVICE_ROLE_KEY_HERE" else {
            throw RevocationAdminError.requestFailed("Cheia service_role nu a fost completată în SupabaseAdminConfig.swift.")
        }
        guard var components = URLComponents(url: SupabaseConfig.restURL(table: table), resolvingAgainstBaseURL: false) else {
            throw RevocationAdminError.requestFailed("URL invalid")
        }
        components.query = query
        guard let url = components.url else { throw RevocationAdminError.requestFailed("URL invalid") }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(SupabaseAdminConfig.serviceRoleKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(SupabaseAdminConfig.serviceRoleKey)", forHTTPHeaderField: "Authorization")
        if let prefer { request.setValue(prefer, forHTTPHeaderField: "Prefer") }
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let text = String(data: data, encoding: .utf8) ?? "necunoscut"
            throw RevocationAdminError.requestFailed(text)
        }
        if data.isEmpty { return [] }
        return (try? JSONDecoder().decode([T].self, from: data)) ?? []
    }
}
