import SwiftUI
import GDCPluginManagerCore

/// Bară de căutare reutilizabilă — fuzzy (typo-tolerant), cu istoric
/// persistat + autocomplete la tastare. Etapa 1 din planul de upgrade
/// (2026-08-29): folosită momentan de `CatalogGrid` (Produse); alte grile
/// (Aplicații/Cursuri/etc.) primesc același component la o etapă viitoare.
struct SearchBar: View {
    @Binding var text: String
    /// Sugestii calculate de view-ul apelator (ex. numele produselor care
    /// se potrivesc deja) — combinate cu istoricul la afișare.
    let liveSuggestions: [String]
    @StateObject private var history: SearchHistoryStore
    @FocusState private var focused: Bool
    @State private var showDropdown = false

    init(text: Binding<String>, historyKey: String, liveSuggestions: [String] = []) {
        _text = text
        self.liveSuggestions = liveSuggestions
        _history = StateObject(wrappedValue: SearchHistoryStore(key: historyKey))
    }

    private var suggestions: [String] {
        if text.trimmingCharacters(in: .whitespaces).isEmpty {
            return history.recent
        }
        let combined = (liveSuggestions + history.recent).filter {
            FuzzySearch.matches(query: text, in: $0) && $0.caseInsensitiveCompare(text) != .orderedSame
        }
        var seen = Set<String>()
        return combined.filter { seen.insert($0.lowercased()).inserted }.prefix(6).map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField(L.t("search.placeholder"), text: $text)
                    .textFieldStyle(.plain)
                    .focused($focused)
                    .onSubmit {
                        history.record(text)
                        showDropdown = false
                    }
                if !text.isEmpty {
                    Button {
                        text = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.25)))
            .onChange(of: focused) { _, isFocused in
                showDropdown = isFocused
            }

            if showDropdown && !suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button {
                            text = suggestion
                            history.record(suggestion)
                            showDropdown = false
                        } label: {
                            HStack {
                                Image(systemName: text.isEmpty ? "clock" : "magnifyingglass")
                                    .foregroundStyle(.secondary)
                                    .font(.system(size: 11))
                                Text(suggestion)
                                Spacer()
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(Color(nsColor: .windowBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2)))
                .padding(.top, 4)
                .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
            }
        }
    }
}
