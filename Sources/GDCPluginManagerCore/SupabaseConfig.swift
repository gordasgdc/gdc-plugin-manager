import Foundation

/// Connection details for the analytics backend (Supabase Postgres,
/// reached through its auto-generated PostgREST API — no SDK dependency,
/// just plain HTTP with an `apikey` header).
///
/// Unlike `PrivateCatalogAuth.swift`'s token, this file IS meant to ship
/// inside the public client app and IS safe to commit: the "anon" key
/// below carries no privilege on its own — every table it can reach has
/// Row Level Security enabled with an INSERT-only policy for the `anon`
/// role (see the setup SQL), so this key can add rows (a device
/// registration, a download event) and nothing else — no read, no
/// update, no delete. Real read access uses a separate `service_role`
/// key that lives only in the Furnizor app (never distributed) — see
/// GDCPluginManagerFurnizor/SupabaseAdminConfig.swift.
public enum SupabaseConfig {
    /// PASTE the Project URL from Supabase → Project Settings → API.
    public static let projectURL = "PASTE_SUPABASE_PROJECT_URL_HERE"

    /// PASTE the "anon public" key from the same page. Safe to commit —
    /// see the type-level doc above.
    public static let anonKey = "PASTE_SUPABASE_ANON_KEY_HERE"

    /// PostgREST's base path for a given table's REST endpoint.
    public static func restURL(table: String) -> URL {
        URL(string: projectURL)!.appendingPathComponent("rest/v1/\(table)")
    }
}
