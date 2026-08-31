import Foundation

/// Banner de lansare publică (2026-08-31), controlabil de Cristi din
/// Furnizor FĂRĂ recompilare — port 1:1 al arhitecturii `PricingCatalog`/
/// `docs/pricing.json` (Regula 27, CLAUDE.md): un fișier mic, servit static
/// la `https://gordas.dev/launch-banner.json`, citit de Client la lansare.
///
/// De ce nu bundle-uit direct în app (cum era prima variantă azi): Cristi
/// a cerut explicit să poată schimba imaginea/textul singur, oricând, fără
/// să mă aștepte pe mine pentru un rebuild+republish pe ambele platforme.
public struct LaunchBannerConfig: Codable, Equatable {
    public var enabled: Bool
    /// Cale relativă (`covers/launch-banner.jpg?v=...`) sau URL extern —
    /// aceeași convenție ca `coverImage` din catalog, rezolvată prin
    /// `CatalogAssets.imageURL(for:)`.
    public var imagePath: String
    public var topText: String
    public var mainText: String
    public var updatedAt: String

    public init(enabled: Bool = false, imagePath: String = "", topText: String = "",
                mainText: String = "", updatedAt: String = "") {
        self.enabled = enabled
        self.imagePath = imagePath
        self.topText = topText
        self.mainText = mainText
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey { case enabled, imagePath, topText, mainText, updatedAt }

    /// Decodare tolerantă — un `launch-banner.json` viitor cu un câmp în
    /// plus, sau un client vechi care citește un JSON mai nou, nu trebuie
    /// să crape niciodată (fail-open, ca `RevocationCheck`/`PricingChecker`).
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? false
        imagePath = try c.decodeIfPresent(String.self, forKey: .imagePath) ?? ""
        topText = try c.decodeIfPresent(String.self, forKey: .topText) ?? ""
        mainText = try c.decodeIfPresent(String.self, forKey: .mainText) ?? ""
        updatedAt = try c.decodeIfPresent(String.self, forKey: .updatedAt) ?? ""
    }

    public var imageURL: URL? { CatalogAssets.imageURL(for: imagePath) }

    /// True doar dacă totul e configurat corect — un `enabled: true` cu
    /// imagine sau text lipsă nu ar arăta un banner util.
    public var isDisplayable: Bool {
        enabled && imageURL != nil && !topText.isEmpty && !mainText.isEmpty
    }
}
