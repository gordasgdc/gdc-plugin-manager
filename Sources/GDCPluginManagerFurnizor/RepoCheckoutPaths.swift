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
    static var privateFilesRepo: URL { developerDir.appendingPathComponent("gdc-plugin-manager-files") }

    /// [2026-09-14] Arhitectura multi-repo: fiecare tip de resursa are repo-ul
    /// lui privat, ca sa nu atingem limitele de dimensiune ale unuia singur.
    /// Cheia e ACEEASI cu cea din catalog (`PluginFile.repo`) si cu cea din
    /// `PrivateCatalogAuth.repos` — o singura sursa de adevar pentru nume.
    static var resourceRepoCheckouts: [String: URL] { [
        "files":   privateFilesRepo,
        "pdfs":    developerDir.appendingPathComponent("gdc-plugin-manager-pdfs"),
        "scripts": developerDir.appendingPathComponent("gdc-plugin-manager-scripts"),
        "resources": developerDir.appendingPathComponent("gdc-plugin-manager-resources"),
    ] }

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

    /// DOAR pentru teste: redirecționează toate checkout-urile sub o rădăcină temporară
    /// (aceeași structură ca ~/Developer). `nil` în aplicație.
    static var testRoot: URL?

    private static var developerDir: URL {
        testRoot ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Developer")
    }

    /// gordasgdc/gdc-plugin-manager (public) — only docs/ is touched here, never the app source.
    ///
    /// D2 (2026-09-25): checkout DEDICAT publicării, nu repo-ul de dezvoltare. Înainte era
    /// `~/Developer/gdc-plugin-manager-catalog-vendor`, iar publicarea mergea pe ramura lui activă
    /// (ex. o ramură de release) și putea atinge fișiere în lucru. Clonă parțială, doar `docs/`
    /// (sparse), pe `main` — vezi `missingCheckoutMessage` pentru crearea ei.
    static var publicCatalogRepo: URL { developerDir
        .appendingPathComponent("_gdc-publish")
        .appendingPathComponent("gdc-plugin-manager") }

    static let publicCatalogSlug = "gordasgdc/gdc-plugin-manager"

    /// Repo-ul așteptat al unui checkout de publicare + ce poate conține nepublicat.
    /// `nil` = nu e un checkout de publicare → orice operație git de publicare e refuzată.
    static func publishTarget(for directory: URL) -> GitOps.PublishTarget? {
        let path = directory.standardizedFileURL.path
        if path == publicCatalogRepo.standardizedFileURL.path {
            return .init(repoSlug: publicCatalogSlug, allowedDirtyPrefixes: ["docs/"])
        }
        for (key, url) in resourceRepoCheckouts where url.standardizedFileURL.path == path {
            return .init(repoSlug: "gordasgdc/gdc-plugin-manager-\(key)", allowedDirtyPrefixes: nil)
        }
        return nil
    }

    static func missingCheckoutMessage(path: String, repoSlug: String) -> String {
        if repoSlug == publicCatalogSlug {
            return """
            Checkout-ul de publicare a catalogului lipsește (\(path)).
            Creează-l o singură dată (clonă parțială, doar docs/, pe main):
                git clone --filter=blob:none --sparse --branch main https://github.com/\(repoSlug).git "\(path)"
                git -C "\(path)" sparse-checkout set docs
            """
        }
        return """
        Checkout-ul de publicare \(repoSlug) lipsește (\(path)).
        Clonează-l o singură dată:
            gh repo clone \(repoSlug) "\(path)"
        """
    }

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
