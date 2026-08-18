import Foundation
import CryptoKit

enum InstallError: Error, LocalizedError {
    case downloadFailed
    case checksumMismatch
    case writeFailed(String)

    var errorDescription: String? {
        switch self {
        case .downloadFailed: return "Download failed."
        case .checksumMismatch: return "Downloaded file doesn't match the expected checksum."
        case .writeFailed(let detail): return "Couldn't write the file: \(detail)"
        }
    }
}

/// Downloads a plugin, verifies it, and copies it into the DaVinci
/// Resolve folder its type belongs in (see `PluginType.installDirectory`
/// in CatalogModel.swift). Tries a direct write first — Resolve's own
/// plugin folders are usually user-writable even though they live under
/// the top-level /Library — and only asks for the admin password (via
/// the same native-dialog `osascript` pattern used elsewhere in this
/// developer's tools, never a scripted `sudo`) if that direct write is
/// actually refused.
@MainActor
final class InstallManager: ObservableObject {
    static let shared = InstallManager()

    /// [pluginId: installedVersion]
    @Published private(set) var installedVersions: [String: String] = [:]

    private var stateFileURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("GDCPluginManager", isDirectory: true)
            .appendingPathComponent("installed.json")
    }

    private init() {
        loadState()
    }

    func isInstalled(_ item: PluginItem) -> Bool {
        installedVersions[item.id] != nil
    }

    func hasUpdate(_ item: PluginItem) -> Bool {
        guard let installed = installedVersions[item.id] else { return false }
        return installed != item.version
    }

    func install(_ item: PluginItem) async throws {
        let (tempURL, _) = try await URLSession.shared.download(from: item.url)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        if let expectedSHA = item.sha256, !expectedSHA.isEmpty {
            let data = try Data(contentsOf: tempURL)
            let actualSHA = SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
            guard actualSHA.lowercased() == expectedSHA.lowercased() else {
                throw InstallError.checksumMismatch
            }
        }

        let destinationDir = item.type.installDirectory
        let destinationURL = destinationDir.appendingPathComponent(item.filename)

        try writeFile(from: tempURL, to: destinationURL, creatingDirectory: destinationDir)

        installedVersions[item.id] = item.version
        saveState()
    }

    func remove(_ item: PluginItem) throws {
        let destinationURL = item.type.installDirectory.appendingPathComponent(item.filename)
        try deleteFile(at: destinationURL)
        installedVersions.removeValue(forKey: item.id)
        saveState()
    }

    // MARK: - Filesystem, with an admin-elevation fallback

    private func writeFile(from sourceURL: URL, to destinationURL: URL, creatingDirectory directory: URL) throws {
        let fm = FileManager.default
        do {
            try fm.createDirectory(at: directory, withIntermediateDirectories: true)
            if fm.fileExists(atPath: destinationURL.path) {
                try fm.removeItem(at: destinationURL)
            }
            try fm.copyItem(at: sourceURL, to: destinationURL)
        } catch {
            // Direct write failed (most likely a permissions issue on a
            // top-level /Library path) - fall back to a native admin
            // password prompt for just this one copy, exactly like the
            // /Applications moves done manually elsewhere this session.
            try elevatedCopy(from: sourceURL, to: destinationURL, creatingDirectory: directory)
        }
    }

    private func deleteFile(at url: URL) throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else { return }
        do {
            try fm.removeItem(at: url)
        } catch {
            try elevatedRemove(at: url)
        }
    }

    private func elevatedCopy(from sourceURL: URL, to destinationURL: URL, creatingDirectory directory: URL) throws {
        let script = """
        mkdir -p \(shellQuote(directory.path)) && \
        rm -f \(shellQuote(destinationURL.path)) && \
        cp \(shellQuote(sourceURL.path)) \(shellQuote(destinationURL.path)) && \
        chmod 644 \(shellQuote(destinationURL.path))
        """
        try runElevated(script)
    }

    private func elevatedRemove(at url: URL) throws {
        try runElevated("rm -f \(shellQuote(url.path))")
    }

    private func runElevated(_ shellScript: String) throws {
        let appleScript = "do shell script \"\(shellScript.replacingOccurrences(of: "\"", with: "\\\""))\" with administrator privileges"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", appleScript]
        let stderrPipe = Pipe()
        process.standardError = stderrPipe
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let data = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: data, encoding: .utf8) ?? "unknown error"
            throw InstallError.writeFailed(message)
        }
    }

    private func shellQuote(_ path: String) -> String {
        "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    // MARK: - Persisted install state

    private func loadState() {
        guard let data = try? Data(contentsOf: stateFileURL),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data) else { return }
        installedVersions = decoded
    }

    private func saveState() {
        guard let data = try? JSONEncoder().encode(installedVersions) else { return }
        try? FileManager.default.createDirectory(at: stateFileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: stateFileURL)
    }
}
