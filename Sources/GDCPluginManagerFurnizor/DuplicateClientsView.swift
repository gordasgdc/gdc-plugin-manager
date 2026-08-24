import SwiftUI

/// Un grup de intrări din SalesLog care au ACELAȘI ID de mașină, dar nume
/// și/sau email diferite — semn de dublură/typo la introducere manuală
/// (cerut explicit 2026-08-24: "unifică intrările pe un singur profil de
/// client corect"). Grupăm strict după `machineID` (nu după nume — numele
/// e chiar ce vrem să corectăm, deci nu poate fi și cheia de grupare).
private struct DuplicateGroup: Identifiable {
    let machineID: String
    let entries: [SalesLog.Entry]
    var id: String { machineID }

    /// Variantele distincte de (nume, email) văzute pentru acest ID de
    /// mașină, în ordinea primei apariții — case-insensitive și fără
    /// spații la capete, ca "Ion Popescu" și " ion popescu" să conteze ca
    /// aceeași variantă, nu ca două typo-uri diferite.
    var variants: [(name: String, email: String)] {
        var seen = Set<String>()
        var result: [(name: String, email: String)] = []
        for entry in entries {
            let key = entry.customer.lowercased() + "|" + entry.email.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            result.append((entry.customer, entry.email))
        }
        return result
    }
}

/// Sheet de curățare: grupează toate vânzările cu ID de mașină duplicat
/// (nume/email diferite pe același ID) și lasă Cristi să aleagă, per grup,
/// care variantă e cea corectă — apoi rescrie DOAR câmpurile client/email
/// ale rândurilor din acel grup (data, produsul, prețul, seria rămân
/// neatinse — vezi SalesLog.update, e o corectare de bookkeeping, nu o
/// ștergere/regenerare de coduri).
struct DuplicateClientsView: View {
    let onApplied: () -> Void
    let onClose: () -> Void

    @State private var groups: [DuplicateGroup] = []
    @State private var choices: [String: Int] = [:] // machineID -> index in variants
    @State private var customNameByGroup: [String: String] = [:]
    @State private var customEmailByGroup: [String: String] = [:]
    @State private var isApplying = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Clienți duplicați").font(.title2).fontWeight(.semibold)
                Spacer()
                Button("Închide") { onClose() }
            }
            .padding(20)

            if groups.isEmpty {
                Text("Niciun duplicat găsit — fiecare ID de mașină are un singur nume/email asociat.")
                    .foregroundStyle(.secondary)
                    .padding(20)
            } else {
                Text("Găsite \(groups.count) ID-uri de mașină cu mai multe nume/email-uri asociate. Alege varianta corectă pentru fiecare — se aplică pe TOATE vânzările cu acel ID (produsul, prețul și codul rămân neschimbate).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)

                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red).font(.caption).padding(.horizontal, 20)
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(groups) { group in
                            groupCard(group)
                        }
                    }
                    .padding(20)
                }
            }
        }
        .frame(width: 620, height: 560)
        .task { loadGroups() }
    }

    @ViewBuilder
    private func groupCard(_ group: DuplicateGroup) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                Text(group.machineID)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)

                Picker("Variantă corectă", selection: Binding(
                    get: { choices[group.machineID] ?? 0 },
                    set: { choices[group.machineID] = $0 }
                )) {
                    ForEach(Array(group.variants.enumerated()), id: \.offset) { index, variant in
                        Text("\(variant.name)" + (variant.email.isEmpty ? "" : " — \(variant.email)") + " (\(count(of: variant, in: group)) vânzări)")
                            .tag(index)
                    }
                    Text("Altceva (scrie manual mai jos)").tag(-1)
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()

                if (choices[group.machineID] ?? 0) == -1 {
                    TextField("Nume corect", text: Binding(
                        get: { customNameByGroup[group.machineID] ?? "" },
                        set: { customNameByGroup[group.machineID] = $0 }
                    )).textFieldStyle(.roundedBorder)
                    TextField("Email corect", text: Binding(
                        get: { customEmailByGroup[group.machineID] ?? "" },
                        set: { customEmailByGroup[group.machineID] = $0 }
                    )).textFieldStyle(.roundedBorder)
                }

                HStack {
                    Spacer()
                    Button("Unifică (\(group.entries.count) rânduri)") {
                        apply(group)
                    }
                    .disabled(isApplying)
                }
            }
            .padding(6)
        }
    }

    private func count(of variant: (name: String, email: String), in group: DuplicateGroup) -> Int {
        group.entries.filter {
            $0.customer.lowercased() == variant.name.lowercased() && $0.email.lowercased() == variant.email.lowercased()
        }.count
    }

    private func loadGroups() {
        let all = SalesLog.readAll()
        let byMachineID = Dictionary(grouping: all.filter { !$0.machineID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            $0.machineID.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        groups = byMachineID.compactMap { machineID, entries in
            let group = DuplicateGroup(machineID: machineID, entries: entries)
            // Doar grupurile cu REALMENTE mai multe variante distincte —
            // același client, aceeași scriere, pe mai multe vânzări = normal,
            // NU un duplicat de corectat.
            guard group.variants.count > 1 else { return nil }
            return group
        }
        .sorted { $0.machineID < $1.machineID }
    }

    private func apply(_ group: DuplicateGroup) {
        errorMessage = nil
        let chosenIndex = choices[group.machineID] ?? 0
        let canonicalName: String
        let canonicalEmail: String
        if chosenIndex == -1 {
            canonicalName = (customNameByGroup[group.machineID] ?? "").trimmingCharacters(in: .whitespaces)
            canonicalEmail = (customEmailByGroup[group.machineID] ?? "").trimmingCharacters(in: .whitespaces)
            guard !canonicalName.isEmpty else {
                errorMessage = "Completează numele corect pentru \(group.machineID)."
                return
            }
        } else {
            let variants = group.variants
            guard chosenIndex >= 0, chosenIndex < variants.count else { return }
            canonicalName = variants[chosenIndex].name
            canonicalEmail = variants[chosenIndex].email
        }

        isApplying = true
        do {
            for entry in group.entries {
                guard entry.customer != canonicalName || entry.email != canonicalEmail else { continue }
                let updated = SalesLog.Entry(
                    dateUTC: entry.dateUTC, productID: entry.productID, productName: entry.productName,
                    customer: canonicalName, email: canonicalEmail, priceEUR: entry.priceEUR,
                    expiresDisplay: entry.expiresDisplay, machineID: entry.machineID, serial: entry.serial
                )
                try SalesLog.update(serial: entry.serial, with: updated)
            }
            loadGroups()
            onApplied()
        } catch {
            errorMessage = error.localizedDescription
        }
        isApplying = false
    }
}
