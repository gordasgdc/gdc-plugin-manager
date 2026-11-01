import Foundation

/// Alegerea copiei „reale" a unei aplicații GDC instalate direct (fără Manager), când LaunchServices
/// raportează mai multe bundle-uri cu același bundle ID (DMG montat, build de dezvoltare, copie pe alt volum).
/// Logica e pură: semnătura se verifică în aplicație și intră aici ca predicat.
public enum ExternalAppSelection {
    /// Locuri unde o copie cu acest bundle ID NU este instalarea utilizatorului: imagine de disc montată sau
    /// volum extern în afara unui folder „Applications", directoare de build, temporare, App Translocation.
    public static func isTransientLocation(_ path: String) -> Bool {
        let comps = path.split(separator: "/").map(String.init)
        if path.contains("/AppTranslocation/") || path.contains("/DerivedData/") || path.contains("/.build/") { return true }
        if path.hasPrefix("/private/var/folders/") || path.hasPrefix("/var/folders/") || path.hasPrefix("/tmp/") || path.hasPrefix("/private/tmp/") { return true }
        if comps.first == "Volumes" && !comps.contains("Applications") { return true }
        return false
    }

    /// Ordinea: /Applications, apoi ~/Applications, apoi orice altă cale stabilă. `isTrusted` respinge copiile
    /// cu semnătură invalidă sau cu alt Team ID; `exists` respinge căile de pe volume deconectate.
    public static func choose(from urls: [URL], home: String = NSHomeDirectory(),
                              exists: (URL) -> Bool = { FileManager.default.fileExists(atPath: $0.path) },
                              isTrusted: (URL) -> Bool) -> URL? {
        let usable = urls.filter { exists($0) && !isTransientLocation($0.path) && isTrusted($0) }
        if let a = usable.first(where: { $0.path.hasPrefix("/Applications/") }) { return a }
        if let h = usable.first(where: { $0.path.hasPrefix(home + "/Applications/") }) { return h }
        return usable.first
    }
}
