import Foundation
import CryptoKit
import GDCPluginManagerCore

/// Ce ocupă fiecare repo privat de resurse și cine trimite spre el.
///
/// DE CE SCANARE LOCALĂ, nu API: toate cele patru repo-uri sunt clonate pe
/// acest Mac (Furnizorul oricum nu poate publica fără ele), deci dimensiunea
/// reală a conținutului se citește instantaneu și fără internet. API-ul
/// GitHub întoarce altceva — dimensiunea repo-ului ÎMPACHETAT, cu tot cu
/// istoric — utilă ca reper pentru limitele GitHub, dar nu comparabilă cu
/// suma fișierelor de acum. Se afișează amândouă, spuse pe nume, în loc să
/// alegem una și să lăsăm impresia că e „dimensiunea".
///
/// Verificarea de orfani merge în ambele sensuri, fiindcă ambele direcții
/// s-au întâmplat deja în acest proiect: fișiere rămase după ștergerea unui
/// produs (ocupă spațiu degeaba) și intrări de catalog fără fișier pe disc
/// (clientul primește 404 la instalare).
@MainActor
enum RepoStorageScanner {

    struct FileEntry: Identifiable, Hashable {
        var id: String { relativePath }
        let relativePath: String
        let bytes: Int64
    }

    struct CatalogReference: Identifiable, Hashable {
        var id: String { "\(section)/\(ownerID)/\(path)" }
        /// „Produse", „Resurse Download", „PDF-uri", „Scripturi".
        let section: String
        let ownerID: String
        let ownerName: String
        let path: String
    }

    struct RepoUsage: Identifiable {
        var id: String { key }
        let key: String
        let repoName: String
        let localPath: URL
        let isCloned: Bool
        let fileCount: Int
        let totalBytes: Int64
        let largestFiles: [FileEntry]
        let references: [CatalogReference]
        /// Pe disc, dar nereferite de nimeni din catalog.
        let orphanFiles: [FileEntry]
        /// În catalog, dar lipsă de pe disc — clientul ar primi 404.
        let missingFiles: [CatalogReference]
        /// Dimensiunea raportată de GitHub (repo împachetat, cu istoric).
        var remoteBytes: Int64?
        /// Modificări necomise sau necomise-nepushate în checkout.
        var gitState: String?
    }

    /// Același conținut, prezent în mai multe repo-uri. Nu e neapărat o
    /// greșeală — un pachet oferit și ca produs, și ca resursă descărcabilă,
    /// ajunge legitim în două locuri — dar e singurul mod de a vedea cât
    /// spațiu costă asta, ca decizia să fie luată în cunoștință de cauză.
    struct DuplicateGroup: Identifiable {
        var id: String { digest }
        let digest: String
        let filename: String
        let bytes: Int64
        /// „files → ProGDC/1.0.0/Nikon_NLog.cube"
        let locations: [String]
        /// Spațiul ocupat de copiile în plus.
        var wastedBytes: Int64 { bytes * Int64(locations.count - 1) }
    }

    /// Limitele reale ale GitHub, ca pragurile afișate să nu fie inventate:
    /// 100 MB per fișier e refuz ferm la push, iar peste ~1 GB per repo
    /// GitHub cere reducerea dimensiunii.
    static let hardFileLimitBytes: Int64 = 100 * 1024 * 1024
    static let softRepoLimitBytes: Int64 = 1024 * 1024 * 1024

    // MARK: Scanarea

    static func scanAll(catalog: Catalog?) -> [RepoUsage] {
        let references = catalogReferences(catalog)
        return PrivateCatalogAuth.repos.keys.sorted().map { key in
            scan(key: key, references: references[key] ?? [])
        }
    }

    private static func scan(key: String, references: [CatalogReference]) -> RepoUsage {
        let repoName = PrivateCatalogAuth.repos[key]?.name ?? "gdc-plugin-manager-\(key)"
        let path = RepoCheckoutPaths.resourceRepoCheckouts[key]
            ?? RepoCheckoutPaths.privateFilesRepo
        let cloned = FileManager.default.fileExists(atPath: path.appendingPathComponent(".git").path)

        guard cloned else {
            return RepoUsage(key: key, repoName: repoName, localPath: path, isCloned: false,
                             fileCount: 0, totalBytes: 0, largestFiles: [], references: references,
                             orphanFiles: [], missingFiles: references)
        }

        let files = enumerateFiles(at: path)
        let onDisk = Set(files.map(\.relativePath))
        let referenced = Set(references.map(\.path))

        return RepoUsage(
            key: key,
            repoName: repoName,
            localPath: path,
            isCloned: true,
            fileCount: files.count,
            totalBytes: files.reduce(0) { $0 + $1.bytes },
            largestFiles: Array(files.sorted { $0.bytes > $1.bytes }.prefix(10)),
            references: references,
            orphanFiles: files.filter { !referenced.contains($0.relativePath) }
                              .sorted { $0.bytes > $1.bytes },
            missingFiles: references.filter { !onDisk.contains($0.path) }
        )
    }

    /// Tot ce e fișier obișnuit sub `root`, mai puțin `.git` și fișierele de
    /// serviciu care nu sunt conținut publicat (README, .gitignore).
    private static func enumerateFiles(at root: URL) -> [FileEntry] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: root,
                                             includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
                                             options: [.skipsHiddenFiles]) else { return [] }
        var result: [FileEntry] = []
        let prefix = root.standardizedFileURL.path + "/"

        for case let url as URL in enumerator {
            if url.lastPathComponent == ".git" {
                enumerator.skipDescendants()
                continue
            }
            guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
                  values.isRegularFile == true else { continue }
            let relative = url.standardizedFileURL.path.replacingOccurrences(of: prefix, with: "")
            // Conținutul publicat stă ÎNTOTDEAUNA într-un subfolder
            // (`<id>/<versiune>/<fișier>`), deci un fișier direct în rădăcina
            // repo-ului e fișier de serviciu — README, CHANGELOG, CLAUDE.md.
            // Fără regula asta apăreau ca „orfane" și dădeau alarme false
            // exact în raportul care trebuie să fie de încredere.
            guard relative.contains("/") else { continue }
            result.append(FileEntry(relativePath: relative, bytes: Int64(values.fileSize ?? 0)))
        }
        return result
    }

    /// Duplicatele dintre repo-uri, după conținut (SHA-256), nu după nume:
    /// două fișiere cu același nume pot fi versiuni diferite, iar același
    /// conținut poate fi salvat sub nume diferite. Se calculează amprenta
    /// doar pentru fișierele a căror dimensiune apare de mai multe ori —
    /// restul nu au cum să fie duplicate.
    static func duplicates(across usages: [RepoUsage]) -> [DuplicateGroup] {
        var byRepo: [(repo: String, entry: FileEntry, url: URL)] = []
        for usage in usages where usage.isCloned {
            for entry in enumerateFiles(at: usage.localPath) {
                byRepo.append((usage.key, entry, usage.localPath.appendingPathComponent(entry.relativePath)))
            }
        }
        var sizeCounts: [Int64: Int] = [:]
        for item in byRepo { sizeCounts[item.entry.bytes, default: 0] += 1 }

        var groups: [String: (bytes: Int64, filename: String, locations: [String])] = [:]
        for item in byRepo where sizeCounts[item.entry.bytes, default: 0] > 1 && item.entry.bytes > 0 {
            guard let digest = sha256(of: item.url) else { continue }
            let label = "\(item.repo) → \(item.entry.relativePath)"
            groups[digest, default: (item.entry.bytes, (item.entry.relativePath as NSString).lastPathComponent, [])]
                .locations.append(label)
        }
        return groups
            .filter { $0.value.locations.count > 1 }
            .map { DuplicateGroup(digest: $0.key, filename: $0.value.filename,
                                  bytes: $0.value.bytes, locations: $0.value.locations.sorted()) }
            .sorted { $0.wastedBytes > $1.wastedBytes }
    }

    /// Citire în flux, nu `Data(contentsOf:)`: un pachet de câteva sute de MB
    /// nu trebuie să intre tot în memorie ca să i se calculeze amprenta.
    private static func sha256(of url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try? handle.read(upToCount: 1 << 20), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return hasher.finalize().compactMap { String(format: "%02x", $0) }.joined()
    }

    // MARK: Cine spre ce repo trimite

    /// Toate trimiterile din catalog, grupate pe cheia de repo. Cheia lipsă
    /// înseamnă repo-ul principal — exact regula de compatibilitate din
    /// `PrivateCatalogAuth.defaultRepoKey`, altfel tot ce e publicat înainte
    /// de arhitectura multi-repo ar apărea ca orfan.
    static func catalogReferences(_ catalog: Catalog?) -> [String: [CatalogReference]] {
        guard let catalog else { return [:] }
        var map: [String: [CatalogReference]] = [:]

        func add(_ reference: CatalogReference, repo: String?) {
            let key = repo ?? PrivateCatalogAuth.defaultRepoKey
            map[key, default: []].append(reference)
        }

        for item in catalog.items + catalog.scriptItems {
            let section = catalog.scriptItems.contains(where: { $0.id == item.id }) ? "Scripturi" : "Produse"
            for file in item.files {
                add(CatalogReference(section: section, ownerID: item.id, ownerName: item.name, path: file.path),
                    repo: file.repo)
            }
        }

        let resourceGroups: [(String, [DownloadableResource])] = [
            ("Resurse Download", catalog.downloadableResources),
            ("PDF-uri", catalog.pdfResources),
            ("Scripturi (resurse)", catalog.scriptResources),
        ]
        for (section, resources) in resourceGroups {
            for resource in resources {
                // Pachetele multi-fișier țin lista în `files`; cele cu un
                // singur fișier o țin în `filePath`. Aceeași cale poate
                // apărea în amândouă la resursele publicate după trecerea la
                // pachete — se numără o singură dată.
                var seen = Set<String>()
                for file in resource.files where seen.insert(file.path).inserted {
                    add(CatalogReference(section: section, ownerID: resource.id, ownerName: resource.name, path: file.path),
                        repo: file.repo)
                }
                if let path = resource.filePath, seen.insert(path).inserted {
                    add(CatalogReference(section: section, ownerID: resource.id, ownerName: resource.name, path: path),
                        repo: resource.fileRepo)
                }
            }
        }
        return map
    }

    // MARK: Completări care au nevoie de rețea sau de git

    /// Dimensiunea raportată de GitHub, în octeți. API-ul o dă în KB.
    static func remoteSize(repoName: String) async -> Int64? {
        var request = URLRequest(url: URL(string: "https://api.github.com/repos/\(PrivateCatalogAuth.ownerLogin)/\(repoName)")!)
        request.setValue("Bearer \(PrivateCatalogAuth.token)", forHTTPHeaderField: "Authorization")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let kilobytes = json["size"] as? Int64 else { return nil }
        return kilobytes * 1024
    }

    /// Starea checkout-ului, în cuvinte. Un repo cu fișiere necomise arată
    /// local altfel decât îl vede clientul — motiv real de „am publicat, dar
    /// la client nu apare".
    static func gitState(at path: URL) -> String? {
        guard let porcelain = try? GitOps.run(["status", "--porcelain"], at: path) else { return nil }
        let dirty = porcelain.split(separator: "\n").count
        // `@{u}` lipsește pe o ramură fără upstream configurat (vezi bug-ul
        // documentat în GitOps.push) — atunci comanda eșuează și nu avem ce
        // raporta, nu înseamnă zero commit-uri nepushate.
        let unpushedRaw = (try? GitOps.run(["rev-list", "--count", "@{u}..HEAD"], at: path))?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let unpushed = unpushedRaw.flatMap { Int($0) } ?? 0

        switch (dirty, unpushed) {
        case (0, 0): return nil
        case (let d, 0): return "\(d) fișiere necomise"
        case (0, let u): return "\(u) commit-uri nepushate"
        case (let d, let u): return "\(d) fișiere necomise · \(u) commit-uri nepushate"
        }
    }

    static func formatted(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
