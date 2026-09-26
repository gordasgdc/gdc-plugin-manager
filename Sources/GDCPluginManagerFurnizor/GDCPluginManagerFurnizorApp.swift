import SwiftUI
import GDCPluginManagerCore

@main
struct GDCPluginManagerFurnizorApp: App {
    /// Mod fără fereastră, cerut de GDC STYLE Lab: publică direct pachetele Demo din căsuța de intrare, scrie rezultatul și iese.
    init() {
        // 1.52.5: înaintea oricărei operații (inclusiv modul fără fereastră): producția după staging
        // pornește cu scrierile blocate până la confirmarea explicită.
        #if DEBUG
        // `-FurnizorSessionFile <cale>`: fișier de sesiune izolat pentru verificări (nu atinge sesiunea reală).
        if let path = UserDefaults.standard.string(forKey: "FurnizorSessionFile") {
            FurnizorEnvironment.sessionFileOverride = URL(fileURLWithPath: path)
        }
        #endif
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
                .frame(minWidth: 1040, minHeight: 600)  // Faza 5: bară laterală + tabel + inspector rămân lizibile
                // Tema salvată se aplică din primul cadru — vezi
                // AppTheme.swift (Core) și comentariul din Client.
                .onAppear {
                    ThemeManager.shared.applyNow()
                    #if DEBUG
                    FurnizorDebugWindowSizer.apply()
                    #endif
                }
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

#if DEBUG
/// `-GDCWindowSize 1040x600` redimensionează fereastra reală (capturi de verificare, fără instalare).
enum FurnizorDebugWindowSizer {
    static func apply() {
        guard let raw = UserDefaults.standard.string(forKey: "GDCWindowSize") else { return }
        let p = raw.split(separator: "x").compactMap { Double($0) }
        guard p.count == 2 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            NSApp.windows.first(where: { $0.isVisible && $0.canBecomeMain })?.setContentSize(NSSize(width: p[0], height: p[1]))
        }
    }
}
#endif
