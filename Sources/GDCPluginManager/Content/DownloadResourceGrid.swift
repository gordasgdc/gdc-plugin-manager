import SwiftUI
import AppKit
import GDCPluginManagerCore

/// Grid pentru o categorie de resurse de download direct (LUT/SFX/VFX/
/// Plugin) — Etapa 2 (2026-08-29). Filtru OS (Toate/Mac/Windows), la fel
/// ca `CatalogGrid` — unele resurse (ex. un plugin Premiere) pot fi
/// specifice unei singure platforme.
struct DownloadResourceGrid: View {
    let resources: [DownloadableResource]

    // Filtru OS local inlocuit 2026-09-11 cu bara COMUNA, care aduce si
    // pret/grup/etichete. `isFree`/`supportedOS` proprii resursei raman
    // sursa de adevar (pasul 1 al precedentei).
    @StateObject private var filters = CatalogFilterState()

    private let columns = [GridItem(.adaptive(minimum: 220, maximum: 280), spacing: GDCTokens.Space.grid)]

    private var filteredResources: [DownloadableResource] { filters.filter(resources) }

    var body: some View {
        VStack(spacing: 0) {
            if !resources.isEmpty {
                CatalogFilterBar(
                    state: filters,
                    options: .product,
                    availableTags: CatalogFacets.tags(resources),
                    availableGroups: CatalogFacets.groups(resources)
                )
            }
            ScrollView {
                if resources.isEmpty {
                    Text(L.t("download.empty")).foregroundStyle(.secondary).padding(GDCTokens.Space.page)
                } else if filteredResources.isEmpty {
                    Text(L.t("filter.price.empty")).foregroundStyle(.secondary).padding(GDCTokens.Space.page)
                } else {
                    LazyVGrid(columns: columns, spacing: GDCTokens.Space.grid) {
                        ForEach(filteredResources) { resource in
                            DownloadResourceCard(resource: resource)
                        }
                    }
                    .padding(GDCTokens.Space.l)
                }
            }
        }
    }
}

struct DownloadResourceCard: View {
    let resource: DownloadableResource
    @State private var isDownloading = false
    @State private var downloadError: String?
    @ObservedObject private var locations = DownloadLocationStore.shared
    // Licențiere adăugată 2026-08-29 (cerut explicit) — port 1:1 al
    // fluxului de pe `PluginCard` (Gratuit/Probă/Licență + WhatsApp).
    @ObservedObject private var license = LicenseManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: GDCTokens.Space.s) {
            HStack(alignment: .top) {
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    Image(systemName: resource.supportedOS.badgeSymbol)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 20, height: 20)
                        .background(Circle().fill(Color.secondary.opacity(0.12)))
                        .help(resource.supportedOS.badgeLabel)
                    licenseBadge
                }
            }
            CoverThumbnail(
                url: resource.coverImageURL,
                fallbackSymbol: resource.category.defaultSymbol,
                tint: resource.category.tintColor,
                height: 100,
                lightboxTitle: resource.name
            )
            Text(resource.name).font(.headline)
            if let kind = resource.pdfKind {
                BadgePill(text: L.t("pdfKind.\(kind.rawValue)"), color: .red)
            }
            CountdownBadge(scheduling: resource.scheduling)
            CollapsibleDescription(text: resource.description)
            ExtraLinksRow(purchaseURL: resource.purchaseURL, demoURL: resource.demoURL, social: resource.socialLinks)
            // Etapa 5+ (2026-08-29, cerut explicit): "să aibă posibilitatea
            // să își pună path-ul... ca să știe tot timpul unde l-a
            // descărcat" — stare 100% locală (DownloadLocationStore), nu
            // parte din catalog. Doar dacă e deblocată (n-are sens sa
            // memorezi o cale pentru ceva ce inca nu poti descarca).
            if license.isUnlocked(for: resource) {
                downloadLocationRow
            }
            Spacer(minLength: 0)
            actionButton
        }
        .contentCard(minHeight: 96, alignment: .leading)
        .overlay(alignment: .topLeading) { infoButton }
    }

    @ViewBuilder
    private var licenseBadge: some View {
        if resource.isFree && resource.isTrial {
            BadgePill(text: L.t("card.trial"), color: .blue)
        } else if resource.isFree {
            BadgePill(text: L.t("card.free"), color: .green)
        } else {
            VStack(alignment: .trailing, spacing: 3) {
                if resource.isPromoActive {
                    Text(resource.priceDisplay).font(.caption2).strikethrough().foregroundStyle(.tertiary)
                }
                Text(resource.effectivePriceEUR.formatted(.currency(code: "EUR")))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                if resource.isPromoActive {
                    BadgePill(text: L.t("card.promo"), color: .red)
                } else {
                    BadgePill(text: L.t("card.paid"), color: .orange)
                        .help(L.t("card.trustMessage"))
                }
            }
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        if !resource.supportedOS.allows(current: .current) {
            Text(L.t("card.incompatibleOS")).font(.caption).foregroundStyle(GDCTokens.Palette.error)
        } else if !license.isUnlocked(for: resource) {
            Button(L.t("card.buy")) { NSWorkspace.shared.open(buyURL) }
        } else if resource.hasDirectFile {
            // [2026-09-14] Fișier încărcat direct pe server: se descarcă din
            // aplicație și se arată în Finder. Fără browser — vezi Regula 20.
            HStack(spacing: GDCTokens.Space.s) {
                Button(isDownloading ? L.t("resource.downloading") : L.t("resource.download")) {
                    Task { await downloadDirect() }
                }
                .disabled(isDownloading)
                if isDownloading { ProgressView().controlSize(.small) }
            }
            if let downloadError {
                Text(downloadError).font(.caption).foregroundStyle(GDCTokens.Palette.error)
            }
        } else if let url = URL(string: resource.url) {
            Button(L.t("audio.open")) { NSWorkspace.shared.open(url) }
        }
    }

    private func downloadDirect() async {
        downloadError = nil
        isDownloading = true
        defer { isDownloading = false }
        do {
            let saved = try await InstallManager.shared.downloadResourceFile(resource)
            NSWorkspace.shared.activateFileViewerSelecting([saved])
        } catch {
            downloadError = error.localizedDescription
        }
    }

    private var buyURL: URL {
        let priceText = resource.effectivePriceEUR.formatted(.currency(code: "EUR"))
        let text = "Salut! Vreau să deblochez \(resource.name) cu o donație de \(priceText). ID calculator: \(MachineID.display)"
        return WhatsAppLink.url(text: text)
    }

    @ViewBuilder
    private var downloadLocationRow: some View {
        if let path = locations.path(for: resource.id) {
            HStack(spacing: 6) {
                Image(systemName: "folder.fill").font(.system(size: 10)).foregroundStyle(.secondary)
                Text(path)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Button {
                    locations.openFolder(for: resource.id)
                } label: {
                    Image(systemName: "arrow.up.forward.square")
                }
                .buttonStyle(.plain)
                .help(L.t("download.location.open"))
                Button {
                    locations.pickFolder(for: resource.id)
                } label: {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.plain)
                .help(L.t("download.location.change"))
            }
        } else {
            Button {
                locations.pickFolder(for: resource.id)
            } label: {
                Label(L.t("download.location.set"), systemImage: "folder.badge.plus")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var infoButton: some View {
        if let urlString = resource.youtubeURL, let url = URL(string: urlString) {
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
