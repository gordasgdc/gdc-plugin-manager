import Foundation
import GDCPluginManagerCore

/// [2026-10-04] Publicarea unui RELEASE DE PRODUS GDC STYLE Lab V3 (un item de catalog per produs comercial, Demo + Full ca ediții
/// ale aceluiași Product ID, toate variantele de pipeline). Intrarea = manifestul `gdc-product-release@1` scris de STYLE Lab
/// (identitățile vin de acolo, nu se tastează); ieșirea = `PluginItem` cu `ofxProduct` + fișierele în
/// `<productId>/<version>/<Full|Demo>/<folder>/…` în repo-ul `files`. Produs PLĂTIT: ediția Full cere serial la descărcare,
/// ediția Demo e gratuită (regula `isDemoPath` din `authorize-download`). Publicarea trece prin `PublishTransaction`
/// (preflight pe repo-uri, jurnal de reluare) și doar la acțiunea explicită a lui Cristi — niciodată automat.
enum StyleLabProductPublisher {
    enum Failure: Error, LocalizedError, Equatable {
        case manifest(String)
        var errorDescription: String? { if case .manifest(let m) = self { return "Manifest STYLE Lab nevalid: \(m)" }; return nil }
    }

    struct Prepared {
        let release: OFXProductRelease
        let name: String
        let files: [(source: URL, repoPath: String)]
    }

    /// Citește și validează manifestul + fișierele de pe disc (pur, fără scriere). Refuză orice divergență: schema, identitatea
    /// de licență ≠ produs, identificatori ai altui produs / altei variante, pachet fără Info.plist sau cu altă identitate / versiune.
    static func prepare(manifest data: Data, releaseFolder: URL) throws -> Prepared {
        guard let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw Failure.manifest("nu e JSON") }
        guard o["schema"] as? String == "gdc-product-release@1" else { throw Failure.manifest("schema \(o["schema"] ?? "lipsă")") }
        guard let prod = o["product"] as? [String: Any], let pid = prod["productId"] as? String, let slug = prod["instrument"] as? String,
              let name = prod["name"] as? String, let version = prod["version"] as? String else { throw Failure.manifest("product") }
        guard (o["licence"] as? [String: Any])?["identity"] as? String == pid else { throw Failure.manifest("licence.identity ≠ productId") }
        let wf = prod["workflow"] as? [String: Any]
        let placement = (wf?["orderKey"] as? Int).map { OFXProductRelease.Placement(orderKey: $0, stage: wf?["stage"] as? String ?? "") }
        guard let vs = o["variants"] as? [[String: Any]], !vs.isEmpty else { throw Failure.manifest("variants") }
        var variants: [OFXProductRelease.Variant] = []
        var files: [(URL, String)] = []
        for v in vs {
            guard let vid = v["variantId"] as? String, let fam = v["family"] as? String, let label = v["label"] as? String, let slot = v["slot"] as? String,
                  let eds = v["editions"] as? [String: Any] else { throw Failure.manifest("variantă incompletă") }
            var editions: [String: OFXProductRelease.EditionPackage] = [:]
            for (k, val) in eds.sorted(by: { $0.key < $1.key }) {
                guard let e = OFXIdentity.Edition(rawValue: k), let p = (val as? [String: Any])?["package"] as? [String: Any],
                      let rel = p["folder"] as? String, let ident = p["identifier"] as? String, p["version"] as? String == version
                else { throw Failure.manifest("ediția \(k) a variantei \(vid)") }
                let folder = (rel as NSString).lastPathComponent
                let sub = e == .full ? "Full" : "Demo"
                guard rel == "\(sub)/\(folder)" else { throw Failure.manifest("folder \(rel)") }
                let bundle = releaseFolder.appendingPathComponent(rel)
                let plist = NSDictionary(contentsOf: bundle.appendingPathComponent("Contents/Info.plist"))
                guard plist?["CFBundleIdentifier"] as? String == ident, plist?["CFBundleShortVersionString"] as? String == version
                else { throw Failure.manifest("pachetul \(rel) de pe disc nu corespunde manifestului (identitate / versiune)") }
                let root = "\(pid)/\(version)/\(sub)/\(folder)"
                editions[k] = .init(folder: folder, identifier: ident, root: root)
                for (u, r) in DemoPublisher.files(under: bundle) { files.append((u, root + "/" + r)) }
            }
            variants.append(.init(variantId: vid, family: fam, label: label, slot: slot, editions: editions))
        }
        let release = OFXProductRelease(productId: pid, instrument: slug, version: version, variants: variants, placement: placement)
        if let problem = release.validate(itemID: pid, itemVersion: version) { throw Failure.manifest("\(problem)") }
        return Prepared(release: release, name: name, files: files)
    }

    /// Itemul de catalog: metadatele existente (copertă, descriere, sumă de susținere, acces, linkuri) se păstrează la actualizare.
    static func item(_ p: Prepared, files: [PluginFile], existing: PluginItem?, description: String, defaultDonationEUR: Double) -> PluginItem {
        PluginItem(id: p.release.productId, name: existing?.name ?? p.name, type: .ofx, description: existing?.description ?? description,
                   version: p.release.version, files: files, iconSymbol: existing?.iconSymbol, priceEUR: existing?.priceEUR ?? defaultDonationEUR,
                   isFree: false, isTrial: false, youtubeURL: existing?.youtubeURL, bundleFolderName: nil, coverImage: existing?.coverImage,
                   supportedOS: .macOS, purchaseURL: existing?.purchaseURL, demoURL: existing?.demoURL, socialLinks: existing?.socialLinks,
                   scheduling: existing?.scheduling, promoPriceEUR: existing?.promoPriceEUR, access: existing?.access, ofxProduct: p.release)
    }

    /// Publică trimiterile de produs date (acțiune explicită). Produs existent cu aceeași versiune sau una mai nouă = refuz
    /// (versiunea produsului vine din STYLE Lab și nu se „ridică” aici: un bump fără cod ar minți clientul — Regula 14).
    @discardableResult
    static func publish(_ subs: [StyleLabSubmission]) -> [DemoPublisher.Result] {
        var results: [DemoPublisher.Result] = []
        guard !subs.isEmpty else { return results }
        do {
            try PublishTransaction.preflight(repoKeys: ["files"])
            let catalog = try CatalogEditor.load()
            var items: [PluginItem] = [], sources: [(URL, PublishTransaction.FileRef)] = [], done: [(StyleLabSubmission, DemoPublisher.Result)] = []
            for s in subs where s.isOFXProduct {
                do {
                    guard let mp = s.manifestPath else { throw Failure.manifest("manifestPath lipsă") }
                    let prepared = try prepare(manifest: Data(contentsOf: URL(fileURLWithPath: mp)), releaseFolder: URL(fileURLWithPath: s.bundlePath))
                    let existing = (catalog.items + catalog.scriptItems).first { $0.id == prepared.release.productId }
                    if let e = existing, !DemoPublisher.isNewer(prepared.release.version, than: e.version) {
                        throw Failure.manifest("versiunea \(prepared.release.version) nu e mai nouă decât cea publicată \(e.version)")
                    }
                    var pf: [PluginFile] = []
                    for (u, path) in prepared.files {
                        let ref = PublishTransaction.FileRef(repoKey: "files", path: path, sha256: try PublishTransaction.sha256(of: u))
                        sources.append((u, ref)); pf.append(PluginFile(path: ref.path, sha256: ref.sha256, repo: "files"))
                    }
                    items.append(item(prepared, files: pf, existing: existing, description: s.description, defaultDonationEUR: 23))
                    done.append((s, DemoPublisher.Result(id: prepared.release.productId, name: prepared.name, version: prepared.release.version,
                                                         status: existing == nil ? "new" : "updated", message: existing == nil ? "produs nou" : "actualizat \(existing!.version) → \(prepared.release.version)")))
                } catch {
                    results.append(DemoPublisher.Result(id: s.id, name: s.name, version: s.version, status: "error", message: error.localizedDescription))
                }
            }
            if !done.isEmpty {
                let label = done.map { "\($0.1.id) \($0.1.version)" }.joined(separator: ", ")
                try PublishTransaction.publish(label: "STYLE Lab: \(label)", sources: sources, files: sources.map(\.1),
                                               catalog: .upsertItems(items), catalogMessage: "Catalog: \(label)", catalogPaths: ["docs/catalog.json", "docs/covers"])
                for (s, r) in done { StyleLabInbox.remove(id: s.id); results.append(r) }
            }
        } catch {
            for s in subs where !results.contains(where: { $0.id == s.id }) {
                results.append(DemoPublisher.Result(id: s.id, name: s.name, version: s.version, status: "error", message: error.localizedDescription))
            }
        }
        return results
    }
}
