import Foundation
import GDCPluginManagerCore

/// Fetch la lansare al `pricing.json` (Regula 27) — folosit de `AppCard`
/// ca să arate preț/ofertă/countdown pe cardurile din „Aplicații”, exact
/// cum apare deja pe cardurile de LUT/DCTL/PowerGrade (`priceEUR`/
/// `promoPriceEUR` din catalog). Port 1:1 al tiparului `LaunchBannerChecker`
/// (fetch + verificare status HTTP + fail-open pe `nil` — un card fără
/// `pricingProductID` sau fără conexiune arată la fel ca înainte, fără preț).
@MainActor
final class AppPricingFetcher: ObservableObject {
    static let shared = AppPricingFetcher()

    private static let pricingURL = URL(string: "https://gordas.dev/pricing.json")!

    @Published private(set) var catalog: PricingCatalog?

    private init() {}

    func refresh() async {
        guard let (data, response) = try? await URLSession.shared.data(from: Self.pricingURL),
              let http = response as? HTTPURLResponse, http.statusCode == 200 else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let decoded = try? decoder.decode(PricingCatalog.self, from: data) else { return }
        catalog = decoded
    }
}
