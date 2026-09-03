import Foundation
import CryptoKit
import CommonCrypto

/// [2026-09-03] Backup criptat, portabil, al INTREGII stari a aplicatiei
/// Furnizor — cerut explicit de Cristi: "in cazul in care trebuie sa schimb
/// Mac-ul... sa pot transfera intreaga stare a aplicatiei dintr-un singur
/// fisier".
///
/// DE CE E CRITIC, nu doar convenabil (constatat la auditul din 2026-09-03):
/// cheia privata Ed25519 din `~/Library/Application Support/GDC License
/// Manager/private_key.txt` exista in EXACT UN exemplar, pe UN Mac, fara
/// Time Machine configurat si fara nicio copie in alta parte. Cu ea se
/// semneaza licentele pentru TOT ecosistemul GDC (CursorPro, DataMover,
/// GDCVault, Master Control Studio Pro, Plugin Manager). Daca discul cedeaza:
///   - licentele deja emise continua sa functioneze (se verifica local, cu
///     cheia publica hardcodata in fiecare aplicatie);
///   - dar NU se mai poate emite NICIO licenta noua, niciodata, pentru
///     niciun produs — nici macar pentru un client existent care isi schimba
///     calculatorul;
///   - singura reparatie ar fi o cheie noua + o versiune noua a FIECAREI
///     aplicatii din ecosistem + reemiterea fiecarei licente vandute.
/// De-aceea cheia privata e primul lucru din arhiva, si de-aceea arhiva se
/// cripteaza: un fisier de backup pierdut sau lasat pe un stick nu trebuie
/// sa fie exploatabil de nimeni.
///
/// FORMAT (versiunea 1):
///   "GDCBK1\n" | UInt32(be) lungime antet | antet JSON in clar | blocuri
/// Antetul JSON contine DOAR parametrii de derivare a cheii (sare, numar de
/// iteratii, algoritm) si un rezumat neutru al continutului — niciun secret.
/// Restul fisierului e o succesiune de blocuri AES-256-GCM.
///
/// DE CE PE BLOCURI si nu un singur sigiliu AES-GCM peste tot: cu repo-urile
/// incluse arhiva trece de 50 MB, iar CryptoKit cere intregul mesaj in
/// memorie pentru un singur `seal`. Blocurile de 8 MB tin consumul de
/// memorie plafonat (Regula 21). Fiecare bloc are in datele autentificate
/// (AAD) identificatorul arhivei + indicele blocului + marcajul de ultim
/// bloc, deci un atacator nu poate reordona, sterge sau trunchia blocuri
/// fara ca decriptarea sa esueze.
enum BackupArchive {

    // MARK: - Erori

    enum BackupError: LocalizedError {
        case notAnArchive
        case unsupportedVersion(Int)
        case wrongPassword
        case corrupted(String)
        case tarFailed(String)
        case nothingToBackUp

        var errorDescription: String? {
            switch self {
            case .notAnArchive:
                return "Fișierul ales nu este un backup GDC."
            case .unsupportedVersion(let v):
                return "Backup-ul a fost creat cu o versiune mai nouă a aplicației (format \(v)). Actualizează Furnizor și încearcă din nou."
            case .wrongPassword:
                return "Parola nu este corectă (sau fișierul a fost modificat după creare)."
            case .corrupted(let detail):
                return "Backup-ul pare deteriorat: \(detail)"
            case .tarFailed(let detail):
                return "Împachetarea/despachetarea a eșuat: \(detail)"
            case .nothingToBackUp:
                return "Nu am găsit nimic de salvat — verifică dacă aplicația a fost folosită pe acest Mac."
            }
        }
    }

    // MARK: - Ce intra in arhiva

    /// O componenta a starii aplicatiei. `isCritical` marcheaza ce nu se
    /// poate reconstrui in niciun fel daca se pierde (cheia privata).
    struct Component: Identifiable, Hashable {
        let id: String
        let label: String
        let detail: String
        let source: URL
        let isDirectory: Bool
        let isCritical: Bool
        /// Optionale = mari (zeci de MB) si recuperabile din git; furnizorul
        /// alege daca le include.
        let isOptional: Bool
    }

    /// Puncte de injectare pentru teste. In aplicatie raman mereu `nil`,
    /// deci se folosesc locatiile reale.
    ///
    /// DE CE EXISTA (2026-09-03): prima rulare a testelor acestui modul a
    /// suprascris cheia privata REALA si jurnalul de vanzari real, pentru ca
    /// restaurarea isi calcula singura destinatiile din `FileManager`, iar
    /// un test nu avea nicio cale sa le redirecteze (schimbarea variabilei
    /// HOME nu are efect — `FileManager` nu o citeste). Datele au fost
    /// recuperate din copiile `.inainte-de-restaurare` pe care tot acest
    /// modul le face inainte sa suprascrie ceva, dar un modul de BACKUP care
    /// nu poate fi testat fara sa puna in pericol exact datele pe care le
    /// protejeaza e un defect de proiectare, nu doar un incident.
    static var applicationSupportOverride: URL?
    static var vendorSourceRootOverride: URL?

    private static var appSupport: URL {
        applicationSupportOverride
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    }

    /// Radacina codului sursa, dedusa din calea checkout-ului public.
    /// Fisierele cu secrete (token GitHub, cheie Supabase) sunt fisiere
    /// SURSA gitignorate: pe un Mac nou, un `git clone` NU le aduce, iar
    /// aplicatia Furnizor nu se poate construi fara ele. De-aceea intra in
    /// backup, desi nu sunt "date".
    private static var vendorSourceRoot: URL {
        vendorSourceRootOverride ?? RepoCheckoutPaths.publicCatalogRepo
    }

    /// Tot ce alcatuieste starea Furnizorului pe acest Mac. Componentele
    /// inexistente sunt sarite tacut (o instalare noua nu are inca de toate).
    static func availableComponents() -> [Component] {
        let fm = FileManager.default
        let licenseDir = appSupport.appendingPathComponent("GDC License Manager", isDirectory: true)
        let furnizorDir = appSupport.appendingPathComponent("GDCPluginManagerFurnizor", isDirectory: true)

        let candidates: [Component] = [
            Component(id: "private_key",
                      label: "Cheia privată de semnare a licențelor",
                      detail: "Fără ea nu se mai poate emite nicio licență, pentru niciun produs GDC.",
                      source: licenseDir.appendingPathComponent("private_key.txt"),
                      isDirectory: false, isCritical: true, isOptional: false),
            Component(id: "public_key",
                      label: "Cheia publică",
                      detail: "Perechea cheii private, folosită la verificare.",
                      source: licenseDir.appendingPathComponent("public_key.txt"),
                      isDirectory: false, isCritical: false, isOptional: false),
            Component(id: "sales",
                      label: "Jurnalul de vânzări și clienți",
                      detail: "Toate licențele emise: client, email, produs, preț, expirare, ID mașină, serial.",
                      source: licenseDir.appendingPathComponent("furnizor_sales.csv"),
                      isDirectory: false, isCritical: true, isOptional: false),
            Component(id: "customers_legacy",
                      label: "Jurnalul vechi de clienți",
                      detail: "Fișierul moștenit din GDC License Manager.",
                      source: licenseDir.appendingPathComponent("customers.csv"),
                      isDirectory: false, isCritical: false, isOptional: false),
            Component(id: "products_legacy",
                      label: "Lista veche de produse",
                      detail: "Fișier moștenit, păstrat pentru compatibilitate.",
                      source: licenseDir.appendingPathComponent("products.txt"),
                      isDirectory: false, isCritical: false, isOptional: false),
            Component(id: "pending_covers",
                      label: "Imagini de copertă în lucru",
                      detail: "Coperțile alese, dar încă nepublicate.",
                      source: furnizorDir.appendingPathComponent("pending-covers", isDirectory: true),
                      isDirectory: true, isCritical: false, isOptional: false),
            Component(id: "github_token",
                      label: "Tokenul GitHub de publicare",
                      detail: "Fișier sursă exclus din git — un clone pe alt Mac NU îl aduce.",
                      source: vendorSourceRoot.appendingPathComponent("Sources/GDCPluginManagerCore/PrivateCatalogAuth.swift"),
                      isDirectory: false, isCritical: true, isOptional: false),
            Component(id: "supabase_key",
                      label: "Cheia de administrare Supabase",
                      detail: "Fișier sursă exclus din git — la fel, nu vine cu un clone.",
                      source: vendorSourceRoot.appendingPathComponent("Sources/GDCPluginManagerFurnizor/SupabaseAdminConfig.swift"),
                      isDirectory: false, isCritical: true, isOptional: false),
            Component(id: "catalog_docs",
                      label: "Catalogul publicat (docs/)",
                      detail: "catalog.json, pricing.json, coperți. Recuperabil și dintr-un git clone.",
                      source: vendorSourceRoot.appendingPathComponent("docs", isDirectory: true),
                      isDirectory: true, isCritical: false, isOptional: true),
            Component(id: "product_files",
                      label: "Fișierele vandabile (repo privat)",
                      detail: "LUT-uri, DCTL, plugin-uri. Zeci de MB; recuperabile din repo-ul privat.",
                      source: RepoCheckoutPaths.privateFilesRepo,
                      isDirectory: true, isCritical: false, isOptional: true),
        ]

        return candidates.filter { fm.fileExists(atPath: $0.source.path) }
    }

    // MARK: - Antet

    private static let magic = Data("GDCBK1\n".utf8)
    private static let formatVersion = 1
    private static let chunkSize = 8 * 1024 * 1024
    /// Pragul minim (recomandarea OWASP pentru PBKDF2-HMAC-SHA256) si
    /// plafonul, ca restaurarea sa nu devina insuportabil de lenta pe o
    /// masina mai slaba decat cea pe care s-a facut backup-ul.
    private static let minIterations: UInt32 = 600_000
    private static let maxIterations: UInt32 = 5_000_000
    /// Cat timp vrem sa dureze derivarea cheii din parola.
    private static let targetKDFSeconds = 0.4

    /// Numarul de iteratii se CALIBREAZA la masina curenta, nu se hardcodeaza.
    ///
    /// DE CE (masurat pe acest Mac, 2026-09-03): un M-series face 600.000 de
    /// iteratii in 0,096 s, pentru ca SHA-256 e accelerat hardware. Adica o
    /// constanta considerata "sigura" azi ofera de fapt un factor de lucru
    /// de 4x mai mic decat se presupune, iar pe hardware-ul de peste doi ani
    /// va fi si mai mic — fara ca nimeni sa observe, pentru ca numarul din
    /// cod ramane acelasi. Calibrarea la un TIMP tinta pastreaza costul real
    /// constant pe orice masina. Numarul efectiv se scrie in antetul arhivei,
    /// deci restaurarea foloseste exact valoarea cu care s-a criptat.
    private static func calibratedIterations() -> UInt32 {
        let probe: UInt32 = 100_000
        let salt = Data(repeating: 0, count: 16)
        let start = Date()
        _ = try? deriveKey(password: "calibrare", salt: salt, iterations: probe)
        let elapsed = Date().timeIntervalSince(start)
        guard elapsed > 0 else { return minIterations }
        let scaled = Double(probe) * (targetKDFSeconds / elapsed)
        return UInt32(min(Double(maxIterations), max(Double(minIterations), scaled)))
    }

    private struct Header: Codable {
        var version: Int
        var createdAt: Date
        var archiveID: String
        var kdf: String
        var iterations: UInt32
        var saltBase64: String
        var cipher: String
        var chunkSize: Int
        /// Rezumat NEUTRU, pentru ca furnizorul sa stie ce contine un fisier
        /// de backup vechi fara sa-l decripteze. Doar etichete, niciun secret.
        var contents: [String]
        var appVersion: String
        var machineName: String
    }

    /// Ce se poate afla despre o arhiva FARA parola — util pentru un ecran de
    /// restaurare care confirma ce urmeaza sa fie importat.
    struct ArchiveInfo {
        let createdAt: Date
        let contents: [String]
        let appVersion: String
        let machineName: String
    }

    // MARK: - Derivarea cheii

    private static func deriveKey(password: String, salt: Data, iterations: UInt32) throws -> SymmetricKey {
        var derived = Data(count: 32)
        let passwordBytes = Array(password.utf8)
        let status: Int32 = derived.withUnsafeMutableBytes { derivedPtr in
            salt.withUnsafeBytes { saltPtr in
                CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    passwordBytes, passwordBytes.count,
                    saltPtr.bindMemory(to: UInt8.self).baseAddress, salt.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                    iterations,
                    derivedPtr.bindMemory(to: UInt8.self).baseAddress, 32)
            }
        }
        guard status == kCCSuccess else {
            throw BackupError.corrupted("derivarea cheii a eșuat (cod \(status))")
        }
        return SymmetricKey(data: derived)
    }

    /// Datele autentificate ale unui bloc. Includerea indicelui si a
    /// marcajului de final e ce impiedica reordonarea sau trunchierea:
    /// un fisier taiat la jumatate nu mai are bloc marcat "ultimul", iar
    /// decriptarea esueaza in loc sa produca o restaurare partiala, tacuta.
    private static func aad(archiveID: String, index: UInt64, isLast: Bool) -> Data {
        var data = Data("GDCBK1|".utf8)
        data.append(Data(archiveID.utf8))
        data.append(contentsOf: withUnsafeBytes(of: index.bigEndian) { Array($0) })
        data.append(isLast ? 1 : 0)
        return data
    }

    // MARK: - Creare

    /// Impacheteaza componentele alese, cripteaza si scrie la `destination`.
    /// `progress` primeste (etapa, fractie 0...1) pe un thread de fundal.
    static func create(components: [Component],
                       password: String,
                       destination: URL,
                       progress: @escaping (String, Double) -> Void) throws {
        guard !components.isEmpty else { throw BackupError.nothingToBackUp }

        let fm = FileManager.default
        let work = fm.temporaryDirectory.appendingPathComponent("gdc-backup-" + UUID().uuidString)
        let stage = work.appendingPathComponent("payload", isDirectory: true)
        try fm.createDirectory(at: stage, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: work) }

        // 1. Copiaza fiecare componenta intr-un director de lucru, sub un nume
        //    stabil (id-ul componentei). Manifestul retine unde trebuie pusa
        //    fiecare inapoi la restaurare — calea absoluta a Mac-ului vechi NU
        //    se foloseste la restaurare (userul poate avea alt nume de cont),
        //    ci se recalculeaza din id.
        progress("Se adună fișierele…", 0.05)
        var manifest: [String: Bool] = [:]
        for component in components {
            let target = stage.appendingPathComponent(component.id)
            do {
                try fm.copyItem(at: component.source, to: target)
                manifest[component.id] = component.isDirectory
            } catch {
                // O componenta ilizibila nu trebuie sa opreasca tot backup-ul —
                // dar nici sa dispara in tacere: apare in raportul de progres.
                progress("Sar peste \(component.label): \(error.localizedDescription)", 0.05)
            }
        }
        guard !manifest.isEmpty else { throw BackupError.nothingToBackUp }
        let manifestData = try JSONEncoder().encode(manifest)
        try manifestData.write(to: stage.appendingPathComponent("manifest.json"))

        // 2. Un singur tar, ca sa pastram structura de directoare si permisiunile
        //    (cheia privata e 0600 — trebuie sa ramana asa si dupa restaurare).
        progress("Se împachetează…", 0.2)
        let tarURL = work.appendingPathComponent("payload.tar")
        try runTar(["-cf", tarURL.path, "-C", stage.path, "."])

        // 3. Criptare pe blocuri.
        progress("Se criptează…", 0.4)
        var salt = Data(count: 16)
        _ = salt.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 16, $0.baseAddress!) }
        let archiveID = UUID().uuidString
        let iterations = calibratedIterations()
        let key = try deriveKey(password: password, salt: salt, iterations: iterations)

        let header = Header(
            version: formatVersion,
            createdAt: Date(),
            archiveID: archiveID,
            kdf: "PBKDF2-HMAC-SHA256",
            iterations: iterations,
            saltBase64: salt.base64EncodedString(),
            cipher: "AES-256-GCM",
            chunkSize: chunkSize,
            contents: components.filter { manifest[$0.id] != nil }.map(\.label),
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?",
            machineName: Host.current().localizedName ?? "Mac")
        let headerData = try JSONEncoder().encode(header)

        if fm.fileExists(atPath: destination.path) { try fm.removeItem(at: destination) }
        fm.createFile(atPath: destination.path, contents: nil)
        guard let out = FileHandle(forWritingAtPath: destination.path),
              let input = FileHandle(forReadingAtPath: tarURL.path) else {
            throw BackupError.corrupted("nu pot scrie la destinație")
        }
        defer { try? out.close(); try? input.close() }

        try out.write(contentsOf: magic)
        try out.write(contentsOf: withUnsafeBytes(of: UInt32(headerData.count).bigEndian) { Data($0) })
        try out.write(contentsOf: headerData)

        let totalBytes: Int64 = ((try? fm.attributesOfItem(atPath: tarURL.path)[.size]) as? Int64) ?? 0
        var written: Int64 = 0
        var index: UInt64 = 0
        var pending = try input.read(upToCount: chunkSize) ?? Data()
        while true {
            let next = try input.read(upToCount: chunkSize) ?? Data()
            let isLast = next.isEmpty
            try autoreleasepool {
                let sealed = try AES.GCM.seal(pending, using: key,
                                              authenticating: aad(archiveID: archiveID, index: index, isLast: isLast))
                guard let combined = sealed.combined else {
                    throw BackupError.corrupted("sigilarea blocului \(index) a eșuat")
                }
                try out.write(contentsOf: withUnsafeBytes(of: UInt32(combined.count).bigEndian) { Data($0) })
                try out.write(contentsOf: combined)
            }
            written += Int64(pending.count)
            if totalBytes > 0 {
                progress("Se criptează…", 0.4 + 0.55 * Double(written) / Double(totalBytes))
            }
            if isLast { break }
            pending = next
            index += 1
        }
        progress("Gata.", 1.0)
    }

    // MARK: - Inspectare (fara parola)

    static func inspect(archive: URL) throws -> ArchiveInfo {
        guard let handle = FileHandle(forReadingAtPath: archive.path) else {
            throw BackupError.notAnArchive
        }
        defer { try? handle.close() }
        let header = try readHeader(handle)
        return ArchiveInfo(createdAt: header.createdAt, contents: header.contents,
                           appVersion: header.appVersion, machineName: header.machineName)
    }

    private static func readHeader(_ handle: FileHandle) throws -> Header {
        guard let head = try handle.read(upToCount: magic.count), head == magic else {
            throw BackupError.notAnArchive
        }
        guard let lenData = try handle.read(upToCount: 4), lenData.count == 4 else {
            throw BackupError.corrupted("antet trunchiat")
        }
        let length = Int(lenData.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian })
        guard length > 0, length < 1_000_000,
              let headerData = try handle.read(upToCount: length), headerData.count == length else {
            throw BackupError.corrupted("antet trunchiat")
        }
        let header = try JSONDecoder().decode(Header.self, from: headerData)
        guard header.version <= formatVersion else {
            throw BackupError.unsupportedVersion(header.version)
        }
        return header
    }

    // MARK: - Restaurare

    /// Decripteaza si pune fiecare componenta la locul ei pe ACEST Mac.
    /// Caile se recalculeaza local (nu se folosesc cele din arhiva), deci
    /// backup-ul e portabil intre conturi de utilizator diferite.
    @discardableResult
    static func restore(archive: URL,
                        password: String,
                        progress: @escaping (String, Double) -> Void) throws -> [String] {
        let fm = FileManager.default
        guard let input = FileHandle(forReadingAtPath: archive.path) else {
            throw BackupError.notAnArchive
        }
        defer { try? input.close() }

        progress("Se verifică arhiva…", 0.05)
        let header = try readHeader(input)
        guard let salt = Data(base64Encoded: header.saltBase64) else {
            throw BackupError.corrupted("sare invalidă în antet")
        }
        let key = try deriveKey(password: password, salt: salt, iterations: header.iterations)

        let work = fm.temporaryDirectory.appendingPathComponent("gdc-restore-" + UUID().uuidString)
        try fm.createDirectory(at: work, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: work) }

        // 1. Decriptare bloc cu bloc, direct intr-un tar temporar.
        progress("Se decriptează…", 0.15)
        let tarURL = work.appendingPathComponent("payload.tar")
        fm.createFile(atPath: tarURL.path, contents: nil)
        guard let tarOut = FileHandle(forWritingAtPath: tarURL.path) else {
            throw BackupError.corrupted("nu pot scrie fișierul temporar")
        }
        defer { try? tarOut.close() }

        var index: UInt64 = 0
        var sawLast = false
        while true {
            guard let lenData = try input.read(upToCount: 4), !lenData.isEmpty else { break }
            guard lenData.count == 4 else { throw BackupError.corrupted("bloc trunchiat") }
            let length = Int(lenData.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian })
            guard let blob = try input.read(upToCount: length), blob.count == length else {
                throw BackupError.corrupted("bloc trunchiat")
            }
            // Nu stim dinainte daca blocul curent e ultimul, iar marcajul face
            // parte din datele autentificate — incercam ambele variante.
            var opened: Data?
            for isLast in [false, true] {
                if let box = try? AES.GCM.SealedBox(combined: blob),
                   let plain = try? AES.GCM.open(box, using: key,
                                                 authenticating: aad(archiveID: header.archiveID, index: index, isLast: isLast)) {
                    opened = plain
                    sawLast = isLast
                    break
                }
            }
            guard let plain = opened else { throw BackupError.wrongPassword }
            try autoreleasepool { try tarOut.write(contentsOf: plain) }
            if sawLast { break }
            index += 1
        }
        guard sawLast else {
            throw BackupError.corrupted("arhiva se termină brusc — fișierul e incomplet")
        }
        try? tarOut.close()

        // 2. Despachetare.
        progress("Se despachetează…", 0.6)
        let stage = work.appendingPathComponent("payload", isDirectory: true)
        try fm.createDirectory(at: stage, withIntermediateDirectories: true)
        try runTar(["-xf", tarURL.path, "-C", stage.path])

        let manifestURL = stage.appendingPathComponent("manifest.json")
        guard let manifestData = fm.contents(atPath: manifestURL.path),
              let manifest = try? JSONDecoder().decode([String: Bool].self, from: manifestData) else {
            throw BackupError.corrupted("manifest lipsă")
        }

        // 3. Punerea la loc, pe caile ACESTUI Mac.
        progress("Se restaurează…", 0.75)
        var restored: [String] = []
        for (id, isDirectory) in manifest {
            guard let target = destinationURL(forComponentID: id) else { continue }
            let staged = stage.appendingPathComponent(id)
            guard fm.fileExists(atPath: staged.path) else { continue }
            do {
                try fm.createDirectory(at: target.deletingLastPathComponent(),
                                       withIntermediateDirectories: true)
                // Ce exista deja se da la o parte cu sufix `.inainte-de-restaurare`,
                // niciodata sters: o restaurare gresita pe Mac-ul bun nu trebuie
                // sa distruga starea curenta.
                if fm.fileExists(atPath: target.path) {
                    let backup = target.appendingPathExtension("inainte-de-restaurare")
                    try? fm.removeItem(at: backup)
                    try fm.moveItem(at: target, to: backup)
                }
                try fm.copyItem(at: staged, to: target)
                if id == "private_key" {
                    // Cheia privata trebuie sa ramana citibila doar de user.
                    try? fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: target.path)
                }
                restored.append(id)
                _ = isDirectory
            } catch {
                progress("Nu am putut restaura \(id): \(error.localizedDescription)", 0.75)
            }
        }
        progress("Gata.", 1.0)
        return restored
    }

    /// Unde ajunge fiecare componenta pe MASINA CURENTA. Calea din arhiva nu
    /// se foloseste niciodata direct — pe un Mac nou, numele contului si deci
    /// calea catre home difera.
    private static func destinationURL(forComponentID id: String) -> URL? {
        let licenseDir = appSupport.appendingPathComponent("GDC License Manager", isDirectory: true)
        let furnizorDir = appSupport.appendingPathComponent("GDCPluginManagerFurnizor", isDirectory: true)
        switch id {
        case "private_key":    return licenseDir.appendingPathComponent("private_key.txt")
        case "public_key":     return licenseDir.appendingPathComponent("public_key.txt")
        case "sales":          return licenseDir.appendingPathComponent("furnizor_sales.csv")
        case "customers_legacy": return licenseDir.appendingPathComponent("customers.csv")
        case "products_legacy":  return licenseDir.appendingPathComponent("products.txt")
        case "pending_covers": return furnizorDir.appendingPathComponent("pending-covers", isDirectory: true)
        case "github_token":   return vendorSourceRoot.appendingPathComponent("Sources/GDCPluginManagerCore/PrivateCatalogAuth.swift")
        case "supabase_key":   return vendorSourceRoot.appendingPathComponent("Sources/GDCPluginManagerFurnizor/SupabaseAdminConfig.swift")
        case "catalog_docs":   return vendorSourceRoot.appendingPathComponent("docs", isDirectory: true)
        case "product_files":  return RepoCheckoutPaths.privateFilesRepo
        default:               return nil
        }
    }

    // MARK: - tar

    private static func runTar(_ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        process.arguments = arguments
        let errPipe = Pipe()
        process.standardError = errPipe
        try process.run()
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw BackupError.tarFailed(String(data: errData, encoding: .utf8) ?? "cod \(process.terminationStatus)")
        }
    }
}
