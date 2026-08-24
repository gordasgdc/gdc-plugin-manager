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

/// One entry in the catalog — one sellable DCTL/LUT/Fuse (or a whole
/// pack of several) from Cristi's own product line (never a general
/// "browse anyone's plugin" catalog).
///
/// `id` is the input to the SHA-512 product hash embedded in every
/// license serial for this item (see LicenseCore.productHash) — it must
/// never change once a single unit has sold, and a retired id must never
/// be reused for an unrelated product, or old serials would wrongly
/// unlock it.
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

    public init(id: String, name: String, type: PluginType, description: String, version: String,
                files: [PluginFile], iconSymbol: String?, priceEUR: Double, isFree: Bool = false, isTrial: Bool = false,
                youtubeURL: String? = nil, bundleFolderName: String? = nil, coverImage: String? = nil) {
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
    }

    /// URL-ul absolut al copertii, gata de descarcat (nil daca nu are).
    public var coverImageURL: URL? { CatalogAssets.imageURL(for: coverImage) }

    // Custom decode: supports both the current `files` array AND the
    // original single-file catalog format (`filePath` + `sha256`, no
    // `isFree`/`isTrial`/`youtubeURL`/`bundleFolderName`), so any entry
    // ever published still decodes cleanly.
    private enum CodingKeys: String, CodingKey {
        case id, name, type, description, version, files, filePath, sha256, iconSymbol, priceEUR, isFree, isTrial, youtubeURL, bundleFolderName, coverImage
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
public struct Course: Codable, Identifiable, Hashable {
    public let id: String
    public let name: String
    public let description: String
    public let options: [CourseOption]
    /// Coperta cursului — preset `.cover` (max 1600px), pentru ca aici
    /// vrem sa se vada detaliul intr-un preview marit, nu doar un simbol.
    /// Cheie optionala: cursurile publicate inainte decodeaza cu nil.
    public let coverImage: String?

    public init(id: String, name: String, description: String, options: [CourseOption], coverImage: String? = nil) {
        self.id = id
        self.name = name
        self.description = description
        self.options = options
        self.coverImage = coverImage
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

    public init(id: String, name: String, url: String, youtubeURL: String? = nil, coverImage: String? = nil) {
        self.youtubeURL = youtubeURL
        self.id = id
        self.name = name
        self.url = url
        self.coverImage = coverImage
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

    public init(id: String, name: String, description: String, kind: Kind, externalURL: String, youtubeURL: String? = nil, coverImage: String? = nil) {
        self.id = id
        self.name = name
        self.description = description
        self.kind = kind
        self.externalURL = externalURL
        self.youtubeURL = youtubeURL
        self.coverImage = coverImage
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

    public init(id: String, title: String, description: String, dateDisplay: String, location: String, externalURL: String, youtubeURL: String? = nil, coverImage: String? = nil) {
        self.id = id
        self.title = title
        self.description = description
        self.dateDisplay = dateDisplay
        self.location = location
        self.externalURL = externalURL
        self.youtubeURL = youtubeURL
        self.coverImage = coverImage
    }

    public var coverImageURL: URL? { CatalogAssets.imageURL(for: coverImage) }
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

    public init(id: String, name: String, description: String, url: String, coverImage: String? = nil) {
        self.id = id
        self.name = name
        self.description = description
        self.url = url
        self.coverImage = coverImage
    }

    public var coverImageURL: URL? { CatalogAssets.imageURL(for: coverImage) }
}

public struct Catalog: Codable {
    public let updatedAt: String?
    public let items: [PluginItem]
    public let courses: [Course]
    public let apps: [AppLink]
    public let educationalResources: [EducationalResource]
    public let events: [Event]
    public let partnerStores: [PartnerStore]

    public init(updatedAt: String?, items: [PluginItem], courses: [Course] = [], apps: [AppLink] = [], educationalResources: [EducationalResource] = [], events: [Event] = [], partnerStores: [PartnerStore] = []) {
        self.updatedAt = updatedAt
        self.items = items
        self.courses = courses
        self.apps = apps
        self.educationalResources = educationalResources
        self.events = events
        self.partnerStores = partnerStores
    }

    // Custom decode: every collection defaults to `[]` if absent, so a
    // catalog published before a given field existed keeps decoding
    // cleanly after this update ships to clients.
    private enum CodingKeys: String, CodingKey {
        case updatedAt, items, courses, apps, educationalResources, events, partnerStores
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        updatedAt = try c.decodeIfPresent(String.self, forKey: .updatedAt)
        items = try c.decodeIfPresent([PluginItem].self, forKey: .items) ?? []
        courses = try c.decodeIfPresent([Course].self, forKey: .courses) ?? []
        apps = try c.decodeIfPresent([AppLink].self, forKey: .apps) ?? []
        educationalResources = try c.decodeIfPresent([EducationalResource].self, forKey: .educationalResources) ?? []
        events = try c.decodeIfPresent([Event].self, forKey: .events) ?? []
        partnerStores = try c.decodeIfPresent([PartnerStore].self, forKey: .partnerStores) ?? []
    }
}
