import Foundation
import AppKit

/// Ghiduri PDF dedicate modulelor administrative ale Furnizorului — Cursuri,
/// Produse, Licențe, Backup. [NOU 2026-09-03] Furnizorul nu avea NICIUN ghid
/// PDF până acum (doar `TokenRenewalGuideView.swift`, un ghid IN-APP pentru
/// un singur flux). Spre deosebire de Client (`HelpGuide.swift`, un singur
/// document unificat, RO/EN/ES — vezi acolo), aici fiecare modul are
/// propriul ghid, DOAR în română — Furnizorul e exclusiv pentru Cristi
/// (niciun sistem de limbă aici, spre deosebire de Client).
/// Generate cu `installer/generate_furnizor_guides.py` — rulează scriptul
/// din nou și suprascrie aceste 4 fișiere la orice schimbare de conținut
/// sau de flux UI în modulele respective.
enum FurnizorGuidePDF: String, CaseIterable {
    case courses = "Ghid-Furnizor-Cursuri"
    case products = "Ghid-Furnizor-Produse"
    case licenses = "Ghid-Furnizor-Licente"
    case backup = "Ghid-Furnizor-Backup"

    var menuTitle: String {
        switch self {
        case .courses: return "Ghid: Gestionarea Cursurilor (PDF)"
        case .products: return "Ghid: Gestionarea Produselor (PDF)"
        case .licenses: return "Ghid: Licențe (PDF)"
        case .backup: return "Ghid: Backup & Securitate (PDF)"
        }
    }

    func open() {
        // Bundle.module (nu Bundle.main) — resursele SPM ale acestui target
        // se instalează într-un .bundle separat, copiat de build_furnizor_app.sh
        // (fix real 2026-09-03: acest pas lipsea complet, vezi comentariul
        // din script — SeasonalPresets era afectat de același bug).
        if let url = Bundle.module.url(forResource: rawValue, withExtension: "pdf") {
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
