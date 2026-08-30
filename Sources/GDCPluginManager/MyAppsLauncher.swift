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
    }

    @Published private(set) var statuses: [String: Status] = [:]
    @Published private(set) var customLaunchers: [CustomLauncher] = []

    private let customLaunchersKey = "gdcpm_custom_launchers"

    private override init() {
        super.init()
        loadCustomLaunchers()
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(handleAppLaunched),
            name: NSWorkspace.didLaunchApplicationNotification, object: nil)
    }

    @objc private func handleAppLaunched(_ note: Notification) {
        guard let launched = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let bundleID = launched.bundleIdentifier,
              knownGDCApps.contains(where: { $0.bundleIdentifier == bundleID }) else { return }
        refreshAll()
    }

    func refreshAll() {
        for app in knownGDCApps {
            refresh(app)
        }
    }

    private func refresh(_ app: MyAppEntry) {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleIdentifier) else {
            statuses[app.id] = Status(isInstalled: false)
            return
        }
        let installedVersion = (try? FileManager.default.attributesOfItem(atPath: appURL.path)) != nil
            ? Bundle(url: appURL)?.infoDictionary?["CFBundleShortVersionString"] as? String
            : nil
        statuses[app.id] = Status(isInstalled: true, installedVersion: installedVersion)

        Task {
            let latest = await fetchLatestVersion(app.versionSource)
            guard let latest else { return }
            var status = statuses[app.id] ?? Status(isInstalled: true, installedVersion: installedVersion)
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
        .fileImporter(isPresented: $showAddLauncher, allowedContentTypes: [.application]) { result in
            guard case .success(let url) = result else { return }
            let name = url.deletingPathExtension().lastPathComponent
            store.addCustomLauncher(name: name, appPath: url.path)
        }
    }
}

private struct MyAppCard: View {
    let app: MyAppEntry
    let status: MyAppsStore.Status

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: app.iconSymbol)
                    .font(.system(size: 22))
                    .foregroundStyle(app.tint)
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
                Image(systemName: "app.badge.checkmark").font(.system(size: 22)).foregroundStyle(.secondary)
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
