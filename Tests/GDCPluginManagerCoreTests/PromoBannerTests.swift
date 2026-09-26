import XCTest
@testable import GDCPluginManagerCore

final class PromoBannerTests: XCTestCase {
    private let legacyJSON = #"{"enabled":true,"imagePath":"","mainText":"TEXT","textOnTop":true,"topText":"SUS","updatedAt":"2026-09-05"}"#

    private func campaign(_ id: String, _ mode: PromoBannerMode = .text, start: Double? = nil, end: Double? = nil, image: String? = nil) -> PromoBannerCampaign {
        PromoBannerCampaign(id: id, name: id, mode: mode, texts: ["ro": .init(top: "T\(id)", main: "M\(id)")], imagePath: image,
                            scheduling: (start == nil && end == nil) ? nil : Scheduling(startDate: start.map { Date(timeIntervalSince1970: $0) },
                                                                                        endDate: end.map { Date(timeIntervalSince1970: $0) }))
    }

    func testLegacyJSONDecodesUnchanged() throws {
        let c = try JSONDecoder().decode(LaunchBannerConfig.self, from: Data(legacyJSON.utf8))
        XCTAssertNil(c.campaigns)
        XCTAssertNil(c.activeCampaign())
        XCTAssertTrue(c.isDisplayable)
        XCTAssertEqual(c.withLegacyFallback(), c, "fără campanii, câmpurile vechi rămân neatinse")
    }

    func testEncodeKeepsLegacyKeysAndOldDecoderStillReadsIt() throws {
        var c = try JSONDecoder().decode(LaunchBannerConfig.self, from: Data(legacyJSON.utf8))
        c.campaigns = [campaign("a")]
        let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(c)) as! [String: Any]
        for key in ["enabled", "imagePath", "topText", "mainText", "textOnTop", "campaigns"] { XCTAssertNotNil(json[key], key) }
    }

    func testBrokenCampaignsDoNotHideClassicBanner() throws {
        let broken = legacyJSON.dropLast() + #","campaigns":"nu-e-listă"}"#
        let c = try JSONDecoder().decode(LaunchBannerConfig.self, from: Data(broken.utf8))
        XCTAssertNil(c.campaigns)
        XCTAssertTrue(c.isDisplayable)
    }

    func testActiveCampaignRespectsScheduleContentAndEnabled() {
        var c = LaunchBannerConfig(enabled: true, campaigns: [campaign("old", start: 0, end: 100), campaign("now", start: 150, end: 300),
                                                             campaign("img", .image, start: 150, end: 300)])
        XCTAssertEqual(c.activeCampaign(at: Date(timeIntervalSince1970: 200))?.id, "now", "„img” n-are imagine → incomplet, ignorat")
        XCTAssertNil(c.activeCampaign(at: Date(timeIntervalSince1970: 120)))
        c.enabled = false
        XCTAssertNil(c.activeCampaign(at: Date(timeIntervalSince1970: 200)))
    }

    func testOverlapDetection() {
        let a = campaign("a", start: 0, end: 100), b = campaign("b", start: 100, end: 200), d = campaign("d", start: 201, end: 300)
        XCTAssertEqual(LaunchBannerConfig.overlappingCampaigns([a, b, d]).map { "\($0.0.id)-\($0.1.id)" }, ["a-b"])
        XCTAssertEqual(LaunchBannerConfig.overlappingCampaigns([a, campaign("forever")]).count, 1, "fără interval = mereu, se suprapune")
    }

    func testLegacyFallbackForOldClients() {
        let c = LaunchBannerConfig(enabled: true, imagePath: "covers/x.png", topText: "VECHI", mainText: "VECHI",
                                   campaigns: [campaign("now", .imageText, start: 0, end: 1e12, image: "covers/b.png")])
        let f = c.withLegacyFallback(at: Date(timeIntervalSince1970: 10))
        XCTAssertEqual(f.topText, "Tnow"); XCTAssertEqual(f.mainText, "Mnow")
        XCTAssertEqual(f.imagePath, "", "imaginea nouă nu se potrivește decupării vechi")
        let onlyImage = LaunchBannerConfig(enabled: true, campaigns: [campaign("i", .image, image: "covers/i.png")])
        XCTAssertFalse(onlyImage.withLegacyFallback().isDisplayable, "„Doar imagine” rămâne ascuns la clienții vechi")
    }

    func testImageOnlyLayoutKeepsGraphicFullyVisible() {
        let narrow = PromoBannerSpec.imageOnlyLayout(width: 470, hasWide: true)
        XCTAssertFalse(narrow.useWide); XCTAssertEqual(narrow.height, 470 / 6, accuracy: 0.01)
        let wide = PromoBannerSpec.imageOnlyLayout(width: 1150, hasWide: true)
        XCTAssertTrue(wide.useWide); XCTAssertEqual(wide.height, 1150 / 12, accuracy: 0.01)
        XCTAssertEqual(PromoBannerSpec.imageOnlyLayout(width: 1150, hasWide: false).height, PromoBannerSpec.maxImageHeight)
    }

    func testTextFallsBackToRomanian() {
        var c = campaign("a"); c.texts["en"] = .init(top: "", main: "")
        XCTAssertEqual(c.text(for: "en")?.main, "Ma"); XCTAssertEqual(c.text(for: "es")?.main, "Ma")
    }
}
