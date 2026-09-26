import AppKit
import ImageIO
import UniformTypeIdentifiers
import GDCPluginManagerCore

/// Validează și optimizează imaginile de banner (Faza 5): PNG (transparență), JPEG (fotografii), SVG (rasterizat local); raport fix per slot,
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
        case contentMismatch(String)
        case unreadable
        case unsafeSVG(String)
        case wrongAspect(expected: CGFloat, got: CGFloat)
        case tooSmall(minWidth: Int, got: Int)
        case tooLarge(bytes: Int)

        var errorDescription: String? {
            switch self {
            case .unsupportedFormat: return "Doar PNG, JPEG sau SVG."
            case .contentMismatch(let why): return "Conținutul fișierului nu corespunde extensiei: \(why)."
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
        guard let data = try? Data(contentsOf: source) else { throw Failure.unreadable }
        let kind = try sniff(data, ext: ext)
        let image: CGImage
        switch kind {
        case .png, .jpeg:
            guard let src = CGImageSourceCreateWithData(data as CFData, nil),
                  let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else { throw Failure.unreadable }
            image = img
        case .svg:
            guard let text = String(data: data, encoding: .utf8) else { throw Failure.unreadable }
            try sanitizeSVG(text)
            image = try rasterizeSVG(data, size: CGSize(width: slot.recommended.width * 2, height: slot.recommended.height * 2))
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

        // Formatul livrat: PNG dacă imaginea chiar folosește transparența (sau e SVG/PNG ușor), altfel JPEG
        // pentru fotografii. Calitatea JPEG coboară în trepte doar până la 0.72 (fără degradare evidentă);
        // dacă tot nu încape, se încearcă @1x; peste atât fișierul e respins, nu stricat.
        let oneX = CGSize(width: slot.recommended.width, height: slot.recommended.height)
        var candidates: [CGImage] = [final]
        if CGFloat(final.width) > oneX.width { candidates.append(try resize(final, to: oneX)) }
        let keepPNG = kind == .svg || usesTransparency(final) || kind == .png
        var smallest = Int.max
        for img in candidates {
            if keepPNG, let out = try encode(img, as: .png, quality: nil) {
                if out.bytes <= PromoBannerSpec.maxBytes { return out }
                smallest = min(smallest, out.bytes)
                // PNG opac prea greu → JPEG e varianta corectă pentru o fotografie.
                if usesTransparency(img) { continue }
            }
            for q in [0.9, 0.84, 0.78, 0.72] {
                guard let out = try encode(img, as: .jpeg, quality: q) else { continue }
                if out.bytes <= PromoBannerSpec.maxBytes { return out }
                smallest = min(smallest, out.bytes)
            }
        }
        throw Failure.tooLarge(bytes: smallest == .max ? 0 : smallest)
    }

    enum Kind { case png, jpeg, svg }

    /// Tipul REAL, din primii octeți, și concordanța cu extensia.
    static func sniff(_ data: Data, ext: String) throws -> Kind {
        let b = [UInt8](data.prefix(16))
        let isPNG = b.starts(with: [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        let isJPEG = b.starts(with: [0xFF, 0xD8, 0xFF])
        let head = String(decoding: data.prefix(512), as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let isSVG = head.hasPrefix("<svg") || (head.hasPrefix("<?xml") && head.contains("<svg"))
        switch ext {
        case "png": guard isPNG else { throw Failure.contentMismatch(".png fără semnătură PNG") }; return .png
        case "jpg", "jpeg": guard isJPEG else { throw Failure.contentMismatch(".jpg fără semnătură JPEG") }; return .jpeg
        case "svg": guard isSVG else { throw Failure.contentMismatch(".svg care nu începe cu <svg>") }; return .svg
        default: throw Failure.unsupportedFormat
        }
    }

    /// Adevărat doar dacă există pixeli efectiv transparenți (nu doar un canal alfa declarat).
    static func usesTransparency(_ image: CGImage) -> Bool {
        switch image.alphaInfo {
        case .none, .noneSkipFirst, .noneSkipLast: return false
        default: break
        }
        let w = min(image.width, 256), h = max(1, min(image.height, 64))
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue), let data = ctx.data else { return true }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        let px = data.bindMemory(to: UInt8.self, capacity: w * h * 4)
        for i in stride(from: 3, to: w * h * 4, by: 4) where px[i] < 250 { return true }
        return false
    }

    /// Codare fără metadate (EXIF/GPS eliminate); întoarce ieșirea și peste limită — decide apelantul.
    private static func encode(_ image: CGImage, as type: UTType, quality: Double?) throws -> Output? {
        let ext = type == .png ? "png" : "jpg"
        let out = FileManager.default.temporaryDirectory.appendingPathComponent("gdc-banner-\(UUID().uuidString).\(ext)")
        guard let dest = CGImageDestinationCreateWithURL(out as CFURL, type.identifier as CFString, 1, nil) else { throw Failure.unreadable }
        var props: [CFString: Any] = [:]
        if let quality { props[kCGImageDestinationLossyCompressionQuality] = quality }
        CGImageDestinationAddImage(dest, image, props as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { throw Failure.unreadable }
        let bytes = (try? FileManager.default.attributesOfItem(atPath: out.path)[.size] as? Int) ?? 0
        if bytes > PromoBannerSpec.maxBytes { try? FileManager.default.removeItem(at: out) }
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
