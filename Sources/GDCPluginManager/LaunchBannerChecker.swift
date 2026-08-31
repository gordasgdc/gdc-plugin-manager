import Foundation
import AppKit
import Combine
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
}
