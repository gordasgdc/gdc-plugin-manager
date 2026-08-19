import Foundation

struct UpdateInfo: Decodable {
    let version: String
    let release_date: String?
    let changes: String?
    let download_url: [String: String]
    let mandatory: Bool?
    let min_version: String?
}

/// Checks docs/update.json (same static-JSON pattern as gdc-production-manager)
/// for a newer app version than what's installed. Purely informational —
/// never blocks anything, just offers a banner + download link.
@MainActor
final class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()

    static let updateURL = URL(string: "https://gordas.dev/update.json")!

    @Published private(set) var availableUpdate: UpdateInfo?

    private var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    private let dismissedVersionKey = "gdcpm_dismissed_update_version"

    func check() async {
        guard let (data, response) = try? await URLSession.shared.data(from: Self.updateURL),
              let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
              let info = try? JSONDecoder().decode(UpdateInfo.self, from: data) else { return }

        guard Self.isNewer(info.version, than: currentVersion) else {
            availableUpdate = nil
            return
        }
        let dismissed = UserDefaults.standard.string(forKey: dismissedVersionKey)
        availableUpdate = (dismissed == info.version) ? nil : info
    }

    func dismiss() {
        guard let version = availableUpdate?.version else { return }
        UserDefaults.standard.set(version, forKey: dismissedVersionKey)
        availableUpdate = nil
    }

    /// Simple dot-separated integer version comparison (1.2.0 > 1.10.0
    /// is compared numerically per segment, not lexicographically).
    private static func isNewer(_ a: String, than b: String) -> Bool {
        let partsA = a.split(separator: ".").map { Int($0) ?? 0 }
        let partsB = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(partsA.count, partsB.count) {
            let x = i < partsA.count ? partsA[i] : 0
            let y = i < partsB.count ? partsB[i] : 0
            if x != y { return x > y }
        }
        return false
    }
}
