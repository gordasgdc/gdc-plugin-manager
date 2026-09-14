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
        case .authenticationFailed: return "Couldn't authenticate with the file server — contact support, the access token may need renewing."
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
        let destinationDir = destinationDirectory(for: item)
        var tempURLs: [URL] = []
        defer { for url in tempURLs { try? FileManager.default.removeItem(at: url) } }

        // Verify every file's checksum BEFORE writing anything, so a bad
        // file in a pack doesn't leave a half-installed folder behind.
        for file in item.files {
            let data = try await fetchPrivateFileData(path: file.path, repoKey: file.repo)
            let actualSHA = SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
            guard actualSHA.lowercased() == file.sha256.lowercased() else {
                throw InstallError.checksumMismatch
            }
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try data.write(to: tempURL)
            tempURLs.append(tempURL)
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
            try fixOFXBundlePermissions(at: destinationDir)
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

    @discardableResult
    func remove(_ item: PluginItem) throws -> RemoveOutcome {
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
        guard let path = resource.filePath, !path.isEmpty else {
            throw InstallError.downloadFailed
        }
        let data = try await fetchPrivateFileData(path: path, repoKey: resource.fileRepo)

        // Verificarea de integritate nu e opțională doar pentru că fișierul
        // e „doar un PDF": un fișier trunchiat se deschide și arată gol, iar
        // userul ar da vina pe conținut, nu pe descărcare.
        if let expected = resource.fileSHA256, !expected.isEmpty {
            let actual = SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
            guard actual == expected else { throw InstallError.checksumMismatch }
        }

        let folder: URL
        if let saved = DownloadLocationStore.shared.path(for: resource.id) {
            folder = URL(fileURLWithPath: saved)
        } else {
            folder = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
        }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let fileName = resource.directFileName ?? "\(resource.id).pdf"
        let destination = folder.appendingPathComponent(fileName)
        do {
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try data.write(to: destination)
        } catch {
            throw InstallError.writeFailed(destination.path)
        }
        return destination
    }

    // MARK: - Authenticated fetch from the private files repo

    /// Fetches one file's raw bytes from the private gdc-plugin-manager-files
    /// repo via GitHub's Contents API, using the embedded read-only token
    /// (see PrivateCatalogAuth.swift). `catalog.json` itself is NOT fetched
    /// this way — only the actual product files, which never sit at a
    /// plain public URL.
    private func fetchPrivateFileData(path: String, repoKey: String? = nil) async throws -> Data {
        // [2026-09-14] Repo-ul se alege dupa cheia din catalog — vezi
        // PrivateCatalogAuth.repos. Fara cheie (tot ce e publicat de dinainte)
        // se foloseste repo-ul principal, exact ca pana acum.
        let repo = PrivateCatalogAuth.repo(for: repoKey)
        guard let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "https://api.github.com/repos/\(repo.owner)/\(repo.name)/contents/\(encodedPath)") else {
            throw InstallError.downloadFailed
        }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(repo.token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github.raw+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw InstallError.downloadFailed }
        if http.statusCode == 401 || http.statusCode == 403 {
            throw InstallError.authenticationFailed
        }
        guard (200...299).contains(http.statusCode) else {
            throw InstallError.downloadFailed
        }
        return data
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
    /// La primul fallback elevat, chown-uim si RADACINA /Library/OFX/Plugins
    /// (nu doar bundle-ul curent) pe userul curent — asta e cererea userului
    /// de "o singura parola, nu la fiecare instalare OFX", dar implementata
    /// cu chown in loc de chmod 777: viitoarele instalari scriu direct, fara
    /// elevare, dar folderul ramane inaccesibil altor useri de pe masina
    /// (777 ar fi world-writable, risc de securitate inutil pe o masina
    /// multi-user).
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

        let currentUser = NSUserName()
        let ofxRoot = PluginType.ofx.installDirectory.path
        let elevatedScript = script + " && chown -R \(shellQuote(currentUser)):staff \(shellQuote(ofxRoot)) 2>/dev/null; true"
        try runElevated(elevatedScript)
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
        let appleScript = "do shell script \"\(shellScript.replacingOccurrences(of: "\"", with: "\\\""))\" with administrator privileges"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", appleScript]
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
