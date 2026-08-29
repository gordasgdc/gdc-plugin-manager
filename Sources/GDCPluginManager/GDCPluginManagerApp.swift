import SwiftUI
import AppKit
import GDCPluginManagerCore

@main
struct GDCPluginManagerApp: App {
    // @StateObject (nu doar `.shared` citit direct) — obligatoriu ca
    // schimbarea din Preferences să REÎNTOARCĂ `body`-ul scenei; altfel
    // `.dynamicTypeSize` de mai jos ar citi valoarea o singură dată, la
    // pornire, și n-ar reacționa niciodată la o schimbare ulterioară.
    @StateObject private var textScale = TextScaleManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 760, minHeight: 500)
                // Tema salvată (Sistem/Light/Dark) se aplică din primul
                // cadru: `ThemeManager` se poate iniția înainte ca `NSApp`
                // să existe, caz în care `apply()` din init n-are pe ce
                // scrie — vezi AppTheme.swift (Core).
                .onAppear { ThemeManager.shared.applyNow() }
                // Mărime text (2026-08-29) — `dynamicTypeSize` reflowează
                // automat orice `Text`/`Label` din aplicație, fără cod
                // suplimentar în fiecare view.
                .dynamicTypeSize(textScale.current.dynamicTypeSize)
        }
        .windowStyle(.titleBar)
        .commands {
            // "GDC Plugin Manager -> About GDC Plugin Manager" — panoul
            // nativ standard macOS, cu credite proprii (autor + copyright)
            // in loc de textul implicit generat de Xcode.
            CommandGroup(replacing: .appInfo) {
                Button("About GDC Plugin Manager") {
                    NSApp.orderFrontStandardAboutPanel(options: [
                        .credits: NSAttributedString(
                            string: "Cristi Gordas / GDC\n© 2026 GDC. Toate drepturile rezervate.",
                            attributes: [.font: NSFont.systemFont(ofSize: 11)]
                        )
                    ])
                }
            }
            // "GDC Plugin Manager -> Check for Updates..." — verificare
            // manuala, separata de banner-ul automat de la lansare (vezi
            // UpdateChecker.swift). Rezultatul apare intr-un alert nativ,
            // deschis chiar din fereastra principala (ContentView) prin
            // notificarea de mai jos, ca sa nu deschidem o fereastra noua
            // doar pentru un mesaj de o linie.
            CommandGroup(after: .appInfo) {
                Button("Check for Updates...") {
                    NotificationCenter.default.post(name: .gdcCheckForUpdatesRequested, object: nil)
                }
            }
            // "Help -> Ghid de utilizare (PDF)" — deschide direct in
            // Preview, la rezolutie mare, nativ. Fisierul PDF real
            // (Ghid-GDCPluginManager.pdf) trebuie adaugat de Cristi in
            // Resources/ — vezi HelpGuide.swift pentru fallback-ul afisat
            // daca lipseste inca.
            CommandGroup(replacing: .help) {
                Button("Ghid de utilizare (PDF)") {
                    HelpGuide.openPDF()
                }
            }
        }

        // Settings scene = "GDC Plugin Manager -> Preferences..." + Cmd+,
        // automat, gestionate nativ de SwiftUI/AppKit — nimic manual de
        // adaugat pentru shortcut sau intrarea de meniu.
        Settings {
            PreferencesView()
        }
    }
}

extension Notification.Name {
    static let gdcCheckForUpdatesRequested = Notification.Name("gdcCheckForUpdatesRequested")
}
