import Foundation
import AppKit
import Combine
import CryptoKit
import GDCPluginManagerCore

/// Fetch-ul `docs/launch-banner.json` + descărcarea/cache-ul imaginii,
/// portat 1:1 după `SeasonalBackgroundLayer` (retry, verificare explicită
/// de status HTTP, fallback pe cache local la eșec) - vezi ContentView.swift
/// pentru istoricul bug-urilor deja reparate acolo, care motivează tiparul.
@MainActor
final class LaunchBannerChecker: ObservableObject {
    static let shared = LaunchBannerChecker()

    @Published private(set) var config: LaunchBannerConfig?
    @Published private(set) var nsImage: NSImage?
    /// Faza 5: campania activă (dacă `launch-banner.json` are `campaigns`) și imaginile ei, decodate o singură dată.
    @Published private(set) var activeCampaign: PromoBannerCampaign?
    @Published private(set) var promoImages = PromoBannerImages()
    /// Imagini deja decodate, pe cale — nicio decodare repetată la redesenare sau la reîmprospătare.
    private var decoded: [String: NSImage] = [:]

    private static let jsonURL = URL(string: "https://gordas.dev/launch-banner.json")!
    private var cacheDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("GDCPluginManager")
    }
    private var jsonCacheURL: URL { cacheDirectory.appendingPathComponent("launch-banner-cache.json") }
    private var imageCacheURL: URL { cacheDirectory.appendingPathComponent("launch-banner-cache-image") }

    func refresh() async {
        var lastError: Error?
        for attempt in 1...2 {
            do {
                let (data, response) = try await URLSession.shared.data(from: Self.jsonURL)
                let status = (response as? HTTPURLResponse)?.statusCode ?? -1
                guard status == 200 else {
                    DiagnosticLog.write("LaunchBanner", "HTTP \(status) la încercarea \(attempt)")
                    if attempt == 1 { try? await Task.sleep(nanoseconds: 800_000_000) }
                    continue
                }
                let decoded = try JSONDecoder().decode(LaunchBannerConfig.self, from: data)
                config = decoded
                try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
                try? data.write(to: jsonCacheURL)
                await loadImage(for: decoded)
                await loadCampaign(for: decoded)
                DiagnosticLog.write("LaunchBanner", "OK, enabled=\(decoded.enabled)")
                return
            } catch {
                lastError = error
                DiagnosticLog.write("LaunchBanner", "fetch EȘUAT la încercarea \(attempt): \(error)")
                if attempt == 1 { try? await Task.sleep(nanoseconds: 800_000_000) }
            }
        }
        // Fetch eșuat de 2 ori - cade pe ultimul config cunoscut, cache-uit
        // pe disc (offline-first, ca la filigranele sezoniere).
        if let cached = try? Data(contentsOf: jsonCacheURL),
           let decoded = try? JSONDecoder().decode(LaunchBannerConfig.self, from: cached) {
            DiagnosticLog.write("LaunchBanner", "fetch eșuat (\(String(describing: lastError))), fallback pe cache local")
            config = decoded
            await loadImage(for: decoded)
            await loadCampaign(for: decoded)
        } else {
            DiagnosticLog.write("LaunchBanner", "fetch eșuat (\(String(describing: lastError))) ȘI niciun cache local - banner ascuns")
        }
    }

    private func loadImage(for config: LaunchBannerConfig) async {
        guard config.isDisplayable, let url = config.imageURL else {
            nsImage = nil
            return
        }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            guard status == 200, let image = NSImage(data: data) else {
                DiagnosticLog.write("LaunchBanner", "imagine HTTP \(status) sau nedecodabilă - fallback cache")
                nsImage = (try? Data(contentsOf: imageCacheURL)).flatMap(NSImage.init(data:))
                return
            }
            nsImage = image
            try? data.write(to: imageCacheURL)
        } catch {
            DiagnosticLog.write("LaunchBanner", "descărcare imagine eșuată: \(error)")
            nsImage = (try? Data(contentsOf: imageCacheURL)).flatMap(NSImage.init(data:))
        }
    }

    // MARK: Campanii (Faza 5)

    private var promoCacheDirectory: URL { cacheDirectory.appendingPathComponent("promo-banner-images", isDirectory: true) }

    /// Alege campania activă și îi încarcă imaginile asincron, cu cache pe disc (fallback offline).
    private func loadCampaign(for config: LaunchBannerConfig) async {
        #if DEBUG
        // `-PromoBannerFixture text|imageText|image`: campanie de test cu grafică generată local.
        if let raw = UserDefaults.standard.string(forKey: "PromoBannerFixture"), let mode = PromoBannerMode(rawValue: raw) {
            promoImages = PromoBannerFixtures.images(for: mode)
            activeCampaign = PromoBannerFixtures.campaign(mode)
            return
        }
        #endif
        guard let campaign = config.activeCampaign() else {
            activeCampaign = nil
            promoImages = PromoBannerImages()
            return
        }
        var images = PromoBannerImages()
        if campaign.mode != .text {
            images.light = await image(at: campaign.imagePath)
            images.dark = await image(at: campaign.imagePathDark)
            if campaign.mode == .image {
                images.wideLight = await image(at: campaign.imagePathWide)
                images.wideDark = await image(at: campaign.imagePathWideDark)
            }
        }
        // O campanie cu imagine obligatorie, dar nedescărcabilă și fără cache, nu se afișează pe jumătate.
        if campaign.mode != .text && images.light == nil {
            DiagnosticLog.write("LaunchBanner", "campania \(campaign.id): imaginea lipsește — banner ascuns")
            activeCampaign = nil
            return
        }
        promoImages = images
        activeCampaign = campaign
        DiagnosticLog.write("LaunchBanner", "campanie activă \(campaign.id) (\(campaign.mode.rawValue))")
    }

    private func image(at path: String?) async -> NSImage? {
        guard let path, !path.isEmpty, let url = CatalogAssets.imageURL(for: path) else { return nil }
        if let cached = decoded[path] { return cached }
        // Nume stabil între porniri (hashValue e aleator per proces): SHA-256 al căii.
        let digest = SHA256.hash(data: Data(path.utf8)).prefix(8).map { String(format: "%02x", $0) }.joined()
        let file = promoCacheDirectory.appendingPathComponent(digest + "-" + url.lastPathComponent)
        var data: Data?
        do {
            let (fetched, response) = try await URLSession.shared.data(from: url)
            if (response as? HTTPURLResponse)?.statusCode == 200 {
                data = fetched
                try? FileManager.default.createDirectory(at: promoCacheDirectory, withIntermediateDirectories: true)
                try? fetched.write(to: file)
            }
        } catch {
            DiagnosticLog.write("LaunchBanner", "imagine campanie: \(error) — încerc cache-ul")
        }
        if data == nil { data = try? Data(contentsOf: file) }
        guard let data, let image = NSImage(data: data) else { return nil }
        decoded[path] = image
        return image
    }

}
