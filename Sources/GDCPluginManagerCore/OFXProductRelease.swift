import Foundation

// [2026-10-04] Produse OFX GDC STYLE Lab V3 (un produs comercial = 4 variante de pipeline × 2 ediții, Demo + Full).
// Contractul vine din GDC STYLE Lab (contractul de identitate a produsului + App/Sources/UI/V3/InstallIdentity.swift,
// ProductInstall.swift). `OFXIdentity` de mai jos e o COPIE a referinței de acolo (aceleași reguli R1–R8, aceiași vectori de
// conformanță: Tests/GDCPluginManagerCoreTests/Fixtures/ofx_install_identity.v1.json). O schimbare de regulă se face ÎNTÂI
// în STYLE Lab (referința), apoi se copiază aici împreună cu vectorii.

/// IDENTITATEA CANONICĂ a unui pachet OFX GDC instalat: CFBundleIdentifier (citit din Info.plist), NICIODATĂ numele folderului.
/// SLOT = identificatorul fără sufixul de ediție: un slot are cel mult un ocupant pe disc (același instrument pe același pipeline
/// nu apare de două ori în Resolve).
public enum OFXIdentity {
    public enum Generation: String, Equatable { case v3, v2, opaque }
    public enum Edition: String, Equatable, Codable, CaseIterable { case full, demo }

    public struct Parsed: Equatable {
        public let generation: Generation
        public let product: String
        public let variant: String
        public let edition: Edition?
        public let slot: String
    }

    public struct Package: Equatable {
        public let identifier: String
        public let folder: String
        public let version: String?
        public init(identifier: String, folder: String, version: String?) { self.identifier = identifier; self.folder = folder; self.version = version }
    }

    public enum Mode: String, Equatable { case distribution, authoring }
    public enum Refusal: String, Equatable { case downgrade, demoOverFull }

    public enum Action: Equatable {
        case install, upgrade, replace, keep
        case refuse(Refusal)
        public var code: String {
            switch self {
            case .install: return "install"
            case .upgrade: return "upgrade"
            case .replace: return "replace"
            case .keep: return "keep"
            case .refuse(let r): return "refuse:\(r.rawValue)"
            }
        }
    }

    public struct Decision: Equatable {
        public let action: Action
        public let write: String?
        public let remove: [String]
    }

    private static func isToken(_ s: String) -> Bool {
        !s.isEmpty && s.unicodeScalars.allSatisfy { ($0.value >= 97 && $0.value <= 122) || ($0.value >= 48 && $0.value <= 57) || $0 == "-" }
    }

    public static func parse(_ identifier: String) -> Parsed {
        let opaque = Parsed(generation: .opaque, product: identifier, variant: "", edition: nil, slot: identifier)
        let prefix = "dev.gordas.style."
        guard identifier.hasPrefix(prefix) else { return opaque }
        let rest = identifier.dropFirst(prefix.count).split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        if rest.count == 4, rest[0] == "v3", isToken(rest[1]), isToken(rest[2]), let e = Edition(rawValue: rest[3]) {
            return Parsed(generation: .v3, product: rest[1], variant: rest[2], edition: e, slot: prefix + "v3." + rest[1] + "." + rest[2])
        }
        if rest.count == 5, rest[0] == "v2", rest[1].count == 4, rest[1].hasPrefix("m"), rest[1].dropFirst().allSatisfy(\.isNumber), isToken(rest[2]), isToken(rest[3]), let e = Edition(rawValue: rest[4]) {
            return Parsed(generation: .v2, product: rest[1] + "." + rest[2], variant: rest[3], edition: e, slot: prefix + "v2." + rest[1] + "." + rest[2] + "." + rest[3])
        }
        return opaque
    }

    /// −1 / 0 / 1; versiune necunoscută (nil) = mai veche decât orice.
    public static func compareVersions(_ a: String?, _ b: String?) -> Int {
        guard let a else { return b == nil ? 0 : -1 }
        guard let b else { return 1 }
        func parts(_ s: String) -> [Int] { s.split(separator: "-").first.map { $0.split(separator: ".").map { Int($0) ?? 0 } } ?? [] }
        let x = parts(a), y = parts(b)
        for i in 0..<max(x.count, y.count) {
            let p = i < x.count ? x[i] : 0, q = i < y.count ? y[i] : 0
            if p != q { return p < q ? -1 : 1 }
        }
        return 0
    }

    public static func decide(incoming: Package, installed: [Package], mode: Mode) -> Decision {
        let inc = parse(incoming.identifier)
        let occupants = installed.filter { parse($0.identifier).slot == inc.slot }
        func unique(_ xs: [String]) -> [String] { var seen = Set<String>(); return xs.filter { seen.insert($0).inserted } }
        if occupants.isEmpty { return Decision(action: .install, write: incoming.folder, remove: []) }                       // R1
        if inc.edition == .demo, occupants.contains(where: { parse($0.identifier).edition == .full }) {                      // R6
            return Decision(action: .refuse(.demoOverFull), write: nil, remove: [])
        }
        let same = occupants.filter { $0.identifier == incoming.identifier }
        let others = occupants.filter { $0.identifier != incoming.identifier }
        let bestSame = same.max { compareVersions($0.version, $1.version) < 0 }
        if mode == .distribution, let b = bestSame, compareVersions(incoming.version, b.version) < 0 {                      // R3
            return Decision(action: .refuse(.downgrade), write: nil, remove: [])
        }
        if same.count == 1, others.isEmpty {
            let o = same[0]
            let cmp = compareVersions(incoming.version, o.version)
            if o.folder == incoming.folder {
                return cmp == 0 ? Decision(action: .keep, write: nil, remove: []) : Decision(action: .upgrade, write: incoming.folder, remove: [])   // R2 / R4
            }
            return Decision(action: .replace, write: incoming.folder, remove: [o.folder])                                      // R5
        }
        return Decision(action: .replace, write: incoming.folder, remove: unique(occupants.map(\.folder).filter { $0 != incoming.folder }))   // R6 / R7
    }

    public static func removal(generation: Generation, product: String, variants: [String]?, installed: [Package]) -> [String] {
        var seen = Set<String>()
        return installed.filter { b in
            let p = parse(b.identifier)
            guard p.generation == generation, p.product == product else { return false }
            return variants.map { $0.contains(p.variant) } ?? true
        }.map(\.folder).filter { seen.insert($0).inserted }.sorted()
    }

    /// Pachetele OFX instalate într-un folder (implicit /Library/OFX/Plugins), cu identitatea din Info.plist. Recursiv pe 3 niveluri
    /// (o copie imbricată într-un dosar de release e tot încărcată de Resolve), fără a coborî ÎN pachete. Pachetele fără
    /// CFBundleIdentifier se ignoră (nu pot fi clasificate, deci nu se ating).
    public static func scanInstalled(root: URL, maxDepth: Int = 3) -> [Package] {
        var out: [Package] = []
        func walk(_ dir: URL, depth: Int, relative: String) {
            guard depth <= maxDepth, let items = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else { return }
            for u in items where (try? u.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true {
                let rel = relative.isEmpty ? u.lastPathComponent : relative + "/" + u.lastPathComponent
                if u.lastPathComponent.hasSuffix(".ofx.bundle") {
                    let plist = u.appendingPathComponent("Contents/Info.plist")
                    guard let d = NSDictionary(contentsOf: plist), let id = d["CFBundleIdentifier"] as? String, !id.isEmpty else { continue }
                    out.append(Package(identifier: id, folder: rel, version: d["CFBundleShortVersionString"] as? String))
                } else {
                    walk(u, depth: depth + 1, relative: rel)
                }
            }
        }
        walk(root, depth: 1, relative: "")
        return out.sorted { $0.folder < $1.folder }
    }
}

/// Câmpul de catalog al unui PRODUS OFX GDC STYLE Lab V3 (`PluginItem.ofxProduct`): un singur item de catalog per produs comercial
/// (Product ID = identitatea de licență), cu variantele de pipeline și edițiile lor. Fișierele itemului stau în
/// `<productId>/<version>/<Full|Demo>/<folder pachet>/…`; `root` al fiecărei ediții = acel prefix. Construit de Furnizor din
/// manifestul `gdc-product-release@1` scris de GDC STYLE Lab — Furnizor și Plugin Manager nu inventează identități.
/// Un client vechi (fără câmp) vede un OFX cu multe fișiere și ar încerca instalarea într-un folder numit după id — eșuează sigur
/// la verificarea Info.plist, fără să atingă alte pachete.
public struct OFXProductRelease: Codable, Hashable {
    public static let schemaID = "gdc-ofx-product@1"

    public struct EditionPackage: Codable, Hashable {
        public let folder: String       // numele folderului .ofx.bundle din /Library/OFX/Plugins (canonic)
        public let identifier: String   // CFBundleIdentifier
        public let root: String         // prefixul fișierelor în repo: „<productId>/<version>/<Full|Demo>/<folder>”
        public init(folder: String, identifier: String, root: String) { self.folder = folder; self.identifier = identifier; self.root = root }
    }

    public struct Variant: Codable, Hashable {
        public let variantId: String    // „ap1-acescct”
        public let family: String       // „ACES”
        public let label: String
        public let slot: String         // identificatorul fără ediție
        public let editions: [String: EditionPackage]   // „full” / „demo”
        public init(variantId: String, family: String, label: String, slot: String, editions: [String: EditionPackage]) {
            self.variantId = variantId; self.family = family; self.label = label; self.slot = slot; self.editions = editions
        }
        public func package(_ e: OFXIdentity.Edition) -> EditionPackage? { editions[e.rawValue] }
    }

    public struct Placement: Codable, Hashable {
        public let orderKey: Int
        public let stage: String        // „linear” / „log” / „film”
        public init(orderKey: Int, stage: String) { self.orderKey = orderKey; self.stage = stage }
    }

    public let schema: String
    public let productId: String
    public let instrument: String       // slug-ul V3 („film”)
    public let version: String
    public let variants: [Variant]
    public let placement: Placement?

    public init(productId: String, instrument: String, version: String, variants: [Variant], placement: Placement?) {
        self.schema = Self.schemaID; self.productId = productId; self.instrument = instrument; self.version = version; self.variants = variants; self.placement = placement
    }

    public enum ValidationError: Error, Equatable { case schema(String), invalid(String) }

    /// Validarea completă (folosită de Furnizor la publicare și de client înainte de orice scriere): aceleași reguli ca
    /// `DistributionManifest.parse` din STYLE Lab, plus forma căilor din repo.
    public func validate(itemID: String, itemVersion: String) -> ValidationError? {
        guard schema == Self.schemaID else { return .schema(schema) }
        guard productId == itemID else { return .invalid("productId \(productId) ≠ id-ul itemului \(itemID)") }
        guard productId == "gdc-style-v3-" + instrument else { return .invalid("productId \(productId) ≠ gdc-style-v3-\(instrument)") }
        guard version == itemVersion else { return .invalid("versiunea produsului \(version) ≠ versiunea itemului \(itemVersion)") }
        guard !variants.isEmpty else { return .invalid("fără variante") }
        var seenVariants = Set<String>(), seenFolders = Set<String>()
        for v in variants {
            guard seenVariants.insert(v.variantId).inserted else { return .invalid("variantă dublă \(v.variantId)") }
            guard !v.editions.isEmpty else { return .invalid("varianta \(v.variantId) fără ediții") }
            for (k, p) in v.editions {
                guard let e = OFXIdentity.Edition(rawValue: k) else { return .invalid("ediție necunoscută \(k)") }
                let parsed = OFXIdentity.parse(p.identifier)
                guard parsed.generation == .v3, parsed.product == instrument, parsed.variant == v.variantId, parsed.edition == e, parsed.slot == v.slot
                else { return .invalid("identificator \(p.identifier) ≠ \(instrument)/\(v.variantId)/\(k)") }
                let f = p.folder
                guard f.hasSuffix(".ofx.bundle"), !f.contains("/"), !f.contains("\\"), !f.hasPrefix("."), f != ".."
                else { return .invalid("folder nevalid \(f)") }
                guard seenFolders.insert(f).inserted else { return .invalid("folder dublu \(f)") }
                let sub = e == .full ? "Full" : "Demo"
                guard p.root == "\(productId)/\(version)/\(sub)/\(f)" else { return .invalid("root \(p.root)") }
            }
        }
        return nil
    }

    /// Ediția gratuită (fără serial) = Demo. Calea unui fișier aparține ediției Demo dacă începe cu rădăcina unui pachet Demo.
    public func isDemoPath(_ path: String) -> Bool {
        variants.contains { v in v.package(.demo).map { path.hasPrefix($0.root + "/") } ?? false }
    }
}

/// Planul de instalare al unui produs OFX V3 în Plugin Manager (mod `distribution`: nu coboară versiunea, nu pune Demo peste Full).
public enum OFXProductInstall {
    public enum Selection: Equatable { case all, variants([String]) }
    public enum PlanError: Error, Equatable { case empty, unknownVariant(String), editionMissing(String) }

    public struct VariantDecision: Equatable {
        public let variantId: String
        public let package: OFXProductRelease.EditionPackage
        public let decision: OFXIdentity.Decision
    }

    public struct Plan: Equatable {
        public let edition: OFXIdentity.Edition
        public let decisions: [VariantDecision]
        public var writes: [VariantDecision] { decisions.filter { $0.decision.write != nil } }
        public var removals: [String] { var seen = Set<String>(); return decisions.flatMap(\.decision.remove).filter { seen.insert($0).inserted } }
        public var refusals: [VariantDecision] { decisions.filter { if case .refuse = $0.decision.action { return true } else { return false } } }
        public var isNoop: Bool { decisions.allSatisfy { $0.decision.write == nil && $0.decision.remove.isEmpty } }
    }

    public static func install(_ r: OFXProductRelease, edition: OFXIdentity.Edition, selection: Selection = .all, installed: [OFXIdentity.Package]) -> Result<Plan, PlanError> {
        let chosen: [OFXProductRelease.Variant]
        switch selection {
        case .all: chosen = r.variants
        case .variants(let ids):
            if ids.isEmpty { return .failure(.empty) }
            for id in ids where !r.variants.contains(where: { $0.variantId == id }) { return .failure(.unknownVariant(id)) }
            chosen = r.variants.filter { ids.contains($0.variantId) }
        }
        guard !chosen.isEmpty else { return .failure(.empty) }
        var out: [VariantDecision] = []
        for v in chosen {
            guard let p = v.package(edition) else { return .failure(.editionMissing(v.variantId)) }
            let inc = OFXIdentity.Package(identifier: p.identifier, folder: p.folder, version: r.version)
            out.append(VariantDecision(variantId: v.variantId, package: p, decision: OFXIdentity.decide(incoming: inc, installed: installed, mode: .distribution)))
        }
        return .success(Plan(edition: edition, decisions: out))
    }

    /// Ce ediție instalează clientul: Full dacă are serial pentru produs SAU un Full e deja instalat (un Full nu se degradează);
    /// altfel Demo (gratuit, cu filigran). Licența rămâne a produsului: activarea se face în instrument.
    public static func edition(hasSerial: Bool, r: OFXProductRelease, installed: [OFXIdentity.Package]) -> OFXIdentity.Edition {
        if hasSerial { return .full }
        let fullInstalled = installed.contains { p in
            let q = OFXIdentity.parse(p.identifier); return q.generation == .v3 && q.product == r.instrument && q.edition == .full
        }
        return fullInstalled ? .full : .demo
    }

    /// Variantele pe care le are deja produsul pe disc (orice ediție) — actualizarea atinge doar acestea.
    public static func installedVariants(_ r: OFXProductRelease, installed: [OFXIdentity.Package]) -> [String] {
        r.variants.filter { v in installed.contains { OFXIdentity.parse($0.identifier).slot == v.slot } }.map(\.variantId)
    }

    /// Versiunea instalată a produsului = cea mai mică dintre variantele prezente (o variantă rămasă în urmă cere actualizare).
    public static func installedVersion(_ r: OFXProductRelease, installed: [OFXIdentity.Package]) -> String? {
        let vs = installed.filter { p in let q = OFXIdentity.parse(p.identifier); return q.generation == .v3 && q.product == r.instrument }.map(\.version)
        guard !vs.isEmpty else { return nil }
        return vs.min { OFXIdentity.compareVersions($0, $1) < 0 } ?? nil
    }

    public static func removal(_ r: OFXProductRelease, installed: [OFXIdentity.Package]) -> [String] {
        OFXIdentity.removal(generation: .v3, product: r.instrument, variants: nil, installed: installed)
    }
}
