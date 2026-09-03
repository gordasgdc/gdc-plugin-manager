import SwiftUI
import AppKit
import GDCPluginManagerCore

/// [2026-09-03] Fișa clientului — Faza 1 din planul de CRM. Deschisă din
/// SalesHistoryView (rândul unei achiziții, sau lista de clienți). Arată
/// TOT ce știm despre un client în UN singur loc: istoric complet de
/// achiziții, dispozitive asociate, descărcări, și note libere — nu mai e
/// nevoie să cauți manual în tabelul de tranzacții + panoul de Statistici
/// separat, ca înainte.
struct ClientDetailView: View {
    let profile: ClientProfile
    var onClose: () -> Void

    @State private var notes: String = ""
    @State private var justCopied: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    statsRow
                    if !profile.purchases.isEmpty { purchaseHistorySection }
                    if !profile.devices.isEmpty || !profile.allMachineIDs.isEmpty { devicesSection }
                    if !profile.downloads.isEmpty { downloadsSection }
                    notesSection
                }
                .padding(20)
            }
        }
        .frame(width: 620, height: 620)
        .onAppear { notes = ClientNotesStore.note(for: profile.key) }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(profile.displayName).font(.title2).fontWeight(.semibold)
                if !profile.email.isEmpty {
                    Text(profile.email).font(.callout).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if profile.hasActiveLicense {
                Label("Licență activă", systemImage: "checkmark.seal.fill")
                    .font(.caption).foregroundStyle(.green)
            }
            Button("Închide") { onClose() }
        }
        .padding(20)
    }

    private var statsRow: some View {
        HStack(spacing: 0) {
            statTile(title: "Total achitat", value: profile.totalSpentEUR.formatted(.currency(code: "EUR")))
            Divider().frame(height: 34)
            statTile(title: "Licențe", value: "\(profile.licenseCount)")
            Divider().frame(height: 34)
            statTile(title: "Dispozitive", value: "\(profile.deviceCount > 0 ? profile.deviceCount : profile.allMachineIDs.count)")
            Divider().frame(height: 34)
            statTile(title: "Descărcări", value: "\(profile.downloadCount)")
        }
        .padding(.vertical, 12)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }

    private func statTile(title: String, value: String) -> some View {
        VStack(spacing: 3) {
            Text(value).font(.title3).fontWeight(.semibold)
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var purchaseHistorySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Istoric achiziții (\(profile.purchases.count))").font(.headline)
            Table(profile.purchases) {
                TableColumn("Dată") { p in Text(shortDate(p.dateUTC)) }.width(90)
                TableColumn("Produs") { p in Text(p.productName) }
                TableColumn("Preț") { p in Text(p.priceDisplay) }.width(80)
                TableColumn("Expiră") { p in Text(p.expiresDisplay) }.width(110)
                TableColumn("Cod") { p in
                    Button(justCopied == p.serial ? "Copiat" : "Copiază") {
                        copyToClipboard(p.serial, key: p.serial)
                    }
                    .controlSize(.small)
                }.width(70)
            }
            .frame(height: min(CGFloat(profile.purchases.count), 6) * 28 + 30)
        }
    }

    private var devicesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Dispozitive (\(max(profile.deviceCount, profile.allMachineIDs.count)))").font(.headline)
            ForEach(profile.allMachineIDs, id: \.self) { mid in
                HStack {
                    Image(systemName: "desktopcomputer").foregroundStyle(.secondary)
                    Text(mid).font(.system(.callout, design: .monospaced))
                    Spacer()
                    if let device = profile.devices.first(where: { $0.machine_id == mid }) {
                        Text("din \(shortDate(device.first_seen_at))").font(.caption).foregroundStyle(.tertiary)
                    }
                    Button(justCopied == mid ? "Copiat" : "Copiază") {
                        copyToClipboard(mid, key: mid)
                    }
                    .controlSize(.small)
                }
            }
        }
    }

    private var downloadsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Descărcări recente (\(profile.downloads.count))").font(.headline)
            ForEach(profile.downloads.prefix(20)) { event in
                HStack {
                    Text(event.product_name)
                    Spacer()
                    Text(shortDate(event.downloaded_at)).font(.caption).foregroundStyle(.secondary)
                }
                .font(.callout)
            }
            if profile.downloads.count > 20 {
                Text("+ \(profile.downloads.count - 20) mai vechi").font(.caption).foregroundStyle(.tertiary)
            }
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Note").font(.headline)
            TextEditor(text: $notes)
                .frame(height: 90)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3)))
                .onChange(of: notes) { _, newValue in
                    ClientNotesStore.setNote(newValue, for: profile.key)
                }
        }
    }

    private func copyToClipboard(_ value: String, key: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(value, forType: .string)
        justCopied = key
    }

    private func shortDate(_ raw: String) -> String {
        guard raw.count >= 10 else { return raw }
        return String(raw.prefix(10))
    }
}
