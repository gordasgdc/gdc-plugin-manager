import AppKit
import Foundation
import GDCPluginManagerCore

/// Descarcă direct binarul unei aplicații din catalog (`AppLink.downloadURL`,
/// găzduit pe gordas.dev) în Descărcări și îl deschide — un .dmg se montează,
/// un .pkg pornește instalarea. Fără browser, fără pagină de repo (Regula 20).
@MainActor
final class AppDirectDownload: ObservableObject {
    static let shared = AppDirectDownload()
    @Published private(set) var active: Set<String> = []
    @Published private(set) var failed: [String: String] = [:]

    func start(appID: String, url: URL) {
        guard !active.contains(appID) else { return }
        active.insert(appID)
        failed[appID] = nil
        DiagnosticLog.write("AppDownload", "start \(appID): \(url.absoluteString)")
        Task {
            do {
                let (temporary, response) = try await URLSession.shared.download(from: url)
                guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                    throw URLError(.badServerResponse)
                }
                let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
                // Numele de pe server poartă deja versiunea (Regula 17); aceeași
                // versiune descărcată din nou înlocuiește copia veche.
                let destination = downloads.appendingPathComponent(url.lastPathComponent)
                try? FileManager.default.removeItem(at: destination)
                try FileManager.default.moveItem(at: temporary, to: destination)
                DiagnosticLog.write("AppDownload", "ok \(appID) → \(destination.path)")
                NSWorkspace.shared.open(destination)
            } catch {
                failed[appID] = error.localizedDescription
                DiagnosticLog.write("AppDownload", "eroare \(appID): \(error.localizedDescription)")
            }
            active.remove(appID)
        }
    }
}
