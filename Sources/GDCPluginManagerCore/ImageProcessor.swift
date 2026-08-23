import Foundation
import ImageIO
import CoreGraphics
import UniformTypeIdentifiers

/// Redimensionarea + compresia automata a imaginilor de prezentare
/// (coperti de produs, evenimente, cursuri, magazine partenere).
///
/// ARCHITECTURE NOTE: foloseste EXCLUSIV ImageIO (framework nativ macOS,
/// deja linkat) — fara nicio dependinta externa in Package.swift. Perechea
/// lui pe Windows este `ImageProcessor.cs` din GDCPluginManagerWin, care
/// face acelasi lucru cu SixLabors.ImageSharp si TREBUIE sa produca
/// aceleasi dimensiuni/calitati (vezi `ImagePreset` de mai jos) — daca
/// schimbi un prag aici, schimba-l si acolo, altfel aceeasi imagine urcata
/// de pe Mac si de pe Windows ar ajunge in catalog cu greutati diferite.
///
/// De ce comprimam mereu, chiar daca fisierul sursa pare mic: o poza
/// exportata din Lightroom/telefon vine tipic cu 4-12 MB si cu metadate
/// EXIF (inclusiv GPS). Catalogul e public pe GitHub Pages, deci fiecare
/// MB neconvertit se plateste la fiecare deschidere a aplicatiei, iar
/// GPS-ul din EXIF ar fi o scurgere de date personale.
public enum ImageProcessor {

    /// Contextul in care va fi afisata imaginea — determina dimensiunea
    /// tinta si formatul de iesire.
    public enum Preset {
        /// Iconite de produs: OFX, PowerGrade, preseturi, LUT/DCTL.
        /// Patrat 512x512, decupat din centru — accentul e pe simbol, nu
        /// pe detaliu, iar formatul patrat garanteaza carduri aliniate in
        /// grila clientului indiferent ce a urcat furnizorul.
        case icon
        /// Materiale educationale, cursuri, magazine partenere, evenimente.
        /// Max 1600px pe latura lunga, proportii pastrate — destul cat sa
        /// se vada detaliile intr-un lightbox pe un ecran Retina, fara sa
        /// ajungem la fisiere de cativa MB.
        case cover

        /// Latura tinta, in pixeli.
        var targetSize: CGFloat {
            switch self {
            case .icon: return 512
            case .cover: return 1600
            }
        }

        /// Calitatea JPEG. 0.82 e pragul sub care artefactele devin
        /// vizibile pe gradiente line (exact ce are o coperta de LUT),
        /// asa ca nu cobori sub atat fara un test vizual.
        var jpegQuality: CGFloat { 0.82 }

        /// Sub cate octeti consideram ca sursa e "deja optimizata" si o
        /// pastram ca atare daca reprocesarea nu o face mai mica.
        /// Vezi `keepOriginalIfSmaller` mai jos pentru motiv.
        var alreadyOptimizedCeiling: Int {
            switch self {
            case .icon: return 300 * 1024      // 300 KB
            case .cover: return 1_200 * 1024   // 1,2 MB
            }
        }
    }

    public enum ProcessingError: LocalizedError {
        case cannotReadImage(URL)
        case cannotDecodeImage(URL)
        case cannotWriteImage(URL)

        public var errorDescription: String? {
            switch self {
            case .cannotReadImage(let url):
                return "Nu pot citi imaginea: \(url.lastPathComponent)"
            case .cannotDecodeImage(let url):
                return "Fisierul nu este o imagine valida: \(url.lastPathComponent)"
            case .cannotWriteImage(let url):
                return "Nu pot scrie imaginea procesata: \(url.lastPathComponent)"
            }
        }
    }

    /// Ce a rezultat din procesare — folosit ca sa putem arata furnizorului
    /// in UI cat a castigat ("4.2 MB -> 180 KB"), nu doar un checkmark mut.
    public struct Result {
        public let outputURL: URL
        public let originalBytes: Int
        public let finalBytes: Int
        public let pixelWidth: Int
        public let pixelHeight: Int

        /// Ex. "4,2 MB -> 180 KB (96% mai mic)".
        public var savingsDescription: String {
            let f = ByteCountFormatter()
            f.countStyle = .file
            let before = f.string(fromByteCount: Int64(originalBytes))
            let after = f.string(fromByteCount: Int64(finalBytes))
            guard originalBytes > 0 else { return "\(before) -> \(after)" }
            let percent = Int((1.0 - Double(finalBytes) / Double(originalBytes)) * 100)
            return "\(before) -> \(after) (\(percent)% mai mic)"
        }
    }

    /// Comprima si redimensioneaza `source`, scriind rezultatul la
    /// `destination`.
    ///
    /// Extensia lui `destination` este IGNORATA si inlocuita cu cea reala
    /// (.jpg sau .png, vezi mai jos) — apelantul trebuie sa foloseasca
    /// `Result.outputURL`, nu URL-ul pe care l-a dat, cand scrie calea in
    /// catalog.
    @discardableResult
    public static func process(source: URL, preset: Preset, destination: URL) throws -> Result {
        let originalBytes = (try? FileManager.default.attributesOfItem(atPath: source.path)[.size] as? Int) ?? 0

        guard let imageSource = CGImageSourceCreateWithURL(source as CFURL, nil) else {
            throw ProcessingError.cannotReadImage(source)
        }

        // Sursa poate avea alpha (un logo PNG pe fundal transparent). O
        // convertire oarba la JPEG ar innegri fundalul, deci decidem
        // formatul de iesire dupa continut, nu dupa extensia sursei.
        let hasAlpha = sourceHasAlpha(imageSource)

        let scaled = try scaledImage(from: imageSource, preset: preset, source: source)

        // Iconitele cu transparenta raman PNG (un logo plat comprima foarte
        // bine in PNG si isi pastreaza fundalul transparent peste orice tema
        // a clientului). Orice altceva devine JPEG — o fotografie in PNG ar
        // fi de 5-10x mai mare degeaba.
        let useePNG = hasAlpha && preset == .icon
        let outputType: UTType = useePNG ? .png : .jpeg
        let outputURL = destination.deletingPathExtension()
            .appendingPathExtension(useePNG ? "png" : "jpg")

        let finalImage: CGImage
        if useePNG {
            finalImage = scaled
        } else {
            // Aplatizam alpha peste alb inainte de JPEG; fara asta zonele
            // transparente ies negre in loc de albe.
            finalImage = hasAlpha ? flattenOntoWhite(scaled) : scaled
        }

        guard let dest = CGImageDestinationCreateWithURL(
            outputURL as CFURL, outputType.identifier as CFString, 1, nil
        ) else {
            throw ProcessingError.cannotWriteImage(outputURL)
        }

        // Nu copiem metadatele sursei: scapam si de greutate, si de
        // coordonatele GPS pe care telefoanele le pun in EXIF.
        let properties: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: preset.jpegQuality
        ]
        CGImageDestinationAddImage(dest, finalImage, properties as CFDictionary)

        guard CGImageDestinationFinalize(dest) else {
            throw ProcessingError.cannotWriteImage(outputURL)
        }

        let finalBytes = (try? FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] as? Int) ?? 0

        // WARNING: recomprimarea NU e garantat un castig. Un logo PNG plat,
        // deja optimizat cu un encoder mai bun decat ImageIO, poate iesi de
        // 2-3x mai MARE dupa reprocesare (masurat: 11 KB -> 32 KB). La fel,
        // o poza deja mica sub prag nu are ce sa castige. In cazurile astea
        // pastram originalul — altfel "optimizarea" ar ingrasa catalogul.
        if let kept = try keepOriginalIfSmaller(
            source: source, processedURL: outputURL,
            originalBytes: originalBytes, finalBytes: finalBytes, preset: preset
        ) {
            return kept
        }

        return Result(
            outputURL: outputURL,
            originalBytes: originalBytes,
            finalBytes: finalBytes,
            pixelWidth: finalImage.width,
            pixelHeight: finalImage.height
        )
    }

    /// Daca reprocesarea nu a facut fisierul mai mic si sursa e oricum un
    /// format web sub pragul de greutate, copiaza sursa peste rezultat si
    /// intoarce un `Result` care descrie originalul pastrat. nil = pastram
    /// varianta procesata (cazul normal).
    private static func keepOriginalIfSmaller(
        source: URL, processedURL: URL,
        originalBytes: Int, finalBytes: Int, preset: Preset
    ) throws -> Result? {
        guard finalBytes >= originalBytes, originalBytes > 0 else { return nil }
        guard originalBytes <= preset.alreadyOptimizedCeiling else { return nil }

        // Doar formate pe care le poate afisa direct orice client/browser.
        // Un TIFF/HEIC "mai mic" tot ar trebui convertit.
        let ext = source.pathExtension.lowercased()
        guard ["jpg", "jpeg", "png"].contains(ext) else { return nil }

        let keptURL = processedURL.deletingPathExtension()
            .appendingPathExtension(ext == "jpeg" ? "jpg" : ext)

        // Rezultatul procesat devine inutil — il stergem ca sa nu ramana un
        // .jpg orfan langa .png-ul pastrat (sau invers).
        if keptURL != processedURL {
            try? FileManager.default.removeItem(at: processedURL)
        }
        if FileManager.default.fileExists(atPath: keptURL.path) {
            try FileManager.default.removeItem(at: keptURL)
        }
        try FileManager.default.copyItem(at: source, to: keptURL)

        let dims = pixelDimensions(of: keptURL)
        return Result(
            outputURL: keptURL,
            originalBytes: originalBytes,
            finalBytes: originalBytes,
            pixelWidth: dims.width,
            pixelHeight: dims.height
        )
    }

    /// Dimensiunile in pixeli ale unei imagini de pe disc, fara sa o decodam
    /// complet (citeste doar headerul).
    private static func pixelDimensions(of url: URL) -> (width: Int, height: Int) {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any],
              let w = props[kCGImagePropertyPixelWidth] as? Int,
              let h = props[kCGImagePropertyPixelHeight] as? Int else {
            return (0, 0)
        }
        return (w, h)
    }

    // MARK: - Interne

    /// Scaleaza (niciodata in sus) si, pentru `.icon`, decupeaza patrat
    /// din centru.
    private static func scaledImage(from imageSource: CGImageSource, preset: Preset, source: URL) throws -> CGImage {
        guard let props = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any],
              let originalWidth = props[kCGImagePropertyPixelWidth] as? CGFloat,
              let originalHeight = props[kCGImagePropertyPixelHeight] as? CGFloat,
              originalWidth > 0, originalHeight > 0 else {
            throw ProcessingError.cannotDecodeImage(source)
        }

        // `kCGImageSourceThumbnailMaxPixelSize` limiteaza LATURA LUNGA.
        // Pentru `.cover` asta e exact ce vrem. Pentru `.icon` vrem insa ca
        // latura SCURTA sa ajunga la 512 (ca sa avem din ce decupa patratul),
        // deci cerem o latura lunga proportional mai mare.
        let maxPixelSize: CGFloat
        switch preset {
        case .cover:
            maxPixelSize = preset.targetSize
        case .icon:
            let shortEdge = min(originalWidth, originalHeight)
            let longEdge = max(originalWidth, originalHeight)
            // `.rounded(.up)`: fara el, raportul fractionar face ca latura
            // scurta sa iasa 511 in loc de 512, si decupajul patrat ar da
            // 511x511 — destul cat sa strice alinierea grilei de carduri.
            maxPixelSize = ((longEdge / shortEdge) * preset.targetSize).rounded(.up)
        }

        // Fara upscaling: o imagine deja mai mica decat tinta ramane la
        // dimensiunea ei (marind-o am adauga octeti fara sa adaugam detaliu).
        let effectiveMax = min(maxPixelSize, max(originalWidth, originalHeight))

        let thumbOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: effectiveMax,
            // Aplica rotatia din EXIF, altfel pozele facute cu telefonul in
            // portret ies culcate.
            kCGImageSourceCreateThumbnailWithTransform: true
        ]

        guard let thumb = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, thumbOptions as CFDictionary) else {
            throw ProcessingError.cannotDecodeImage(source)
        }

        guard preset == .icon else { return thumb }
        return centerCropSquare(thumb)
    }

    /// Decupeaza cel mai mare patrat posibil din centrul imaginii.
    private static func centerCropSquare(_ image: CGImage) -> CGImage {
        let side = min(image.width, image.height)
        let x = (image.width - side) / 2
        let y = (image.height - side) / 2
        let rect = CGRect(x: x, y: y, width: side, height: side)
        return image.cropping(to: rect) ?? image
    }

    /// True daca formatul sursei poate purta transparenta si chiar o are.
    private static func sourceHasAlpha(_ imageSource: CGImageSource) -> Bool {
        guard let props = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any] else {
            return false
        }
        return (props[kCGImagePropertyHasAlpha] as? Bool) ?? false
    }

    /// Deseneaza imaginea peste un fundal alb opac, ca alpha sa nu devina
    /// negru la scrierea in JPEG.
    private static func flattenOntoWhite(_ image: CGImage) -> CGImage {
        let width = image.width
        let height = image.height
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else {
            return image
        }
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage() ?? image
    }
}
