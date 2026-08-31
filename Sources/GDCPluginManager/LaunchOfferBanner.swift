import SwiftUI
import AppKit

/// Banner de lansare publică — ancorat jos de tot pe ecranul principal
/// (`ContentView.detail`), controlat de Cristi din Furnizor FĂRĂ
/// recompilare (2026-08-31, vezi `LaunchBannerChecker`/`LaunchBannerModel`,
/// portat după modelul `docs/pricing.json`/Regula 27). Textul rămâne
/// REAL (SwiftUI `Text`, nu parte din imagine) — generatoarele AI de
/// imagini nu randează fiabil text cu diacritice românești.
///
/// Non-interactiv (`.allowsHitTesting(false)`), la fel ca filigranul
/// sezonier — decorativ, nu blochează click-urile pe conținutul de deasupra.
/// Complet ascuns (`EmptyView`) dacă bannerul e dezactivat din Furnizor sau
/// nu s-a putut încărca nimic, nici măcar din cache local.
struct LaunchOfferBanner: View {
    @ObservedObject private var checker = LaunchBannerChecker.shared

    private static let imageAspectRatio: CGFloat = 1248.0 / 832.0

    var body: some View {
        Group {
            if let config = checker.config, config.isDisplayable, let nsImage = checker.nsImage {
                GeometryReader { geo in
                    let height = min(geo.size.width / Self.imageAspectRatio, 190)
                    ZStack {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                        VStack(spacing: 4) {
                            Text(config.topText)
                                .font(.system(size: 13, weight: .bold))
                                .tracking(3)
                                .foregroundStyle(.white.opacity(0.9))
                            Text(config.mainText)
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
            }
        }
        .allowsHitTesting(false)
        .task { await checker.refresh() }
    }
}
