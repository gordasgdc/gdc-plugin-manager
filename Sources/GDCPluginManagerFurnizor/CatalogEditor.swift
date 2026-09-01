import Foundation
import GDCPluginManagerCore

enum CatalogEditorError: Error, LocalizedError {
    case itemNotFound(String)
    case courseNotFound(String)
    case appNotFound(String)
    case audioTrackNotFound(String)
    case educationalResourceNotFound(String)
    case eventNotFound(String)
    case partnerStoreNotFound(String)
    case serviceCenterNotFound(String)
    case downloadableResourceNotFound(String)
    case partnerOfferNotFound(String)
    case bundleNotFound(String)
    case tutorialNotFound(String)

    var errorDescription: String? {
        switch self {
        case .itemNotFound(let id): return "Nu există niciun produs cu id-ul „\(id)” în catalog."
        case .courseNotFound(let id): return "Nu există niciun curs cu id-ul „\(id)” în catalog."
        case .appNotFound(let id): return "Nu există nicio aplicație cu id-ul „\(id)” în catalog."
        case .audioTrackNotFound(let id): return "Nu există niciun element audio cu id-ul „\(id)” în catalog."
        case .educationalResourceNotFound(let id): return "Nu există niciun material cu id-ul „\(id)” în catalog."
        case .eventNotFound(let id): return "Nu există niciun eveniment cu id-ul „\(id)” în catalog."
        case .partnerStoreNotFound(let id): return "Nu există niciun magazin cu id-ul „\(id)” în catalog."
        case .serviceCenterNotFound(let id): return "Nu există niciun service cu id-ul „\(id)” în catalog."
        case .downloadableResourceNotFound(let id): return "Nu există nicio resursă de download cu id-ul „\(id)” în catalog."
        case .partnerOfferNotFound(let id): return "Nu există nicio ofertă parteneră cu id-ul „\(id)” în catalog."
        case .bundleNotFound(let id): return "Nu există niciun pachet cu id-ul „\(id)” în catalog."
        case .tutorialNotFound(let id): return "Nu există niciun tutorial cu id-ul „\(id)” în catalog."
        }
    }
}

/// Reads/writes docs/catalog.json in the local public-repo checkout —
/// the same file the client app fetches (unauthenticated) from GitHub
/// Pages. Only this file is touched in that checkout; app source lives
/// in a separate working tree entirely (see RepoCheckoutPaths).
enum CatalogEditor {
    /// BUG REAL, GRAV (2026-08-31): pana acum, `upsert*`/`setSeasonalBackgrounds`
    /// foloseau `(try? load()) ?? Catalog(items: [])` — daca `docs/catalog.json`
    /// lipsea de pe disc (unelte de "curatare" precum CleanMyMac stergeau tot
    /// folderul `docs/`, vezi CLAUDE.md), `load()` arunca, `try?` inghitea
    /// eroarea TACUT, iar publicarea urmatoare rescria fisierul de la zero cu
    /// DOAR itemul curent — stergand ireversibil (dupa push) toate celelalte
    /// produse/aplicatii/evenimente/etc. Asa au disparut produse reale
    /// publicate anterior, fara nicio eroare aratata furnizorului.
    /// Fix, doua parti: (1) daca fisierul lipseste, incearca intai
    /// auto-recuperare din git (acelasi remediu aplicat manual, repetat, in
    /// aceasta sesiune) inainte de a ceda; (2) daca tot esueaza (git lipseste,
    /// checkout corupt etc.), ARUNCA eroarea mai departe — niciun apelant nu
    /// mai are voie sa o transforme in "catalog gol", publicarea trebuie sa
    /// esueze vizibil (eroare in UI), nu sa stearga tacut restul catalogului.
    static func load() throws -> Catalog {
        if !FileManager.default.fileExists(atPath: RepoCheckoutPaths.catalogJSONURL.path) {
            try? GitOps.run(["checkout", "--", "docs/"], at: RepoCheckoutPaths.publicCatalogRepo)
        }
        let data = try Data(contentsOf: RepoCheckoutPaths.catalogJSONURL)
        return try JSONDecoder().decode(Catalog.self, from: data)
    }

    // MARK: - Products (PluginItem)

    /// Adds a new item, or replaces the existing one with the same `id`
    /// (an update — id, and therefore its crypto product hash, never
    /// changes). Updates `updatedAt` to today.
    static func upsert(_ item: PluginItem) throws {
        let catalog = try load()
        var items = catalog.items.filter { $0.id != item.id }
        items.append(item)
        items.sort { $0.name < $1.name }
        try write(catalog: catalog, items: items)
    }

    /// Removes an item entirely — for a product published by mistake, or
    /// pulled from sale. Does NOT touch the files in the private repo;
    /// callers that also want those gone should remove that folder
    /// themselves (see PublishView.deleteProduct).
    static func remove(id: String) throws {
        let catalog = try load()
        let items = catalog.items.filter { $0.id != id }
        guard items.count != catalog.items.count else {
            throw CatalogEditorError.itemNotFound(id)
        }
        try write(catalog: catalog, items: items)
    }

    // MARK: - Courses

    static func upsertCourse(_ course: Course) throws {
        let catalog = try load()
        var courses = catalog.courses.filter { $0.id != course.id }
        courses.append(course)
        courses.sort { $0.name < $1.name }
        try write(catalog: catalog, courses: courses)
    }

    static func removeCourse(id: String) throws {
        let catalog = try load()
        let courses = catalog.courses.filter { $0.id != id }
        guard courses.count != catalog.courses.count else {
            throw CatalogEditorError.courseNotFound(id)
        }
        try write(catalog: catalog, courses: courses)
    }

    // MARK: - App links

    static func upsertApp(_ app: AppLink) throws {
        let catalog = try load()
        var apps = catalog.apps.filter { $0.id != app.id }
        apps.append(app)
        apps.sort { $0.name < $1.name }
        try write(catalog: catalog, apps: apps)
    }

    static func removeApp(id: String) throws {
        let catalog = try load()
        let apps = catalog.apps.filter { $0.id != id }
        guard apps.count != catalog.apps.count else {
            throw CatalogEditorError.appNotFound(id)
        }
        try write(catalog: catalog, apps: apps)
    }

    // MARK: - Audio (secțiunea "Audio", modelată pe Aplicații)

    static func upsertAudioTrack(_ track: AudioTrack) throws {
        let catalog = try load()
        var audioTracks = catalog.audioTracks.filter { $0.id != track.id }
        audioTracks.append(track)
        audioTracks.sort { $0.name < $1.name }
        try write(catalog: catalog, audioTracks: audioTracks)
    }

    static func removeAudioTrack(id: String) throws {
        let catalog = try load()
        let audioTracks = catalog.audioTracks.filter { $0.id != id }
        guard audioTracks.count != catalog.audioTracks.count else {
            throw CatalogEditorError.audioTrackNotFound(id)
        }
        try write(catalog: catalog, audioTracks: audioTracks)
    }

    // MARK: - Educational resources (books / online courses / guides sold externally)

    static func upsertEducationalResource(_ resource: EducationalResource) throws {
        let catalog = try load()
        var resources = catalog.educationalResources.filter { $0.id != resource.id }
        resources.append(resource)
        resources.sort { $0.name < $1.name }
        try write(catalog: catalog, educationalResources: resources)
    }

    static func removeEducationalResource(id: String) throws {
        let catalog = try load()
        let resources = catalog.educationalResources.filter { $0.id != id }
        guard resources.count != catalog.educationalResources.count else {
            throw CatalogEditorError.educationalResourceNotFound(id)
        }
        try write(catalog: catalog, educationalResources: resources)
    }

    // MARK: - Events (workshops, cohorts, festivals)

    static func upsertEvent(_ event: Event) throws {
        let catalog = try load()
        var events = catalog.events.filter { $0.id != event.id }
        events.append(event)
        events.sort { $0.title < $1.title }
        try write(catalog: catalog, events: events)
    }

    static func removeEvent(id: String) throws {
        let catalog = try load()
        let events = catalog.events.filter { $0.id != id }
        guard events.count != catalog.events.count else {
            throw CatalogEditorError.eventNotFound(id)
        }
        try write(catalog: catalog, events: events)
    }

    // MARK: - Partner stores

    static func upsertPartnerStore(_ store: PartnerStore) throws {
        let catalog = try load()
        var stores = catalog.partnerStores.filter { $0.id != store.id }
        stores.append(store)
        stores.sort { $0.name < $1.name }
        try write(catalog: catalog, partnerStores: stores)
    }

    static func removePartnerStore(id: String) throws {
        let catalog = try load()
        let stores = catalog.partnerStores.filter { $0.id != id }
        guard stores.count != catalog.partnerStores.count else {
            throw CatalogEditorError.partnerStoreNotFound(id)
        }
        try write(catalog: catalog, partnerStores: stores)
    }

    // MARK: - Service centers (Service & Reparații Echipament)

    static func upsertServiceCenter(_ center: ServiceCenter) throws {
        let catalog = try load()
        var centers = catalog.serviceCenters.filter { $0.id != center.id }
        centers.append(center)
        centers.sort { $0.name < $1.name }
        try write(catalog: catalog, serviceCenters: centers)
    }

    static func removeServiceCenter(id: String) throws {
        let catalog = try load()
        let centers = catalog.serviceCenters.filter { $0.id != id }
        guard centers.count != catalog.serviceCenters.count else {
            throw CatalogEditorError.serviceCenterNotFound(id)
        }
        try write(catalog: catalog, serviceCenters: centers)
    }

    // MARK: - Downloadable resources (LUT/SFX/VFX/Plugin — download direct, Etapa 2)

    static func upsertDownloadableResource(_ resource: DownloadableResource) throws {
        let catalog = try load()
        var resources = catalog.downloadableResources.filter { $0.id != resource.id }
        resources.append(resource)
        resources.sort { $0.name < $1.name }
        try write(catalog: catalog, downloadableResources: resources)
    }

    static func removeDownloadableResource(id: String) throws {
        let catalog = try load()
        let resources = catalog.downloadableResources.filter { $0.id != id }
        guard resources.count != catalog.downloadableResources.count else {
            throw CatalogEditorError.downloadableResourceNotFound(id)
        }
        try write(catalog: catalog, downloadableResources: resources)
    }

    // MARK: - Partner offers (Oferte/Promoții branduri partenere, Etapa 4)

    static func upsertPartnerOffer(_ offer: PartnerOffer) throws {
        let catalog = try load()
        var offers = catalog.partnerOffers.filter { $0.id != offer.id }
        offers.append(offer)
        offers.sort { $0.brandName < $1.brandName }
        try write(catalog: catalog, partnerOffers: offers)
    }

    static func removePartnerOffer(id: String) throws {
        let catalog = try load()
        let offers = catalog.partnerOffers.filter { $0.id != id }
        guard offers.count != catalog.partnerOffers.count else {
            throw CatalogEditorError.partnerOfferNotFound(id)
        }
        try write(catalog: catalog, partnerOffers: offers)
    }

    // MARK: - Filigrane sezoniere — BIBLIOTECĂ (2026-08-29)
    //
    // Era un singur slot global (`setSeasonalBackground(_: String?)`).
    // Acum e o listă persistată: fiecare intrare are perioadă, poziție și
    // comutator propriu — vezi `SeasonalBackgroundConfig` (Core).

    static func setSeasonalBackgrounds(_ configs: [SeasonalBackgroundConfig]) throws {
        let catalog = try load()
        try write(catalog: catalog, seasonalBackgrounds: configs)
    }

    static func upsertSeasonalBackground(_ config: SeasonalBackgroundConfig) throws {
        let catalog = try load()
        var list = catalog.seasonalBackgrounds
        // Păstrează POZIȚIA în listă la editare (ordinea contează: la
        // coliziune de poziție câștigă ultimul — vezi Core).
        if let index = list.firstIndex(where: { $0.id == config.id }) {
            list[index] = config
        } else {
            list.append(config)
        }
        try write(catalog: catalog, seasonalBackgrounds: list)
    }

    static func removeSeasonalBackground(id: String) throws {
        let catalog = try load()
        try write(catalog: catalog, seasonalBackgrounds: catalog.seasonalBackgrounds.filter { $0.id != id })
    }

    // MARK: - Pachete/Bundle-uri (Etapa 9, 2026-08-29)

    static func upsertBundle(_ bundle: ProductBundle) throws {
        let catalog = try load()
        var bundles = catalog.productBundles.filter { $0.id != bundle.id }
        bundles.append(bundle)
        bundles.sort { $0.name < $1.name }
        try write(catalog: catalog, productBundles: bundles)
    }

    static func removeBundle(id: String) throws {
        let catalog = try load()
        let bundles = catalog.productBundles.filter { $0.id != id }
        guard bundles.count != catalog.productBundles.count else {
            throw CatalogEditorError.bundleNotFound(id)
        }
        try write(catalog: catalog, productBundles: bundles)
    }

    // MARK: - Tutorials (embedded YouTube videos)

    static func upsertTutorial(_ tutorial: Tutorial) throws {
        let catalog = try load()
        var tutorials = catalog.tutorials.filter { $0.id != tutorial.id }
        tutorials.append(tutorial)
        tutorials.sort { ($0.addedAt ?? "") > ($1.addedAt ?? "") } // cele mai noi primele
        try write(catalog: catalog, tutorials: tutorials)
    }

    static func removeTutorial(id: String) throws {
        let catalog = try load()
        let tutorials = catalog.tutorials.filter { $0.id != id }
        guard tutorials.count != catalog.tutorials.count else {
            throw CatalogEditorError.tutorialNotFound(id)
        }
        try write(catalog: catalog, tutorials: tutorials)
    }

    // MARK: - Write

    /// Rewrites docs/catalog.json, starting from `catalog` and replacing
    /// only whichever collections the caller passes — everything else
    /// (including collections a caller doesn't know about) is preserved
    /// unchanged. `updatedAt` always bumps to today.
    private static func write(
        catalog: Catalog,
        items: [PluginItem]? = nil,
        courses: [Course]? = nil,
        apps: [AppLink]? = nil,
        audioTracks: [AudioTrack]? = nil,
        educationalResources: [EducationalResource]? = nil,
        events: [Event]? = nil,
        partnerStores: [PartnerStore]? = nil,
        serviceCenters: [ServiceCenter]? = nil,
        downloadableResources: [DownloadableResource]? = nil,
        partnerOffers: [PartnerOffer]? = nil,
        seasonalBackgrounds: [SeasonalBackgroundConfig]? = nil,
        productBundles: [ProductBundle]? = nil,
        tutorials: [Tutorial]? = nil
    ) throws {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let updated = Catalog(
            updatedAt: formatter.string(from: Date()),
            items: items ?? catalog.items,
            courses: courses ?? catalog.courses,
            apps: apps ?? catalog.apps,
            audioTracks: audioTracks ?? catalog.audioTracks,
            educationalResources: educationalResources ?? catalog.educationalResources,
            events: events ?? catalog.events,
            partnerStores: partnerStores ?? catalog.partnerStores,
            serviceCenters: serviceCenters ?? catalog.serviceCenters,
            downloadableResources: downloadableResources ?? catalog.downloadableResources,
            partnerOffers: partnerOffers ?? catalog.partnerOffers,
            seasonalBackgrounds: seasonalBackgrounds ?? catalog.seasonalBackgrounds,
            productBundles: productBundles ?? catalog.productBundles,
            tutorials: tutorials ?? catalog.tutorials
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(updated)
        try data.write(to: RepoCheckoutPaths.catalogJSONURL)
    }
}
