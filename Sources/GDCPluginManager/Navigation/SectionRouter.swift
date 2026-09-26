import SwiftUI
import GDCPluginManagerCore

/// Selecția din bara laterală → ecranul afișat (UI_ARCHITECTURE.md §2).
/// Mutat din `ContentView.detailContent`, neschimbat: o secțiune nouă atinge
/// doar acest fișier, nu shell-ul.
struct SectionRouter: View {
    let selection: SidebarSection?
    @EnvironmentObject private var catalog: CatalogService

    /// Fiecare categorie nouă își are cheia ei de catalog — vezi
    /// `Catalog.pdfResources` / `Catalog.scriptResources` pentru motiv.
    private func resourcesFor(_ category: DownloadCategory) -> [DownloadableResource] {
        switch category {
        case .pdf: return catalog.pdfResources
        case .script: return catalog.scriptResources
        default: return catalog.downloadableResources
        }
    }

    /// Toate produsele instalabile, indiferent în ce cheie de catalog stau.
    /// Scripturile au cheia lor (`scriptItems`) din motive de
    /// retrocompatibilitate, dar pentru UI sunt produse ca oricare altele.
    private var allInstallableItems: [PluginItem] { catalog.allInstallableItems }

    // Extras din body — switch cu multe cazuri inline facea type-check-ul
    // Swift sa depaseasca timeout-ul ("unable to type-check in reasonable
    // time") dupa adaugarea cazului .serviceCenters.
    var body: some View {
        switch selection {
        case .license:
            LicensePane()
        case .help:
            HelpView()
        case .courses:
            // Etapa 4 (2026-08-29): filtrat pe valabilitate temporală —
            // conținut nescheduled (nil) rămâne mereu vizibil, identic cu
            // înainte.
            CoursesGrid(courses: catalog.courses.filter { $0.scheduling?.isActiveNow ?? true })
        case .educationalResources:
            EducationalResourcesGrid(resources: catalog.educationalResources.filter { $0.scheduling?.isActiveNow ?? true })
        case .community:
            CommunityGrid(channels: catalog.communityChannels.publishedSorted)
        case .tutorials:
            TutorialsGrid(tutorials: catalog.tutorials.filter { $0.scheduling?.isActiveNow ?? true })
        case .events:
            EventsGrid(events: catalog.events.filter { $0.scheduling?.isActiveNow ?? true })
        case .partnerOffers:
            PartnerOffersGrid(offers: catalog.partnerOffers.filter { $0.scheduling?.isActiveNow ?? true })
        case .bundles:
            BundleGrid(bundles: catalog.productBundles.filter { $0.scheduling?.isActiveNow ?? true }, catalog: catalog)
        case .partnerStores:
            PartnerStoresGrid(stores: catalog.partnerStores.filter { $0.scheduling?.isActiveNow ?? true })
        case .serviceCenters:
            ServiceCentersGrid(centers: catalog.serviceCenters.filter { $0.scheduling?.isActiveNow ?? true })
        case .apps:
            AppsGrid(apps: catalog.apps.filter {
                ($0.scheduling?.isActiveNow ?? true) && !$0.resolvedAccess.tags.contains(DeveloperShelf.appsTag)
            })
        case .developer(let shelf):
            switch shelf {
            case .apps:
                AppsGrid(apps: catalog.apps.filter {
                    ($0.scheduling?.isActiveNow ?? true) && $0.resolvedAccess.tags.contains(DeveloperShelf.appsTag)
                })
            case .scripts, .sdk:
                DownloadResourceGrid(resources: (catalog.downloadableResources + catalog.scriptResources + catalog.pdfResources)
                    .filter { ($0.scheduling?.isActiveNow ?? true) && $0.resolvedAccess.tags.contains(shelf.tag) })
            }
        case .myApps:
            MyAppsGrid()
        case .audio:
            AudioGrid(tracks: catalog.audioTracks.filter { $0.scheduling?.isActiveNow ?? true })
        case .download(let category):
            // PDF-urile stau intr-o cheie separata de catalog (vezi
            // Catalog.pdfResources) — nu se filtreaza din lista comuna.
            DownloadResourceGrid(resources: resourcesFor(category)
                .filter { $0.category == category && ($0.scheduling?.isActiveNow ?? true) })
        case .android:
            MobileAppPane()
        case .all, .none:
            CatalogGrid(items: allInstallableItems.filter { $0.scheduling?.isActiveNow ?? true })
        case .type(let type):
            // Scripturile vin din cheia LOR de catalog — vezi
            // Catalog.scriptItems pentru motivul retrocompatibilitatii.
            CatalogGrid(items: (type == .scripts ? catalog.scriptItems : catalog.items)
                .filter { $0.type == type && ($0.scheduling?.isActiveNow ?? true) })
        }
    }

}
