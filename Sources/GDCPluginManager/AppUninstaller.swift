import AppKit
import GDCPluginManagerCore

/// Dezinstalare completă din interiorul aplicației (fără script extern):
/// confirmare nativă → șterge datele locale → mută aplicația la Coș → închide.
/// Aceleași căi ca `Dezinstalare_GDCPluginManager.command` (rămas doar în repo).
@MainActor
enum AppUninstaller {
    private static var bundleID: String { Bundle.main.bundleIdentifier ?? "com.gordasgdc.pluginmanager" }

    private static var pathsToRemove: [URL] {
        let lib = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library")
        let id = bundleID
        return [
            "Application Support/GDCPluginManager",
            "Application Support/GDC Plugin Manager",
            "Caches/\(id)",
            "Caches/\(id).ShipIt",
            "Preferences/\(id).plist",
            "Saved Application State/\(id).savedState",
            "Logs/GDCPluginManager",
            "Logs/GDCPluginManager.log",
            "HTTPStorages/\(id)",
            "WebKit/\(id)",
        ].map { lib.appendingPathComponent($0) }
    }

    static func confirmAndUninstall() {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = L.t("uninstall.title")
        alert.informativeText = L.t("uninstall.body")
        alert.addButton(withTitle: L.t("uninstall.confirm"))
        alert.addButton(withTitle: L.t("uninstall.cancel"))
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        run()
    }

    private static func run() {
        DiagnosticLog.write("Uninstall", "Dezinstalare pornită (\(bundleID))")
        UserDefaults.standard.removePersistentDomain(forName: bundleID)
        UserDefaults.standard.synchronize()
        var failed: [String] = []
        for url in pathsToRemove where FileManager.default.fileExists(atPath: url.path) {
            do { try FileManager.default.removeItem(at: url) }
            catch {
                failed.append(url.lastPathComponent)
                DiagnosticLog.write("Uninstall", "Nu am putut șterge \(url.path): \(error.localizedDescription)")
            }
        }
        let app = Bundle.main.bundleURL
        NSWorkspace.shared.recycle([app]) { _, error in
            DispatchQueue.main.async {
                if let error {
                    let a = NSAlert()
                    a.alertStyle = .warning
                    a.messageText = L.t("uninstall.trashFailed")
                    a.informativeText = error.localizedDescription
                    a.runModal()
                }
                if !failed.isEmpty {
                    DiagnosticLog.write("Uninstall", "Rămase: \(failed.joined(separator: ", "))")
                }
                NSApp.terminate(nil)
            }
        }
    }
}
