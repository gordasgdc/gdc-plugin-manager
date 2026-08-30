import Foundation

/// Preț dinamic pentru toate aplicațiile standalone GDC (2026-08-30) —
/// motivul e explicit: o ofertă de Black Friday necesita pana acum
/// recompilarea + resemnarea + republicarea FIECAREI aplicații (12 repo-uri)
/// doar ca sa schimbi o cifra afișată. `pricing.json` e citit de fiecare
/// aplicație client la lansare (vezi PricingChecker, portat identic per
/// repo, dupa modelul UpdateChecker/update.json) — o modificare aici devine
/// vizibilă în CÂTEVA SECUNDE pe toate aplicațiile deja instalate, fără
/// recompilare.
///
/// Format `docs/pricing.json`:
/// ```json
/// {
///   "updatedAt": "2026-08-30",
///   "products": {
///     "gdc-datamover": {
///       "name": "DataMover", "basePrice": 23, "currency": "EUR",
///       "promo": { "price": 15, "label": "Black Friday -35%",
///                  "startsAt": "2026-11-27T00:00:00Z", "endsAt": "2026-12-01T23:59:59Z" }
///     }
///   }
/// }
/// ```
/// `promo: null` (sau lipsă) = niciun preț special activ.
struct PricingCatalog: Codable {
    var updatedAt: String
    var products: [String: ProductPricing]
}

struct ProductPricing: Codable, Equatable {
    var name: String
    var basePrice: Double
    var currency: String
    /// Program de oferte (2026-08-30) - NU o singura oferta activa/inactiva,
    /// ci o LISTA de intervale programate dinainte ("1-15 sept: pret X,
    /// 27 noi - 1 dec: Black Friday Y, 20-31 dec: Craciun Z") - cerut
    /// explicit: Cristi vrea sa planifice din timp mai multe ferestre, nu
    /// doar sa comute manual o oferta la momentul potrivit. Aplicatia
    /// alege automat fereastra a carei perioada contine "acum"; daca
    /// niciuna nu se potriveste, foloseste `basePrice`. La coliziune de
    /// perioade (nu ar trebui sa existe, dar Furnizor nu valideaza asta
    /// strict), castiga PRIMA gasita in lista.
    var promoSchedule: [PricingPromo] = []

    enum CodingKeys: String, CodingKey { case name, basePrice, currency, promoSchedule }
    init(name: String, basePrice: Double, currency: String, promoSchedule: [PricingPromo] = []) {
        self.name = name; self.basePrice = basePrice; self.currency = currency; self.promoSchedule = promoSchedule
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        basePrice = try c.decode(Double.self, forKey: .basePrice)
        currency = try c.decode(String.self, forKey: .currency)
        // Compatibil cu `pricing.json` scris inainte de acest camp (lista
        // goala implicit).
        promoSchedule = try c.decodeIfPresent([PricingPromo].self, forKey: .promoSchedule) ?? []
    }

    /// Fereastra activa ACUM, daca exista - portat identic in
    /// PricingChecker-ul fiecarei aplicatii.
    var activePromo: PricingPromo? { promoSchedule.first(where: { $0.isActiveNow }) }
    /// Urmatoarea fereastra VIITOARE (nu inca activa) - folosit de Furnizor
    /// ca sa arate "oferta X incepe pe [data]" inainte sa devina activa.
    var nextScheduledPromo: PricingPromo? {
        promoSchedule.filter { $0.startsAt > Date() }.min { $0.startsAt < $1.startsAt }
    }
}

struct PricingPromo: Codable, Equatable, Identifiable {
    /// Doar pentru identitate in List-urile SwiftUI din Furnizor - NU se
    /// salveaza in pricing.json (fiecare decodare genereaza un id nou,
    /// suficient pentru o singura sesiune de editare).
    var id = UUID()
    var price: Double
    var label: String
    var startsAt: Date
    var endsAt: Date
    /// Opțional (2026-08-30, cerut explicit): afișează un countdown live
    /// ("Se termină în 2 zile 14 ore") în UI-ul aplicației, ca să creeze
    /// urgență ("Aoleu, trece oferta!") — nu toate ofertele îl vor (ex. o
    /// simplă reducere permanentă de sezon, fără presiune de timp).
    /// Implicit `false` la decodare dacă lipsește din JSON (compatibil cu
    /// orice `pricing.json` scris înainte de acest câmp).
    var showCountdown: Bool = false

    enum CodingKeys: String, CodingKey {
        case price, label, startsAt, endsAt, showCountdown
    }

    init(price: Double, label: String, startsAt: Date, endsAt: Date, showCountdown: Bool = false) {
        self.price = price
        self.label = label
        self.startsAt = startsAt
        self.endsAt = endsAt
        self.showCountdown = showCountdown
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        price = try c.decode(Double.self, forKey: .price)
        label = try c.decode(String.self, forKey: .label)
        startsAt = try c.decode(Date.self, forKey: .startsAt)
        endsAt = try c.decode(Date.self, forKey: .endsAt)
        showCountdown = try c.decodeIfPresent(Bool.self, forKey: .showCountdown) ?? false
    }

    /// True daca promoția e activă ACUM (folosit și de Furnizor pentru
    /// preview, și portat identic în PricingChecker-ul fiecărei aplicații).
    var isActiveNow: Bool {
        let now = Date()
        return now >= startsAt && now <= endsAt
    }

    /// Timp ramas pana la finalul ofertei, format scurt ("2z 14h 3m") —
    /// portat identic in PricingChecker; folosit doar cand showCountdown
    /// e true SI isActiveNow e true.
    var countdownText: String {
        let remaining = max(0, endsAt.timeIntervalSinceNow)
        let days = Int(remaining) / 86400
        let hours = (Int(remaining) % 86400) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        if days > 0 { return "\(days)z \(hours)h" }
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }
}
