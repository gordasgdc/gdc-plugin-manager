import SwiftUI
import GDCPluginManagerCore

// MARK: - Editor de etichete cu selectie multipla si sugestii (2026-09-11)
//
// Cerut explicit de Cristi: "tot ce introduc, tag-uri sau chiar si nume, sa-mi
// apara sau sa se autocompleteze cand incep sa scriu ceva si deja a mai fost
// scris... sau la tag-uri sa am posibilitatea sa le aleg pur si simplu".
//
// Doua surse de sugestii, in aceeasi lista:
//   1. Etichetele DEJA PUBLICATE oriunde in catalog (`CatalogTagIndex`) —
//      asta rezolva cazul "poate sunt repetitive": scrii o data „Emulare Film"
//      si data viitoare o alegi dintr-un click, garantat identica (fara
//      „emulare film" / „Emulare  Film" ca intrari separate).
//   2. Sugestiile fixe de domeniu (`AccessTagSuggestions`), pentru un catalog
//      inca gol, unde n-ai de unde alege nimic.
//
// DELIBERAT fara store propriu de istoric — exact aceeasi decizie ca la
// `AutocompleteTextField`: sursa de adevar e catalogul publicat, nu un fisier
// local paralel care ar putea diverge.

/// Colecteaza toate etichetele si grupurile folosite REAL in catalog, din
/// toate sectiunile. Citit o singura data per deschidere de panou.
enum CatalogTagIndex {
    /// Toate etichetele distincte din intreg catalogul, sortate alfabetic.
    static func allTags(in catalog: Catalog) -> [String] {
        var all: Set<String> = []
        func collect<T: AccessDescribing>(_ items: [T]) {
            for item in items { all.formUnion(item.resolvedAccess.tags) }
        }
        collect(catalog.items)
        collect(catalog.courses)
        collect(catalog.apps)
        collect(catalog.audioTracks)
        collect(catalog.educationalResources)
        collect(catalog.events)
        collect(catalog.partnerStores)
        collect(catalog.serviceCenters)
        collect(catalog.downloadableResources)
        collect(catalog.partnerOffers)
        collect(catalog.productBundles)
        collect(catalog.tutorials)
        return all
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    /// Incarca direct din catalogul de pe disc; lista goala daca nu poate fi
    /// citit (fail-open — un editor fara sugestii ramane perfect utilizabil).
    static func loadAllTags() -> [String] {
        guard let catalog = try? CatalogEditor.load() else { return [] }
        return allTags(in: catalog)
    }

    /// Etichetele PROPRII ale tutorialelor (`Tutorial.tags`, separate de cele
    /// din `access`) plus toate celelalte din catalog — la editarea unui
    /// tutorial ai nevoie sa le vezi pe amandoua la un loc.
    static func loadTutorialTags() -> [String] {
        guard let catalog = try? CatalogEditor.load() else { return [] }
        var all = Set(allTags(in: catalog))
        for tutorial in catalog.tutorials { all.formUnion(tutorial.tags) }
        return all
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    /// Valori deja folosite pentru un camp text repetitiv oarecare (categoria
    /// unui tutorial, formatul unui curs, eticheta unei optiuni). Acelasi
    /// principiu ca `AutocompleteTextField`: sursa e catalogul publicat.
    static func loadValues(_ extract: (Catalog) -> [String]) -> [String] {
        guard let catalog = try? CatalogEditor.load() else { return [] }
        return Set(extract(catalog))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }
}

/// Editor de etichete: ce ai ales apare ca „chips" (cu X), scrii ca sa
/// filtrezi, dai click pe o sugestie ca s-o adaugi. Inlocuieste campul text
/// „separate prin virgula" — care cerea sa tii minte exact cum ai scris
/// eticheta data trecuta.
struct AccessTagsEditor: View {
    @Binding var tagsText: String
    /// Etichete deja publicate oriunde in catalog.
    let publishedTags: [String]
    /// Sugestii fixe de domeniu, pentru cand catalogul inca n-are nimic.
    var domainSuggestions: [String] = []

    @State private var draft = ""
    @FocusState private var focused: Bool

    /// Sursa de adevar ramane `tagsText` (string, exact ca in model) — aici
    /// doar il parsam/recompunem, ca sa nu introducem o a doua stare care ar
    /// putea diverge de formular.
    private var selected: [String] {
        tagsText.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private func setSelected(_ tags: [String]) {
        // Pastram ordinea, eliminam duplicatele indiferent de majuscule.
        var seen: Set<String> = []
        let unique = tags.filter { seen.insert($0.lowercased()).inserted }
        tagsText = unique.joined(separator: ", ")
    }

    private func add(_ tag: String) {
        let clean = tag.trimmingCharacters(in: .whitespaces)
        guard !clean.isEmpty else { return }
        setSelected(selected + [clean])
        draft = ""
    }

    private func remove(_ tag: String) {
        setSelected(selected.filter { $0.caseInsensitiveCompare(tag) != .orderedSame })
    }

    /// Sugestiile publicate au prioritate (sunt reale), cele de domeniu vin
    /// dupa, si niciodata ceva deja selectat.
    private var suggestions: [String] {
        let chosen = Set(selected.map { $0.lowercased() })
        var pool = publishedTags
        for s in domainSuggestions where !pool.contains(where: { $0.caseInsensitiveCompare(s) == .orderedSame }) {
            pool.append(s)
        }
        let available = pool.filter { !chosen.contains($0.lowercased()) }

        let trimmed = draft.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return Array(available.prefix(12)) }
        return available.filter { FuzzySearch.matches(query: trimmed, in: $0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !selected.isEmpty {
                FlowRow(spacing: 6) {
                    ForEach(selected, id: \.self) { tag in
                        HStack(spacing: 4) {
                            Text(tag).font(.caption)
                            Button {
                                remove(tag)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("Elimină eticheta")
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                    }
                }
            }

            HStack(spacing: 8) {
                TextField("Scrie o etichetă nouă și apasă Enter", text: $draft)
                    .textFieldStyle(.roundedBorder)
                    .focused($focused)
                    .onSubmit { add(draft) }
                Button("Adaugă") { add(draft) }
                    .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            if !suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(draft.isEmpty ? "Alege dintre cele deja folosite:" : "Sugestii:")
                        .font(.caption).foregroundStyle(.secondary)
                    FlowRow(spacing: 6) {
                        ForEach(suggestions, id: \.self) { suggestion in
                            Button { add(suggestion) } label: {
                                Text(suggestion)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Capsule().fill(.quaternary))
                                    .contentShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .help("Adaugă „\(suggestion)”")
                        }
                    }
                }
            }
        }
    }
}

/// Asezare pe randuri cu revenire automata — `HStack` ar taia etichetele care
/// nu incap, iar `LazyVGrid` cere coloane de latime fixa (etichetele au latimi
/// foarte diferite). SwiftUI n-are un FlowLayout nativ pe macOS 14.
struct FlowRow: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth == .infinity ? x : maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

/// Rand de sugestii clickabile pentru un editor de etichete care isi tine
/// deja propria lista (ex. `Tutorial.tags`, cu `TagChipsFlow`-ul lui). Nu
/// inlocuieste editorul existent — doar ii adauga sursa de sugestii.
struct TagSuggestionsRow: View {
    let suggestions: [String]
    let draft: String
    let alreadyChosen: [String]
    let onPick: (String) -> Void

    private var visible: [String] {
        let chosen = Set(alreadyChosen.map { $0.lowercased() })
        let available = suggestions.filter { !chosen.contains($0.lowercased()) }
        let trimmed = draft.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return Array(available.prefix(12)) }
        return available.filter { FuzzySearch.matches(query: trimmed, in: $0) }
    }

    var body: some View {
        if !visible.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text(draft.isEmpty ? "Alege dintre cele deja folosite:" : "Sugestii:")
                    .font(.caption).foregroundStyle(.secondary)
                FlowRow(spacing: 6) {
                    ForEach(visible, id: \.self) { suggestion in
                        Button { onPick(suggestion) } label: {
                            Text(suggestion)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(.quaternary))
                                .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .help("Adaugă „\(suggestion)”")
                    }
                }
            }
        }
    }
}
