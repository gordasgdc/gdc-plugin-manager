import Foundation

/// O dependenta de sistem verificata la lansare — orice ce NU poate fi
/// bundle-uit direct in aplicatie (spre deosebire de Python, care e deja
/// bundle-uit portabil in PythonRuntime/, vezi build_app.sh — acela NU
/// mai trebuie verificat, e mereu prezent).
public struct SystemDependency: Identifiable {
    public let id: String
    public let name: String
    public let isPresent: Bool
    /// URL de deschis (pagina oficiala de download) daca isPresent=false.
    /// Niciodata un script care instaleaza singur ceva la nivel de
    /// sistem fara pasul explicit al userului — vezi nota din
    /// SystemDependencyChecker despre de ce.
    public let downloadURL: URL?

    public init(id: String, name: String, isPresent: Bool, downloadURL: URL?) {
        self.id = id
        self.name = name
        self.isPresent = isPresent
        self.downloadURL = downloadURL
    }
}

/// Verifica dependentele de sistem care nu pot fi bundle-uite in
/// aplicatie. Pe Mac, practic exista UNA singura care conteaza:
/// DaVinci Resolve insusi (fara el, PowerGrade-urile/OFX-urile n-au unde
/// sa se instaleze).
///
/// DE CE nu instalam nimic automat: DaVinci Resolve e ~5GB, cere
/// acceptarea unui EULA Blackmagic si (pt. Studio) o licenta separata —
/// nu e ceva ce o aplicatie tert-parte poate/trebuie sa instaleze fara
/// stirea explicita a userului. Butonul deschide pagina oficiala de
/// download, userul face restul.
public enum SystemDependencyChecker {
    public static func checkAll() -> [SystemDependency] {
        [checkResolve()]
    }

    private static func checkResolve() -> SystemDependency {
        let candidatePaths = [
            "/Applications/DaVinci Resolve/DaVinci Resolve.app",
            "/Applications/DaVinci Resolve.app",
        ]
        let present = candidatePaths.contains { FileManager.default.fileExists(atPath: $0) }
        return SystemDependency(
            id: "davinci-resolve",
            name: "DaVinci Resolve",
            isPresent: present,
            downloadURL: URL(string: "https://www.blackmagicdesign.com/products/davinciresolve")
        )
    }
}
