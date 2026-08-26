import SwiftUI

/// Bloc "Profil Utilizator" în sidebar-ul din stânga (vezi CLAUDE.md,
/// Partea 1, Regula 12) — arată Nume (sau „Anonim"), Email și Machine ID
/// (HWID), și permite editarea rapidă a numelui/emailului opțional.
/// Telemetria rămâne strict opțională: câmpurile pot rămâne goale
/// oricând, aplicația funcționează identic.
struct ProfileSidebarBlock: View {
    @ObservedObject private var profile = UserProfileStore.shared
    @State private var showEditor = false
    @State private var editName = ""
    @State private var editEmail = ""
    @State private var justCopiedID = false

    var body: some View {
        // Marit 2026-08-26 (cerut explicit: zona era "miniaturizata, greu de
        // citit") - caption/caption2/caption2 -> subheadline/footnote/caption,
        // plus spatiere verticala marita (2 -> 4) si padding propriu, ca
        // blocul sa respire fata de restul sidebar-ului.
        Button { showEditor = true } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "person.circle")
                        .foregroundStyle(.secondary)
                    Text(profile.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                if !profile.email.trimmingCharacters(in: .whitespaces).isEmpty {
                    Text(profile.email)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Text(profile.machineID)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showEditor) {
            VStack(alignment: .leading, spacing: 10) {
                Text(L.t("profile.editor.title")).font(.headline)
                TextField(L.t("onboarding.name"), text: $editName).textFieldStyle(.roundedBorder)
                TextField(L.t("onboarding.email"), text: $editEmail).textFieldStyle(.roundedBorder)
                HStack {
                    Text(L.t("license.machineID.title"))
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button(justCopiedID ? L.t("license.machineID.copied") : L.t("license.machineID.copy")) {
                        let pb = NSPasteboard.general
                        pb.clearContents()
                        pb.setString(profile.machineID, forType: .string)
                        justCopiedID = true
                    }
                    .controlSize(.small)
                }
                Text(profile.machineID)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                HStack {
                    Spacer()
                    Button(L.t("common.ok")) {
                        profile.save(name: editName, email: editEmail, sendTelemetry: true)
                        showEditor = false
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(16)
            .frame(width: 300)
            .onAppear {
                editName = profile.name
                editEmail = profile.email
            }
        }
    }
}
