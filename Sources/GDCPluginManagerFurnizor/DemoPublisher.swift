import Foundation
import CryptoKit
import GDCPluginManagerCore

/// Publicare directă a pachetelor OFX Demo trimise de GDC STYLE Lab (`autoPublish`), fără formularul de publicare:
/// copiază fișierele în repo-ul privat, înregistrează/actualizează produsul în catalog (gratuit) și împinge o singură dată ambele repo-uri.
/// Produs existent (același cod `<cod>-demo`) → păstrează metadatele (copertă, acces, linkuri), înlocuiește fișierele și setează versiunea nouă
/// (cea din STYLE Lab, sau patch+1 peste cea publicată dacă aceasta nu e mai nouă) — indexul (`catalog.json`) se actualizează automat.
enum DemoPublisher {
    struct Result: Codable, Equatable {
        var id: String, name: String, version: String
        var status: String      // „new” | „updated” | „error”
        var message: String
    }

    static var resultURL: URL { StyleLabInbox.folder.appendingPathComponent("publish-result.json") }

    /// Versiunea de publicat: cea din STYLE Lab dacă e strict mai nouă decât cea publicată; altfel patch+1 peste cea publicată.
    static func targetVersion(submitted: String, published: String?) -> String {
        guard let p = published else { return submitted }
        return isNewer(submitted, than: p) ? submitted : PublishView.nextVersion(after: p)
    }

    static func isNewer(_ a: String, than b: String) -> Bool {
        let x = a.split(separator: ".").compactMap { Int($0) }, y = b.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(x.count, y.count) {
            let p = i < x.count ? x[i] : 0, q = i < y.count ? y[i] : 0
            if p != q { return p > q }
        }
        return false
    }

    static func files(under root: URL) -> [(URL, String)] {
        guard let en = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else { return [] }
        var out: [(URL, String)] = []
        for case let u as URL in en {
            if (try? u.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true { continue }
            out.append((u, String(u.path.dropFirst(root.path.count + 1))))
        }
        return out.sorted { $0.1 < $1.1 }
    }

    /// Rulează pe tot conținutul `autoPublish` din căsuță; întoarce și scrie rezultatele (`publish-result.json`).
    @discardableResult
    static func run() -> [Result] {
        let subs = StyleLabInbox.pending().filter { $0.autoPublish == true }
        var results: [Result] = []
        func finish() -> [Result] {
            try? JSONEncoder().encode(results).write(to: resultURL, options: .atomic)
            return results
        }
        guard !subs.isEmpty else { return finish() }
        do {
            let checkout = try RepoCheckoutPaths.resourceCheckout(for: "files")
            try GitOps.pull(at: checkout)
            try GitOps.pull(at: RepoCheckoutPaths.publicCatalogRepo)
            var catalog = try CatalogEditor.load()
            var published: [(StyleLabSubmission, Result)] = []
            for s in subs {
                let existing = (catalog.items + catalog.scriptItems).first { $0.id == s.id }
                let version = targetVersion(submitted: s.version, published: existing?.version)
                do {
                    guard s.id.hasSuffix("-demo") else { throw NSError(domain: "Demo", code: 1, userInfo: [NSLocalizedDescriptionKey: "Codul trebuie să se termine în „-demo”"]) }
                    let picked = files(under: URL(fileURLWithPath: s.bundlePath))
                    guard !picked.isEmpty else { throw NSError(domain: "Demo", code: 2, userInfo: [NSLocalizedDescriptionKey: "Pachetul e gol sau lipsește"]) }
                    var pf: [PluginFile] = []
                    for (u, rel) in picked {
                        let data = try Data(contentsOf: u)
                        let sha = SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
                        // Ca la publicarea manuală: calea e relativă la RĂDĂCINA pachetului (installer-ul creează singur folderul `bundleFolderName`); a-l repeta aici imbrica pachetul.
                        let path = "\(s.id)/\(version)/\(rel)"
                        let dest = checkout.appendingPathComponent(path)
                        try FileManager.default.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
                        try? FileManager.default.removeItem(at: dest)
                        try FileManager.default.copyItem(at: u, to: dest)
                        pf.append(PluginFile(path: path, sha256: sha, repo: "files"))
                    }
                    var cover = existing?.coverImage
                    if cover == nil, let c = s.coverFile, FileManager.default.fileExists(atPath: c) {
                        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("stylelab-cover-\(s.id).png")
                        try? FileManager.default.removeItem(at: tmp)
                        if (try? FileManager.default.copyItem(at: URL(fileURLWithPath: c), to: tmp)) != nil {
                            cover = try CoverImageStore.commit(.local(processed: tmp, savings: "din STYLE Lab"), id: s.id, previous: nil)
                        }
                    }
                    let item = PluginItem(
                        id: s.id, name: s.name, type: .ofx, description: s.description, version: version, files: pf,
                        iconSymbol: existing?.iconSymbol, priceEUR: 0, isFree: true, isTrial: false, youtubeURL: existing?.youtubeURL,
                        bundleFolderName: s.bundleFolderName, coverImage: cover, supportedOS: existing?.supportedOS ?? .macOS,
                        purchaseURL: existing?.purchaseURL, demoURL: existing?.demoURL, socialLinks: existing?.socialLinks,
                        scheduling: existing?.scheduling, promoPriceEUR: nil, access: existing?.access)
                    try CatalogEditor.upsert(item)
                    catalog = try CatalogEditor.load()
                    let r = Result(id: s.id, name: s.name, version: version, status: existing == nil ? "new" : "updated",
                                   message: existing == nil ? "înregistrat ca demo public" : "actualizat \(existing!.version) → \(version)")
                    published.append((s, r))
                } catch {
                    results.append(Result(id: s.id, name: s.name, version: version, status: "error", message: error.localizedDescription))
                }
            }
            if !published.isEmpty {
                let label = published.map { "\($0.0.id) \($0.1.version)" }.joined(separator: ", ")
                try GitOps.commitAndPush(at: checkout, message: "Demo: \(label)")
                try GitOps.commitAndPush(at: RepoCheckoutPaths.publicCatalogRepo, message: "Catalog: demo \(label)", paths: ["docs/catalog.json", "docs/covers"])
                for (s, r) in published { StyleLabInbox.remove(id: s.id); results.append(r) }
            }
        } catch {
            for s in subs where !results.contains(where: { $0.id == s.id }) {
                results.append(Result(id: s.id, name: s.name, version: s.version, status: "error", message: error.localizedDescription))
            }
        }
        return finish()
    }
}
