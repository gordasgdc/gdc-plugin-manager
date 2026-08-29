import AppKit
import Combine

/// Selector explicit de temă Sistem/Light/Dark — Regula 18 (Partea 1,
/// CLAUDE.md): "unii clienți vor Light chiar și noaptea, alții Dark
/// permanent; NU e suficient să urmezi orbește tema sistemului".
///
/// Port 1:1 al implementării de referință `AppTheme.swift` din MediaFlow
/// Monitor (aceeași structură, aceleași etichete), mutat în **Core** ca să
/// fie folosit identic de AMÂNDOUĂ aplicațiile Mac (Client + Furnizor) —
/// nu două copii care pot diverge. Cheia de `UserDefaults` e aceeași
/// literal în ambele, dar domeniile de preferințe sunt separate
/// (bundle ID-uri diferite), deci alegerile lor nu se calcă reciproc.
public enum AppTheme: String, CaseIterable, Identifiable, Sendable {
    case system, light, dark

    public var id: String { rawValue }

    /// Etichetă RO implicită. Clientul (care are `Localization.swift`)
    /// o poate suprascrie cu traducerea lui; Furnizorul e RO-only și o
    /// folosește ca atare.
    public var label: String {
        switch self {
        case .system: return "Sistem"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    public var nsAppearance: NSAppearance? {
        switch self {
        case .system: return nil // nil = urmează setarea macOS
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }
}

/// Persistă alegerea local (`UserDefaults`) și o aplică IMEDIAT, fără
/// repornire.
///
/// DELIBERAT `NSApp.appearance`, nu `.preferredColorScheme()` pe view-ul
/// rădăcină: `preferredColorScheme` afectează doar ierarhia SwiftUI a acelei
/// ferestre — meniurile, panourile native (`NSOpenPanel`, `NSAlert`),
/// popover-ele și fereastra de Preferences ar fi rămas pe tema sistemului,
/// adică exact incoerența pe care selectorul trebuie s-o elimine.
public final class ThemeManager: ObservableObject {
    public static let shared = ThemeManager()

    private static let key = "GDCPluginManager.appTheme"

    @Published public private(set) var current: AppTheme

    private init() {
        let saved = UserDefaults.standard.string(forKey: Self.key)
        current = saved.flatMap(AppTheme.init(rawValue:)) ?? .system
        apply()
    }

    public func set(_ theme: AppTheme) {
        guard theme != current else { return }
        UserDefaults.standard.set(theme.rawValue, forKey: Self.key)
        current = theme
        apply()
    }

    /// Apelat o dată la pornire (init) și la fiecare schimbare.
    private func apply() {
        // La `init` (înainte ca `NSApplication` să fie pornită) `NSApp` poate
        // fi încă nil — atunci aplicarea se face la prima `set`/`applyNow`.
        NSApp?.appearance = current.nsAppearance
    }

    /// De chemat din `.task`/`onAppear`-ul ferestrei principale, ca tema
    /// salvată să fie activă de la primul cadru chiar dacă `ThemeManager`
    /// s-a inițializat înainte ca `NSApp` să existe.
    public func applyNow() { apply() }
}
