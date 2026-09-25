import Foundation
import AppKit
import GDCPluginManagerCore

/// Cine folosește fiecare imagine din `docs/covers/`.
///
/// DE CE SE CITEȘTE JSON-UL BRUT, nu modelul tipizat: `coverImage` există pe
/// nouă tipuri diferite din catalog (produse, cursuri, tutoriale, materiale,
/// evenimente, magazine, service, oferte, pachete) și va exista pe al zecelea
/// care se adaugă. O listă scrisă de mână aici ar rămâne în urmă tăcut, iar
/// consecința e cea mai rea posibilă pentru un ecran care oferă ȘTERGEREA:
/// o imagine folosită de un tip nou ar apărea „nefolosită" și ar fi ștearsă
/// de sub el. Parcurgerea recursivă a JSON-ului găsește orice `coverImage`,
/// indiferent unde apare și indiferent când a fost adăugat tipul.
@MainActor
enum ImageLibraryScanner {

    struct Usage: Identifiable, Hashable {
        var id: String { "\(ownerID)/\(ownerName)" }
        let ownerID: String
        let ownerName: String
    }

    struct LibraryImage: Identifiable {
        var id: String { fileURL.lastPathComponent }
        let fileURL: URL
        /// Valoarea gata de scris în `coverImage`, cu cache-bust din conținut.
        let catalogValue: String
        let bytes: Int64
        let pixelSize: CGSize?
        let usages: [Usage]

        var filename: String { fileURL.lastPathComponent }
        var isUnused: Bool { usages.isEmpty }
    }

    /// Toate imaginile din bibliotecă, cu utilizatorii lor.
    static func scan() -> [LibraryImage] {
        let referenced = referencedFilenames()

        return CoverImageStore.libraryEntries().map { entry in
            let filename = entry.fileURL.lastPathComponent
            let attributes = try? FileManager.default.attributesOfItem(atPath: entry.fileURL.path)
            return LibraryImage(
                fileURL: entry.fileURL,
                catalogValue: entry.catalogValue,
                bytes: (attributes?[.size] as? NSNumber)?.int64Value ?? 0,
                pixelSize: pixelSize(of: entry.fileURL),
                usages: referenced[filename] ?? []
            )
        }
    }

    /// Numele de fișier referit → cine îl referă. Cheia e DOAR numele
    /// fișierului: valoarea din catalog poartă și folderul, și un sufix
    /// `?v=<hash>` care se schimbă la fiecare reîncărcare a aceleiași
    /// coperți. O comparație pe valoarea întreagă ar rata exact imaginile
    /// înlocuite recent — adică pe cele mai active.
    static func referencedFilenames() -> [String: [Usage]] {
        var result: [String: [Usage]] = [:]

        for url in [RepoCheckoutPaths.catalogJSONURL, RepoCheckoutPaths.launchBannerJSONURL] {
            guard let data = try? Data(contentsOf: url),
                  let root = try? JSONSerialization.jsonObject(with: data) else { continue }
            walk(root, into: &result)
        }
        return result
    }

    private static func walk(_ node: Any, into result: inout [String: [Usage]]) {
        if let dictionary = node as? [String: Any] {
            for key in ["coverImage", "imageURL", "image"] {
                guard let value = dictionary[key] as? String,
                      !value.isEmpty,
                      !CatalogAssets.isExternal(value) else { continue }
                let filename = ((value.split(separator: "?").first.map(String.init) ?? value) as NSString)
                    .lastPathComponent
                let usage = Usage(
                    ownerID: dictionary["id"] as? String ?? "—",
                    ownerName: dictionary["name"] as? String
                        ?? dictionary["title"] as? String
                        ?? dictionary["id"] as? String
                        ?? "(fără nume)"
                )
                if !result[filename, default: []].contains(usage) {
                    result[filename, default: []].append(usage)
                }
            }
            for value in dictionary.values { walk(value, into: &result) }
        } else if let array = node as? [Any] {
            for value in array { walk(value, into: &result) }
        }
    }

    /// Dimensiunea în pixeli, citită din metadate — fără a decoda imaginea.
    private static func pixelSize(of url: URL) -> CGSize? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Double,
              let height = properties[kCGImagePropertyPixelHeight] as? Double else { return nil }
        return CGSize(width: width, height: height)
    }

    // MARK: Ștergerea

    enum DeleteError: LocalizedError {
        case stillInUse([Usage])
        var errorDescription: String? {
            switch self {
            case .stillInUse(let usages):
                return "Imaginea e folosită de: \(usages.map(\.ownerName).joined(separator: ", ")). Schimbă întâi coperta acolo."
            }
        }
    }

    /// Șterge imaginea din checkout-ul public ȘI publică ștergerea.
    ///
    /// Publicarea e obligatorie aici: coperile stau în repo-ul public servit
    /// prin GitHub Pages, deci o ștergere doar locală ar lăsa fișierul viu pe
    /// site până la următoarea publicare de produs — adică exact imaginea pe
    /// care tocmai ai decis să n-o mai vrei.
    static func delete(_ image: LibraryImage) throws {
        guard image.isUnused else { throw DeleteError.stillInUse(image.usages) }

        let repo = RepoCheckoutPaths.publicCatalogRepo
        let relativePath = "docs/\(CatalogAssets.coversFolderName)/\(image.filename)"

        // O imagine poate exista pe disc FĂRĂ să fie în git: publicarea
        // scrie coperta înainte de commit, deci o publicare întreruptă lasă
        // fișierul netrackuit. `git rm` ar eșua acolo cu „did not match any
        // files" — un mesaj care nu spune nimic despre cauza reală. Cazul se
        // tratează explicit: nu e nimic de publicat, doar de șters de pe disc.
        let isTracked = (try? GitOps.run(["ls-files", "--error-unmatch", "--", relativePath], at: repo)) != nil
        guard isTracked else {
            try FileManager.default.removeItem(at: image.fileURL)
            return
        }

        // `git rm` (nu `FileManager.removeItem` + `commitAndPush`): acela
        // filtrează căile inexistente înainte de `git add`, iar o cale
        // ȘTEARSĂ nu mai există — ștergerea n-ar fi ajuns niciodată în index,
        // iar commit-ul ar fi fost gol sau ar fi măturat alte modificări.
        try GitOps.verifyPublishCheckout(at: repo)   // D2: repo corect, main, fără modificări străine
        try GitOps.run(["rm", "--", relativePath], at: repo)
        try GitOps.run(["commit", "-m", "Sterge coperta nefolosita \(image.filename)", "--", relativePath], at: repo)
        try GitOps.push(at: repo)
    }
}
