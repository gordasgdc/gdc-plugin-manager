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
    /// Ultima instalare/actualizare a eșuat; acțiunea principală o reia (aceeași operație).
    case failed(isUpdate: Bool)
    /// Neinstalat, iar catalogul afișat e cel din cache (rețea indisponibilă). Informativ:
    /// acțiunea rămâne activă, exact ca înainte.
    case offline

    public static func derive(isCompatible: Bool,
                              isUnlocked: Bool,
                              isBusy: Bool,
                              installedVersion: String?,
                              catalogVersion: String,
                              lastInstallFailed: Bool = false,
                              isOffline: Bool = false) -> ProductActionState {
        if !isCompatible { return .incompatible }
        if !isUnlocked { return .licenseRequired }
        if isBusy { return .installing }
        if lastInstallFailed && installedVersion != catalogVersion { return .failed(isUpdate: installedVersion != nil) }
        guard let installedVersion else { return isOffline ? .offline : .notInstalled }
        if installedVersion != catalogVersion {
            return .updateAvailable(installed: installedVersion, latest: catalogVersion)
        }
        return .installed(version: installedVersion)
    }
}
