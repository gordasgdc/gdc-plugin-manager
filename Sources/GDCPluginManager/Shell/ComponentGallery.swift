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
        return Self.states.enumerated().compactMap { i, state in
            var d = dict
            d["id"] = "gallery-\(i)"
            d["name"] = i % 3 == 1 ? "GDC Film Emulation Complete Pipeline for DaVinci Resolve Studio — Extended Edition" : "GDC Halation \(i + 1)"
            d["description"] = i % 2 == 0
                ? "Emulare de peliculă cu halation, bloom și grain, calibrată pe scanări reale; funcționează în spațiul de lucru DaVinci Wide Gamut / Intermediate și în ACEScct, cu preseturi pentru Kodak 2383 și Fuji 3513."
                : "Look scurt."
            d["coverImage"] = Self.covers[i % Self.covers.count] as Any
            d["isFree"] = i % 4 == 0
            d["isTrial"] = i == 4
            guard let json = try? JSONSerialization.data(withJSONObject: d.compactMapValues { $0 is NSNull ? nil : $0 }),
                  let item = try? JSONDecoder().decode(PluginItem.self, from: json) else { return nil }
            return (item, state)
        }
    }

    var body: some View {
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
