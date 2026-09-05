import SwiftUI
import GDCPluginManagerCore

/// Editor inline pentru o listă de adrese/sedii SUPLIMENTARE — Multi-Locație
/// (2026-09-05), reutilizat de `PublishServiceCenterView`/
/// `PublishPartnerStoreView` (adresa "principală" a fiecărei entități
/// rămâne câmpul `address` existent, neschimbat). Pe tiparul listei de
/// opțiuni din `PublishCourseView` — add/remove inline, fără sheet (un
/// singur câmp text nu justifică un sheet separat, spre deosebire de
/// `AddEventOccurrenceSheet`, care are 4 câmpuri).
struct AdditionalAddressesEditor: View {
    @Binding var addresses: [String]
    let existingValues: [String]
    @State private var newAddress = ""

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                Text("Sedii/locații suplimentare (opțional)").fontWeight(.medium)
                ForEach(addresses, id: \.self) { addr in
                    HStack {
                        Text(addr)
                        Spacer()
                        Button(role: .destructive) {
                            addresses.removeAll { $0 == addr }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.red)
                    }
                }
                HStack {
                    AutocompleteTextField(placeholder: "Adresă suplimentară", text: $newAddress,
                                           existingValues: existingValues)
                    Button("Adaugă") {
                        let trimmed = newAddress.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty, !addresses.contains(trimmed) else { return }
                        addresses.append(trimmed)
                        newAddress = ""
                    }
                    .disabled(newAddress.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding(8)
        }
    }
}
