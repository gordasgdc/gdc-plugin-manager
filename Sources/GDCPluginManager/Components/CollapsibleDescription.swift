import SwiftUI
import AppKit
import GDCPluginManagerCore

/// Descriere colapsabilă, reutilizabilă în ORICE card din catalog —
/// cerință directă (2026-09-01): "la tot unde am tema de descriere ...
/// să se poată desfășura", generalizarea disclosure-ului deja făcut la
/// Tutoriale peste toate celelalte 8 tipuri de card (Produse/Cursuri/
/// Materiale/Evenimente/Pachete/Oferte/Magazine/Resurse Download/Audio).
/// Colapsat implicit — text ascuns complet, doar eticheta "Descriere" —
/// apasă săgeata ca să se desfacă. Nimic randat dacă textul e gol.
struct CollapsibleDescription: View {
    let text: String
    @State private var expanded = false

    var body: some View {
        if !text.isEmpty {
            DisclosureGroup(isExpanded: $expanded) {
                Text(text)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, GDCTokens.Space.xs)
            } label: {
                Text(L.t("card.showDescription")).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
