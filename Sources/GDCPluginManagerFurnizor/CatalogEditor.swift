import Foundation
import GDCPluginManagerCore

/// Reads/writes docs/catalog.json in the local public-repo checkout —
/// the same file the client app fetches (unauthenticated) from GitHub
/// Pages. Only this file is touched in that checkout; app source lives
/// in a separate working tree entirely (see RepoCheckoutPaths).
enum CatalogEditor {
    static func load() throws -> Catalog {
        let data = try Data(contentsOf: RepoCheckoutPaths.catalogJSONURL)
        return try JSONDecoder().decode(Catalog.self, from: data)
    }

    /// Adds a new item, or replaces the existing one with the same `id`
    /// (an update — id, and therefore its crypto product hash, never
    /// changes). Updates `updatedAt` to today.
    static func upsert(_ item: PluginItem) throws {
        var catalog = (try? load()) ?? Catalog(updatedAt: nil, items: [])
        var items = catalog.items.filter { $0.id != item.id }
        items.append(item)
        items.sort { $0.name < $1.name }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        catalog = Catalog(updatedAt: formatter.string(from: Date()), items: items)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(catalog)
        try data.write(to: RepoCheckoutPaths.catalogJSONURL)
    }
}
