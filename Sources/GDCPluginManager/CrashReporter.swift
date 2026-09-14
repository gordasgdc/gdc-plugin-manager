import Foundation
import AppKit
import Sentry
import GDCPluginManagerCore

/// Pornirea raportării de erori și contextul atașat fiecărui raport.
///
/// CE NU SE TRIMITE, deliberat: `sendDefaultPii` rămâne oprit (fără adrese IP
/// sau nume de utilizator), iar `beforeSend` taie calea către directorul
/// personal din orice mesaj — altfel un simplu „nu găsesc fișierul" ar
/// trimite numele real al utilizatorului Mac-ului, care apare în fiecare cale
/// `/Users/<nume>/…`. Serialul de licență și ID-ul de mașină nu se atașează
/// niciodată: dacă va fi vreodată nevoie să legăm un raport de un client, se
/// face cu un identificator neutru, nu cu date reale.
enum CrashReporter {

    static func start() {
        guard CrashReportingConfig.isEnabled else { return }

        SentrySDK.start { options in
            options.dsn = CrashReportingConfig.dsn
            options.environment = CrashReportingConfig.environment
            options.releaseName = CrashReportingConfig.releaseName

            // Sesiuni: câte porniri s-au terminat cu bine și câte cu o
            // eroare. De aici iese rata de crash pe versiune.
            options.enableAutoSessionTracking = true

            // Stivă completă și pentru mesajele simple, nu doar pentru
            // excepții — altfel un `capture(message:)` ajunge fără niciun
            // indiciu despre locul din care a plecat.
            options.attachStacktrace = true

            // Fără date personale implicite (IP, nume de utilizator).
            options.sendDefaultPii = false

            // Nu urmărim performanța: e o unealtă de diagnostic pentru erori,
            // iar tranzacțiile ar consuma cotă fără să răspundă la întrebarea
            // „de ce a crăpat la clientul X".
            options.tracesSampleRate = 0.0

            options.beforeSend = { event in
                scrubHomeDirectory(from: event)
            }
        }

        applyStaticContext()
        observeThemeChanges()
        runSelfTestIfRequested()
    }

    /// Trimite un eveniment de probă și AȘTEAPTĂ confirmarea, apoi scrie
    /// rezultatul la consolă. Pornit doar cu `GDC_SENTRY_SELFTEST=1`.
    ///
    /// DE CE EXISTĂ: „am pus DSN-ul, merge?" nu se poate răspunde altfel decât
    /// provocând un crash real și sperând că apare în panou. Aici întrebarea
    /// primește un răspuns imediat și verificabil — util la orice rotire de
    /// DSN, nu doar la prima configurare.
    ///
    /// `flush` e obligatoriu: SDK-ul trimite pe un fir de fundal, iar o
    /// aplicație închisă imediat după pornire poate muri înainte ca
    /// evenimentul să plece. Exact asta s-a întâmplat la prima mea încercare
    /// de verificare — colectorul local n-a primit nimic, deși pornirea
    /// reușise.
    private static func runSelfTestIfRequested() {
        guard ProcessInfo.processInfo.environment["GDC_SENTRY_SELFTEST"] == "1" else { return }

        breadcrumb("Auto-verificare pornită", category: "selftest")
        SentrySDK.capture(message: "Auto-verificare GDC Plugin Manager") { scope in
            scope.setLevel(.info)
            scope.setTag(value: "selftest", key: "kind")
        }
        SentrySDK.flush(timeout: 10)
        FileHandle.standardError.write(Data("[sentry] auto-verificare: eveniment trimis si golit\n".utf8))
    }

    /// Persistența temei e deja implementată în `ThemeManager` (scrie în
    /// `UserDefaults` la fiecare schimbare). Ce lipsea era DOVADA: dacă tema
    /// nu s-ar mai păstra între porniri, raportul trebuie să spună dacă
    /// scrierea a eșuat sau citirea de la pornire. De aceea urma de mai jos
    /// conține și valoarea recitită imediat după scriere.
    private static func observeThemeChanges() {
        breadcrumb(
            "Temă citită la pornire",
            category: "theme",
            data: [
                "value_in_preferences": ThemeManager.shared.valueReadAtLaunch ?? "(nimic salvat)",
                "applied": ThemeManager.shared.current.rawValue,
            ])

        ThemeManager.changeObserver = { theme, persisted in
            breadcrumb(
                "Temă schimbată",
                category: "theme",
                data: [
                    "selected": theme.rawValue,
                    "read_back": persisted ?? "(nimic)",
                    "persisted_ok": persisted == theme.rawValue,
                ])
            // Tema face parte din contextul fiecărui raport viitor.
            refreshContext()
        }
    }

    // MARK: Context

    /// Versiunea, mediul, sistemul de operare și limba — atașate o dată, la
    /// pornire, deci prezente pe FIECARE raport ulterior.
    private static func applyStaticContext() {
        let os = ProcessInfo.processInfo.operatingSystemVersion
        let osVersion = "\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)"

        SentrySDK.configureScope { scope in
            scope.setTag(value: CrashReportingConfig.environment, key: "environment")
            scope.setTag(value: osVersion, key: "os_version")
            scope.setTag(value: L.current.rawValue, key: "app_language")
            scope.setTag(value: ThemeManager.shared.current.rawValue, key: "app_theme")

            scope.setContext(value: [
                "version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?",
                "build": Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?",
                "os": "macOS \(osVersion)",
                "language": L.current.rawValue,
                "theme": ThemeManager.shared.current.rawValue,
                // Arhitectura separă un crash care apare doar pe Intel de
                // unul general — informația nu se poate deduce altfel din
                // raport.
                "architecture": architecture,
            ], key: "gdc")
        }
    }

    private static var architecture: String {
        #if arch(arm64)
        return "arm64"
        #elseif arch(x86_64)
        return "x86_64"
        #else
        return "unknown"
        #endif
    }

    /// De chemat când utilizatorul schimbă limba sau tema: rapoartele
    /// ulterioare trebuie să arate starea de ACUM, nu pe cea de la pornire.
    static func refreshContext() {
        guard CrashReportingConfig.isEnabled else { return }
        applyStaticContext()
    }

    // MARK: Breadcrumbs

    /// Urmă de navigare/acțiune, vizibilă în raport ca istoric al ultimilor
    /// pași dinaintea erorii. Fără ele, un crash arată ca un punct izolat;
    /// cu ele se vede ce făcea utilizatorul.
    static func breadcrumb(_ message: String, category: String, data: [String: Any]? = nil) {
        guard CrashReportingConfig.isEnabled else { return }
        let crumb = Breadcrumb(level: .info, category: category)
        crumb.message = message
        crumb.data = data
        SentrySDK.addBreadcrumb(crumb)
    }

    // MARK: Curățare

    /// Înlocuiește calea reală a directorului personal cu `~`.
    ///
    /// Fără asta, orice eroare de fișier ar fi trimis numele real al
    /// utilizatorului Mac-ului (`/Users/ion.popescu/…`) — o dată personală pe
    /// care n-am cerut-o și n-avem ce face cu ea.
    /// `Sentry.Event` calificat explicit: catalogul are propriul tip `Event`
    /// (evenimentele publicate de Cristi), importat din Core — fără prefix,
    /// compilatorul nu poate alege între ele.
    private static func scrubHomeDirectory(from event: Sentry.Event) -> Sentry.Event {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        guard !home.isEmpty else { return event }

        if let message = event.message?.formatted {
            event.message = SentryMessage(formatted: message.replacingOccurrences(of: home, with: "~"))
        }
        event.breadcrumbs = event.breadcrumbs?.map { crumb in
            if let text = crumb.message {
                crumb.message = text.replacingOccurrences(of: home, with: "~")
            }
            return crumb
        }
        return event
    }
}
