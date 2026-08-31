import Foundation

/// Model public, comun, al `pricing.json` (Regula 27) — pana acum fiecare
/// aplicatie standalone GDC (CGConvertor, CursorPro, DataMover, GDC Vault,
/// Master Control Studio Pro, MediaFlow Monitor) isi duplica propriul
/// `PricingChecker` cu structuri PRIVATE identice, pentru ca fiecare traieste
/// intr-un repo separat, fara dependinta SPM intre ele. Aici insa, in
/// `gdc-plugin-manager-catalog-vendor`, Client si Furnizor sunt in ACELASI
/// pachet — un singur model public in Core, folosit de amandoua, in loc sa
/// se duplice a saptea oara.
public struct PricingCatalog: Codable {
    public var products: [String: ProductPricing]
    public var updatedAt: String?

    public init(products: [String: ProductPricing] = [:], updatedAt: String? = nil) {
        self.products = products
        self.updatedAt = updatedAt
    }
}

public struct ProductPricing: Codable {
    public var basePrice: Double
    public var currency: String
    public var name: String
    public var promoSchedule: [PricingPromo]

    enum CodingKeys: String, CodingKey { case basePrice, currency, name, promoSchedule }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        basePrice = try c.decode(Double.self, forKey: .basePrice)
        currency = try c.decodeIfPresent(String.self, forKey: .currency) ?? "EUR"
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        promoSchedule = try c.decodeIfPresent([PricingPromo].self, forKey: .promoSchedule) ?? []
    }

    public init(basePrice: Double, currency: String = "EUR", name: String = "", promoSchedule: [PricingPromo] = []) {
        self.basePrice = basePrice
        self.currency = currency
        self.name = name
        self.promoSchedule = promoSchedule
    }

    /// Fereastra activă ACUM din program, dacă există.
    public var activePromo: PricingPromo? { promoSchedule.first(where: { $0.isActiveNow }) }
    /// Prețul afișat clientului chiar acum — promoția activă, altfel prețul de bază.
    public var effectivePrice: Double { activePromo?.price ?? basePrice }
}

public struct PricingPromo: Codable {
    public var price: Double
    public var label: String
    public var startsAt: Date
    public var endsAt: Date
    public var showCountdown: Bool

    enum CodingKeys: String, CodingKey { case price, label, startsAt, endsAt, showCountdown }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        price = try c.decode(Double.self, forKey: .price)
        label = try c.decode(String.self, forKey: .label)
        startsAt = try c.decode(Date.self, forKey: .startsAt)
        endsAt = try c.decode(Date.self, forKey: .endsAt)
        showCountdown = try c.decodeIfPresent(Bool.self, forKey: .showCountdown) ?? false
    }

    public init(price: Double, label: String, startsAt: Date, endsAt: Date, showCountdown: Bool = false) {
        self.price = price
        self.label = label
        self.startsAt = startsAt
        self.endsAt = endsAt
        self.showCountdown = showCountdown
    }

    public var isActiveNow: Bool {
        let now = Date()
        return now >= startsAt && now <= endsAt
    }

    /// Convertit la un `Scheduling` — permite reutilizarea directă a
    /// `CountdownBadge`-ului deja existent în Client, fără cod UI nou.
    public var asScheduling: Scheduling {
        Scheduling(startDate: startsAt, endDate: endsAt, showCountdown: showCountdown)
    }
}
