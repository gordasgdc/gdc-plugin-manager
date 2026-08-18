import Foundation

/// Local checkouts the vendor app automates — deliberately separate from
/// ~/Downloads/GDCPluginManager (the source code working tree), so
/// publishing a product never mixes with in-progress code edits.
enum RepoCheckoutPaths {
    /// gordasgdc/gdc-plugin-manager-files (private) — where the actual
    /// product files (.dctl/.cube/.fuse) live, at <id>/<version>/<file>.
    static let privateFilesRepo = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Downloads")
        .appendingPathComponent("gdc-plugin-manager-files")

    /// gordasgdc/gdc-plugin-manager (public) — only docs/catalog.json is
    /// touched here, never the app source.
    static let publicCatalogRepo = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Downloads")
        .appendingPathComponent("gdc-plugin-manager-catalog-vendor")

    static var catalogJSONURL: URL {
        publicCatalogRepo.appendingPathComponent("docs").appendingPathComponent("catalog.json")
    }
}
