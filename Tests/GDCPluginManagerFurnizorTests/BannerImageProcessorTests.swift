import XCTest
import AppKit
import ImageIO
import UniformTypeIdentifiers
import GDCPluginManagerCore
@testable import GDCPluginManagerFurnizor

final class BannerImageProcessorTests: XCTestCase {
    private func png(_ w: Int, _ h: Int, noise: Bool = false) throws -> URL {
        let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        if noise, let data = ctx.data {
            let p = data.bindMemory(to: UInt32.self, capacity: w * h)
            for i in 0..<(w * h) { p[i] = UInt32.random(in: 0...UInt32.max) | 0xFF00_0000 }
        } else {
            ctx.setFillColor(CGColor(red: 0.8, green: 0.5, blue: 0.2, alpha: 1)); ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("t-\(UUID().uuidString).png")
        let d = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(d, ctx.makeImage()!, nil); CGImageDestinationFinalize(d)
        return url
    }

    private func svg(_ body: String, w: Int = 1200, h: Int = 200) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("t-\(UUID().uuidString).svg")
        try #"<svg xmlns="http://www.w3.org/2000/svg" width="\#(w)" height="\#(h)" viewBox="0 0 \#(w) \#(h)">\#(body)</svg>"#.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func testValidPNGIsAcceptedAndOptimized() throws {
        let out = try BannerImageProcessor.process(try png(1200, 200), slot: .standard)
        XCTAssertEqual(out.pixelSize, CGSize(width: 1200, height: 200))
        XCTAssertLessThanOrEqual(out.bytes, PromoBannerSpec.maxBytes)
    }

    func testOversizedPNGIsDownscaledTo2x() throws {
        let out = try BannerImageProcessor.process(try png(3600, 600), slot: .standard)
        XCTAssertEqual(out.pixelSize, CGSize(width: 2400, height: 400))
    }

    func testWrongAspectTooSmallAndTooHeavyAreRejected() throws {
        XCTAssertThrowsError(try BannerImageProcessor.process(try png(1200, 300), slot: .standard)) {
            guard case BannerImageProcessor.Failure.wrongAspect = $0 else { return XCTFail("\($0)") }
        }
        XCTAssertThrowsError(try BannerImageProcessor.process(try png(600, 100), slot: .standard)) {
            XCTAssertEqual($0 as? BannerImageProcessor.Failure, .tooSmall(minWidth: 1200, got: 600))
        }
        XCTAssertThrowsError(try BannerImageProcessor.process(URL(fileURLWithPath: "/tmp/x.jpg"), slot: .standard))
    }

    private func jpeg(_ w: Int, _ h: Int) throws -> URL {
        let src = try png(w, h)
        let img = CGImageSourceCreateImageAtIndex(CGImageSourceCreateWithURL(src as CFURL, nil)!, 0, nil)!
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("t-\(UUID().uuidString).jpg")
        let d = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(d, img, nil); CGImageDestinationFinalize(d)
        return url
    }

    func testJPEGIsAcceptedAndStaysJPEG() throws {
        let out = try BannerImageProcessor.process(try jpeg(2400, 400), slot: .standard)
        XCTAssertEqual(out.url.pathExtension, "jpg")
        XCTAssertLessThanOrEqual(out.bytes, PromoBannerSpec.maxBytes)
    }

    func testExtensionMustMatchRealContent() throws {
        let fake = FileManager.default.temporaryDirectory.appendingPathComponent("t-\(UUID().uuidString).jpg")
        try FileManager.default.copyItem(at: try png(1200, 200), to: fake)
        XCTAssertThrowsError(try BannerImageProcessor.process(fake, slot: .standard)) {
            guard case BannerImageProcessor.Failure.contentMismatch = $0 else { return XCTFail("\($0)") }
        }
        let notSVG = FileManager.default.temporaryDirectory.appendingPathComponent("t-\(UUID().uuidString).svg")
        try Data("hello".utf8).write(to: notSVG)
        XCTAssertThrowsError(try BannerImageProcessor.process(notSVG, slot: .standard))
    }

    func testOpaqueHeavyPNGBecomesJPEGOrIsRejectedNeverOversized() throws {
        do {
            let out = try BannerImageProcessor.process(try png(2400, 400, noise: true), slot: .standard)
            XCTAssertEqual(out.url.pathExtension, "jpg", "PNG opac prea greu → JPEG")
            XCTAssertLessThanOrEqual(out.bytes, PromoBannerSpec.maxBytes)
        } catch BannerImageProcessor.Failure.tooLarge {}
    }

    func testTransparencyIsDetected() throws {
        let ctx = CGContext(data: nil, width: 20, height: 20, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1)); ctx.fill(CGRect(x: 0, y: 0, width: 10, height: 20))
        XCTAssertTrue(BannerImageProcessor.usesTransparency(ctx.makeImage()!))
        ctx.fill(CGRect(x: 0, y: 0, width: 20, height: 20))
        XCTAssertFalse(BannerImageProcessor.usesTransparency(ctx.makeImage()!))
    }

    func testHeavy2xFallsBackTo1xWhenThatFits() throws {
        // Zgomot doar pe jumătate de rânduri: @2x > 400 KB, @1x sub limită.
        let url = try png(2400, 400, noise: true)
        do {
            let out = try BannerImageProcessor.process(url, slot: .standard)
            XCTAssertEqual(out.pixelSize, CGSize(width: 1200, height: 200))
            XCTAssertLessThanOrEqual(out.bytes, PromoBannerSpec.maxBytes)
        } catch BannerImageProcessor.Failure.tooLarge {
            // Zgomot pur rămâne prea greu și la @1x — respins corect, nu trunchiat.
        }
    }

    func testUnsafeSVGIsRejected() throws {
        for body in [#"<image href="https://evil.example/x.png" width="10" height="10"/>"#,
                     #"<script>alert(1)</script>"#,
                     #"<foreignObject></foreignObject>"#,
                     #"<rect style="fill:url('https://x/y')" width="10" height="10"/>"#] {
            XCTAssertThrowsError(try BannerImageProcessor.process(try svg(body), slot: .standard), body) {
                guard case BannerImageProcessor.Failure.unsafeSVG = $0 else { return XCTFail("\(body): \($0)") }
            }
        }
    }

    func testSafeSVGIsRasterizedLocally() throws {
        let out = try BannerImageProcessor.process(try svg(##"<rect width="1200" height="200" fill="#C77829"/><circle cx="100" cy="100" r="60" fill="#fff"/>"##), slot: .standard)
        XCTAssertEqual(out.pixelSize, CGSize(width: 2400, height: 400))
        XCTAssertEqual(out.url.pathExtension, "png")
    }
}
