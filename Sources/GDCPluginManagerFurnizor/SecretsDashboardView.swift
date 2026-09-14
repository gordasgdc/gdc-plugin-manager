import SwiftUI

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
    @State private var expanded: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(registry.secrets) { secret in
                        row(for: secret)
                        Divider()
                    }
                }
            }
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
            VStack(alignment: .leading, spacing: 4) {
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
    private func row(for secret: ManagedSecret) -> some View {
        let status = registry.status(for: secret)
        let isOpen = expanded.contains(secret.id)

        VStack(alignment: .leading, spacing: 0) {
            Button {
                if isOpen { expanded.remove(secret.id) } else { expanded.insert(secret.id) }
            } label: {
                HStack(spacing: 12) {
                    statusPill(status.severity)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(secret.name).font(.headline)
                        Text(status.headline)
                            .font(.subheadline)
                            .foregroundStyle(color(for: status.severity))
                    }
                    Spacer()
                    if status.mirrorReport.contains(where: { $0.inSync == false }) {
                        Label("oglindă desincronizată", systemImage: "arrow.triangle.branch")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    Image(systemName: isOpen ? "chevron.down" : "chevron.right")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isOpen { detail(for: secret, status: status) }
        }
    }

    @ViewBuilder
    private func detail(for secret: ManagedSecret, status: SecretStatus) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            labeled("La ce folosește", secret.purpose)

            // Impactul stă într-o casetă proprie: e singura informație de
            // care ai nevoie ca să decizi dacă te oprești din ce faci acum.
            VStack(alignment: .leading, spacing: 4) {
                Label("Dacă expiră", systemImage: "exclamationmark.triangle")
                    .font(.caption).fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Text(secret.impact).font(.callout).fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.orange.opacity(0.10)))

            labeled("Unde e stocat", secret.location.humanDescription, monospaced: true)

            if let detail = status.detail {
                labeled("Stare", detail)
            }

            if !status.mirrorReport.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Trebuie să fie aceeași valoare și în:")
                        .font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
                    ForEach(status.mirrorReport) { check in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: check.inSync == true ? "checkmark.circle.fill"
                                            : check.inSync == false ? "xmark.circle.fill" : "questionmark.circle")
                                .foregroundStyle(check.inSync == true ? Color.green
                                               : check.inSync == false ? Color.red : Color.secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(check.label).font(.callout)
                                Text(check.note).font(.caption).foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }

            if !secret.requiredScopes.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Permisiuni necesare la generare")
                        .font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
                    ForEach(secret.requiredScopes, id: \.self) { scope in
                        Label(scope, systemImage: "checkmark.square").font(.caption)
                    }
                }
            }

            if !secret.afterRenewal.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("După înlocuire")
                        .font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
                    ForEach(Array(secret.afterRenewal.enumerated()), id: \.offset) { index, step in
                        Label("\(index + 1). \(step)", systemImage: "arrow.turn.down.right")
                            .font(.caption)
                            .labelStyle(.titleOnly)
                    }
                }
            }

            if let url = secret.renewURL {
                Link(destination: url) {
                    Label("Deschide pagina de reînnoire", systemImage: "arrow.up.right.square")
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
