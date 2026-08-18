import Foundation
import GDCPluginManagerCore

/// Fire-and-forget writes to the analytics backend (Supabase) — a
/// registration row (`devices`) and a download event (`download_events`).
/// Both tables only accept INSERT from the anon key (see
/// SupabaseConfig.swift), so this can never read, overwrite, or delete
/// anything, and both calls swallow their own errors: analytics must
/// never be able to break an install or block the app on a bad network.
enum AnalyticsClient {
    static func registerDevice(name: String, email: String) {
        let body: [String: Any] = [
            "machine_id": MachineID.display,
            "name": name.trimmingCharacters(in: .whitespacesAndNewlines),
            "email": email.trimmingCharacters(in: .whitespacesAndNewlines),
        ]
        post(table: "devices", body: body)
    }

    static func logDownload(productID: String, productName: String) {
        let body: [String: Any] = [
            "product_id": productID,
            "product_name": productName,
            "machine_id": MachineID.display,
        ]
        post(table: "download_events", body: body)
    }

    private static func post(table: String, body: [String: Any]) {
        guard SupabaseConfig.projectURL.hasPrefix("https://"),
              let data = try? JSONSerialization.data(withJSONObject: body) else {
            return // config not filled in yet, or bad payload - fail silently
        }
        var request = URLRequest(url: SupabaseConfig.restURL(table: table))
        request.httpMethod = "POST"
        request.httpBody = data
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        // Skip PostgREST's default "return the inserted row" response -
        // this is fire-and-forget, the app never reads the result.
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")

        URLSession.shared.dataTask(with: request) { _, _, _ in
            // Deliberately ignored - see the type doc above.
        }.resume()
    }
}
