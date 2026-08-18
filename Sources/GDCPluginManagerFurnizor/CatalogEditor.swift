import Foundation
import GDCPluginManagerCore

enum CatalogEditorError: Error, LocalizedError {
    case itemNotFound(String)
    case courseNotFound(String)
    case appNotFound(String)

    var errorDescription: String? {
        switch self {
        case .itemNotFound(let id): return "Nu există niciun produs cu id-ul „\(id)” în catalog."
        case .courseNotFound(let id): return "Nu există niciun curs cu id-ul „\(id)” în catalog."
        case .appNotFound(let id): return "Nu există nicio aplicație cu id-ul „\(id)” în catalog."
        }
    }
}

/// Reads/writes docs/catalog.json in the local public-repo checkout —
/// the same file the client app fetches (unauthenticated) from GitHub
/// Pages. Only this file is touched in that checkout; app source lives
/// in a separate working tree entirely (see RepoCheckoutPaths).
enum CatalogEditor {
    static func load() throws -> Catalog {
        let data = try Data(contentsOf: RepoCheckoutPaths.catalogJSONURL)
        return try JSONDecoder().decode(Catalog.self, from: data)
    }

    // MARK: - Products (PluginItem)

    /// Adds a new item, or replaces the existing one with the same `id`
    /// (an update — id, and therefore its crypto product hash, never
    /// changes). Updates `updatedAt` to today.
    static func upsert(_ item: PluginItem) throws {
        let catalog = (try? load()) ?? Catalog(updatedAt: nil, items: [])
        var items = catalog.items.filter { $0.id != item.id }
        items.append(item)
        items.sort { $0.name < $1.name }
        try write(items: items, courses: catalog.courses, apps: catalog.apps)
    }

    /// Removes an item entirely — for a product published by mistake, or
    /// pulled from sale. Does NOT touch the files in the private repo;
    /// callers that also want those gone should remove that folder
    /// themselves (see PublishView.deleteProduct).
    static func remove(id: String) throws {
        let catalog = try load()
        let items = catalog.items.filter { $0.id != id }
        guard items.count != catalog.items.count else {
            throw CatalogEditorError.itemNotFound(id)
        }
        try write(items: items, courses: catalog.courses, apps: catalog.apps)
    }

    // MARK: - Courses

    static func upsertCourse(_ course: Course) throws {
        let catalog = (try? load()) ?? Catalog(updatedAt: nil, items: [])
        var courses = catalog.courses.filter { $0.id != course.id }
        courses.append(course)
        courses.sort { $0.name < $1.name }
        try write(items: catalog.items, courses: courses, apps: catalog.apps)
    }

    static func removeCourse(id: String) throws {
        let catalog = try load()
        let courses = catalog.courses.filter { $0.id != id }
        guard courses.count != catalog.courses.count else {
            throw CatalogEditorError.courseNotFound(id)
        }
        try write(items: catalog.items, courses: courses, apps: catalog.apps)
    }

    // MARK: - App links

    static func upsertApp(_ app: AppLink) throws {
        let catalog = (try? load()) ?? Catalog(updatedAt: nil, items: [])
        var apps = catalog.apps.filter { $0.id != app.id }
        apps.append(app)
        apps.sort { $0.name < $1.name }
        try write(items: catalog.items, courses: catalog.courses, apps: apps)
    }

    static func removeApp(id: String) throws {
        let catalog = try load()
        let apps = catalog.apps.filter { $0.id != id }
        guard apps.count != catalog.apps.count else {
            throw CatalogEditorError.appNotFound(id)
        }
        try write(items: catalog.items, courses: catalog.courses, apps: apps)
    }

    // MARK: - Write

    private static func write(items: [PluginItem], courses: [Course], apps: [AppLink]) throws {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let catalog = Catalog(updatedAt: formatter.string(from: Date()), items: items, courses: courses, apps: apps)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(catalog)
        try data.write(to: RepoCheckoutPaths.catalogJSONURL)
    }
}
