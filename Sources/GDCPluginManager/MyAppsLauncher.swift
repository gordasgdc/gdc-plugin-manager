import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Etapa 3 din Planul Integrat de Upgrade v2.0 (2026-08-29) — "Aplicațiile
/// Mele": lansator rapid pentru aplicațiile GDC deja instalate pe acest
/// Mac, plus scurtături personalizate către alte aplicații (DaVinci
/// Resolve, Premiere, etc.).
///
/// Detectarea "deținerii" unei aplicații GDC NU se face prin licență
/// (GDCPluginManager n-are acces la fișierele de activare ale altor
/// aplicații, fiecare își ține licența separat local) — se face prin
/// PREZENȚA aplicației instalate pe disc (`NSWorkspace`, după bundle ID).
/// E o aproximare corectă în practică: dacă cineva a instalat DataMover,
/// aproape sigur l-a și cumpărat/activat.
///
/// Sursa versiunii publicate diferă per aplicație (fiecare GDC app își
/// alege propriul mecanism de update — vezi CLAUDE.md Regula 13/20):
/// majoritatea citesc direct GitHub Releases API, MediaFlow Monitor are
/// propriul `update.json`. `VersionSource` acoperă ambele, fără să
/// presupună un format comun.
enum VersionSource {
    case githubReleases(repo: String)
    case updateJSON(url: URL)
}

struct MyAppEntry: Identifiable {
    let id: String
    let name: String
    let bundleIdentifier: String
    let iconSymbol: String
    let tint: Color
    let versionSource: VersionSource
}

/// Cele 4 aplicații GDC cu bundle .app real, lansabil direct pe Mac.
/// `gdc-production-manager` (script Python, `run-mac.command`) și
/// `gdc-resolve-encoder` (bibliotecă C++, folosită DIN DaVinci Resolve,
/// niciodată lansată direct de user) NU au un bundle standard de
/// verificat/lansat — excluse intenționat, nu omise din neatenție.
let knownGDCApps: [MyAppEntry] = [
    MyAppEntry(id: "gdc-datamover", name: "DataMover", bundleIdentifier: "dev.gordas.datamover",
               iconSymbol: "externaldrive.connected.to.line.below", tint: .cyan,
               versionSource: .githubReleases(repo: "gordasgdc/datamover")),
    MyAppEntry(id: "cursorpro", name: "CursorPro GDC", bundleIdentifier: "com.gordasgdc.cursorpro",
               iconSymbol: "cursorarrow.rays", tint: .pink,
               versionSource: .githubReleases(repo: "gordasgdc/cursorpro-gdc")),
    MyAppEntry(id: "gdc-vault", name: "GDC Vault", bundleIdentifier: "com.gordasgdc.vault",
               iconSymbol: "lock.shield", tint: .green,
               versionSource: .githubReleases(repo: "gordasgdc/gdc-vault-mac")),
    MyAppEntry(id: "media-flow-monitor", name: "MediaFlow Monitor", bundleIdentifier: "com.gdc.mediaflowmonitor",
               iconSymbol: "waveform.path.ecg", tint: .orange,
               versionSource: .updateJSON(url: URL(string: "https://gordas.dev/media-flow-monitor/update.json")!)),
    MyAppEntry(id: "mac-master-control-pro", name: "Master Control Studio Pro", bundleIdentifier: "com.gordasgdc.macmastercontrolpro",
               iconSymbol: "gearshape.2", tint: .yellow,
               versionSource: .githubReleases(repo: "gordasgdc/mac-master-control-pro")),
    // 2026-09-05: lipsea complet din listă — CGConvertor e o aplicație GDC
    // reală, semnată, deja instalabilă, dar userii trebuiau s-o adauge
    // manual ca "scurtătură personalizată" (exact regula pe care Cristi a
    // cerut-o: doar aplicațiile EXTERNE ajung acolo, ale noastre apar
    // automat la instalare).
    MyAppEntry(id: "cgconvertor", name: "CGConvertor", bundleIdentifier: "com.cristigordas.CGConvertor",
               iconSymbol: "film.stack", tint: .purple,
               versionSource: .githubReleases(repo: "gordasgdc/CGConvertor")),
]

/// O scurtătură personalizată către o aplicație aleasă liber de user (ex.
/// DaVinci Resolve Studio, Premiere Pro, Photoshop, Lightroom) — persistată
/// local, NU face parte din catalogul GDC.
struct CustomLauncher: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    /// Cale absolută către `.app` (bookmark-ul de securitate ar fi mai
    /// robust la mutarea aplicației, dar userul alege explicit din
    /// `/Applications`, unde aplicațiile rareori se mută).
    var appPath: String

    init(name: String, appPath: String) {
        self.id = UUID().uuidString
        self.name = name
        self.appPath = appPath
    }
}

@MainActor
final class MyAppsStore: NSObject, ObservableObject {
    static let shared = MyAppsStore()

    struct Status {
        var isInstalled = false
        var installedVersion: String?
        var latestVersion: String?
        var hasUpdate = false
        /// Calea bundle-ului instalat — folosita pentru a extrage iconita
        /// REALA a aplicatiei (NSWorkspace), niciodata un simbol generic
        /// cand aplicatia chiar exista pe disc.
        var appPath: String?
    }

    @Published private(set) var statuses: [String: Status] = [:]
    @Published private(set) var customLaunchers: [CustomLauncher] = []

    private let customLaunchersKey = "gdcpm_custom_launchers"

    /// Sursele de fisiere active - tinute vii cat traieste store-ul (retain
    /// explicit, altfel DispatchSourceFileSystemObject se opreste la deinit).
    private var directoryWatchers: [DispatchSourceFileSystemObject] = []

    private override init() {
        super.init()
        loadCustomLaunchers()
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(handleAppLaunched),
            name: NSWorkspace.didLaunchApplicationNotification, object: nil)
        watchApplicationsFolders()
    }

    @objc private func handleAppLaunched(_ note: Notification) {
        guard let launched = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let bundleID = launched.bundleIdentifier,
              knownGDCApps.contains(where: { $0.bundleIdentifier == bundleID }) else { return }
        refreshAll()
    }

    /// Prinde o instalare (.pkg/copiere manuala) chiar daca aplicatia nu a
    /// fost inca lansata deloc - `didLaunchApplicationNotification` singur
    /// nu acopera acest caz. Un DispatchSource pe folderul de nivel 1
    /// (nu FSEvents recursiv) e suficient si ieftin: orice schimbare in
    /// `/Applications`/`~/Applications` declanseaza un rescan (doar 4-5
    /// verificari `urlForApplication`, nu o scanare de disc).
    private func watchApplicationsFolders() {
        for path in ["/Applications", NSHomeDirectory() + "/Applications"] {
            let fd = open(path, O_EVTONLY)
            guard fd >= 0 else { continue }
            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fd, eventMask: [.write], queue: .main)
            source.setEventHandler { [weak self] in self?.refreshAll() }
            source.setCancelHandler { close(fd) }
            source.resume()
            directoryWatchers.append(source)
        }
    }

    func refreshAll() {
        for app in knownGDCApps {
            refresh(app)
        }
    }

    /// Citeste versiunea instalata DIRECT din bytes-ii de pe disc, ocolind
    /// `Bundle(url:)` (2026-08-30, bug real gasit de Cristi: "actualizez
    /// aplicatia, dau refresh, eticheta ramane tot actualizare disponibila").
    /// Cauza reala: `Bundle` cache-uieste `infoDictionary`-ul intern pentru
    /// toata durata procesului - odata ce GDC Plugin Manager a citit versiunea
    /// unei aplicatii (ex. la lansare), citirile ulterioare din ACELASI
    /// proces (inclusiv Refresh) intorc valoarea VECHE din cache, chiar daca
    /// fisierul Info.plist s-a schimbat intre timp pe disc - dispare doar
    /// dupa ce userul inchide complet si redeschide GDC Plugin Manager
    /// (proces nou = cache Bundle gol). Citirea directa a plist-ului
    /// (fara `Bundle`) nu are acest cache, deci reflecta mereu starea reala.
    private static func readInfoPlistVersion(appURL: URL) -> String? {
        let infoPlistURL = appURL.appendingPathComponent("Contents/Info.plist")
        guard let data = try? Data(contentsOf: infoPlistURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any]
        else { return nil }
        return plist["CFBundleShortVersionString"] as? String
    }

    private func refresh(_ app: MyAppEntry) {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleIdentifier) else {
            statuses[app.id] = Status(isInstalled: false)
            return
        }
        let installedVersion = Self.readInfoPlistVersion(appURL: appURL)
        statuses[app.id] = Status(isInstalled: true, installedVersion: installedVersion, appPath: appURL.path)

        Task {
            let latest = await fetchLatestVersion(app.versionSource)
            guard let latest else { return }
            var status = statuses[app.id] ?? Status(isInstalled: true, installedVersion: installedVersion, appPath: appURL.path)
            status.latestVersion = latest
            if let installedVersion {
                status.hasUpdate = isNewer(latest, than: installedVersion)
            }
            statuses[app.id] = status
        }
    }

    private func fetchLatestVersion(_ source: VersionSource) async -> String? {
        switch source {
        case .githubReleases(let repo):
            guard let url = URL(string: "https://api.github.com/repos/\(repo)/releases/latest") else { return nil }
            guard let (data, response) = try? await URLSession.shared.data(from: url),
                  let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tag = json["tag_name"] as? String else { return nil }
            return tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
        case .updateJSON(let url):
            guard let (data, response) = try? await URLSession.shared.data(from: url),
                  let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let version = json["version"] as? String else { return nil }
            return version
        }
    }

    /// Comparare semver simplă, componentă cu componentă — suficientă
    /// pentru formatul `MAJOR.MINOR.PATCH` folosit peste tot în ecosistem.
    private func isNewer(_ a: String, than b: String) -> Bool {
        let av = a.split(separator: ".").compactMap { Int($0) }
        let bv = b.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(av.count, bv.count) {
            let x = i < av.count ? av[i] : 0
            let y = i < bv.count ? bv[i] : 0
            if x != y { return x > y }
        }
        return false
    }

    func launch(_ app: MyAppEntry) {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleIdentifier) else { return }
        NSWorkspace.shared.open(appURL)
    }

    // MARK: - Custom launchers (persistate local)

    private func loadCustomLaunchers() {
        guard let data = UserDefaults.standard.data(forKey: customLaunchersKey),
              let decoded = try? JSONDecoder().decode([CustomLauncher].self, from: data) else { return }
        customLaunchers = decoded
    }

    private func saveCustomLaunchers() {
        guard let data = try? JSONEncoder().encode(customLaunchers) else { return }
        UserDefaults.standard.set(data, forKey: customLaunchersKey)
    }

    func addCustomLauncher(name: String, appPath: String) {
        customLaunchers.append(CustomLauncher(name: name, appPath: appPath))
        saveCustomLaunchers()
    }

    func removeCustomLauncher(_ launcher: CustomLauncher) {
        customLaunchers.removeAll { $0.id == launcher.id }
        saveCustomLaunchers()
    }

    func launchCustom(_ launcher: CustomLauncher) {
        NSWorkspace.shared.open(URL(fileURLWithPath: launcher.appPath))
    }
}

struct MyAppsGrid: View {
    @StateObject private var store = MyAppsStore.shared
    @State private var showAddLauncher = false

    private let columns = [GridItem(.adaptive(minimum: 220, maximum: 280), spacing: 14)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L.t("myApps.section.gdc")).font(.headline).foregroundStyle(.secondary)
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(knownGDCApps) { app in
                            MyAppCard(app: app, status: store.statuses[app.id] ?? .init())
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(L.t("myApps.section.custom")).font(.headline).foregroundStyle(.secondary)
                        Spacer()
                        Button {
                            showAddLauncher = true
                        } label: {
                            Label(L.t("myApps.addCustom"), systemImage: "plus.circle.fill")
                        }
                        .buttonStyle(.plain)
                    }
                    if store.customLaunchers.isEmpty {
                        Text(L.t("myApps.custom.empty")).font(.caption).foregroundStyle(.secondary)
                    } else {
                        LazyVGrid(columns: columns, spacing: 14) {
                            ForEach(store.customLaunchers) { launcher in
                                CustomLauncherCard(launcher: launcher, store: store)
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .onAppear { store.refreshAll() }
        .fileImporter(isPresented: $showAddLauncher, allowedContentTypes: [.application], allowsMultipleSelection: true) { result in
            guard case .success(let urls) = result else { return }
            for url in urls {
                store.addCustomLauncher(name: url.deletingPathExtension().lastPathComponent, appPath: url.path)
            }
        }
    }
}

private struct MyAppCard: View {
    let app: MyAppEntry
    let status: MyAppsStore.Status

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Iconita REALA a aplicatiei instalate (extrasa din bundle,
                // niciodata bundle-uita in cod - vezi nota de mai jos despre
                // marcile inregistrate). Cand nu e instalata, cadem pe
                // simbolul generic ca fallback vizual.
                if let path = status.appPath {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                        .resizable().frame(width: 26, height: 26)
                } else {
                    Image(systemName: app.iconSymbol)
                        .font(.system(size: 22))
                        .foregroundStyle(app.tint)
                }
                Spacer()
                if status.hasUpdate {
                    Text(L.t("myApps.updateAvailable"))
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(Color.orange))
                }
            }
            Text(app.name).font(.headline)
            if let v = status.installedVersion {
                Text("v\(v)").font(.caption2).foregroundStyle(.tertiary)
            }
            Spacer(minLength: 0)
            if status.isInstalled {
                Button(L.t("myApps.open")) { MyAppsStore.shared.launch(app) }
            } else {
                Text(L.t("myApps.notInstalled")).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 100, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(.background.secondary))
        .opacity(status.isInstalled ? 1 : 0.55)
    }
}

private struct CustomLauncherCard: View {
    let launcher: CustomLauncher
    @ObservedObject var store: MyAppsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Iconita reala a aplicatiei alese (DaVinci Resolve,
                // Photoshop, Lightroom etc.) - extrasa direct din bundle-ul
                // deja instalat pe masina userului, exact ca in Finder.
                // NU bundle-uim siglele oficiale ale acestor aplicatii terte
                // in cod - sunt marci inregistrate ale Adobe/Blackmagic,
                // redistribuirea lor fara licenta ar fi risc de trademark.
                Image(nsImage: NSWorkspace.shared.icon(forFile: launcher.appPath))
                    .resizable().frame(width: 26, height: 26)
                Spacer()
                Button {
                    store.removeCustomLauncher(launcher)
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            Text(launcher.name).font(.headline)
            Spacer(minLength: 0)
            Button(L.t("myApps.open")) { store.launchCustom(launcher) }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 100, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(.background.secondary))
    }
}
