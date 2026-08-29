import Foundation

/// Cautare fuzzy simpla, fara dependinta externa — potrivita pentru un
/// catalog de marime mica/medie (zeci-sute de produse), nu pentru indexare
/// de text la scara mare. Doua strategii combinate:
/// 1. Substring pe textul normalizat (fara diacritice, fara majuscule) —
///    prinde orice cautare "corecta" sau partiala instant.
/// 2. Distanta Levenshtein marginita per-cuvant — prinde typo-uri (1-2
///    caractere gresite/lipsa/in plus), fara sa devina lenta pe texte lungi.
public enum FuzzySearch {
    /// Elimina diacritice si normalizeaza la lowercase, ca "Crăciun" si
    /// "craciun" (sau "café"/"cafe") sa se potriveasca identic.
    public static func normalize(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
    }

    /// True daca `query` se potriveste cu `text`, exact sau aproximativ.
    /// `query` gol se potriveste mereu (cazul "nimic tastat inca").
    public static func matches(query: String, in text: String) -> Bool {
        let q = normalize(query).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return true }
        let t = normalize(text)
        if t.contains(q) { return true }

        // Typo tolerance: distanta editare marginita, scalata cu lungimea
        // interogarii (un cuvant de 3 litere nu tolereaza 2 greseli, ar
        // deveni un "match cu orice").
        let maxDistance = q.count <= 4 ? 1 : 2
        let words = t.split(separator: " ")
        for word in words {
            if levenshtein(q, String(word), limit: maxDistance) <= maxDistance {
                return true
            }
        }
        return false
    }

    /// True daca `query` se potriveste in ORICARE dintre campurile date —
    /// helper pentru "cauta in titlu, descriere, tip, id" dintr-un singur loc.
    public static func matches(query: String, inAny fields: [String?]) -> Bool {
        let q = normalize(query).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return true }
        return fields.contains { field in
            guard let field, !field.isEmpty else { return false }
            return matches(query: q, in: field)
        }
    }

    /// Distanta Levenshtein, cu iesire timpurie daca depaseste `limit`
    /// (nu conteaza cat de mare e distanta reala peste prag, doar ca a
    /// depasit) — suficient pentru "e un typo plauzibil sau nu".
    private static func levenshtein(_ a: String, _ b: String, limit: Int) -> Int {
        if abs(a.count - b.count) > limit { return limit + 1 }
        let a = Array(a), b = Array(b)
        var previous = Array(0...b.count)
        var current = [Int](repeating: 0, count: b.count + 1)
        for i in 1...max(a.count, 1) where a.count > 0 {
            current[0] = i
            var rowMin = current[0]
            for j in 1...max(b.count, 1) where b.count > 0 {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                current[j] = Swift.min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + cost)
                rowMin = Swift.min(rowMin, current[j])
            }
            if b.isEmpty { current[0] = i }
            if rowMin > limit { return limit + 1 }
            previous = current
        }
        return b.isEmpty ? a.count : previous[b.count]
    }
}

/// Istoric de căutări recente, persistat local (UserDefaults) — folosit
/// identic de orice bară de căutare din Client/Furnizor. Plafonat la 8
/// intrări (cea mai recentă prima), fără duplicate.
public final class SearchHistoryStore: ObservableObject {
    private let key: String
    private let limit = 8
    @Published public private(set) var recent: [String] = []

    public init(key: String) {
        self.key = key
        recent = UserDefaults.standard.stringArray(forKey: key) ?? []
    }

    public func record(_ term: String) {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        recent.removeAll { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
        recent.insert(trimmed, at: 0)
        if recent.count > limit { recent = Array(recent.prefix(limit)) }
        UserDefaults.standard.set(recent, forKey: key)
    }

    public func clear() {
        recent = []
        UserDefaults.standard.removeObject(forKey: key)
    }
}
