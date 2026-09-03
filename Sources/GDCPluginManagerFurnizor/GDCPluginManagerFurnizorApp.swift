import SwiftUI
import GDCPluginManagerCore

@main
struct GDCPluginManagerFurnizorApp: App {
    var body: some Scene {
        WindowGroup {
            FurnizorContentView()
                .frame(minWidth: 720, minHeight: 560)
                // Tema salvată se aplică din primul cadru — vezi
                // AppTheme.swift (Core) și comentariul din Client.
                .onAppear { ThemeManager.shared.applyNow() }
        }
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(replacing: .appInfo) {}
            // [NOU 2026-09-03] Primul meniu Ajutor al Furnizorului — pana
            // acum n-avea niciunul, doar TokenRenewalGuideView (in-app,
            // scoped la un singur flux). Vezi FurnizorGuidePDF.swift.
            CommandGroup(replacing: .help) {
                ForEach(FurnizorGuidePDF.allCases, id: \.self) { guide in
                    Button(guide.menuTitle) { guide.open() }
                }
            }
        }

        // Settings scene = "GDC Plugin Manager Furnizor -> Preferences..."
        // + Cmd+, automat, nativ. Furnizorul nu avea până acum niciun ecran
        // de setări — adăugat pentru selectorul de temă (Regula 18).
        Settings {
            FurnizorPreferencesView()
        }
    }
}
