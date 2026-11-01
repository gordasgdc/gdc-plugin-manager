import Foundation
import Security

/// Verifică, prin mecanismele platformei, că un bundle aflat pe disc este semnat valid de Team ID-ul așteptat.
/// Se folosește doar pentru intrările care declară `teamIdentifier`; nu citește licențe și nu execută aplicația.
enum ExternalAppSignature {
    static func isValid(appURL: URL, teamIdentifier: String) -> Bool {
        var code: SecStaticCode?
        guard SecStaticCodeCreateWithPath(appURL as CFURL, [], &code) == errSecSuccess, let code else { return false }
        var requirement: SecRequirement?
        let text = "anchor apple generic and certificate leaf[subject.OU] = \"\(teamIdentifier)\""
        guard SecRequirementCreateWithString(text as CFString, [], &requirement) == errSecSuccess, let requirement else { return false }
        return SecStaticCodeCheckValidity(code, SecCSFlags(rawValue: kSecCSCheckAllArchitectures), requirement) == errSecSuccess
    }
}
