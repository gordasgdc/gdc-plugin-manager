import SwiftUI
import GDCPluginManagerCore

/// Câmp de text cu sugestii — Etapa 5+ (2026-08-29, cerut explicit):
/// "dacă încep să scriu cuvinte repetitive [ex. „Online", numele unei
/// firme], să mi le sugereze... să fie mai ușor și mai productiv".
///
/// DELIBERAT fără store propriu de istoric: sugestiile vin din valorile
/// deja folosite pe alte produse publicate (`existingValues`, calculat de
/// view-ul apelator din `existingItems`/`existingResources` deja
/// încărcate) — capturează exact tiparul cerut ("online" repetat, numele
/// unei firme repetat) fără nicio persistență nouă de gestionat.
struct AutocompleteTextField: View {
    let placeholder: String
    @Binding var text: String
    let existingValues: [String]

    @FocusState private var focused: Bool
    @State private var showDropdown = false

    private var suggestions: [String] {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        let pool = Array(Set(existingValues.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }))
        let matches: [String]
        if trimmed.isEmpty {
            matches = pool
        } else {
            matches = pool.filter {
                FuzzySearch.matches(query: trimmed, in: $0) && $0.caseInsensitiveCompare(trimmed) != .orderedSame
            }
        }
        return matches.sorted().prefix(6).map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField(placeholder, text: $text)
                .textFieldStyle(.roundedBorder)
                .focused($focused)
                .onChange(of: focused) { _, isFocused in showDropdown = isFocused }

            if showDropdown && !suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button {
                            text = suggestion
                            showDropdown = false
                        } label: {
                            Text(suggestion)
                                .font(.callout)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(Color(nsColor: .windowBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.2)))
                .padding(.top, 2)
                .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
            }
        }
    }
}
