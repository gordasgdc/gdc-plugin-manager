#if DEBUG
import AppKit

/// DEBUG: campanii + grafică generată local, pentru capturile de verificare (fără rețea, fără date de producție).
public enum PromoBannerFixtures {
    public static func campaign(_ mode: PromoBannerMode) -> PromoBannerCampaign {
        PromoBannerCampaign(id: "fixture-\(mode.rawValue)", name: "Crăciun 2026 (\(mode.rawValue))", mode: mode,
                            texts: ["ro": .init(top: "CRĂCIUN", main: "Pachete festive pentru coloriști — susține proiectul cu o donație"),
                                    "en": .init(top: "CHRISTMAS", main: "Festive packs for colorists — support the project with a donation"),
                                    "es": .init(top: "NAVIDAD", main: "Paquetes festivos para coloristas — apoya el proyecto con una donación")],
                            imagePath: mode == .text ? nil : "fixture.png")
    }

    /// Grafică la @2x pentru slotul dat; `dark` schimbă paleta; `withText` desenează text (doar „Doar imagine”).
    public static func image(slot: PromoBannerSpec.Slot, dark: Bool, withText: Bool) -> NSImage {
        let size = CGSize(width: slot.recommended.width * 2, height: slot.recommended.height * 2)
        let img = NSImage(size: size)
        img.lockFocus()
        let colors = dark ? [NSColor(srgbRed: 0.16, green: 0.10, blue: 0.05, alpha: 1), NSColor(srgbRed: 0.45, green: 0.27, blue: 0.10, alpha: 1)]
                          : [NSColor(srgbRed: 0.98, green: 0.92, blue: 0.83, alpha: 1), NSColor(srgbRed: 0.90, green: 0.73, blue: 0.50, alpha: 1)]
        NSGradient(colors: colors)?.draw(in: CGRect(origin: .zero, size: size), angle: 20)
        for k in 0..<Int(size.width / 220) {
            let r = CGFloat(40 + (k * 37) % 70)
            (dark ? NSColor.white.withAlphaComponent(0.10) : NSColor.white.withAlphaComponent(0.45)).setFill()
            NSBezierPath(ovalIn: CGRect(x: CGFloat(k) * 220 + 30, y: size.height * 0.5 - r + CGFloat((k * 53) % 90) - 45, width: r * 2, height: r * 2)).fill()
        }
        if withText {
            let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: size.height * 0.22, weight: .heavy),
                                                        .foregroundColor: dark ? NSColor(srgbRed: 0.95, green: 0.68, blue: 0.32, alpha: 1) : NSColor(srgbRed: 0.45, green: 0.25, blue: 0.05, alpha: 1)]
            let s = NSAttributedString(string: "CRĂCIUN · PACHETE FESTIVE", attributes: attrs)
            let b = s.size()
            s.draw(at: CGPoint(x: (size.width - b.width) / 2, y: (size.height - b.height) / 2))
        }
        img.unlockFocus()
        return img
    }

    public static func images(for mode: PromoBannerMode) -> PromoBannerImages {
        switch mode {
        case .text: return PromoBannerImages()
        case .imageText: return PromoBannerImages(light: image(slot: .split, dark: false, withText: false), dark: image(slot: .split, dark: true, withText: false))
        case .image: return PromoBannerImages(light: image(slot: .standard, dark: false, withText: true), dark: image(slot: .standard, dark: true, withText: true),
                                              wideLight: image(slot: .wide, dark: false, withText: true), wideDark: image(slot: .wide, dark: true, withText: true))
        }
    }
}
#endif
