import XCTest
import CryptoKit
@testable import GDCPluginManagerCore

/// Rețea simulată: fiecare cerere e înregistrată și primește răspunsul programat.
final class StubProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) -> (Int, Data))?
    nonisolated(unsafe) static var requests: [URLRequest] = []

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        var req = request
        if req.httpBody == nil, let stream = req.httpBodyStream {
            stream.open(); defer { stream.close() }
            var data = Data(); var buf = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable { let n = stream.read(&buf, maxLength: buf.count); if n <= 0 { break }; data.append(buf, count: n) }
            req.httpBody = data
        }
        Self.requests.append(req)
        let (status, body) = Self.handler?(req) ?? (500, Data())
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: req.url!, statusCode: status, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

final class DownloadAuthorizerTests: XCTestCase {
    private let endpoint = URL(string: "https://example.supabase.co/functions/v1/authorize-download")!
    private let product = "gdc-demo"
    private let path = "gdc-demo/1.0/a.ofx"
    private let payload = Data("continut-produs".utf8)
    private var sha: String { SHA256.hash(data: payload).map { String(format: "%02x", $0) }.joined() }

    private func authorizer() -> DownloadAuthorizer {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubProtocol.self]
        return DownloadAuthorizer(endpoint: endpoint, apiKey: "anon-public", session: URLSession(configuration: config),
                                  machineID: "AEBAGBAFAY", platform: "mac", clientVersion: "9.9.9")
    }

    private func authJSON(url: String = "https://raw.example/f?token=t", product: String? = nil, path: String? = nil) -> Data {
        try! JSONSerialization.data(withJSONObject: ["url": url, "productID": product ?? self.product, "path": path ?? self.path,
                                                    "sha256": sha, "size": payload.count, "issuedAt": "x", "useWithinSeconds": 60])
    }

    override func setUp() { StubProtocol.requests = []; StubProtocol.handler = nil }

    func testAuthorizedDownloadReturnsVerifiedBytes() async throws {
        StubProtocol.handler = { req in req.url == self.endpoint ? (200, self.authJSON()) : (200, self.payload) }
        let data = try await authorizer().fetch(productID: product, path: path, expectedSHA256: sha, serial: "SERIAL-1")
        XCTAssertEqual(data, payload)
        XCTAssertEqual(StubProtocol.requests.count, 2)

        let authReq = StubProtocol.requests[0]
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: authReq.httpBody ?? Data()) as? [String: String])
        XCTAssertEqual(body, ["productID": product, "path": path, "machineID": "AEBAGBAFAY", "platform": "mac",
                              "serial": "SERIAL-1", "clientVersion": "9.9.9"])
        XCTAssertEqual(authReq.value(forHTTPHeaderField: "apikey"), "anon-public")
        // Descărcarea artefactului NU poartă niciun antet de autentificare.
        XCTAssertNil(StubProtocol.requests[1].value(forHTTPHeaderField: "Authorization"))
    }

    func testFreeProductSendsNoSerial() async throws {
        StubProtocol.handler = { req in req.url == self.endpoint ? (200, self.authJSON()) : (200, self.payload) }
        _ = try await authorizer().fetch(productID: product, path: path, expectedSHA256: sha, serial: nil)
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: StubProtocol.requests[0].httpBody ?? Data()) as? [String: String])
        XCTAssertNil(body["serial"])
    }

    func testServerErrorsMapToFailures() async {
        let cases: [(Int, String, DownloadAuthorizer.Failure)] = [
            (403, "invalid_license", .invalidLicense), (403, "revoked_license", .revokedLicense),
            (403, "unauthorized_platform", .unauthorizedPlatform), (403, "unauthorized_artifact", .unauthorizedArtifact),
            (404, "unknown_product", .unknownProduct), (404, "artifact_unavailable", .artifactUnavailable),
            (429, "rate_limited", .rateLimited), (400, "malformed_request", .malformedRequest), (500, "internal_error", .server(500)),
        ]
        for (status, code, expected) in cases {
            StubProtocol.handler = { _ in (status, try! JSONSerialization.data(withJSONObject: ["error": code, "message": "m"])) }
            do {
                _ = try await authorizer().fetch(productID: product, path: path, expectedSHA256: sha, serial: nil)
                XCTFail("\(code) acceptat")
            } catch { XCTAssertEqual(error as? DownloadAuthorizer.Failure, expected, code) }
        }
    }

    func testExpiredURLIsReauthorizedOnceThenFails() async {
        var downloads = 0
        StubProtocol.handler = { req in
            if req.url == self.endpoint { return (200, self.authJSON()) }
            downloads += 1
            return (403, Data())
        }
        do {
            _ = try await authorizer().fetch(productID: product, path: path, expectedSHA256: sha, serial: nil)
            XCTFail("URL expirat acceptat")
        } catch { XCTAssertEqual(error as? DownloadAuthorizer.Failure, .artifactUnavailable) }
        XCTAssertEqual(downloads, 2, "exact o reautorizare")
        XCTAssertEqual(StubProtocol.requests.filter { $0.url == endpoint }.count, 2)
    }

    func testExpiredURLRecoversWithFreshAuthorization() async throws {
        var downloads = 0
        StubProtocol.handler = { req in
            if req.url == self.endpoint { return (200, self.authJSON()) }
            downloads += 1
            return downloads == 1 ? (404, Data()) : (200, self.payload)
        }
        let data = try await authorizer().fetch(productID: product, path: path, expectedSHA256: sha, serial: nil)
        XCTAssertEqual(data, payload)
    }

    func testChecksumMismatchIsRejectedEvenWhenAuthorized() async {
        StubProtocol.handler = { req in req.url == self.endpoint ? (200, self.authJSON()) : (200, Data("alt continut".utf8)) }
        do {
            _ = try await authorizer().fetch(productID: product, path: path, expectedSHA256: sha, serial: nil)
            XCTFail("fișier modificat acceptat")
        } catch { XCTAssertEqual(error as? DownloadAuthorizer.Failure, .checksumMismatch) }
    }

    func testAuthorizationForADifferentArtifactOrInsecureURLIsRejected() async {
        for bad in [authJSON(path: "gdc-demo/1.0/alt.ofx"), authJSON(product: "alt-produs"), authJSON(url: "http://raw.example/f")] {
            StubProtocol.requests = []
            StubProtocol.handler = { req in req.url == self.endpoint ? (200, bad) : (200, self.payload) }
            do {
                _ = try await authorizer().fetch(productID: product, path: path, expectedSHA256: sha, serial: nil)
                XCTFail("autorizare nepotrivită acceptată")
            } catch { XCTAssertEqual(error as? DownloadAuthorizer.Failure, .server(200)) }
            XCTAssertEqual(StubProtocol.requests.count, 1, "artefactul nu trebuie descărcat")
        }
    }

    func testNetworkFailure() async {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 1
        let a = DownloadAuthorizer(endpoint: URL(string: "https://127.0.0.1:1/x")!, apiKey: "k", session: URLSession(configuration: config), machineID: "AEBAGBAFAY")
        do {
            _ = try await a.authorize(productID: product, path: path, serial: nil)
            XCTFail("rețea indisponibilă acceptată")
        } catch { XCTAssertEqual(error as? DownloadAuthorizer.Failure, .network) }
    }
}
