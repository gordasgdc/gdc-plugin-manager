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

    private var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    private let dismissedVersionKey = "gdcpm_dismissed_update_version"

    func check() async {
        guard let (data, response) = try? await URLSession.shared.data(from: Self.updateURL),
              let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
              let info = try? JSONDecoder().decode(UpdateInfo.self, from: data) else { return }

        guard Self.isNewer(info.version, than: currentVersion) else {
            availableUpdate = nil
            return
        }
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
