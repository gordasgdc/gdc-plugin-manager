import XCTest
import CryptoKit
@testable import GDCPluginManagerCore

/// Test end-to-end pe funcția `authorize-download` DEPLOYATĂ, cu codul real al clientului.
/// Rulează doar la cerere: `GDC_LIVE_TESTS=1 swift test --filter DownloadAuthorizerLiveTests`
/// (în CI e sărit: nu depinde de rețea și nu adaugă rânduri în auditul de producție).
final class DownloadAuthorizerLiveTests: XCTestCase {
    func testRealFreeResourceDownloadsWithCatalogChecksum() async throws {
        guard ProcessInfo.processInfo.environment["GDC_LIVE_TESTS"] == "1" else { throw XCTSkip("GDC_LIVE_TESTS=1 pentru testul live") }
        let (catalogData, _) = try await URLSession.shared.data(from: URL(string: "https://gordas.dev/catalog.json")!)
        let catalog = try JSONDecoder().decode(Catalog.self, from: catalogData)
        let resource = try XCTUnwrap(catalog.downloadableResources.first { $0.isFree && !$0.files.isEmpty }, "nicio resursă gratuită în catalog")
        let file = resource.files[0]
        let authorizer = DownloadAuthorizer(machineID: "AAAAAAAAAA", clientVersion: "live-xctest")

        let data = try await authorizer.fetch(productID: resource.id, path: file.path, expectedSHA256: file.sha256, serial: nil)
        XCTAssertEqual(SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined(), file.sha256.lowercased())

        do {
            _ = try await authorizer.fetch(productID: resource.id, path: "\(resource.id)/nu-exista.bin", expectedSHA256: nil, serial: nil)
            XCTFail("fișier străin autorizat")
        } catch { XCTAssertEqual(error as? DownloadAuthorizer.Failure, .unauthorizedArtifact) }
    }
}
