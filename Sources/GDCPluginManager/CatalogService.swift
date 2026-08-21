import Foundation
import GDCPluginManagerCore

/// Fetches the plugin catalog from GitHub Pages, with a local cache so
/// the app still shows something (marked stale) if offline.
@MainActor
final class CatalogService: ObservableObject {
    static let shared = CatalogService()

    // gordas.dev e domeniul custom pt. gdc-plugin-manager (root) — URL direct,
    // fara sa mai depindem de redirect-ul GitHub gordasgdc.github.io -> gordas.dev
    // (care trecea prin Worker-ul de routing si dadea 404 pe fisiere de root).
    static let catalogURL = URL(string: "https://gordas.dev/catalog.json")!

    @Published private(set) var items: [PluginItem] = []
    @Published private(set) var courses: [Course] = []
    @Published private(set) var apps: [AppLink] = []
    @Published private(set) var educationalResources: [EducationalResource] = []
    @Published private(set) var events: [Event] = []
    @Published private(set) var partnerStores: [PartnerStore] = []
    @Published private(set) var isLoading = false
    @Published private(set) var loadError: String?

    private var cacheFileURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("GDCPluginManager", isDirectory: true)
            .appendingPathComponent("catalog-cache.json")
    }

    private init() {
        loadFromCache()
    }

    func refresh() async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }

        do {
            // GitHub Pages serves catalog.json with `cache-control: max-age=600`
            // — the default cache policy would silently honor that and could
            // serve a stale response even when the user explicitly asks to
            // refresh, so every refresh() call bypasses the local HTTP cache.
            var request = URLRequest(url: Self.catalogURL, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData)
            request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? -1
                throw CatalogFetchError.badStatus(code)
            }
            do {
                let catalog = try JSONDecoder().decode(Catalog.self, from: data)
                items = catalog.items
                courses = catalog.courses
                apps = catalog.apps
                educationalResources = catalog.educationalResources
                events = catalog.events
                partnerStores = catalog.partnerStores
                saveToCache(data: data)
            } catch {
                throw CatalogFetchError.decodeFailed
            }
        } catch {
            // Keep whatever was already loaded from cache — only surface
            // the error if we have nothing at all to show. Distinguish
            // WHY it failed instead of always blaming "check your
            // internet" — a decode failure (old app version, catalog
            // grew a type it doesn't know) or a bad server response need
            // a different fix than an actual network outage.
            guard items.isEmpty else { return }
            switch error {
            case CatalogFetchError.decodeFailed:
                loadError = L.t("catalog.error.parse")
            case CatalogFetchError.badStatus(let code):
                loadError = String(format: L.t("catalog.error.server"), code)
            default:
                loadError = L.t("catalog.error")
            }
        }
    }

    private enum CatalogFetchError: Error {
        case badStatus(Int)
        case decodeFailed
    }

    private func loadFromCache() {
        guard let data = try? Data(contentsOf: cacheFileURL),
              let catalog = try? JSONDecoder().decode(Catalog.self, from: data) else { return }
        items = catalog.items
        courses = catalog.courses
        apps = catalog.apps
        educationalResources = catalog.educationalResources
        events = catalog.events
        partnerStores = catalog.partnerStores
    }

    private func saveToCache(data: Data) {
        try? FileManager.default.createDirectory(at: cacheFileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: cacheFileURL)
    }
}
