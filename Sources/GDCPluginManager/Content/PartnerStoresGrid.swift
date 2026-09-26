import SwiftUI
import AppKit
import GDCPluginManagerCore

struct PartnerStoresGrid: View {
    let stores: [PartnerStore]

    // Mai lat decât înainte (260→300): cardurile au acum copertă și
    // descrierea se vede întreagă, deci au nevoie de spațiu ca să nu se
    // înghesuie textul pe rânduri de 3 cuvinte.
    private let columns = [GridItem(.adaptive(minimum: 300, maximum: 400), spacing: 16)]

    var body: some View {
        // Bara de filtre comuna (2026-09-11) — shadowing pe `stores`,
        // deci corpul de mai jos ramane neschimbat, dar primeste lista
        // deja filtrata. Vezi CatalogFilterBar.swift.
        FilteredCatalogSection(items: stores, options: .content) { stores in
        ScrollView {
            if stores.isEmpty {
                Text(L.t("stores.empty")).foregroundStyle(.secondary).padding(40)
            } else {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(stores) { store in
                        PartnerStoreCard(store: store)
                    }
                }
                .padding(16)
            }
        }
        }
    }
}

struct PartnerStoreCard: View {
    let store: PartnerStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            CoverThumbnail(
                url: store.coverImageURL,
                fallbackSymbol: "storefront.fill",
                tint: .accentColor,
                height: 130,
                lightboxTitle: store.name
            )
            Text(store.name).font(.headline)
            CountdownBadge(scheduling: store.scheduling)
            CollapsibleDescription(text: store.description)
            Spacer(minLength: 0)
            HStack {
                if let url = URL(string: store.url) {
                    Button(L.t("stores.visit")) { NSWorkspace.shared.open(url) }
                        .controlSize(.small)
                }
                MapButton(mapsURL: store.mapsURL)
            }
            // Multi-Locație (2026-09-05) — sedii suplimentare, câte un rând.
            ForEach(store.additionalAddresses, id: \.self) { addr in
                HStack(spacing: 6) {
                    Text(addr).font(.caption).foregroundStyle(.secondary)
                    MapButton(mapsURL: MapsLink.url(for: addr))
                }
            }
            SocialLinksRow(store.socialLinks)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 180, alignment: .leading)
        .glassCardBackground()
    }
}

func serviceCategoryLabel(_ category: ServiceCategory) -> String {
    L.t("servicecategory.\(category.rawValue)")
}
