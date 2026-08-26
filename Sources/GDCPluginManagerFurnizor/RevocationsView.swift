import SwiftUI

/// Panoul "Revocări licențe" (vezi CLAUDE.md, Partea 1, Regula 12) —
/// permite revocarea instant a unei licențe deja generate/activate
/// (machine_id + product_id), pentru orice aplicație din ecosistem
/// (funcționează pentru orice produs, nu doar cele din catalog — folosește
/// aceleași ID-uri ca `gdcStandaloneProducts` din GenerateSerialView.swift).
struct RevocationsView: View {
    @State private var records: [RevocationRecord] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    @State private var newMachineID = ""
    @State private var newProductID = ""
    @State private var newReason = ""
    @State private var isSubmitting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Revocări licențe").font(.title2).fontWeight(.semibold)
            Text("Revocă instant o licență deja activată (sabotaj, abuz, test expirat) — clientul o pierde la următoarea verificare online. Funcționează fail-open: fără conexiune, licența existentă rămâne activă, nu se blochează niciodată doar din cauza rețelei.")
                .font(.callout)
                .foregroundStyle(.secondary)

            GroupBox("Revocă o licență nouă") {
                VStack(alignment: .leading, spacing: 10) {
                    TextField("Machine ID (din secțiunea Licență a clientului)", text: $newMachineID)
                        .textFieldStyle(.roundedBorder)
                    TextField("ID produs (ex: gdc-vault, cgconvertor, sau id din catalog)", text: $newProductID)
                        .textFieldStyle(.roundedBorder)
                    TextField("Motiv (opțional, doar informativ)", text: $newReason)
                        .textFieldStyle(.roundedBorder)
                    HStack {
                        Spacer()
                        Button("Revocă") { Task { await submitRevocation() } }
                            .buttonStyle(.borderedProminent)
                            .tint(.red)
                            .disabled(isSubmitting || newMachineID.trimmingCharacters(in: .whitespaces).isEmpty || newProductID.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                .padding(.top, 4)
            }

            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red).font(.callout)
            }

            HStack {
                Text("Licențe revocate (\(records.count))").font(.headline)
                Spacer()
                Button("Reîmprospătează") { Task { await load() } }
                if isLoading { ProgressView().controlSize(.small) }
            }

            List(records) { record in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(record.product_id).fontWeight(.medium)
                        Text(record.machine_id).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                        if let reason = record.reason, !reason.isEmpty {
                            Text(reason).font(.caption).foregroundStyle(.secondary)
                        }
                        Text(record.revoked_at).font(.caption2).foregroundStyle(.tertiary)
                    }
                    Spacer()
                    Button("Anulează revocarea") { Task { await unrevoke(record) } }
                        .controlSize(.small)
                }
            }
        }
        .padding(20)
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            records = try await RevocationAdminClient.fetchAll()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func submitRevocation() async {
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await RevocationAdminClient.revoke(machineID: newMachineID, productID: newProductID, reason: newReason)
            newMachineID = ""; newProductID = ""; newReason = ""
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func unrevoke(_ record: RevocationRecord) async {
        do {
            try await RevocationAdminClient.unrevoke(id: record.id)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
