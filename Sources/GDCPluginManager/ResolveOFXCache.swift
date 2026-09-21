import Foundation
import AppKit
import GDCPluginManagerCore

/// DaVinci Resolve memorează în `OFXPluginCacheV2.xml` starea fiecărui pachet OFX (status 0 = încărcat, 2 = eșuat) și NU mai încearcă un pachet marcat eșuat,
/// nici după ce fișierele au fost reparate/reinstalate — în „Video Plugins” apare „failed”, iar în nod „lipsă”. Găsit pe 2026-09-21: 19 pachete instalate
/// întâi cu structură greșită au rămas blocate așa și după reinstalarea corectă. După orice instalare OFX ștergem intrarea pachetului din cache, ca Resolve
/// să-l scaneze din nou la următoarea pornire. Se scrie doar cât Resolve e închis (altfel și-ar rescrie cache-ul la ieșire); altfel se notează în jurnal.
enum ResolveOFXCache {
    static var cacheURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Blackmagic Design/DaVinci Resolve/OFXPluginCacheV2.xml")
    }

    static var resolveIsRunning: Bool {
        NSWorkspace.shared.runningApplications.contains { ($0.bundleIdentifier ?? "").hasPrefix("com.blackmagic-design.DaVinciResolve") }
    }

    /// Elimină blocul `<bundle>` al pachetului din cache; întoarce true dacă a schimbat ceva.
    @discardableResult
    static func forget(bundlePath: String) -> Bool {
        guard let xml = try? String(contentsOf: cacheURL, encoding: .utf8), xml.contains(bundlePath) else { return false }
        if resolveIsRunning {
            DiagnosticLog.write("ResolveCache", "Resolve rulează: intrarea pentru \(URL(fileURLWithPath: bundlePath).lastPathComponent) rămâne până la repornire — închide Resolve și reinstalează dacă apare „failed”")
            return false
        }
        let esc = NSRegularExpression.escapedPattern(for: bundlePath)
        guard let re = try? NSRegularExpression(pattern: "<bundle>\\s*<binary [^>]*bundle_path=\"" + esc + "\"[^>]*/>\\s*</bundle>\\s*") else { return false }
        let out = re.stringByReplacingMatches(in: xml, range: NSRange(xml.startIndex..., in: xml), withTemplate: "")
        guard out != xml else { return false }
        do {
            try out.write(to: cacheURL, atomically: true, encoding: .utf8)
            DiagnosticLog.write("ResolveCache", "intrare ștearsă din cache-ul Resolve: \(URL(fileURLWithPath: bundlePath).lastPathComponent)")
            return true
        } catch {
            DiagnosticLog.write("ResolveCache", "nu am putut scrie cache-ul Resolve: \(error.localizedDescription)")
            return false
        }
    }
}
