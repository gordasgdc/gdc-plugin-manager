import Foundation
import CryptoKit
import GDCPluginManagerCore

/// What actually happened after `install(_:)`/`remove(_:)` — for
/// everything except PowerGrade this is always the plain case (the
/// existing file-copy flow can't do anything else); PowerGrade can also
/// finish with files verified and on disk but needing one manual step,
/// because Resolve's scripting bridge wasn't available (see
/// PowerGradeImporter.swift).
enum InstallOutcome {
    /// [2026-09-14] Poarta caile REALE de pe disc, verificate dupa scriere —
    /// pana acum instalarea reusita nu spunea nimic utilizatorului, nici macar
    /// unde a ajuns fisierul (`case .installed: break` in ContentView).
    case installed(paths: [URL])
    /// PowerGrade only: imported straight into Resolve's Gallery, into
    /// this product's own album (see PowerGradeImporter.albumName(for:)).
    case installedToGallery(albumName: String)
    case installedNeedsManualStep(folder: URL)
}

enum RemoveOutcome: Equatable {
    case removed
    case removedNeedsManualGalleryCleanup
}

enum InstallError: Error, LocalizedError {
    case downloadFailed
    case authenticationFailed
    /// S1: serverul de autorizare a respins licența (invalidă, revocată, altă platformă).
    case licenseRejected
    /// S1: prea multe cereri de autorizare într-un interval scurt.
    case tooManyRequests
    case checksumMismatch
    /// [2026-09-14] Fișierul a fost scris, dar verificarea de după instalare
    /// nu confirmă că a ajuns întreg la destinație.
    case verificationFailed(String, String)
    case writeFailed(String)
    /// SECURITATE (raportat de Cristi 2026-08-24): un PowerGrade PLĂTIT a
    /// cărui import automat în Gallery eșuează NU mai are voie să lase pe
    /// disc fișierul .drx brut — vezi comentariul de la locul unde e
    /// aruncată, în `install(_:)`. Mesajul e intenționat generic (fără
    /// cale de fișier, fără instrucțiuni) — ContentView arată în plus
    /// butonul de contact WhatsApp pentru asistență manuală.
    case paidResourceInstallFailed

    var errorDescription: String? {
        switch self {
        case .downloadFailed: return "Download failed."
        case .authenticationFailed: return "Couldn't authenticate with the file server — contact support."
        case .licenseRejected: return L.t("install.error.licenseRejected")
        case .tooManyRequests: return L.t("install.error.rateLimited")
        case .checksumMismatch: return "Downloaded file doesn't match the expected checksum."
        case .verificationFailed(let path, let reason):
            return "Instalarea nu s-a confirmat: \(reason).\nCale: \(path)"
        case .writeFailed(let detail): return "Couldn't write the file: \(detail)"
        case .paidResourceInstallFailed: return "A apărut o eroare la încărcarea resursei plătite. Te rugăm să contactezi suportul pentru asistență."
        }
    }
}

/// Downloads a plugin, verifies it, and copies it into the DaVinci
/// Resolve folder its type belongs in (see `PluginType.installDirectory`
/// in CatalogModel.swift). Tries a direct write first — Resolve's own
/// plugin folders are usually user-writable even though they live under
/// the top-level /Library — and only asks for the admin password (via
/// the same native-dialog `osascript` pattern used elsewhere in this
/// developer's tools, never a scripted `sudo`) if that direct write is
/// actually refused.
@MainActor
final class InstallManager: ObservableObject {
    static let shared = InstallManager()

    /// [pluginId: installedVersion]
    @Published private(set) var installedVersions: [String: String] = [:]

    private var stateFileURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("GDCPluginManager", isDirectory: true)
            .appendingPathComponent("installed.json")
    }

    private init() {
        loadState()
    }

    func isInstalled(_ item: PluginItem) -> Bool {
        installedVersions[item.id] != nil
    }

    /// Versiunea instalată local (nil = neinstalat).
    func installedVersion(of item: PluginItem) -> String? {
        installedVersions[item.id]
    }

    func hasUpdate(_ item: PluginItem) -> Bool {
        guard let installed = installedVersions[item.id] else { return false }
        return installed != item.version
    }

    /// A pack (multiple files, e.g. a whole folder of LUTs published
    /// together) installs into its own subfolder, so it stays visually
    /// grouped in Resolve's own browser instead of scattering loose
    /// files at the root next to everything else. That subfolder is
    /// named after the product id for LUT/DCTL/Fuse packs — but for an
    /// OFX bundle it MUST keep its exact original `.ofx.bundle` folder
    /// name (`bundleFolderName`) instead, since that literal name is how
    /// Resolve identifies it. A single-file item installs flat, exactly
    /// as before — no behavior change for anything already published.
    private func destinationDirectory(for item: PluginItem) -> URL {
        let base = item.type.installDirectory
        // [2026-09-14] Scripturile NU intră într-un subfolder numit după id
        // (cum fac pack-urile de LUT/DCTL): Resolve citește meniul Scripts
        // direct din cele 7 subfoldere ale lui, iar un folder în plus ar
        // însemna un submeniu în plus, cu numele produsului — nu ce vrea
        // nimeni. Merg direct în subfolderul ales (implicit Utility), iar un
        // pachet care are DEJA structură proprie și-o păstrează prin
        // `relativeInstallPath`.
        if item.type == .scripts {
            return base.appendingPathComponent((item.scriptFolder ?? .default).rawValue)
        }
        guard item.isPack else { return base }
        return base.appendingPathComponent(item.bundleFolderName ?? item.id)
    }

    @discardableResult
    func install(_ item: PluginItem) async throws -> InstallOutcome {
        DiagnosticLog.write("Install", "start \(item.id) v\(item.version) (\(item.files.count) fișiere)")
        if item.type == .ofx, let product = item.ofxProduct { return try await installOFXProduct(item, product) }
        let destinationDir = destinationDirectory(for: item)
        var tempURLs: [URL] = []
        defer { for url in tempURLs { try? FileManager.default.removeItem(at: url) } }

        // Verify every file's checksum BEFORE writing anything, so a bad
        // file in a pack doesn't leave a half-installed folder behind.
        for file in item.files {
            let data = try await fetchAuthorizedFileData(productID: item.id, file: file)
            let actualSHA = SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
            guard actualSHA.lowercased() == file.sha256.lowercased() else {
                throw InstallError.checksumMismatch
            }
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try data.write(to: tempURL)
            tempURLs.append(tempURL)
        }

        // Pachet OFX (folder `.ofx.bundle`): aceeași instalare ATOMICĂ ca la produsele V3 — pregătit, verificat, pus în loc dintr-o singură operație, fără chown pe folderul de pluginuri.
        if item.type == .ofx, item.isPack {
            let root = item.type.installDirectory
            let folder = destinationDir.lastPathComponent
            guard destinationDir.deletingLastPathComponent().standardizedFileURL.path == root.standardizedFileURL.path, folder.hasSuffix(".ofx.bundle") else {
                throw InstallError.verificationFailed(item.name, "structura pachetului OFX")
            }
            let files = zip(item.files, tempURLs).map { (relativeInstallPath(for: $0.0, in: item), $0.1) }
            guard files.contains(where: { $0.0 == "Contents/Info.plist" }), files.allSatisfy({ OFXAtomicInstall.isSafeRelative($0.0) }) else {
                throw InstallError.verificationFailed(item.name, "structura pachetului OFX")
            }
            try atomicOFXInstall(root: root, bundles: [(folder, "", "", files)], removals: [])
            installedVersions[item.id] = item.version
            saveState()
            let bundlePathForCache = destinationDir.path
            Task.detached(priority: .utility) { ResolveOFXCache.forget(bundlePath: bundlePathForCache) }
            return .installed(paths: [destinationDir])
        }

        // [2026-09-14] CURATARE INAINTE DE SCRIERE, doar acolo unde folderul
        // apartine EXCLUSIV acestui produs. O versiune noua cu mai putine
        // fisiere decat cea veche lasa altfel resturi care raman incarcate de
        // Resolve la nesfarsit (un DCTL sters din pack ramanea pe disc).
        //
        // EXCEPTIE CRITICA — scripturile: destinatia lor (Fusion/Scripts/
        // Utility etc.) e un folder COMUN, al Resolve-ului, in care stau si
        // scripturile altcuiva. O stergere acolo ar distruge munca userului.
        // De aceea conditia e „folder propriu", nu „pack".
        let ownsDestinationFolder = item.isPack && item.type != .scripts
        if ownsDestinationFolder, FileManager.default.fileExists(atPath: destinationDir.path) {
            try deleteDirectory(at: destinationDir)
        }

        var writtenURLs: [URL] = []
        for (file, tempURL) in zip(item.files, tempURLs) {
            // Bug real, gasit la implementarea OFX: file.filename e doar
            // ultima componenta a caii (vezi CatalogModel.swift), deci
            // orice pack cu subfoldere (ex. un .ofx.bundle intreg, cu
            // Contents/MacOS/..., Contents/Resources/...) se scria PLAT,
            // pierzand structura de foldere si putand suprascrie fisiere
            // cu nume identic din subfoldere diferite. Fix: refacem calea
            // relativa la produs din file.path (format "id/versiune/rest"
            // — vezi PublishView.swift repoRelativePath) si o pastram la
            // instalare, nu doar numele de fisier.
            let relativePath = relativeInstallPath(for: file, in: item)
            let destinationURL = destinationDir.appendingPathComponent(relativePath)
            try writeFile(from: tempURL, to: destinationURL, creatingDirectory: destinationURL.deletingLastPathComponent())
            writtenURLs.append(destinationURL)
        }

        // VERIFICARE POST-INSTALARE (cerut explicit): nu ne bazam pe faptul ca
        // `writeFile` n-a aruncat. Pe calea elevata, copierea se face de un
        // proces separat (osascript); un esec partial, un disc plin sau un
        // prompt de parola anulat trebuie sa iasa la iveala AICI, nu peste o
        // saptamana, cand userul se intreaba de ce nu vede plugin-ul in Resolve.
        //
        // Comparam existenta si DIMENSIUNEA fata de sursa temporara. Nu
        // re-calculam SHA-ul: octetii au fost deja verificati inainte de
        // scriere (mai sus), iar singurul pas dintre ei si disc e copierea —
        // o copiere trunchiata se vede ca diferenta de dimensiune.
        for (destinationURL, tempURL) in zip(writtenURLs, tempURLs) {
            let fm = FileManager.default
            guard fm.fileExists(atPath: destinationURL.path) else {
                throw InstallError.verificationFailed(destinationURL.path, "fișierul nu există după instalare")
            }
            let expected = (try? fm.attributesOfItem(atPath: tempURL.path)[.size] as? Int) ?? nil
            let actual = (try? fm.attributesOfItem(atPath: destinationURL.path)[.size] as? Int) ?? nil
            if let expected, let actual, expected != actual {
                throw InstallError.verificationFailed(destinationURL.path,
                    "dimensiune diferită (\(actual) în loc de \(expected) octeți)")
            }
        }

        installedVersions[item.id] = item.version
        saveState()

        if item.type == .ofx {
            // Bundle-ul OFX trebuie sa fie executabil si fara flag-ul de
            // carantina Gatekeeper, altfel Resolve nu-l incarca la
            // pornire (vezi cerinta explicita a userului). Fisierele nu
            // trec prin Safari/browser (le scriem noi direct din bytes
            // descarcati prin API), deci in practica xattr e de multe ori
            // un no-op — dar il rulam oricum, defensiv, e ieftin.
            for u in writtenURLs { try fixOFXBundlePermissions(at: u) }   // doar fișierele scrise: niciodată tot folderul de pluginuri
            // Citirea + regex + rescrierea cache-ului Resolve pot dura secunde: niciodata pe firul principal (App Hanging, Sentry 1.39.2).
            let bundlePathForCache = destinationDir.path
            Task.detached(priority: .utility) { ResolveOFXCache.forget(bundlePath: bundlePathForCache) }
            // Pachet OFX valid = Contents/Info.plist chiar sub folderul .ofx.bundle (altfel Resolve nu-l vede). Un pachet imbricat/greșit se șterge, nu rămâne stricat pe disc.
            if !FileManager.default.fileExists(atPath: destinationDir.appendingPathComponent("Contents/Info.plist").path) {
                try? FileManager.default.removeItem(at: destinationDir)
                installedVersions[item.id] = nil
                saveState()
                throw InstallError.verificationFailed(item.name, "structura pachetului OFX")
            }
        }

        guard item.type == .powerGrade else { return .installed(paths: writtenURLs) }
        switch PowerGradeImporter.importIntoGallery(productName: item.name, files: writtenURLs, stagingFolder: destinationDir) {
        case .importedToGallery(let albumName):
            return .installedToGallery(albumName: albumName)
        case .stagedOnly(let folder):
            guard item.isFree else {
                // SECURITATE: pentru un produs GRATUIT, "stagedOnly" e
                // inofensiv (oricine îl poate lua oricum) — dar pentru
                // unul PLĂTIT, fișierul .drx verificat, complet
                // funcțional, ajungea pe disc chiar și când importul
                // automat eșua, EXACT ce header-ul din
                // PowerGradeImporter.swift ("EXCLUSIV prin Scripting
                // API") voia să evite. Un client putea provoca
                // intenționat eșecul (nu deschide Resolve) ca să obțină
                // fișierul brut și să-l distribuie neautorizat. Fix:
                // ștergem tot ce am scris (folderul de staging) și
                // dezinstalăm din `installedVersions` — nu rămâne NIMIC
                // recuperabil pe disc — apoi aruncăm o eroare generică,
                // fără cale de fișier sau instrucțiuni de instalare
                // manuală (ContentView.swift arată în schimb butonul de
                // contact WhatsApp, pentru instalare manuală asistată).
                try? FileManager.default.removeItem(at: folder)
                installedVersions.removeValue(forKey: item.id)
                saveState()
                throw InstallError.paidResourceInstallFailed
            }
            return .installedNeedsManualStep(folder: folder)
        }
    }

    // MARK: - Produse OFX GDC STYLE Lab V3 (identitate pe slot)

    /// [2026-10-04] Un produs V3 = mai multe pachete `.ofx.bundle` (variante de pipeline), fiecare cu identitatea din Info.plist.
    /// Regulile (OFXProductInstall / OFXIdentity, aceleași ca GDC STYLE Lab): Demo → Full înlocuiește în același slot, Full → Demo
    /// refuzat, copiile redenumite / dublurile se curăță, alte produse și pachetele altor producători nu se ating niciodată.
    /// Ediția: Full cu serial pentru produs (sau dacă un Full e deja instalat), altfel Demo (gratuit, cu filigran).
    private func installOFXProduct(_ item: PluginItem, _ product: OFXProductRelease) async throws -> InstallOutcome {
        if let problem = product.validate(itemID: item.id, itemVersion: item.version) {
            DiagnosticLog.write("Install", "produs OFX nevalid \(item.id): \(problem)")
            throw InstallError.verificationFailed(item.name, "descrierea produsului din catalog nu e validă")
        }
        let root = PluginType.ofx.installDirectory
        let installed = OFXIdentity.scanInstalled(root: root)
        let serial = LicenseManager.shared.serial(for: item.id)
        let edition = OFXProductInstall.edition(hasSerial: !(serial ?? "").isEmpty, r: product, installed: installed)
        let already = OFXProductInstall.installedVariants(product, installed: installed)
        let selection: OFXProductInstall.Selection = already.isEmpty ? .all : .variants(already)   // actualizarea atinge doar variantele prezente
        let plan: OFXProductInstall.Plan
        switch OFXProductInstall.install(product, edition: edition, selection: selection, installed: installed) {
        case .success(let p): plan = p
        case .failure(let e):
            DiagnosticLog.write("Install", "plan OFX eșuat \(item.id): \(e)")
            throw InstallError.verificationFailed(item.name, "pachetele produsului nu corespund pipeline-urilor instalate")
        }
        for d in plan.decisions { DiagnosticLog.write("Install", "\(item.id) \(d.variantId) [\(edition.rawValue)]: \(d.decision.action.code)") }
        if let refused = plan.refusals.first {
            // o versiune mai nouă e deja pe disc (refuse:downgrade) sau un Full există (refuse:demoOverFull): nimic nu se schimbă
            DiagnosticLog.write("Install", "\(item.id): refuzat \(refused.decision.action.code), nimic scris")
            if plan.writes.isEmpty, plan.removals.isEmpty {
                installedVersions[item.id] = OFXProductInstall.installedVersion(product, installed: installed) ?? item.version
                saveState()
                return .installed(paths: [])
            }
        }

        // 1) TOATE fișierele pachetelor de scris se descarcă și se verifică ÎNAINTE de orice ștergere/scriere.
        var staged: [(folder: String, identifier: String, files: [(rel: String, temp: URL)])] = []
        var temps: [URL] = []
        defer { for u in temps { try? FileManager.default.removeItem(at: u) } }
        for d in plan.writes {
            let prefix = d.package.root + "/"
            let files = item.files.filter { $0.path.hasPrefix(prefix) }
            guard !files.isEmpty, files.contains(where: { $0.path == prefix + "Contents/Info.plist" }) else {
                throw InstallError.verificationFailed(item.name, "pachetul \(d.package.folder) lipsește din catalog")
            }
            var list: [(String, URL)] = []
            for f in files {
                let rel = String(f.path.dropFirst(prefix.count))
                guard !rel.isEmpty, !rel.split(separator: "/").contains(".."), !rel.hasPrefix("/") else { throw InstallError.verificationFailed(item.name, "cale nevalidă în pachet") }
                let data = try await fetchAuthorizedFileData(productID: item.id, file: f)
                let sha = SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
                guard sha.lowercased() == f.sha256.lowercased() else { throw InstallError.checksumMismatch }
                let t = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                try data.write(to: t); temps.append(t); list.append((rel, t))
            }
            staged.append((d.package.folder, d.package.identifier, list))
        }

        // 2) ATOMIC: pachetele se pregătesc într-un folder temporar, apoi UN script (o singură autorizare, dacă e nevoie) le pune în locul celor vechi și scoate
        //    copiile de curățat (redenumite, dubluri, ediția Demo înlocuită); un eșec nu lasă nimic pe jumătate (rollback). Fără chown pe folderul de pluginuri.
        try atomicOFXInstall(root: root, bundles: staged.map { ($0.folder, $0.identifier, product.version, $0.files) }, removals: plan.removals)
        var written: [URL] = []
        for s in staged {
            let dir = root.appendingPathComponent(s.folder)
            written.append(dir)
            // verificare: identitatea scrisă = cea anunțată (altfel slotul ar fi greșit în Resolve)
            let plist = NSDictionary(contentsOf: dir.appendingPathComponent("Contents/Info.plist"))
            guard plist?["CFBundleIdentifier"] as? String == s.identifier, plist?["CFBundleShortVersionString"] as? String == product.version else {
                throw InstallError.verificationFailed(dir.path, "identitatea pachetului OFX nu corespunde catalogului")
            }
            let bundlePath = dir.path
            Task.detached(priority: .utility) { ResolveOFXCache.forget(bundlePath: bundlePath) }
        }
        // 3) după instalare: niciun slot al produsului nu are doi ocupanți
        let after = OFXIdentity.scanInstalled(root: root).filter { OFXIdentity.parse($0.identifier).product == product.instrument && OFXIdentity.parse($0.identifier).generation == .v3 }
        let slots = after.map { OFXIdentity.parse($0.identifier).slot }
        if Set(slots).count != slots.count { DiagnosticLog.write("Install", "\(item.id): DUBLURĂ după instalare \(after.map(\.folder))") }
        installedVersions[item.id] = product.version
        saveState()
        DiagnosticLog.write("Install", "\(item.id) \(product.version) [\(edition.rawValue)]: \(staged.count) pachete scrise, \(plan.removals.count) șterse")
        return .installed(paths: written)
    }

    @discardableResult
    func remove(_ item: PluginItem) throws -> RemoveOutcome {
        if item.type == .ofx, let product = item.ofxProduct {   // toți ocupanții sloturilor produsului, orice ediție / nume; nimic altceva
            let root = PluginType.ofx.installDirectory
            for rel in OFXProductInstall.removal(product, installed: OFXIdentity.scanInstalled(root: root)) { try deleteDirectory(at: root.appendingPathComponent(rel)) }
            installedVersions.removeValue(forKey: item.id)
            saveState()
            return .removed
        }
        var galleryOutcome: RemoveOutcome = .removed
        if item.type == .powerGrade {
            switch PowerGradeImporter.removeFromGallery(productName: item.name) {
            case .removedFromGallery: galleryOutcome = .removed
            case .removedFilesOnly: galleryOutcome = .removedNeedsManualGalleryCleanup
            }
        }

        if item.isPack {
            try deleteDirectory(at: destinationDirectory(for: item))
        } else if let file = item.files.first {
            try deleteFile(at: destinationDirectory(for: item).appendingPathComponent(file.filename))
        }
        installedVersions.removeValue(forKey: item.id)
        saveState()
        return galleryOutcome
    }

    // MARK: - Descărcare directă a unei resurse (PDF/ghid/carte)

    /// [2026-09-14] Descarcă fișierul unei `DownloadableResource` încărcat
    /// direct în repo-ul privat și îl salvează local — FĂRĂ browser.
    ///
    /// DE CE nu reutilizează `install(_:)`: acolo fișierele ajung în
    /// folderele DaVinci Resolve, unde un PDF n-are ce căuta. Aici userul
    /// alege unde se salvează (`DownloadLocationStore`, implicit
    /// `~/Downloads`) și primește fișierul deschis în Finder. Mecanismul de
    /// ADUCERE a octeților e însă exact același (`fetchPrivateFileData`) —
    /// o singură implementare autentificată, nu două.
    ///
    /// Întoarce calea locală a fișierului salvat.
    @MainActor
    func downloadResourceFile(_ resource: DownloadableResource) async throws -> URL {
        // [2026-09-14] O resursă poate fi un PACHET (folder cu subfoldere), nu
        // doar un fișier. Forma veche (`filePath`) rămâne suportată pentru
        // resursele publicate înainte.
        let toDownload: [PluginFile]
        if !resource.files.isEmpty {
            toDownload = resource.files
        } else if let path = resource.filePath, !path.isEmpty {
            toDownload = [PluginFile(path: path, sha256: resource.fileSHA256 ?? "", repo: resource.fileRepo)]
        } else {
            throw InstallError.downloadFailed
        }

        let folder: URL
        if let saved = DownloadLocationStore.shared.path(for: resource.id) {
            folder = URL(fileURLWithPath: saved)
        } else {
            folder = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
        }
        // Un pachet ajunge într-un folder propriu, ca să nu împrăștie zeci de
        // fișiere direct în Descărcări. Un singur fișier rămâne un fișier.
        let root = toDownload.count > 1 ? folder.appendingPathComponent(resource.id) : folder
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        var written: [URL] = []
        for file in toDownload {
            let data = try await fetchAuthorizedFileData(productID: resource.id, file: file)
            // Verificarea de integritate nu e opțională doar pentru că fișierul
            // e „doar un PDF": un fișier trunchiat se deschide și arată gol, iar
            // userul ar da vina pe conținut, nu pe descărcare.
            if !file.sha256.isEmpty {
                let actual = SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
                guard actual.lowercased() == file.sha256.lowercased() else { throw InstallError.checksumMismatch }
            }
            // Calea relativă la resursă („<id>/subfolder/fișier") se păstrează,
            // ca structura pachetului să ajungă intactă la user.
            let prefix = "\(resource.id)/"
            let relative = file.path.hasPrefix(prefix) ? String(file.path.dropFirst(prefix.count)) : file.filename
            let destination = root.appendingPathComponent(relative)
            do {
                try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
                if FileManager.default.fileExists(atPath: destination.path) {
                    try FileManager.default.removeItem(at: destination)
                }
                try data.write(to: destination)
            } catch {
                throw InstallError.writeFailed(destination.path)
            }
            written.append(destination)
        }
        // Pentru un pachet, arătăm folderul; pentru un fișier, fișierul.
        return toDownload.count > 1 ? root : (written.first ?? root)
    }

    // MARK: - Authorized fetch (S1, 2026-09-25)

    /// Aduce octeții unui fișier de produs prin `authorize-download`: clientul
    /// nu mai deține niciun credential pentru repo-urile private. Serialul
    /// (dacă există) e reverificat pe server; SHA-256 se verifică și aici, și
    /// de apelant (două controale distincte de autorizare și de integritate).
    private func fetchAuthorizedFileData(productID: String, file: PluginFile) async throws -> Data {
        let authorizer = DownloadAuthorizer(clientVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String)
        let serial = await MainActor.run { LicenseManager.shared.serial(for: productID) }
        do {
            return try await authorizer.fetch(productID: productID, path: file.path,
                                              expectedSHA256: file.sha256, serial: serial)
        } catch let failure as DownloadAuthorizer.Failure {
            DiagnosticLog.write("Install", "autorizare/descărcare eșuată pentru \(productID):\(file.path) — \(failure)")
            switch failure {
            case .invalidLicense, .revokedLicense, .unauthorizedPlatform: throw InstallError.licenseRejected
            case .rateLimited: throw InstallError.tooManyRequests
            case .checksumMismatch: throw InstallError.checksumMismatch
            default: throw InstallError.downloadFailed
            }
        }
    }

    /// Calea unui fisier RELATIVA LA RADACINA PRODUSULUI (nu doar numele
    /// de fisier) — reconstruita din `file.path`, care e mereu in formatul
    /// "id/versiune/rest..." (vezi PublishView.swift, `repoRelativePath`).
    /// Pentru un produs simplu (un singur fisier, fara subfoldere) da
    /// acelasi rezultat ca `file.filename` de dinainte — schimbarea
    /// conteaza doar pentru pack-uri cu structura de foldere (OFX bundles
    /// in special, dar si orice alt pack publicat cu subfoldere).
    private func relativeInstallPath(for file: PluginFile, in item: PluginItem) -> String {
        let prefix = "\(item.id)/\(item.version)/"
        guard file.path.hasPrefix(prefix) else { return file.filename }
        return String(file.path.dropFirst(prefix.count))
    }

    /// Dupa ce toate fisierele unui bundle OFX sunt scrise pe disc:
    /// permisiuni recursive 755 (executabil pentru toata lumea, cerut
    /// explicit) si eliminarea recursiva a atributului de carantina
    /// Gatekeeper, ca DaVinci Resolve sa il incarce la pornire fara
    /// avertismentul "developer nu poate fi verificat". Incearca intai
    /// fara elevare (folderul e de obicei scriabil, la fel ca restul
    /// scrierilor din writeFile), cade pe `runElevated` daca nu.
    ///
    /// [2026-10-04] Nu mai schimbă proprietarul folderului de pluginuri: o instalare cu o singură parolă vine acum din instalarea atomică
    /// (`atomicOFXInstall`, un singur script pentru toate pachetele), nu din preluarea întregului folder de către utilizator.
    private func fixOFXBundlePermissions(at bundleDirectoryOrParent: URL) throws {
        let script = """
        chmod -R 755 \(shellQuote(bundleDirectoryOrParent.path)) && \
        xattr -dr com.apple.quarantine \(shellQuote(bundleDirectoryOrParent.path)) 2>/dev/null; \
        true
        """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", script]
        let stderrPipe = Pipe()
        process.standardError = stderrPipe
        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 { return }
        } catch { /* fall through to elevated */ }

        try runElevated(script)   // doar ținta dată; proprietarul folderului de pluginuri nu se schimbă niciodată
    }

    // MARK: - Instalare OFX atomică

    /// Pregătește pachetele într-un folder temporar privat, le verifică (Info.plist prezent, identitate / versiune dacă sunt date, hash de arbore), apoi rulează
    /// scriptul `OFXAtomicInstall` o singură dată: direct dacă folderul de pluginuri e scriibil, altfel cu o singură autorizare de administrator.
    private func atomicOFXInstall(root: URL, bundles: [(folder: String, identifier: String, version: String, files: [(rel: String, temp: URL)])], removals: [String]) throws {
        let fm = FileManager.default
        let token = UUID().uuidString.lowercased().replacingOccurrences(of: "-", with: "").prefix(20)
        let stage = fm.temporaryDirectory.appendingPathComponent("gdc-ofx-stage-\(token)")
        try fm.createDirectory(at: stage, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        defer { try? fm.removeItem(at: stage) }
        var writes: [OFXAtomicInstall.Write] = []
        for b in bundles {
            let dir = stage.appendingPathComponent(b.folder)
            for (rel, temp) in b.files {
                guard OFXAtomicInstall.isSafeRelative(rel) else { throw InstallError.verificationFailed(b.folder, "cale nevalidă în pachet") }
                let dst = dir.appendingPathComponent(rel)
                try fm.createDirectory(at: dst.deletingLastPathComponent(), withIntermediateDirectories: true)
                try fm.copyItem(at: temp, to: dst)
            }
            let plist = NSDictionary(contentsOf: dir.appendingPathComponent("Contents/Info.plist"))
            guard plist != nil else { throw InstallError.verificationFailed(b.folder, "structura pachetului OFX") }
            if !b.identifier.isEmpty || !b.version.isEmpty {
                guard plist?["CFBundleIdentifier"] as? String == b.identifier, plist?["CFBundleShortVersionString"] as? String == b.version else {
                    throw InstallError.verificationFailed(b.folder, "identitatea pachetului OFX nu corespunde catalogului")
                }
            }
            let sha: String
            do { sha = try OFXAtomicInstall.treeHash(dir.path) } catch { throw InstallError.verificationFailed(b.folder, "pachet ilizibil") }
            writes.append(OFXAtomicInstall.Write(staged: dir.path, folder: b.folder, identifier: b.identifier, version: b.version, treeSHA: sha))
        }
        guard let script = OFXAtomicInstall.script(root: root.path, writes: writes, removals: removals, token: String(token)) else {
            DiagnosticLog.write("Install", "plan OFX atomic refuzat: \(OFXAtomicInstall.violation(root: root.path, writes: writes, removals: removals, token: String(token)) ?? "?")")
            throw InstallError.verificationFailed(root.path, "planul de instalare nu e valid")
        }
        let writable = fm.isWritableFile(atPath: root.path) || (!fm.fileExists(atPath: root.path) && fm.isWritableFile(atPath: root.deletingLastPathComponent().path))
        if writable {
            let p = Process(); p.executableURL = URL(fileURLWithPath: "/bin/sh"); p.arguments = ["-c", script]
            let err = Pipe(); p.standardError = err
            try p.run(); p.waitUntilExit()
            if p.terminationStatus == 0 { DiagnosticLog.write("Install", "OFX atomic: \(writes.count) pachete, \(removals.count) scoase (fără elevare)"); return }
            let msg = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            DiagnosticLog.write("Install", "OFX atomic fără elevare a eșuat (\(p.terminationStatus)): \(msg) — reîncerc cu autorizare")
        }
        try runElevated(script)
        DiagnosticLog.write("Install", "OFX atomic: \(writes.count) pachete, \(removals.count) scoase (o autorizare)")
    }

    // MARK: - Filesystem, with an admin-elevation fallback

    private func writeFile(from sourceURL: URL, to destinationURL: URL, creatingDirectory directory: URL) throws {
        let fm = FileManager.default
        do {
            try fm.createDirectory(at: directory, withIntermediateDirectories: true)
            if fm.fileExists(atPath: destinationURL.path) {
                try fm.removeItem(at: destinationURL)
            }
            try fm.copyItem(at: sourceURL, to: destinationURL)
        } catch {
            // Direct write failed (most likely a permissions issue on a
            // top-level /Library path) - fall back to a native admin
            // password prompt for just this one copy, exactly like the
            // /Applications moves done manually elsewhere this session.
            try elevatedCopy(from: sourceURL, to: destinationURL, creatingDirectory: directory)
        }
    }

    private func deleteFile(at url: URL) throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else { return }
        do {
            try fm.removeItem(at: url)
        } catch {
            try elevatedRemove(at: url, recursive: false)
        }
    }

    /// Removes a whole pack subfolder (and everything in it).
    private func deleteDirectory(at url: URL) throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else { return }
        do {
            try fm.removeItem(at: url)
        } catch {
            try elevatedRemove(at: url, recursive: true)
        }
    }

    private func elevatedCopy(from sourceURL: URL, to destinationURL: URL, creatingDirectory directory: URL) throws {
        let script = """
        mkdir -p \(shellQuote(directory.path)) && \
        rm -f \(shellQuote(destinationURL.path)) && \
        cp \(shellQuote(sourceURL.path)) \(shellQuote(destinationURL.path)) && \
        chmod 644 \(shellQuote(destinationURL.path))
        """
        try runElevated(script)
    }

    private func elevatedRemove(at url: URL, recursive: Bool) throws {
        try runElevated("rm -\(recursive ? "rf" : "f") \(shellQuote(url.path))")
    }

    private func runElevated(_ shellScript: String) throws {
        // Scriptul trece ca argv (quoted form), nu lipit într-un literal
        // AppleScript: un `\` în cale nu mai poate închide șirul (S2, 2026-09-25).
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = UpdatePackageVerifier.osascriptArguments(script: shellScript)
        let stderrPipe = Pipe()
        process.standardError = stderrPipe
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let data = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: data, encoding: .utf8) ?? "unknown error"
            throw InstallError.writeFailed(message)
        }
    }

    private func shellQuote(_ path: String) -> String {
        "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    // MARK: - Persisted install state

    private func loadState() {
        guard let data = try? Data(contentsOf: stateFileURL),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data) else { return }
        installedVersions = decoded
    }

    private func saveState() {
        guard let data = try? JSONEncoder().encode(installedVersions) else { return }
        try? FileManager.default.createDirectory(at: stateFileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: stateFileURL)
    }
}
