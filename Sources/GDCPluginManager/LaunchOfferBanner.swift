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
/// [2026-08-31, BUG REAL găsit și reparat — identic cu cel deja documentat
/// la `SeasonalBackgroundLayer`] `.task` era atașat pe un
/// `Group { if let ... }` — la primul randaj (`checker.config` încă `nil`,
/// înainte ca `refresh()` să apuce să ruleze), acel Group nu are NICIUN
/// copil concret, iar SwiftUI nu garantează `.task`/`onAppear` pe un
/// asemenea "gol condițional" — confirmat direct din
/// `%TEMP%/gdcpm-crash.log`: zero apeluri "LaunchBanner" vreodată, deci
/// `refresh()` nu pornea NICIODATĂ. Fix: `.task` atașat pe un container
/// CONCRET, mereu prezent (`Color.clear` cu `frame` fix), cu conținutul
/// condiționat suprapus DOAR când există.
struct LaunchOfferBanner: View {
    @ObservedObject private var checker = LaunchBannerChecker.shared

    private static let maxHeight: CGFloat = 190

    var body: some View {
        GeometryReader { geo in
            Color.clear
                .frame(width: geo.size.width, height: Self.maxHeight)
                .overlay(alignment: .bottom) {
                    if let config = checker.config, config.isDisplayable, let nsImage = checker.nsImage {
                        // [2026-08-31, BUG REAL #2] Raportul de aspect era
                        // hardcodat (1248/832, imaginea generată AI inițial)
                        // — după ce Cristi a republicat o imagine nouă prin
                        // Furnizor (CoverImagePicker, preset `.cover`, care
                        // decupează la un alt raport de aspect), imaginea
                        // reală a devenit 1248x477. Cu raportul vechi
                        // hardcodat, înălțimea calculată nu mai corespundea
                        // imaginii REALE — textul (poziționat relativ la
                        // acea înălțime greșită) ajungea suprapus peste
                        // conținutul imaginii. Fix: raportul se citește
                        // DIRECT din imaginea primită, niciodată presupus.
                        let aspectRatio = max(nsImage.size.width / max(nsImage.size.height, 1), 0.1)
                        let height = min(geo.size.width / aspectRatio, Self.maxHeight)
                        ZStack(alignment: .top) {
                            Image(nsImage: nsImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                            // Voal întunecat sus — textul rămâne lizibil
                            // INDIFERENT ce se află în imagine la acel punct
                            // (nu ne mai bazăm pe o "bandă goală" anume,
                            // fiindcă orice imagine viitoare, încărcată prin
                            // uploader-ul standard de copertă, poate avea
                            // orice compoziție).
                            LinearGradient(colors: [.black.opacity(0.55), .black.opacity(0)],
                                           startPoint: .top, endPoint: .bottom)
                                .frame(height: min(height * 0.6, 70))
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
                            .padding(.top, 10)
                            .shadow(color: .black.opacity(0.6), radius: 6)
                            .frame(maxWidth: .infinity)
                        }
                        .frame(width: geo.size.width, height: height)
                        .clipped()
                    }
                }
        }
        .frame(height: Self.maxHeight)
        .allowsHitTesting(false)
        .task {
            DiagnosticLog.write("LaunchBanner", "view task pornit")
            await checker.refresh()
        }
    }
}
