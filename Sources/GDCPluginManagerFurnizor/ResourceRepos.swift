import Foundation

/// Repo-urile private de resurse: DOAR nume, fără credential.
///
/// Înlocuiește partea non-secretă a `PrivateCatalogAuth` (lot A, 2026-09-26).
/// Furnizorul nu mai încorporează tokenul GitHub vechi: publicarea trece prin
/// `git` (credential helper), apelurile API prin `gh` (`GHCLI`), iar clienții
/// descarcă prin `authorize-download` (tokenul stă doar pe server).
/// `PrivateCatalogAuth.swift` e exclus din compilare în Package.swift.
public struct ResourceRepo: Sendable {
    public let owner: String
    public let name: String
}

public enum ResourceRepos {
    public static let ownerLogin = "gordasgdc"

    /// Cheia din catalog (`PluginFile.repo`) → repo-ul real.
    public static let repos: [String: ResourceRepo] = [
        "files":     ResourceRepo(owner: ownerLogin, name: "gdc-plugin-manager-files"),
        "pdfs":      ResourceRepo(owner: ownerLogin, name: "gdc-plugin-manager-pdfs"),
        "scripts":   ResourceRepo(owner: ownerLogin, name: "gdc-plugin-manager-scripts"),
        "resources": ResourceRepo(owner: ownerLogin, name: "gdc-plugin-manager-resources"),
    ]

    /// Tot ce a fost publicat înainte de multi-repo nu are câmp `repo`.
    public static let defaultRepoKey = "files"

    /// Cade pe repo-ul principal la o cheie necunoscută, în loc să eșueze.
    public static func repo(for key: String?) -> ResourceRepo {
        repos[key ?? defaultRepoKey] ?? repos[defaultRepoKey]!
    }

    public static var owner: String { repos[defaultRepoKey]!.owner }
    public static var repo: String { repos[defaultRepoKey]!.name }
}
