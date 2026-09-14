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

    /// [2026-09-14] Arhitectura multi-repo: fiecare tip de resursa are repo-ul
    /// lui privat, ca sa nu atingem limitele de dimensiune ale unuia singur.
    /// Cheia e ACEEASI cu cea din catalog (`PluginFile.repo`) si cu cea din
    /// `PrivateCatalogAuth.repos` — o singura sursa de adevar pentru nume.
    static let resourceRepoCheckouts: [String: URL] = [
        "files":   privateFilesRepo,
        "pdfs":    developerDir.appendingPathComponent("gdc-plugin-manager-pdfs"),
        "scripts": developerDir.appendingPathComponent("gdc-plugin-manager-scripts"),
    ]

    /// Checkout-ul local pentru o cheie de repo. Arunca explicit daca clona
    /// lipseste — altfel Furnizor ar crea un folder gol si ar face push intr-un
    /// repo inexistent, esuand mult mai departe, cu un mesaj de neinteles.
    static func resourceCheckout(for key: String) throws -> URL {
        guard let url = resourceRepoCheckouts[key] else {
            throw RepoCheckoutError.unknownRepoKey(key)
        }
        guard FileManager.default.fileExists(atPath: url.appendingPathComponent(".git").path) else {
            throw RepoCheckoutError.missingCheckout(key, url.path)
        }
        return url
    }

    private static var developerDir: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Developer")
    }

    /// gordasgdc/gdc-plugin-manager (public) — only docs/catalog.json is
    /// touched here, never the app source.
    static let publicCatalogRepo = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Developer")
        .appendingPathComponent("gdc-plugin-manager-catalog-vendor")

    static var catalogJSONURL: URL {
        publicCatalogRepo.appendingPathComponent("docs").appendingPathComponent("catalog.json")
    }

    /// Preturi dinamice (2026-08-30) - vezi PricingModel/PricingEditor.
    /// Fisier separat de catalog.json (produse standalone, nu marketplace),
    /// dar in acelasi checkout/repo public, servit static prin GitHub Pages.
    static var pricingJSONURL: URL {
        publicCatalogRepo.appendingPathComponent("docs").appendingPathComponent("pricing.json")
    }

    /// Banner de lansare (2026-08-31) - vezi LaunchBannerModel/Editor.
    static var launchBannerJSONURL: URL {
        publicCatalogRepo.appendingPathComponent("docs").appendingPathComponent("launch-banner.json")
    }
}

enum RepoCheckoutError: Error, LocalizedError {
    case unknownRepoKey(String)
    case missingCheckout(String, String)

    var errorDescription: String? {
        switch self {
        case .unknownRepoKey(let key):
            return "Cheie de repo necunoscuta: „\(key)”."
        case .missingCheckout(let key, let path):
            return """
            Repo-ul de resurse „\(key)” nu e clonat local (\(path)).
            Cloneaza-l o singura data:
                gh repo clone gordasgdc/gdc-plugin-manager-\(key) \(path)
            """
        }
    }
}
