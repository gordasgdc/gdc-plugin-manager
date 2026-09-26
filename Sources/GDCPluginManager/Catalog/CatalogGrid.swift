import SwiftUI
import AppKit
import GDCPluginManagerCore

struct CatalogGrid: View {
    let items: [PluginItem]
    @EnvironmentObject private var catalog: CatalogService

    // Filtrele locale (priceFilter/osFilter, copiate si in celelalte
    // sectiuni) au fost inlocuite 2026-09-11 cu bara COMUNA — pentru
    // plugin-uri, `isFree`/`supportedOS` raman sursa de adevar, derivate
    // prin `resolvedAccess` (pasul 1 al precedentei), deci filtrarea da
    // exact aceleasi rezultate ca inainte, dar dintr-un singur loc.
    @StateObject private var filters = CatalogFilterState()

    // 240 (de la 220): cardul are acum și copertă, iar descrierea urcă la
    // 5 rânduri — sub 240 textul se rupe urât.
    private let columns = [GridItem(.adaptive(minimum: 240, maximum: 300), spacing: 14)]

    private var filteredItems: [PluginItem] { filters.filter(items) }

    var body: some View {
        VStack(spacing: 0) {
            if !items.isEmpty {
                CatalogFilterBar(
                    state: filters,
                    options: .product,
                    availableTags: CatalogFacets.tags(items),
                    availableGroups: CatalogFacets.groups(items)
                )
            }

            ScrollView {
                if catalog.isLoading && items.isEmpty {
                    ProgressView(L.t("catalog.loading")).padding(40)
                } else if let error = catalog.loadError, items.isEmpty {
                    Text(error).foregroundStyle(.secondary).padding(40)
                } else if items.isEmpty {
                    Text(L.t("catalog.empty")).foregroundStyle(.secondary).padding(40)
                } else if filteredItems.isEmpty {
                    Text(L.t("filter.price.empty")).foregroundStyle(.secondary).padding(40)
                } else {
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(filteredItems) { item in
                            PluginCard(item: item)
                        }
                    }
                    .padding(16)
                }
            }
        }
    }
}
