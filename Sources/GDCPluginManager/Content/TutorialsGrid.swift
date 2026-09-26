import SwiftUI
import AppKit
import GDCPluginManagerCore

/// Secțiunea "Tutoriale" — cerință directă (2026-09-01): căutare + grupare
/// pe categorie (liberă, aleasă de Furnizor) + carduri compacte în grilă
/// largă (nu listă lungă), cu descriere expandabilă la cerere.
struct TutorialsGrid: View {
    let tutorials: [Tutorial]
    @State private var searchText = ""
    @State private var selectedCategory: String?

    private var categories: [String] {
        Array(Set(tutorials.map(\.category))).sorted()
    }

    private var filtered: [Tutorial] {
        tutorials.filter { tutorial in
            let matchesCategory = selectedCategory == nil || tutorial.category == selectedCategory
            let matchesSearch = searchText.isEmpty
                || FuzzySearch.matches(query: searchText, inAny: [tutorial.title, tutorial.description, tutorial.category] + tutorial.tags)
            return matchesCategory && matchesSearch
        }
    }

    private let columns = [GridItem(.adaptive(minimum: 280, maximum: 340), spacing: GDCTokens.Space.l)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField(L.t("tutorials.search"), text: $searchText)
                        .textFieldStyle(.plain)
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: { Image(systemName: "xmark.circle.fill") }
                            .buttonStyle(.plain).foregroundStyle(.secondary)
                    }
                }
                .padding(GDCTokens.Space.s)
                .background(RoundedRectangle(cornerRadius: GDCTokens.Radius.control).fill(.background.secondary))

                if categories.count > 1 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: GDCTokens.Space.s) {
                            categoryChip(nil, label: L.t("tutorials.allCategories"))
                            ForEach(categories, id: \.self) { cat in categoryChip(cat, label: cat) }
                        }
                    }
                }

                if filtered.isEmpty {
                    Text(L.t("search.noResults")).foregroundStyle(.secondary).padding(GDCTokens.Space.page)
                } else {
                    LazyVGrid(columns: columns, spacing: GDCTokens.Space.l) {
                        ForEach(filtered) { TutorialCard(tutorial: $0) }
                    }
                }
            }
            .padding(GDCTokens.Space.xl)
        }
    }

    @ViewBuilder
    private func categoryChip(_ value: String?, label: String) -> some View {
        Button {
            selectedCategory = value
        } label: {
            Text(label).font(.caption).fontWeight(selectedCategory == value ? .bold : .regular)
                .padding(.horizontal, GDCTokens.Space.m).padding(.vertical, 6)
                .background(Capsule().fill(selectedCategory == value ? Color.accentColor.opacity(0.3) : Color.gray.opacity(0.15)))
        }
        .buttonStyle(.plain)
    }
}

struct TutorialCard: View {
    let tutorial: Tutorial
    @State private var showTags = false

    var body: some View {
        VStack(alignment: .leading, spacing: GDCTokens.Space.s) {
            ZStack {
                if let url = tutorial.thumbnail {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().aspectRatio(16/9, contentMode: .fill)
                        } else {
                            Rectangle().fill(Color.gray.opacity(0.2))
                        }
                    }
                } else {
                    Rectangle().fill(Color.gray.opacity(0.2))
                }
                if let watch = tutorial.watchURL {
                    Button { NSWorkspace.shared.open(watch) } label: {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 34))
                            .foregroundStyle(.white)
                            .shadow(radius: 4)
                    }
                    .buttonStyle(.plain)
                    .help(L.t("card.youtubeLink"))
                }
            }
            .frame(height: 160)
            .clipShape(RoundedRectangle(cornerRadius: GDCTokens.Radius.control))
            .clipped()

            HStack {
                Text(tutorial.category).font(.caption2).fontWeight(.semibold)
                    .padding(.horizontal, GDCTokens.Space.s).padding(.vertical, 3)
                    .background(Capsule().fill(.tint.opacity(0.18)))
                Spacer()
                CountdownBadge(scheduling: tutorial.scheduling)
            }

            Text(tutorial.title).font(.headline).lineLimit(2)

            if !tutorial.tags.isEmpty {
                DisclosureGroup(isExpanded: $showTags) {
                    FlowLayout(spacing: 6) {
                        ForEach(tutorial.tags, id: \.self) { tag in
                            Text(tag).font(.caption2).foregroundStyle(.secondary)
                                .padding(.horizontal, 7).padding(.vertical, GDCTokens.Space.xxs)
                                .background(Capsule().fill(Color.gray.opacity(0.15)))
                        }
                    }
                    .padding(.top, GDCTokens.Space.xs)
                } label: {
                    Text(String(format: L.t("tutorials.showTags"), tutorial.tags.count)).font(.caption).foregroundStyle(.secondary)
                }
            }

            CollapsibleDescription(text: tutorial.description)
        }
        .contentCard()
    }
}
