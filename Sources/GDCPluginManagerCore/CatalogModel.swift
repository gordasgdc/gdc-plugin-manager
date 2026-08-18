import Foundation

public enum PluginType: String, Codable, CaseIterable, Identifiable {
    case dctl
    case lut
    case fuse

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .dctl: return "DCTL"
        case .lut: return "LUT"
        case .fuse: return "Fuse"
        }
    }

    /// Where DaVinci Resolve actually reads this file type from, on
    /// macOS. Verified against Resolve's own documentation/forum
    /// guidance, not assumed:
    /// - DCTL and LUT share the same folder (Resolve tells them apart by
    ///   file extension).
    /// - Fuses live under Resolve's own Fusion folder.
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
        }
    }
}

/// One entry in the catalog — one sellable DCTL/LUT/Fuse from Cristi's
/// own product line (never a general "browse anyone's plugin" catalog).
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
    /// Path to the file inside the private gdc-plugin-manager-files repo,
    /// e.g. "lut-wedding-style/1.2.0/WeddingStyle.cube" — fetched through
    /// an authenticated GitHub Contents API request (see
    /// PrivateCatalogAuth.swift / InstallManager.swift), never a plain
    /// public URL.
    public let filePath: String
    public let sha256: String
    public let iconSymbol: String?
    public let priceEUR: Double
    /// If true, no license is required at all — the client can install
    /// and update this item directly, for free, with no purchase/
    /// activation step. `priceEUR` is ignored (treated as 0) when this
    /// is true.
    public let isFree: Bool

    public init(id: String, name: String, type: PluginType, description: String, version: String,
                filePath: String, sha256: String, iconSymbol: String?, priceEUR: Double, isFree: Bool = false) {
        self.id = id
        self.name = name
        self.type = type
        self.description = description
        self.version = version
        self.filePath = filePath
        self.sha256 = sha256
        self.iconSymbol = iconSymbol
        self.priceEUR = priceEUR
        self.isFree = isFree
    }

    // Custom decode so older catalog entries written before `isFree`
    // existed still decode cleanly (defaults to false, i.e. paid).
    private enum CodingKeys: String, CodingKey {
        case id, name, type, description, version, filePath, sha256, iconSymbol, priceEUR, isFree
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        type = try c.decode(PluginType.self, forKey: .type)
        description = try c.decode(String.self, forKey: .description)
        version = try c.decode(String.self, forKey: .version)
        filePath = try c.decode(String.self, forKey: .filePath)
        sha256 = try c.decode(String.self, forKey: .sha256)
        iconSymbol = try c.decodeIfPresent(String.self, forKey: .iconSymbol)
        priceEUR = try c.decode(Double.self, forKey: .priceEUR)
        isFree = try c.decodeIfPresent(Bool.self, forKey: .isFree) ?? false
    }

    /// The filename this plugin should be saved as on disk — taken from
    /// the last path component of filePath.
    public var filename: String { (filePath as NSString).lastPathComponent }

    public var priceDisplay: String {
        priceEUR.formatted(.currency(code: "EUR"))
    }
}

public struct Catalog: Codable {
    public let updatedAt: String?
    public let items: [PluginItem]

    public init(updatedAt: String?, items: [PluginItem]) {
        self.updatedAt = updatedAt
        self.items = items
    }
}
