import SwiftUI
import AppKit
import GDCPluginManagerCore

/// Rezultate unificate ale căutării globale — combină toate cele 8
/// colecții din catalog, fiecare filtrată cu `FuzzySearch` pe câmpurile ei
/// relevante. O secțiune nu se afișează deloc dacă n-are niciun rezultat.
struct GlobalSearchResults: View {
    @ObservedObject var catalog: CatalogService
    let query: String

    // Etapa 4 extinsă (2026-08-29): rezultatele de căutare respectă
    // valabilitatea temporală în TOATE colecțiile, nu doar Cursuri/
    // Evenimente/Materiale/Oferte — un produs/aplicație/resursă expirată
    // sau neînceput încă nu trebuie să apară nici prin căutare globală.
    private var matchedItems: [PluginItem] {
        (catalog.items + catalog.scriptItems).filter { ($0.scheduling?.isActiveNow ?? true) && FuzzySearch.matches(query: query, inAny: [$0.name, $0.description, $0.id, $0.type.label]) }
    }
    private var matchedApps: [AppLink] {
        catalog.apps.filter { ($0.scheduling?.isActiveNow ?? true) && FuzzySearch.matches(query: query, inAny: [$0.name, $0.id]) }
    }
    private var matchedCourses: [Course] {
        catalog.courses.filter { ($0.scheduling?.isActiveNow ?? true) && FuzzySearch.matches(query: query, inAny: [$0.name, $0.description, $0.id]) }
    }
    private var matchedAudio: [AudioTrack] {
        catalog.audioTracks.filter { ($0.scheduling?.isActiveNow ?? true) && FuzzySearch.matches(query: query, inAny: [$0.name, $0.description, $0.id]) }
    }
    private var matchedEvents: [Event] {
        catalog.events.filter { ($0.scheduling?.isActiveNow ?? true) && FuzzySearch.matches(query: query, inAny: [$0.title, $0.description, $0.location, $0.id]) }
    }
    private var matchedResources: [EducationalResource] {
        catalog.educationalResources.filter { ($0.scheduling?.isActiveNow ?? true) && FuzzySearch.matches(query: query, inAny: [$0.name, $0.description, $0.kind.label, $0.id]) }
    }
    private var matchedTutorials: [Tutorial] {
        catalog.tutorials.filter { ($0.scheduling?.isActiveNow ?? true) && FuzzySearch.matches(query: query, inAny: [$0.title, $0.description, $0.category, $0.id] + $0.tags) }
    }
    private var matchedOffers: [PartnerOffer] {
        catalog.partnerOffers.filter { ($0.scheduling?.isActiveNow ?? true) && FuzzySearch.matches(query: query, inAny: [$0.brandName, $0.description, $0.id, $0.couponCode]) }
    }
    private var matchedStores: [PartnerStore] {
        catalog.partnerStores.filter { ($0.scheduling?.isActiveNow ?? true) && FuzzySearch.matches(query: query, inAny: [$0.name, $0.description, $0.id]) }
    }
    private var matchedCenters: [ServiceCenter] {
        catalog.serviceCenters.filter { ($0.scheduling?.isActiveNow ?? true) && FuzzySearch.matches(query: query, inAny: [$0.name, $0.specialization, serviceCategoryLabel($0.category), $0.id]) }
    }
    private var matchedDownloads: [DownloadableResource] {
        (catalog.downloadableResources + catalog.pdfResources + catalog.scriptResources).filter { ($0.scheduling?.isActiveNow ?? true) && FuzzySearch.matches(query: query, inAny: [$0.name, $0.description, $0.id, $0.category.rawValue]) }
    }
    private var matchedBundles: [ProductBundle] {
        catalog.productBundles.filter { ($0.scheduling?.isActiveNow ?? true) && FuzzySearch.matches(query: query, inAny: [$0.name, $0.description, $0.id]) }
    }

    private var totalMatches: Int {
        matchedItems.count + matchedApps.count + matchedCourses.count + matchedAudio.count
            + matchedEvents.count + matchedResources.count + matchedTutorials.count + matchedStores.count + matchedCenters.count
            + matchedDownloads.count + matchedOffers.count + matchedBundles.count
    }

    private let productColumns = [GridItem(.adaptive(minimum: 240, maximum: 300), spacing: 14)]
    private let wideColumns = [GridItem(.adaptive(minimum: 260, maximum: 340), spacing: 14)]

    var body: some View {
        ScrollView {
            if totalMatches == 0 {
                Text(L.t("search.noResults")).foregroundStyle(.secondary).padding(40)
            } else {
                VStack(alignment: .leading, spacing: 20) {
                    section(title: L.t("sidebar.all"), isEmpty: matchedItems.isEmpty) {
                        LazyVGrid(columns: productColumns, spacing: 14) {
                            ForEach(matchedItems) { PluginCard(item: $0) }
                        }
                    }
                    section(title: L.t("sidebar.apps"), isEmpty: matchedApps.isEmpty) {
                        LazyVGrid(columns: wideColumns, spacing: 14) {
                            ForEach(matchedApps) { AppCard(app: $0) }
                        }
                    }
                    section(title: L.t("sidebar.audio"), isEmpty: matchedAudio.isEmpty) {
                        LazyVGrid(columns: wideColumns, spacing: 14) {
                            ForEach(matchedAudio) { AudioCard(track: $0) }
                        }
                    }
                    section(title: L.t("sidebar.courses"), isEmpty: matchedCourses.isEmpty) {
                        LazyVGrid(columns: wideColumns, spacing: 14) {
                            ForEach(matchedCourses) { CourseCard(course: $0) }
                        }
                    }
                    section(title: L.t("sidebar.educationalResources"), isEmpty: matchedResources.isEmpty) {
                        LazyVGrid(columns: wideColumns, spacing: 14) {
                            ForEach(matchedResources) { EducationalResourceCard(resource: $0) }
                        }
                    }
                    section(title: L.t("sidebar.tutorials"), isEmpty: matchedTutorials.isEmpty) {
                        LazyVGrid(columns: wideColumns, spacing: 14) {
                            ForEach(matchedTutorials) { TutorialCard(tutorial: $0) }
                        }
                    }
                    section(title: L.t("sidebar.events"), isEmpty: matchedEvents.isEmpty) {
                        LazyVGrid(columns: wideColumns, spacing: 14) {
                            ForEach(matchedEvents) { EventCard(event: $0) }
                        }
                    }
                    section(title: L.t("sidebar.partnerOffers"), isEmpty: matchedOffers.isEmpty) {
                        LazyVGrid(columns: wideColumns, spacing: 14) {
                            ForEach(matchedOffers) { PartnerOfferCard(offer: $0) }
                        }
                    }
                    section(title: L.t("sidebar.bundles"), isEmpty: matchedBundles.isEmpty) {
                        LazyVGrid(columns: wideColumns, spacing: 14) {
                            ForEach(matchedBundles) { BundleCard(bundle: $0, catalog: catalog) }
                        }
                    }
                    section(title: L.t("sidebar.partnerStores"), isEmpty: matchedStores.isEmpty) {
                        LazyVGrid(columns: wideColumns, spacing: 14) {
                            ForEach(matchedStores) { PartnerStoreCard(store: $0) }
                        }
                    }
                    section(title: L.t("sidebar.serviceCenters"), isEmpty: matchedCenters.isEmpty) {
                        LazyVGrid(columns: wideColumns, spacing: 14) {
                            ForEach(matchedCenters) { ServiceCenterCard(center: $0) }
                        }
                    }
                    ForEach(DownloadCategory.allCases) { category in
                        let matches = matchedDownloads.filter { $0.category == category }
                        section(title: L.t("sidebar.download.\(category.rawValue)"), isEmpty: matches.isEmpty) {
                            LazyVGrid(columns: wideColumns, spacing: 14) {
                                ForEach(matches) { DownloadResourceCard(resource: $0) }
                            }
                        }
                    }
                }
                .padding(16)
            }
        }
    }

    @ViewBuilder
    private func section<Content: View>(title: String, isEmpty: Bool, @ViewBuilder content: () -> Content) -> some View {
        if !isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(.headline).foregroundStyle(.secondary)
                content()
            }
        }
    }
}
