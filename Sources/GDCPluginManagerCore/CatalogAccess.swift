import Foundation

// MARK: - Sistem universal de acces, pret, grupare si etichete (2026-09-11)
//
// Cerut explicit de Cristi: aceleasi badge-uri de status/pret, aceeasi bara
// de filtre si aceleasi grupuri/etichete in TOATE sectiunile catalogului, nu
// doar la Aplicatii.
//
// DECIZIA DE ARHITECTURA CARE CONTEAZA (plan aprobat 2026-09-11):
// `CatalogAccess` e un strat DERIVAT, nu unul paralel. Auditul modelelor a
// gasit deja PATRU dialecte diferite de "e gratuit?" —
//   1. `PluginItem.isFree` + `priceEUR`/`promoPriceEUR`
//   2. `DownloadableResource.isFree` + `priceEUR`/`promoPriceEUR`
//   3. `Course.accessType == .free` + `options[].priceEUR`
//   4. `AppLink.pricingProductID` -> `pricing.json` (Regula 27)
// — plus `ProductBundle.bundlePriceEUR`, fara notiune de gratuit.
//
// Daca `CatalogAccess` ar fi stocat si el un `isFree`/`kind` peste acestea,
// am fi creat exact a doua sursa de adevar pe care Regula 30 o interzice:
// doua campuri care pot spune lucruri diferite despre acelasi produs, fara
// nicio regula de arbitraj. De aceea:
//
//   REGULA DE PRECEDENTA (unica, explicita, aplicata in `resolvedAccess`):
//   1. Campul NATIV al modelului castiga INTOTDEAUNA (isFree/priceEUR la
//      plugin-uri si resurse, accessType la cursuri, Pricing Manager la
//      aplicatii).
//   2. `CatalogAccess.kind`/`referencePriceEUR` se consulta DOAR daca
//      modelul nu are nativ acea informatie.
//   3. `group`/`tags`/`note` sunt pur aditive — nu exista nicaieri azi,
//      deci n-au cu ce intra in conflict.
//
// Practic: `PluginItem` NU primeste niciodata un `kind` propriu. Primeste
// `access` doar pentru grup/etichete/aviz, iar `resolvedAccess.isFree` se
// deriva din `isFree`-ul lui existent.

/// Tipul de acces — folosit DOAR de modelele care nu au deja o notiune
/// proprie de gratuit/platit (Audio, Tutoriale, Materiale, Evenimente,
/// Magazine, Oferte, Pachete, Aplicatii externe).
public enum AccessKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case free, paid, trial, external

    public var id: String { rawValue }

    /// Eticheta lunga — formulare de Furnizor (panoul de publicare).
    public var label: String {
        switch self {
        case .free: return "Gratuit"
        case .paid: return "Plătit"
        case .trial: return "Trial / Demo"
        case .external: return "Extern (cu plată la terț)"
        }
    }

    /// Cheia de localizare a badge-ului de pe cardul clientului.
    /// Traducerile RO/EN/ES stau in `Localization.swift` (Client),
    /// respectiv in resursele WPF (Windows) — Core ramane fara UI.
    public var localizationKey: String { "access.kind." + rawValue }

    public var isFree: Bool { self == .free }
}

/// Gruparea dupa origine/proprietar — se aplica identic in orice sectiune.
public enum CatalogGroup: String, Codable, CaseIterable, Identifiable, Sendable {
    case gdc, partners, mine, external

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .gdc: return "Proiecte GDC"
        case .partners: return "Parteneri"
        case .mine: return "Resursele mele"
        case .external: return "Externe"
        }
    }

    public var localizationKey: String { "access.group." + rawValue }
}

/// Datele NOI, comune tuturor modelelor — exact si numai ce nu exista deja
/// nicaieri. Optional pe fiecare model, deci catalogul publicat decodeaza
/// neschimbat (vezi `Catalog` si testul de compatibilitate din CLAUDE.md).
public struct CatalogAccess: Codable, Hashable, Sendable {
    /// Consultat DOAR cand modelul nu are un camp nativ de gratuit/platit.
    public let kind: AccessKind?
    /// Pret de REFERINTA — fallback, folosit doar cand modelul nu are un
    /// pret propriu si nici nu rezolva unul dinamic din Pricing Manager.
    public let referencePriceEUR: Double?
    /// Aviz/nota libera afisata sub nume (ex. „Trial 14 zile", „Licenta se
    /// cumpara de pe site-ul producatorului").
    public let note: String?
    /// Grupare dupa origine/proprietar.
    public let group: CatalogGroup?
    /// Taxonomie libera, specifica domeniului (ex. „Emulare Film",
    /// „Utility", „Color Space", „SFX", „Overlays", „Transitions").
    public let tags: [String]

    public init(kind: AccessKind? = nil, referencePriceEUR: Double? = nil, note: String? = nil, group: CatalogGroup? = nil, tags: [String] = []) {
        self.kind = kind
        self.referencePriceEUR = referencePriceEUR
        self.note = note
        self.group = group
        self.tags = tags
    }

    private enum CodingKeys: String, CodingKey {
        case kind, referencePriceEUR, note, group, tags
    }

    // Decodor explicit: `tags` e non-optional, deci Codable-ul sintetizat ar
    // arunca `keyNotFound` pentru orice `access` scris fara etichete.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        kind = try c.decodeIfPresent(AccessKind.self, forKey: .kind)
        referencePriceEUR = try c.decodeIfPresent(Double.self, forKey: .referencePriceEUR)
        note = try c.decodeIfPresent(String.self, forKey: .note)
        group = try c.decodeIfPresent(CatalogGroup.self, forKey: .group)
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
    }

    /// True daca structura nu poarta nicio informatie — folosit de Furnizor
    /// ca sa scrie `nil` in loc de un obiect gol in catalog.
    public var isEmpty: Bool {
        kind == nil && referencePriceEUR == nil
            && (note?.isEmpty ?? true) && group == nil && tags.isEmpty
    }
}

/// Rezultatul aplicarii regulii de precedenta — ce afiseaza UI-ul efectiv.
/// Construit intotdeauna prin `resolvedAccess`, niciodata scris pe disc.
public struct ResolvedAccess: Hashable, Sendable {
    /// `nil` = NECUNOSCUT, deliberat. Un element fara nicio informatie de
    /// pret (un eveniment, un magazin partener) nu e nici gratuit, nici
    /// premium — filtrele il lasa doar la „Toate", in loc sa-l clasifice
    /// gresit intr-o categorie in care n-are ce cauta.
    public let isFree: Bool?
    /// Textul de pret gata formatat, daca exista unul de aratat.
    public let priceDisplay: String?
    /// Cheia de localizare a badge-ului de status, daca e cazul.
    public let kindKey: String?
    public let note: String?
    public let group: CatalogGroup?
    public let tags: [String]
    public let supportedOS: SupportedOS?

    public init(isFree: Bool?, priceDisplay: String? = nil, kindKey: String? = nil, note: String? = nil, group: CatalogGroup? = nil, tags: [String] = [], supportedOS: SupportedOS? = nil) {
        self.isFree = isFree
        self.priceDisplay = priceDisplay
        self.kindKey = kindKey
        self.note = note
        self.group = group
        self.tags = tags
        self.supportedOS = supportedOS
    }
}

/// Implementat de fiecare model din catalog. `access` e partea STOCATA
/// (datele noi), `resolvedAccess` e partea CALCULATA (precedenta aplicata).
public protocol AccessDescribing {
    var access: CatalogAccess? { get }
    var resolvedAccess: ResolvedAccess { get }
}

public extension AccessDescribing {
    /// Implementare implicita pentru modelele care NU au niciun camp nativ
    /// de pret/gratuit (Audio, Tutoriale, Materiale, Evenimente, Magazine,
    /// Service, Oferte): totul vine din `access`, pasul 2 al precedentei.
    var resolvedAccess: ResolvedAccess {
        ResolvedAccess(
            isFree: access?.kind?.isFree,
            priceDisplay: CatalogAccess.formatPrice(access?.referencePriceEUR),
            kindKey: access?.kind?.localizationKey,
            note: access?.note,
            group: access?.group,
            tags: access?.tags ?? []
        )
    }
}

public extension CatalogAccess {
    /// Formatare unica a pretului in tot ecosistemul — „23 €" pentru sume
    /// intregi, „23.5 €" altfel. Zero si nil nu afiseaza nimic (un pret 0
    /// se comunica prin badge-ul „Gratuit", nu prin textul „0 €").
    static func formatPrice(_ value: Double?) -> String? {
        guard let value, value > 0 else { return nil }
        let isWhole = value.truncatingRemainder(dividingBy: 1) == 0
        return (isWhole ? String(Int(value)) : String(value)) + " €"
    }
}

// MARK: - Conformari per model (regula de precedenta aplicata)
//
// Fiecare extensie de mai jos implementeaza EXPLICIT pasul 1 al precedentei:
// campul nativ al modelului castiga. Unde nu exista camp nativ, modelul se
// bazeaza pe implementarea implicita din `extension AccessDescribing` de mai
// sus (pasul 2) si nu mai apare aici.

extension PluginItem: AccessDescribing {
    /// Sursa de adevar pentru gratuit/pret ramane `isFree`/`effectivePriceEUR`
    /// — `access.kind`/`referencePriceEUR` sunt IGNORATE aici, deliberat.
    public var resolvedAccess: ResolvedAccess {
        ResolvedAccess(
            isFree: isFree,
            priceDisplay: isFree ? nil : CatalogAccess.formatPrice(effectivePriceEUR),
            kindKey: isFree ? AccessKind.free.localizationKey : AccessKind.paid.localizationKey,
            note: access?.note,
            group: access?.group,
            tags: access?.tags ?? [],
            supportedOS: supportedOS
        )
    }
}

extension DownloadableResource: AccessDescribing {
    /// Identic cu `PluginItem` — are propriul `isFree`/`priceEUR`.
    public var resolvedAccess: ResolvedAccess {
        ResolvedAccess(
            isFree: isFree,
            priceDisplay: isFree ? nil : CatalogAccess.formatPrice(effectivePriceEUR),
            kindKey: isFree ? AccessKind.free.localizationKey : AccessKind.paid.localizationKey,
            note: access?.note,
            group: access?.group,
            tags: access?.tags ?? [],
            supportedOS: supportedOS
        )
    }
}

extension Course: AccessDescribing {
    /// Sursa de adevar e `CourseAccessType` (enum propriu, cu patru cazuri
    /// specifice cursurilor — abonament/mentorat n-au echivalent in
    /// `AccessKind`, si nici nu trebuie sa aiba). Pretul vine din cea mai
    /// mica optiune, ca sa arate „de la X €".
    public var resolvedAccess: ResolvedAccess {
        let isFree = accessType == .free
        let cheapest = options.map(\.priceEUR).min()
        return ResolvedAccess(
            isFree: isFree,
            priceDisplay: isFree ? nil : CatalogAccess.formatPrice(cheapest),
            kindKey: isFree ? AccessKind.free.localizationKey : AccessKind.paid.localizationKey,
            note: access?.note,
            group: access?.group,
            tags: access?.tags ?? []
        )
    }
}

extension AppLink: AccessDescribing {
    /// Pasul 1 aici e Pricing Manager (`pricingProductID`, Regula 27) — dar
    /// pretul dinamic se rezolva in Client (`AppPricingFetcher`), nu in Core,
    /// care n-are acces la retea. Deci: daca exista `pricingProductID`,
    /// `priceDisplay` ramane `nil` si UI-ul il completeaza din fetcher;
    /// altfel cade pe `access.referencePriceEUR` (pasul 2).
    public var resolvedAccess: ResolvedAccess {
        ResolvedAccess(
            isFree: access?.kind?.isFree,
            priceDisplay: pricingProductID == nil ? CatalogAccess.formatPrice(access?.referencePriceEUR) : nil,
            kindKey: access?.kind?.localizationKey,
            note: access?.note,
            group: access?.group,
            tags: access?.tags ?? [],
            supportedOS: supportedOS
        )
    }
}

extension ProductBundle: AccessDescribing {
    /// Are pret propriu, dar nicio notiune de gratuit — un pachet cu pret 0
    /// nu exista in practica, deci `isFree` se deriva strict din pret.
    public var resolvedAccess: ResolvedAccess {
        ResolvedAccess(
            isFree: bundlePriceEUR <= 0,
            priceDisplay: CatalogAccess.formatPrice(bundlePriceEUR),
            kindKey: bundlePriceEUR <= 0 ? AccessKind.free.localizationKey : AccessKind.paid.localizationKey,
            note: access?.note,
            group: access?.group,
            tags: access?.tags ?? []
        )
    }
}

extension Tutorial: AccessDescribing {
    /// `Tutorial` are deja `tags: [String]` si `category: String` proprii.
    /// Decizie explicita a lui Cristi (2026-09-11): raman NESCHIMBATE, iar
    /// etichetele din `access` le COMPLETEAZA, nu le inlocuiesc — de aceea
    /// cele doua liste se reunesc aici, fara duplicate, pastrand ordinea.
    public var resolvedAccess: ResolvedAccess {
        var merged = tags
        for tag in access?.tags ?? [] where !merged.contains(tag) {
            merged.append(tag)
        }
        return ResolvedAccess(
            isFree: access?.kind?.isFree,
            priceDisplay: CatalogAccess.formatPrice(access?.referencePriceEUR),
            kindKey: access?.kind?.localizationKey,
            note: access?.note,
            group: access?.group,
            tags: merged
        )
    }
}

// Fara camp nativ de pret/gratuit — folosesc implementarea implicita
// (pasul 2 al precedentei): totul vine din `access`.
extension AudioTrack: AccessDescribing {}
extension EducationalResource: AccessDescribing {}
extension Event: AccessDescribing {}
extension ServiceCenter: AccessDescribing {}
extension PartnerStore: AccessDescribing {}
extension PartnerOffer: AccessDescribing {}
