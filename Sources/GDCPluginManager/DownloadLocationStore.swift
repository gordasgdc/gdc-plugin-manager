import Foundation
import AppKit

/// Ține minte, LOCAL pe acest Mac, unde a salvat userul fiecare resursă
/// descărcată (LUT/SFX/VFX/Plugin) — cerut explicit 2026-08-29: "să aibă
/// posibilitatea să își pună path-ul... ca să știe tot timpul unde l-a
/// descărcat". Persistat în `UserDefaults`, cheiat după ID-ul resursei —
/// NU face parte din catalog.json (e stare per-client, nu conținut
/// publicat), la fel ca `CustomLauncher`/`UserProfileStore`.
@MainActor
final class DownloadLocationStore: ObservableObject {
    static let shared = DownloadLocationStore()

    @Published private(set) var paths: [String: String] = [:]

    private let key = "gdcpm_download_locations"

    private init() {
        paths = UserDefaults.standard.dictionary(forKey: key) as? [String: String] ?? [:]
    }

    func path(for resourceID: String) -> String? { paths[resourceID] }

    func setPath(_ path: String, for resourceID: String) {
        paths[resourceID] = path
        UserDefaults.standard.set(paths, forKey: key)
    }

    func clear(for resourceID: String) {
        paths.removeValue(forKey: resourceID)
        UserDefaults.standard.set(paths, forKey: key)
    }

    /// Deschide un `NSOpenPanel` (alegere folder) și salvează calea aleasă.
    func pickFolder(for resourceID: String) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Alege folderul"
        panel.message = "Unde ai salvat/descărcat această resursă?"
        if panel.runModal() == .OK, let url = panel.url {
            setPath(url.path, for: resourceID)
        }
    }

    func openFolder(for resourceID: String) {
        guard let path = paths[resourceID] else { return }
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
    }
}
