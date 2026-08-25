import Foundation

/// Local checkouts the vendor app automates — deliberately separate from
/// ~/Developer/GDCPluginManager (the source code working tree), so
/// publishing a product never mixes with in-progress code edits.
///
/// MUTAT din ~/Downloads in ~/Developer (2026-08-25): ~/Downloads e curatat
/// automat de unelte precum CleanMyMac/Hazel pe acest Mac, si a sters cele
/// doua repo-uri de sursa in timpul unei sesiuni de lucru (recuperate din
/// Cos de gunoi). ~/Developer e locatia stabila pentru toate proiectele
/// GDC de acum inainte.
enum RepoCheckoutPaths {
    /// gordasgdc/gdc-plugin-manager-files (private) — where the actual
    /// product files (.dctl/.cube/.fuse) live, at <id>/<version>/<file>.
    static let privateFilesRepo = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Developer")
        .appendingPathComponent("gdc-plugin-manager-files")

    /// gordasgdc/gdc-plugin-manager (public) — only docs/catalog.json is
    /// touched here, never the app source.
    static let publicCatalogRepo = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Developer")
        .appendingPathComponent("gdc-plugin-manager-catalog-vendor")

    static var catalogJSONURL: URL {
        publicCatalogRepo.appendingPathComponent("docs").appendingPathComponent("catalog.json")
    }
}
