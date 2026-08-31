import Foundation
import AppKit
import CryptoKit
import GDCPluginManagerCore

/// Ce a ales furnizorul pentru coperta unui produs, inainte de publicare.
///
/// ARCHITECTURE NOTE — de ce un enum si nu doua campuri optionale (`fisier`
/// + `url`): cele doua variante se EXCLUD. Cu doua campuri ar fi existat
/// starea "si fisier, si URL", iar UI-ul si publicarea ar fi trebuit sa
/// decida arbitrar care castiga. Enum-ul face starea imposibila, la fel cum
/// modelul din catalog are un singur camp `coverImage` (vezi CatalogAssets).
enum CoverImageSelection: Equatable {
    /// Produsul nu are coperta — cardul cade pe `iconSymbol`.
    case none

    /// Valoare deja publicata, incarcata din catalog la editare. O pastram
    /// distincta de `.local`/`.external` ca sa stim ca NU trebuie rescris
    /// nimic pe disc daca furnizorul n-a atins imaginea.
    case existing(String)

    /// Link extern (CDN-ul furnizorului). Nu trece prin compresie si nu
    /// ocupa spatiu in repo.
    case external(String)

    /// Fisier local DEJA comprimat, aflat intr-un folder temporar. Se mută
    /// in `docs/covers/` abia la publicare (vezi `CoverImageStore.commit`),
    /// pentru ca id-ul produsului poate fi inca in curs de tastare.
    case local(processed: URL, savings: String)

    /// Valoarea de scris in catalog daca s-ar publica exact asa cum e acum.
    /// nil pentru `.none`; pentru `.local` abia `commit` stie calea finala.
    var catalogValuePreview: String? {
        switch self {
        case .none: return nil
        case .existing(let v), .external(let v): return v
        case .local: return nil
        }
    }
}

/// Scrie/sterge coperile in checkout-ul public, langa `catalog.json`.
///
/// WARNING: imaginile se comit in ACELASI repo si in acelasi push ca
/// `catalog.json` (vezi `GitOps.commitAndPush` din ecranele de publicare).
/// Daca adaugi aici o scriere pe disc, asigura-te ca se intampla INAINTE de
/// commit — altfel catalogul ar referi o coperta care nu e inca publicata,
/// iar clientii ar primi 404 pana la urmatorul push.
enum CoverImageStore {

    /// `<checkout public>/docs/covers/`, creat la nevoie.
    static var coversDirectory: URL {
        RepoCheckoutPaths.publicCatalogRepo
            .appendingPathComponent("docs")
            .appendingPathComponent(CatalogAssets.coversFolderName)
    }

    /// Comprima o imagine aleasa de furnizor intr-un folder temporar si
    /// intoarce selectia gata de previzualizat. Compresia se face ACUM, nu
    /// la publicare, tocmai ca furnizorul sa vada in preview exact fisierul
    /// care va ajunge la clienti (si cat s-a castigat).
    static func prepareLocal(source: URL, preset: ImageProcessor.Preset) throws -> CoverImageSelection {
        // BUG REAL (2026-08-31): foloseam `FileManager.default.temporaryDirectory`
        // (`/var/folders/.../T/`) — exact tipul de folder pe care unelte de
        // curatare (CleanMyMac etc.) il considera "junk" si il sterg agresiv
        // la scanare. Daca un scan rula intre alegerea imaginii si "Publică",
        // fisierul disparea, iar publicarea esua cu o eroare care arata
        // calea interna (nume UUID), nu numele ales de furnizor ("brown.png")
        // — extrem de confuz, parea un bug de aplicatie. Mutat in Application
        // Support (niciodata tratat ca temp/cache de vreun cleaner) — acelasi
        // tipar folosit deja pentru cache-urile Client-ului (launch-banner-cache-image).
        let tempDir = try FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("GDCPluginManagerFurnizor", isDirectory: true)
            .appendingPathComponent("pending-covers", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        // Nume unic: acelasi fisier ales de doua ori la rand nu trebuie sa
        // dea peste rezultatul anterior cat timp preview-ul inca il arata.
        let temp = tempDir.appendingPathComponent(UUID().uuidString)
        let result = try ImageProcessor.process(source: source, preset: preset, destination: temp)
        return .local(processed: result.outputURL, savings: result.savingsDescription)
    }

    /// Finalizeaza selectia pentru produsul `id` si intoarce valoarea de
    /// scris in `coverImage`.
    ///
    /// `previous` e valoarea din catalog dinainte de editare — ne trebuie ca
    /// sa stergem fisierul vechi cand furnizorul trece de la o imagine
    /// locala la un URL extern (sau la nimic), altfel ar ramane orfan in
    /// repo pentru totdeauna.
    /// `@discardableResult`: la stergerea unui produs se apeleaza cu `.none`
    /// doar pentru efectul de curatare a fisierelor, iar rezultatul (nil) nu
    /// intereseaza pe nimeni.
    @discardableResult
    static func commit(_ selection: CoverImageSelection, id: String, previous: String?) throws -> String? {
        switch selection {
        case .existing(let value):
            // Nimic de scris: furnizorul n-a atins imaginea.
            return value

        case .none:
            try removeLocalFiles(id: id, previous: previous)
            return nil

        case .external(let url):
            let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                try removeLocalFiles(id: id, previous: previous)
                return nil
            }
            // A trecut de pe upload local pe CDN — fisierul din repo nu mai
            // e referit de nimeni.
            try removeLocalFiles(id: id, previous: previous)
            return trimmed

        case .local(let processed, _):
            try FileManager.default.createDirectory(at: coversDirectory, withIntermediateDirectories: true)
            // Stergem intai orice covers/<id>.* existent: extensia se poate
            // schimba intre publicari (un PNG cu alpha inlocuit cu un JPEG),
            // si am ramane cu doua fisiere pentru acelasi produs.
            try removeLocalFiles(id: id, previous: previous)

            let ext = processed.pathExtension.isEmpty ? "jpg" : processed.pathExtension
            let destination = coversDirectory.appendingPathComponent("\(id).\(ext)")
            // BUG REAL (2026-08-31): `copyItem` arunca "already exists" daca
            // fisierul vechi mai era pe disc (ex. `removeLocalFiles` de mai
            // sus nu-l gasise dupa un ciclu extern de stergere/restaurare a
            // `docs/`) — republicarea aceleiasi coperti devenea imposibila
            // fara sa redenumesti produsul, ca sa ocolesti coliziunea.
            // Stergere explicita inainte de copiere elimina complet aceasta
            // clasa de eroare.
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.copyItem(at: processed, to: destination)

            // PITFALL FIXED 2026-08-24: cand o coperta se INLOCUIESTE la
            // acelasi id (deci acelasi URL final), GitHub Pages trimite
            // `Cache-Control: max-age=14400` (4 ore) pe fisierele din
            // docs/ — orice client care a mai vazut URL-ul (AsyncImage pe
            // Mac, BitmapImage pe Windows, browser, si mai ales
            // service worker-ul PWA-ului, care e cache-first PE IMAGINI
            // FARA expirare) ramane cu poza veche pana la 4 ore sau, in
            // PWA, pana la un CACHE_VERSION bump. Sufixul de mai jos —
            // derivat din CONTINUTUL fisierului, nu dintr-un timestamp —
            // face ca noua imagine sa aiba mereu un URL DIFERIT cand
            // bytes-ii chiar s-au schimbat, ceea ce bate orice cache HTTP
            // sau de service worker fara sa fie nevoie sa schimbam vreun
            // cod de randare (toate randeaza direct string-ul din catalog).
            let versionSuffix = try cacheBustSuffix(for: destination)

            // Cale RELATIVA in catalog, niciodata absoluta — vezi
            // CatalogAssets pentru motiv (schimbarea domeniului dintr-un
            // singur loc).
            return "\(CatalogAssets.coversFolderName)/\(id).\(ext)?v=\(versionSuffix)"
        }
    }

    /// Primii 8 caractere hex din SHA-256 al fisierului — scurt, dar practic
    /// imposibil sa coincida intre doua imagini diferite. Derivat din
    /// continut, nu din data curenta: republicarea acelorasi bytes (ex. un
    /// build repetat fara nicio schimbare reala) produce acelasi sufix, deci
    /// acelasi URL — clientii care il au deja in cache nu re-descarca degeaba.
    private static func cacheBustSuffix(for fileURL: URL) throws -> String {
        let data = try Data(contentsOf: fileURL)
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined().prefix(8).description
    }

    /// Sterge orice `docs/covers/<id>.*`, plus fisierul indicat de
    /// `previous` daca acesta era o cale locala cu alt nume.
    ///
    /// NOTE: nu arunca daca fisierele lipsesc — stergerea e idempotenta,
    /// altfel republicarea unui produs fara coperta ar esua degeaba.
    private static func removeLocalFiles(id: String, previous: String?) throws {
        let fm = FileManager.default

        // Orice extensie pentru id-ul curent.
        if let entries = try? fm.contentsOfDirectory(at: coversDirectory, includingPropertiesForKeys: nil) {
            for entry in entries where entry.deletingPathExtension().lastPathComponent == id {
                try? fm.removeItem(at: entry)
            }
        }

        // Valoarea veche, daca era locala si arata spre alt nume de fisier.
        // Sufixul `?v=...` (cache-busting, vezi commit()) NU e parte din
        // calea reala de pe disc — trebuie taiat, altfel FileManager cauta
        // literal un fisier numit "id.jpg?v=abcd1234", care nu exista.
        if let previous, !CatalogAssets.isExternal(previous) {
            let pathOnly = previous.split(separator: "?", maxSplits: 1).first.map(String.init) ?? previous
            let old = RepoCheckoutPaths.publicCatalogRepo
                .appendingPathComponent("docs")
                .appendingPathComponent(pathOnly)
            try? fm.removeItem(at: old)
        }
    }

    /// O intrare din biblioteca de imagini deja publicate — vezi
    /// `libraryEntries()`. Cerinta lui Cristi (2026-08-31): "odata ce ai
    /// urcat, poti sa o selectezi si sa o folosesti in mai multe locuri" —
    /// pana acum fiecare copertă trebuia reîncărcată de pe disc separat
    /// pentru fiecare produs, chiar dacă imaginea era deja publicată.
    struct LibraryEntry: Identifiable, Hashable {
        /// Numele fisierului (fara extensie) — ce arata furnizorului in UI.
        let id: String
        let fileURL: URL
        /// Valoarea gata de scris in `coverImage`, cu acelasi cache-bust
        /// prin hash de continut ca orice publicare noua.
        let catalogValue: String
    }

    /// Toate imaginile deja publicate in `docs/covers/` — root, fara
    /// subfolderul `seasonal/` (filigrane, alt scop) si fara
    /// `launch-banner.*` (slot unic, nu un produs reutilizabil).
    static func libraryEntries() -> [LibraryEntry] {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(at: coversDirectory, includingPropertiesForKeys: [.isDirectoryKey]) else {
            return []
        }
        return entries.compactMap { url -> LibraryEntry? in
            guard (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory != true else { return nil }
            let name = url.deletingPathExtension().lastPathComponent
            guard name != "launch-banner" else { return nil }
            guard let suffix = try? cacheBustSuffix(for: url) else { return nil }
            let value = "\(CatalogAssets.coversFolderName)/\(url.lastPathComponent)?v=\(suffix)"
            return LibraryEntry(id: name, fileURL: url, catalogValue: value)
        }
        .sorted { $0.id.localizedCaseInsensitiveCompare($1.id) == .orderedAscending }
    }

    /// Deschide selectorul de fisiere. nil daca furnizorul a anulat.
    ///
    /// NOTE: `.image` acopera tot ce stie ImageIO sa citeasca (HEIC de pe
    /// telefon, TIFF din Photoshop, etc.) — nu limitam la jpg/png, pentru ca
    /// ImageProcessor oricum converteste la un format web.
    @MainActor
    static func pickFile() -> URL? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Alege imaginea de prezentare — se comprimă automat la publicare."
        panel.prompt = "Alege"
        return panel.runModal() == .OK ? panel.url : nil
    }
}
