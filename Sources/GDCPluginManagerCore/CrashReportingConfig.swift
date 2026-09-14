import Foundation

/// Unde se trimit rapoartele de erori și în ce mediu rulează aplicația.
///
/// DSN-ul e o adresă de INTRARE, nu o cheie de acces: permite doar TRIMITEREA
/// de evenimente către proiect, nu citirea a nimic. Sentry îl documentează
/// explicit ca fiind sigur de inclus în aplicații distribuite — oricum ajunge
/// în binar la orice client, deci ascunderea lui în `.gitignore` n-ar aduce
/// nimic (spre deosebire de tokenul din `PrivateCatalogAuth`, care dă acces
/// de citire la repo-uri private și de aceea NU e comis).
///
/// Singurul abuz posibil cu un DSN scurs e umplerea cotei cu evenimente
/// false. Dacă se întâmplă, se rotește din panoul Sentry (Settings → Client
/// Keys) și se publică o versiune nouă.
public enum CrashReportingConfig {

    /// Variabila de mediu are prioritate: un build de test poate trimite în
    /// alt proiect fără nicio modificare de cod.
    private static let environmentOverrideKey = "GDC_SENTRY_DSN"

    /// PUNE AICI DSN-ul din Sentry → Settings → Projects → Client Keys (DSN).
    /// Gol = raportarea e OPRITĂ complet (vezi `isEnabled`).
    private static let compiledDSN = "https://1df3dfe13c935d9ac9f2ef9763305de2@o4512086216933376.ingest.de.sentry.io/4512086226305104"

    public static var dsn: String {
        let fromEnvironment = ProcessInfo.processInfo.environment[environmentOverrideKey]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let fromEnvironment, !fromEnvironment.isEmpty { return fromEnvironment }
        return compiledDSN.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Fără DSN nu se pornește NIMIC.
    ///
    /// Deliberat, nu o eroare: un DSN necompletat e starea normală până când
    /// proiectul Sentry e creat, iar o aplicație care crapă la pornire pentru
    /// că lipsește configurarea unei unelte de diagnostic ar fi exact opusul
    /// scopului. Aici, lipsa lui înseamnă doar că nu se trimite nimic.
    public static var isEnabled: Bool { !dsn.isEmpty }

    /// Mediu: „production" pentru build-urile distribuite, „development"
    /// pentru cele rulate din linia de comandă.
    ///
    /// Distincția se face după semnătură, nu după un `#if DEBUG`: build-urile
    /// se fac cu ACELAȘI script (`build_app.sh`) și în dezvoltare, și pentru
    /// release, deci flagul de compilare ar fi fost identic în ambele cazuri
    /// și n-ar fi separat nimic.
    public static var environment: String {
        Bundle.main.bundleIdentifier == nil ? "development" : "production"
    }

    public static var releaseName: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
        return "gdc-plugin-manager@\(version)"
    }
}
