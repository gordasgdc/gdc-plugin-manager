import Foundation
import GDCPluginManagerCore

/// Tracks when the embedded read-only GitHub token (PrivateCatalogAuth,
/// in Core — the client app's only way to fetch product files) expires,
/// so Cristi gets warned well before it lapses and breaks every
/// installed copy of the client app.
///
/// Deliberately does NOT store a manually-entered "generated on" date —
/// GitHub's own API tells us the real expiration directly: any
/// authenticated response made with a fine-grained PAT carries a
/// `github-authentication-token-expiration` response header (confirmed
/// live against this exact token before writing this file — not
/// assumed from docs). Reading it live means this can never drift out
/// of sync with reality, even if the token is rotated without anyone
/// remembering to update a stored date.
@MainActor
final class GitHubTokenStatus: ObservableObject {
    static let shared = GitHubTokenStatus()

    @Published private(set) var expiresAt: Date?
    @Published private(set) var checkFailed = false

    private init() {}

    var daysRemaining: Int? {
        guard let expiresAt else { return nil }
        let seconds = expiresAt.timeIntervalSinceNow
        return Int((seconds / 86400).rounded(.down))
    }

    /// Thresholds match what Cristi asked for: quiet until 30 days out,
    /// then a visible warning, red past 14.
    enum Severity { case ok, warning, critical, unknown }

    var severity: Severity {
        guard let daysRemaining else { return checkFailed ? .unknown : .ok }
        if daysRemaining <= 14 { return .critical }
        if daysRemaining <= 30 { return .warning }
        return .ok
    }

    func check() async {
        checkFailed = false
        var request = URLRequest(url: URL(string: "https://api.github.com/repos/\(PrivateCatalogAuth.owner)/\(PrivateCatalogAuth.repo)")!)
        request.setValue("Bearer \(PrivateCatalogAuth.token)", forHTTPHeaderField: "Authorization")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")

        guard let (_, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              let raw = http.value(forHTTPHeaderField: "github-authentication-token-expiration") else {
            checkFailed = true
            return
        }
        expiresAt = Self.parse(raw)
        if expiresAt == nil { checkFailed = true }
    }

    /// GitHub sends this as e.g. "2027-08-16 22:00:00 UTC" - not a
    /// standard ISO-8601 string, so it needs its own formatter.
    private static func parse(_ raw: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss 'UTC'"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.date(from: raw)
    }
}
