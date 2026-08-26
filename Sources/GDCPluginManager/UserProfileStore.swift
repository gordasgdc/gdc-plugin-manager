import Foundation
import GDCPluginManagerCore

/// Profilul opțional al utilizatorului (Nume/Email) — cerut explicit
/// (CLAUDE.md, Partea 1, Regula 12): "Profil Utilizator, HWID & Telemetrie
/// Opțională (Mac & Windows)". Numele/emailul erau deja trimise o dată la
/// onboarding către Supabase (AnalyticsClient.registerDevice), dar NU
/// erau persistate local — deci nu puteau fi afișate în sidebar după
/// prima pornire. Acest store le păstrează local (UserDefaults, simplu
/// text, nimic sensibil) și le face editabile oricând.
final class UserProfileStore: ObservableObject {
    static let shared = UserProfileStore()

    @Published var name: String {
        didSet { UserDefaults.standard.set(name, forKey: Self.nameKey) }
    }
    @Published var email: String {
        didSet { UserDefaults.standard.set(email, forKey: Self.emailKey) }
    }

    let machineID = MachineID.display

    private static let nameKey = "gdcpm_profile_name"
    private static let emailKey = "gdcpm_profile_email"

    private init() {
        name = UserDefaults.standard.string(forKey: Self.nameKey) ?? ""
        email = UserDefaults.standard.string(forKey: Self.emailKey) ?? ""
    }

    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? L.t("profile.anonymous") : trimmed
    }

    /// Salvează local ȘI trimite (fire-and-forget, opțional) către
    /// Supabase — apelată din OnboardingView și din editarea manuală din
    /// sidebar. Telemetria rămâne strict opțională: dacă numele e gol,
    /// nu se trimite nimic (la fel ca înainte, în OnboardingView).
    func save(name: String, email: String, sendTelemetry: Bool) {
        self.name = name
        self.email = email
        if sendTelemetry, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            AnalyticsClient.registerDevice(name: name, email: email)
        }
    }
}
