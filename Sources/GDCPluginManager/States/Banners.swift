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
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            Text(L.t("update.check.failed"))
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button(L.t("update.check.openWebsite")) {
                NSWorkspace.shared.open(URL(string: "https://gordas.dev/")!)
            }
            Button(L.t("update.dismiss")) { updateChecker.dismissCheckFailedBanner() }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color.orange.opacity(0.10))
    }
}

struct UpdateBanner: View {
    let update: UpdateInfo
    @ObservedObject private var updateChecker = UpdateChecker.shared

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.down.circle.fill").foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(L.t("update.title")).font(.subheadline).fontWeight(.semibold)
                Text("v\(update.version)" + (update.changes.map { " — \($0)" } ?? ""))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            // Nu mai deschide browserul — vezi SelfUpdater.swift.
            if !update.download_url.isEmpty {
                Button(L.t("update.download")) {
                    Task { await SelfUpdater.downloadAndInstall(info: update) }
                }
            }
            Button(L.t("update.dismiss")) { updateChecker.dismiss() }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color.accentColor.opacity(0.12))
    }
}

/// Banner de avertisment pentru dependinte de sistem lipsa (ex. DaVinci
/// Resolve neinstalat) — vezi SystemDependencyChecker. Status complet
/// (toate dependintele, nu doar cele lipsa) e in Preferences.
struct DependencyBanner: View {
    let missing: [SystemDependency]

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(L.t("dependency.missing.title")).font(.subheadline).fontWeight(.semibold)
                Text(missing.map(\.name).joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            ForEach(missing) { dep in
                if let url = dep.downloadURL {
                    Button(String(format: L.t("dependency.install.button"), dep.name)) { NSWorkspace.shared.open(url) }
                }
            }
        }
        .padding(12)
        .background(Color.orange.opacity(0.12))
    }
}

/// [ÎNLOCUIT 2026-09-11] `PriceFilter`/`OSFilter` traiau aici si erau
/// copiate, cu propriul `@State` si propriile `Picker`-e, in fiecare
/// sectiune. Au fost unificate in `CatalogFilterBar.swift`
/// (`AccessPriceFilter`/`AccessOSFilter`/`CatalogFilterState`), care
/// filtreaza pe `ResolvedAccess` — deci regula „ce inseamna gratuit" e
/// aplicata o singura data, in Core, nu reinterpretata per sectiune.
