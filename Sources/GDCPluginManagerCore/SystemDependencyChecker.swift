import Foundation

/// O dependenta de sistem verificata la lansare — orice ce NU poate fi
/// bundle-uit direct in aplicatie (spre deosebire de Python, care e deja
/// bundle-uit portabil in PythonRuntime/, vezi build_app.sh — acela NU
/// mai trebuie verificat, e mereu prezent).
///
/// Extins 2026-08-26 (Faza 1, "Manager Modular de Dependinte" — vezi
/// CLAUDE.md Partea 1, Regula 4): de la o singura verificare hardcodata
/// (DaVinci Resolve) la un model generic, ca in `DependencyManager.swift`
/// din CGConvertor — fiecare componenta e un `SystemDependency` cu status
/// propriu, `isOptional` (o componenta optionala nu blocheaza indicatorul
/// global verde), si o actiune asociata (deschide un URL/ghid).
public struct SystemDependency: Identifiable {
    public let id: String
    public let name: String
    public let isPresent: Bool
    /// O dependinta optionala (ex. Scripting API — doar PowerGrade-urile
    /// il folosesc, si oricum cad gratios pe import manual daca lipseste)
    /// NU face indicatorul global rosu — doar cele obligatorii o fac.
    public let isOptional: Bool
    /// Explicatie scurta, aratata in panou sub numele componentei.
    public let detail: String
    /// URL de deschis (pagina oficiala de download/ghid) daca isPresent=false.
    /// Niciodata un script care instaleaza singur ceva la nivel de
    /// sistem fara pasul explicit al userului — vezi nota din
    /// SystemDependencyChecker despre de ce.
    public let downloadURL: URL?

    public init(id: String, name: String, isPresent: Bool, isOptional: Bool = false, detail: String = "", downloadURL: URL?) {
        self.id = id
        self.name = name
        self.isPresent = isPresent
        self.isOptional = isOptional
        self.detail = detail
        self.downloadURL = downloadURL
    }
}

/// Verifica dependentele de sistem care nu pot fi bundle-uite in
/// aplicatie: DaVinci Resolve insusi (fara el, nimic n-are unde sa se
/// instaleze), plus — din 2026-08-26 — cerintele speciale per tip de
/// produs (foldere OFX/LUT/DCTL/Fusion, Scripting API pentru PowerGrade).
///
/// DE CE nu instalam nimic automat pentru DaVinci Resolve insusi: e
/// ~5GB, cere acceptarea unui EULA Blackmagic si (pt. Studio) o licenta
/// separata — nu e ceva ce o aplicatie tert-parte poate/trebuie sa
/// instaleze fara stirea explicita a userului. Butonul deschide pagina
/// oficiala de download, userul face restul. Folderele de instalare
/// (OFX/LUT/DCTL/Fusion) SUNT create automat de InstallManager la prima
/// instalare a unui produs de tipul respectiv — verificarea de-aici e
/// informativa (arata userului ca totul e pregatit), nu un blocaj real.
public enum SystemDependencyChecker {
    public static func checkAll() -> [SystemDependency] {
        [
            checkResolve(),
            checkFolder(id: "ofx-folder", name: "Efecte OFX (FX)", path: OFXPaths.pluginsFolder, detail: "Foldere efecte/DVE — create automat la prima instalare de OFX."),
            checkFolder(id: "lut-folder", name: "LUT / DCTL", path: OFXPaths.lutFolder, detail: "Depozit LUT-uri si DCTL — creat automat la prima instalare."),
            checkFolder(id: "fusion-folder", name: "Fusion (Fuse)", path: OFXPaths.fusionFolder, detail: "Depozit Fuse-uri — creat automat la prima instalare."),
            checkScriptingAPI(),
        ]
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
            isOptional: false,
            detail: present ? "Detectat." : "Necesar pentru orice instalare de plugin.",
            downloadURL: URL(string: "https://www.blackmagicdesign.com/products/davinciresolve")
        )
    }

    /// Foldere unde Resolve citeste efectiv fisierele — vezi
    /// `PluginType.installDirectory` in CatalogModel.swift, aceleasi cai.
    /// Optionale: daca lipsesc acum, apar automat la prima instalare —
    /// nu e nevoie de nicio actiune manuala a userului.
    private static func checkFolder(id: String, name: String, path: URL, detail: String) -> SystemDependency {
        let present = FileManager.default.fileExists(atPath: path.path)
        return SystemDependency(
            id: id, name: name, isPresent: present, isOptional: true,
            detail: present ? detail : detail + " (nu exista inca — normal, pana la prima instalare)",
            downloadURL: nil
        )
    }

    /// Scripting API-ul lui Resolve (python3 + fusionscript.so) — folosit
    /// EXCLUSIV pentru import automat de PowerGrade in Gallery (vezi
    /// PowerGradeImporter.swift). Optional: fara el, PowerGrade-urile tot
    /// se instaleaza (staged, import manual din Gallery) — niciodata
    /// blocat complet.
    private static func checkScriptingAPI() -> SystemDependency {
        let libPath = "/Applications/DaVinci Resolve/DaVinci Resolve.app/Contents/Libraries/Fusion/fusionscript.so"
        let hasLib = FileManager.default.fileExists(atPath: libPath)
        let hasPython = ["/usr/bin/python3", "/usr/local/bin/python3", "/opt/homebrew/bin/python3"]
            .contains { FileManager.default.isExecutableFile(atPath: $0) }
        let present = hasLib && hasPython
        return SystemDependency(
            id: "scripting-api",
            name: "Scripting API (import automat PowerGrade)",
            isPresent: present,
            isOptional: true,
            detail: present ? "Import automat in Gallery activ." : "Fara el, PowerGrade-urile se instaleaza oricum — doar import-ul in Gallery devine manual.",
            downloadURL: nil
        )
    }
}

/// Caile foldere folosite si de `PluginType.installDirectory`
/// (CatalogModel.swift) — duplicate aici intentionat (nu extrase intr-un
/// helper comun) ca sa nu introducem un cuplaj nou intre model si checker
/// pentru un singur folosinta; daca una din cele doua se schimba, cealalta
/// trebuie actualizata manual (verifica ambele la orice schimbare de cale).
enum OFXPaths {
    static var pluginsFolder: URL { URL(fileURLWithPath: "/Library/OFX/Plugins") }
    static var lutFolder: URL {
        FileManager.default.urls(for: .libraryDirectory, in: .localDomainMask).first!
            .appendingPathComponent("Application Support/Blackmagic Design/DaVinci Resolve/LUT")
    }
    static var fusionFolder: URL {
        FileManager.default.urls(for: .libraryDirectory, in: .localDomainMask).first!
            .appendingPathComponent("Application Support/Blackmagic Design/DaVinci Resolve/Fusion/Fuses")
    }
}
