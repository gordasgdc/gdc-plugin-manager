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
        .commands { CommandGroup(replacing: .appInfo) {} }

        // Settings scene = "GDC Plugin Manager Furnizor -> Preferences..."
        // + Cmd+, automat, nativ. Furnizorul nu avea până acum niciun ecran
        // de setări — adăugat pentru selectorul de temă (Regula 18).
        Settings {
            FurnizorPreferencesView()
        }
    }
}
