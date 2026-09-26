import SwiftUI
import AppKit
import GDCPluginManagerCore

/// Grid pentru Oferte Parteneri — Etapa 4 (2026-08-29). Discount afișat ca
/// badge grafic pe card, generat automat din `discountText` (dacă e setat).
/// Grid pentru Pachete/Bundle-uri — Etapa 9 (2026-08-29). Fiecare card
/// listează produsele incluse (rezolvate din catalog după `BundleItemRef`),
/// suma individuală tăiată + prețul total al pachetului, buton WhatsApp
/// (achiziția, ca la orice produs — licențele individuale rămân un pas
/// manual separat al Furnizorului, neschimbat).
struct BundleGrid: View {
    let bundles: [ProductBundle]
    @ObservedObject var catalog: CatalogService

    private let columns = [GridItem(.adaptive(minimum: 300, maximum: 400), spacing: 16)]

    var body: some View {
        // Bara de filtre comuna (2026-09-11) — shadowing pe `bundles`,
        // deci corpul de mai jos ramane neschimbat, dar primeste lista
        // deja filtrata. Vezi CatalogFilterBar.swift.
        FilteredCatalogSection(items: bundles, options: .content) { bundles in
        ScrollView {
            if bundles.isEmpty {
                Text(L.t("bundles.empty")).foregroundStyle(.secondary).padding(40)
            } else {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(bundles) { bundle in
                        BundleCard(bundle: bundle, catalog: catalog)
                    }
                }
                .padding(16)
            }
        }
        }
    }
}

struct BundleCard: View {
    let bundle: ProductBundle
    @ObservedObject var catalog: CatalogService

    /// Nume + preț individual pentru fiecare produs inclus, rezolvate
    /// după tip (produs/resursă download/curs) — un ID care nu se mai
    /// găsește (produs șters ulterior) e omis silențios, nu crapă cardul.
    private var resolvedItems: [(name: String, priceEUR: Double?)] {
        bundle.items.compactMap { ref in
            switch ref.kind {
            case .product:
                guard let item = (catalog.items + catalog.scriptItems).first(where: { $0.id == ref.id }) else { return nil }
                return (item.name, item.priceEUR)
            case .download:
                guard let resource = (catalog.downloadableResources + catalog.pdfResources).first(where: { $0.id == ref.id }) else { return nil }
                return (resource.name, resource.priceEUR)
            case .course:
                guard let course = catalog.courses.first(where: { $0.id == ref.id }) else { return nil }
                return (course.name, nil)
            case .audio:
                guard let track = catalog.audioTracks.first(where: { $0.id == ref.id }) else { return nil }
                return (track.name, nil)
            case .app:
                guard let app = catalog.apps.first(where: { $0.id == ref.id }) else { return nil }
                return (app.name, nil)
            case .material:
                guard let resource = catalog.educationalResources.first(where: { $0.id == ref.id }) else { return nil }
                return (resource.name, nil)
            }
        }
    }

    private var individualTotal: Double {
        resolvedItems.compactMap(\.priceEUR).reduce(0, +)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            CoverThumbnail(
                url: bundle.coverImageURL,
                fallbackSymbol: "shippingbox.fill",
                tint: .purple,
                height: 130,
                lightboxTitle: bundle.name
            )
            Text(bundle.name).font(.headline)
            CountdownBadge(scheduling: bundle.scheduling)
            CollapsibleDescription(text: bundle.description)

            VStack(alignment: .leading, spacing: 3) {
                Text(L.t("bundles.includes")).font(.caption2).foregroundStyle(.secondary)
                ForEach(resolvedItems, id: \.name) { entry in
                    Text("• \(entry.name)").font(.caption2).foregroundStyle(.secondary)
                }
            }

            HStack(alignment: .lastTextBaseline, spacing: 8) {
                if individualTotal > bundle.bundlePriceEUR {
                    Text(individualTotal.formatted(.currency(code: "EUR")))
                        .font(.caption)
                        .strikethrough()
                        .foregroundStyle(.tertiary)
                }
                Text(bundle.bundlePriceDisplay)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.orange)
            }

            ExtraLinksRow(purchaseURL: nil, demoURL: nil, social: bundle.socialLinks)
            Button(L.t("bundles.buy")) { NSWorkspace.shared.open(buyURL) }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCardBackground()
        .overlay(alignment: .topTrailing) {
            if let urlString = bundle.youtubeURL, let url = URL(string: urlString) {
                Button { NSWorkspace.shared.open(url) } label: {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                        .background(Circle().fill(.background).frame(width: 16, height: 16))
                }
                .buttonStyle(.plain)
                .help(L.t("card.youtubeLink"))
                .padding(8)
                .help(L.t("card.tutorial"))
            }
        }
    }

    private var buyURL: URL {
        let itemsList = resolvedItems.map(\.name).joined(separator: ", ")
        let text = "Salut! Vreau să cumpăr pachetul „\(bundle.name)” (\(itemsList)) la \(bundle.bundlePriceDisplay). ID calculator: \(MachineID.display)"
        return WhatsAppLink.url(text: text)
    }
}
