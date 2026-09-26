import SwiftUI
import AppKit
import GDCPluginManagerCore

struct PartnerOffersGrid: View {
    let offers: [PartnerOffer]

    private let columns = [GridItem(.adaptive(minimum: 300, maximum: 400), spacing: 16)]

    var body: some View {
        // Bara de filtre comuna (2026-09-11) — shadowing pe `offers`,
        // deci corpul de mai jos ramane neschimbat, dar primeste lista
        // deja filtrata. Vezi CatalogFilterBar.swift.
        FilteredCatalogSection(items: offers, options: .content) { offers in
        ScrollView {
            if offers.isEmpty {
                Text(L.t("partnerOffers.empty")).foregroundStyle(.secondary).padding(40)
            } else {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(offers) { offer in
                        PartnerOfferCard(offer: offer)
                    }
                }
                .padding(16)
            }
        }
        }
    }
}

struct PartnerOfferCard: View {
    let offer: PartnerOffer

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                CoverThumbnail(
                    url: offer.coverImageURL,
                    fallbackSymbol: "tag.fill",
                    tint: .red,
                    height: 150,
                    lightboxTitle: offer.brandName
                )
                // Badge de discount, generat automat din `discountText` —
                // permis aici (brand PARTENER, nu produs propriu GDC).
                if let discountText = offer.discountText {
                    Text(discountText.uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Capsule().fill(Color.red))
                        .padding(8)
                }
            }
            Text(offer.brandName).font(.headline)
            CountdownBadge(scheduling: offer.scheduling)
            CollapsibleDescription(text: offer.description)
            if let coupon = offer.couponCode {
                HStack(spacing: 4) {
                    Text(L.t("partnerOffers.coupon")).font(.caption2).foregroundStyle(.secondary)
                    Text(coupon).font(.caption2.monospaced()).fontWeight(.bold)
                }
            }
            ExtraLinksRow(purchaseURL: nil, demoURL: nil, social: offer.socialLinks)
            if let url = URL(string: offer.url) {
                Button(L.t("partnerOffers.open")) { NSWorkspace.shared.open(url) }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCardBackground()
        .overlay(alignment: .topLeading) {
            if let urlString = offer.youtubeURL, let url = URL(string: urlString) {
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
}
