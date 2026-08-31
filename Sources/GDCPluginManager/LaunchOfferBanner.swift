import SwiftUI
import AppKit
import GDCPluginManagerCore

/// Banner de lansare publică — ancorat jos de tot pe ecranul principal
/// (`ContentView.detail`), controlat de Cristi din Furnizor FĂRĂ
/// recompilare (2026-08-31, vezi `LaunchBannerChecker`/`LaunchBannerModel`,
/// portat după modelul `docs/pricing.json`/Regula 27). Textul rămâne
/// REAL (SwiftUI `Text`, nu parte din imagine) — generatoarele AI de
/// imagini nu randează fiabil text cu diacritice românești.
///
/// Non-interactiv (`.allowsHitTesting(false)`), la fel ca filigranul
/// sezonier — decorativ, nu blochează click-urile pe conținutul de deasupra.
/// Complet ascuns dacă bannerul e dezactivat din Furnizor sau nu s-a putut
/// încărca nimic, nici măcar din cache local.
///
/// [2026-08-31, BUG REAL #1, reparat] `.task` era atașat pe un
/// `Group { if let ... }` — la primul randaj (`checker.config` încă `nil`),
/// acel Group n-are niciun copil concret, iar SwiftUI nu garantează
/// `.task` pe un asemenea gol condițional. Confirmat din log (zero apeluri
/// "LaunchBanner"). Fix: `.task` atașat pe un container CONCRET, mereu
/// prezent.
///
/// [2026-08-31, BUG REAL #2, reparat] Textul suprapus PESTE imagine
/// (poziționat relativ la o "bandă goală" presupusă în imagine) s-a
/// dovedit fragil de două ori la rând — o dată din cauza unui raport de
/// aspect hardcodat greșit, a doua oară din motive tot legate de
/// poziționare relativă la conținutul imaginii. DECIZIE FINALĂ: textul nu
/// mai stă NICIODATĂ suprapus peste imagine — stă într-o bandă SOLIDĂ,
/// SEPARATĂ, sub imagine. Zero ambiguitate: banda are propriul fundal
/// opac, propria înălțime fixă, complet independentă de ce se află în
/// imagine sau de raportul ei de aspect.
struct LaunchOfferBanner: View {
    @ObservedObject private var checker = LaunchBannerChecker.shared

    private static let imageHeight: CGFloat = 150
    private static let textBandHeight: CGFloat = 46

    var body: some View {
        Color.clear
            .frame(height: Self.imageHeight + Self.textBandHeight)
            .overlay(alignment: .bottom) {
                if let config = checker.config, config.isDisplayable, let nsImage = checker.nsImage {
                    // Poziția benzii de text (sus/jos) e o opțiune aleasă
                    // de Cristi din Furnizor (`config.textOnTop`), nu fixă
                    // în cod — vezi `LaunchBannerConfig.textOnTop`.
                    VStack(spacing: 0) {
                        if config.textOnTop {
                            textBand(config)
                            imageView(nsImage)
                        } else {
                            imageView(nsImage)
                            textBand(config)
                        }
                    }
                }
            }
            .allowsHitTesting(false)
            .task {
                await checker.refresh()
                DiagnosticLog.write("LaunchBanner", "task finalizat, config=\(String(describing: checker.config)), image=\(checker.nsImage != nil)")
            }
    }

    /// Bandă SOLIDĂ, separată de imagine — textul nu depinde deloc de ce
    /// se află în imagine.
    @ViewBuilder
    private func textBand(_ config: LaunchBannerConfig) -> some View {
        ZStack {
            Color.black.opacity(0.82)
            VStack(spacing: 2) {
                Text(config.topText)
                    .font(.system(size: 11, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.85))
                Text(config.mainText)
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(colors: [Color(red: 1, green: 0.87, blue: 0.6), Color(red: 0.85, green: 0.65, blue: 0.25)],
                                       startPoint: .top, endPoint: .bottom)
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
        }
        .frame(height: Self.textBandHeight)
    }

    @ViewBuilder
    private func imageView(_ nsImage: NSImage) -> some View {
        Image(nsImage: nsImage)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(height: Self.imageHeight)
            .clipped()
    }
}
