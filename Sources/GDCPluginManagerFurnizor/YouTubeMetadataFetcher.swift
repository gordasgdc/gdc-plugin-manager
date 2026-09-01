import Foundation

/// Preia automat metadate de la un link YouTube — cerință directă
/// (2026-09-01): "atunci când bag linkul ... să creeze ca un fel de
/// embedded ... titlul, descrierea, tagurile, imaginea".
///
/// Titlu + imagine: prin oEmbed public (`youtube.com/oembed`), fără nicio
/// cheie — funcționează mereu, pentru orice video public. Descriere +
/// taguri: necesită YouTube Data API v3 (cheie personală, gratuită, din
/// Google Cloud Console — Cristi o lipește o singură dată în Furnizor,
/// Setări → "Cheie YouTube Data API"). FĂRĂ cheie configurată, descrierea
/// și tagurile rămân goale, editabile manual — fail-open, ca restul
/// integrărilor externe din ecosistem (Regula 27/PricingChecker).
enum YouTubeMetadataFetcher {
    struct FetchedMetadata {
        let videoID: String
        let title: String
        let thumbnailURL: String
        let description: String
        let tags: [String]
    }

    enum FetchError: Error, LocalizedError {
        case invalidURL
        case networkError(String)

        var errorDescription: String? {
            switch self {
            case .invalidURL: return "Link YouTube invalid — verifică formatul (youtube.com/watch?v=... sau youtu.be/...)."
            case .networkError(let msg): return "Eroare de rețea: \(msg)"
            }
        }
    }

    private static let apiKeyDefaultsKey = "youtube_data_api_key"

    static var dataAPIKey: String {
        get { UserDefaults.standard.string(forKey: apiKeyDefaultsKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: apiKeyDefaultsKey) }
    }

    /// Acceptă watch?v=, youtu.be/, shorts/, embed/, sau un ID gol/deja curat.
    static func extractVideoID(from urlString: String) -> String? {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let components = URLComponents(string: trimmed) else { return nil }

        if let host = components.host, host.contains("youtu.be") {
            let id = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            return id.isEmpty ? nil : id
        }
        if let queryItems = components.queryItems, let v = queryItems.first(where: { $0.name == "v" })?.value, !v.isEmpty {
            return v
        }
        for marker in ["/shorts/", "/embed/", "/v/"] {
            if let range = trimmed.range(of: marker) {
                let rest = trimmed[range.upperBound...]
                let id = rest.split(separator: "?").first.map(String.init) ?? String(rest)
                return id.isEmpty ? nil : id
            }
        }
        // Poate fi deja doar un ID (11 caractere, alfanumeric + -_).
        if trimmed.count == 11, trimmed.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }) {
            return trimmed
        }
        return nil
    }

    static func fetch(youtubeURL urlString: String) async throws -> FetchedMetadata {
        guard let videoID = extractVideoID(from: urlString) else { throw FetchError.invalidURL }

        // Pasul 1: oEmbed - titlu + thumbnail, fara cheie, mereu disponibil.
        var title = "Tutorial YouTube"
        var thumbnail = "https://img.youtube.com/vi/\(videoID)/maxresdefault.jpg"
        if let oembedURL = URL(string: "https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v=\(videoID)&format=json") {
            do {
                let (data, response) = try await URLSession.shared.data(from: oembedURL)
                if let http = response as? HTTPURLResponse, http.statusCode == 200,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    title = (json["title"] as? String) ?? title
                    if let thumb = json["thumbnail_url"] as? String { thumbnail = thumb }
                }
            } catch {
                // fail-open: pastram valorile implicite, userul completeaza manual
            }
        }

        // Pasul 2 (optional): YouTube Data API v3 - descriere + taguri,
        // doar daca Cristi a configurat o cheie in Setari Furnizor.
        var description = ""
        var tags: [String] = []
        let key = dataAPIKey
        if !key.isEmpty, let apiURL = URL(string: "https://www.googleapis.com/youtube/v3/videos?part=snippet&id=\(videoID)&key=\(key)") {
            do {
                let (data, response) = try await URLSession.shared.data(from: apiURL)
                if let http = response as? HTTPURLResponse, http.statusCode == 200,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let items = json["items"] as? [[String: Any]],
                   let snippet = items.first?["snippet"] as? [String: Any] {
                    description = (snippet["description"] as? String) ?? ""
                    tags = (snippet["tags"] as? [String]) ?? []
                    if title == "Tutorial YouTube", let realTitle = snippet["title"] as? String { title = realTitle }
                }
            } catch {
                // fail-open: descrierea/tagurile raman goale, editabile manual
            }
        }

        return FetchedMetadata(videoID: videoID, title: title, thumbnailURL: thumbnail, description: description, tags: tags)
    }
}
