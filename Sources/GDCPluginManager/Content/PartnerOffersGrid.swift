import SwiftUI
import AppKit
import GDCPluginManagerCore

struct PartnerOffersGrid: View {
    let offers: [PartnerOffer]

    private let columns = [GridItem(.adaptive(minimum: 300, maximum: 400), spacing: GDCTokens.Space.l)]

    var body: some View {
        // Bara de filtre comuna (2026-09-11) — shadowing pe `offers`,
        // deci corpul de mai jos ramane neschimbat, dar primeste lista
        // deja filtrata. Vezi CatalogFilterBar.swift.
        FilteredCatalogSection(items: offers, options: .content) { offers in
        ScrollView {
            if offers.isEmpty {
                Text(L.t("partnerOffers.empty")).foregroundStyle(.secondary).padding(GDCTokens.Space.page)
            } else {
                LazyVGrid(columns: columns, spacing: GDCTokens.Space.grid) {
                    ForEach(offers) { offer in
                        PartnerOfferCard(offer: offer)
                    }
                }
                .padding(GDCTokens.Space.l)
            }
        }
        }
    }
}

struct PartnerOfferCard: View {
    let offer: PartnerOffer

    var body: some View {
        VStack(alignment: .leading, spacing: GDCTokens.Space.s) {
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
                        .padding(.horizontal, 10).padding(.vertical, GDCTokens.Space.xs)
                        .background(Capsule().fill(GDCTokens.Palette.error))
                        .padding(GDCTokens.Space.s)
                }
            }
            Text(offer.brandName).font(.headline)
            CountdownBadge(scheduling: offer.scheduling)
            CollapsibleDescription(text: offer.description)
            if let coupon = offer.couponCode {
                HStack(spacing: GDCTokens.Space.xs) {
                    Text(L.t("partnerOffers.coupon")).font(.caption2).foregroundStyle(.secondary)
                    Text(coupon).font(.caption2.monospaced()).fontWeight(.bold)
                }
            }
            ExtraLinksRow(purchaseURL: nil, demoURL: nil, social: offer.socialLinks)
            if let url = URL(string: offer.url) {
                Button(L.t("partnerOffers.open")) { NSWorkspace.shared.open(url) }
            }
        }
        .padding(GDCTokens.Space.m)
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
                .padding(GDCTokens.Space.s)
                .help(L.t("card.tutorial"))
            }
        }
    }
}
