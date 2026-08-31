import AppKit
import Combine
import SwiftUI

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

/// Mărime text UI, opțională — cerut explicit 2026-08-29 ("setări de mărire
/// a textului").
///
/// [2026-08-31, BUG REAL găsit și reparat] Varianta inițială folosea
/// `dynamicTypeSize` (infrastructura de accesibilitate SwiftUI) — pe
/// hârtie, alegerea "corectă" (reflow automat, fără text tăiat). ÎN
/// PRACTICĂ, pe macOS 14, modificatorul nu producea NICIO schimbare
/// vizibilă NICĂIERI în această aplicație, confirmat direct de Cristi de
/// două ori (o dată cu modificatorul aplicat la nivel de Scene, a doua
/// oară mutat la nivel de View — tot fără efect). Motivul exact rămâne
/// neclar (posibil: macOS randează multe stiluri semantice de font la
/// dimensiuni FIXE, spre deosebire de iOS, unde Dynamic Type are tabele
/// de dimensiuni explicite per treaptă) — indiferent de cauză, dovada
/// empirică ("nu funcționează") bate presupunerea teoretică ("ar trebui
/// să funcționeze"). Înlocuit cu EXACT aceeași strategie deja dovedită pe
/// Windows (`TextScaleStore.cs`, `ScaleTransform` pe `LayoutTransform`):
/// un factor de scalare aplicat direct, vizual, pe întregul arbore
/// (`.scaleEffect` + compensare de `frame`, vezi `GDCPluginManagerApp.swift`).
public enum TextScalePreference: String, CaseIterable, Identifiable, Sendable {
    case small, normal, large, xlarge

    public var id: String { rawValue }

    /// Aceiași factori ca `TextScalePreferenceExtensions.ScaleFactor` de pe
    /// Windows — paritate vizuală între platforme.
    public var scaleFactor: CGFloat {
        switch self {
        case .small: return 0.9
        case .normal: return 1.0
        case .large: return 1.15
        case .xlarge: return 1.3
        }
    }
}

public final class TextScaleManager: ObservableObject {
    public static let shared = TextScaleManager()

    private static let key = "GDCPluginManager.textScale"

    @Published public var current: TextScalePreference {
        didSet {
            guard current != oldValue else { return }
            UserDefaults.standard.set(current.rawValue, forKey: Self.key)
        }
    }

    private init() {
        let saved = UserDefaults.standard.string(forKey: Self.key)
        current = saved.flatMap(TextScalePreference.init(rawValue:)) ?? .normal
    }
}
