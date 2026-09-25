import Foundation
import CryptoKit

/// Verificarea pachetului de actualizare înainte de instalarea privilegiată
/// (S2, 2026-09-25 — engineering/DISTRIBUTION_SECURITY.md §S2).
///
/// Două porți, ambele obligatorii:
///   1. în contextul utilizatorului (`verify`) — eșec rapid, mesaj clar;
///   2. în scriptul root (`rootInstallScript`) — root COPIAZĂ pachetul într-un
///      folder propriu (700), apoi verifică exact copia pe care o instalează:
///      SHA-256 = cel verificat la pasul 1, semnătură Developer ID Installer,
///      Team ID GDC. Orice eșec oprește scriptul ÎNAINTE de `installer`.
/// Astfel „verificat A, instalat B” nu e posibil: fișierul din folderul
/// utilizatorului nu mai e atins după copiere.
public enum UpdatePackageVerifier {
    /// Team ID-ul GDC (certificatele Developer ID Application/Installer).
    public static let trustedTeamID = "8AR6XP8MG7"
    static let distributionStatus = "Status: signed by a developer certificate issued by Apple for distribution"

    public enum VerifyError: Error, Equatable, CustomStringConvertible {
        case unsigned
        case notDeveloperIDDistribution
        case wrongTeam(String?)
        case checksumMismatch
        case invalidVersion(String)
        case unsafePath
        case toolFailed(String)

        public var description: String {
            switch self {
            case .unsigned: return "pachetul nu este semnat"
            case .notDeveloperIDDistribution: return "pachetul nu e semnat cu un certificat Developer ID"
            case .wrongTeam(let t): return "pachetul e semnat de alt dezvoltator (\(t ?? "necunoscut"))"
            case .checksumMismatch: return "suma de control nu corespunde"
            case .invalidVersion(let v): return "versiune invalidă în manifest: \(v)"
            case .unsafePath: return "cale de fișier nesigură"
            case .toolFailed(let d): return "verificarea nu a putut rula: \(d)"
            }
        }
    }

    public struct Signature: Equatable {
        public let teamID: String
        public let notarized: Bool
    }

    /// Doar cifre și puncte (1.2.3). Versiunea ajunge în nume de fișiere;
    /// orice alt caracter e respins (fără injecție în comenzi).
    public static func validateVersion(_ version: String) throws {
        guard version.range(of: #"^\d{1,4}(\.\d{1,4}){1,3}$"#, options: .regularExpression) != nil else {
            throw VerifyError.invalidVersion(version)
        }
    }

    /// Interpretează ieșirea `pkgutil --check-signature`. Cerințe: status de
    /// distribuție Developer ID și primul certificat = „Developer ID Installer: … (<Team ID>)”.
    public static func parse(pkgutilOutput output: String, exitStatus: Int32,
                             expectedTeamID: String = trustedTeamID) -> Result<Signature, VerifyError> {
        guard exitStatus == 0, !output.contains("Status: no signature") else { return .failure(.unsigned) }
        guard output.contains(distributionStatus) else { return .failure(.notDeveloperIDDistribution) }
        let leaf = output.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
            .first { $0.hasPrefix("1. ") }
        guard let leaf, leaf.hasPrefix("1. Developer ID Installer: ") else {
            return .failure(.notDeveloperIDDistribution)
        }
        let team = leaf.range(of: #"\(([A-Z0-9]{10})\)$"#, options: .regularExpression)
            .map { String(leaf[$0].dropFirst().dropLast()) }
        guard team == expectedTeamID else { return .failure(.wrongTeam(team)) }
        return .success(Signature(teamID: expectedTeamID, notarized: output.contains("Notarization: trusted by the Apple notary service")))
    }

    public static func sha256(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while true {
            let chunk = try autoreleasepool { try handle.read(upToCount: 8 << 20) } ?? Data()
            if chunk.isEmpty { break }
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    /// Poarta 1 (context utilizator): semnătură + Team ID; întoarce SHA-256-ul
    /// fișierului verificat, pe care poarta root îl cere identic.
    public static func verify(pkg: URL, expectedTeamID: String = trustedTeamID) throws -> (Signature, sha256: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/pkgutil")
        process.arguments = ["--check-signature", pkg.path]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do { try process.run() } catch { throw VerifyError.toolFailed(error.localizedDescription) }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let signature = try parse(pkgutilOutput: String(decoding: data, as: UTF8.self),
                                  exitStatus: process.terminationStatus, expectedTeamID: expectedTeamID).get()
        return (signature, try sha256(of: pkg))
    }

    /// Cale acceptată într-un script shell: absolută, fără ghilimele/metacaractere.
    static func isSafePath(_ path: String) -> Bool {
        path.hasPrefix("/") && path.range(of: #"^[A-Za-z0-9/._ -]+$"#, options: .regularExpression) != nil
    }

    /// Argumentele `osascript` care rulează scriptul (ca root dacă `elevated`):
    /// scriptul e transmis ca argv, deci nu trece prin escaping manual.
    /// `elevated: false` există doar pentru teste (același drum, fără parolă).
    public static func osascriptArguments(script: String, elevated: Bool = true) -> [String] {
        ["-e", "on run argv",
         "-e", "do shell script \"/bin/bash -c \" & quoted form of (item 1 of argv)" + (elevated ? " with administrator privileges" : ""),
         "-e", "end run",
         script]
    }

    /// Poarta 2: scriptul rulat ca root (via `osascript … with administrator privileges`,
    /// transmis ca ARGUMENT, nu ca fișier — nu există un fișier de script de înlocuit).
    /// `installCommand` e injectabil doar pentru teste; producția folosește `installer`.
    public static func rootInstallScript(pkg: URL, expectedSHA256: String, relaunchApp: String, logFile: URL,
                                         expectedTeamID: String = trustedTeamID,
                                         installCommand: String = "/usr/sbin/installer -target / -pkg",
                                         workParent: String = "/private/tmp") throws -> String {
        guard isSafePath(pkg.path), isSafePath(relaunchApp), isSafePath(logFile.path), isSafePath(workParent),
              expectedSHA256.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil,
              expectedTeamID.range(of: "^[A-Z0-9]{10}$", options: .regularExpression) != nil else {
            throw VerifyError.unsafePath
        }
        return """
        set -u
        exec >>'\(logFile.path)' 2>&1
        sleep 2  # aplicația curentă se închide înainte de instalare
        block() { echo "INSTALARE BLOCATĂ: $1"; exit "$2"; }
        work=$(mktemp -d '\(workParent)/gdcpm-install.XXXXXX') || block "folder temporar" 10
        chmod 700 "$work"
        trap 'rm -rf "$work"' EXIT
        cp '\(pkg.path)' "$work/update.pkg" || block "copiere" 11
        pkg="$work/update.pkg"
        actual=$(/usr/bin/shasum -a 256 "$pkg" | /usr/bin/awk '{print $1}')
        [ "$actual" = '\(expectedSHA256)' ] || block "suma de control diferă" 20
        sig=$(/usr/sbin/pkgutil --check-signature "$pkg") || block "pachet nesemnat" 21
        printf '%s\\n' "$sig" | /usr/bin/grep -qF '\(distributionStatus)' || block "nu e Developer ID" 22
        printf '%s\\n' "$sig" | /usr/bin/grep -qE '^ *1\\. Developer ID Installer: .*\\(\(expectedTeamID)\\)$' || block "Team ID diferit" 23
        echo "Verificare OK, instalez."
        \(installCommand) "$pkg" || block "installer a eșuat" 30
        echo "Pornesc aplicația actualizată."
        /usr/bin/open '\(relaunchApp)'
        """
    }
}
