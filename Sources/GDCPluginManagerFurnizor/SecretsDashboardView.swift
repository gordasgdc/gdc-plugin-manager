import SwiftUI
import GDCPluginManagerCore

/// Dashboard-ul tuturor secretelor de care depinde ecosistemul GDC Plugin
/// Manager — vezi `SecretRegistry` pentru inventar și pentru sursa fiecărei
/// date afișate aici.
///
/// Scopul e unul singur: să afli că un secret expiră ÎNAINTE să se rupă
/// ceva, nu după. De aceea fiecare rând spune și ce anume se rupe — sub
/// presiune contează mai mult „clienții nu mai descarcă nimic" decât
/// numele constantei.
struct SecretsDashboardView: View {
    @StateObject private var registry = SecretRegistry.shared
    @State private var selectedSecretID: String?
    @State private var renewing: ManagedSecret?
    @State private var exportedTo: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            // Faza 5 (V1): tabel + detaliile secretului selectat în inspector. Valorile nu se afișează niciodată.
            Table(registry.secrets, selection: $selectedSecretID) {
                TableColumn("Stare") { secret in statusPill(registry.status(for: secret).severity) }
                    .width(min: 70, ideal: 90)
                TableColumn("Secret") { Text($0.name).fontWeight(.medium) }
                    .width(min: 180, ideal: 260)
                TableColumn("Situație") { secret in
                    let status = registry.status(for: secret)
                    Text(status.headline).foregroundStyle(color(for: status.severity))
                }
                .width(min: 140, ideal: 220)
                TableColumn("Expiră") { secret in
                    Text(registry.status(for: secret).expiresAt?.formatted(date: .abbreviated, time: .omitted) ?? "—")
                        .font(GDCTokens.Typography.numeric).foregroundStyle(GDCTokens.Palette.textSecondary)
                }
                .width(min: 80, ideal: 110)
                TableColumn("Oglinzi") { secret in
                    if registry.status(for: secret).mirrorReport.contains(where: { $0.inSync == false }) {
                        Label("desincronizat", systemImage: "arrow.triangle.branch").foregroundStyle(GDCTokens.Palette.warning)
                    } else {
                        Text("—").foregroundStyle(GDCTokens.Palette.textTertiary)
                    }
                }
                .width(min: 90, ideal: 120)
            }
        }
        .inspector(isPresented: .constant(true)) {
            Group {
                if let secret = registry.secrets.first(where: { $0.id == selectedSecretID }) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: GDCTokens.Space.m) {
                            Text(secret.name).font(GDCTokens.Typography.sectionTitle)
                            detail(for: secret, status: registry.status(for: secret))
                        }
                        .padding(GDCTokens.Space.l)
                    }
                } else {
                    Text("Alege un secret din tabel pentru detalii și pașii de reînnoire.")
                        .font(GDCTokens.Typography.secondary).foregroundStyle(GDCTokens.Palette.textSecondary)
                        .multilineTextAlignment(.center).padding(GDCTokens.Space.xl)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .inspectorColumnWidth(min: 380, ideal: 460, max: 720)
        }
        .sheet(item: $renewing) { secret in
            SecretRenewalWizardView(secret: secret)
        }
        .task {
            // Doar prima dată: o reîmprospătare la fiecare intrare în
            // secțiune ar însemna un apel de rețea la fiecare click pe
            // sidebar, fără ca ceva să se fi putut schimba între timp.
            if registry.lastRefresh == nil { await registry.refreshAll() }
        }
    }

    // MARK: Antet

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: GDCTokens.Space.xs) {
                Text("Token-uri & Chei").font(.title2).fontWeight(.semibold)
                Text(summaryLine)
                    .font(.callout)
                    .foregroundStyle(registry.worstSeverity == .ok ? .secondary : Color.primary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                Button {
                    Task { await registry.refreshAll() }
                } label: {
                    if registry.isRefreshing {
                        ProgressView().controlSize(.small)
                    } else {
                        Label("Reverifică tot", systemImage: "arrow.clockwise")
                    }
                }
                .disabled(registry.isRefreshing)

                Button {
                    exportedTo = EmergencyGuidePDF.export(statuses: registry.statuses)
                } label: {
                    Label("Ghid de urgență (PDF)", systemImage: "doc.richtext")
                }
                .help("Toate procedurile manuale, într-un PDF de ținut pe telefon. Nu conține nicio valoare de token.")

                if let exported = exportedTo {
                    Button("Arată ghidul salvat") {
                        NSWorkspace.shared.activateFileViewerSelecting([exported])
                    }
                    .buttonStyle(.link)
                    .font(.caption2)
                }
                if let last = registry.lastRefresh {
                    Text("Verificat \(SecretRegistry.relative(last))")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .padding(20)
    }

    private var summaryLine: String {
        let statuses = registry.secrets.map { registry.status(for: $0).severity }
        let critical = statuses.filter { $0 == .critical }.count
        let missing = statuses.filter { $0 == .missing }.count
        let warning = statuses.filter { $0 == .warning }.count
        var parts: [String] = []
        if critical > 0 { parts.append("\(critical) necesită acțiune acum") }
        if missing > 0 { parts.append("\(missing) lipsesc") }
        if warning > 0 { parts.append("\(warning) de urmărit") }
        let optional = statuses.filter { $0 == .optionalUnset }.count
        if optional > 0 { parts.append("\(optional) opțional neconfigurat") }
        if parts.isEmpty {
            return registry.lastRefresh == nil ? "Se verifică…" : "Toate cele \(registry.secrets.count) sunt în regulă."
        }
        return parts.joined(separator: " · ")
    }

    // MARK: Un rând

    @ViewBuilder
    private func detail(for secret: ManagedSecret, status: SecretStatus) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            labeled("La ce folosește", secret.purpose)

            // Impactul stă într-o casetă proprie: e singura informație de
            // care ai nevoie ca să decizi dacă te oprești din ce faci acum.
            VStack(alignment: .leading, spacing: GDCTokens.Space.xs) {
                Label("Dacă expiră", systemImage: "exclamationmark.triangle")
                    .font(.caption).fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Text(secret.impact).font(.callout).fixedSize(horizontal: false, vertical: true)
            }
            .padding(GDCTokens.Space.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: GDCTokens.Radius.control).fill(GDCTokens.Palette.warning.opacity(0.10)))

            labeled("Unde e stocat", secret.location.humanDescription, monospaced: true)

            if let detail = status.detail {
                labeled("Stare", detail)
            }

            if !status.mirrorReport.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Trebuie să fie aceeași valoare și în:")
                        .font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
                    ForEach(status.mirrorReport) { check in
                        HStack(alignment: .top, spacing: GDCTokens.Space.s) {
                            Image(systemName: check.inSync == true ? "checkmark.circle.fill"
                                            : check.inSync == false ? "xmark.circle.fill" : "questionmark.circle")
                                .foregroundStyle(check.inSync == true ? GDCTokens.Palette.success
                                               : check.inSync == false ? GDCTokens.Palette.error : Color.secondary)
                            VStack(alignment: .leading, spacing: GDCTokens.Space.xxs) {
                                Text(check.label).font(.callout)
                                Text(check.note).font(.caption).foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }

            if !secret.requiredScopes.isEmpty {
                VStack(alignment: .leading, spacing: GDCTokens.Space.xs) {
                    Text("Permisiuni necesare la generare")
                        .font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
                    ForEach(secret.requiredScopes, id: \.self) { scope in
                        Label(scope, systemImage: "checkmark.square").font(.caption)
                    }
                }
            }

            if !secret.afterRenewal.isEmpty {
                VStack(alignment: .leading, spacing: GDCTokens.Space.xs) {
                    Text("După înlocuire")
                        .font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
                    ForEach(Array(secret.afterRenewal.enumerated()), id: \.offset) { index, step in
                        Label("\(index + 1). \(step)", systemImage: "arrow.turn.down.right")
                            .font(.caption)
                            .labelStyle(.titleOnly)
                    }
                }
            }

            HStack(spacing: GDCTokens.Space.m) {
                Button {
                    renewing = secret
                } label: {
                    Label("Reînnoiește pas cu pas", systemImage: "wand.and.stars")
                }
                .buttonStyle(.borderedProminent)

                if let url = secret.renewURL {
                    Link(destination: url) {
                        Label("Deschide pagina de reînnoire", systemImage: "arrow.up.right.square")
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 18)
        .frame(maxWidth: 720, alignment: .leading)
    }

    private func labeled(_ title: String, _ value: String, monospaced: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
            Text(value)
                .font(monospaced ? .system(.caption, design: .monospaced) : .callout)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
    }

    // MARK: Indicatorul vizual

    private func statusPill(_ severity: SecretStatus.Severity) -> some View {
        Circle()
            .fill(color(for: severity))
            .frame(width: 12, height: 12)
            .overlay(Circle().strokeBorder(.black.opacity(0.12)))
            .accessibilityLabel(accessibilityText(severity))
    }

    private func color(for severity: SecretStatus.Severity) -> Color {
        switch severity {
        case .ok: return .green
        case .optionalUnset: return .secondary
        case .warning: return .orange
        case .critical, .missing: return .red
        case .unknown: return .secondary
        }
    }

    private func accessibilityText(_ severity: SecretStatus.Severity) -> String {
        switch severity {
        case .ok: return "în regulă"
        case .optionalUnset: return "opțional, neconfigurat"
        case .warning: return "expiră curând"
        case .critical: return "necesită acțiune"
        case .missing: return "lipsește"
        case .unknown: return "necunoscut"
        }
    }
}
