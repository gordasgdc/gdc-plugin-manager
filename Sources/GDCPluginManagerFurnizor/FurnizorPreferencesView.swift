import SwiftUI
import GDCPluginManagerCore

/// Fereastra nativă de Preferences a Furnizorului (Cmd+,) — NU exista
/// deloc până acum: Furnizorul nu avea niciun ecran de setări.
///
/// Adăugată 2026-08-29 pentru Regula 18 (Partea 1, CLAUDE.md): selectorul
/// explicit de temă Sistem/Light/Dark e obligatoriu pe TOATE aplicațiile
/// desktop GDC, iar Furnizorul nu e scutit doar pentru că e un instrument
/// intern (același raționament ca la Regula 15 despre versiunea în UI).
struct FurnizorPreferencesView: View {
    @ObservedObject private var theme = ThemeManager.shared

    private var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    var body: some View {
        Form {
            Section("Temă") {
                Picker("", selection: Binding(get: { theme.current }, set: { theme.set($0) })) {
                    ForEach(AppTheme.allCases) { option in
                        Text(option.label).tag(option)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                Text("Se aplică imediat, fără repornire. Independent de tema macOS.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Despre") {
                HStack {
                    Text("Versiune")
                    Spacer()
                    Text("v\(currentVersion)").foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 230)
    }
}
