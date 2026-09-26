import Foundation

/// Apeluri la API-ul GitHub prin `gh`, cu autentificarea lui Cristi de pe
/// acest Mac — niciun token în binar sau în memoria aplicației.
/// Fără `gh` instalat sau neautentificat: `nil` (apelantul arată „necunoscut").
enum GHCLI {
    /// `gh` nu e în PATH-ul unei aplicații pornite din Finder.
    static func executable() -> URL? {
        for path in ["/opt/homebrew/bin/gh", "/usr/local/bin/gh", "/usr/bin/gh"] where FileManager.default.isExecutableFile(atPath: path) {
            return URL(fileURLWithPath: path)
        }
        return nil
    }

    /// Ieșirea standard la cod 0; `nil` altfel. stderr nu se loghează
    /// (poate conține detalii de autentificare).
    static func run(_ args: [String]) async throws -> String? {
        guard let gh = executable() else { return nil }
        return try await Task.detached {
            let process = Process()
            process.executableURL = gh
            process.arguments = args
            // Fără prompturi interactive într-o aplicație GUI.
            var env = ProcessInfo.processInfo.environment
            env["GH_PROMPT_DISABLED"] = "1"
            process.environment = env
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe()
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            return String(data: data, encoding: .utf8)
        }.value
    }
}
