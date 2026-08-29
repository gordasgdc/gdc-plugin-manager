import Foundation
import SwiftUI

public enum PluginType: String, Codable, CaseIterable, Identifiable {
    case dctl
    case lut
    case fuse
    /// A `.drx` grade + thumbnail pair for DaVinci Resolve's Gallery.
    /// Unlike dctl/lut/fuse, Resolve doesn't scan a folder for these —
    /// there is no such folder. `installDirectory` here is just a local
    /// staging area; the real "install" is done by PowerGradeImporter,
    /// which either imports straight into Resolve's Gallery via
    /// scripting (Resolve Studio, Resolve running) or, failing that,
    /// leaves the verified files here with manual-import instructions.
    case powerGrade
    /// A DaVinci Resolve Studio OFX plugin — an `.ofx.bundle` folder
    /// (Contents/MacOS/<binary>, Contents/Info.plist, …), installed as
    /// one whole unit, never touched file-by-file. Resolve identifies it
    /// by that exact bundle folder name, so — unlike a LUT/DCTL pack,
    /// which installs into a subfolder named after the catalog id — an
    /// OFX product's install folder must keep its original bundle name
    /// (see `PluginItem.bundleFolderName`).
    case ofx

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .dctl: return "DCTL"
        case .lut: return "LUT"
        case .fuse: return "Fuse"
        case .powerGrade: return "PowerGrade"
        case .ofx: return "OFX"
        }
    }

    /// One distinct, representative SF Symbol per category — used as the
    /// sidebar icon for the whole category, and as a card's icon when
    /// the vendor hasn't set a custom `iconSymbol` for that particular
    /// product.
    public var defaultSymbol: String {
        switch self {
        case .dctl: return "wand.and.stars"
        case .lut: return "eyedropper.halffull"
        case .fuse: return "puzzlepiece.extension"
        case .powerGrade: return "paintpalette"
        case .ofx: return "camera.filters"
        }
    }

    /// One distinct, well-separated color per category — used to tint a
    /// product's icon and its type badge, so categories read apart at a
    /// glance in a mixed grid. Deliberately not reused as a semantic
    /// color anywhere else in the client UI (badge.free is green,
    /// badge.trial is blue — different meaning, different spot on the
    /// card, kept distinguishable by label text regardless).
    public var tintColor: Color {
        switch self {
        case .dctl: return .yellow
        case .lut: return .green
        case .fuse: return .pink
        case .powerGrade: return .purple
        case .ofx: return .cyan
        }
    }

    /// Where DaVinci Resolve actually reads this file type from, on
    /// macOS. Verified against Resolve's own documentation/forum
    /// guidance, not assumed:
    /// - DCTL and LUT share the same folder (Resolve tells them apart by
    ///   file extension).
    /// - Fuses live under Resolve's own Fusion folder.
    /// - PowerGrades have no such folder (see the `powerGrade` case
    ///   doc) — this is only a staging directory under the user's own
    ///   Movies folder, not something Resolve scans.
    public var installDirectory: URL {
        let libraryDir = FileManager.default.urls(for: .libraryDirectory, in: .localDomainMask).first!
        switch self {
        case .lut:
            return libraryDir
                .appendingPathComponent("Application Support")
                .appendingPathComponent("Blackmagic Design")
                .appendingPathComponent("DaVinci Resolve")
                .appendingPathComponent("LUT")
        case .dctl:
            // Bug real, gasit revizuind cerinta userului: DCTL-urile
            // stateau in acelasi folder ca LUT-urile obisnuite (.../LUT/),
            // fara subfolderul "DCTL" dedicat pe care Resolve il cauta
            // specific pentru fisierele .dctl. Fara acest subfolder, un
            // .dctl copiat plat in LUT/ nu apare corect ca nod DCTL in
            // pagina Color. Instalarile vechi (dinainte de acest fix) au
            // ramas orfane in LUT/ - un reinstall/update le muta automat
            // in noua locatie corecta.
            return libraryDir
                .appendingPathComponent("Application Support")
                .appendingPathComponent("Blackmagic Design")
                .appendingPathComponent("DaVinci Resolve")
                .appendingPathComponent("LUT")
                .appendingPathComponent("DCTL")
        case .fuse:
            return libraryDir
                .appendingPathComponent("Application Support")
                .appendingPathComponent("Blackmagic Design")
                .appendingPathComponent("DaVinci Resolve")
                .appendingPathComponent("Fusion")
                .appendingPathComponent("Fuses")
        case .powerGrade:
            return FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first!
                .appendingPathComponent("GDC PowerGrades")
        case .ofx:
            // The standard cross-host OFX location on macOS (used by
            // Resolve, Nuke, Fusion standalone, etc.) — confirmed via
            // Blackmagic's own forum guidance: root /Library, never the
            // per-user ~/Library. Requires an admin-elevated write (see
            // InstallManager.elevatedCopy), same as the other top-level
            // /Library paths above.
            return URL(fileURLWithPath: "/Library/OFX/Plugins")
        }
    }
}

/// One file belonging to a PluginItem, as it sits in the private
/// gdc-plugin-manager-files repo — `path` is the full path inside that
/// repo (e.g. "lut-wedding-style/1.2.0/WeddingStyle1.cube"), fetched
/// through an authenticated GitHub Contents API request (see
/// PrivateCatalogAuth.swift / InstallManager.swift), never a plain
/// public URL.
public struct PluginFile: Codable, Hashable {
    public let path: String
    public let sha256: String

    public init(path: String, sha256: String) {
        self.path = path
        self.sha256 = sha256
    }

    /// The name this file should be saved as on disk — last path
    /// component of `path`.
    public var filename: String { (path as NSString).lastPathComponent }
}

/// Unde locuiesc imaginile de prezentare (coperti) ale catalogului.
///
/// ARCHITECTURE NOTE — de ce in repo-ul PUBLIC, nu in cel privat de fisiere:
/// fisierele vandabile (.dctl/.cube/.ofx) stau in gdc-plugin-manager-files
/// (privat) si se descarca autentificat, prin GitHub Contents API. Coperile
/// NU sunt continut protejat, sunt material de prezentare — si mai ales
/// site-ul public gordas.dev trebuie sa le poata afisa, iar el nu are cum
/// sa se autentifice. Deci stau in repo-ul public, langa catalog.json:
///
///     gdc-plugin-manager/docs/covers/<id>.jpg   ->  https://gordas.dev/covers/<id>.jpg
///
/// SISTEM HIBRID — un singur camp `coverImage`, doua surse posibile:
///
///   1. UPLOAD LOCAL: cale relativa ("covers/<id>.jpg"). Furnizor a
///      comprimat imaginea cu ImageProcessor si a scris-o in docs/covers/,
///      iar ea se publica odata cu catalog.json. Se rezolva fata de
///      `baseURL`, ca sa putem schimba domeniul dintr-un singur loc.
///
///   2. URL EXTERN: un link absolut ("https://cdn.exemplu.com/x.jpg"),
///      gazduit de furnizor pe CDN-ul/serverul lui. Se foloseste ca atare,
///      NU trece prin compresie si nu ocupa spatiu in repo.
///
/// Un singur camp (nu doua) tocmai ca sa nu existe starea ambigua "si
/// upload, si URL — care castiga?". Ce e scris in `coverImage` e sursa
/// adevarului, iar `isExternal` spune doar din care ramura provine.
///
/// WARNING (varianta 2): un URL extern iese complet din controlul nostru —
/// daca furnizorul sterge fisierul de pe CDN sau ii expira domeniul,
/// coperta dispare din aplicatie si de pe site fara ca noi sa aflam.
/// Clientii TREBUIE sa trateze esecul de incarcare ca pe un caz normal si
/// sa cada inapoi pe `iconSymbol`, nu sa arate un chenar spart.
public enum CatalogAssets {
    /// Acelasi domeniu ca CatalogService.catalogURL / UpdateChecker.updateURL.
    public static let baseURL = URL(string: "https://gordas.dev/")!

    /// Numele folderului din `docs/` in care Furnizor scrie coperile
    /// urcate local (varianta 1).
    public static let coversFolderName = "covers"

    /// True daca valoarea e un link extern (varianta 2), nu o cale
    /// relativa gazduita de noi. Folosit de Furnizor ca sa stie ca nu are
    /// ce sterge din docs/covers/ cand se schimba imaginea.
    public static func isExternal(_ coverImage: String?) -> Bool {
        guard let coverImage else { return false }
        let lower = coverImage.lowercased()
        return lower.hasPrefix("http://") || lower.hasPrefix("https://")
    }

    /// Transforma valoarea din catalog intr-un URL descarcabil, indiferent
    /// de varianta. nil daca produsul nu are inca o coperta.
    ///
    /// NOTE: `URL(string:relativeTo:)` ar rezolva oricum corect si un URL
    /// absolut (ignora base-ul), dar verificam explicit ca sa fie evident
    /// la citire ca sistemul hibrid e intentionat, nu un efect secundar.
    public static func imageURL(for coverImage: String?) -> URL? {
        guard let coverImage, !coverImage.isEmpty else { return nil }
        if isExternal(coverImage) { return URL(string: coverImage) }
        return URL(string: coverImage, relativeTo: baseURL)
    }
}

/// Compatibilitatea de sistem de operare a unui produs — folosita de
/// Client (buton dezactivat cu "Incompatibil cu sistemul tau") si de
/// Furnizor (selector la publicare). Valoare implicita `.crossPlatform`:
/// toate produsele existente inainte de acest camp (DCTL/LUT/Fuse/OFX
/// pentru Resolve) chiar RULEAZA identic pe ambele platforme, asa ca
/// decodarea unei intrari vechi (fara aceasta cheie) trebuie sa insemne
/// "merge oriunde", nu "ascunde-l pe toata lumea".
public enum SupportedOS: String, Codable, CaseIterable, Identifiable {
    case macOS
    case windows
    case crossPlatform

    public var id: String { rawValue }

    /// True daca produsul e instalabil pe platforma curenta a clientului.
    public func allows(current: SupportedOS) -> Bool {
        self == .crossPlatform || self == current
    }

    #if os(macOS)
    public static let current: SupportedOS = .macOS
    #else
    public static let current: SupportedOS = .windows
    #endif

    /// Simbol SF Symbols pentru badge-ul de compatibilitate de pe card —
    /// înlocuiește emoji-urile 🍎/🪟/🔄 (2026-08-29, cerut explicit: "nu-mi
    /// place, prefer să fie... impecabil, profesionist"). SF Symbols sunt
    /// vectoriale (identic ca principiu cu un SVG — scalează perfect,
    /// se tint-uiesc cu culoarea din temă), nativ Apple, nu emoji color.
    public var badgeSymbol: String {
        switch self {
        case .macOS: return "apple.logo"
        case .windows: return "pc"
        case .crossPlatform: return "arrow.triangle.2.circlepath"
        }
    }

    /// Etichetă scurtă, pentru accesibilitate/tooltip lângă simbol.
    public var badgeLabel: String {
        switch self {
        case .macOS: return "Mac"
        case .windows: return "Windows"
        case .crossPlatform: return "Mac + Windows"
        }
    }
}

/// One entry in the catalog — one sellable DCTL/LUT/Fuse (or a whole
/// pack of several) from Cristi's own product line (never a general
/// "browse anyone's plugin" catalog).
///
/// `id` is the input to the SHA-512 product hash embedded in every
/// license serial for this item (see LicenseCore.productHash) — it must
/// never change once a single unit has sold, and a retired id must never
/// be reused for an unrelated product, or old serials would wrongly
/// unlock it.
/// Set opțional de linkuri către rețele sociale ale unei resurse/produs —
/// Etapa 2 din Planul Integrat de Upgrade v2.0 (2026-08-29). Toate 100%
/// opționale: dacă un câmp e nil, iconița corespunzătoare nu apare deloc
/// pe cardul din Client (niciodată dezactivată/goală). Struct separat
/// (nu 4 câmpuri direct pe `PluginItem`) ca să poată fi reutilizat 1:1 pe
/// alte tipuri de conținut (Aplicații/Audio/etc.) la o etapă viitoare,
/// fără să dubleze cele 4 chei peste tot.
public struct SocialLinks: Codable, Hashable {
    public let facebookURL: String?
    public let youtubeURL: String?
    public let instagramURL: String?
    public let tiktokURL: String?
    /// LinkedIn — adăugat 2026-08-29 la cererea explicită a lui Cristi
    /// ("să adăugăm și LinkedIn"). Opțional ca toate celelalte; o valoare
    /// absentă din `catalog.json` decodează nil (Codable sintetizat trata
    /// deja o cheie lipsă ca nil pentru un Optional), deci fiecare produs/
    /// resursă publicată înainte rămâne exact ce era.
    public let linkedinURL: String?

    public init(facebookURL: String? = nil, youtubeURL: String? = nil, instagramURL: String? = nil,
                tiktokURL: String? = nil, linkedinURL: String? = nil) {
        self.facebookURL = facebookURL
        self.youtubeURL = youtubeURL
        self.instagramURL = instagramURL
        self.tiktokURL = tiktokURL
        self.linkedinURL = linkedinURL
    }

    /// True dacă niciunul dintre cele 5 linkuri nu e completat — folosit
    /// ca să nu afișăm un rând gol de iconițe pe card.
    public var isEmpty: Bool {
        facebookURL == nil && youtubeURL == nil && instagramURL == nil
            && tiktokURL == nil && linkedinURL == nil
    }
}

public struct PluginItem: Codable, Identifiable, Hashable {
    public let id: String
    public let name: String
    public let type: PluginType
    public let description: String
    public let version: String
    /// One file (a single DCTL/LUT), or several (a pack — e.g. a whole
    /// folder of LUTs published together). See `installFolderName`.
    public let files: [PluginFile]
    public let iconSymbol: String?
    public let priceEUR: Double
    /// If true, no license is required at all — the client can install
    /// and update this item directly, for free, with no purchase/
    /// activation step. `priceEUR` is ignored (treated as 0) when this
    /// is true.
    public let isFree: Bool
    /// A watermarked trial version of a paid product, published as its
    /// own separate catalog entry (own id, own card) — always paired
    /// with `isFree = true` (no license needed either), but shown with a
    /// distinct "Probă" badge instead of "Gratuit" so customers know it's
    /// a limited/watermarked sample, not a genuinely free product. The
    /// watermark itself lives inside the file — the app has no notion of
    /// it beyond this label.
    public let isTrial: Bool
    /// Link to an unlisted YouTube tutorial for this product, shown as a
    /// small "i" info button on its card — nil until Cristi adds one
    /// (the button is hidden, not disabled, when nil), and freely
    /// editable after publishing without touching the product's files.
    public let youtubeURL: String?
    /// OFX only: the exact original `.ofx.bundle` folder name, as picked
    /// in Furnizor — Resolve identifies an OFX plugin by that literal
    /// folder name, so (unlike a LUT/DCTL pack, which installs under a
    /// folder named after `id`) this must be preserved verbatim. nil for
    /// every other type, where the `id`-named subfolder is used instead.
    public let bundleFolderName: String?
    /// Coperta produsului: fie cale relativa ("covers/<id>.jpg", urcata
    /// local si comprimata), fie URL extern absolut — vezi `CatalogAssets`.
    /// nil daca produsul nu are inca una; cardul cade atunci pe `iconSymbol`.
    ///
    /// NOTE: la upload local se foloseste presetul `.icon` (patrat
    /// 512x512) — vezi ImageProcessor.Preset.
    public let coverImage: String?
    /// Compatibilitate OS — vezi `SupportedOS`. Implicit `.crossPlatform`
    /// (toate produsele existente pana acum ruleaza pe ambele platforme).
    public let supportedOS: SupportedOS
    /// Link opțional către magazinul/achiziția externă a produsului (ex.
    /// pagina de pe un marketplace terț) — Etapa 2 (2026-08-29). Afișat
    /// ca buton separat pe card doar dacă nu e nil; complet independent
    /// de `priceEUR`/`isFree` (un produs poate fi vândut și direct prin
    /// GDC, și listat și extern).
    public let purchaseURL: String?
    /// Link opțional către un demo/preview (pagină, video, sample) —
    /// Etapa 2 (2026-08-29). Distinct de `youtubeURL` (acela e tutorial
    /// de UTILIZARE; acesta e o PREZENTARE a produsului înainte de achiziție).
    public let demoURL: String?
    /// Linkuri opționale către rețele sociale ale acestei resurse — vezi
    /// `SocialLinks`. nil (nu doar toate câmpurile interne nil) pentru
    /// orice produs publicat înainte de Etapa 2.
    public let socialLinks: SocialLinks?
    /// Valabilitate temporală opțională — Etapa 4 extinsă (2026-08-29,
    /// cerut explicit: "valabilitate temporală trebuie să fie la toate
    /// rubricile"). Vezi `Scheduling`. `nil` = mereu vizibil.
    public let scheduling: Scheduling?
    /// Sumă de susținere PROMOȚIONALĂ, temporară — activă doar cât timp
    /// `scheduling` e activ (vezi `effectivePriceEUR`). Rămâne în
    /// limitele Regulii 3 (Partea 1): tot o sumă de DONAȚIE, niciodată
    /// afișată cu cuvintele "preț redus"/"discount"/"reducere" — badge-ul
    /// din Client o etichetează explicit "Susținere promoțională",
    /// niciodată "-X% OFF" (acela e rezervat EXCLUSIV ofertelor de la
    /// branduri PARTENERE, `PartnerOffer`, o relație comercială diferită).
    public let promoPriceEUR: Double?

    public init(id: String, name: String, type: PluginType, description: String, version: String,
                files: [PluginFile], iconSymbol: String?, priceEUR: Double, isFree: Bool = false, isTrial: Bool = false,
                youtubeURL: String? = nil, bundleFolderName: String? = nil, coverImage: String? = nil, supportedOS: SupportedOS = .crossPlatform,
                purchaseURL: String? = nil, demoURL: String? = nil, socialLinks: SocialLinks? = nil,
                scheduling: Scheduling? = nil, promoPriceEUR: Double? = nil) {
        self.id = id
        self.name = name
        self.type = type
        self.description = description
        self.version = version
        self.files = files
        self.iconSymbol = iconSymbol
        self.priceEUR = priceEUR
        self.isFree = isFree
        self.isTrial = isTrial
        self.youtubeURL = youtubeURL
        self.bundleFolderName = bundleFolderName
        self.coverImage = coverImage
        self.supportedOS = supportedOS
        self.purchaseURL = purchaseURL
        self.demoURL = demoURL
        self.socialLinks = socialLinks
        self.scheduling = scheduling
        self.promoPriceEUR = promoPriceEUR
    }

    /// URL-ul absolut al copertii, gata de descarcat (nil daca nu are).
    public var coverImageURL: URL? { CatalogAssets.imageURL(for: coverImage) }

    /// Suma de afișat ACUM — cea promoțională, dacă `promoPriceEUR` e
    /// setat ȘI `scheduling` e activ acum; altfel `priceEUR` normal.
    public var effectivePriceEUR: Double {
        if let promoPriceEUR, scheduling?.isActiveNow ?? false { return promoPriceEUR }
        return priceEUR
    }

    public var isPromoActive: Bool {
        promoPriceEUR != nil && (scheduling?.isActiveNow ?? false)
    }

    // Custom decode: supports both the current `files` array AND the
    // original single-file catalog format (`filePath` + `sha256`, no
    // `isFree`/`isTrial`/`youtubeURL`/`bundleFolderName`), so any entry
    // ever published still decodes cleanly.
    private enum CodingKeys: String, CodingKey {
        case id, name, type, description, version, files, filePath, sha256, iconSymbol, priceEUR, isFree, isTrial, youtubeURL, bundleFolderName, coverImage, supportedOS, purchaseURL, demoURL, socialLinks, scheduling, promoPriceEUR
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        type = try c.decode(PluginType.self, forKey: .type)
        description = try c.decode(String.self, forKey: .description)
        version = try c.decode(String.self, forKey: .version)
        if let decodedFiles = try c.decodeIfPresent([PluginFile].self, forKey: .files) {
            files = decodedFiles
        } else {
            // Legacy single-file entry.
            let legacyPath = try c.decode(String.self, forKey: .filePath)
            let legacySHA = try c.decode(String.self, forKey: .sha256)
            files = [PluginFile(path: legacyPath, sha256: legacySHA)]
        }
        iconSymbol = try c.decodeIfPresent(String.self, forKey: .iconSymbol)
        priceEUR = try c.decode(Double.self, forKey: .priceEUR)
        isFree = try c.decodeIfPresent(Bool.self, forKey: .isFree) ?? false
        isTrial = try c.decodeIfPresent(Bool.self, forKey: .isTrial) ?? false
        youtubeURL = try c.decodeIfPresent(String.self, forKey: .youtubeURL)
        bundleFolderName = try c.decodeIfPresent(String.self, forKey: .bundleFolderName)
        // Cheie noua (2026-08): intrarile publicate inainte de sistemul de
        // coperti nu o au deloc, deci decodeIfPresent -> nil, fara eroare.
        coverImage = try c.decodeIfPresent(String.self, forKey: .coverImage)
        // Cheie noua (2026-08-25): intrarile vechi nu o au -> .crossPlatform,
        // pastrand comportamentul actual (instalabil pe ambele platforme).
        supportedOS = try c.decodeIfPresent(SupportedOS.self, forKey: .supportedOS) ?? .crossPlatform
        // Chei noi (Etapa 2, 2026-08-29) — orice produs publicat inainte
        // nu le are, decodeIfPresent -> nil, fara eroare.
        purchaseURL = try c.decodeIfPresent(String.self, forKey: .purchaseURL)
        demoURL = try c.decodeIfPresent(String.self, forKey: .demoURL)
        socialLinks = try c.decodeIfPresent(SocialLinks.self, forKey: .socialLinks)
        // Chei noi (Etapa 4 extinsă, 2026-08-29) — orice produs publicat
        // inainte nu le are, decodeIfPresent -> nil, fara eroare.
        scheduling = try c.decodeIfPresent(Scheduling.self, forKey: .scheduling)
        promoPriceEUR = try c.decodeIfPresent(Double.self, forKey: .promoPriceEUR)
    }

    // Written explicitly (not synthesized) because CodingKeys carries
    // legacy-only cases (filePath/sha256) that don't map to a stored
    // property — synthesis requires an exact match, so it can't derive
    // encode(to:) from this CodingKeys on its own.
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(type, forKey: .type)
        try c.encode(description, forKey: .description)
        try c.encode(version, forKey: .version)
        try c.encode(files, forKey: .files)
        try c.encodeIfPresent(iconSymbol, forKey: .iconSymbol)
        try c.encode(priceEUR, forKey: .priceEUR)
        try c.encode(isFree, forKey: .isFree)
        try c.encode(isTrial, forKey: .isTrial)
        try c.encodeIfPresent(youtubeURL, forKey: .youtubeURL)
        try c.encodeIfPresent(bundleFolderName, forKey: .bundleFolderName)
        try c.encodeIfPresent(coverImage, forKey: .coverImage)
        try c.encode(supportedOS, forKey: .supportedOS)
        try c.encodeIfPresent(purchaseURL, forKey: .purchaseURL)
        try c.encodeIfPresent(demoURL, forKey: .demoURL)
        try c.encodeIfPresent(socialLinks, forKey: .socialLinks)
        try c.encodeIfPresent(scheduling, forKey: .scheduling)
        try c.encodeIfPresent(promoPriceEUR, forKey: .promoPriceEUR)
    }

    /// True for a multi-file pack (e.g. a whole folder of LUTs published
    /// together) — these install into their own named subfolder inside
    /// DaVinci Resolve's plugin folder, instead of loose at the root,
    /// so a pack stays visually grouped in Resolve's own browser.
    public var isPack: Bool { files.count > 1 }

    public var priceDisplay: String {
        priceEUR.formatted(.currency(code: "EUR"))
    }
}

/// One priced duration option on a Course (e.g. "1 oră" / "2 ore" /
/// "1 la 1") — fully custom per course, no shared fixed set.
public struct CourseOption: Codable, Hashable, Identifiable {
    public let id: String
    public let label: String
    public let priceEUR: Double

    public init(id: String = UUID().uuidString, label: String, priceEUR: Double) {
        self.id = id
        self.label = label
        self.priceEUR = priceEUR
    }

    public var priceDisplay: String {
        priceEUR.formatted(.currency(code: "EUR"))
    }
}

/// A bookable course/session — not a downloadable product. No files, no
/// install, no license; the client just shows it and lets the customer
/// reach out (WhatsApp) to book one of its priced options.
/// Valabilitate temporală opțională (From - To) — Etapa 4 din Planul
/// Integrat de Upgrade v2.0 (2026-08-29). Aplicat la Cursuri, Materiale,
/// Evenimente și Oferte Parteneri: dacă e setat, conținutul apare automat
/// în Client doar între `startDate` și `endDate` (comparat cu ora curentă
/// a dispozitivului clientului, nu cu ora serverului — suficient pentru
/// acest caz de utilizare, fără nevoie de sincronizare de timp server).
/// `nil` (struct absent) = mereu vizibil, comportament identic cu înainte
/// de Etapa 4 — orice conținut existent, publicat fără scheduling,
/// continuă să apară neschimbat.
public struct Scheduling: Codable, Hashable {
    public let startDate: Date?
    public let endDate: Date?

    public init(startDate: Date? = nil, endDate: Date? = nil) {
        self.startDate = startDate
        self.endDate = endDate
    }

    /// True dacă acest conținut ar trebui să fie vizibil ACUM. Fără
    /// `startDate` = deja pornit; fără `endDate` = nu expiră niciodată.
    public var isActiveNow: Bool {
        let now = Date()
        if let startDate, now < startDate { return false }
        if let endDate, now > endDate { return false }
        return true
    }

    public var isEmpty: Bool { startDate == nil && endDate == nil }
}

public struct Course: Codable, Identifiable, Hashable {
    public let id: String
    public let name: String
    public let description: String
    public let options: [CourseOption]
    /// Coperta cursului — preset `.cover` (max 1600px), pentru ca aici
    /// vrem sa se vada detaliul intr-un preview marit, nu doar un simbol.
    /// Cheie optionala: cursurile publicate inainte decodeaza cu nil.
    public let coverImage: String?
    /// Valabilitate temporală opțională — Etapa 4 (2026-08-29). Vezi `Scheduling`.
    public let scheduling: Scheduling?
    /// Rețele sociale opționale — 2026-08-29, cerut explicit ("să apară la
    /// toate rubricile", nu doar la produse/resurse). Codable sintetizat:
    /// o cheie lipsă într-un `catalog.json` vechi decodează nil automat, iar
    /// encoderul o omite când e nil — 100% retrocompatibil, ca `scheduling`.
    public let socialLinks: SocialLinks?

    public init(id: String, name: String, description: String, options: [CourseOption], coverImage: String? = nil, scheduling: Scheduling? = nil, socialLinks: SocialLinks? = nil) {
        self.id = id
        self.name = name
        self.description = description
        self.options = options
        self.coverImage = coverImage
        self.scheduling = scheduling
        self.socialLinks = socialLinks
    }

    public var coverImageURL: URL? { CatalogAssets.imageURL(for: coverImage) }
}

/// A link to one of Cristi's other apps (CursorPro GDC, GDC Production
/// Manager, etc.) shown in the client app's "Aplicații" section — just a
/// name and an outbound link, nothing to install.
public struct AppLink: Codable, Identifiable, Hashable {
    public let id: String
    public let name: String
    public let url: String
    /// Same optional YouTube tutorial link as `PluginItem.youtubeURL` —
    /// a missing key in older catalog entries decodes as nil automatically
    /// (Swift's Codable synthesis treats a missing key as nil for an
    /// Optional property), so this needs no custom CodingKeys/init here.
    public let youtubeURL: String?

    /// Coperta aplicatiei — preset `.icon` (patrat), la fel ca PartnerStore:
    /// e un logo, recunoscut dupa forma, nu dupa detaliu. Adaugat 2026-08-24,
    /// deci catalogul vechi (fara aceasta cheie) decodeaza cu nil automat.
    public let coverImage: String?
    /// Valabilitate temporală opțională — Etapa 4 extinsă (2026-08-29). Vezi `Scheduling`.
    public let scheduling: Scheduling?
    /// Rețele sociale opționale — 2026-08-29. Vezi `Course.socialLinks`.
    public let socialLinks: SocialLinks?

    public init(id: String, name: String, url: String, youtubeURL: String? = nil, coverImage: String? = nil, scheduling: Scheduling? = nil, socialLinks: SocialLinks? = nil) {
        self.youtubeURL = youtubeURL
        self.id = id
        self.name = name
        self.url = url
        self.coverImage = coverImage
        self.scheduling = scheduling
        self.socialLinks = socialLinks
    }

    public var coverImageURL: URL? { CatalogAssets.imageURL(for: coverImage) }
}

/// One audio file/pack in the client's "Audio" section — modeled 1:1 on
/// `AppLink` (own catalog collection, own sidebar entry, no license/
/// install), but with an extra `description` field since an audio
/// asset (format, metadate, ce conține) needs more context than a bare
/// name+link. `url` points at the audio file/pachet (descărcare directă
/// sau stocare externă) — nu trece prin `gdc-plugin-manager-files`/
/// licențiere, la fel ca Aplicații.
public struct AudioTrack: Codable, Identifiable, Hashable {
    public let id: String
    public let name: String
    public let description: String
    public let url: String
    public let youtubeURL: String?
    /// Coperta piesei/pachetului audio — preset `.icon`, la fel ca AppLink.
    public let coverImage: String?
    /// Valabilitate temporală opțională — Etapa 4 extinsă (2026-08-29). Vezi `Scheduling`.
    public let scheduling: Scheduling?

    public init(id: String, name: String, description: String, url: String, youtubeURL: String? = nil, coverImage: String? = nil, scheduling: Scheduling? = nil) {
        self.id = id
        self.name = name
        self.description = description
        self.url = url
        self.youtubeURL = youtubeURL
        self.coverImage = coverImage
        self.scheduling = scheduling
    }

    public var coverImageURL: URL? { CatalogAssets.imageURL(for: coverImage) }
}

/// A book, online course, or guide sold by a third party (Amazon,
/// Gumroad, Udemy, …) — unlike `Course`, this is NOT bookable via
/// WhatsApp: the client just shows it and links straight out to
/// `externalURL` to buy. No files, no license, no install.
public struct EducationalResource: Codable, Identifiable, Hashable {
    public enum Kind: String, Codable, CaseIterable, Identifiable {
        case course, book, guide
        public var id: String { rawValue }
        public var label: String {
            switch self {
            case .course: return "Curs"
            case .book: return "Carte"
            case .guide: return "Ghid"
            }
        }
    }

    public let id: String
    public let name: String
    public let description: String
    public let kind: Kind
    public let externalURL: String
    public let youtubeURL: String?
    /// Coperta materialului (coperta cartii/cursului) — preset `.cover`.
    public let coverImage: String?
    /// Valabilitate temporală opțională — Etapa 4 (2026-08-29). Vezi `Scheduling`.
    public let scheduling: Scheduling?
    /// Rețele sociale opționale — 2026-08-29. Vezi `Course.socialLinks`.
    public let socialLinks: SocialLinks?

    public init(id: String, name: String, description: String, kind: Kind, externalURL: String, youtubeURL: String? = nil, coverImage: String? = nil, scheduling: Scheduling? = nil, socialLinks: SocialLinks? = nil) {
        self.id = id
        self.name = name
        self.description = description
        self.kind = kind
        self.externalURL = externalURL
        self.youtubeURL = youtubeURL
        self.coverImage = coverImage
        self.scheduling = scheduling
        self.socialLinks = socialLinks
    }

    public var coverImageURL: URL? { CatalogAssets.imageURL(for: coverImage) }
}

/// A community announcement — workshop, course cohort, or festival —
/// shown in the client's "Evenimente" section. Just informational: a
/// date range as free text (no calendar logic needed), a location, and
/// an outbound link for details/registration. No files, no license.
public struct Event: Codable, Identifiable, Hashable {
    public let id: String
    public let title: String
    public let description: String
    /// Free text on purpose (e.g. "15-17 martie 2026") — a festival or
    /// multi-day workshop doesn't fit a single Date, and the vendor
    /// tool has no need for calendar math on it.
    public let dateDisplay: String
    public let location: String
    public let externalURL: String
    public let youtubeURL: String?

    /// Afisul evenimentului — preset `.cover`. Aici imaginea chiar poarta
    /// informatie (data, lista de invitati, program), deci e cazul in care
    /// lightbox-ul din client/site conteaza cel mai mult.
    public let coverImage: String?
    /// Valabilitate temporală opțională — Etapa 4 (2026-08-29). Vezi
    /// `Scheduling`. Distinctă de `dateDisplay` (text liber, informativ
    /// despre CÂND are loc evenimentul) — aceasta controlează CÂND
    /// apare/dispare anunțul în Client, cele două nu sunt legate.
    public let scheduling: Scheduling?
    /// Rețele sociale opționale — 2026-08-29. Vezi `Course.socialLinks`.
    public let socialLinks: SocialLinks?

    public init(id: String, title: String, description: String, dateDisplay: String, location: String, externalURL: String, youtubeURL: String? = nil, coverImage: String? = nil, scheduling: Scheduling? = nil, socialLinks: SocialLinks? = nil) {
        self.socialLinks = socialLinks
        self.id = id
        self.title = title
        self.description = description
        self.dateDisplay = dateDisplay
        self.location = location
        self.externalURL = externalURL
        self.youtubeURL = youtubeURL
        self.coverImage = coverImage
        self.scheduling = scheduling
    }

    public var coverImageURL: URL? { CatalogAssets.imageURL(for: coverImage) }
    /// Link Google Maps generat din `location` — Etapa 5 (2026-08-29).
    public var mapsURL: URL? { MapsLink.url(for: location) }
}

/// Categoria unui service partener din secțiunea "Service & Reparații
/// Echipament" — determină iconița din grilă și gruparea vizuală.
public enum ServiceCategory: String, Codable, CaseIterable, Identifiable {
    case drone
    case camera
    case optics
    case urgent

    public var id: String { rawValue }

    // Fara `label` aici in mod deliberat: Core nu are acces la
    // Localization.swift (target separat, GDCPluginManager) — eticheta
    // afisata (RO/EN/ES) se rezolva in Client, prin L.t (vezi
    // ContentView.swift, serviceCategoryLabel(_:)), nu hardcodata aici.

    public var symbol: String {
        switch self {
        case .drone: return "airplane.circle.fill"
        case .camera: return "camera.fill"
        case .optics: return "camera.aperture"
        case .urgent: return "bolt.fill"
        }
    }
}

/// Un partener de service/reparații echipament foto-video (drone,
/// camere, obiective) — afișat în secțiunea "Service & Reparații
/// Echipament" din sidebar. La fel ca `PartnerStore`: doar informativ,
/// niciun fișier, nicio licență.
/// Link direct către Google Maps, dintr-un text de adresă liber (nu
/// coordonate) — Etapa 5 din Planul Integrat de Upgrade v2.0
/// (2026-08-29). Folosește endpoint-ul de căutare public al Google Maps
/// (`api=1`), care nu necesită cheie API — deschide browserul/aplicația
/// Maps cu textul căutat, exact ca un search manual.
public enum MapsLink {
    /// Termeni fără sens ca adresă fizică — un curs/eveniment/service
    /// "Online" nu are unde deschide o hartă. Semnalat explicit
    /// (2026-08-29): "am multe locuri în care e online... chiar nimica,
    /// că este online" — mai bine ascundem butonul decât să trimitem la
    /// o căutare Google Maps absurdă pentru cuvântul "online".
    private static let nonPhysicalTerms: Set<String> = [
        "online", "webinar", "virtual", "remote", "la distanță", "distanta",
        "zoom", "internet", "n/a", "-",
    ]

    public static func url(for address: String) -> URL? {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let normalized = trimmed.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
        guard !nonPhysicalTerms.contains(normalized) else { return nil }
        var components = URLComponents(string: "https://www.google.com/maps/search/")!
        components.queryItems = [
            URLQueryItem(name: "api", value: "1"),
            URLQueryItem(name: "query", value: trimmed),
        ]
        return components.url
    }
}

public struct ServiceCenter: Codable, Identifiable, Hashable {
    public let id: String
    public let name: String
    public let category: ServiceCategory
    public let specialization: String
    /// Link de contact rapid — `tel:`, `https://wa.me/...` sau `mailto:`.
    public let contactURL: String
    /// Website — opțional, nu orice service are.
    public let websiteURL: String?
    public let coverImage: String?
    /// Valabilitate temporală opțională — Etapa 4 extinsă (2026-08-29). Vezi `Scheduling`.
    public let scheduling: Scheduling?
    /// Adresă fizică opțională (text liber — oraș, stradă, orice localizează
    /// un punct de lucru) — Etapa 5 (2026-08-29). Dacă e completată, Client
    /// afișează un buton care deschide Google Maps cu acest text căutat
    /// (vezi `MapsLink`). Distinctă de `websiteURL` (acela e site-ul, nu
    /// locația fizică).
    public let address: String?
    /// Rețele sociale opționale — 2026-08-29. Vezi `Course.socialLinks`.
    public let socialLinks: SocialLinks?

    public init(id: String, name: String, category: ServiceCategory, specialization: String,
                contactURL: String, websiteURL: String? = nil, coverImage: String? = nil, scheduling: Scheduling? = nil, address: String? = nil, socialLinks: SocialLinks? = nil) {
        self.socialLinks = socialLinks
        self.id = id
        self.name = name
        self.category = category
        self.specialization = specialization
        self.contactURL = contactURL
        self.websiteURL = websiteURL
        self.coverImage = coverImage
        self.scheduling = scheduling
        self.address = address
    }

    public var coverImageURL: URL? { CatalogAssets.imageURL(for: coverImage) }
    public var mapsURL: URL? { address.flatMap { MapsLink.url(for: $0) } }
}

/// A partner equipment shop (photo/video gear) shown in the client's
/// "Magazine partenere" section — name, description, direct link.
/// Nothing to install, no license.
public struct PartnerStore: Codable, Identifiable, Hashable {
    public let id: String
    public let name: String
    public let description: String
    public let url: String
    /// Logo-ul magazinului — preset `.icon` (patrat 512x512), pentru ca un
    /// logo se recunoaste dupa forma, nu dupa detaliu. Daca logo-ul e PNG
    /// cu fundal transparent, ImageProcessor il pastreaza PNG (nu-l
    /// innegreste pe fundal alb) — vezi ImageProcessor.process.
    public let coverImage: String?
    /// Valabilitate temporală opțională — Etapa 4 extinsă (2026-08-29). Vezi `Scheduling`.
    public let scheduling: Scheduling?
    /// Adresă fizică opțională — Etapa 5 (2026-08-29). Vezi `ServiceCenter.address`.
    public let address: String?
    /// Rețele sociale opționale — 2026-08-29. Vezi `Course.socialLinks`.
    public let socialLinks: SocialLinks?

    public init(id: String, name: String, description: String, url: String, coverImage: String? = nil, scheduling: Scheduling? = nil, address: String? = nil, socialLinks: SocialLinks? = nil) {
        self.socialLinks = socialLinks
        self.id = id
        self.name = name
        self.description = description
        self.url = url
        self.coverImage = coverImage
        self.scheduling = scheduling
        self.address = address
    }

    public var coverImageURL: URL? { CatalogAssets.imageURL(for: coverImage) }
    public var mapsURL: URL? { address.flatMap { MapsLink.url(for: $0) } }
}

/// Categoria unei resurse de download direct — Etapa 2 din Planul Integrat
/// de Upgrade v2.0 (2026-08-29, confirmat explicit de Cristi: "produse
/// noi, separate, cu simplu link de download, ca Audio"). Distinctă de
/// `PluginType` (care e specific Resolve, cu auto-instalare) — resursele
/// astea sunt cross-host (Premiere/FCP/Resolve), userul le descarcă și le
/// importă manual, la fel ca `AudioTrack`/`AppLink`.
public enum DownloadCategory: String, Codable, CaseIterable, Identifiable {
    case lut, sfx, vfx, plugin

    public var id: String { rawValue }

    public var defaultSymbol: String {
        switch self {
        case .lut: return "eyedropper.halffull"
        case .sfx: return "waveform"
        case .vfx: return "sparkles"
        case .plugin: return "puzzlepiece.extension"
        }
    }

    public var tintColor: Color {
        switch self {
        case .lut: return .mint
        case .sfx: return .teal
        case .vfx: return .purple
        case .plugin: return .orange
        }
    }
}

/// O resursă de download direct (LUT/SFX/VFX/Plugin pentru Premiere Pro,
/// Final Cut Pro sau DaVinci Resolve) — NU auto-instalează nicăieri, spre
/// deosebire de `PluginItem`; userul descarcă fișierul de la `url` și îl
/// importă manual în aplicația lui de editare. Model 1:1 pe `AudioTrack`,
/// plus câmpurile de linkuri/social din Etapa 2 (`purchaseURL`/`demoURL`/
/// `socialLinks`, ca la `PluginItem`) și `supportedOS` (unele resurse pot
/// fi specifice unui format/plugin disponibil doar pe o platformă).
public struct DownloadableResource: Codable, Identifiable, Hashable {
    public let id: String
    public let name: String
    public let description: String
    public let category: DownloadCategory
    public let url: String
    public let youtubeURL: String?
    public let coverImage: String?
    public let supportedOS: SupportedOS
    public let purchaseURL: String?
    public let demoURL: String?
    public let socialLinks: SocialLinks?
    /// Valabilitate temporală opțională — Etapa 4 extinsă (2026-08-29). Vezi `Scheduling`.
    public let scheduling: Scheduling?
    /// Licențiere — adăugată 2026-08-29 (cerut explicit: "nu am varianta
    /// aia de gratuit, plătit, trimite ID mașină, cumpără produsul,
    /// WhatsApp"). Port 1:1 al modelului de pe `PluginItem`: acces prin
    /// Ed25519 (`LicenseCore`), aceeași cheie publică din ecosistem, ACELAȘI
    /// flux WhatsApp + ID mașină. Implicit `true` (retrocompatibil — orice
    /// resursă publicată înainte de acest câmp rămâne exact ce era: liberă,
    /// descărcabilă direct, fără cod).
    public let isFree: Bool
    public let isTrial: Bool
    public let priceEUR: Double
    /// Sumă de susținere promoțională temporară — vezi `PluginItem.promoPriceEUR`
    /// (aceleași reguli de conformitate cu Regula 3: rămâne donație).
    public let promoPriceEUR: Double?

    public init(id: String, name: String, description: String, category: DownloadCategory, url: String,
                youtubeURL: String? = nil, coverImage: String? = nil, supportedOS: SupportedOS = .crossPlatform,
                purchaseURL: String? = nil, demoURL: String? = nil, socialLinks: SocialLinks? = nil, scheduling: Scheduling? = nil,
                isFree: Bool = true, isTrial: Bool = false, priceEUR: Double = 0, promoPriceEUR: Double? = nil) {
        self.id = id
        self.name = name
        self.description = description
        self.category = category
        self.url = url
        self.youtubeURL = youtubeURL
        self.coverImage = coverImage
        self.supportedOS = supportedOS
        self.purchaseURL = purchaseURL
        self.demoURL = demoURL
        self.socialLinks = socialLinks
        self.scheduling = scheduling
        self.isFree = isFree
        self.isTrial = isTrial
        self.priceEUR = priceEUR
        self.promoPriceEUR = promoPriceEUR
    }

    public var coverImageURL: URL? { CatalogAssets.imageURL(for: coverImage) }

    public var priceDisplay: String { priceEUR.formatted(.currency(code: "EUR")) }
    public var effectivePriceEUR: Double {
        if let promoPriceEUR, scheduling?.isActiveNow ?? false { return promoPriceEUR }
        return priceEUR
    }
    public var isPromoActive: Bool { promoPriceEUR != nil && (scheduling?.isActiveNow ?? false) }

    // Custom Codable: `isFree`/`isTrial`/`priceEUR`/`promoPriceEUR` sunt
    // chei NOI (2026-08-29) — orice resursă publicată înainte de asta nu
    // le are deloc în JSON. `isFree` default TRUE la decodare (nu `false`
    // ca la `PluginItem`) — păstrează exact comportamentul dinainte de
    // acest câmp (liberă, fără cod), nu transformă silențios resurse deja
    // publicate în "produse plătite fără licență activabilă".
    private enum CodingKeys: String, CodingKey {
        case id, name, description, category, url, youtubeURL, coverImage, supportedOS, purchaseURL, demoURL, socialLinks, scheduling, isFree, isTrial, priceEUR, promoPriceEUR
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        description = try c.decode(String.self, forKey: .description)
        category = try c.decode(DownloadCategory.self, forKey: .category)
        url = try c.decode(String.self, forKey: .url)
        youtubeURL = try c.decodeIfPresent(String.self, forKey: .youtubeURL)
        coverImage = try c.decodeIfPresent(String.self, forKey: .coverImage)
        supportedOS = try c.decodeIfPresent(SupportedOS.self, forKey: .supportedOS) ?? .crossPlatform
        purchaseURL = try c.decodeIfPresent(String.self, forKey: .purchaseURL)
        demoURL = try c.decodeIfPresent(String.self, forKey: .demoURL)
        socialLinks = try c.decodeIfPresent(SocialLinks.self, forKey: .socialLinks)
        scheduling = try c.decodeIfPresent(Scheduling.self, forKey: .scheduling)
        isFree = try c.decodeIfPresent(Bool.self, forKey: .isFree) ?? true
        isTrial = try c.decodeIfPresent(Bool.self, forKey: .isTrial) ?? false
        priceEUR = try c.decodeIfPresent(Double.self, forKey: .priceEUR) ?? 0
        promoPriceEUR = try c.decodeIfPresent(Double.self, forKey: .promoPriceEUR)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(description, forKey: .description)
        try c.encode(category, forKey: .category)
        try c.encode(url, forKey: .url)
        try c.encodeIfPresent(youtubeURL, forKey: .youtubeURL)
        try c.encodeIfPresent(coverImage, forKey: .coverImage)
        try c.encode(supportedOS, forKey: .supportedOS)
        try c.encodeIfPresent(purchaseURL, forKey: .purchaseURL)
        try c.encodeIfPresent(demoURL, forKey: .demoURL)
        try c.encodeIfPresent(socialLinks, forKey: .socialLinks)
        try c.encodeIfPresent(scheduling, forKey: .scheduling)
        try c.encode(isFree, forKey: .isFree)
        try c.encode(isTrial, forKey: .isTrial)
        try c.encode(priceEUR, forKey: .priceEUR)
        try c.encodeIfPresent(promoPriceEUR, forKey: .promoPriceEUR)
    }
}

/// O ofertă/promoție de la un brand PARTENER (ex. discount la echipament
/// foto/video/lămpi) — Etapa 4 din Planul Integrat de Upgrade v2.0
/// (2026-08-29). Distinctă de produsele GDC din catalog: e o relație
/// comercială cu un brand terț, deci limbajul de "discount"/"%" e
/// permis aici — spre deosebire de produsele/resursele proprii GDC
/// (Regula 3, Partea 1: acelea rămân EXCLUSIV donație, niciodată preț/
/// discount, chiar și cele din marketplace-ul gratuit).
public struct PartnerOffer: Codable, Identifiable, Hashable {
    public let id: String
    /// Numele brandului/partenerului (ex. "Aputure", "Nanlite").
    public let brandName: String
    public let description: String
    /// Text liber de discount, afișat ca badge pe card (ex. "-20%",
    /// "-50% OFF", "SPECIAL OFFER") — text, nu procent numeric, ca să
    /// acopere și cazuri non-procentuale ("2 la preț de 1").
    public let discountText: String?
    public let couponCode: String?
    /// Link către magazinul/produsul partenerului.
    public let url: String
    public let youtubeURL: String?
    public let coverImage: String?
    public let socialLinks: SocialLinks?
    public let scheduling: Scheduling?

    public init(id: String, brandName: String, description: String, discountText: String? = nil,
                couponCode: String? = nil, url: String, youtubeURL: String? = nil, coverImage: String? = nil,
                socialLinks: SocialLinks? = nil, scheduling: Scheduling? = nil) {
        self.id = id
        self.brandName = brandName
        self.description = description
        self.discountText = discountText
        self.couponCode = couponCode
        self.url = url
        self.youtubeURL = youtubeURL
        self.coverImage = coverImage
        self.socialLinks = socialLinks
        self.scheduling = scheduling
    }

    public var coverImageURL: URL? { CatalogAssets.imageURL(for: coverImage) }
}

/// Tipul de conținut referit dintr-un pachet — un `ProductBundle` poate
/// combina produse din categorii diferite (ex. un Curs + un pachet de
/// LUT-uri), deci referința trebuie să spună ȘI unde să caute ID-ul.
public enum BundleItemKind: String, Codable, CaseIterable {
    case product        // PluginItem (catalog.items)
    case download       // DownloadableResource (catalog.downloadableResources)
    case course         // Course (catalog.courses)
    case audio          // AudioTrack (catalog.audioTracks) — adăugat 2026-08-29
    case app            // AppLink (catalog.apps) — aplicații proprii GDC, adăugat 2026-08-29
    case material       // EducationalResource (catalog.educationalResources) — materiale proprii, adăugat 2026-08-29
}

public struct BundleItemRef: Codable, Hashable {
    public let kind: BundleItemKind
    public let id: String

    public init(kind: BundleItemKind, id: String) {
        self.kind = kind
        self.id = id
    }
}

/// Un pachet/bundle — Etapa 9 din Planul Integrat de Upgrade v2.0
/// (2026-08-29, idee a lui Cristi: "combin produse, unul sau mai multe,
/// să le vând la bulk, la super ofertă"). DELIBERAT doar un construct de
/// PREZENTARE/MARKETING (grupare + preț total afișat), NU un mecanism nou
/// de licențiere: fluxul rămâne cel existent — clientul apasă "Cumpără
/// pachetul" (WhatsApp, ca la orice produs), iar Furnizorul generează în
/// continuare, manual, câte o licență per produs inclus din pachet (exact
/// ca acum, doar că negocierea/plata se face o singură dată, pentru tot
/// pachetul). Simplu, sigur, fără risc de a sparge modelul de încredere
/// bazat pe donație+WhatsApp deja funcțional în tot ecosistemul.
public struct ProductBundle: Codable, Identifiable, Hashable {
    public let id: String
    public let name: String
    public let description: String
    public let items: [BundleItemRef]
    /// Prețul TOTAL al pachetului (de obicei sub suma prețurilor
    /// individuale) — afișat lângă suma individuală tăiată, pe card.
    public let bundlePriceEUR: Double
    public let coverImage: String?
    public let youtubeURL: String?
    public let socialLinks: SocialLinks?
    public let scheduling: Scheduling?

    public init(id: String, name: String, description: String, items: [BundleItemRef], bundlePriceEUR: Double,
                coverImage: String? = nil, youtubeURL: String? = nil, socialLinks: SocialLinks? = nil, scheduling: Scheduling? = nil) {
        self.id = id
        self.name = name
        self.description = description
        self.items = items
        self.bundlePriceEUR = bundlePriceEUR
        self.coverImage = coverImage
        self.youtubeURL = youtubeURL
        self.socialLinks = socialLinks
        self.scheduling = scheduling
    }

    public var coverImageURL: URL? { CatalogAssets.imageURL(for: coverImage) }
    public var bundlePriceDisplay: String { bundlePriceEUR.formatted(.currency(code: "EUR")) }
}

/// Unde apare filigranul sezonier în fereastra Client-ului — 2026-08-29,
/// cerut explicit de Cristi ("să aleagă unde apare pe ecran"). Implicit
/// `.bottomTrailing`: exact comportamentul hardcodat de dinainte, deci un
/// filigran migrat dintr-un catalog vechi arată identic cu ce arăta.
public enum SeasonalPosition: String, Codable, CaseIterable, Identifiable, Sendable {
    case bottomTrailing, bottomLeading, topTrailing, topLeading, center

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .bottomTrailing: return "Jos-dreapta"
        case .bottomLeading: return "Jos-stânga"
        case .topTrailing: return "Sus-dreapta"
        case .topLeading: return "Sus-stânga"
        case .center: return "Centru"
        }
    }
}

/// O intrare din BIBLIOTECA de filigrane sezoniere — 2026-08-29.
///
/// Înlocuiește `Catalog.seasonalBackground: String?` (un singur slot global,
/// fără perioadă și fără poziție). Cristi a cerut trei lucruri care nu
/// încăpeau într-un simplu String: (a) din ce dată până în ce dată apare,
/// (b) unde apare pe ecran, (c) ca o imagine proprie încărcată o dată să
/// rămână SALVATĂ și reutilizabilă mai târziu, nu folosită și uitată.
///
/// De-aia `Catalog.seasonalBackgrounds` e o LISTĂ (biblioteca), nu un slot:
/// fiecare intrare are propriul `isEnabled` + `scheduling`, deci Cristi
/// poate ține pregătite toate filigranele anului și le lasă să se aprindă
/// singure la datele lor.
public struct SeasonalBackgroundConfig: Codable, Hashable, Identifiable {
    /// Slug stabil — e și numele fișierului din `docs/covers/seasonal/`, și
    /// cheia de cache pe disc din Client (vezi `SeasonalBackgroundLayer`).
    public let id: String
    /// Eticheta pusă de Cristi ("Black Friday 2026") — doar pentru lista
    /// din Furnizor, nu apare nicăieri la clienți.
    public let label: String
    /// Cale relativă (`covers/seasonal/<id>.svg`) sau URL extern — același
    /// sistem hibrid ca `coverImage` (vezi `CatalogAssets`).
    public let imagePath: String
    /// `nil` = mereu vizibil (cât timp `isEnabled`), identic cu
    /// comportamentul de dinainte de această schimbare.
    public let scheduling: Scheduling?
    public let position: SeasonalPosition
    /// Comutator manual, independent de dată — un filigran poate sta în
    /// bibliotecă stins, gata de folosit, fără să-i ștergi perioada.
    public let isEnabled: Bool
    /// Intensitate reglabilă (2026-08-29, cerut explicit de Cristi — "cât
    /// de tare să se vadă"). 0.07 = valoarea implicită de dinainte
    /// (opacitate FIXĂ, hardcodată în Client). Acum fiecare filigran din
    /// bibliotecă are propria intensitate, reglabilă dintr-un slider în
    /// Furnizor — fără să mai fie nevoie de o modificare de cod pentru
    /// fiecare filigran nou. Interval practic 0.03–0.20 (impus în UI, nu
    /// aici în model — modelul acceptă orice `Double` valid).
    public let opacity: Double

    public init(id: String, label: String, imagePath: String, scheduling: Scheduling? = nil,
                position: SeasonalPosition = .bottomTrailing, isEnabled: Bool = true, opacity: Double = 0.07) {
        self.id = id
        self.label = label
        self.imagePath = imagePath
        self.scheduling = scheduling
        self.position = position
        self.isEnabled = isEnabled
        self.opacity = opacity
    }

    private enum CodingKeys: String, CodingKey {
        case id, label, imagePath, scheduling, position, isEnabled, opacity
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        label = try c.decodeIfPresent(String.self, forKey: .label) ?? ""
        imagePath = try c.decode(String.self, forKey: .imagePath)
        scheduling = try c.decodeIfPresent(Scheduling.self, forKey: .scheduling)
        position = try c.decodeIfPresent(SeasonalPosition.self, forKey: .position) ?? .bottomTrailing
        isEnabled = try c.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        // Retrocompatibil: filigranele publicate înainte de acest câmp nu au
        // "opacity" în JSON — 0.07 reproduce EXACT comportamentul vechi
        // (constanta hardcodată din SeasonalBackgroundLayer), fără nicio
        // schimbare vizuală pentru bibliotecile deja publicate.
        opacity = try c.decodeIfPresent(Double.self, forKey: .opacity) ?? 0.07
    }

    /// Vizibil ACUM: bifat manual ȘI (fără perioadă SAU în interiorul ei).
    public var isActiveNow: Bool {
        isEnabled && (scheduling?.isActiveNow ?? true)
    }

    public var imageURL: URL? { CatalogAssets.imageURL(for: imagePath) }
}

public struct Catalog: Codable {
    public let updatedAt: String?
    public let items: [PluginItem]
    public let courses: [Course]
    public let apps: [AppLink]
    public let audioTracks: [AudioTrack]
    public let educationalResources: [EducationalResource]
    public let events: [Event]
    public let partnerStores: [PartnerStore]
    public let serviceCenters: [ServiceCenter]
    /// Resurse de download direct (LUT/SFX/VFX/Plugin) — Etapa 2
    /// (2026-08-29). Default `[]`: orice catalog publicat înainte de asta
    /// decodează curat, fără eroare.
    public let downloadableResources: [DownloadableResource]
    /// Oferte/Promoții de la branduri partenere — Etapa 4 (2026-08-29).
    /// Default `[]`: retrocompatibil.
    public let partnerOffers: [PartnerOffer]
    /// BIBLIOTECA de filigrane sezoniere — 2026-08-29. Înlocuiește vechiul
    /// `seasonalBackground: String?` (un singur slot global, fără perioadă
    /// și fără poziție); vezi `SeasonalBackgroundConfig` pentru motivație.
    /// Un `catalog.json` vechi, cu cheia singulară, e migrat SILENȚIOS la
    /// decodare — vezi `init(from:)` de mai jos.
    public let seasonalBackgrounds: [SeasonalBackgroundConfig]
    /// Pachete/Bundle-uri — Etapa 9 (2026-08-29). Default `[]`: retrocompatibil.
    public let productBundles: [ProductBundle]

    public init(updatedAt: String?, items: [PluginItem], courses: [Course] = [], apps: [AppLink] = [], audioTracks: [AudioTrack] = [], educationalResources: [EducationalResource] = [], events: [Event] = [], partnerStores: [PartnerStore] = [], serviceCenters: [ServiceCenter] = [], downloadableResources: [DownloadableResource] = [], partnerOffers: [PartnerOffer] = [], seasonalBackgrounds: [SeasonalBackgroundConfig] = [], productBundles: [ProductBundle] = []) {
        self.updatedAt = updatedAt
        self.items = items
        self.courses = courses
        self.apps = apps
        self.audioTracks = audioTracks
        self.educationalResources = educationalResources
        self.events = events
        self.partnerStores = partnerStores
        self.serviceCenters = serviceCenters
        self.downloadableResources = downloadableResources
        self.partnerOffers = partnerOffers
        self.seasonalBackgrounds = seasonalBackgrounds
        self.productBundles = productBundles
    }

    // Custom decode: every collection defaults to `[]` if absent, so a
    // catalog published before a given field existed keeps decoding
    // cleanly after this update ships to clients.
    private enum CodingKeys: String, CodingKey {
        case updatedAt, items, courses, apps, audioTracks, educationalResources, events, partnerStores, serviceCenters, downloadableResources, partnerOffers, seasonalBackgrounds, productBundles
    }

    /// Cheia SINGULARĂ, doar pentru citirea unui `catalog.json` publicat
    /// înainte de bibliotecă. Nu se mai SCRIE niciodată — la prima
    /// republicare din Furnizor, catalogul iese cu forma nouă.
    private enum LegacyCodingKeys: String, CodingKey {
        case seasonalBackground
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        updatedAt = try c.decodeIfPresent(String.self, forKey: .updatedAt)
        items = try c.decodeIfPresent([PluginItem].self, forKey: .items) ?? []
        courses = try c.decodeIfPresent([Course].self, forKey: .courses) ?? []
        apps = try c.decodeIfPresent([AppLink].self, forKey: .apps) ?? []
        audioTracks = try c.decodeIfPresent([AudioTrack].self, forKey: .audioTracks) ?? []
        educationalResources = try c.decodeIfPresent([EducationalResource].self, forKey: .educationalResources) ?? []
        events = try c.decodeIfPresent([Event].self, forKey: .events) ?? []
        partnerStores = try c.decodeIfPresent([PartnerStore].self, forKey: .partnerStores) ?? []
        serviceCenters = try c.decodeIfPresent([ServiceCenter].self, forKey: .serviceCenters) ?? []
        downloadableResources = try c.decodeIfPresent([DownloadableResource].self, forKey: .downloadableResources) ?? []
        partnerOffers = try c.decodeIfPresent([PartnerOffer].self, forKey: .partnerOffers) ?? []
        productBundles = try c.decodeIfPresent([ProductBundle].self, forKey: .productBundles) ?? []

        // MIGRARE SILENȚIOASĂ (2026-08-29): un `catalog.json` publicat
        // înainte de bibliotecă are `seasonalBackground` (String). Îl
        // convertim într-o intrare unică, FĂRĂ scheduling (mereu activă) și
        // pe poziția implicită `.bottomTrailing` — adică EXACT ce arăta
        // înainte; niciun client nu vede o schimbare de comportament la
        // update. Cheia nouă câștigă dacă ambele există.
        if let list = try c.decodeIfPresent([SeasonalBackgroundConfig].self, forKey: .seasonalBackgrounds) {
            seasonalBackgrounds = list
        } else if let legacy = try decoder.container(keyedBy: LegacyCodingKeys.self)
            .decodeIfPresent(String.self, forKey: .seasonalBackground) {
            seasonalBackgrounds = [SeasonalBackgroundConfig(
                id: "migrat-2026-08-29",
                label: "Filigran existent (migrat automat)",
                imagePath: legacy
            )]
        } else {
            seasonalBackgrounds = []
        }
    }

    /// Vezi `[SeasonalBackgroundConfig].activeNowDeduplicated`.
    public var activeSeasonalBackgrounds: [SeasonalBackgroundConfig] {
        seasonalBackgrounds.activeNowDeduplicated
    }
}

public extension Array where Element == SeasonalBackgroundConfig {
    /// Filigranele care ar trebui randate ACUM, deduplicate pe poziție.
    ///
    /// DECIZIE DE COLIZIUNE (documentată deliberat, nu accidentală): dacă
    /// mai multe filigrane active cad pe ACEEAȘI poziție, câștigă ULTIMUL
    /// din listă (ultimul adăugat/editat în Furnizor). Suprapunerea a două
    /// imagini în același colț ar da o pată ilizibilă; alegerea e stabilă și
    /// previzibilă, nu aleatorie, și nu aruncă niciodată eroare. Filigranele
    /// pe poziții DIFERITE se randează toate — sunt independente.
    var activeNowDeduplicated: [SeasonalBackgroundConfig] {
        var byPosition: [SeasonalPosition: SeasonalBackgroundConfig] = [:]
        for config in self where config.isActiveNow {
            byPosition[config.position] = config // ultimul câștigă
        }
        return SeasonalPosition.allCases.compactMap { byPosition[$0] }
    }
}
