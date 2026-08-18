import Foundation
import GDCPluginManagerCore

/// Read-only access to the analytics backend, using the `service_role`
/// key (see SupabaseAdminConfig.swift) — this bypasses Row Level
/// Security, so it can actually list rows, unlike the client app's
/// insert-only anon key.
enum AnalyticsAdminError: Error, LocalizedError {
    case requestFailed(String)
    var errorDescription: String? {
        switch self {
        case .requestFailed(let detail): return "Cerere eșuată către Supabase: \(detail)"
        }
    }
}

struct DeviceRecord: Codable, Identifiable, Hashable {
    let machine_id: String
    let name: String?
    let email: String?
    let first_seen_at: String
    var id: String { machine_id }
}

struct DownloadEventRecord: Codable, Identifiable, Hashable {
    let id: Int
    let product_id: String
    let product_name: String
    let machine_id: String?
    let downloaded_at: String
}

enum AnalyticsAdminClient {
    static func fetchDevices() async throws -> [DeviceRecord] {
        try await fetch(table: "devices", query: "select=*&order=first_seen_at.desc")
    }

    /// Capped at 20k rows — plenty of headroom for this scale, and keeps
    /// one bad query from pulling down an unbounded table forever.
    static func fetchDownloadEvents() async throws -> [DownloadEventRecord] {
        try await fetch(table: "download_events", query: "select=*&order=downloaded_at.desc&limit=20000")
    }

    private static func fetch<T: Decodable>(table: String, query: String) async throws -> [T] {
        guard SupabaseAdminConfig.serviceRoleKey != "PASTE_SERVICE_ROLE_KEY_HERE" else {
            throw AnalyticsAdminError.requestFailed("Cheia service_role nu a fost completată încă în SupabaseAdminConfig.swift.")
        }
        guard var components = URLComponents(url: SupabaseConfig.restURL(table: table), resolvingAgainstBaseURL: false) else {
            throw AnalyticsAdminError.requestFailed("URL invalid")
        }
        components.query = query
        guard let url = components.url else { throw AnalyticsAdminError.requestFailed("URL invalid") }

        var request = URLRequest(url: url)
        request.setValue(SupabaseAdminConfig.serviceRoleKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(SupabaseAdminConfig.serviceRoleKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "necunoscut"
            throw AnalyticsAdminError.requestFailed(body)
        }
        return try JSONDecoder().decode([T].self, from: data)
    }
}

/// Parses PostgREST's ISO-8601 timestamps (with fractional seconds) —
/// shared by every view that needs to format or group these dates.
enum SupabaseDate {
    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let isoFormatterNoFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static func parse(_ string: String) -> Date? {
        isoFormatter.date(from: string) ?? isoFormatterNoFraction.date(from: string)
    }
}
