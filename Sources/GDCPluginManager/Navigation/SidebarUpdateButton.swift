import SwiftUI
import AppKit
import GDCPluginManagerCore

/// Etichetă compactă tip "pill" — GRATUIT (verde) / LICENȚĂ (portocaliu) /
/// PROBĂ (albastru). Un fundal plin + text alb, nu doar text colorat, ca
/// sa citeasca clar ca un badge, nu ca o simpla nota de pret.
/// Ceas live opțional pentru conținut cu ofertă cu termen (2026-08-31,
/// cerut explicit de Cristi - vezi `Scheduling.showCountdown`/`countdownText`).
/// Nu arată nimic dacă nu se aplică (countdown dezactivat de Furnizor, fără
/// termen, sau expirat) - `Group` gol nu ocupă spațiu în layout.
/// Se auto-actualizează la 60s - suficient pentru "live" fără cost UI de
/// a reface un `Text` in fiecare card la fiecare secundă.
/// Buton vizibil în sidebar, lângă versiune: „Caută actualizări” când nu e
/// nimic nou, ecuson verde „Actualizare disponibilă vX” când există — la
/// apăsare pornește direct Self-Updater-ul (fără meniul din bara de sus).
struct SidebarUpdateButton: View {
    @ObservedObject private var updateChecker = UpdateChecker.shared
    @State private var isChecking = false

    var body: some View {
        if let info = updateChecker.availableUpdate, !info.download_url.isEmpty {
            Button {
                Task { await SelfUpdater.downloadAndInstall(info: info) }
            } label: {
                Label("\(L.t("update.popup.title")) v\(info.version)", systemImage: "arrow.down.circle.fill")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .foregroundStyle(.white)
                    .padding(.horizontal, GDCTokens.Space.s).padding(.vertical, 3)
                    .background(Capsule().fill(GDCTokens.Palette.success))
            }
            .buttonStyle(.plain)
            .help(L.t("update.popup.now"))
        } else {
            Button {
                isChecking = true
                NotificationCenter.default.post(name: .gdcCheckForUpdatesRequested, object: nil)
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { isChecking = false }
            } label: {
                if isChecking {
                    ProgressView().controlSize(.mini)
                } else {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 11, weight: .semibold))
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help(L.t("menu.checkForUpdates"))
        }
    }
}
