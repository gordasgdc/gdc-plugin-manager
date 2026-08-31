import SwiftUI
import GDCPluginManagerCore

/// Selector reutilizabil de valabilitate temporală (From-To) — Etapa 4
/// (2026-08-29). Folosit de Cursuri/Materiale/Evenimente/Oferte Parteneri.
/// Un toggle activează/dezactivează scheduling-ul complet — implicit OFF,
/// ca orice conținut nou să rămână "mereu vizibil" fără pas suplimentar.
struct SchedulingPicker: View {
    @Binding var scheduling: Scheduling?

    @State private var isEnabled: Bool
    @State private var startDate: Date
    @State private var endDate: Date
    // 2026-08-31 - ceas live opțional, cerut explicit ("să apară ca un
    // ceas cât timp mai este până dispare") - vezi Scheduling.showCountdown.
    @State private var showCountdown: Bool

    init(scheduling: Binding<Scheduling?>) {
        _scheduling = scheduling
        let current = scheduling.wrappedValue
        _isEnabled = State(initialValue: current != nil)
        _startDate = State(initialValue: current?.startDate ?? Date())
        _endDate = State(initialValue: current?.endDate ?? Date().addingTimeInterval(7 * 86400))
        _showCountdown = State(initialValue: current?.showCountdown ?? false)
    }

    private func push() {
        scheduling = Scheduling(startDate: startDate, endDate: endDate, showCountdown: showCountdown)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Valabilitate temporală (apare/dispare automat)", isOn: $isEnabled)
                .onChange(of: isEnabled) { _, enabled in
                    scheduling = enabled ? Scheduling(startDate: startDate, endDate: endDate, showCountdown: showCountdown) : nil
                }
            if isEnabled {
                DatePicker("Apare din:", selection: $startDate)
                    .onChange(of: startDate) { _, _ in push() }
                DatePicker("Dispare din:", selection: $endDate)
                    .onChange(of: endDate) { _, _ in push() }
                Toggle("Arată countdown live la clienți (opțional)", isOn: $showCountdown)
                    .onChange(of: showCountdown) { _, _ in push() }
                Text(showCountdown
                     ? "Clienții vor vedea „Mai sunt Xz Yh” lângă acest conținut, cât timp e activ — util pentru oferte cu termen (Black Friday etc.)."
                     : "Conținutul va apărea automat la clienți doar în acest interval — nu e nevoie să-l publici/ștergi manual la fiecare capăt.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
