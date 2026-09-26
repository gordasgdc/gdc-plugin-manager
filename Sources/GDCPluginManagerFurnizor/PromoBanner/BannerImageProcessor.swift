import AppKit
import ImageIO
import UniformTypeIdentifiers
import GDCPluginManagerCore

/// Validează și optimizează imaginile de banner (Faza 5): doar PNG/SVG, raport fix per slot,
/// minim dimensiunea recomandată @1x, maxim @2x (peste se micșorează), ≤ 400 KB după re-encodare.
/// SVG: respins dacă referă resurse externe sau conține script; apoi rasterizat local în PNG.
enum BannerImageProcessor {
    struct Output: Equatable {
        let url: URL
        let pixelSize: CGSize
        let bytes: Int
    }

    enum Failure: LocalizedError, Equatable {
        case unsupportedFormat
        case unreadable
        case unsafeSVG(String)
        case wrongAspect(expected: CGFloat, got: CGFloat)
        case tooSmall(minWidth: Int, got: Int)
        case tooLarge(bytes: Int)

        var errorDescription: String? {
            switch self {
            case .unsupportedFormat: return "Doar PNG sau SVG."
            case .unreadable: return "Fișierul nu poate fi citit ca imagine (sau SVG-ul nu poate fi randat pe acest macOS)."
            case .unsafeSVG(let why): return "SVG respins din motive de siguranță: \(why)."
            case .wrongAspect(let e, let g):
                return String(format: "Raport %.2f:1, dar slotul cere %.0f:1 (toleranță 2%%).", g, e)
            case .tooSmall(let m, let g): return "Prea mică: \(g) px lățime, minimum \(m) px."
            case .tooLarge(let b): return "După optimizare are \(b / 1000) KB — limita e \(PromoBannerSpec.maxBytes / 1000) KB. Simplifică grafica sau reduce culorile."
            }
        }
    }

    static func process(_ source: URL, slot: PromoBannerSpec.Slot) throws -> Output {
        let ext = source.pathExtension.lowercased()
        let image: CGImage
        switch ext {
        case "png":
            guard let src = CGImageSourceCreateWithURL(source as CFURL, nil),
                  let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else { throw Failure.unreadable }
            image = img
        case "svg":
            guard let data = try? Data(contentsOf: source), let text = String(data: data, encoding: .utf8) else { throw Failure.unreadable }
            try sanitizeSVG(text)
            image = try rasterizeSVG(data, size: CGSize(width: slot.recommended.width * 2, height: slot.recommended.height * 2))
        default:
            throw Failure.unsupportedFormat
        }

        let w = CGFloat(image.width), h = CGFloat(image.height)
        guard h > 0 else { throw Failure.unreadable }
        let ratio = w / h
        guard abs(ratio - slot.aspect) / slot.aspect <= PromoBannerSpec.aspectTolerance else {
            throw Failure.wrongAspect(expected: slot.aspect, got: ratio)
        }
        guard w >= slot.recommended.width else { throw Failure.tooSmall(minWidth: Int(slot.recommended.width), got: Int(w)) }

        // Peste @2x nu aduce nimic pe ecran, doar greutate: se micșorează exact la @2x.
        let maxSize = CGSize(width: slot.recommended.width * 2, height: slot.recommended.height * 2)
        let final = w > maxSize.width ? try resize(image, to: maxSize) : image

        if let out = try encode(final, slot: slot), out.bytes <= PromoBannerSpec.maxBytes { return out }
        // @2x prea greu (grafică fotografică/gradienți): se încearcă @1x, încă clar pe ecranele obișnuite.
        let oneX = CGSize(width: slot.recommended.width, height: slot.recommended.height)
        if CGFloat(final.width) > oneX.width, let out = try encode(try resize(final, to: oneX), slot: slot) {
            if out.bytes <= PromoBannerSpec.maxBytes { return out }
            try? FileManager.default.removeItem(at: out.url)
            throw Failure.tooLarge(bytes: out.bytes)
        }
        let bytes = (try encode(final, slot: slot))?.bytes ?? 0
        throw Failure.tooLarge(bytes: bytes)
    }

    /// PNG fără metadate; întoarce ieșirea chiar dacă depășește limita (apelantul decide).
    private static func encode(_ image: CGImage, slot: PromoBannerSpec.Slot) throws -> Output? {
        let out = FileManager.default.temporaryDirectory
            .appendingPathComponent("gdc-banner-\(slot.rawValue)-\(UUID().uuidString).png")
        guard let dest = CGImageDestinationCreateWithURL(out as CFURL, UTType.png.identifier as CFString, 1, nil) else { throw Failure.unreadable }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else { throw Failure.unreadable }
        let bytes = (try? FileManager.default.attributesOfItem(atPath: out.path)[.size] as? Int) ?? 0
        if bytes > PromoBannerSpec.maxBytes { defer { try? FileManager.default.removeItem(at: out) } ; return Output(url: out, pixelSize: CGSize(width: image.width, height: image.height), bytes: bytes) }
        return Output(url: out, pixelSize: CGSize(width: image.width, height: image.height), bytes: bytes)
    }

    /// Respinge orice poate încărca ceva din afara fișierului sau executa cod.
    static func sanitizeSVG(_ text: String) throws {
        let lower = text.lowercased()
        for (needle, why) in [("<script", "conține <script>"), ("<foreignobject", "conține <foreignObject>"),
                              ("<!entity", "declară entități XML"), ("<!doctype", "declară DOCTYPE"),
                              ("javascript:", "conține javascript:"), ("@import", "importă CSS extern")] where lower.contains(needle) {
            throw Failure.unsafeSVG(why)
        }
        // href/xlink:href: doar ancore interne (#id) sau imagini raster încorporate (data:image/…).
        let hrefs = try NSRegularExpression(pattern: #"(?:xlink:)?href\s*=\s*["']\s*([^"']*)"#, options: [.caseInsensitive])
        for m in hrefs.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            guard let r = Range(m.range(at: 1), in: text) else { continue }
            let v = text[r].lowercased()
            if !(v.hasPrefix("#") || v.hasPrefix("data:image/png") || v.hasPrefix("data:image/jpeg")) {
                throw Failure.unsafeSVG("referă o resursă externă")
            }
        }
        if lower.range(of: #"url\(\s*['"]?\s*(https?:|//|file:)"#, options: .regularExpression) != nil {
            throw Failure.unsafeSVG("referă o resursă externă în CSS")
        }
    }

    private static func rasterizeSVG(_ data: Data, size: CGSize) throws -> CGImage {
        guard let svg = NSImage(data: data) else { throw Failure.unreadable }
        guard let ctx = CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw Failure.unreadable }
        // Păstrează raportul SVG-ului (verificat apoi ca la PNG), centrat pe transparent.
        let s = svg.size
        guard s.width > 0, s.height > 0 else { throw Failure.unreadable }
        let scale = min(size.width / s.width, size.height / s.height)
        let target = CGSize(width: (s.width * scale).rounded(), height: (s.height * scale).rounded())
        let nsctx = NSGraphicsContext(cgContext: ctx, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = nsctx
        svg.draw(in: CGRect(origin: .zero, size: target))
        NSGraphicsContext.restoreGraphicsState()
        guard let full = ctx.makeImage(), let cropped = full.cropping(to: CGRect(x: 0, y: Int(size.height - target.height), width: Int(target.width), height: Int(target.height))) else {
            throw Failure.unreadable
        }
        return cropped
    }

    private static func resize(_ image: CGImage, to size: CGSize) throws -> CGImage {
        guard let ctx = CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw Failure.unreadable }
        ctx.interpolationQuality = .high
        ctx.draw(image, in: CGRect(origin: .zero, size: size))
        guard let out = ctx.makeImage() else { throw Failure.unreadable }
        return out
    }
}
