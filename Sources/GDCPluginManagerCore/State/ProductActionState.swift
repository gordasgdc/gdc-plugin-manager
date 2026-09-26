import Foundation

/// Starea de acțiune a unui produs din catalog, DERIVATĂ (nu stocată în view).
/// UI_ARCHITECTURE.md §3. Cardul o primește și trimite intenții; nu mai decide singur.
///
/// Ordinea de prioritate reproduce exact logica anterioară din `PluginCard.actionButton`:
/// incompatibil → licență → operație în curs → actualizare → instalat → neinstalat.
/// Stările cu progres (downloading/paused/updating) sunt amânate: `InstallManager` nu
/// expune încă progres sau reluare — ar fi funcționalitate nouă, nu refactorizare.
public enum ProductActionState: Equatable, Sendable {
    case incompatible
    case licenseRequired
    case installing
    case updateAvailable(installed: String, latest: String)
    case installed(version: String)
    case notInstalled

    public static func derive(isCompatible: Bool,
                              isUnlocked: Bool,
                              isBusy: Bool,
                              installedVersion: String?,
                              catalogVersion: String) -> ProductActionState {
        if !isCompatible { return .incompatible }
        if !isUnlocked { return .licenseRequired }
        if isBusy { return .installing }
        guard let installedVersion else { return .notInstalled }
        if installedVersion != catalogVersion {
            return .updateAvailable(installed: installedVersion, latest: catalogVersion)
        }
        return .installed(version: installedVersion)
    }
}
