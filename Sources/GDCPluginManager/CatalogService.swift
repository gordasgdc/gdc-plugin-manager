import Foundation
import GDCPluginManagerCore

/// Fetches the plugin catalog from GitHub Pages, with a local cache so
/// the app still shows something (marked stale) if offline.
@MainActor
final class CatalogService: ObservableObject {
    static let shared = CatalogService()

    static let catalogURL = URL(string: "https://gordasgdc.github.io/gdc-plugin-manager/catalog.json")!

    @Published private(set) var items: [PluginItem] = []
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
            let (data, response) = try await URLSession.shared.data(from: Self.catalogURL)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                throw URLError(.badServerResponse)
            }
            let catalog = try JSONDecoder().decode(Catalog.self, from: data)
            items = catalog.items
            saveToCache(data: data)
        } catch {
            // Keep whatever was already loaded from cache — only surface
            // the error if we have nothing at all to show.
            if items.isEmpty {
                loadError = L.t("catalog.error")
            }
        }
    }

    private func loadFromCache() {
        guard let data = try? Data(contentsOf: cacheFileURL),
              let catalog = try? JSONDecoder().decode(Catalog.self, from: data) else { return }
        items = catalog.items
    }

    private func saveToCache(data: Data) {
        try? FileManager.default.createDirectory(at: cacheFileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: cacheFileURL)
    }
}
