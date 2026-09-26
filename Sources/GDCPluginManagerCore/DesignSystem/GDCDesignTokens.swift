import SwiftUI

/// GDC Design Tokens — sursa unică a valorilor vizuale (Faza 2, 2026-09-25).
///
///     GDCTokens  →  primitive (GDC UI Components)  →  ecrane  →  produs
///
/// Regula de folosire (engineering/DESIGN_SYSTEM.md): un ecran nou sau atins
/// nu mai scrie literal `padding(16)`, `cornerRadius(12)`, `.orange`, ci
/// `GDCTokens.Space.l`, `GDCTokens.Radius.card`, `GDCTokens.Palette.warning`.
/// Valorile de mai jos sunt cele DEJA folosite cel mai des în client (inventar
/// 2026-09-25), deci adoptarea lor nu schimbă aspectul — redesign-ul
/// ulterior schimbă valoarea aici, o singură dată.
public enum GDCTokens {

    /// Grilă de 2pt; treptele acoperă valorile folosite azi (4/6/8/12/14/16/24/40).
    public enum Space {
        public static let xxs: CGFloat = 2
        public static let xs: CGFloat = 4
        public static let s: CGFloat = 8
        public static let m: CGFloat = 12
        public static let l: CGFloat = 16
        public static let xl: CGFloat = 24
        public static let xxl: CGFloat = 32
        public static let page: CGFloat = 40
        /// Spațiul dintre carduri în grile (valoarea dominantă azi: 14).
        public static let grid: CGFloat = 14
    }

    /// Raze concentrice: un element interior folosește o treaptă mai mică decât containerul.
    public enum Radius {
        public static let badge: CGFloat = 6
        public static let control: CGFloat = 8
        public static let inset: CGFloat = 10
        public static let card: CGFloat = 12
        public static let panel: CGFloat = 16
    }

    /// Tipografie semantică (Dynamic Type — Regula 24). Mărimi fixe DOAR pentru
    /// cifre de afișaj/iconițe, niciodată pentru text de citit.
    public enum Typography {
        public static let display = Font.system(.largeTitle, design: .default).weight(.semibold)
        public static let pageTitle = Font.title2.weight(.semibold)
        public static let sectionTitle = Font.headline
        public static let cardTitle = Font.headline
        public static let body = Font.body
        public static let secondary = Font.callout
        public static let metadata = Font.caption
        public static let caption = Font.caption2
        public static let label = Font.subheadline.weight(.medium)
        public static let numeric = Font.body.monospacedDigit()
        public static let code = Font.system(.caption, design: .monospaced)
    }

    /// Culori SEMANTICE. Textul și fundalurile rămân semantice de sistem
    /// (Regula 37: fără culori literale pe controale), deci Light/Dark vin gratis.
    public enum Palette {
        /// Accent GDC (amber/cupru — Regula 7/12), ajustat per temă pentru contrast.
        public static let accent = Color(nsColor: NSColor(name: "GDCAccent") { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(srgbRed: 0.95, green: 0.68, blue: 0.32, alpha: 1)
                : NSColor(srgbRed: 0.78, green: 0.47, blue: 0.16, alpha: 1)
        })
        public static let textPrimary = Color.primary
        public static let textSecondary = Color.secondary
        public static let textTertiary = Color(nsColor: .tertiaryLabelColor)
        public static let disabled = Color(nsColor: .disabledControlTextColor)
        public static let selection = Color(nsColor: .selectedContentBackgroundColor)
        public static let separator = Color(nsColor: .separatorColor)
        public static let windowBackground = Color(nsColor: .windowBackgroundColor)
        public static let surface = Color(nsColor: .controlBackgroundColor)
        // Stări — identice în ambele teme, definite o singură dată (Regula 37).
        public static let success = Color.green
        public static let warning = Color.orange
        public static let error = Color.red
        public static let destructive = Color.red
        public static let info = Color.blue
        /// Textul de pe accent. Închis în ambele teme: alb pe amberul Light dă ~3.3:1 (sub 4.5:1).
        public static let onAccent = Color(nsColor: NSColor(srgbRed: 0.11, green: 0.07, blue: 0.02, alpha: 1))
    }

    /// Finisajul „lucios discret” (prototip A+B): reflex pe imagine + muchie de lumină.
    /// Doar pe suprafețe care plutesc (carduri); niciodată pe tabele sau formulare.
    public enum Finish {
        private static func dynamic(dark: CGFloat, light: CGFloat) -> Color {
            Color(nsColor: NSColor(name: nil) { a in
                NSColor(white: 1, alpha: a.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light)
            })
        }
        /// Începutul gradientului de reflex (sus), care se stinge la 42% din înălțime.
        public static let glossTop = dynamic(dark: 0.09, light: 0.28)
        /// Linia de lumină de pe muchia de sus a imaginii și a cardului.
        public static let edge = dynamic(dark: 0.14, light: 0.70)
        public static var gloss: LinearGradient {
            LinearGradient(stops: [.init(color: glossTop, location: 0), .init(color: .clear, location: 0.42)],
                           startPoint: .top, endPoint: .bottom)
        }
    }

    /// Ierarhia suprafețelor: opac < translucid < material < ridicat.
    /// Materialul se folosește DOAR pe suprafețe care plutesc peste conținut
    /// (carduri în grilă, banner, popover) — nu pe fundaluri de pagină sau tabele.
    public enum Surface {
        public static let card: Material = .ultraThinMaterial
        public static let floating: Material = .regularMaterial
        public static let bar: Material = .bar
    }

    public enum Border {
        public static let hairline: CGFloat = 1
        /// Bordura fină a cardurilor (valoarea actuală din `glassCardBackground`).
        public static let cardColor = Color.white.opacity(0.2)
        public static let focusWidth: CGFloat = 2
    }

    public struct Elevation: Sendable {
        public let color: Color
        public let radius: CGFloat
        public let y: CGFloat
        public static let none = Elevation(color: .clear, radius: 0, y: 0)
        /// Card în grilă (valoarea actuală).
        public static let card = Elevation(color: .black.opacity(0.10), radius: 10, y: 4)
        public static let hover = Elevation(color: .black.opacity(0.16), radius: 16, y: 6)
        public static let floating = Elevation(color: .black.opacity(0.22), radius: 24, y: 10)
    }

    /// Durate scurte: animația comunică o schimbare de stare, nu decorează.
    /// Toate trec prin `GDCTokens.Motion.animation(_:reduceMotion:)`.
    public enum Motion {
        public static let fast: Double = 0.12
        public static let standard: Double = 0.2
        public static let emphasized: Double = 0.32

        public static func animation(_ duration: Double = standard, reduceMotion: Bool) -> Animation? {
            reduceMotion ? nil : .easeOut(duration: duration)
        }
    }

    public enum Size {
        public static let minHitTarget: CGFloat = 28
        public static let cardMinWidth: CGFloat = 260
        /// Imaginea cardului de produs (prototip A+B aprobat 2026-09-26).
        public static let cardArtworkHeight: CGFloat = 156
        /// Înălțimea fixă a cardului de produs (butonul cade pe aceeași linie în grilă).
        public static let productCardHeight: CGFloat = 372
        public static let badgeHeight: CGFloat = 20
        public static let sidebarMinWidth: CGFloat = 220
        public static let iconS: CGFloat = 14
        public static let iconM: CGFloat = 20
        public static let iconL: CGFloat = 32
    }
}

public extension View {
    /// Aplică o treaptă de elevație din `GDCTokens.Elevation`.
    func gdcElevation(_ e: GDCTokens.Elevation) -> some View {
        shadow(color: e.color, radius: e.radius, x: 0, y: e.y)
    }
}
