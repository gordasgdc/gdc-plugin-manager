import SwiftUI
import GDCPluginManagerCore

// MARK: - Bara de filtre + badge-uri, UNICE pentru tot catalogul (2026-09-11)
//
// Inainte de refactorizarea asta, `ContentView.swift` avea 14 aparitii de
// `PriceFilter`/`OSFilter` imprastiate prin sectiuni, fiecare cu propriul
// `@State` si propriul `Picker` copiat. Aici traiesc o singura data.
//
// Filtrarea lucreaza EXCLUSIV pe `ResolvedAccess` (vezi CatalogAccess.swift),
// deci nicio sectiune nu mai decide singura ce inseamna „gratuit" — regula de
// precedenta e aplicata o singura data, in Core.

/// Ce filtre arata bara intr-o anumita sectiune. Nu toate au sens peste tot
/// (un eveniment n-are platforma), deci fiecare sectiune cere ce-i trebuie.
struct CatalogFilterOptions: OptionSet {
    let rawValue: Int
    static let price    = CatalogFilterOptions(rawValue: 1 << 0)
    static let os       = CatalogFilterOptions(rawValue: 1 << 1)
    static let group    = CatalogFilterOptions(rawValue: 1 << 2)
    static let tags     = CatalogFilterOptions(rawValue: 1 << 3)

    /// Implicit pentru sectiunile de produse (plugin-uri, resurse, aplicatii).
    static let product: CatalogFilterOptions = [.price, .os, .group, .tags]
    /// Pentru continut fara platforma (cursuri, evenimente, materiale…).
    static let content: CatalogFilterOptions = [.price, .group, .tags]
}

enum AccessPriceFilter: String, CaseIterable, Identifiable {
    case all, free, paid
    var id: String { rawValue }
    var label: String {
        switch self {
        case .all: return L.t("filter.price.all")
        case .free: return L.t("filter.price.free")
        case .paid: return L.t("filter.price.paid")
        }
    }
    /// `isFree == nil` inseamna NECUNOSCUT, nu „platit": un element fara
    /// nicio informatie de pret apare doar la „Toate", niciodata clasificat
    /// gresit intr-o categorie in care n-are ce cauta.
    func matches(_ access: ResolvedAccess) -> Bool {
        switch self {
        case .all: return true
        case .free: return access.isFree == true
        case .paid: return access.isFree == false
        }
    }
}

enum AccessOSFilter: String, CaseIterable, Identifiable {
    case all, mac, windows
    var id: String { rawValue }
    var label: String {
        switch self {
        case .all: return L.t("filter.os.all")
        case .mac: return L.t("filter.os.mac")
        case .windows: return L.t("filter.os.windows")
        }
    }
    /// Platforma necunoscuta (`nil`) trece prin orice filtru — fail-open, nu
    /// ascundem un element doar fiindca furnizorul n-a completat campul.
    func matches(_ os: SupportedOS?) -> Bool {
        guard let os else { return true }
        switch self {
        case .all: return true
        case .mac: return os == .macOS || os == .crossPlatform
        case .windows: return os == .windows || os == .crossPlatform
        }
    }
}

enum AccessGroupFilter: Hashable {
    case all
    case group(CatalogGroup)

    var label: String {
        switch self {
        case .all: return L.t("access.group.all")
        case .group(let g): return L.t(g.localizationKey)
        }
    }
    func matches(_ group: CatalogGroup?) -> Bool {
        switch self {
        case .all: return true
        case .group(let g): return group == g
        }
    }
}

/// Starea celor patru filtre + logica de potrivire. Separata de View ca sa
/// poata fi verificata fara UI.
@MainActor final class CatalogFilterState: ObservableObject {
    @Published var price: AccessPriceFilter = .all
    @Published var os: AccessOSFilter = .all
    @Published var group: AccessGroupFilter = .all
    @Published var tag: String = ""

    func matches(_ access: ResolvedAccess) -> Bool {
        price.matches(access)
            && os.matches(access.supportedOS)
            && group.matches(access.group)
            && (tag.isEmpty || access.tags.contains(tag))
    }

    func filter<T: AccessDescribing>(_ items: [T]) -> [T] {
        items.filter { matches($0.resolvedAccess) }
    }
}

/// Bara de filtre propriu-zisa. `availableTags`/`availableGroups` se calculeaza
/// din continutul REAL al sectiunii — un filtru fara nicio valoare nu se
/// afiseaza deloc, ca sa nu ofere alegeri care nu duc nicaieri.
struct CatalogFilterBar: View {
    @ObservedObject var state: CatalogFilterState
    var options: CatalogFilterOptions = .product
    let availableTags: [String]
    let availableGroups: [CatalogGroup]

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                if options.contains(.price) {
                    Picker("", selection: $state.price) {
                        ForEach(AccessPriceFilter.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 260)
                }
                if options.contains(.os) {
                    Picker("", selection: $state.os) {
                        ForEach(AccessOSFilter.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 240)
                }
                Spacer(minLength: 0)
            }
            if showsSecondRow {
                HStack(spacing: 12) {
                    if options.contains(.group) && !availableGroups.isEmpty {
                        Picker("", selection: $state.group) {
                            Text(AccessGroupFilter.all.label).tag(AccessGroupFilter.all)
                            ForEach(availableGroups) { g in
                                Text(L.t(g.localizationKey)).tag(AccessGroupFilter.group(g))
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 420)
                    }
                    if options.contains(.tags) && !availableTags.isEmpty {
                        Picker("", selection: $state.tag) {
                            Text(L.t("access.tag.all")).tag("")
                            ForEach(availableTags, id: \.self) { Text($0).tag($0) }
                        }
                        .labelsHidden()
                        .frame(maxWidth: 220)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var showsSecondRow: Bool {
        (options.contains(.group) && !availableGroups.isEmpty)
            || (options.contains(.tags) && !availableTags.isEmpty)
    }
}

extension CatalogGroup: @retroactive Identifiable {}

// MARK: - Badge-uri reutilizabile

/// Badge-ul de status (GRATUIT / PLĂTIT / TRIAL / EXTERN). Nu afiseaza nimic
/// daca statusul e necunoscut — un card fara informatie ramane curat, nu
/// primeste o eticheta inventata.
struct AccessBadge: View {
    let access: ResolvedAccess

    var body: some View {
        if let key = access.kindKey {
            Text(L.t(key))
                .font(.system(size: 9, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(tint)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(tint.opacity(0.15)))
        }
    }

    /// Culoare SEMANTICA (verde = gratuit, portocaliu = trial), separata de
    /// accentul aplicatiei — vezi regula de culoare din CLAUDE.md.
    private var tint: Color {
        switch access.kindKey {
        case AccessKind.free.localizationKey: return .green
        case AccessKind.trial.localizationKey: return .orange
        default: return .secondary
        }
    }
}

/// Pretul + avizul liber, sub numele elementului.
struct AccessPriceLabel: View {
    let access: ResolvedAccess

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let price = access.priceDisplay {
                Text(price)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            if let note = access.note, !note.isEmpty {
                Text(note)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }
}

/// Etichetele de domeniu, plafonate vizual (restul raman in filtru).
struct AccessTagsRow: View {
    let tags: [String]
    var limit: Int = 3

    var body: some View {
        if !tags.isEmpty {
            HStack(spacing: 4) {
                ForEach(tags.prefix(limit), id: \.self) { tag in
                    Text(tag)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(.quaternary))
                }
            }
        }
    }
}

// MARK: - Helper pentru colectarea valorilor disponibile

enum CatalogFacets {
    static func tags<T: AccessDescribing>(_ items: [T]) -> [String] {
        Array(Set(items.flatMap { $0.resolvedAccess.tags })).sorted()
    }
    static func groups<T: AccessDescribing>(_ items: [T]) -> [CatalogGroup] {
        let present = Set(items.compactMap { $0.resolvedAccess.group })
        return CatalogGroup.allCases.filter { present.contains($0) }
    }
}

/// Invelisul standard al unei sectiuni: bara de filtre sus, continutul
/// filtrat dedesubt. Fiecare grid din `ContentView` il foloseste, ca sa nu
/// mai copieze `@State`-ul si `Picker`-ele — exact duplicarea eliminata de
/// refactorizarea din 2026-09-11.
struct FilteredCatalogSection<T: AccessDescribing, Content: View>: View {
    let items: [T]
    var options: CatalogFilterOptions = .product
    var emptyTextKey: String = "access.filter.none"
    @ViewBuilder var content: ([T]) -> Content

    @StateObject private var filters = CatalogFilterState()

    private var filtered: [T] { filters.filter(items) }

    var body: some View {
        VStack(spacing: 0) {
            // Bara nu apare deloc daca sectiunea n-are din ce filtra — o
            // bara cu o singura optiune e zgomot, nu functionalitate.
            if hasAnythingToFilter {
                CatalogFilterBar(
                    state: filters,
                    options: options,
                    availableTags: CatalogFacets.tags(items),
                    availableGroups: CatalogFacets.groups(items)
                )
                Divider()
            }
            if !items.isEmpty && filtered.isEmpty {
                ScrollView {
                    Text(L.t(emptyTextKey)).foregroundStyle(.secondary).padding(40)
                }
            } else {
                content(filtered)
            }
        }
    }

    private var hasAnythingToFilter: Bool {
        guard !items.isEmpty else { return false }
        let accesses = items.map(\.resolvedAccess)
        let hasPrice = options.contains(.price) && accesses.contains { $0.isFree != nil }
        let hasOS = options.contains(.os) && accesses.contains { $0.supportedOS != nil }
        let hasGroup = options.contains(.group) && !CatalogFacets.groups(items).isEmpty
        let hasTags = options.contains(.tags) && !CatalogFacets.tags(items).isEmpty
        return hasPrice || hasOS || hasGroup || hasTags
    }
}
