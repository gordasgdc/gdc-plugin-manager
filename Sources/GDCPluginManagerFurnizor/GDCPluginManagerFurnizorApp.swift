import SwiftUI
import GDCPluginManagerCore

@main
struct GDCPluginManagerFurnizorApp: App {
    /// Mod fără fereastră, cerut de GDC STYLE Lab: publică direct pachetele Demo din căsuța de intrare, scrie rezultatul și iese.
    init() {
        if CommandLine.arguments.contains("--publish-demo-inbox") {
            DemoPublisher.run()
            exit(0)
        }
    }

    var body: some Scene {
        WindowGroup {
            VStack(spacing: 0) {
                // 1.52.4: banner permanent în staging (frate în VStack, nu suprapus — Regula 24).
                if FurnizorEnvironment.active == .staging {
                    Text("MEDIU DE TEST — STAGING · publicările merg DOAR în repo-urile *-staging; Supabase, secretele și registrul de vânzări sunt blocate")
                        .font(.callout.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(Color.red)
                }
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
