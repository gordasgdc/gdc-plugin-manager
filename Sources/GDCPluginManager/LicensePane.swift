import SwiftUI
import AppKit

/// The License destination in the main sidebar — same content/shape as
/// CursorPro GDC's LicensePane, adapted from a Preferences-window pane
/// to a plain sidebar destination since this app is a normal windowed
/// app (Dock icon, no menu-bar-accessory mode), not a background utility.
struct LicensePane: View {
    @ObservedObject private var license = LicenseManager.shared
    @State private var codeField = ""
    @State private var justActivated = false
    @State private var justCopiedMachineID = false

    private static let machineID = MachineID.display

    private static var whatsAppURL: URL {
        let text = "Salut! Vreau să cumpăr GDC Plugin Manager (acces pe viață). ID calculator: \(machineID)"
        return URL(string: "https://wa.me/34643109970?text=" + text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)!
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(L.t("license.pane.title")).font(.title2).fontWeight(.semibold)

                statusCard

                if !license.isLicensed {
                    machineIDCard
                    activationCard
                    buyCard
                } else {
                    Button(L.t("license.deactivate"), role: .destructive) { license.deactivate() }
                }
                Spacer(minLength: 0)
            }
            .padding(24)
            .frame(maxWidth: 520, alignment: .leading)
        }
    }

    private var statusCard: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: license.isLicensed ? "checkmark.seal.fill" : (license.isTrialActive ? "clock.fill" : "exclamationmark.triangle.fill"))
                .font(.system(size: 28))
                .foregroundStyle(license.isLicensed ? .green : (license.isTrialActive ? .orange : .red))
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 4) {
                Text(statusTitle).font(.headline)
                Text(statusBody)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(nsColor: .separatorColor), lineWidth: 1))
    }

    private var statusTitle: String {
        if license.isLicensed { return L.t("license.status.licensed") }
        if license.isTrialActive { return L.t("license.status.trial") }
        return L.t("license.status.expired")
    }

    private var statusBody: String {
        if license.isLicensed { return L.t("license.status.licensed.body") }
        if license.isTrialActive {
            let days = license.trialDaysRemaining
            return days <= 1 ? L.t("license.status.trial.lastDay") : String(format: L.t("license.status.trial.daysLeft"), days)
        }
        return L.t("license.status.expired.body")
    }

    private var machineIDCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L.t("license.machineID.title")).font(.headline)
            Text(L.t("license.machineID.body"))
                .font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                Text(Self.machineID)
                    .font(.system(.body, design: .monospaced))
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .textBackgroundColor)))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(nsColor: .separatorColor), lineWidth: 1))
                Button(justCopiedMachineID ? L.t("license.machineID.copied") : L.t("license.machineID.copy")) {
                    let pb = NSPasteboard.general
                    pb.clearContents()
                    pb.setString(Self.machineID, forType: .string)
                    justCopiedMachineID = true
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(nsColor: .separatorColor), lineWidth: 1))
    }

    private var activationCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField(L.t("license.field.placeholder"), text: $codeField)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))

            if let error = license.activationError {
                Text(error).font(.callout).foregroundStyle(.red)
            }
            if justActivated {
                Label(L.t("license.activated.success"), systemImage: "checkmark.circle.fill")
                    .font(.callout).foregroundStyle(.green)
            }

            Button(L.t("license.activate")) {
                justActivated = license.activate(code: codeField)
                if justActivated { codeField = "" }
            }
            .disabled(codeField.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(nsColor: .separatorColor), lineWidth: 1))
    }

    private var buyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L.t("license.buy.title")).font(.headline)
            Text(L.t("license.buy.price")).font(.callout).foregroundStyle(.secondary)
            Button(L.t("license.buy.button")) { NSWorkspace.shared.open(Self.whatsAppURL) }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(nsColor: .separatorColor), lineWidth: 1))
    }
}
