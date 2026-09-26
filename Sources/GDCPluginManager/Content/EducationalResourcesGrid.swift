import SwiftUI
import AppKit
import GDCPluginManagerCore

struct EducationalResourcesGrid: View {
    let resources: [EducationalResource]

    // Mai lat decât înainte (260→300): cardurile au acum copertă și
    // descrierea se vede întreagă, deci au nevoie de spațiu ca să nu se
    // înghesuie textul pe rânduri de 3 cuvinte.
    private let columns = [GridItem(.adaptive(minimum: 300, maximum: 400), spacing: GDCTokens.Space.l)]

    var body: some View {
        // Bara de filtre comuna (2026-09-11) — shadowing pe `resources`,
        // deci corpul de mai jos ramane neschimbat, dar primeste lista
        // deja filtrata. Vezi CatalogFilterBar.swift.
        FilteredCatalogSection(items: resources, options: .content) { resources in
        ScrollView {
            if resources.isEmpty {
                StateView(kind: .empty, title: L.t("state.empty.title"), message: L.t("resources.empty"),
                              actions: [.init(title: L.t("catalog.refresh")) { Task { await CatalogService.shared.refresh() } }])
            } else {
                LazyVGrid(columns: columns, spacing: GDCTokens.Space.grid) {
                    ForEach(resources) { resource in
                        EducationalResourceCard(resource: resource)
                    }
                }
                .padding(GDCTokens.Space.l)
            }
        }
        }
    }
}

struct EducationalResourceCard: View {
    let resource: EducationalResource

    var body: some View {
        VStack(alignment: .leading, spacing: GDCTokens.Space.s) {
            CoverThumbnail(
                url: resource.coverImageURL,
                fallbackSymbol: "book.fill",
                tint: .accentColor,
                height: GDCTokens.Size.cardArtworkHeight,
                lightboxTitle: resource.name
            )
            HStack {
                Spacer()
                Text(resource.kind.label)
                    .font(.caption2).fontWeight(.semibold)
                    .padding(.horizontal, GDCTokens.Space.s).padding(.vertical, 3)
                    .background(Capsule().fill(.tint.opacity(0.18)))
                if let urlString = resource.youtubeURL, let url = URL(string: urlString) {
                    Button { NSWorkspace.shared.open(url) } label: {
                        Image(systemName: "play.circle")
                    }
                    .buttonStyle(.plain)
                    .help(L.t("card.youtubeLink"))
                }
            }
            Text(resource.name).font(.headline)
            CountdownBadge(scheduling: resource.scheduling)
            CollapsibleDescription(text: resource.description)
            Spacer(minLength: 0)
            if let url = URL(string: resource.externalURL) {
                Button(L.t("resources.buy")) { NSWorkspace.shared.open(url) }
                    .controlSize(.small)
            }
            SocialLinksRow(resource.socialLinks)
        }
        .contentCard(minHeight: 200, alignment: .leading)
    }
}
