import Foundation
import CryptoKit
import GDCPluginManagerCore

/// D2b (2026-09-26): publicări pe mai multe repo-uri (fișiere private + catalog public) fără stări
/// periculoase. Git nu are tranzacții între repo-uri, deci siguranța vine din trei reguli:
///
/// 1. **Preflight comun**: TOATE checkout-urile implicate sunt verificate (repo, `main`, fără operații
///    în curs, fără modificări străine) și sincronizate ÎNAINTE de prima scriere.
/// 2. **Catalogul nu referă niciodată fișiere inexistente**: publicare = fișiere → verificare pe
///    `origin/main` (existență + SHA-256) → catalog; ștergere = catalog (confirmat pe server) →
///    fișierele care nu mai sunt referite de nimic. Orice întrerupere lasă cel mult fișiere orfane,
///    invizibile clienților.
/// 3. **Jurnal local** (`PublishJournal`): fiecare operație are un ID și pașii confirmați; „Reia”
///    continuă de la primul pas neconfirmat (idempotent), „Curăță orfanii” șterge doar ce serverul
///    confirmă că nu mai e referit. Fără force-push, fără tokenuri în jurnal.
enum PublishTransaction {
    struct FileRef: Codable, Hashable {
        let repoKey: String
        let path: String
        let sha256: String
    }

    struct FolderRef: Codable, Hashable {
        let repoKey: String
        let folder: String   // ex. "gdc-demo/" (toate versiunile produsului)
    }

    enum CatalogOperation: Codable {
        case upsertItems([PluginItem])
        case upsertDownloadableResource(DownloadableResource)
        case removeItems(ids: [String], covers: [String: String?])   // id → coperta anterioară

        /// ID-urile care trebuie să existe (publicare) sau să lipsească (ștergere) pe server.
        var ids: [String] {
            switch self {
            case .upsertItems(let items): return items.map(\.id)
            case .upsertDownloadableResource(let r): return [r.id]
            case .removeItems(let ids, _): return ids
            }
        }
        var isRemoval: Bool { if case .removeItems = self { return true } else { return false } }
    }

    enum Kind: String, Codable { case publish, delete }

    enum Step: String, Codable { case filesPushed, filesVerified, catalogPushed, catalogVerified, filesRemoved }

    struct Record: Codable, Identifiable {
        let id: UUID
        let kind: Kind
        let createdAt: Date
        let label: String
        let files: [FileRef]            // publicare: trebuie să existe pe server cu acest SHA-256
        let deleteFolders: [FolderRef]  // ștergere: foldere ale căror fișiere NEREFERITE se șterg
        let catalog: CatalogOperation
        let catalogMessage: String
        let catalogPaths: [String]
        let expectedDeletions: [String]
        var completed: [Step] = []
        var lastError: String?
        /// Amprenta intrărilor de catalog de pe server la ÎNCEPUTUL operației (id → SHA-256 al intrării,
        /// sau "absent"). La „Reia”, o diferență înseamnă o modificare ulterioară → oprire, nu suprascriere.
        var serverBaseline: [String: String] = [:]

        enum CodingKeys: String, CodingKey {
            case id, kind, createdAt, label, files, deleteFolders, catalog, catalogMessage, catalogPaths,
                 expectedDeletions, completed, lastError, serverBaseline
        }
        init(id: UUID, kind: Kind, createdAt: Date, label: String, files: [FileRef], deleteFolders: [FolderRef],
             catalog: CatalogOperation, catalogMessage: String, catalogPaths: [String], expectedDeletions: [String]) {
            self.id = id; self.kind = kind; self.createdAt = createdAt; self.label = label; self.files = files
            self.deleteFolders = deleteFolders; self.catalog = catalog; self.catalogMessage = catalogMessage
            self.catalogPaths = catalogPaths; self.expectedDeletions = expectedDeletions
        }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decode(UUID.self, forKey: .id); kind = try c.decode(Kind.self, forKey: .kind)
            createdAt = try c.decode(Date.self, forKey: .createdAt); label = try c.decode(String.self, forKey: .label)
            files = try c.decode([FileRef].self, forKey: .files); deleteFolders = try c.decode([FolderRef].self, forKey: .deleteFolders)
            catalog = try c.decode(CatalogOperation.self, forKey: .catalog)
            catalogMessage = try c.decode(String.self, forKey: .catalogMessage)
            catalogPaths = try c.decode([String].self, forKey: .catalogPaths)
            expectedDeletions = try c.decode([String].self, forKey: .expectedDeletions)
            completed = try c.decodeIfPresent([Step].self, forKey: .completed) ?? []
            lastError = try c.decodeIfPresent(String.self, forKey: .lastError)
            serverBaseline = try c.decodeIfPresent([String: String].self, forKey: .serverBaseline) ?? [:]
        }

        var repoKeys: [String] { Array(Set(files.map(\.repoKey) + deleteFolders.map(\.repoKey))).sorted() }
        func has(_ step: Step) -> Bool { completed.contains(step) }
    }

    struct IncompleteError: Error, LocalizedError {
        let record: Record
        let underlying: String
        var errorDescription: String? {
            let done = record.completed.map(\.rawValue).joined(separator: ", ")
            return "Publicare incompletă „\(record.label)” (\(record.id.uuidString.prefix(8))). Pași confirmați: \(done.isEmpty ? "niciunul" : done). "
                + "Catalogul nu referă fișiere lipsă. Folosește „Reia” (sau „Curăță orfanii”).\n\(underlying)"
        }
    }

    // MARK: - 1. Preflight

    /// Verifică TOATE checkout-urile (catalog + repo-urile cheilor date), apoi le sincronizează.
    /// Nu scrie nimic. Aruncă la primul checkout nepotrivit, înainte de orice modificare.
    @discardableResult
    static func preflight(repoKeys: [String]) throws -> [String: URL] {
        var checkouts: [String: URL] = [:]
        for key in Set(repoKeys) { checkouts[key] = try RepoCheckoutPaths.resourceCheckout(for: key) }
        let all = [RepoCheckoutPaths.publicCatalogRepo] + checkouts.values.sorted { $0.path < $1.path }
        for dir in all { try GitOps.verifyPublishCheckout(at: dir) }
        for dir in all { try GitOps.pull(at: dir) }
        return checkouts
    }

    // MARK: - 2. Publicare

    /// `sources`: fișiere locale noi, copiate în checkout-ul repo-ului lor. `files`: TOATE fișierele pe
    /// care le va referi catalogul (noi sau existente) — verificate pe server înainte de catalog.
    /// Se apelează DUPĂ `preflight` (și după scrierea copertei, dacă există).
    static func publish(label: String, sources: [(URL, FileRef)], files: [FileRef], catalog: CatalogOperation,
                        catalogMessage: String, catalogPaths: [String], log: (String) -> Void = { _ in }) throws {
        var record = Record(id: UUID(), kind: .publish, createdAt: Date(), label: label, files: files, deleteFolders: [],
                            catalog: catalog, catalogMessage: catalogMessage, catalogPaths: catalogPaths, expectedDeletions: [])
        record.serverBaseline = try catalogFingerprints(ids: catalog.ids, ref: "HEAD")
        try PublishJournal.save(record)
        try execute(record, sources: sources, log: log)
    }

    // MARK: - 3. Ștergere

    static func delete(label: String, folders: [FolderRef], catalog: CatalogOperation, catalogMessage: String,
                       catalogPaths: [String], expectedDeletions: [String], log: (String) -> Void = { _ in }) throws {
        var record = Record(id: UUID(), kind: .delete, createdAt: Date(), label: label, files: [], deleteFolders: folders,
                            catalog: catalog, catalogMessage: catalogMessage, catalogPaths: catalogPaths,
                            expectedDeletions: expectedDeletions)
        record.serverBaseline = try catalogFingerprints(ids: catalog.ids, ref: "HEAD")
        try PublishJournal.save(record)
        try execute(record, sources: [], log: log)
    }

    // MARK: - 4. Reia / Curăță orfanii

    /// Reverifică și resincronizează toate checkout-urile, apoi continuă de la primul pas neconfirmat.
    static func resume(_ stale: Record, log: (String) -> Void = { _ in }) throws {
        // Starea curentă din jurnal: dacă operația nu mai e acolo, e deja încheiată → nimic de făcut.
        guard let record = PublishJournal.load(id: stale.id) else { log("Operația era deja încheiată."); return }
        try preflight(repoKeys: record.repoKeys)
        try checkNoConcurrentChange(record)
        try execute(record, sources: [], log: log)
    }

    /// Înainte ca reluarea să scrie în catalog: intrările vizate trebuie să fie EXACT ca la începutul
    /// operației. Altfel cineva a publicat/modificat între timp (versiune nouă sau aceeași versiune
    /// schimbată) → oprire, fără nicio scriere; decizia rămâne manuală.
    static func checkNoConcurrentChange(_ record: Record) throws {
        let current = try catalogFingerprints(ids: record.catalog.ids, ref: "origin/\(GitOps.publishBranch)")
        let changed: [String]
        if !record.has(.catalogPushed) {
            changed = record.catalog.ids.filter { record.serverBaseline[$0] != nil && current[$0] != record.serverBaseline[$0] }
        } else if record.kind == .delete {
            changed = record.catalog.ids.filter { current[$0] != absent }   // produsul a reapărut după ștergere
        } else {
            changed = []
        }
        guard changed.isEmpty else {
            let versions = try serverVersions(ids: changed)
            let detail = changed.map { id in versions[id].map { "\(id) (acum \($0) pe server)" } ?? id }.joined(separator: ", ")
            throw GitOps.PublishGuardError(message: "Reluare oprită: \(detail) s-a modificat pe server după întreruperea operației „\(record.label)”. "
                + "Nu suprascriu modificările ulterioare și nu am scris nimic. Verifică manual catalogul, apoi publică din nou sau șterge operația din listă.")
        }
    }

    /// Doar pentru o publicare al cărei catalog NU a ajuns pe server: șterge fișierele ei pe care
    /// catalogul de pe `origin/main` nu le referă. Necesită confirmarea explicită din interfață.
    static func cleanupOrphans(_ record: Record, log: (String) -> Void = { _ in }) throws -> Int {
        guard record.kind == .publish else { throw GitOps.PublishGuardError(message: "Curățarea orfanilor e doar pentru publicări incomplete.") }
        let checkouts = try preflight(repoKeys: record.repoKeys)
        let referenced = try referencedFilesOnServer()
        var removed = 0
        for (key, dir) in checkouts {
            let orphans = record.files.filter { $0.repoKey == key && !referenced.contains(RepoPath(repo: key, path: $0.path)) }
                .filter { (try? GitOps.serverSHA256(at: dir, path: $0.path)) != nil }
            guard !orphans.isEmpty else { continue }
            for f in orphans { try GitOps.run(["rm", "--quiet", "--", f.path], at: dir) }
            try commitAndPushOrUnwind(at: dir, message: "Curat fișiere orfane: \(record.label)")
            removed += orphans.count
            log("Șterse \(orphans.count) fișiere orfane din „\(key)”")
        }
        try PublishJournal.remove(id: record.id)
        return removed
    }

    // MARK: - Execuție pe pași

    private static func execute(_ initial: Record, sources: [(URL, FileRef)], log: (String) -> Void) throws {
        var record = initial
        func confirm(_ step: Step) throws {
            if !record.has(step) { record.completed.append(step) }
            try PublishJournal.save(record)
        }
        do {
            switch record.kind {
            case .publish:
                if !record.has(.filesPushed) {
                    try pushFiles(record, sources: sources, log: log)
                    try confirm(.filesPushed)
                }
                if !record.has(.filesVerified) {
                    try verifyFilesOnServer(record.files)
                    log("Fișierele există pe server cu SHA-256 corect")
                    try confirm(.filesVerified)
                }
                if !record.has(.catalogPushed) {
                    try pushCatalog(record, log: log)
                    try confirm(.catalogPushed)
                }
                if !record.has(.catalogVerified) {
                    try verifyCatalogOnServer(record.catalog)
                    try confirm(.catalogVerified)
                }
            case .delete:
                if !record.has(.catalogPushed) {
                    try pushCatalog(record, log: log)
                    try confirm(.catalogPushed)
                }
                if !record.has(.catalogVerified) {
                    try verifyCatalogOnServer(record.catalog)
                    log("Catalogul de pe server nu mai conține produsele")
                    try confirm(.catalogVerified)
                }
                if !record.has(.filesRemoved) {
                    try removeUnreferencedFiles(record.deleteFolders, message: record.catalogMessage, log: log)
                    try confirm(.filesRemoved)
                }
            }
            try PublishJournal.remove(id: record.id)
        } catch {
            record.lastError = error.localizedDescription
            try? PublishJournal.save(record)
            throw IncompleteError(record: record, underlying: error.localizedDescription)
        }
    }

    private static func pushFiles(_ record: Record, sources: [(URL, FileRef)], log: (String) -> Void) throws {
        let keys = Set(record.files.map(\.repoKey)).union(sources.map(\.1.repoKey))
        for key in keys.sorted() {
            let dir = try RepoCheckoutPaths.resourceCheckout(for: key)
            for (local, ref) in sources where ref.repoKey == key {
                let dest = dir.appendingPathComponent(ref.path)
                try FileManager.default.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
                if FileManager.default.fileExists(atPath: dest.path) { try FileManager.default.removeItem(at: dest) }
                try FileManager.default.copyItem(at: local, to: dest)
            }
            // Idempotent: fără nimic nou, doar împinge ce a rămas de la o încercare anterioară.
            try commitAndPushOrUnwind(at: dir, message: record.label)
            log("Fișiere trimise în „\(key)”")
        }
    }

    private static func verifyFilesOnServer(_ files: [FileRef]) throws {
        for key in Set(files.map(\.repoKey)) {
            let dir = try RepoCheckoutPaths.resourceCheckout(for: key)
            try GitOps.fetch(at: dir)
            for f in files where f.repoKey == key {
                guard let sha = try GitOps.serverSHA256(at: dir, path: f.path) else {
                    throw GitOps.PublishGuardError(message: "Fișierul \(f.path) lipsește pe server (\(key)). Catalogul NU a fost modificat.")
                }
                guard sha == f.sha256.lowercased() else {
                    throw GitOps.PublishGuardError(message: "Fișierul \(f.path) de pe server are alt SHA-256 decât cel publicat. Catalogul NU a fost modificat.")
                }
            }
        }
    }

    private static func pushCatalog(_ record: Record, log: (String) -> Void) throws {
        let current = try CatalogEditor.load()
        let present = Set((current.items + current.scriptItems).map(\.id) + current.downloadableResources.map(\.id))
        switch record.catalog {
        case .upsertItems(let items):
            for item in items { try CatalogEditor.upsert(item) }
        case .upsertDownloadableResource(let resource):
            try CatalogEditor.upsertDownloadableResource(resource)
        case .removeItems(let ids, let covers):
            for id in ids {
                try CoverImageStore.commit(.none, id: id, previous: covers[id] ?? nil)
                if present.contains(id) { try CatalogEditor.remove(id: id) }   // idempotent la reluare
            }
        }
        try commitAndPushOrUnwind(at: RepoCheckoutPaths.publicCatalogRepo, message: record.catalogMessage,
                                  paths: record.catalogPaths, expectedDeletions: Set(record.expectedDeletions),
                                  restoreOnFailure: ["docs/catalog.json"])
        log("Catalog trimis")
    }

    private static func verifyCatalogOnServer(_ op: CatalogOperation) throws {
        let dir = RepoCheckoutPaths.publicCatalogRepo
        try GitOps.fetch(at: dir)
        let ids = try catalogIDsOnServer()
        for id in op.ids where ids.contains(id) == op.isRemoval {
            throw GitOps.PublishGuardError(message: op.isRemoval
                ? "„\(id)” e încă în catalogul de pe server. Fișierele NU au fost șterse."
                : "„\(id)” nu apare în catalogul de pe server după publicare.")
        }
    }

    private static func removeUnreferencedFiles(_ folders: [FolderRef], message: String, log: (String) -> Void) throws {
        let referenced = try referencedFilesOnServer()
        for key in Set(folders.map(\.repoKey)).sorted() {
            let dir = try RepoCheckoutPaths.resourceCheckout(for: key)
            try GitOps.fetch(at: dir)
            var toRemove: [String] = []
            var kept = 0
            for folder in folders where folder.repoKey == key {
                for path in try GitOps.serverFiles(at: dir, under: folder.folder) {
                    if referenced.contains(RepoPath(repo: key, path: path)) { kept += 1 } else { toRemove.append(path) }
                }
            }
            if kept > 0 { log("\(kept) fișiere rămân în „\(key)” (încă referite în catalog)") }
            guard !toRemove.isEmpty else { continue }
            for path in toRemove where FileManager.default.fileExists(atPath: dir.appendingPathComponent(path).path) {
                try GitOps.run(["rm", "--quiet", "--", path], at: dir)
            }
            try commitAndPushOrUnwind(at: dir, message: message)
            log("Șterse \(toRemove.count) fișiere nereferite din „\(key)”")
        }
    }

    /// Commit + push; dacă push-ul e respins, commit-ul local e DESFĂCUT (`reset --mixed` la starea de
    /// dinainte), altfel reluarea ar găsi o istorie divergentă. Nu se pierde nimic: fișierele rămân în
    /// arborele de lucru, iar `restoreOnFailure` (catalog.json) se reface din jurnal la reluare.
    private static func commitAndPushOrUnwind(at dir: URL, message: String, paths: [String]? = nil,
                                              expectedDeletions: Set<String> = [], restoreOnFailure: [String] = []) throws {
        let before = try GitOps.run(["rev-parse", "HEAD"], at: dir).trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try GitOps.commitAndPush(at: dir, message: message, paths: paths, expectedDeletions: expectedDeletions)
        } catch {
            let now = (try? GitOps.run(["rev-parse", "HEAD"], at: dir).trimmingCharacters(in: .whitespacesAndNewlines)) ?? before
            if now != before { _ = try? GitOps.run(["reset", "--quiet", "--mixed", before], at: dir) }
            for path in restoreOnFailure { _ = try? GitOps.run(["checkout", "--", path], at: dir) }
            throw error
        }
    }

    static let absent = "absent"

    /// Obiectul de catalog pentru fiecare id (orice colecție), la `ref`:
    /// "HEAD" = baza pe care s-a sincronizat operația (preflight); "origin/main" = serverul acum (după fetch).
    private static func catalogEntries(ids: [String], ref: String) throws -> [String: [String: Any]] {
        let dir = RepoCheckoutPaths.publicCatalogRepo
        if ref.hasPrefix("origin/") { try GitOps.fetch(at: dir) }
        let text = try GitOps.run(["show", "\(ref):docs/catalog.json"], at: dir)
        guard let root = try JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any] else { return [:] }
        var found: [String: [String: Any]] = [:]
        for case let array as [[String: Any]] in root.values {
            for obj in array { if let id = obj["id"] as? String, ids.contains(id) { found[id] = obj } }
        }
        return found
    }

    static func catalogFingerprints(ids: [String], ref: String) throws -> [String: String] {
        let entries = try catalogEntries(ids: ids, ref: ref)
        var result: [String: String] = [:]
        for id in ids {
            if let obj = entries[id] {
                let data = try JSONSerialization.data(withJSONObject: obj, options: [.sortedKeys])
                result[id] = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            } else {
                result[id] = absent
            }
        }
        return result
    }

    private static func serverVersions(ids: [String]) throws -> [String: String] {
        try catalogEntries(ids: ids, ref: "origin/\(GitOps.publishBranch)").compactMapValues { $0["version"] as? String }
    }

    // MARK: - Catalogul de pe server

    struct RepoPath: Hashable { let repo: String; let path: String }

    private static func serverCatalogJSON() throws -> Any {
        let text = try GitOps.serverText(at: RepoCheckoutPaths.publicCatalogRepo, path: "docs/catalog.json")
        return try JSONSerialization.jsonObject(with: Data(text.utf8))
    }

    /// ID-urile tuturor obiectelor din colecțiile de la rădăcina catalogului de pe server.
    static func catalogIDsOnServer() throws -> Set<String> {
        guard let root = try serverCatalogJSON() as? [String: Any] else { return [] }
        var ids = Set<String>()
        for case let array as [[String: Any]] in root.values {
            for obj in array { if let id = obj["id"] as? String { ids.insert(id) } }
        }
        return ids
    }

    /// Toate perechile (repo, cale) referite ORIUNDE în catalogul de pe server: `files[]` (path + repo)
    /// și forma veche `filePath` + `fileRepo`. Un fișier referit de orice produs sau versiune rămâne.
    static func referencedFilesOnServer() throws -> Set<RepoPath> {
        var refs = Set<RepoPath>()
        func walk(_ value: Any) {
            if let obj = value as? [String: Any] {
                if let path = obj["path"] as? String, obj["sha256"] != nil || obj["repo"] != nil {
                    refs.insert(RepoPath(repo: (obj["repo"] as? String) ?? PrivateCatalogAuth.defaultRepoKey, path: path))
                }
                if let path = obj["filePath"] as? String {
                    refs.insert(RepoPath(repo: (obj["fileRepo"] as? String) ?? PrivateCatalogAuth.defaultRepoKey, path: path))
                }
                obj.values.forEach(walk)
            } else if let array = value as? [Any] {
                array.forEach(walk)
            }
        }
        walk(try serverCatalogJSON())
        return refs
    }

    /// SHA-256 în flux, pentru fișierele locale alese la publicare (Regula 21).
    static func sha256(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while true {
            let chunk = try autoreleasepool { try handle.read(upToCount: 1 << 20) ?? Data() }
            if chunk.isEmpty { break }
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}

/// Jurnal local al operațiilor de publicare neterminate. Un fișier JSON per operație; conține doar
/// metadate de catalog și căi de fișiere — niciun token sau secret.
enum PublishJournal {
    /// Jurnal separat per mediu: `publish-journal` (producție) / `publish-journal-staging`.
    static var directoryOverride: URL?
    static var directory: URL {
        get {
            directoryOverride ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                .appendingPathComponent("GDC License Manager", isDirectory: true)
                .appendingPathComponent(FurnizorEnvironment.active == .staging ? "publish-journal-staging" : "publish-journal", isDirectory: true)
        }
        set { directoryOverride = newValue }
    }

    private static func url(for id: UUID) -> URL { directory.appendingPathComponent("\(id.uuidString).json") }

    static func save(_ record: PublishTransaction.Record) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(record).write(to: url(for: record.id), options: .atomic)
    }

    static func remove(id: UUID) throws {
        let u = url(for: id)
        if FileManager.default.fileExists(atPath: u.path) { try FileManager.default.removeItem(at: u) }
    }

    static func load(id: UUID) -> PublishTransaction.Record? {
        try? JSONDecoder().decode(PublishTransaction.Record.self, from: Data(contentsOf: url(for: id)))
    }

    static func pending() -> [PublishTransaction.Record] {
        let urls = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        return urls.filter { $0.pathExtension == "json" }
            .compactMap { try? JSONDecoder().decode(PublishTransaction.Record.self, from: Data(contentsOf: $0)) }
            .sorted { $0.createdAt < $1.createdAt }
    }
}
