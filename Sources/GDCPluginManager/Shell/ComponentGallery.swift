#if DEBUG
import SwiftUI
import GDCPluginManagerCore

/// Galeria de componente (doar build DEBUG, pornită cu `-GDCComponentGallery YES`):
/// cardul de produs în toate cele 8 stări, cu coperți reale, texte lungi și fără copertă,
/// pentru verificarea vizuală RO/EN/ES × Light/Dark și la redimensionare. Nu instalează nimic.
struct ComponentGallery: View {
    @ObservedObject private var catalog = CatalogService.shared
    @ObservedObject private var languageStore = LanguageStore.shared

    private var width: Double? {
        let w = UserDefaults.standard.double(forKey: "GDCGalleryWidth")
        return w > 0 ? w : nil
    }

    private static let covers = ["covers/CG Convertor.png", "covers/Clapperboard Digital.png", "covers/CursorPro GDC.png", nil]
    private static let states: [ProductActionState] = [
        .notInstalled, .licenseRequired, .installing, .installed(version: "1.4.0"),
        .updateAvailable(installed: "1.2.0", latest: "1.3.0"), .failed(isUpdate: false), .incompatible, .offline,
    ]

    private var fixtures: [(PluginItem, ProductActionState)] {
        guard let base = catalog.items.first,
              let data = try? JSONEncoder().encode(base),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [] }
        let offset = UserDefaults.standard.integer(forKey: "GDCGalleryOffset")
        return Self.states.enumerated().dropFirst(offset).compactMap { i, state in
            var d = dict
            d["id"] = "gallery-\(i)"
            d["name"] = i % 3 == 1 ? "GDC Film Emulation Complete Pipeline for DaVinci Resolve Studio — Extended Edition" : "GDC Halation \(i + 1)"
            d["description"] = i % 2 == 0
                ? "Emulare de peliculă cu halation, bloom și grain, calibrată pe scanări reale; funcționează în spațiul de lucru DaVinci Wide Gamut / Intermediate și în ACEScct, cu preseturi pentru Kodak 2383 și Fuji 3513."
                : "Look scurt."
            d["coverImage"] = Self.covers[i % Self.covers.count] as Any
            d["isFree"] = i % 4 == 0
            d["isTrial"] = i == 4
            d["priceEUR"] = 23
            guard let json = try? JSONSerialization.data(withJSONObject: d.compactMapValues { $0 is NSNull ? nil : $0 }),
                  let item = try? JSONDecoder().decode(PluginItem.self, from: json) else { return nil }
            return (item, state)
        }
    }

    var body: some View {
        if UserDefaults.standard.string(forKey: "GDCGalleryMode") == "states" { statesGallery } else { cardsGallery }
    }

    /// Bannerele (texte reale, inclusiv mesajul lung de verificare eșuată) + stările de ecran.
    private var statesGallery: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GDCTokens.Space.s) {
                Banner(kind: .info, title: L.t("update.title"),
                       message: "v1.40.0 — " + L.t("offline.banner.body"),
                       actions: [.init(title: L.t("update.download"), isPrimary: true) {}],
                       dismiss: .init(title: L.t("update.dismiss")) {})
                Banner(kind: .warning, title: L.t("dependency.missing.title"), message: "Python 3",
                       actions: [.init(title: String(format: L.t("dependency.install.button"), "Python 3"), isPrimary: true) {}])
                Banner(kind: .warning, title: L.t("update.check.failed.title"), message: L.t("update.check.failed"),
                       actions: [.init(title: L.t("update.check.openWebsite")) {}], dismiss: .init(title: L.t("update.dismiss")) {})
                Banner(kind: .offline, title: L.t("offline.banner.title"), message: L.t("offline.banner.body"),
                       actions: [.init(title: L.t("card.retry")) {}], dismiss: .init(title: L.t("update.dismiss")) {})
                HStack(alignment: .top, spacing: GDCTokens.Space.l) {
                    StateView(kind: .empty, title: L.t("state.empty.title"), message: L.t("filter.price.empty"),
                              symbol: "line.3.horizontal.decrease.circle", actions: [.init(title: L.t("state.resetFilters")) {}])
                    StateView(kind: .error, title: L.t("state.error.title"), message: L.t("catalog.error.parse"),
                              actions: [.init(title: L.t("card.retry"), isPrimary: true) {}])
                }
                StateView(kind: .loading, message: L.t("catalog.loading"))
            }
            .padding(.vertical, GDCTokens.Space.m)
        }
    }

    private var cardsGallery: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: GDCTokens.Size.cardMinWidth), spacing: GDCTokens.Space.grid)],
                      spacing: GDCTokens.Space.grid) {
                ForEach(fixtures, id: \.0.id) { item, state in
                    ProductCard(item: item, forcedState: state)
                }
            }
            .padding(GDCTokens.Space.l)
        }
        .environmentObject(catalog)
        .environmentObject(InstallManager.shared)
        // `-GDCGalleryWidth 560` simulează o fereastră îngustă (reflow-ul grilei).
        .frame(maxWidth: width.map { CGFloat($0) } ?? .infinity)
        .frame(maxWidth: .infinity)
    }
}
#endif
