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
/// fișierul BRUT, exact cum a fost ales, într-un singur slot global
/// (`docs/covers/seasonal/background.<ext>`) — nu e per-produs.
enum SeasonalBackgroundStore {
    static var directory: URL {
        RepoCheckoutPaths.publicCatalogRepo
            .appendingPathComponent("docs")
            .appendingPathComponent(CatalogAssets.coversFolderName)
            .appendingPathComponent("seasonal", isDirectory: true)
    }

    /// Copiază `source` (svg/png/jpg — orice a ales furnizorul) ca noul
    /// filigran global, cu cache-busting după conținut (același motiv ca
    /// `CoverImageStore` — GitHub Pages cache-uiește 4h, PWA cache-first).
    /// `nil` șterge filigranul curent (revenire la fundalul Shift normal).
    static func commit(source: URL?) throws -> String? {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        // Curăță orice "background.*" vechi — extensia se poate schimba
        // (ex. de la .svg la .png) între publicări.
        if let entries = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) {
            for entry in entries where entry.deletingPathExtension().lastPathComponent == "background" {
                try? FileManager.default.removeItem(at: entry)
            }
        }
        guard let source else { return nil }

        let ext = source.pathExtension.isEmpty ? "png" : source.pathExtension
        let destination = directory.appendingPathComponent("background.\(ext)")
        try FileManager.default.copyItem(at: source, to: destination)

        let data = try Data(contentsOf: destination)
        let digest = SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined().prefix(8)
        return "\(CatalogAssets.coversFolderName)/seasonal/background.\(ext)?v=\(digest)"
    }

    /// Scrie un preset predefinit (SVG inline, din `SeasonalPresets`) —
    /// nu cere niciun fișier de pe disc, doar alegerea din galerie.
    static func commitPreset(_ preset: SeasonalPreset) throws -> String? {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(preset.id).svg")
        try preset.svg.write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }
        return try commit(source: tempURL)
    }

    @MainActor
    static func pickFile() -> URL? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image, .svg]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Alege imaginea/SVG-ul de fundal sezonier (fișierul original, fără compresie)."
        panel.prompt = "Alege"
        return panel.runModal() == .OK ? panel.url : nil
    }
}

/// Câteva filigrane sezoniere pregătite din start (SVG inline, vectorial —
/// niciun asset extern de gestionat).
///
/// [ÎNVECHIT 2026-08-29, refăcut complet] Prima variantă (o formă
/// geometrică goală + un simbol vag) a fost respinsă explicit de Cristi:
/// "arată ca făcut de un copil de 3 ani... nici pe departe ce mă
/// imaginam". Cerința reală, clarificată punct cu punct: fiecare filigran
/// trebuie să fie o SCENĂ recognoscibilă (brad + cadouri de Crăciun,
/// artificii + pahar de șampanie de Revelion, iepuraș + coș de ouă de
/// Paște, umbrelă de plajă + valuri de vară, fulger + explozie pentru
/// ofertă flash) ȘI să conțină textul de urare/temă explicit (nu doar un
/// simbol abstract). Stil: contur alb (stroke), fără umpluri solide mari
/// — orice formă plină de aceeași culoare cu restul liniei ar deveni
/// invizibilă suprapusă (SVG-ul e randat la opacitate mică peste fundalul
/// închis al aplicației, deci un fundal alb cu text închis ÎN INTERIOR
/// ar dispărea complet) — de-aia textul stă mereu SEPARAT de forme, nu
/// suprapus peste o umplere.
struct SeasonalPreset: Identifiable {
    let id: String
    let label: String
    let svg: String
}

enum SeasonalPresets {
    static let all: [SeasonalPreset] = [
        SeasonalPreset(id: "black-friday", label: "Black Friday", svg: """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 400">
          <text x="200" y="145" font-family="Helvetica, Arial" font-size="54" font-weight="900" fill="#FFFFFF" text-anchor="middle">BLACK</text>
          <text x="200" y="205" font-family="Helvetica, Arial" font-size="54" font-weight="900" fill="#FFFFFF" text-anchor="middle">FRIDAY</text>
          <g fill="none" stroke="#FFFFFF" stroke-width="6" stroke-linejoin="round">
            <path d="M105 250 L250 250 L302 300 L250 350 L105 350 Z"/>
          </g>
          <circle cx="148" cy="300" r="9" fill="#FFFFFF"/>
          <text x="235" y="313" font-family="Helvetica, Arial" font-size="32" font-weight="800" fill="#FFFFFF" text-anchor="middle">%</text>
          <text x="200" y="385" font-family="Helvetica, Arial" font-size="17" font-weight="700" letter-spacing="5" fill="#FFFFFF" text-anchor="middle">SUPER REDUCERI</text>
        </svg>
        """),
        SeasonalPreset(id: "christmas", label: "Crăciun", svg: """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 400">
          <g fill="none" stroke="#FFFFFF" stroke-width="6" stroke-linejoin="round">
            <path d="M200 42 L245 112 L215 112 L260 178 L225 178 L275 246 L125 246 L175 178 L140 178 L185 112 L155 112 Z"/>
            <rect x="182" y="246" width="36" height="28"/>
            <rect x="108" y="292" width="62" height="46" rx="4"/>
            <rect x="228" y="292" width="62" height="46" rx="4"/>
          </g>
          <path d="M108 292 L170 338 M170 292 L108 338" stroke="#FFFFFF" stroke-width="4" fill="none"/>
          <path d="M228 292 L290 338 M290 292 L228 338" stroke="#FFFFFF" stroke-width="4" fill="none"/>
          <path d="M200 12 L206 28 L223 28 L209 38 L214 55 L200 45 L186 55 L191 38 L177 28 L194 28 Z" fill="#FFFFFF"/>
          <circle cx="184" cy="140" r="6" fill="#FFFFFF"/>
          <circle cx="216" cy="160" r="6" fill="#FFFFFF"/>
          <circle cx="168" cy="200" r="6" fill="#FFFFFF"/>
          <circle cx="232" cy="212" r="6" fill="#FFFFFF"/>
          <circle cx="200" cy="228" r="6" fill="#FFFFFF"/>
          <circle cx="80" cy="65" r="4" fill="#FFFFFF"/>
          <circle cx="325" cy="85" r="4" fill="#FFFFFF"/>
          <circle cx="55" cy="130" r="3" fill="#FFFFFF"/>
          <circle cx="340" cy="150" r="3" fill="#FFFFFF"/>
          <circle cx="100" cy="180" r="3" fill="#FFFFFF"/>
          <text x="200" y="378" font-family="Helvetica, Arial" font-size="27" font-weight="700" fill="#FFFFFF" text-anchor="middle">Sărbători Fericite</text>
        </svg>
        """),
        SeasonalPreset(id: "new-year", label: "Revelion / Anul Nou", svg: """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 400">
          <g stroke="#FFFFFF" stroke-width="3" fill="none">
            <path d="M95 85 L95 35 M95 85 L65 60 M95 85 L125 60 M95 85 L55 90 M95 85 L135 90 M95 85 L70 118 M95 85 L120 118"/>
            <path d="M305 65 L305 25 M305 65 L280 45 M305 65 L330 45 M305 65 L270 70 M305 65 L340 70 M305 65 L285 95 M305 65 L325 95"/>
          </g>
          <circle cx="95" cy="35" r="4" fill="#FFFFFF"/>
          <circle cx="305" cy="25" r="4" fill="#FFFFFF"/>
          <circle cx="125" cy="60" r="3" fill="#FFFFFF"/>
          <circle cx="330" cy="45" r="3" fill="#FFFFFF"/>
          <circle cx="55" cy="90" r="3" fill="#FFFFFF"/>
          <g fill="none" stroke="#FFFFFF" stroke-width="6">
            <path d="M172 165 L172 300 Q172 322 200 322 Q228 322 228 300 L228 165 Q228 142 200 128 Q172 142 172 165 Z"/>
            <path d="M188 322 L188 358 M212 322 L212 358 M172 358 L228 358"/>
          </g>
          <circle cx="190" cy="215" r="4" fill="#FFFFFF"/>
          <circle cx="210" cy="248" r="4" fill="#FFFFFF"/>
          <circle cx="195" cy="280" r="4" fill="#FFFFFF"/>
          <text x="200" y="105" font-family="Helvetica, Arial" font-size="34" font-weight="900" fill="#FFFFFF" text-anchor="middle">LA MULȚI ANI!</text>
        </svg>
        """),
        SeasonalPreset(id: "spring", label: "Ofertă de Primăvară", svg: """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 400">
          <g stroke="#FFFFFF" stroke-width="4" fill="none">
            <circle cx="325" cy="70" r="28"/>
            <path d="M325 28 L325 14 M325 128 L325 114 M367 70 L381 70 M269 70 L283 70 M356 44 L365 35 M295 105 L286 114 M356 96 L365 105 M295 35 L286 44"/>
          </g>
          <path d="M50 345 Q200 250 350 345" stroke="#FFFFFF" stroke-width="5" fill="none"/>
          <g fill="none" stroke="#FFFFFF" stroke-width="5">
            <g transform="translate(120,225)">
              <ellipse cx="0" cy="-28" rx="15" ry="28"/>
              <ellipse cx="0" cy="-28" rx="15" ry="28" transform="rotate(72)"/>
              <ellipse cx="0" cy="-28" rx="15" ry="28" transform="rotate(144)"/>
              <ellipse cx="0" cy="-28" rx="15" ry="28" transform="rotate(216)"/>
              <ellipse cx="0" cy="-28" rx="15" ry="28" transform="rotate(288)"/>
              <circle r="9" fill="#FFFFFF" stroke="none"/>
              <path d="M0 28 L0 85" stroke-width="4"/>
            </g>
            <g transform="translate(255,255) scale(0.65)">
              <ellipse cx="0" cy="-28" rx="15" ry="28"/>
              <ellipse cx="0" cy="-28" rx="15" ry="28" transform="rotate(72)"/>
              <ellipse cx="0" cy="-28" rx="15" ry="28" transform="rotate(144)"/>
              <ellipse cx="0" cy="-28" rx="15" ry="28" transform="rotate(216)"/>
              <ellipse cx="0" cy="-28" rx="15" ry="28" transform="rotate(288)"/>
              <circle r="9" fill="#FFFFFF" stroke="none"/>
              <path d="M0 28 L0 95" stroke-width="4"/>
            </g>
          </g>
          <g fill="none" stroke="#FFFFFF" stroke-width="4">
            <ellipse cx="88" cy="155" rx="30" ry="15" transform="rotate(-18 88 155)"/>
            <path d="M60 150 Q42 142 36 152"/>
            <path d="M116 145 L118 133"/>
          </g>
          <circle cx="98" cy="153" r="3" fill="#FFFFFF"/>
          <text x="200" y="382" font-family="Helvetica, Arial" font-size="24" font-weight="700" fill="#FFFFFF" text-anchor="middle">Ofertă de Primăvară</text>
        </svg>
        """),
        SeasonalPreset(id: "easter", label: "Paște", svg: """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 400">
          <g fill="none" stroke="#FFFFFF" stroke-width="5">
            <ellipse cx="140" cy="225" rx="52" ry="62"/>
            <circle cx="140" cy="148" r="38"/>
            <ellipse cx="116" cy="90" rx="15" ry="42" transform="rotate(-15 116 90)"/>
            <ellipse cx="164" cy="90" rx="15" ry="42" transform="rotate(15 164 90)"/>
            <path d="M128 162 Q140 168 152 162"/>
          </g>
          <circle cx="126" cy="142" r="4" fill="#FFFFFF"/>
          <circle cx="154" cy="142" r="4" fill="#FFFFFF"/>
          <g fill="none" stroke="#FFFFFF" stroke-width="5">
            <path d="M235 258 L335 258 L320 328 L250 328 Z"/>
            <path d="M235 258 Q285 210 335 258"/>
            <path d="M240 258 L330 258" stroke-width="3"/>
          </g>
          <g fill="none" stroke="#FFFFFF" stroke-width="3">
            <ellipse cx="260" cy="242" rx="13" ry="17" transform="rotate(-10 260 242)"/>
            <ellipse cx="288" cy="236" rx="13" ry="17" transform="rotate(5 288 236)"/>
            <ellipse cx="313" cy="246" rx="13" ry="17" transform="rotate(15 313 246)"/>
          </g>
          <text x="200" y="382" font-family="Helvetica, Arial" font-size="27" font-weight="700" fill="#FFFFFF" text-anchor="middle">Paște Fericit</text>
        </svg>
        """),
        SeasonalPreset(id: "summer", label: "Vară / Vacanță", svg: """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 400">
          <g fill="none" stroke="#FFFFFF" stroke-width="4">
            <circle cx="325" cy="60" r="24"/>
            <path d="M325 24 L325 12 M362 60 L374 60 M325 96 L325 108 M288 60 L276 60 M350 35 L359 26 M300 85 L291 94 M350 85 L359 94 M300 35 L291 26"/>
          </g>
          <g fill="none" stroke="#FFFFFF" stroke-width="6">
            <path d="M200 118 A98 58 0 0 1 102 162 L298 162 A98 58 0 0 1 200 118 Z"/>
            <path d="M200 162 L200 315"/>
            <path d="M165 315 L235 315"/>
            <path d="M150 162 L200 118 M175 162 L200 118 M225 162 L200 118 M250 162 L200 118"/>
          </g>
          <g fill="none" stroke="#FFFFFF" stroke-width="5">
            <path d="M15 295 Q55 275 95 295 T175 295 T255 295 T335 295 T385 295"/>
            <path d="M15 335 Q55 315 95 335 T175 335 T255 335 T335 335 T385 335"/>
          </g>
          <g fill="none" stroke="#FFFFFF" stroke-width="4">
            <path d="M262 232 L280 288 L244 288 Z"/>
            <path d="M244 288 L280 288 L275 306 L249 306 Z"/>
            <path d="M262 232 L292 214"/>
          </g>
          <circle cx="292" cy="214" r="3" fill="#FFFFFF"/>
          <text x="200" y="378" font-family="Helvetica, Arial" font-size="24" font-weight="700" fill="#FFFFFF" text-anchor="middle">Ofertă de Vară</text>
        </svg>
        """),
        SeasonalPreset(id: "flash-offer", label: "Ofertă Flash / Super Ofertă", svg: """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 400">
          <g fill="none" stroke="#FFFFFF" stroke-width="3">
            <path d="M200 55 L200 25 M258 70 L280 50 M298 115 L328 105 M298 175 L328 185 M258 220 L280 240 M142 220 L120 240 M102 175 L72 185 M102 115 L72 105 M142 70 L120 50"/>
          </g>
          <path d="M222 78 L152 205 L194 205 L172 320 L272 175 L218 175 Z" fill="none" stroke="#FFFFFF" stroke-width="7" stroke-linejoin="round"/>
          <text x="200" y="368" font-family="Helvetica, Arial" font-size="30" font-weight="900" letter-spacing="2" fill="#FFFFFF" text-anchor="middle">FLASH OFFER</text>
        </svg>
        """),
    ]
}
