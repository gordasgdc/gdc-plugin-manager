import SwiftUI
import GDCPluginManagerCore

// MARK: - Editor comun de acces/grupare/etichete (2026-09-11)
//
// O singura sectiune de formular, refolosita in TOATE panourile `Publish*View`
// din Furnizor. Inlocuieste ideea de a copia campurile de acces in fiecare
// panou — exact duplicarea pe care refactorizarea asta o elimina in Client.
//
// IMPORTANT: `showsKind` e FALS pentru sectiunile care au deja un camp nativ
// de gratuit/platit (plugin-uri, resurse descarcabile, cursuri). Acolo,
// afisarea unui selector de tip acces ar crea exact a doua sursa de adevar pe
// care regula de precedenta din `CatalogAccess` o interzice — furnizorul
// editeaza mai departe `isFree`/`priceEUR` din panoul propriu al sectiunii.

/// Starea de formular a datelor comune. Tine text, nu model — conversia se
/// face o singura data, in `model`.
struct AccessFormState {
    var kind: AccessKind?
    var referencePriceText: String = ""
    var note: String = ""
    var group: CatalogGroup?
    var tagsText: String = ""

    init() {}

    init(_ access: CatalogAccess?) {
        kind = access?.kind
        referencePriceText = access?.referencePriceEUR.map { value in
            value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(value)) : String(value)
        } ?? ""
        note = access?.note ?? ""
        group = access?.group
        tagsText = (access?.tags ?? []).joined(separator: ", ")
    }

    mutating func reset() { self = AccessFormState() }

    /// `nil` cand formularul e gol — ca sa nu scriem un obiect `access: {}`
    /// inutil in catalog pentru fiecare element atins.
    var model: CatalogAccess? {
        // Virgula zecimala romaneasca ("49,90") e acceptata la fel ca punctul
        // — altfel un pret tastat firesc s-ar pierde tacut.
        let normalized = referencePriceText
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ",", with: ".")
        let price = Double(normalized)
        let trimmedNote = note.trimmingCharacters(in: .whitespaces)
        let tags = tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let access = CatalogAccess(
            kind: kind,
            referencePriceEUR: (price ?? 0) > 0 ? price : nil,
            note: trimmedNote.isEmpty ? nil : trimmedNote,
            group: group,
            tags: tags
        )
        return access.isEmpty ? nil : access
    }
}

struct AccessEditorSection: View {
    @Binding var state: AccessFormState
    /// Fals pentru sectiunile cu camp nativ de pret/gratuit — vezi nota de sus.
    var showsKind: Bool = true
    /// Fals pentru sectiunile fara pret propriu de referinta.
    var showsReferencePrice: Bool = true
    /// Sugestii de etichete specifice domeniului, afisate sub camp.
    var tagSuggestions: [String] = []

    var body: some View {
        GroupBox("Acces, grup & etichete") {
            VStack(alignment: .leading, spacing: 12) {
                if showsKind {
                    Picker("Tip acces", selection: $state.kind) {
                        Text("Nespecificat").tag(AccessKind?.none)
                        ForEach(AccessKind.allCases) { kind in
                            Text(kind.label).tag(AccessKind?.some(kind))
                        }
                    }
                    Text("„Gratuit” afișează badge-ul verde la clienți și include elementul în filtrul „Gratuite”. Nespecificat = cardul rămâne exact ca înainte.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                if showsReferencePrice {
                    TextField("Preț de referință € (opțional, ex. 49)", text: $state.referencePriceText)
                        .textFieldStyle(.roundedBorder)
                    Text("Folosit DOAR dacă elementul nu are un preț propriu și nici un ID din Pricing Manager — acolo prețul dinamic rămâne sursa de adevăr.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                TextField("Aviz afișat pe card (opțional, ex. „Trial 14 zile”)", text: $state.note)
                    .textFieldStyle(.roundedBorder)

                Divider()

                Picker("Grup", selection: $state.group) {
                    Text("Fără grup").tag(CatalogGroup?.none)
                    ForEach(CatalogGroup.allCases) { group in
                        Text(group.label).tag(CatalogGroup?.some(group))
                    }
                }

                TextField("Etichete, separate prin virgulă", text: $state.tagsText)
                    .textFieldStyle(.roundedBorder)
                if tagSuggestions.isEmpty {
                    Text("Apar ca filtru rapid de tip în secțiunea clientului.")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("Sugestii: " + tagSuggestions.joined(separator: ", "))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(8)
        }
    }
}

/// Sugestii de etichete per domeniu — pornire rapida pentru furnizor, nu o
/// lista inchisa: campul ramane text liber.
enum AccessTagSuggestions {
    static let plugins = ["Emulare Film", "Utility", "Conversion", "Color Space"]
    static let audioVFX = ["SFX", "Overlays", "Transitions", "Ambient"]
    static let apps = ["Utilitare", "Film / Emulare Film", "Audio", "VFX"]
    static let learning = ["Începător", "Avansat", "Workflow", "Color"]
}
