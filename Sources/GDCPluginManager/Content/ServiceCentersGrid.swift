import SwiftUI
import AppKit
import GDCPluginManagerCore

struct ServiceCentersGrid: View {
    let centers: [ServiceCenter]

    private let columns = [GridItem(.adaptive(minimum: 280, maximum: 380), spacing: GDCTokens.Space.l)]

    var body: some View {
        // Bara de filtre comuna (2026-09-11) — shadowing pe `centers`,
        // deci corpul de mai jos ramane neschimbat, dar primeste lista
        // deja filtrata. Vezi CatalogFilterBar.swift.
        FilteredCatalogSection(items: centers, options: .content) { centers in
        ScrollView {
            if centers.isEmpty {
                Text(L.t("servicecenters.empty")).foregroundStyle(.secondary).padding(GDCTokens.Space.page)
            } else {
                // Grup pe categorie, fiecare cu propriul grid — nu o singura
                // grila cu header "spanned" (nu se poate garanta latimea
                // completa intr-un LazyVGrid cu coloane adaptive).
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(ServiceCategory.allCases) { category in
                        let group = centers.filter { $0.category == category }
                        if !group.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Label(serviceCategoryLabel(category), systemImage: category.symbol)
                                    .font(.headline)
                                LazyVGrid(columns: columns, spacing: GDCTokens.Space.grid) {
                                    ForEach(group) { center in
                                        ServiceCenterCard(center: center)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(GDCTokens.Space.l)
            }
        }
        }
    }
}

struct ServiceCenterCard: View {
    let center: ServiceCenter

    var body: some View {
        VStack(alignment: .leading, spacing: GDCTokens.Space.s) {
            CoverThumbnail(
                url: center.coverImageURL,
                fallbackSymbol: center.category.symbol,
                tint: .accentColor,
                height: 110,
                lightboxTitle: center.name
            )
            Text(center.name).font(.headline)
            CountdownBadge(scheduling: center.scheduling)
            CollapsibleDescription(text: center.specialization)
            Spacer(minLength: 0)
            HStack {
                if let url = URL(string: center.contactURL) {
                    Button(L.t("servicecenters.contact")) { NSWorkspace.shared.open(url) }
                        .controlSize(.small)
                }
                if let websiteString = center.websiteURL, let url = URL(string: websiteString) {
                    Button(L.t("servicecenters.website")) { NSWorkspace.shared.open(url) }
                        .controlSize(.small)
                }
                MapButton(mapsURL: center.mapsURL)
            }
            // Multi-Locație (2026-09-05) — sedii suplimentare, câte un rând.
            ForEach(center.additionalAddresses, id: \.self) { addr in
                HStack(spacing: 6) {
                    Text(addr).font(.caption).foregroundStyle(.secondary)
                    MapButton(mapsURL: MapsLink.url(for: addr))
                }
            }
            SocialLinksRow(center.socialLinks)
        }
        .padding(GDCTokens.Space.m)
        .frame(maxWidth: .infinity, minHeight: 170, alignment: .leading)
        .glassCardBackground()
    }
}
