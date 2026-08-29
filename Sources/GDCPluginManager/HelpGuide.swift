import Foundation
import AppKit

/// Deschide ghidul de utilizare PDF, in limba curenta a aplicatiei, direct
/// in Preview (NSWorkspace.open respecta mereu aplicatia implicita a
/// userului pentru PDF). Fisierele (Resources/Ghid-GDCPluginManager-{ro,en,es}.pdf)
/// sunt generate cu `installer/generate_pdf.py` — [REDESENAT 2026-08-29]
/// coperta cu banner de brand, 16 sectiuni (acopera toate etapele v2.0:
/// cautare globala, Resurse Download, Aplicatiile Mele, Oferte & Pachete,
/// tema, marime text), nu doar setul original de 8. Ruleaza scriptul din
/// nou si suprascrie aceste 3 fisiere la orice schimbare de continut.
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
