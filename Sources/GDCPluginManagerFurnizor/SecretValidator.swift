import Foundation
import GDCPluginManagerCore

/// Verifică o valoare NOUĂ înainte să fie scrisă undeva.
///
/// DE CE ÎNAINTE, NU DUPĂ: un token greșit copiat (trunchiat la copiere, cu
/// un spațiu lipit la final, generat pe alt cont sau fără repo-ul potrivit
/// bifat) arată exact ca unul bun. Scris fără verificare, defectul apare
/// abia la următorul build sau, mai rău, abia la clienți. Validarea aici
/// face un apel REAL cu valoarea nouă și acceptă doar ce funcționează.
enum ValidationKind {
    /// PAT fine-grained: trebuie să poată citi FIECARE repo din listă.
    /// Un token generat corect, dar cu un singur repo bifat din patru, e
    /// exact genul de greșeală care trece neobservată.
    case githubPAT(repos: [String])
    /// Cheie Supabase: trebuie să poată interoga tabelul dat.
    case supabaseKey(table: String)
    case youTubeAPIKey
    /// Nu se poate valida automat (certificat, cheie de semnare, secret de CI).
    case none
}

struct ValidationResult {
    let ok: Bool
    let message: String
    /// Completat când sursa răspunde și cu o dată de expirare (PAT-urile).
    var expiresAt: Date?
}

enum SecretValidator {

    static func validate(_ value: String, kind: ValidationKind) async -> ValidationResult {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return ValidationResult(ok: false, message: "Câmpul e gol.")
        }
        // Greșeala cea mai frecventă și cea mai greu de văzut cu ochiul:
        // spații sau un newline lipite la copiere. Le semnalăm explicit în
        // loc să le tăiem tăcut, ca să se știe ce s-a salvat.
        if trimmed != value {
            return ValidationResult(ok: false, message: "Valoarea are spații sau rând nou la început/sfârșit. Copiaz-o din nou, fără ele.")
        }

        switch kind {
        case .githubPAT(let repos):
            return await validateGitHubPAT(trimmed, repos: repos)
        case .supabaseKey(let table):
            return await validateSupabaseKey(trimmed, table: table)
        case .youTubeAPIKey:
            return await validateYouTube(trimmed)
        case .none:
            return ValidationResult(ok: true, message: "Nu se poate verifica automat — urmează pașii manuali din ghid.")
        }
    }

    // MARK: GitHub

    private static func validateGitHubPAT(_ token: String, repos: [String]) async -> ValidationResult {
        var unreachable: [String] = []
        var expiresAt: Date?

        for repo in repos {
            var request = URLRequest(url: URL(string: "https://api.github.com/repos/\(ResourceRepos.ownerLogin)/\(repo)")!)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")

            guard let (_, response) = try? await URLSession.shared.data(for: request),
                  let http = response as? HTTPURLResponse else {
                return ValidationResult(ok: false, message: "Fără răspuns de la GitHub. Verifică internetul și reîncearcă.")
            }
            if http.statusCode == 401 {
                return ValidationResult(ok: false, message: "GitHub respinge tokenul (401). Probabil e trunchiat sau deja revocat.")
            }
            if http.statusCode != 200 {
                unreachable.append(repo)
                continue
            }
            if expiresAt == nil, let raw = http.value(forHTTPHeaderField: "github-authentication-token-expiration") {
                expiresAt = SecretRegistry.parseGitHubExpiration(raw)
            }
        }

        if !unreachable.isEmpty {
            return ValidationResult(
                ok: false,
                message: "Tokenul e valid, dar NU vede \(unreachable.count) din \(repos.count) repo-uri: \(unreachable.joined(separator: ", ")). Întoarce-te la „Repository access” și bifează-le pe toate."
            )
        }

        var message = "Funcționează pe toate cele \(repos.count) repo-uri."
        if let expiresAt {
            let days = Int((expiresAt.timeIntervalSinceNow / 86400).rounded(.down))
            message += " Expiră în \(days) zile (\(expiresAt.formatted(date: .abbreviated, time: .omitted)))."
            // Un token nou cu viață scurtă e aproape sigur o expirare aleasă
            // greșit în formular — merită spus acum, nu peste o lună.
            if days < 60 {
                message += " Atenție: e neobișnuit de scurt pentru un token de producție."
            }
        }
        return ValidationResult(ok: true, message: message, expiresAt: expiresAt)
    }

    // MARK: Supabase

    private static func validateSupabaseKey(_ key: String, table: String) async -> ValidationResult {
        var components = URLComponents(url: SupabaseConfig.restURL(table: table), resolvingAgainstBaseURL: false)
        components?.query = "select=*&limit=1"
        guard let url = components?.url else {
            return ValidationResult(ok: false, message: "URL Supabase invalid.")
        }
        var request = URLRequest(url: url)
        request.setValue(key, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse else {
            return ValidationResult(ok: false, message: "Fără răspuns de la Supabase. Verifică internetul.")
        }
        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8)?.prefix(160) ?? ""
            return ValidationResult(ok: false, message: "Supabase a răspuns \(http.statusCode). \(body)")
        }
        return ValidationResult(ok: true, message: "Citește tabelul „\(table)" + "” — cheia are drepturile necesare.",
                                expiresAt: SecretRegistry.jwtExpiry(key))
    }

    // MARK: YouTube

    private static func validateYouTube(_ key: String) async -> ValidationResult {
        // Un id de videoclip public, stabil de peste un deceniu: verificăm
        // cheia, nu existența unui anumit tutorial al lui Cristi.
        let url = URL(string: "https://www.googleapis.com/youtube/v3/videos?part=snippet&id=jNQXAC9IVRw&key=\(key)")!
        guard let (data, response) = try? await URLSession.shared.data(from: url),
              let http = response as? HTTPURLResponse else {
            return ValidationResult(ok: false, message: "Fără răspuns de la Google. Verifică internetul.")
        }
        guard http.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? ""
            if body.contains("API key not valid") {
                return ValidationResult(ok: false, message: "Cheia nu e validă.")
            }
            if body.contains("has not been used") || body.contains("disabled") {
                return ValidationResult(ok: false, message: "Cheia e validă, dar YouTube Data API v3 nu e activat pe proiectul ei.")
            }
            return ValidationResult(ok: false, message: "Google a răspuns \(http.statusCode).")
        }
        return ValidationResult(ok: true, message: "Cheia funcționează.")
    }
}
