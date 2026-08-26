import Foundation

struct UpdateInfo: Decodable {
    let version: String
    let release_date: String?
    let changes: String?
    let download_url: [String: String]
    let mandatory: Bool?
    let min_version: String?
}

/// Verifica docs/update.json (acelasi pattern de JSON static ca in
/// gdc-production-manager) pentru o versiune de APLICATIE mai noua decat
/// cea instalata. Pur informativ — nu blocheaza niciodata nimic, doar
/// arata un banner cu link de descarcare.
///
/// =====================================================================
/// PROCESS: doua fluxuri de actualizare COMPLET DIFERITE, a nu se confunda
/// =====================================================================
///
/// 1. PRODUSE (LUT / DCTL / OFX / Fuse / PowerGrade) — in-app, 1 click.
///      sursa:    catalog.json (`PluginItem.version`)
///      compara:  InstallManager.hasUpdate(_:) — versiunea din catalog vs
///                cea salvata local in installedVersions
///      actiune:  butonul "Actualizeaza" de pe card -> InstallManager.install
///      rezultat: fisierele se descarca si se scriu direct, fara browser.
///    Asta E deja complet automat: dupa ce Furnizor publica o versiune
///    noua, clientii o vad la urmatorul refresh de catalog si o iau cu un
///    click.
///
/// 2. APLICATIA IN SINE — NU e self-update, deschide browserul.
///      sursa:    update.json (campul `version`, comun Mac + Windows)
///      compara:  isNewer(_:than:) vs CFBundleShortVersionString
///      actiune:  butonul "Descarca" din UpdateBanner -> NSWorkspace.open
///      rezultat: se deschide browserul, userul descarca arhiva si
///                reinstaleaza manual.
///
/// WARNING: pasul 2 NU e un self-updater. Ca sa devina 1-click in-app ar
/// trebui descarcare in fundal + inlocuirea bundle-ului .app + repornire —
/// o aplicatie nu-si poate suprascrie propriul bundle cat timp ruleaza,
/// deci ar fi nevoie de un helper separat care asteapta iesirea. Nu e
/// implementat; daca cineva cere "update cu 1 click", asta e piesa care
/// lipseste.
///
/// WARNING: `update.json` are UN SINGUR camp `version`, comun ambelor
/// platforme. Orice rebuild real trebuie sa creasca versiunea in Info.plist
/// (Mac), in .csproj + installer.iss (Windows) SI in update.json. Refolosirea
/// aceluiasi tag cu `--clobber` lasa update.json in urma si notificarea nu
/// se mai declanseaza niciodata pentru cei care au deja aplicatia instalata.
@MainActor
final class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()

    static let updateURL = URL(string: "https://gordas.dev/update.json")!

    @Published private(set) var availableUpdate: UpdateInfo?

    /// PITFALL FIXED 2026-08-26: `availableUpdate` respecta filtrul de
    /// dismissal (corect pentru banner/popup, care nu trebuie sa reapara pe
    /// o versiune deja inchisa). Dar verificarea MANUALA ("Check for
    /// Updates..." din meniu / butonul din Preferences) citea tot
    /// `availableUpdate` — daca versiunea fusese respinsa o data (chiar din
    /// greseala), verificarea manuala minea "esti la zi" desi exista clar o
    /// versiune mai noua. Reprodus live pe Windows (structura identica) cu
    /// un log real: `info.Version=1.3.0, IsNewer=True, dismissed=1.3.0`.
    /// `latestInfo` e sursa ADEVARATA, necenzurata de dismissal — orice
    /// verificare declansata manual de user trebuie sa citeasca de aici.
    @Published private(set) var latestInfo: UpdateInfo?

    private var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    private let dismissedVersionKey = "gdcpm_dismissed_update_version"

    /// Cache-buster pe fiecare cerere: GitHub Pages (Fastly) serveste
    /// docs/update.json cu `max-age=600` — un nod CDN care a raspuns o
    /// data la un update.json vechi il tine cache-uit pana la 10 minute,
    /// indiferent ce publicam intre timp. Pitfall identic celui deja
    /// documentat pentru coperti (CoverImageStore) — acolo solutia a fost
    /// un query param derivat din continut; aici, un check de update
    /// trebuie sa fie mereu proaspat, nu doar stabil, deci un query param
    /// NOU la fiecare apel (timestamp) e alegerea corecta.
    private static func cacheBustedUpdateURL() -> URL {
        var components = URLComponents(url: updateURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "t", value: String(Int(Date().timeIntervalSince1970)))]
        return components.url!
    }

    func check() async {
        let url = Self.cacheBustedUpdateURL()
        DiagnosticLog.write("UpdateChecker", "check() start. currentVersion=\(currentVersion), GET \(url.absoluteString)")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(from: url)
        } catch {
            DiagnosticLog.write("UpdateChecker", "Cerere esuata: \(error)")
            return
        }
        guard let http = response as? HTTPURLResponse else {
            DiagnosticLog.write("UpdateChecker", "Raspuns fara HTTPURLResponse (neasteptat).")
            return
        }
        DiagnosticLog.write("UpdateChecker", "HTTP \(http.statusCode)")
        guard (200...299).contains(http.statusCode) else {
            DiagnosticLog.write("UpdateChecker", "Status neasteptat, opresc aici.")
            return
        }
        let info: UpdateInfo
        do {
            info = try JSONDecoder().decode(UpdateInfo.self, from: data)
        } catch {
            let body = String(data: data, encoding: .utf8) ?? "<nu e text UTF-8>"
            DiagnosticLog.write("UpdateChecker", "Decodare esuata: \(error). Body: \(body)")
            return
        }
        DiagnosticLog.write("UpdateChecker", "info.version=\(info.version)")

        guard Self.isNewer(info.version, than: currentVersion) else {
            DiagnosticLog.write("UpdateChecker", "isNewer=false — nu e mai noua, sau egala.")
            availableUpdate = nil
            latestInfo = nil
            return
        }
        latestInfo = info
        // PITFALL FIXED 2026-08-24: `mandatory` exista in JSON de la
        // inceput dar nu era citit nicaieri — un update marcat mandatory
        // se comporta identic cu unul optional (un singur "Later" il
        // ascundea definitiv). Acum un update mandatory IGNORA inchiderea
        // anterioara: reapare la fiecare check() (lansare/refresh) cat
        // timp versiunea instalata ramane veche. Tot nu blocheaza
        // folosirea aplicatiei — asta ar cere un helper de self-update
        // real (vezi WARNING de mai sus) — dar userul nu mai poate sa
        // "uite" definitiv de un fix critic cu un singur click.
        let dismissed = UserDefaults.standard.string(forKey: dismissedVersionKey)
        let alreadyDismissed = (dismissed == info.version) && info.mandatory != true
        availableUpdate = alreadyDismissed ? nil : info
    }

    func dismiss() {
        guard let info = availableUpdate else { return }
        if info.mandatory != true {
            UserDefaults.standard.set(info.version, forKey: dismissedVersionKey)
        }
        availableUpdate = nil
    }

    /// Simple dot-separated integer version comparison (1.2.0 > 1.10.0
    /// is compared numerically per segment, not lexicographically).
    private static func isNewer(_ a: String, than b: String) -> Bool {
        let partsA = a.split(separator: ".").map { Int($0) ?? 0 }
        let partsB = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(partsA.count, partsB.count) {
            let x = i < partsA.count ? partsA[i] : 0
            let y = i < partsB.count ? partsB[i] : 0
            if x != y { return x > y }
        }
        return false
    }
}
