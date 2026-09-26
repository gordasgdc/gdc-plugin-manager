import SwiftUI
import AppKit
import GDCPluginManagerCore

enum SidebarSection: Hashable {
    case all
    case type(PluginType)
    case audio
    case download(DownloadCategory)
    case courses
    case educationalResources
    case tutorials
    case events
    case partnerOffers
    case bundles
    case partnerStores
    case serviceCenters
    case apps
    case myApps
    case android
    case license
    case help
    case community
    case developer(DeveloperShelf)
}

/// Secțiunea DEVELOPER (2026-09-19). Maparea e prin etichete din catalog
/// (`access.tags`), editabile din Furnizor — nicio listă fixă de produse:
/// aplicațiile cu eticheta „Developer” ajung la „Aplicații & Utilitare”
/// (și ies din lista generală a Ecosistemului), resursele descărcabile cu
/// eticheta raftului lor ajung la „Scripturi & Automation” / „SDK & Resurse Dev”.
enum DeveloperShelf: String, Hashable, CaseIterable {
    case apps, scripts, sdk

    static let appsTag = "Developer"

    var tag: String {
        switch self {
        case .apps: return Self.appsTag
        case .scripts: return "Scripturi & Automation"
        case .sdk: return "SDK & Resurse Dev"
        }
    }

    var titleKey: String { "sidebar.developer.\(rawValue)" }

    var symbol: String {
        switch self {
        case .apps: return "hammer"
        case .scripts: return "terminal"
        case .sdk: return "shippingbox"
        }
    }
}
