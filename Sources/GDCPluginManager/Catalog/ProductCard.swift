import SwiftUI
import AppKit
import GDCPluginManagerCore

/// Cardul de produs (prototip A+B aprobat 2026-09-26): ierarhia nativă din A,
/// imaginea de `Size.cardArtworkHeight` cu finisaj lucios discret și insigna pe imagine din B.
/// Starea vine din `ProductActionState` (Core, testat); cardul doar o afișează.
struct ProductCard: View {
    let item: PluginItem
    /// Doar pentru galeria de componente (build DEBUG): forțează o stare ca să fie verificată vizual.
    var forcedState: ProductActionState? = nil
    @EnvironmentObject private var installs: InstallManager
    @ObservedObject private var license = LicenseManager.shared
    @EnvironmentObject private var catalog: CatalogService

    @State private var isBusy = false
    @State private var errorMessage: String?
    @State private var statusMessage: String?
    /// Caile REALE unde a ajuns produsul, verificate dupa instalare.
    @State private var installedPaths: [URL] = []
    @State private var showResolveWarning = false
    /// Eșec de instalare pentru o resursă PLĂTITĂ (vezi InstallError.
    /// paidResourceInstallFailed / InstallManager.swift) — mesaj generic +
    /// buton WhatsApp în loc de fișiere/instrucțiuni de instalare manuală.
    @State private var showPaidResourceSupportError = false

    var body: some View {
        ContentCard(fixedHeight: GDCTokens.Size.productCardHeight) {
            VStack(alignment: .leading, spacing: GDCTokens.Space.s) {
                artwork
                VStack(alignment: .leading, spacing: GDCTokens.Space.xxs) {
                    Text(item.type.label.uppercased())
                        .font(.caption2.weight(.bold))
                        .tracking(0.8)
                        .foregroundStyle(item.type.tintColor)
                    Text(item.name)
                        .font(GDCTokens.Typography.cardTitle)
                        .lineLimit(1)
                        .help(item.name)
                    Text(item.description)
                        .font(GDCTokens.Typography.metadata)
                        .foregroundStyle(GDCTokens.Palette.textSecondary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .help(item.description)
                }
                HStack(spacing: GDCTokens.Space.s) {
                    Text(versionLine)
                        .font(GDCTokens.Typography.caption.monospacedDigit())
                        .foregroundStyle(GDCTokens.Palette.textTertiary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    infoButton
                }
                extraLinksRow
                messages
                Spacer(minLength: 0)
                actionButton
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(item.name)
        .alert(resolveWarningTitle, isPresented: $showResolveWarning) {
            Button(L.t("resolve.running.ok")) {}
        } message: {
            Text(resolveWarningBody)
        }
    }

    /// Imaginea (coperta sau simbolul tipului) cu insignele pe ea: stare/preț jos-stânga,
    /// numărătoarea inversă sus-stânga, platforma sus-dreapta.
    private var artwork: some View {
        CoverThumbnail(
            url: item.coverImageURL,
            fallbackSymbol: item.iconSymbol ?? item.type.defaultSymbol,
            tint: item.type.tintColor,
            height: GDCTokens.Size.cardArtworkHeight,
            lightboxTitle: item.name
        )
        .overlay(alignment: .bottomLeading) { artworkBadges.padding(GDCTokens.Space.s) }
        .overlay(alignment: .topLeading) { CountdownBadge(scheduling: item.scheduling).padding(GDCTokens.Space.s) }
        .overlay(alignment: .topTrailing) {
            // Platforma: vizibilă pentru TOATE cele 3 stări (cerere explicită 2026-08-25).
            Image(systemName: item.supportedOS.badgeSymbol)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(GDCTokens.Palette.textSecondary)
                .frame(width: GDCTokens.Size.badgeHeight, height: GDCTokens.Size.badgeHeight)
                .background(.regularMaterial, in: Circle())
                .padding(GDCTokens.Space.s)
                .help(osBadgeTooltip)
                .accessibilityLabel(osBadgeTooltip)
        }
    }

    private var versionLine: String {
        if case .updateAvailable(let installed, let latest) = actionState { return "v\(installed) → v\(latest)" }
        if case .installed(let version) = actionState { return "\(L.t("card.installed")) v\(version)" }
        return "\(L.t("card.version")) \(item.version)"
    }

    /// Mesajele operației (eroare, confirmare, contact) — aceleași ca înainte.
    @ViewBuilder
    private var messages: some View {
        if case .offline = actionState {
            Text(L.t("card.offline.note"))
                .font(GDCTokens.Typography.caption)
                .foregroundStyle(GDCTokens.Palette.textSecondary)
                .lineLimit(2)
        }
        if let errorMessage {
            Text(errorMessage).font(GDCTokens.Typography.caption).foregroundStyle(GDCTokens.Palette.error)
                .lineLimit(2).help(errorMessage)
        }
        if let statusMessage {
            Text(statusMessage).font(GDCTokens.Typography.caption).foregroundStyle(GDCTokens.Palette.info)
                .lineLimit(1).help(statusMessage)
            if let first = installedPaths.first {
                Button(L.t("install.revealInFinder")) {
                    NSWorkspace.shared.activateFileViewerSelecting([first])
                }
                .buttonStyle(.link)
                .font(GDCTokens.Typography.caption)
            }
        }
        if showPaidResourceSupportError {
            Button {
                NSWorkspace.shared.open(supportContactURL)
            } label: {
                Label(L.t("install.contact.support"), systemImage: "message.fill")
                    .font(GDCTokens.Typography.caption)
                    .lineLimit(1)
            }
            .buttonStyle(.bordered)
            .tint(GDCTokens.Palette.success)
        }
    }

    /// Insignele de pe imagine: stare (eroare/offline/incompatibil, altfel gratuit/probă/
    /// licență/promo) + suma de susținere, dacă e cazul (Regula 3: donație, nu preț).
    @ViewBuilder
    private var artworkBadges: some View {
        HStack(spacing: GDCTokens.Space.xs) {
            switch actionState {
            case .failed: StatusBadge(kind: .error, onArtwork: true)
            case .incompatible: StatusBadge(kind: .incompatible, onArtwork: true)
            case .offline: StatusBadge(kind: .offline, onArtwork: true)
            default:
                if item.isFree && item.isTrial {
                    StatusBadge(kind: .trial, onArtwork: true)
                } else if item.isFree {
                    StatusBadge(kind: .free, onArtwork: true)
                } else {
                    if item.isPromoActive {
                        StatusBadge(kind: .promo, onArtwork: true)
                    } else {
                        StatusBadge(kind: .license, onArtwork: true).help(L.t("card.trustMessage"))
                    }
                    HStack(spacing: GDCTokens.Space.xs) {
                        if item.isPromoActive {
                            Text(item.priceDisplay).strikethrough().foregroundStyle(GDCTokens.Palette.textSecondary)
                        }
                        Text(item.effectivePriceEUR.formatted(.currency(code: "EUR"))).fontWeight(.semibold)
                    }
                    .font(.caption2.monospacedDigit())
                    .padding(.horizontal, GDCTokens.Space.s)
                    .frame(height: GDCTokens.Size.badgeHeight)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: GDCTokens.Radius.badge))
                }
            }
        }
    }

    private var extraLinksRow: some View {
        ExtraLinksRow(purchaseURL: item.purchaseURL, demoURL: item.demoURL, social: item.socialLinks)
    }

    /// Tutorial link, editable anytime from Furnizor without touching the
    /// product's files — hidden entirely (not disabled) until one exists,
    /// so a not-yet-recorded tutorial doesn't clutter every card.
    @ViewBuilder
    private var infoButton: some View {
        if let urlString = item.youtubeURL, let url = URL(string: urlString) {
            Button { NSWorkspace.shared.open(url) } label: {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help(L.t("card.youtubeLink"))
            .help(L.t("card.tutorial"))
        }
    }

    private var osBadgeTooltip: String {
        switch item.supportedOS {
        case .macOS: return "Doar macOS"
        case .windows: return "Doar Windows"
        case .crossPlatform: return "Compatibil Mac + Windows"
        }
    }

    private var resolveWarningTitle: String {
        item.type == .powerGrade ? L.t("resolve.notrunning.title") : L.t("resolve.running.title")
    }

    private var resolveWarningBody: String {
        item.type == .powerGrade ? L.t("resolve.notrunning.body") : L.t("resolve.running.body")
    }

    /// Derivată din managerii existenți (UI_ARCHITECTURE.md §3); cardul doar o afișează.
    private var actionState: ProductActionState {
        forcedState ?? .derive(isCompatible: item.supportedOS.allows(current: .current),
                isUnlocked: license.isUnlocked(for: item),
                isBusy: isBusy,
                installedVersion: installs.installedVersion(of: item),
                catalogVersion: item.version,
                lastInstallFailed: errorMessage != nil || showPaidResourceSupportError,
                isOffline: catalog.isShowingCachedCatalog)
    }

    @ViewBuilder
    private var actionButton: some View {
        switch actionState {
        case .incompatible:
            Text(L.t("card.incompatibleOS"))
                .font(GDCTokens.Typography.metadata)
                .foregroundStyle(GDCTokens.Palette.textSecondary)
                .frame(minHeight: GDCTokens.Size.minHitTarget)
        case .licenseRequired:
            Button(L.t("card.buy")) { NSWorkspace.shared.open(buyURL) }
                .buttonStyle(.gdcPrimary)
        case .installing:
            ProgressRow(label: L.t("card.installing"))
                .frame(minHeight: GDCTokens.Size.minHitTarget)
        case .updateAvailable:
            HStack(spacing: GDCTokens.Space.s) {
                Button(L.t("card.update")) { runGuarded { install() } }.buttonStyle(.gdcPrimary)
                Button(L.t("card.remove"), role: .destructive) { runGuarded { remove() } }.buttonStyle(.gdcDestructive)
            }
        case .installed:
            HStack(spacing: GDCTokens.Space.s) {
                StatusBadge(kind: .installed)
                Spacer(minLength: 0)
                Button(L.t("card.remove"), role: .destructive) { runGuarded { remove() } }.buttonStyle(.gdcDestructive)
            }
        case .failed(let isUpdate):
            HStack(spacing: GDCTokens.Space.s) {
                Button(L.t("card.retry")) { runGuarded { install() } }.buttonStyle(.gdcPrimary)
                if isUpdate {
                    Button(L.t("card.remove"), role: .destructive) { runGuarded { remove() } }.buttonStyle(.gdcDestructive)
                }
            }
        case .notInstalled, .offline:
            Button(L.t("card.install")) { runGuarded { install() } }.buttonStyle(.gdcPrimary)
        }
    }

    private var buyURL: URL {
        // Suma promoțională activă (dacă e cazul) — vezi effectivePriceEUR.
        let priceText = item.effectivePriceEUR.formatted(.currency(code: "EUR"))
        let text = "Salut! Vreau să deblochez \(item.name) cu o donație de \(priceText). ID calculator: \(MachineID.display)"
        return WhatsAppLink.url(text: text)
    }

    private var supportContactURL: URL {
        let text = "Salut! A apărut o eroare la instalarea \(item.name) — mă poți ajuta să o instalez manual? ID calculator: \(MachineID.display)"
        return WhatsAppLink.url(text: text)
    }

    private func runGuarded(_ action: @escaping () -> Void) {
        // Every other type must be closed (it only reads its plugin
        // folder at launch); PowerGrade is the opposite — it needs a
        // running, scriptable Resolve to import into (see
        // PowerGradeImporter.swift). Without Resolve running, the action
        // still proceeds for PowerGrade — it just falls back to staging
        // the files with a manual-import message instead of failing.
        if item.type != .powerGrade && ResolveProcessCheck.isRunning {
            showResolveWarning = true
            return
        }
        if item.type == .powerGrade && !ResolveProcessCheck.isRunning {
            showResolveWarning = true
        }
        action()
    }

    private func install() {
        errorMessage = nil
        statusMessage = nil
        installedPaths = []
        showPaidResourceSupportError = false
        isBusy = true
        Task {
            do {
                let outcome = try await installs.install(item)
                AnalyticsClient.logDownload(productID: item.id, productName: item.name)
                DiagnosticLog.write("Install", "ok \(item.id) v\(item.version)")
                switch outcome {
                case .installedToGallery(let albumName):
                    statusMessage = String(format: L.t("powergrade.imported"), albumName)
                case .installedNeedsManualStep(let folder):
                    statusMessage = String(format: L.t("powergrade.manualstep"), folder.path)
                case .installed(let paths):
                    // [2026-09-14] Pana acum o instalare reusita nu spunea
                    // NIMIC. Acum arata unde a ajuns efectiv fisierul, verificat
                    // pe disc, si ofera un buton care il deschide in Finder.
                    // OFX: clientul nu vede folderul și nu are „Arată în Finder” (cerință explicită) — doar „Instalat”.
                    installedPaths = item.type == .ofx ? [] : paths
                    if item.type == .ofx {
                        statusMessage = L.t("install.doneShort")
                    } else if let first = paths.first {
                        let folder = first.deletingLastPathComponent().path
                            .replacingOccurrences(of: NSHomeDirectory(), with: "~")
                        statusMessage = String(format: L.t("install.done"), folder)
                    } else {
                        statusMessage = L.t("install.doneShort")
                    }
                }
            } catch InstallError.paidResourceInstallFailed {
                // Mesaj generic, fără cale de fișier/instrucțiuni — vezi
                // InstallManager.swift. Butonul de contact apare separat,
                // mai jos în card (showPaidResourceSupportError).
                errorMessage = L.t("install.paidresource.error")
                showPaidResourceSupportError = true
            } catch InstallError.downloadFailed {
                // Fișierul nu mai există la calea din catalogul local (catalog vechi în cache, produs republicat) → reîmprospătăm catalogul; utilizatorul reîncearcă.
                DiagnosticLog.write("Install", "eroare \(item.id): descărcare eșuată — reîmprospătez catalogul")
                await CatalogService.shared.refresh()
                errorMessage = L.t("install.catalogRefreshed")
            } catch {
                DiagnosticLog.write("Install", "eroare \(item.id): \(error.localizedDescription)")
                errorMessage = error.localizedDescription
            }
            isBusy = false
        }
    }

    private func remove() {
        errorMessage = nil
        statusMessage = nil
        showPaidResourceSupportError = false
        do {
            let outcome = try installs.remove(item)
            if item.type == .powerGrade, outcome == .removedNeedsManualGalleryCleanup {
                statusMessage = L.t("powergrade.manualremove")
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
