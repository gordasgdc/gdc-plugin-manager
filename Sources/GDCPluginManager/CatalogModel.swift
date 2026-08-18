import Foundation

enum PluginType: String, Codable, CaseIterable, Identifiable {
    case dctl
    case lut
    case fuse

    var id: String { rawValue }

    var label: String {
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
    var installDirectory: URL {
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
struct PluginItem: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let type: PluginType
    let description: String
    let version: String
    let url: URL
    let sha256: String?
    let iconSymbol: String?

    /// The filename this plugin should be saved as on disk — taken from
    /// the download URL's last path component, so the catalog doesn't
    /// need to repeat it.
    var filename: String { url.lastPathComponent }
}

struct Catalog: Codable {
    let updatedAt: String?
    let items: [PluginItem]
}
