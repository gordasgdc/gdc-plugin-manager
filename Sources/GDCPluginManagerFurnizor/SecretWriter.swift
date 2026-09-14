import Foundation
import CryptoKit

/// Scrie o valoare nouă la locul unui secret — cu backup înainte și
/// verificare prin recitire după.
///
/// DE CE NU UN `sed` COPIAT DIN GHID: pasul manual pe care îl descria ghidul
/// de dinainte funcționează, dar e exact genul de comandă care, tastată greșit sub
/// presiune, rescrie altceva sau lasă fișierul pe jumătate. Aici fiecare
/// scriere e: (1) backup al fișierului întreg, (2) înlocuire DOAR a grupului
/// capturat de regex, (3) recitire și comparare de amprentă. Dacă pasul 3 nu
/// confirmă, scrierea e raportată ca eșuată, nu presupusă reușită.
///
/// VALORILE NU SE LOGHEAZĂ NICIODATĂ. Mesajele de eroare vorbesc despre
/// fișiere și amprente, niciodată despre conținut.
/// `@MainActor`: scrierile pornesc din interfață și sunt fișiere mici
/// (câțiva KB) — nu justifică o coadă proprie. Adnotarea aliniază acest tip
/// cu `SecretRegistry`, ale cărui funcții de citire și amprentă le refolosim
/// pentru verificarea de după scriere.
@MainActor
enum SecretWriter {

    enum WriteError: LocalizedError {
        case notWritable(String)
        case fileMissing(String)
        case patternNotFound(String)
        case verificationFailed(String)
        case ghUnavailable
        case ghFailed(String)

        var errorDescription: String? {
            switch self {
            case .notWritable(let what):
                return "„\(what)" + "” nu se poate schimba din aplicație — vezi pașii manuali din ghid."
            case .fileMissing(let path):
                return "Nu găsesc fișierul: \(path)"
            case .patternNotFound(let path):
                return "Nu am găsit linia de modificat în \(path). Fișierul a fost probabil restructurat — modifică manual și actualizează tiparul din SecretRegistry."
            case .verificationFailed(let path):
                return "Am scris în \(path), dar recitirea nu confirmă valoarea nouă. NU considera schimbarea făcută."
            case .ghUnavailable:
                return "Nu găsesc `gh` pe acest Mac. Instalează GitHub CLI sau pune secretul manual din interfața GitHub."
            case .ghFailed(let output):
                return "Comanda `gh` a eșuat:\n\(output)"
            }
        }
    }

    /// Unde se strâng copiile de siguranță. Application Support, nu un folder
    /// temporar — vezi motivul documentat în `CoverImageStore.prepareLocal`:
    /// uneltele de curățare șterg agresiv `/var/folders/.../T/`.
    static var backupDirectory: URL {
        let base = (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                 appropriateFor: nil, create: true))
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        return base
            .appendingPathComponent("GDCPluginManagerFurnizor", isDirectory: true)
            .appendingPathComponent("secret-backups", isDirectory: true)
    }

    /// Scrie `newValue` la locația dată. Întoarce calea backup-ului, dacă s-a
    /// făcut unul (pentru ca UI-ul să poată spune unde e, nu doar că există).
    @discardableResult
    static func write(_ newValue: String, to location: SecretLocation) throws -> URL? {
        switch location {
        case .sourceFile(let path, let pattern):
            return try writeSourceFile(newValue, path: path, pattern: pattern)

        case .userDefaults(let key):
            UserDefaults.standard.set(newValue, forKey: key)
            guard UserDefaults.standard.string(forKey: key) == newValue else {
                throw WriteError.verificationFailed("preferințe → \(key)")
            }
            return nil

        case .diskFile(let url):
            let backup = try backUp(url)
            try newValue.write(to: url, atomically: true, encoding: .utf8)
            // Cheia privată nu trebuie să rămână lizibilă pentru alți
            // utilizatori ai Mac-ului; `atomically` scrie un fișier nou, deci
            // permisiunile vechi nu se păstrează singure.
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
            let reread = try? String(contentsOf: url, encoding: .utf8)
            guard reread?.trimmingCharacters(in: .whitespacesAndNewlines) == newValue else {
                throw WriteError.verificationFailed(url.path)
            }
            return backup

        case .keychainCertificate:
            throw WriteError.notWritable("Certificat din keychain")

        case .githubActionsSecret(let repo, let name):
            try setGitHubSecret(newValue, repo: repo, name: name)
            return nil
        }
    }

    // MARK: Fișiere sursă

    private static func writeSourceFile(_ newValue: String, path: String, pattern: String) throws -> URL? {
        let url = URL(fileURLWithPath: path, relativeTo: RepoCheckoutPaths.publicCatalogRepo).standardizedFileURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw WriteError.fileMissing(url.path)
        }
        let text = try String(contentsOf: url, encoding: .utf8)
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges > 1,
              let valueRange = Range(match.range(at: 1), in: text) else {
            throw WriteError.patternNotFound(url.path)
        }

        let backup = try backUp(url)

        // Înlocuire pe intervalul exact al grupului capturat, NU prin
        // template-ul regexului: un token care conține `$` ar fi interpretat
        // ca referință de grup și ar produce tăcut altă valoare.
        var updated = text
        updated.replaceSubrange(valueRange, with: newValue)
        try updated.write(to: url, atomically: true, encoding: .utf8)

        guard let confirmed = SecretRegistry.readValue(at: .sourceFile(path: path, pattern: pattern)),
              SecretRegistry.fingerprint(confirmed) == SecretRegistry.fingerprint(newValue) else {
            throw WriteError.verificationFailed(url.path)
        }
        return backup
    }

    private static func backUp(_ url: URL) throws -> URL {
        let stamp = ISO8601DateFormatter.filenameSafe.string(from: Date())
        let folder = backupDirectory.appendingPathComponent(stamp, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let destination = folder.appendingPathComponent(url.lastPathComponent)
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.copyItem(at: url, to: destination)
        return destination
    }

    // MARK: Secrete de CI

    /// Pune valoarea în secretul de Actions prin `gh`, cu valoarea trimisă pe
    /// STDIN — nu ca argument de linie de comandă, care ar fi vizibil în
    /// lista de procese a oricui e logat pe Mac cât durează comanda.
    private static func setGitHubSecret(_ value: String, repo: String, name: String) throws {
        let candidates = ["/opt/homebrew/bin/gh", "/usr/local/bin/gh", "/usr/bin/gh"]
        guard let ghPath = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            throw WriteError.ghUnavailable
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ghPath)
        process.arguments = ["secret", "set", name, "--repo", repo]
        let input = Pipe(), output = Pipe()
        process.standardInput = input
        process.standardOutput = output
        process.standardError = output
        try process.run()
        input.fileHandleForWriting.write(Data(value.utf8))
        try? input.fileHandleForWriting.close()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw WriteError.ghFailed(String(data: data, encoding: .utf8) ?? "cod \(process.terminationStatus)")
        }
    }
}

extension ISO8601DateFormatter {
    /// `2026-09-14T153012Z` — sortabil alfabetic și valid ca nume de folder
    /// (`:` e separator de cale în Finder).
    static let filenameSafe: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withYear, .withMonth, .withDay, .withTime, .withTimeZone, .withDashSeparatorInDate]
        return f
    }()
}
