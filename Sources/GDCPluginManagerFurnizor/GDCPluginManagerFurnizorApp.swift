import SwiftUI
import GDCPluginManagerCore

@main
struct GDCPluginManagerFurnizorApp: App {
    /// Mod fără fereastră, cerut de GDC STYLE Lab: publică direct pachetele Demo din căsuța de intrare, scrie rezultatul și iese.
    init() {
        // 1.52.5: înaintea oricărei operații (inclusiv modul fără fereastră): producția după staging
        // pornește cu scrierile blocate până la confirmarea explicită.
        FurnizorEnvironment.bootstrapSession()
        if CommandLine.arguments.contains("--publish-demo-inbox") {
            DemoPublisher.run()
            exit(0)
        }
    }

    var body: some Scene {
        WindowGroup {
            VStack(spacing: 0) {
                // 1.52.4: banner permanent în staging (frate în VStack, nu suprapus — Regula 24).
                EnvironmentBanner()
                FurnizorContentView()
            }
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
