import Foundation

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

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .dctl: return "DCTL"
        case .lut: return "LUT"
        case .fuse: return "Fuse"
        case .powerGrade: return "PowerGrade"
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
        case .dctl, .lut:
            return libraryDir
                .appendingPathComponent("Application Support")
                .appendingPathComponent("Blackmagic Design")
                .appendingPathComponent("DaVinci Resolve")
                .appendingPathComponent("LUT")
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

    public init(id: String, name: String, type: PluginType, description: String, version: String,
                files: [PluginFile], iconSymbol: String?, priceEUR: Double, isFree: Bool = false, isTrial: Bool = false) {
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
    }

    // Custom decode: supports both the current `files` array AND the
    // original single-file catalog format (`filePath` + `sha256`, no
    // `isFree`/`isTrial`), so any entry ever published still decodes
    // cleanly.
    private enum CodingKeys: String, CodingKey {
        case id, name, type, description, version, files, filePath, sha256, iconSymbol, priceEUR, isFree, isTrial
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

    public init(id: String, name: String, description: String, options: [CourseOption]) {
        self.id = id
        self.name = name
        self.description = description
        self.options = options
    }
}

/// A link to one of Cristi's other apps (CursorPro GDC, GDC Production
/// Manager, etc.) shown in the client app's "Aplicații" section — just a
/// name and an outbound link, nothing to install.
public struct AppLink: Codable, Identifiable, Hashable {
    public let id: String
    public let name: String
    public let url: String

    public init(id: String, name: String, url: String) {
        self.id = id
        self.name = name
        self.url = url
    }
}

public struct Catalog: Codable {
    public let updatedAt: String?
    public let items: [PluginItem]
    public let courses: [Course]
    public let apps: [AppLink]

    public init(updatedAt: String?, items: [PluginItem], courses: [Course] = [], apps: [AppLink] = []) {
        self.updatedAt = updatedAt
        self.items = items
        self.courses = courses
        self.apps = apps
    }

    // Custom decode: `courses`/`apps` default to `[]` if absent, so the
    // catalog already live today (real products, no courses/apps keys
    // yet) keeps decoding cleanly after this update ships to clients.
    private enum CodingKeys: String, CodingKey {
        case updatedAt, items, courses, apps
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        updatedAt = try c.decodeIfPresent(String.self, forKey: .updatedAt)
        items = try c.decodeIfPresent([PluginItem].self, forKey: .items) ?? []
        courses = try c.decodeIfPresent([Course].self, forKey: .courses) ?? []
        apps = try c.decodeIfPresent([AppLink].self, forKey: .apps) ?? []
    }
}
