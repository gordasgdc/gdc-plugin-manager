import Foundation

/// Verificare ONLINE, opțională, peste licențierea existentă (Ed25519,
/// 100% offline) — vezi CLAUDE.md, Partea 1, Regula 12. Adaugă un
/// "kill-switch" pe care Cristi îl poate declanșa manual din Furnizor
/// (sabotaj/abuz al unui cod deja activat), FĂRĂ să schimbe deloc formatul
/// criptografic al codurilor existente — pur aditiv, retrocompatibil.
///
/// FAIL-OPEN, niciodată fail-closed: absența unui răspuns POZITIV de
/// revocare (eroare de rețea, offline, request eșuat) înseamnă NErevocat.
/// O licență deja activată local nu se blochează NICIODATĂ doar pentru că
/// utilizatorul e offline — revocarea se aplică abia la următoarea
/// verificare online reușită care confirmă explicit `true`. Același
/// principiu de gratie ca `LicenseManager.gracePeriodSeconds` (HWID).
///
/// Folosește apelul RPC `is_license_revoked(machine_id, product_id)` din
/// Supabase (vezi supabase/migrations/2026-08-26_license_revocations.sql)
/// — NICIODATĂ un SELECT direct pe tabel: RLS blochează complet accesul
/// direct cu cheia anon, tocmai ca niciun client să nu poată enumera
/// machine_id-urile altor clienți revocați.
public final class RevocationCheck: @unchecked Sendable {
    public static let shared = RevocationCheck()

    /// ID-urile de produs confirmate revocate printr-un raspuns POZITIV
    /// de la server, in aceasta sesiune. Niciodata populat pe baza unei
    /// erori/timeout — doar pe baza unui `true` explicit primit. Accesat
    /// atat sincron (isUnlocked, orice thread) cat si dintr-un Task async
    /// (refresh) — protejat cu un lock simplu, nu MainActor, ca sa nu
    /// forteze fiecare apelant sincron sa devina async.
    private let lock = NSLock()
    private var _revokedProductIDs: Set<String> = []
    public var revokedProductIDs: Set<String> {
        lock.lock(); defer { lock.unlock() }
        return _revokedProductIDs
    }

    private init() {}

    public func isRevoked(_ productID: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return _revokedProductIDs.contains(productID)
    }

    private func markRevoked(_ productID: String) {
        lock.lock(); defer { lock.unlock() }
        _revokedProductIDs.insert(productID)
    }

    /// Reverifica toate produsele licentiate local. Apelata la lansare +
    /// dupa fiecare activare noua — niciodata blocanta pentru UI (fiecare
    /// verificare individuala esueaza silentios pe orice problema de retea).
    public func refresh(productIDs: [String]) async {
        for productID in productIDs {
            if let revoked = await checkOne(machineID: MachineID.display, productID: productID), revoked {
                markRevoked(productID)
            }
        }
    }

    private func checkOne(machineID: String, productID: String) async -> Bool? {
        guard SupabaseConfig.projectURL.hasPrefix("https://") else { return nil }
        let url = URL(string: SupabaseConfig.projectURL)!.appendingPathComponent("rest/v1/rpc/is_license_revoked")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        let body: [String: String] = ["p_machine_id": machineID, "p_product_id": productID]
        guard let data = try? JSONSerialization.data(withJSONObject: body) else { return nil }
        request.httpBody = data
        request.timeoutInterval = 8

        guard let (respData, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            return nil // orice eroare de retea/server -> fail-open, NU revocat
        }
        // PostgREST RPC pentru o functie ce intoarce `boolean` da inapoi
        // literal `true`/`false` ca body JSON.
        if let text = String(data: respData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
            return text == "true"
        }
        return nil
    }
}
