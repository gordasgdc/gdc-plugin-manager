import SwiftUI
import AppKit

/// Banner de lansare publică — imagine statică (bundled în app, nu descărcată,
/// nu face parte din biblioteca de filigrane sezoniere din
/// `SeasonalBackgroundsLayer`/Furnizor) ancorată jos de tot pe ecranul
/// principal (`ContentView.detail`), cu textul de ofertă suprapus REAL
/// (SwiftUI `Text`, diacritice ro corecte garantat — imaginea generată AI
/// nu poate randa text fiabil, vezi discuția din sesiune).
///
/// Non-interactiv (`.allowsHitTesting(false)`), la fel ca filigranul
/// sezonier — decorativ, nu blochează click-urile pe conținutul de deasupra.
/// TEMPORAR: se scoate manual din `ContentView` când se încheie oferta de
/// lansare (nu are logică de scheduling — dacă devine nevoie de asta,
/// portă modelul `Scheduling`/`showCountdown` deja existent, nu inventa altul).
struct LaunchOfferBanner: View {
    private static let imageAspectRatio: CGFloat = 1248.0 / 832.0

    var body: some View {
        GeometryReader { geo in
            let height = min(geo.size.width / Self.imageAspectRatio, 190)
            ZStack {
                if let nsImage = Self.bundledImage {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                }
                VStack(spacing: 4) {
                    Text("LANSARE")
                        .font(.system(size: 13, weight: .bold))
                        .tracking(3)
                        .foregroundStyle(.white.opacity(0.9))
                    Text("PREȚURI SPECIALE DE DESCHIDERE")
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(colors: [Color(red: 1, green: 0.87, blue: 0.6), Color(red: 0.85, green: 0.65, blue: 0.25)],
                                           startPoint: .top, endPoint: .bottom)
                        )
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .shadow(color: .black.opacity(0.6), radius: 6)
                // Textul stă în banda superioară, goală, a imaginii —
                // exact zona lăsată liber la generare pentru asta.
                .offset(y: -height * 0.22)
            }
            .frame(width: geo.size.width, height: height)
            .clipped()
        }
        .frame(height: 190)
        .allowsHitTesting(false)
    }

    /// `Bundle.module` (nu `Bundle.main`) — resursa SPM a acestui target,
    /// la fel ca `HelpGuide.swift` pentru PDF-uri.
    private static let bundledImage: NSImage? = {
        guard let url = Bundle.module.url(forResource: "LaunchOfferBanner", withExtension: "jpg") else { return nil }
        return NSImage(contentsOf: url)
    }()
}
