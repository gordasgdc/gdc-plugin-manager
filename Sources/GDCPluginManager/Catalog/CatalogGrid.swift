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
    private let columns = [GridItem(.adaptive(minimum: 240, maximum: 300), spacing: GDCTokens.Space.grid)]

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
                    StateView(kind: .loading, message: L.t("catalog.loading"))
                } else if let error = catalog.loadError, items.isEmpty {
                    StateView(kind: .error, title: L.t("state.error.title"), message: error,
                              actions: [.init(title: L.t("card.retry"), isPrimary: true) { Task { await catalog.refresh() } }])
                } else if items.isEmpty {
                    StateView(kind: .empty, title: L.t("state.empty.title"), message: L.t("catalog.empty"),
                              actions: [.init(title: L.t("catalog.refresh")) { Task { await CatalogService.shared.refresh() } }])
                } else if filteredItems.isEmpty {
                    StateView(kind: .empty, title: L.t("state.empty.title"), message: L.t("filter.price.empty"), symbol: "line.3.horizontal.decrease.circle",
                              actions: [.init(title: L.t("state.resetFilters")) { filters.reset() }])
                } else {
                    LazyVGrid(columns: columns, spacing: GDCTokens.Space.grid) {
                        ForEach(filteredItems) { item in
                            ProductCard(item: item)
                        }
                    }
                    .padding(GDCTokens.Space.l)
                }
            }
        }
    }
}
