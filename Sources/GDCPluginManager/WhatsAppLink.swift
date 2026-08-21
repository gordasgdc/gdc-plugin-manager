import Foundation

/// Numarul de contact WhatsApp, nu ca literal simplu in sursa — repo-ul e
/// public pe GitHub, iar un numar de telefon scris direct ca text e usor de
/// gasit de crawlere automate care aduna numere pentru spam. Reconstruit la
/// rulare din bucati, ca sa nu apara ca sir contiguu "34643109970" in cod.
enum WhatsAppLink {
    private static let parts = ["34", "643", "109", "970"]

    private static var number: String { parts.joined() }

    static func url(text: String? = nil) -> URL {
        var comps = URLComponents(string: "https://wa.me/\(number)")!
        if let text {
            comps.queryItems = [URLQueryItem(name: "text", value: text)]
        }
        return comps.url!
    }
}
