import Foundation
import Security
import CryptoKit
import GDCPluginManagerCore

/// Inventarul TUTUROR secretelor de care depinde ecosistemul GDC Plugin
/// Manager, cu starea lor citită din surse reale.
///
/// DE CE EXISTĂ: până acum singurul secret urmărit era PAT-ul GitHub
/// (`GitHubTokenStatus`), deși de el depind încă șase: dacă oricare expiră
/// fără avertisment, se rupe ceva ce nu se repară în cinci minute (clienții
/// nu mai descarcă, nu mai poți semna un build, nu mai poți genera licențe).
///
/// PRINCIPIU, identic cu cel din `GitHubTokenStatus`: NICIO dată introdusă
/// manual. Fiecare expirare se citește din sursa care o știe cu adevărat —
/// headerul GitHub, `exp`-ul din JWT, certificatul din keychain. O dată
/// tastată de mână se desincronizează tăcut la prima rotire uitată, și
/// atunci dashboard-ul devine mai periculos decât lipsa lui: arată verde
/// exact când nu trebuie.
///
/// VALORILE SECRETELOR NU IES NICIODATĂ DIN ACEST FIȘIER. Se citesc doar
/// ca să li se calculeze expirarea sau amprenta SHA-256 (pentru comparația
/// între oglinzi); nu se afișează, nu se loghează, nu se copiază în clipboard.
enum SecretLocation {
    /// O constantă într-un fișier sursă din checkout-ul local.
    case sourceFile(path: String, pattern: String)
    /// O preferință a Furnizorului (ex. cheia YouTube Data API).
    case userDefaults(key: String)
    /// Un fișier de sine stătător pe disc (cheia privată de licențiere).
    case diskFile(URL)
    /// Un certificat din keychain-ul de login.
    case keychainCertificate(commonName: String)
    /// Un secret de GitHub Actions — valoarea nu e citibilă nici de tine,
    /// doar data ultimei actualizări.
    case githubActionsSecret(repo: String, name: String)

    /// Locațiile din care se poate CITI efectiv o valoare de comparat.
    /// Un certificat nu are o „valoare" (prezența lui o stabilește sondarea
    /// din keychain), iar un secret de CI nu e citibil prin API by design.
    ///
    /// BUG REAL (2026-09-14, raportat imediat după prima versiune: ambele
    /// certificate Developer ID apăreau ROȘII, „Lipsește"): verificarea de
    /// prezență din `probe` trata orice `readValue == nil` ca secret lipsă
    /// și ieșea din funcție ÎNAINTE să apuce să citească expirarea din
    /// keychain. Certificatele erau la locul lor, valabile până în 2031.
    /// Excepția era scrisă doar pentru secretele de CI — un `if case`
    /// punctual, ușor de uitat la adăugarea unui tip nou de locație. Acum
    /// regula stă pe locația însăși, deci orice tip viitor trebuie să
    /// declare explicit dacă are sau nu o valoare citibilă.
    var hasReadableValue: Bool {
        switch self {
        case .sourceFile, .userDefaults, .diskFile: return true
        case .keychainCertificate, .githubActionsSecret: return false
        }
    }

    /// Se poate scrie de aici valoarea nouă? Un certificat se instalează
    /// prin Xcode/Keychain Access, nu prin aplicație — wizardul trebuie să
    /// spună asta, nu să ofere un câmp care oricum ar eșua la salvare.
    var isWritableFromApp: Bool {
        switch self {
        case .sourceFile, .userDefaults, .diskFile, .githubActionsSecret: return true
        case .keychainCertificate: return false
        }
    }

    var humanDescription: String {
        switch self {
        case .sourceFile(let path, _): return path
        case .userDefaults(let key): return "Preferințe Furnizor → \(key)"
        case .diskFile(let url): return url.path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
        case .keychainCertificate(let name): return "Keychain → \(name)"
        case .githubActionsSecret(let repo, let name): return "GitHub Actions → \(repo) → \(name)"
        }
    }
}

/// De unde aflăm când expiră.
enum ExpirySource {
    /// Headerul `github-authentication-token-expiration`, citit live.
    case githubTokenHeader
    /// Câmpul `exp` din payload-ul unui JWT, decodat local (fără rețea).
    /// Cheile Supabase noi (`sb_secret_…`) NU sunt JWT — atunci cade pe
    /// „fără expirare", ceea ce e adevărul, nu o eroare.
    case jwtExp
    /// `Validity Not After` din certificat.
    case certificateValidity
    /// Nu expiră de la sine; contează doar să existe și să fie valid.
    case neverExpires
    /// Nu putem citi o expirare — doar data ultimei actualizări.
    case lastUpdatedOnly
}

/// Un alt loc care trebuie să conțină EXACT aceeași valoare. Sursa celei mai
/// scumpe clase de bug din acest proiect: tokenul rotit pe Mac, uitat în
/// fișierul Windows sau în secretul de CI — build-urile pică abia peste
/// săptămâni, iar cauza pare oriunde altundeva.
struct SecretMirror {
    let label: String
    let location: SecretLocation
}

struct ManagedSecret: Identifiable {
    let id: String
    let name: String
    /// La ce folosește, pe scurt.
    let purpose: String
    /// Ce se rupe CONCRET dacă expiră — text scris ca să poată fi citit sub
    /// presiune, nu ca să sune bine.
    let impact: String
    let location: SecretLocation
    let expiry: ExpirySource
    /// Pagina exactă de reînnoire (pasul 1 din wizard, Etapa 2).
    let renewURL: URL?
    /// Permisiunile exacte de bifat (pasul 2 din wizard, Etapa 2).
    let requiredScopes: [String]
    let mirrors: [SecretMirror]
    /// Un secret fără de care ecosistemul funcționează. Lipsa lui e o stare
    /// neutră, nu o alarmă: dacă un secret opțional necompletat ar apărea
    /// roșu, roșul ar înceta să mai însemne „oprește-te și rezolvă acum".
    let isOptional: Bool
    /// Cum se verifică o valoare nouă înainte de a fi scrisă — vezi
    /// `SecretValidator`.
    let validation: ValidationKind
    /// Ce mai trebuie făcut DUPĂ înlocuire ca schimbarea să ajungă la cine
    /// trebuie. Pentru PAT: un simplu „am pus tokenul nou" nu e suficient —
    /// clienții deja instalați îl folosesc pe cel vechi până la un release.
    let afterRenewal: [String]

    init(id: String, name: String, purpose: String, impact: String,
         location: SecretLocation, expiry: ExpirySource, renewURL: String? = nil,
         requiredScopes: [String] = [], mirrors: [SecretMirror] = [],
         isOptional: Bool = false, validation: ValidationKind = .none,
         afterRenewal: [String] = []) {
        self.id = id
        self.name = name
        self.purpose = purpose
        self.impact = impact
        self.location = location
        self.expiry = expiry
        self.renewURL = renewURL.flatMap(URL.init(string:))
        self.requiredScopes = requiredScopes
        self.mirrors = mirrors
        self.isOptional = isOptional
        self.validation = validation
        self.afterRenewal = afterRenewal
    }
}

// MARK: - Starea calculată

struct SecretStatus {
    enum Severity: Int, Comparable {
        case optionalUnset, ok, warning, critical, missing, unknown
        static func < (a: Severity, b: Severity) -> Bool { a.rawValue < b.rawValue }
    }

    var severity: Severity = .unknown
    var expiresAt: Date?
    var lastUpdated: Date?
    /// O linie scurtă, cea afișată în tabel („expiră în 337 zile").
    var headline: String = "Se verifică…"
    /// Explicație suplimentară, afișată în detaliu.
    var detail: String?
    /// Rezultatul comparației cu oglinzile: nil = nu are oglinzi.
    var mirrorReport: [MirrorCheck] = []

    struct MirrorCheck: Identifiable {
        var id: String { label }
        let label: String
        let inSync: Bool?      // nil = nu s-a putut verifica
        let note: String
    }

    var daysRemaining: Int? {
        guard let expiresAt else { return nil }
        return Int((expiresAt.timeIntervalSinceNow / 86400).rounded(.down))
    }

    /// Aceleași praguri cerute pentru PAT și păstrate pentru tot restul:
    /// liniște până la 30 de zile, avertisment până la 14, roșu sub.
    static func severity(forDaysRemaining days: Int) -> Severity {
        if days < 0 { return .critical }
        if days <= 14 { return .critical }
        if days <= 30 { return .warning }
        return .ok
    }
}

// MARK: - Inventarul

extension SecretRegistry {
    /// Ordinea contează: primele sunt cele a căror expirare oprește complet
    /// clienții, ultimele cele care degradează doar funcții interne.
    static func allSecrets() -> [ManagedSecret] {
        let winRepo = "gordasgdc/gdc-plugin-manager-win"
        return [
            ManagedSecret(
                id: "github-pat",
                name: "PAT GitHub (catalog privat)",
                purpose: "Singura cale prin care clientul descarcă fișierele produselor din cele 4 repo-uri private.",
                impact: "Toți clienții instalați primesc eroare de autentificare la orice descărcare. Nu se repară din catalog — cere build + release nou pe Mac ȘI pe Windows.",
                location: .sourceFile(path: "Sources/GDCPluginManagerCore/PrivateCatalogAuth.swift",
                                      pattern: #"public static let token = "([^"]+)""#),
                expiry: .githubTokenHeader,
                renewURL: "https://github.com/settings/personal-access-tokens",
                requiredScopes: [
                    "Resource owner: gordasgdc",
                    "Repository access: Only select repositories → gdc-plugin-manager-files, -pdfs, -scripts, -resources",
                    "Repository permissions → Contents: Read-only",
                    "Nimic altceva bifat",
                ],
                mirrors: [
                    SecretMirror(label: "Sursa Windows",
                                 location: .sourceFile(path: "../GDCPluginManagerWin/src/GDCPluginManager.Core/Services/PrivateCatalogAuth.cs",
                                                       pattern: #"public const string Token = "([^"]+)""#)),
                    SecretMirror(label: "Secret CI Windows",
                                 location: .githubActionsSecret(repo: winRepo, name: "PRIVATE_CATALOG_TOKEN")),
                ],
                validation: .githubPAT(repos: ["gdc-plugin-manager-files", "gdc-plugin-manager-pdfs",
                                               "gdc-plugin-manager-scripts", "gdc-plugin-manager-resources"]),
                afterRenewal: [
                    "./build_app.sh && ./build_furnizor_app.sh (Regula 0 — se verifică versiunea INSTALATĂ)",
                    "Bump versiune Client + CHANGELOG, commit, push",
                    "Release nou Mac + Windows, altfel clienții rămân pe tokenul vechi",
                    "Abia DUPĂ ce un client actualizat descarcă cu succes: revocă tokenul vechi",
                ]
            ),
            ManagedSecret(
                id: "vendor-private-key",
                name: "Cheie privată de licențiere (Ed25519)",
                purpose: "Semnează fiecare serial generat. Perechea publică e compilată în toate aplicațiile GDC.",
                impact: "Nu mai poți genera NICIO licență pentru niciun client. Dacă se pierde fără backup, toate licențele viitoare cer schimbarea cheii publice în fiecare aplicație — adică un release pentru tot ecosistemul.",
                location: .diskFile(FileManager.default.homeDirectoryForCurrentUser
                    .appendingPathComponent("Library/Application Support/GDC License Manager/private_key.txt")),
                expiry: .neverExpires,
                afterRenewal: [
                    "Nu se „reînnoiește” — se protejează. Verifică periodic că e inclusă în backup (Backup & Restaurare).",
                ]
            ),
            ManagedSecret(
                id: "developer-id-app",
                name: "Certificat Developer ID Application",
                purpose: "Semnează aplicațiile .app înainte de notarizare.",
                impact: "Nu mai poți semna sau notariza niciun build Mac. macOS refuză să deschidă build-uri nesemnate la utilizatori.",
                location: .keychainCertificate(commonName: "Developer ID Application: DUMITRU CRISTINEL GORDAS"),
                expiry: .certificateValidity,
                renewURL: "https://developer.apple.com/account/resources/certificates/list",
                requiredScopes: ["Tip: Developer ID Application", "Se generează din Xcode → Settings → Accounts → Manage Certificates"]
            ),
            ManagedSecret(
                id: "developer-id-installer",
                name: "Certificat Developer ID Installer",
                purpose: "Semnează pachetele .pkg (Client și Furnizor).",
                impact: "Nu mai poți produce un .pkg instalabil fără avertisment Gatekeeper.",
                location: .keychainCertificate(commonName: "Developer ID Installer: DUMITRU CRISTINEL GORDAS"),
                expiry: .certificateValidity,
                renewURL: "https://developer.apple.com/account/resources/certificates/list",
                requiredScopes: ["Tip: Developer ID Installer"]
            ),
            ManagedSecret(
                id: "supabase-service-role",
                name: "Cheie Supabase service_role",
                purpose: "Citire completă a bazei (Clienți, Statistici, Revocări) din Furnizor. Ocolește Row Level Security.",
                impact: "Secțiunile Clienți, Statistici și Revocări din Furnizor rămân goale. Clienții nu sunt afectați.",
                location: .sourceFile(path: "Sources/GDCPluginManagerFurnizor/SupabaseAdminConfig.swift",
                                      pattern: #"static let serviceRoleKey = "([^"]+)""#),
                expiry: .jwtExp,
                renewURL: "https://supabase.com/dashboard/project/jvxrclpyngdcqnbwvtfn/settings/api-keys",
                requiredScopes: ["Secret key / service_role — NU publishable/anon"],
                validation: .supabaseKey(table: "devices"),
                afterRenewal: ["Rebuild Furnizor (./build_furnizor_app.sh). Nu afectează clienții — cheia nu e în Client."]
            ),
            ManagedSecret(
                id: "release-pat",
                name: "PAT de release Windows (CI)",
                purpose: "Permite workflow-ului de CI Windows să creeze release-uri.",
                impact: "Build-urile Windows trec, dar publicarea release-ului pică la final.",
                location: .githubActionsSecret(repo: winRepo, name: "RELEASE_PAT"),
                expiry: .lastUpdatedOnly,
                renewURL: "https://github.com/settings/personal-access-tokens",
                requiredScopes: ["Contents: Read and write pe gdc-plugin-manager-win"]
            ),
            ManagedSecret(
                id: "supabase-anon",
                name: "Cheie Supabase anon (Client)",
                purpose: "Telemetrie din aplicația client. Limitată de RLS la INSERT.",
                impact: "Se oprește doar colectarea de statistici. Nimic vizibil pentru clienți.",
                location: .sourceFile(path: "Sources/GDCPluginManagerCore/SupabaseConfig.swift",
                                      pattern: #"public static let anonKey = "([^"]+)""#),
                expiry: .jwtExp,
                renewURL: "https://supabase.com/dashboard/project/jvxrclpyngdcqnbwvtfn/settings/api-keys"
            ),
            ManagedSecret(
                id: "youtube-api",
                name: "Cheie YouTube Data API",
                purpose: "Preia automat titlul și durata unui tutorial din link-ul YouTube.",
                impact: "Metadatele tutorialelor trebuie completate manual. Nimic altceva.",
                location: .userDefaults(key: "youtube_data_api_key"),
                expiry: .neverExpires,
                renewURL: "https://console.cloud.google.com/apis/credentials",
                requiredScopes: ["API key cu YouTube Data API v3 activat"],
                isOptional: true,
                validation: .youTubeAPIKey
            ),
        ]
    }
}

// MARK: - Motorul de verificare

@MainActor
final class SecretRegistry: ObservableObject {
    static let shared = SecretRegistry()

    let secrets: [ManagedSecret] = SecretRegistry.allSecrets()

    @Published private(set) var statuses: [String: SecretStatus] = [:]
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastRefresh: Date?

    private init() {}

    func status(for secret: ManagedSecret) -> SecretStatus {
        statuses[secret.id] ?? SecretStatus()
    }

    /// Cea mai gravă stare din tot inventarul — ce afișează insigna din bara
    /// de unelte, ca să nu fie nevoie să deschizi dashboard-ul ca să afli că
    /// ceva e roșu.
    var worstSeverity: SecretStatus.Severity {
        let relevant = statuses.values.map(\.severity).filter { $0 != .unknown && $0 != .optionalUnset }
        return relevant.max() ?? .unknown
    }

    func refreshAll() async {
        isRefreshing = true
        for secret in secrets {
            let status = await probe(secret)
            statuses[secret.id] = status
        }
        lastRefresh = Date()
        isRefreshing = false
    }

    // MARK: Sondarea unui singur secret

    private func probe(_ secret: ManagedSecret) async -> SecretStatus {
        var status = SecretStatus()

        // Pasul 1: există? Un secret lipsă nu are rost verificat mai departe,
        // iar starea „lipsește" e distinctă de „expirat" — cauza și reparația
        // sunt complet diferite.
        let value = Self.readValue(at: secret.location)
        if secret.location.hasReadableValue,
           value == nil || value!.isEmpty || Self.isPlaceholder(value!) {
            status.severity = secret.isOptional ? .optionalUnset : .missing
            status.headline = secret.isOptional
                ? "Neconfigurat (opțional)"
                : (value == nil ? "Lipsește" : "Necompletat (șablon)")
            status.detail = "Nu am găsit o valoare reală la \(secret.location.humanDescription)."
            return status
        }

        // Pasul 2: expirarea, din sursa care o știe cu adevărat.
        switch secret.expiry {
        case .githubTokenHeader:
            if let date = await Self.githubTokenExpiry(token: value ?? "") {
                status.expiresAt = date
            } else {
                status.severity = .unknown
                status.headline = "Nu am putut verifica"
                status.detail = "GitHub nu a răspuns sau tokenul nu mai e valid. Verifică conexiunea, apoi reîncearcă."
            }

        case .jwtExp:
            if let date = Self.jwtExpiry(value ?? "") {
                status.expiresAt = date
            } else {
                // Cheile Supabase în format nou (`sb_secret_…`) nu sunt JWT
                // și nu expiră — asta NU e o eroare de citire.
                status.severity = .ok
                status.headline = "Fără expirare"
                status.detail = "Cheia nu e în format JWT (formatul nou Supabase), deci nu are dată de expirare. Rămâne valabilă până o revoci manual."
            }

        case .certificateValidity:
            if case .keychainCertificate(let name) = secret.location, let date = Self.certificateExpiry(commonName: name) {
                status.expiresAt = date
            } else {
                status.severity = .missing
                status.headline = "Negăsit în keychain"
                status.detail = "Certificatul nu e instalat pe acest Mac. Fără el nu se poate semna niciun build."
            }

        case .neverExpires:
            status.severity = .ok
            status.headline = "Prezent — nu expiră"

        case .lastUpdatedOnly:
            if case .githubActionsSecret(let repo, let name) = secret.location,
               let updated = await Self.githubSecretUpdatedAt(repo: repo, name: name) {
                status.lastUpdated = updated
                status.severity = .ok
                status.headline = "Actualizat \(Self.relative(updated))"
                status.detail = "GitHub nu expune expirarea unui secret de Actions — se poate afișa doar când a fost pus ultima dată."
            } else {
                status.severity = .unknown
                status.headline = "Nu am putut verifica"
                status.detail = "Necesită `gh` autentificat pe acest Mac (gh auth status)."
            }
        }

        // Pasul 3: severitatea din zilele rămase, dacă avem o expirare reală.
        if let days = status.daysRemaining {
            status.severity = SecretStatus.severity(forDaysRemaining: days)
            status.headline = days < 0 ? "EXPIRAT de \(-days) zile" : "Expiră în \(days) zile"
            if let expiresAt = status.expiresAt {
                status.detail = "Data exactă: \(expiresAt.formatted(date: .long, time: .omitted))"
            }
        }

        // Pasul 4: oglinzile. Aceeași valoare trebuie să fie în toate
        // locurile declarate; altfel un build merge și altul nu, iar cauza
        // e invizibilă din oricare dintre ele.
        if let value, !secret.mirrors.isEmpty {
            status.mirrorReport = await Self.checkMirrors(secret.mirrors, against: value, referenceExpiry: status.expiresAt)
            // O oglindă desincronizată nu poate lăsa starea verde: e exact
            // tipul de defect care se descoperă altfel abia la un release.
            if status.mirrorReport.contains(where: { $0.inSync == false }), status.severity == .ok {
                status.severity = .warning
            }
        }

        return status
    }
}

// MARK: - Citirea valorilor (nu ies niciodată din acest fișier)

extension SecretRegistry {

    /// Rădăcina checkout-ului de surse. Căile din inventar sunt relative la
    /// ea, inclusiv cea cu `../` spre repo-ul Windows — o singură sursă de
    /// adevăr pentru unde stă codul pe acest Mac.
    private static var sourceRoot: URL { RepoCheckoutPaths.publicCatalogRepo }

    static func readValue(at location: SecretLocation) -> String? {
        switch location {
        case .sourceFile(let path, let pattern):
            let url = URL(fileURLWithPath: path, relativeTo: sourceRoot).standardizedFileURL
            guard let text = try? String(contentsOf: url, encoding: .utf8),
                  let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
                  match.numberOfRanges > 1,
                  let range = Range(match.range(at: 1), in: text) else { return nil }
            return String(text[range])

        case .userDefaults(let key):
            return UserDefaults.standard.string(forKey: key)

        case .diskFile(let url):
            return (try? String(contentsOf: url, encoding: .utf8))?
                .trimmingCharacters(in: .whitespacesAndNewlines)

        case .keychainCertificate, .githubActionsSecret:
            // Certificatul nu are o „valoare" de comparat, iar secretul de CI
            // nu e citibil prin API.
            return nil
        }
    }

    /// Șabloanele necompletate arată ca o valoare, dar nu sunt una. Fără
    /// verificarea asta, un `PASTE_…_HERE` ar apărea verde în dashboard.
    static func isPlaceholder(_ value: String) -> Bool {
        value.hasPrefix("PASTE_") || value.contains("_HERE")
    }

    /// Amprentă scurtă, folosită DOAR ca să comparăm două locuri fără să
    /// atingem valorile. SHA-256 e ireversibil: amprenta nu spune nimic
    /// despre token, dar două token-uri diferite nu pot avea aceeași amprentă.
    static func fingerprint(_ value: String) -> String {
        let digest = SHA256.hash(data: Data(value.utf8))
        return digest.compactMap { String(format: "%02x", $0) }.joined().prefix(12).description
    }

    // MARK: Expirări

    /// Exact mecanismul confirmat live în `GitHubTokenStatus`: orice răspuns
    /// autentificat cu un PAT fine-grained poartă headerul de expirare.
    static func githubTokenExpiry(token: String) async -> Date? {
        guard !token.isEmpty else { return nil }
        var request = URLRequest(url: URL(string: "https://api.github.com/repos/\(PrivateCatalogAuth.owner)/\(PrivateCatalogAuth.repo)")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        guard let (_, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              let raw = http.value(forHTTPHeaderField: "github-authentication-token-expiration") else { return nil }
        return parseGitHubExpiration(raw)
    }

    /// GitHub trimite "2027-08-16 22:00:00 UTC" — nu ISO-8601, deci are nevoie
    /// de formatterul lui. Extras ca să-l folosească și validarea din wizard,
    /// care citește același header cu tokenul NOU, înainte de a-l salva.
    nonisolated static func parseGitHubExpiration(_ raw: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss 'UTC'"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.date(from: raw)
    }

    /// `exp` din payload-ul unui JWT. Local, fără rețea — deci funcționează
    /// și când n-ai internet, exact când ai mai mare nevoie de dashboard.
    nonisolated static func jwtExpiry(_ token: String) -> Date? {
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { return nil }
        var payload = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        payload += String(repeating: "=", count: (4 - payload.count % 4) % 4)
        guard let data = Data(base64Encoded: payload),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let exp = json["exp"] as? Double else { return nil }
        return Date(timeIntervalSince1970: exp)
    }

    /// `Validity Not After` citit prin Security framework, nu prin shell.
    /// Se atinge doar partea publică a identității, deci macOS nu cere parola
    /// keychain-ului.
    static func certificateExpiry(commonName: String) -> Date? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassIdentity,
            kSecReturnRef as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll,
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let identities = result as? [SecIdentity] else { return nil }

        var newest: Date?
        for identity in identities {
            var certRef: SecCertificate?
            guard SecIdentityCopyCertificate(identity, &certRef) == errSecSuccess,
                  let cert = certRef,
                  let summary = SecCertificateCopySubjectSummary(cert) as String?,
                  summary.hasPrefix(commonName) else { continue }

            let keys = [kSecOIDX509V1ValidityNotAfter] as CFArray
            guard let values = SecCertificateCopyValues(cert, keys, nil) as? [String: Any],
                  let entry = values[kSecOIDX509V1ValidityNotAfter as String] as? [String: Any],
                  let seconds = entry[kSecPropertyKeyValue as String] as? Double else { continue }

            // Valoarea e în „absolute time" (secunde de la 2001-01-01), nu
            // epoch Unix — o confuzie care ar da un an greșit cu 31 de ani.
            let date = Date(timeIntervalSinceReferenceDate: seconds)
            // Dacă există mai multe certificate cu același nume (reînnoire
            // făcută fără ștergerea celui vechi), contează cel care ține cel
            // mai mult: pe acela îl va alege și codesign.
            if newest == nil || date > newest! { newest = date }
        }
        return newest
    }

    /// Data ultimei actualizări a unui secret de GitHub Actions, prin `gh`.
    /// Folosim `gh`, nu PAT-ul încorporat: acela e Contents:Read-only pe
    /// repo-urile de resurse și nu are cum să citească secrete de CI.
    static func githubSecretUpdatedAt(repo: String, name: String) async -> Date? {
        guard let output = try? await runGH(["api", "/repos/\(repo)/actions/secrets/\(name)", "--jq", ".updated_at"]),
              let raw = output.split(separator: "\n").first.map(String.init) else { return nil }
        return ISO8601DateFormatter().date(from: raw.trimmingCharacters(in: .whitespaces))
    }

    /// `gh` nu e în PATH-ul unei aplicații pornite din Finder (aplicațiile
    /// GUI nu moștenesc mediul shell-ului), deci îl căutăm explicit.
    private static func ghExecutable() -> URL? {
        for path in ["/opt/homebrew/bin/gh", "/usr/local/bin/gh", "/usr/bin/gh"] where FileManager.default.isExecutableFile(atPath: path) {
            return URL(fileURLWithPath: path)
        }
        return nil
    }

    private static func runGH(_ args: [String]) async throws -> String? {
        guard let gh = ghExecutable() else { return nil }
        return try await Task.detached {
            let process = Process()
            process.executableURL = gh
            process.arguments = args
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

    // MARK: Oglinzi

    static func checkMirrors(_ mirrors: [SecretMirror], against value: String, referenceExpiry: Date?) async -> [SecretStatus.MirrorCheck] {
        let reference = fingerprint(value)
        var checks: [SecretStatus.MirrorCheck] = []

        for mirror in mirrors {
            switch mirror.location {
            case .githubActionsSecret(let repo, let name):
                // Valoarea nu e citibilă — dar se poate deduce ceva sigur:
                // un PAT fine-grained trăiește cel mult un an, deci nu poate
                // fi fost creat înainte de (expirare − 1 an). Dacă secretul
                // de CI a fost pus înainte de acel moment, conține cu
                // certitudine ALT token, nu pe cel curent. Deducția e
                // unilaterală: „mai nou" nu dovedește că e identic.
                let updated = await githubSecretUpdatedAt(repo: repo, name: name)
                guard let updated else {
                    checks.append(.init(label: mirror.label, inSync: nil,
                                        note: "Nu am putut citi (necesită `gh` autentificat)."))
                    continue
                }
                if let referenceExpiry, let earliestCreation = Calendar.current.date(byAdding: .year, value: -1, to: referenceExpiry),
                   updated < earliestCreation {
                    checks.append(.init(label: mirror.label, inSync: false,
                                        note: "Pus la \(updated.formatted(date: .abbreviated, time: .omitted)) — înainte ca tokenul curent să poată fi existat. Conține sigur o valoare veche."))
                } else {
                    checks.append(.init(label: mirror.label, inSync: nil,
                                        note: "Actualizat \(relative(updated)). Valoarea nu e citibilă prin API — plauzibil la zi, nu demonstrabil."))
                }

            default:
                guard let other = readValue(at: mirror.location) else {
                    checks.append(.init(label: mirror.label, inSync: nil,
                                        note: "Nu am găsit fișierul (\(mirror.location.humanDescription))."))
                    continue
                }
                let same = fingerprint(other) == reference
                checks.append(.init(label: mirror.label, inSync: same,
                                    note: same ? "Identic cu valoarea de pe Mac."
                                               : "DIFERIT de valoarea de pe Mac — build-urile de acolo folosesc alt token."))
            }
        }
        return checks
    }

    static func relative(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "ro_RO")
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
