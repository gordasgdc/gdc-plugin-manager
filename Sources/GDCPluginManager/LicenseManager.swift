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
    /// it needs its own license. No app-wide trial: the app is free,
    /// only products cost money.
    func isUnlocked(for item: PluginItem) -> Bool {
        licensedProducts[item.id] != nil
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

    private func loadSavedLicenses() {
        guard let store = loadStore() else { return }
        for (productID, code) in store {
            if case .success(let payload) = LicenseCore.validate(serial: code, expectedProductID: productID) {
                licensedProducts[productID] = payload
            }
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
        case .wrongMachine: return L.t("license.error.wrongMachine")
        case .expired: return L.t("license.error.expired")
        }
    }
}
