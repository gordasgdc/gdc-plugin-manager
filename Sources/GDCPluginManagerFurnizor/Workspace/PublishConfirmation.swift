import SwiftUI
import GDCPluginManagerCore

/// Poarta de publicare (Faza 5): în spațiul de lucru, orice „Publică/Actualizează” trece întâi prin
/// foaia de confirmare. În afara lui (valoarea implicită) acțiunea rulează direct, ca înainte.
/// Nu înlocuiește nimic din siguranța existentă: blocarea scrierilor după o sesiune STAGING,
/// tranzacțiile multi-repo și jurnalul „Reia / Curăță” rămân exact cum sunt.
struct PublishGate {
    let request: (_ title: String, _ action: @escaping @MainActor () async -> Void) -> Void
}

private struct PublishGateKey: EnvironmentKey {
    static let defaultValue = PublishGate { _, action in Task { await action() } }
}

extension EnvironmentValues {
    var publishGate: PublishGate {
        get { self[PublishGateKey.self] }
        set { self[PublishGateKey.self] = newValue }
    }
}

/// O cerere de publicare în așteptarea confirmării.
struct PendingPublish: Identifiable {
    let id = UUID()
    let title: String
    let action: @MainActor () async -> Void
}

struct PublishConfirmationSheet: View {
    let pending: PendingPublish
    let onDone: () -> Void

    @State private var confirmed = false
    private var isProduction: Bool { FurnizorEnvironment.active == .production }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: GDCTokens.Space.s) {
                StatusPill(text: isProduction ? "PRODUCȚIE" : "STAGING",
                           color: isProduction ? GDCTokens.Palette.destructive : GDCTokens.Palette.info)
                Text("Publică „\(pending.title.isEmpty ? "intrarea curentă" : pending.title)”")
                    .font(GDCTokens.Typography.sectionTitle)
                    .lineLimit(2)
            }
            .padding(GDCTokens.Space.l)

            VStack(alignment: .leading, spacing: GDCTokens.Space.s) {
                step("1", "Formular validat (câmpurile obligatorii sunt completate)", done: true)
                step("2", isProduction ? "Mediu: PRODUCȚIE — clienții văd modificarea în câteva minute"
                                       : "Mediu: STAGING — repo-uri de test, clienții nu văd nimic", done: true)
                step("3", "Publicare prin tranzacția existentă (catalog + fișiere); la eșec: jurnalul „Reia / Curăță”", done: false)
                if isProduction {
                    Toggle("Am verificat conținutul și vreau să-l public către clienți", isOn: $confirmed)
                        .toggleStyle(.checkbox)
                        .padding(.top, GDCTokens.Space.xs)
                }
            }
            .padding(.horizontal, GDCTokens.Space.l)
            .padding(.bottom, GDCTokens.Space.l)

            Divider()
            HStack(spacing: GDCTokens.Space.s) {
                Spacer()
                Button("Anulează", role: .cancel, action: onDone)
                    .keyboardShortcut(.cancelAction)
                    .buttonStyle(GDCButtonStyle(role: .secondary))
                Button(isProduction ? "Publică în producție" : "Publică în staging") {
                    let action = pending.action
                    onDone()
                    Task { await action() }
                }
                .buttonStyle(GDCButtonStyle(role: .primary))
                .disabled(isProduction && !confirmed)
                .keyboardShortcut(.defaultAction)
            }
            .padding(GDCTokens.Space.m)
        }
        .frame(width: 520)
        .background(GDCTokens.Palette.surface)
    }

    private func step(_ n: String, _ text: String, done: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: GDCTokens.Space.s) {
            StatusPill(text: n, color: done ? GDCTokens.Palette.success : GDCTokens.Palette.warning)
            Text(text).font(GDCTokens.Typography.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}
