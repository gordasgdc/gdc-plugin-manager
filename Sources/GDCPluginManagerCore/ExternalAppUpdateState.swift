import Foundation

/// Disponibilitatea unei versiuni noi pentru o aplicație găsită pe disc: vine doar din versiunea REALĂ instalată
/// (Info.plist al copiei alese) și versiunea PUBLICATĂ (manifestul produsului). Lipsa oricăreia dintre ele nu
/// produce niciodată „actualizare disponibilă” — existența produsului în lista cunoscută nu e un motiv.
public enum ExternalAppUpdateState: Equatable {
    case unknown, upToDate, updateAvailable

    public static func evaluate(installed: String?, published: String?, isNewer: (String, String) -> Bool) -> ExternalAppUpdateState {
        guard let installed, !installed.isEmpty, let published, !published.isEmpty else { return .unknown }
        return isNewer(published, installed) ? .updateAvailable : .upToDate
    }
}
