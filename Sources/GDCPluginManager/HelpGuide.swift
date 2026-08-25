import Foundation
import AppKit

/// Deschide ghidul de utilizare PDF, in limba curenta a aplicatiei, direct
/// in Preview (NSWorkspace.open respecta mereu aplicatia implicita a
/// userului pentru PDF). Fisierele (Resources/Ghid-GDCPluginManager-{ro,en,es}.pdf)
/// sunt continut de baza, generat automat — de inlocuit cu ghidul complet
/// cand e gata, pastrand aceleasi nume de fisier.
enum HelpGuide {
    static func openPDF() {
        let suffix = L.current.rawValue // "ro" / "en" / "es"
        let filename = "Ghid-GDCPluginManager-\(suffix)"

        // Bundle.module (nu Bundle.main) — resursele SPM ale acestui target
        // se instaleaza intr-un .bundle separat (vezi build_app.sh, care il
        // copiaza in Contents/Resources/ langa executabil).
        if let url = Bundle.module.url(forResource: filename, withExtension: "pdf")
            ?? Bundle.module.url(forResource: "Ghid-GDCPluginManager-en", withExtension: "pdf") {
            NSWorkspace.shared.open(url)
            return
        }

        let alert = NSAlert()
        alert.messageText = "Ghidul nu e încă disponibil"
        alert.informativeText = "Fișierul PDF de ghid nu a fost încă adăugat la această versiune a aplicației."
        alert.alertStyle = .informational
        alert.runModal()
    }
}
