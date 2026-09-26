import SwiftUI
import AppKit
import GDCPluginManagerCore

struct PluginCard: View {
    let item: PluginItem
    @EnvironmentObject private var installs: InstallManager
    @ObservedObject private var license = LicenseManager.shared

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
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                typeBadge
                // Badge vizibil pentru TOATE cele 3 stari, inclusiv
                // crossPlatform (2026-08-25, cerere explicita: "Ambele"
                // trebuie sa se vada, nu doar sa fie absenta unui badge —
                // decizia anterioara de a-l ascunde pentru starea implicita
                // a fost o presupunere gresita despre asteptarile UX).
                // SF Symbols vectoriale, nu emoji color (2026-08-29, cerut
                // explicit — "impecabil, profesionist") — chip circular
                // discret, ton neutru, la fel ca stilul de badge din
                // `typeBadge` de mai jos.
                Image(systemName: item.supportedOS.badgeSymbol)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(Color.secondary.opacity(0.12)))
                    .help(osBadgeTooltip)
            }
            // Coperta produsului (preset .icon, pătrat 512×512). Dacă
            // produsul n-are una, cade pe simbolul SF — cardul păstrează
            // aceeași înălțime, deci grila rămâne aliniată.
            CoverThumbnail(
                url: item.coverImageURL,
                fallbackSymbol: item.iconSymbol ?? item.type.defaultSymbol,
                tint: item.type.tintColor,
                height: 128,
                lightboxTitle: item.name
            )
            .frame(height: 128)
            .clipped()
            .overlay(alignment: .topTrailing) { priceBadges.padding(6) }
            .overlay(alignment: .topLeading) { CountdownBadge(scheduling: item.scheduling).padding(6) }
            Text(item.name)
                .font(.system(.headline, design: .rounded))
                .lineLimit(1)
            Text(item.description)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, minHeight: 30, alignment: .topLeading)
                .help(item.description)
            HStack(spacing: 6) {
                Text("\(L.t("card.version")) \(item.version)")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.tertiary)
                Spacer(minLength: 0)
                infoButton
            }
            extraLinksRow

            if let errorMessage {
                Text(errorMessage).font(.caption2).foregroundStyle(.red)
                    .lineLimit(1).help(errorMessage)
            }
            if let statusMessage {
                Text(statusMessage).font(.caption2).foregroundStyle(.blue)
                    .lineLimit(1).help(statusMessage)
                if let first = installedPaths.first {
                    Button(L.t("install.revealInFinder")) {
                        NSWorkspace.shared.activateFileViewerSelecting([first])
                    }
                    .buttonStyle(.link)
                    .font(.caption2)
                }
            }
            if showPaidResourceSupportError {
                Button {
                    NSWorkspace.shared.open(supportContactURL)
                } label: {
                    Label(L.t("install.contact.support"), systemImage: "message.fill")
                        .font(.caption2)
                        .lineLimit(1)
                }
                .buttonStyle(.bordered)
                .tint(.green)
            }

            Spacer(minLength: 0)
            actionButton
                .frame(height: 28)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: cardHeight, maxHeight: cardHeight, alignment: .topLeading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.2), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 4)
        .alert(resolveWarningTitle, isPresented: $showResolveWarning) {
            Button(L.t("resolve.running.ok")) {}
        } message: {
            Text(resolveWarningBody)
        }
    }

    /// Înălțime fixă pentru TOATE cardurile din grilă: butonul de jos cade
    /// pe aceeași linie indiferent de descriere/preț/mesaje.
    private let cardHeight: CGFloat = 340

    /// Ecusoane uniforme, colț dreapta-sus al imaginii: stare (GRATUIT /
    /// TRIAL / LICENȚĂ / PROMO) + suma de susținere, dacă e cazul.
    @ViewBuilder
    private var priceBadges: some View {
        VStack(alignment: .trailing, spacing: 4) {
            if item.isFree && item.isTrial {
                BadgePill(text: L.t("card.trial"), color: .blue)
            } else if item.isFree {
                BadgePill(text: L.t("card.free"), color: .green)
            } else {
                if item.isPromoActive {
                    BadgePill(text: L.t("card.promo"), color: .red)
                } else {
                    BadgePill(text: L.t("card.paid"), color: .orange)
                        .help(L.t("card.trustMessage"))
                }
                HStack(spacing: 4) {
                    if item.isPromoActive {
                        Text(item.priceDisplay).strikethrough().foregroundStyle(.secondary)
                    }
                    Text(item.effectivePriceEUR.formatted(.currency(code: "EUR")))
                        .fontWeight(.semibold)
                }
                .font(.system(size: 10, design: .rounded))
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(.ultraThinMaterial, in: Capsule())
            }
        }
    }

    private var extraLinksRow: some View {
        ExtraLinksRow(purchaseURL: item.purchaseURL, demoURL: item.demoURL, social: item.socialLinks)
    }

    /// Centered tag at the top of the card naming the product's type
    /// (LUT / DCTL / Fuse / PowerGrade / OFX) — a quick, consistent way
    /// to tell categories apart in a mixed grid.
    private var typeBadge: some View {
        Text(item.type.label.uppercased())
            .font(.system(size: 9, weight: .bold))
            .tracking(0.5)
            .foregroundStyle(item.type.tintColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(item.type.tintColor.opacity(0.15)))
            .frame(maxWidth: .infinity, alignment: .center)
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

    @ViewBuilder
    private var actionButton: some View {
        if !item.supportedOS.allows(current: .current) {
            Text(L.t("card.incompatibleOS"))
                .font(.caption)
                .foregroundStyle(.red)
        } else if !license.isUnlocked(for: item) {
            Button(L.t("card.buy")) { NSWorkspace.shared.open(buyURL) }
        } else if isBusy {
            ProgressView().controlSize(.small)
        } else if installs.hasUpdate(item) {
            HStack {
                Button(L.t("card.update")) { runGuarded { install() } }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                Button(L.t("card.remove"), role: .destructive) { runGuarded { remove() } }
            }
        } else if installs.isInstalled(item) {
            HStack {
                Label(L.t("card.installed"), systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
                Spacer()
                Button(L.t("card.remove"), role: .destructive) { runGuarded { remove() } }
            }
        } else {
            Button(L.t("card.install")) { runGuarded { install() } }
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
