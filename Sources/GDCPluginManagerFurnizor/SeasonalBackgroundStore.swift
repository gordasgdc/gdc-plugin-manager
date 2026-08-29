import Foundation
import AppKit
import CryptoKit
import UniformTypeIdentifiers
import GDCPluginManagerCore

/// Scrie filigranul/fundalul sezonier al Client-ului — Etapa 6
/// (2026-08-29). DELIBERAT separat de `CoverImageStore`: coperile de
/// produs trec prin `ImageProcessor` (compresie, redimensionare la un
/// preset fix) — corect pentru thumbnail-uri de card, greșit pentru un
/// filigran, unde Cristi vrea explicit posibilitatea unui SVG vectorial
/// nealterat (compresia/rasterizarea l-ar strica). Acest store copiază
/// fișierul BRUT, exact cum a fost ales.
///
/// [SCHIMBAT 2026-08-29] Era UN SINGUR slot global
/// (`docs/covers/seasonal/background.<ext>`), deci o imagine încărcată era
/// folosită o dată și pierdută la următoarea. Acum e o BIBLIOTECĂ: un
/// fișier per intrare, `docs/covers/seasonal/<id>.<ext>` — încărcarea unei
/// imagini noi ADAUGĂ, nu înlocuiește.
///
/// RECOMANDARE PNG vs SVG — **INVERSATĂ pe 2026-08-29** față de decizia
/// inițială. Motiv real, nu preferință: decodorul SVG nativ (ImageIO) de pe
/// macOS NU randează DELOC elementele `<text>` (bug găsit și confirmat izolat
/// — vezi jurnalul de la `SeasonalPresets` mai jos). Orice SVG cu text ar
/// arăta gol/incomplet la clienți, silențios, fără nicio eroare. **PNG e
/// acum recomandarea implicită** pentru orice filigran cu text — rămâne
/// sigur indiferent de conținut, fiindcă e deja o imagine rasterizată, nu
/// interpretată la runtime. SVG rămâne acceptat la upload (util pentru forme
/// PURE, fără text — un logo vectorial simplu, de exemplu), dar Furnizorul
/// avertizează acum explicit dacă fișierul ales conține `<text>`.
enum SeasonalBackgroundStore {
    static var directory: URL {
        RepoCheckoutPaths.publicCatalogRepo
            .appendingPathComponent("docs")
            .appendingPathComponent(CatalogAssets.coversFolderName)
            .appendingPathComponent("seasonal", isDirectory: true)
    }

    /// Copiază `source` (svg/png/jpg — orice a ales furnizorul) ca fișier al
    /// intrării `id` din bibliotecă, cu cache-busting după conținut (același
    /// motiv ca `CoverImageStore` — GitHub Pages cache-uiește 4h, PWA
    /// cache-first). Întoarce valoarea de scris în `imagePath`.
    static func commit(source: URL, id: String) throws -> String {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        removeFiles(id: id) // extensia se poate schimba între încărcări

        let ext = source.pathExtension.isEmpty ? "png" : source.pathExtension.lowercased()
        let destination = directory.appendingPathComponent("\(id).\(ext)")
        try FileManager.default.copyItem(at: source, to: destination)

        let data = try Data(contentsOf: destination)
        let digest = SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined().prefix(8)
        return "\(CatalogAssets.coversFolderName)/seasonal/\(id).\(ext)?v=\(digest)"
    }

    /// Scrie un preset predefinit — de la 2026-08-29 e un PNG bundle-uit
    /// (`Resources/SeasonalPresets/<preset.id>.png`), nu mai SVG generat la
    /// runtime (vezi doc-comment-ul de la `SeasonalPreset`).
    enum PresetError: LocalizedError {
        case resourceMissing(String)
        var errorDescription: String? {
            switch self {
            case .resourceMissing(let id):
                return "Lipsește fișierul preset „\(id).png” din bundle — reinstalează aplicația."
            }
        }
    }

    static func commitPreset(_ preset: SeasonalPreset, id: String) throws -> String {
        guard let resourceURL = SeasonalPresets.resourceURL(for: preset) else {
            throw PresetError.resourceMissing(preset.id)
        }
        return try commit(source: resourceURL, id: id)
    }

    /// Șterge fișierul (orice extensie) al unei intrări scoase din
    /// bibliotecă — altfel ar rămâne orfan în repo pentru totdeauna, exact
    /// pitfall-ul deja documentat la coperți (`CoverImageStore`).
    static func removeFiles(id: String) {
        guard let entries = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return }
        for entry in entries where entry.deletingPathExtension().lastPathComponent == id {
            try? FileManager.default.removeItem(at: entry)
        }
    }

    @MainActor
    static func pickFile() -> URL? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image, .svg]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Alege imaginea de fundal sezonier (fișierul original, fără compresie). Recomandat: PNG — un SVG cu text nu se va vedea la clienți (decodorul SVG de pe macOS nu randează text)."
        panel.prompt = "Alege"
        return panel.runModal() == .OK ? panel.url : nil
    }
}

/// Câteva filigrane sezoniere predefinite, gata de folosit din galerie —
/// PNG randat, NU SVG inline (schimbat 2026-08-29, bug real găsit, nu
/// presupunere).
///
/// **BUG REAL, GĂSIT ȘI REPARAT 2026-08-29: decodorul SVG nativ (ImageIO)
/// de pe macOS NU randează DELOC elementele `<text>`.** Toate cele 7
/// preseturi anterioare (redesenate complet ca "scene recognoscibile +
/// text explicit", vezi jurnalul vechi mai jos) aveau, fără să știm,
/// textul complet invizibil în Client — confirmat izolat, pixel cu pixel
/// (`NSImage(data:)` pe un SVG minimal cu `<text>`, alpha 0 exact la
/// poziția textului, indiferent de font). Doar formele geometrice
/// (path/circle/rect) se randau. Cristi a raportat live exact acest
/// simptom ("filigranul nu se vede") pe un filigran cu text ales din
/// galerie. **Decizie, la cererea explicită a lui Cristi ("dacă crede că
/// SVG face probleme, lasă doar PNG, dar să fim siguri că-i 100%
/// funcțional")**: preseturile predefinite sunt acum PNG randat o
/// singură dată (offline, prin conversia textului în path-uri vectoriale
/// reale via CoreText — `CTFontCreatePathForGlyph` — apoi rasterizare la
/// 960×960 cu fundal transparent), NU mai SVG cu `<text>` la runtime.
/// Bibliotecile custom (upload propriu) rămân libere să accepte orice
/// extensie — recomandarea implicită s-a schimbat din SVG în PNG (vezi
/// `SeasonalBackgroundView.swift`), tocmai din cauza acestui bug: SVG
/// rămâne sigur DOAR pentru forme pure, fără text.
///
/// Fișierele PNG trăiesc în `Resources/SeasonalPresets/<id>.png`
/// (bundle-uite prin `Package.swift`, `.copy(...)`) — încărcate prin
/// `Bundle.module`, NU generate la runtime.
struct SeasonalPreset: Identifiable {
    let id: String
    let label: String
}

enum SeasonalPresets {
    static let all: [SeasonalPreset] = [
        SeasonalPreset(id: "black-friday", label: "Black Friday"),
        SeasonalPreset(id: "christmas", label: "Crăciun"),
        SeasonalPreset(id: "new-year", label: "Revelion / Anul Nou"),
        SeasonalPreset(id: "spring", label: "Ofertă de Primăvară"),
        SeasonalPreset(id: "easter", label: "Paște"),
        SeasonalPreset(id: "summer", label: "Vară / Vacanță"),
        SeasonalPreset(id: "flash-offer", label: "Ofertă Flash / Super Ofertă"),
    ]

    /// URL-ul fișierului PNG bundle-uit al unui preset — `nil` doar dacă
    /// bundle-ul e corupt/incomplet (n-ar trebui să se întâmple niciodată
    /// cu build-ul normal, dar `commitPreset` tratează explicit acest caz
    /// în loc să crape).
    static func resourceURL(for preset: SeasonalPreset) -> URL? {
        Bundle.module.url(forResource: preset.id, withExtension: "png", subdirectory: "SeasonalPresets")
    }
}
