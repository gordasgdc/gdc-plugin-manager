import SwiftUI
import AppKit
import GDCPluginManagerCore

/// Filigran sezonier — Etapa 6 (2026-08-29). O imagine MARE (nu o
/// iconiță), la opacitate mică, "gravată" în fundalul ferestrei: ocupă o
/// porțiune generoasă din colțul dreapta-jos, non-interactivă
/// (`allowsHitTesting(false)`), fără să concureze cu conținutul din
/// prim-plan. `nil` => nimic randat, fundalul Shift normal rămâne
/// neschimbat.
extension SeasonalPosition {
    var alignment: Alignment {
        switch self {
        case .bottomTrailing: return .bottomTrailing
        case .bottomLeading: return .bottomLeading
        case .topTrailing: return .topTrailing
        case .topLeading: return .topLeading
        case .center: return .center
        }
    }
}

/// Toate filigranele active acum, fiecare la poziția lui configurată —
/// 2026-08-29. `Catalog.activeSeasonalBackgrounds` a filtrat deja după
/// `isActiveNow` și a rezolvat coliziunile de poziție (ultimul adăugat
/// câștigă, vezi comentariul de acolo), deci aici doar randăm.
struct SeasonalBackgroundsLayer: View {
    let configs: [SeasonalBackgroundConfig]

    var body: some View {
        ZStack {
            ForEach(configs) { config in
                SeasonalBackgroundLayer(config: config)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: config.position.alignment)
            }
        }
        .allowsHitTesting(false)
    }
}

struct SeasonalBackgroundLayer: View {
    let config: SeasonalBackgroundConfig
    @State private var nsImage: NSImage?

    /// Cache local pe disc (Etapa 8) — la fel ca `catalog-cache.json`, ca
    /// filigranul să rămână vizibil offline / la eșec de rețea.
    ///
    /// CHEIAT PER FILIGRAN (2026-08-29): era un singur fișier global
    /// `seasonal-background-cache`, ceea ce cu o bibliotecă de mai multe
    /// filigrane ar fi însemnat că ultimul descărcat suprascrie cache-ul
    /// tuturor celorlalte (offline, toate ar fi arătat aceeași imagine).
    private var cacheFileURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("GDCPluginManager")
            .appendingPathComponent("seasonal-cache", isDirectory: true)
            // `id` e slug de catalog (litere mici/cifre/cratime), dar
            // filtrăm oricum ce ar putea deveni cale ("/", "..").
            .appendingPathComponent(config.id.replacingOccurrences(of: "/", with: "_"))
    }

    var body: some View {
        // [2026-08-29, BUG REAL găsit și reparat] `.task` era atașat pe un
        // `Group { if let nsImage {...} }` — la primul randaj (`nsImage`
        // încă `nil`), acel Group nu are NICIUN copil concret, iar SwiftUI
        // pare să NU garanteze `.task`/`onAppear` pe un asemenea "gol
        // condițional" (confirmat printr-un print de diagnostic care
        // NICIODATĂ nu apărea — task-ul pur și simplu nu pornea, deci
        // fetch-ul de imagine nu se declanșa NICIODATĂ, indiferent ce era
        // publicat sau ce opacitate avea). Fix: `.task` atașat pe un
        // container CONCRET, mereu prezent (`Color.clear` cu `frame` fix),
        // cu imaginea suprapusă DOAR când există — containerul de bază nu
        // mai depinde de starea condițională.
        Color.clear
            .frame(width: 480, height: 480)
            .overlay {
                if let nsImage {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        // [2026-08-29] Intensitate per-filigran, nu mai o
                        // constantă globală - vezi SeasonalBackgroundConfig.opacity.
                        .opacity(config.opacity)
                }
            }
            // [2026-08-29, corectat la cererea lui Cristi] Padding NEGATIV
            // aici împingea imaginea în afara ferestrei și îi tăia efectiv
            // o bucată vizibilă din colț ("îmi mănâncă din imagine"). Acum
            // inset POZITIV — filigranul rămâne întreg, doar cu puțin
            // spațiu față de margine.
            // [2026-08-29, mărit la cererea lui Cristi] 24pt încă îl lipea
            // prea aproape de margine ("ca și cum l-ar tăia") — 48pt (dublu)
            // lasă o distanță vizibilă, clară, pe orice latură.
            .padding(config.position == .center ? 0 : 48)
        .task(id: config.imagePath) {
            // Log de diagnostic PERMANENT (nu print-uri temporare) — vezi
            // DiagnosticLog.swift. Motiv direct: bug-ul real de azi (task
            // neatașat corect, fetch-ul nu pornea niciodată) a fost gasit
            // DOAR adăugând print-uri temporare, rulând din Terminal cu
            // NSUnbufferedIO=YES. Cu logul permanent, un raport viitor de
            // gen "nu apare filigranul" se diagnostichează direct din
            // %TEMP%/gdcpm-crash.log, fără să mai reproducem manual bug-ul.
            DiagnosticLog.write("SeasonalBackground", "task pornit pt. id=\(config.id) imagePath=\(config.imagePath)")
            guard let url = config.imageURL else {
                DiagnosticLog.write("SeasonalBackground", "id=\(config.id): imageURL NIL")
                nsImage = nil
                return
            }
            // NU AsyncImage: decodorul lui SwiftUI nu randează fiabil SVG
            // pe macOS (2026-08-29, filigran Black Friday invizibil în
            // Client — cauza reală). `NSImage(data:)` ȘTIE nativ SVG
            // (suport adăugat în macOS 12+), la fel ca orice raster.
            //
            // [2026-08-29] RETRY + eroare reală în log — găsit live (raportat
            // de Cristi): un filigran eșua consecvent la fetch în timp ce
            // altul, publicat în același minut, mergea perfect — verificat
            // direct că fișierul era disponibil pe server (HTTP 200, `curl`)
            // exact cât timp aplicația raporta eșec. Concluzie: nu era un
            // bug de cod, ci un blip TRANZITORIU de rețea/CDN (gordas.dev
            // trece prin Cloudflare ȘI Fastly/GitHub Pages — un nod de edge
            // poate rata o cerere fără ca alta, milisecunde mai târziu, s-o
            // rateze). `try?` ascundea eroarea REALĂ (timeout? DNS? TLS?) —
            // acum se loghează explicit. Un singur retry, cu pauză scurtă,
            // rezolvă marea majoritate a acestor blip-uri fără interacțiune
            // manuală (fără "Reîmprospătează" apăsat de 10 ori).
            // [2026-08-29, val 2 — BUG REAL găsit din log-ul de diagnostic]
            // `URLSession.shared.data(from:)` NU aruncă la un status HTTP de
            // eroare (404/500) — aruncă DOAR la eșec de rețea (DNS/TLS/
            // timeout). Un 404 tranzitoriu de CDN (edge stale, imediat după
            // republish — vezi comentariul de mai sus) trecea deci prin
            // ramura de "succes", primea corpul paginii de eroare a
            // GitHub Pages (9115 bytes, identic pe toate filigranele
            // afectate), eșua la `NSImage(data:)`, și IEȘEA din buclă cu
            // `break` — fără al doilea retry, exact eșecul pe care retry-ul
            // exista să-l repare. Fix: statusul HTTP se verifică EXPLICIT
            // înainte de decodare; orice non-200 (sau eșec de decodare a
            // unui răspuns 200, date corupte) se tratează ca eșec real, care
            // CONTINUĂ bucla de retry, nu `break`.
            var lastError: Error?
            var loaded = false
            for attempt in 1...2 {
                do {
                    let (data, response) = try await URLSession.shared.data(from: url)
                    let status = (response as? HTTPURLResponse)?.statusCode ?? -1
                    guard status == 200 else {
                        DiagnosticLog.write("SeasonalBackground", "id=\(config.id): HTTP \(status) (\(data.count) bytes) la încercarea \(attempt)")
                        lastError = nil
                        if attempt == 1 { try? await Task.sleep(nanoseconds: 800_000_000) }
                        continue
                    }
                    guard let image = NSImage(data: data) else {
                        DiagnosticLog.write("SeasonalBackground", "id=\(config.id): HTTP 200 (\(data.count) bytes) dar NSImage nu a decodat (încercarea \(attempt))")
                        lastError = nil
                        if attempt == 1 { try? await Task.sleep(nanoseconds: 800_000_000) }
                        continue
                    }
                    DiagnosticLog.write("SeasonalBackground", "id=\(config.id): OK, \(data.count) bytes, HTTP 200 (încercarea \(attempt))")
                    nsImage = image
                    saveToCache(data: data)
                    loaded = true
                    break
                } catch {
                    lastError = error
                    DiagnosticLog.write("SeasonalBackground", "id=\(config.id): fetch EȘUAT la încercarea \(attempt): \(error)")
                    if attempt == 1 {
                        try? await Task.sleep(nanoseconds: 800_000_000) // 0.8s, apoi reîncearcă o dată
                    }
                }
            }
            if !loaded {
                if let cached = try? Data(contentsOf: cacheFileURL), let image = NSImage(data: cached) {
                    DiagnosticLog.write("SeasonalBackground", "id=\(config.id): fetch eșuat de 2 ori (\(String(describing: lastError))), fallback pe cache local reușit")
                    nsImage = image
                } else {
                    DiagnosticLog.write("SeasonalBackground", "id=\(config.id): fetch eșuat de 2 ori (\(String(describing: lastError))) ȘI niciun cache local disponibil")
                }
            }
        }
    }

    private func saveToCache(data: Data) {
        try? FileManager.default.createDirectory(at: cacheFileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: cacheFileURL)
    }
}
