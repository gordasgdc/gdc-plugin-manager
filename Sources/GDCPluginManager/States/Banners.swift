import SwiftUI
import AppKit
import GDCPluginManagerCore

/// [2026-09-03] Port 1:1 al bannerului de pe Windows — vezi
/// UpdateChecker.checkFailed. Aratat DOAR cand nu exista deja un
/// UpdateBanner normal de aratat (else-branch in body), ca sa nu se
/// suprapuna doua bannere de update.
struct CheckFailedBanner: View {
    @ObservedObject private var updateChecker = UpdateChecker.shared

    var body: some View {
        Banner(kind: .warning, title: L.t("update.check.failed.title"), message: L.t("update.check.failed"),
               actions: [.init(title: L.t("update.check.openWebsite")) { NSWorkspace.shared.open(URL(string: "https://gordas.dev/")!) }],
               dismiss: .init(title: L.t("update.dismiss")) { updateChecker.dismissCheckFailedBanner() })
    }
}

struct UpdateBanner: View {
    let update: UpdateInfo
    @ObservedObject private var updateChecker = UpdateChecker.shared

    var body: some View {
        Banner(kind: .info, title: L.t("update.title"),
               message: "v\(update.version)" + (update.changes.map { " — \($0)" } ?? ""),
               actions: update.download_url.isEmpty ? [] : [.init(title: L.t("update.download"), isPrimary: true) {
                   Task { await SelfUpdater.downloadAndInstall(info: update) }
               }],
               dismiss: .init(title: L.t("update.dismiss")) { updateChecker.dismiss() })
    }
}

/// Banner de avertisment pentru dependinte de sistem lipsa (ex. DaVinci
/// Resolve neinstalat) — vezi SystemDependencyChecker. Status complet
/// (toate dependintele, nu doar cele lipsa) e in Preferences.
struct DependencyBanner: View {
    let missing: [SystemDependency]

    var body: some View {
        Banner(kind: .warning, title: L.t("dependency.missing.title"),
               message: missing.map(\.name).joined(separator: ", "),
               actions: missing.enumerated().compactMap { index, dep in
                   dep.downloadURL.map { url in
                       .init(title: String(format: L.t("dependency.install.button"), dep.name), isPrimary: index == 0) {
                           NSWorkspace.shared.open(url)
                       }
                   }
               })
    }
}

/// [ÎNLOCUIT 2026-09-11] `PriceFilter`/`OSFilter` traiau aici si erau
/// copiate, cu propriul `@State` si propriile `Picker`-e, in fiecare
/// sectiune. Au fost unificate in `CatalogFilterBar.swift`
/// (`AccessPriceFilter`/`AccessOSFilter`/`CatalogFilterState`), care
/// filtreaza pe `ResolvedAccess` — deci regula „ce inseamna gratuit" e
/// aplicata o singura data, in Core, nu reinterpretata per sectiune.

/// Catalogul afișat e cel din cache: ultima reîmprospătare a eșuat din cauza rețelei.
/// „Reîncearcă” face exact ce face butonul de reîmprospătare din bara de unelte.
struct OfflineBanner: View {
    @ObservedObject private var catalog = CatalogService.shared
    let onDismiss: () -> Void

    var body: some View {
        Banner(kind: .offline, title: L.t("offline.banner.title"), message: L.t("offline.banner.body"),
               actions: [.init(title: L.t("card.retry")) { Task { await catalog.refresh() } }],
               dismiss: .init(title: L.t("update.dismiss"), perform: onDismiss))
    }
}
