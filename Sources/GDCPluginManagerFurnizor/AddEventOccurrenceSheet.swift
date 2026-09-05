import SwiftUI
import GDCPluginManagerCore

/// Sheet de adăugare a unei locații/perioade/preț suplimentare pentru un
/// eveniment — Multi-Locație (2026-09-05). Pe tiparul exact al
/// `AddPromoWindowSheet` (PricingManagerView.swift), dar toate câmpurile
/// sunt OPȚIONALE prin design (locație/interval libere, preț poate lipsi
/// complet = gratuit) — cerință explicită: nicio restricție de validare
/// inutilă, userul completează doar ce are sens pentru acea ocurență.
struct AddEventOccurrenceSheet: View {
    @Environment(\.dismiss) private var dismiss
    let existingLocations: [String]
    let onAdd: (EventOccurrence) -> Void

    @State private var location = ""
    @State private var dateDisplay = ""
    @State private var priceText = ""
    @State private var priceLabel = ""

    /// Singura validare reală: dacă userul a scris ceva la preț, trebuie
    /// să fie un număr — altfel orice combinație (inclusiv toate goale)
    /// e acceptată.
    private var priceIsValid: Bool {
        priceText.trimmingCharacters(in: .whitespaces).isEmpty
            || Double(priceText.replacingOccurrences(of: ",", with: ".")) != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Locație/perioadă suplimentară").font(.title3).bold()

            AutocompleteTextField(placeholder: "Locație (opțional)", text: $location,
                                   existingValues: existingLocations)
            TextField("Interval/dată (text liber, opțional)", text: $dateDisplay)
                .textFieldStyle(.roundedBorder)

            Divider()
            Text("Preț (opțional — lasă gol pentru gratuit/fără preț stabilit)")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                TextField("ex. 23", text: $priceText).textFieldStyle(.roundedBorder).frame(width: 100)
                Text("EUR")
                TextField("Etichetă categorie (opțional, ex. Early bird)", text: $priceLabel)
                    .textFieldStyle(.roundedBorder)
            }
            if !priceIsValid {
                Label("Prețul trebuie să fie un număr (sau lasă câmpul gol).", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption).foregroundStyle(.orange)
            }

            HStack {
                Button("Anulează") { dismiss() }
                Spacer()
                Button("Adaugă") {
                    let trimmedPrice = priceText.trimmingCharacters(in: .whitespaces)
                    let price = trimmedPrice.isEmpty ? nil : Double(trimmedPrice.replacingOccurrences(of: ",", with: "."))
                    let trimmedLabel = priceLabel.trimmingCharacters(in: .whitespaces)
                    onAdd(EventOccurrence(
                        location: location.trimmingCharacters(in: .whitespaces),
                        dateDisplay: dateDisplay.trimmingCharacters(in: .whitespaces),
                        priceEUR: price,
                        priceLabel: trimmedLabel.isEmpty ? nil : trimmedLabel
                    ))
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!priceIsValid)
            }
        }
        .padding(24)
        .frame(width: 420)
    }
}
