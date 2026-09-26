import SwiftUI
import AppKit

// MARK: - Modelul campaniilor (Faza 5, bannere promoționale)
//
// Compatibilitate: `launch-banner.json` păstrează TOATE câmpurile vechi. `campaigns` e opțional;
// clienții ≤ 1.40 îl ignoră și afișează câmpurile vechi, pe care Furnizorul le scrie ca rezervă
// (`withLegacyFallback`). Fără `campaigns`, clientul nou afișează bannerul clasic, neschimbat.

public enum PromoBannerMode: String, Codable, CaseIterable, Sendable {
    case text, imageText, image
}

public struct PromoBannerText: Codable, Equatable, Sendable {
    public var top: String
    public var main: String
    public init(top: String = "", main: String = "") { self.top = top; self.main = main }
    public var isEmpty: Bool {
        top.trimmingCharacters(in: .whitespaces).isEmpty && main.trimmingCharacters(in: .whitespaces).isEmpty
    }
}

public struct PromoBannerCampaign: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var mode: PromoBannerMode
    /// Chei: "ro" (obligatoriu la modurile cu text), "en", "es". În modul „Doar imagine”
    /// textul e opțional și servește ca descriere accesibilă (VoiceOver).
    public var texts: [String: PromoBannerText]
    /// Imagini (căi din catalog, ca `coverImage`). Standard = 6:1; lată = 12:1 (opțională, doar „Doar imagine”);
    /// la „Imagine + text” se folosește `imagePath` cu raportul 3:1.
    public var imagePath: String?
    public var imagePathDark: String?
    public var imagePathWide: String?
    public var imagePathWideDark: String?
    public var linkURL: String?
    public var scheduling: Scheduling?

    public init(id: String, name: String, mode: PromoBannerMode = .text, texts: [String: PromoBannerText] = [:],
                imagePath: String? = nil, imagePathDark: String? = nil, imagePathWide: String? = nil,
                imagePathWideDark: String? = nil, linkURL: String? = nil, scheduling: Scheduling? = nil) {
        self.id = id; self.name = name; self.mode = mode; self.texts = texts
        self.imagePath = imagePath; self.imagePathDark = imagePathDark
        self.imagePathWide = imagePathWide; self.imagePathWideDark = imagePathWideDark
        self.linkURL = linkURL; self.scheduling = scheduling
    }

    enum CodingKeys: String, CodingKey {
        case id, name, mode, texts, imagePath, imagePathDark, imagePathWide, imagePathWideDark, linkURL, scheduling
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        // Un mod necunoscut (versiune viitoare) cade pe text, nu strică decodarea.
        mode = (try? c.decodeIfPresent(PromoBannerMode.self, forKey: .mode)) ?? .text
        texts = (try? c.decodeIfPresent([String: PromoBannerText].self, forKey: .texts)) ?? [:]
        imagePath = try c.decodeIfPresent(String.self, forKey: .imagePath)
        imagePathDark = try c.decodeIfPresent(String.self, forKey: .imagePathDark)
        imagePathWide = try c.decodeIfPresent(String.self, forKey: .imagePathWide)
        imagePathWideDark = try c.decodeIfPresent(String.self, forKey: .imagePathWideDark)
        linkURL = try c.decodeIfPresent(String.self, forKey: .linkURL)
        scheduling = try? c.decodeIfPresent(Scheduling.self, forKey: .scheduling)
    }

    /// Textul pentru limba cerută, altfel RO; `nil` dacă nu există niciunul.
    public func text(for language: String) -> PromoBannerText? {
        if let t = texts[language], !t.isEmpty { return t }
        if let t = texts["ro"], !t.isEmpty { return t }
        return nil
    }

    public func isActive(at date: Date) -> Bool {
        if let start = scheduling?.startDate, date < start { return false }
        if let end = scheduling?.endDate, date > end { return false }
        return true
    }

    /// Conținutul minim ca bannerul să poată fi afișat în modul ales.
    public var hasRequiredContent: Bool {
        let hasImage = !(imagePath ?? "").isEmpty
        let hasText = !(texts["ro"]?.main ?? "").trimmingCharacters(in: .whitespaces).isEmpty
        switch mode {
        case .text: return hasText
        case .imageText: return hasText && hasImage
        case .image: return hasImage
        }
    }

    var interval: (start: Date, end: Date) {
        (scheduling?.startDate ?? .distantPast, scheduling?.endDate ?? .distantFuture)
    }
}

/// Specificația imaginilor (validată în Furnizor, folosită la randare în client).
public enum PromoBannerSpec {
    public enum Slot: String, CaseIterable, Sendable {
        case standard, wide, split
        /// Raportul lățime/înălțime.
        public var aspect: CGFloat { switch self { case .standard: 6; case .wide: 12; case .split: 3 } }
        /// Dimensiunea recomandată (@1x) în pixeli; se acceptă și @2x.
        public var recommended: CGSize {
            switch self {
            case .standard: CGSize(width: 1200, height: 200)
            case .wide: CGSize(width: 2400, height: 200)
            case .split: CGSize(width: 600, height: 200)
            }
        }
    }
    public static let maxBytes = 400_000
    public static let aspectTolerance: CGFloat = 0.02
    /// De la această lățime (puncte) „Doar imagine” folosește varianta lată, dacă există.
    public static let wideMinWidth: CGFloat = 900
    public static let textBandHeight: CGFloat = 56
    public static let splitHeight: CGFloat = 72
    /// Plafon pentru „Doar imagine” — peste el imaginea rămâne întreagă (fit), pe fundalul benzii.
    public static let maxImageHeight: CGFloat = 160

    /// „Doar imagine”: ce variantă și ce înălțime, ca grafica să fie integral vizibilă.
    public static func imageOnlyLayout(width: CGFloat, hasWide: Bool) -> (useWide: Bool, height: CGFloat) {
        let useWide = hasWide && width >= wideMinWidth
        let aspect = useWide ? Slot.wide.aspect : Slot.standard.aspect
        return (useWide, min(max(width / aspect, 40), maxImageHeight))
    }

    public static func height(for mode: PromoBannerMode, width: CGFloat, hasWide: Bool) -> CGFloat {
        switch mode {
        case .text: return textBandHeight
        case .imageText: return splitHeight
        case .image: return imageOnlyLayout(width: width, hasWide: hasWide).height
        }
    }
}

public extension LaunchBannerConfig {
    /// Campania afișată acum: activă în interval, cu conținut complet; la suprapunere (ce n-ar trebui
    /// să treacă de validarea din Furnizor) câștigă, determinist, cea cu începutul cel mai recent.
    func activeCampaign(at date: Date = Date()) -> PromoBannerCampaign? {
        guard enabled, let campaigns else { return nil }
        return campaigns
            .filter { $0.isActive(at: date) && $0.hasRequiredContent }
            .max { ($0.interval.start, $0.id) < ($1.interval.start, $1.id) }
    }

    /// Perechile de campanii care se suprapun în timp (Furnizorul blochează publicarea).
    static func overlappingCampaigns(_ campaigns: [PromoBannerCampaign]) -> [(PromoBannerCampaign, PromoBannerCampaign)] {
        var result: [(PromoBannerCampaign, PromoBannerCampaign)] = []
        for i in campaigns.indices {
            for j in campaigns.indices where j > i {
                let a = campaigns[i].interval, b = campaigns[j].interval
                if a.start <= b.end && b.start <= a.end { result.append((campaigns[i], campaigns[j])) }
            }
        }
        return result
    }

    /// Câmpurile vechi, pentru clienții ≤ 1.40: textul RO al campaniei curente (sau al următoarei),
    /// fără imagine (raportul nou nu se potrivește cu decuparea veche). „Doar imagine” → ascuns la ei.
    func withLegacyFallback(at date: Date = Date()) -> LaunchBannerConfig {
        guard let campaigns, !campaigns.isEmpty else { return self }
        var copy = self
        let current = activeCampaign(at: date)
            ?? campaigns.filter { $0.interval.start > date && $0.hasRequiredContent }.min { $0.interval.start < $1.interval.start }
        let text = current.flatMap { $0.mode == .image ? nil : $0.texts["ro"] }
        copy.topText = text?.top ?? ""
        copy.mainText = text?.main ?? ""
        copy.imagePath = ""
        copy.textOnTop = true
        copy.scheduling = current?.scheduling
        return copy
    }
}

// MARK: - Randarea (aceeași în client și în previzualizarea din Furnizor)

public struct PromoBannerImages: Equatable {
    public var light: NSImage?
    public var dark: NSImage?
    public var wideLight: NSImage?
    public var wideDark: NSImage?
    public init(light: NSImage? = nil, dark: NSImage? = nil, wideLight: NSImage? = nil, wideDark: NSImage? = nil) {
        self.light = light; self.dark = dark; self.wideLight = wideLight; self.wideDark = wideDark
    }
}

public struct PromoBannerView: View {
    let campaign: PromoBannerCampaign
    let language: String
    let images: PromoBannerImages
    let onTap: (() -> Void)?

    @Environment(\.colorScheme) private var scheme
    @State private var width: CGFloat = 0

    public init(campaign: PromoBannerCampaign, language: String, images: PromoBannerImages, onTap: (() -> Void)? = nil) {
        self.campaign = campaign; self.language = language; self.images = images; self.onTap = onTap
    }

    private var isDark: Bool { scheme == .dark }
    private var hasWide: Bool { (isDark ? images.wideDark ?? images.wideLight : images.wideLight) != nil }
    private var height: CGFloat { PromoBannerSpec.height(for: campaign.mode, width: width, hasWide: hasWide) }
    private var bandColor: Color { isDark ? Color(white: 0.08) : Color(white: 0.99) }
    private var text: PromoBannerText? { campaign.text(for: language) }

    public var body: some View {
        content
            .frame(maxWidth: .infinity)
            .frame(height: width == 0 ? PromoBannerSpec.textBandHeight : height)
            .background(bandColor)
            .overlay(alignment: .top) { GDCTokens.Palette.separator.frame(height: GDCTokens.Border.hairline) }
            .background(GeometryReader { g in
                Color.clear
                    .onAppear { width = g.size.width }
                    .onChange(of: g.size.width) { _, w in width = w }
            })
            .contentShape(Rectangle())
            .onTapGesture { onTap?() }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel([text?.top, text?.main].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ". "))
            .accessibilityAddTraits(onTap == nil ? [] : .isLink)
    }

    @ViewBuilder private var content: some View {
        switch campaign.mode {
        case .text:
            textBlock
        case .imageText:
            HStack(spacing: 0) {
                if let img = isDark ? images.dark ?? images.light : images.light {
                    // 3:1, umple panoul cu decupare centrală (textul e separat, nu în imagine).
                    Image(nsImage: img).resizable().interpolation(.high).aspectRatio(contentMode: .fill)
                        .frame(width: PromoBannerSpec.splitHeight * PromoBannerSpec.Slot.split.aspect, height: PromoBannerSpec.splitHeight)
                        .clipped()
                        .accessibilityHidden(true)
                }
                textBlock
            }
        case .image:
            let layout = PromoBannerSpec.imageOnlyLayout(width: width, hasWide: hasWide)
            let img = layout.useWide
                ? (isDark ? images.wideDark ?? images.wideLight : images.wideLight)
                : (isDark ? images.dark ?? images.light : images.light)
            if let img {
                // Fit: grafica rămâne integral vizibilă; surplusul e fundalul benzii.
                Image(nsImage: img).resizable().interpolation(.high).aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var textBlock: some View {
        VStack(spacing: GDCTokens.Space.xxs) {
            if let top = text?.top, !top.isEmpty {
                Text(top).font(.caption.weight(.bold)).tracking(2)
                    .foregroundStyle(GDCTokens.Palette.accent)
            }
            if let main = text?.main, !main.isEmpty {
                Text(main).font(.headline).foregroundStyle(GDCTokens.Palette.textPrimary)
                    .lineLimit(2).minimumScaleFactor(0.75)
            }
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, GDCTokens.Space.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
