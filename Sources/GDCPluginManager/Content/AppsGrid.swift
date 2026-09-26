import SwiftUI
import AppKit
import GDCPluginManagerCore

struct AppsGrid: View {
    let apps: [AppLink]

    // Bara de filtre si badge-urile vin din componentele COMUNE
    // (CatalogFilterBar.swift) — aceleasi in toate sectiunile.
    @StateObject private var filters = CatalogFilterState()

    private let columns = [GridItem(.adaptive(minimum: 220, maximum: 280), spacing: 14)]

    private var filtered: [AppLink] { filters.filter(apps) }

    var body: some View {
        VStack(spacing: 0) {
            CatalogFilterBar(
                state: filters,
                options: .product,
                availableTags: CatalogFacets.tags(apps),
                availableGroups: CatalogFacets.groups(apps)
            )
            Divider()
            ScrollView {
                if apps.isEmpty {
                    Text(L.t("apps.empty")).foregroundStyle(.secondary).padding(40)
                } else if filtered.isEmpty {
                    Text(L.t("access.filter.none")).foregroundStyle(.secondary).padding(40)
                } else {
                    LazyVGrid(columns: columns, spacing: 14) {
                        // Preț dinamic (Regula 27) - un singur fetch pentru
                        // tot grid-ul, nu unul per card.
                        ForEach(filtered) { app in
                            AppCard(app: app)
                        }
                    }
                    .padding(16)
                }
            }
            // Atasat pe ScrollView (mereu prezent), nu pe LazyVGrid din
            // ramura `else` - acelasi bug de `.task` pe conditional gol deja
            // documentat la SeasonalBackgroundLayer/LaunchOfferBanner.
            .task { await AppPricingFetcher.shared.refresh() }
        }
    }
}


struct AppCard: View {
    let app: AppLink
    @ObservedObject private var downloader = AppDirectDownload.shared

    /// Apps aren't a `PluginType` case, so they get their own fixed tint
    /// here instead of `PluginType.tintColor` — matches the blue Cristi
    /// asked for, distinct from every plugin category's color.
    private let tint = Color.blue

    // Preț dinamic (Regula 27, 2026-08-31) - vezi AppPricingFetcher. Un
    // card fara `pricingProductID` (Clapperboard Digital, GDC Metadata
    // View Premium etc.) sau fara raspuns de la gordas.dev ramane
    // NESCHIMBAT - fail-open, nu un card gol/eronat.
    @ObservedObject private var pricingFetcher = AppPricingFetcher.shared
    private var pricing: ProductPricing? {
        guard let id = app.pricingProductID else { return nil }
        return pricingFetcher.catalog?.products[id]
    }
    private func formattedPrice(_ value: Double) -> String {
        let isWhole = value.truncatingRemainder(dividingBy: 1) == 0
        return "\(isWhole ? String(Int(value)) : String(value)) €"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(L.t("apps.badge"))
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(tint)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(tint.opacity(0.15)))
                // Badge de status comun (GRATUIT/TRIAL/EXTERN) — nu apare
                // deloc daca furnizorul n-a declarat un tip de acces.
                AccessBadge(access: app.resolvedAccess)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            // Coperta, daca aplicatia are una — altfel cade pe simbolul
            // "app.badge" de mai jos, la aceeasi inaltime (CoverThumbnail
            // face fallback-ul singur, vezi CoverImageViews.swift).
            CoverThumbnail(
                url: app.coverImageURL,
                fallbackSymbol: "app.badge",
                tint: tint,
                height: 56,
                lightboxTitle: app.name
            )
            Text(app.name).font(.headline)
            if let pricing {
                if let promo = pricing.activePromo {
                    HStack(spacing: 4) {
                        Text(formattedPrice(promo.price))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.orange)
                        Text(formattedPrice(pricing.basePrice))
                            .font(.caption2).strikethrough().foregroundStyle(.tertiary)
                    }
                    CountdownBadge(scheduling: promo.asScheduling)
                } else {
                    Text(formattedPrice(pricing.basePrice))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            } else {
                // Fara pret dinamic din Pricing Manager, `resolvedAccess`
                // aplica pasul 2 al precedentei (pret de referinta + aviz).
                AccessPriceLabel(access: app.resolvedAccess)
                CountdownBadge(scheduling: app.scheduling)
            }
            AccessTagsRow(tags: app.resolvedAccess.tags)
            Spacer(minLength: 0)
            if let raw = app.downloadURL, let file = URL(string: raw) {
                let busy = downloader.active.contains(app.id)
                Button(busy ? L.t("apps.downloading") : L.t("apps.download")) { downloader.start(appID: app.id, url: file) }
                    .disabled(busy)
                if let reason = downloader.failed[app.id] {
                    Text(L.t("apps.downloadFailed")).font(.caption).foregroundStyle(.secondary).help(reason)
                }
            }
            if let url = URL(string: app.url) {
                Button(L.t("apps.open")) { NSWorkspace.shared.open(url) }
            }
            SocialLinksRow(app.socialLinks)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
        .glassCardBackground()
        .overlay(alignment: .topTrailing) { infoButton }
    }

    @ViewBuilder
    private var infoButton: some View {
        if let urlString = app.youtubeURL, let url = URL(string: urlString) {
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
