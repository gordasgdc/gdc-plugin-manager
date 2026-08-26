import Foundation
import GDCPluginManagerCore

/// Owns GDC Plugin Manager's per-product license state. The app itself
/// is free — anyone can install and browse the catalog UI — only
/// installing/updating a specific product requires that product's own
/// license. Same crypto/format as every other GDC product
/// (LicenseCore.swift), just applied once per item instead of once
/// globally for the whole app.
final class LicenseManager: ObservableObject {
    static let shared = LicenseManager()

    /// [productID: verified payload] — rebuilt from disk at launch and
    /// after every successful activation. A product ID appears here only
    /// if its stored serial still validates (expiry/machine-lock are
    /// re-checked on every load, never cached as a bare bool).
    @Published private(set) var licensedProducts: [String: LicenseCore.Payload] = [:]
    @Published var activationError: String?

    /// [productID: raw serial code] — the only thing persisted; payloads
    /// are always re-derived by re-validating on load, same discipline
    /// as the old single-license file.
    private var storeFileURL: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("GDCPluginManager", isDirectory: true)
            .appendingPathComponent("licenses.json")
    }

    private init() {
        loadSavedLicenses()
    }

    var isLicensed: Bool { !licensedProducts.isEmpty }

    /// The check before install/update/remove for one specific item —
    /// free items need no license at all; everything else needs its own.
    /// No app-wide trial: the app is free, only paid products need
    /// unlocking, and free ones are just... free.
    func isUnlocked(for item: PluginItem) -> Bool {
        item.isFree || (licensedProducts[item.id] != nil && !RevocationCheck.shared.isRevoked(item.id))
    }

    /// Reverifica revocarea online (fail-open, vezi RevocationCheck.swift)
    /// pentru toate produsele licentiate curent. Apelata la lansare —
    /// niciodata sincron/blocanta pentru UI.
    func refreshRevocations() async {
        await RevocationCheck.shared.refresh(productIDs: Array(licensedProducts.keys))
    }

    /// Validates a pasted code against every product currently in the
    /// catalog. A serial only embeds a HASH of its product ID (see
    /// LicenseCore's format comment), not the ID itself, so there's no
    /// way to know which product a code is for without trying
    /// candidates — cheap and entirely local for a catalog this size.
    @discardableResult
    func activate(code: String, candidateProductIDs: [String]) -> Bool {
        activationError = nil
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !candidateProductIDs.isEmpty else {
            activationError = L.t("license.error.catalogNotLoaded")
            return false
        }

        // Malformed/bad-signature/wrong-machine/expired are all
        // independent of *which* product ID we check against — the
        // first candidate's answer is authoritative for all of them.
        // Only .wrongProduct is candidate-specific, so that's the only
        // case worth looping on.
        var lastError: LicenseCore.ValidationError = .wrongProduct
        for productID in candidateProductIDs {
            switch LicenseCore.validate(serial: trimmed, expectedProductID: productID) {
            case .success(let payload):
                saveLicense(productID: productID, code: trimmed)
                licensedProducts[productID] = payload
                Task { await RevocationCheck.shared.refresh(productIDs: [productID]) }
                return true
            case .failure(.wrongProduct):
                lastError = .wrongProduct
                continue
            case .failure(let otherError):
                activationError = Self.message(for: otherError)
                return false
            }
        }
        activationError = Self.message(for: lastError)
        return false
    }

    func deactivate(productID: String) {
        licensedProducts.removeValue(forKey: productID)
        guard let url = storeFileURL,
              var store = loadStore() else { return }
        store.removeValue(forKey: productID)
        try? writeStore(store, to: url)
    }

    /// Reincarca si reverifica fiecare cod stocat — niciodata un flag
    /// cache-uit (GDC-SEC-05). Kill-switch diferentiat (decizie 2026-08-24):
    ///   - badSignature/malformedCode -> tamper evident: sters din store de
    ///     pe disc (hard lock), nu doar din memorie.
    ///   - hwidUnavailable -> grace period: daca ultima verificare buna e
    ///     recenta, ramane licentiat (payload atasat erorii); altfel demo.
    ///   - wrongMachine/wrongProduct/expired -> demo, codul ramane pe disc.
    private func loadSavedLicenses() {
        guard var store = loadStore() else { return }

        let hwidAvailable = MachineID.isAvailable
        let lastGood = readLastGoodTimestamp()
        let graceActive = lastGood != 0 && (Date().timeIntervalSince1970 - lastGood) < Self.gracePeriodSeconds
        var anyValidated = false
        var removedAny = false

        for (productID, code) in store {
            switch LicenseCore.validate(serial: code, expectedProductID: productID, hwidAvailable: hwidAvailable) {
            case .success(let payload):
                licensedProducts[productID] = payload
                anyValidated = true
            case .failure(.badSignature), .failure(.malformedCode):
                // Tamper evident — elimina codul falsificat/corupt de pe disc.
                store.removeValue(forKey: productID)
                removedAny = true
            case .failure(.hwidUnavailable(let payload)) where graceActive:
                licensedProducts[productID] = payload // grace activ — pastreaza starea buna anterioara
            case .failure:
                // hwidUnavailable (grace expirat) / wrongMachine / wrongProduct / expired
                // -> mod demo, codul ramane pe disc ca istoric.
                break
            }
        }

        if anyValidated {
            writeLastGoodTimestamp(Date().timeIntervalSince1970)
        }
        if removedAny, let url = storeFileURL {
            try? writeStore(store, to: url)
        }
    }

    private func saveLicense(productID: String, code: String) {
        guard let url = storeFileURL else { return }
        var store = loadStore() ?? [:]
        store[productID] = code
        try? writeStore(store, to: url)
    }

    private func loadStore() -> [String: String]? {
        guard let url = storeFileURL,
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data) else { return nil }
        return decoded
    }

    private func writeStore(_ store: [String: String], to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(store)
        try data.write(to: url)
    }

    private static func message(for error: LicenseCore.ValidationError) -> String {
        switch error {
        case .malformedCode: return L.t("license.error.malformed")
        case .badSignature: return L.t("license.error.badSignature")
        case .wrongProduct: return L.t("license.error.wrongProduct")
        case .wrongPlatform: return L.t("license.error.wrongPlatform")
        case .wrongMachine: return L.t("license.error.wrongMachine")
        case .hwidUnavailable: return L.t("license.error.hwidUnavailable")
        case .expired: return L.t("license.error.expired")
        }
    }

    // MARK: - Kill-switch diferentiat (decizie 2026-08-24)
    //
    // Pe Mac practic inatins (IOKit rareori esueaza real), dar pastram
    // acelasi mecanism ca Windows/C++/Python pentru simetrie si ca sa nu
    // fim surprinsi daca apare vreodata (VM, sandbox restrictiv etc.).

    private static let gracePeriodSeconds: TimeInterval = 5 * 86400 // 5 zile

    private var graceFileURL: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("GDCPluginManager", isDirectory: true)
            .appendingPathComponent("last_good_hwid.txt")
    }

    private func readLastGoodTimestamp() -> TimeInterval {
        guard let url = graceFileURL,
              let text = try? String(contentsOf: url, encoding: .utf8),
              let ts = TimeInterval(text.trimmingCharacters(in: .whitespacesAndNewlines)) else { return 0 }
        return ts
    }

    private func writeLastGoodTimestamp(_ ts: TimeInterval) {
        guard let url = graceFileURL else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? "\(ts)".write(to: url, atomically: true, encoding: .utf8)
    }
}
