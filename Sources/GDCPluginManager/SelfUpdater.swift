import AppKit

/// Descarca si instaleaza automat un update de APLICATIE, fara sa mai
/// treaca prin browser/pagina de GitHub.
///
/// ARCHITECTURE NOTE (2026-08-26): pana acum, atat bannerul cat si
/// pop-up-ul de update chemau `NSWorkspace.shared.open(url)` — asta
/// deschidea arhiva .zip in browser (download normal), userul trebuia
/// s-o dezarhiveze si sa instaleze manual peste versiunea curenta. Cristi
/// a cerut explicit scoaterea self-updater-ului din backlog, dupa ce
/// reteta a fost verificata deja end-to-end pe DataMover (vezi
/// `DataMover/mac-native/Sources/DataMoverMac/SelfUpdater.swift`, testat
/// manual, live, de Cristi). Fisierul asta PORTEAZA reteta aceea, adaptata
/// la ce exista deja in acest repo:
///
///   1. `docs/update.json` -> `download_url.mac` (deja fetch-uit de
///      `UpdateChecker.check()`, NU mai facem un al doilea request de
///      versiune) — indica `GDCPluginManager-Mac.zip`, un ARHIVA, nu un
///      `.pkg` gol ca la DataMover. Trebuie dezarhivata local inainte de
///      instalare.
///   2. Instalare prin promptul NATIV de parola admin
///      (`osascript ... with administrator privileges`) — ACELASI pattern
///      folosit deja in `InstallManager.swift` pentru elevarea OFX (vezi
///      acolo), niciodata `sudo` interactiv sau Terminal.
///   3. Copia locala a `.pkg`-ului extras se redenumeste cu versiunea
///      INAINTE de instalare — Regula 17 din CLAUDE.md ("orice fisier
///      descarcat/creat local, in afara mecanismului `releases/latest/
///      download/...`, trebuie sa poarte versiunea in nume").
///
/// WARNING: pasul de instalare (promptul de parola admin) NU poate fi
/// verificat automat de Claude — cere interactiune fizica reala a userului
/// cu fereastra de sistem. Verificat automat doar pana la "arhiva
/// descarcata + dezarhivata + pachetul .pkg gasit si redenumit corect".
enum SelfUpdater {

    // Arhiva Mac are ~25 MB (pkg + PDF + launcher) — mult mai mare decat
    // .pkg-ul de cateva sute de KB de la DataMover. Timeout-ul implicit al
    // URLSession.shared (60s per request) a picat REAL la testare pe un
    // fisier de dimensiunea asta; o sesiune dedicata, cu timeout marit,
    // evita esecuri false pe conexiuni mai lente ale userilor.
    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120
        config.timeoutIntervalForResource = 300
        return URLSession(configuration: config)
    }()

    enum UpdateError: LocalizedError {
        case downloadFailed(String)
        case unzipFailed(String)
        case pkgNotFound
        case installScriptFailed(String)

        var errorDescription: String? {
            switch self {
            case .downloadFailed(let detail): return "Descărcarea a eșuat: \(detail)"
            case .unzipFailed(let detail): return "Dezarhivarea a eșuat: \(detail)"
            case .pkgNotFound: return "Arhiva descărcată nu conține un pachet .pkg."
            case .installScriptFailed(let detail): return "Nu am putut porni instalarea: \(detail)"
            }
        }
    }

    /// Descarca arhiva Mac din `info.download_url`, o dezarhiveaza,
    /// gaseste `.pkg`-ul dinauntru, il redenumeste cu versiunea si porneste
    /// instalarea. La succes, aplicatia curenta se inchide singura —
    /// scriptul de instalare o relanseaza dupa ce termina.
    @MainActor
    static func downloadAndInstall(info: UpdateInfo) async {
        guard let zipURL = URL(string: info.download_url) else {
            presentFailure(UpdateError.downloadFailed("Lipsește link-ul de descărcare pentru Mac în update.json"))
            return
        }

        let progress = UpdateProgressWindow(version: info.version)
        progress.show()

        do {
            let tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("gdcpm-update-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

            progress.setStatus(L.t("update.downloading"))
            let zipPath = tempDir.appendingPathComponent("GDCPluginManager-Mac.zip")
            try await download(from: zipURL, to: zipPath)

            progress.setStatus(L.t("update.extracting"))
            let extractDir = tempDir.appendingPathComponent("extracted", isDirectory: true)
            try unzip(zipPath: zipPath, to: extractDir)

            guard let extractedPkg = findPkg(in: extractDir) else {
                throw UpdateError.pkgNotFound
            }

            // Regula 17: redenumim cu versiunea INAINTE de instalare —
            // arhiva sursa are un nume stabil (necesar pt. releases/latest/
            // download), dar copia locala nu mai are acea constrangere.
            let versionedPkg = tempDir.appendingPathComponent("GDCPluginManager-\(info.version).pkg")
            try FileManager.default.moveItem(at: extractedPkg, to: versionedPkg)

            progress.setStatus(L.t("update.installing"))
            try runInstaller(pkgPath: versionedPkg, tempDir: tempDir)

            // Scriptul de instalare (pornit mai sus, ruleaza independent sub
            // osascript) se ocupa de tot ce urmeaza: instalare + relansare.
            progress.close()
            NSApp.terminate(nil)
        } catch {
            progress.close()
            presentFailure(error)
        }
    }

    // MARK: - Descarcare

    private static func download(from url: URL, to destination: URL) async throws {
        let (tempLocation, response): (URL, URLResponse)
        do {
            (tempLocation, response) = try await session.download(from: url)
        } catch {
            throw UpdateError.downloadFailed(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw UpdateError.downloadFailed("HTTP \(code)")
        }
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.moveItem(at: tempLocation, to: destination)
    }

    // MARK: - Dezarhivare

    /// `/usr/bin/unzip`, nativ pe macOS — Foundation n-are un API de
    /// dezarhivare, iar arhivele noastre (.zip cu .pkg inauntru) sunt
    /// simple, nu justifica o dependinta noua (ex. ZIPFoundation) doar
    /// pentru asta.
    private static func unzip(zipPath: URL, to destination: URL) throws {
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-o", "-q", zipPath.path, "-d", destination.path]
        let errorPipe = Pipe()
        process.standardError = errorPipe
        do {
            try process.run()
        } catch {
            throw UpdateError.unzipFailed(error.localizedDescription)
        }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let errData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errText = String(data: errData, encoding: .utf8) ?? ""
            throw UpdateError.unzipFailed(errText.isEmpty ? "cod \(process.terminationStatus)" : errText)
        }
    }

    /// Cauta primul `.pkg` din arhiva extrasa (o singura adancime — vezi
    /// structura reala a `GDCPluginManager-Mac.zip`: .pkg + .command +
    /// .pdf, toate la radacina, fara subfoldere).
    private static func findPkg(in directory: URL) -> URL? {
        let contents = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        return contents.first { $0.pathExtension.lowercased() == "pkg" }
    }

    // MARK: - Instalare

    /// Port 1:1 al `runInstaller` din DataMover — vezi WARNING de acolo
    /// despre `installer -pkg ... -target /` care nu poate fi verificat
    /// automat, doar pana la "scriptul e scris si pornit corect".
    private static func runInstaller(pkgPath: URL, tempDir: URL) throws {
        let logPath = tempDir.appendingPathComponent("gdcpm_update.log")
        let scriptPath = tempDir.appendingPathComponent("gdcpm_update.sh")

        let scriptContent = """
        #!/bin/bash
        exec > "\(logPath.path)" 2>&1
        sleep 2
        echo "Instalez actualizarea..."
        installer -pkg "\(pkgPath.path)" -target /
        status=$?
        if [ $status -ne 0 ]; then
            echo "Instalarea a esuat (cod $status)."
            exit $status
        fi
        echo "Pornesc aplicatia actualizata..."
        open "/Applications/GDCPluginManager.app"
        rm -rf "\(tempDir.path)"
        """
        do {
            try scriptContent.write(to: scriptPath, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptPath.path)
        } catch {
            throw UpdateError.installScriptFailed(error.localizedDescription)
        }

        // Acelasi pattern de elevare ca in InstallManager.swift (OFX):
        // `osascript ... with administrator privileges` deschide promptul
        // NATIV macOS de parola, fara Terminal si fara `sudo` interactiv.
        let escapedPath = scriptPath.path.replacingOccurrences(of: "\"", with: "\\\"")
        let appleScript = "do shell script \"\(escapedPath)\" with administrator privileges"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", appleScript]
        do {
            try process.run()
        } catch {
            throw UpdateError.installScriptFailed(error.localizedDescription)
        }
        // Fire-and-forget INTENTIONAT: promptul de parola e modal la nivel
        // de SISTEM, iar `installer` + relansarea mai dureaza cateva
        // secunde dupa ce userul introduce parola — nu blocam UI-ul.
    }

    // MARK: - Eroare

    @MainActor
    private static func presentFailure(_ error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = L.t("update.installFailed.title")
        alert.informativeText = String(format: L.t("update.installFailed.body"), error.localizedDescription)
        alert.addButton(withTitle: L.t("update.installFailed.openPage"))
        alert.addButton(withTitle: "OK")
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "https://github.com/gordasgdc/gdc-plugin-manager/releases/latest")!)
        }
    }
}

/// Fereastra minimala de progres (AppKit) — port 1:1 al celei din
/// DataMover (`UpdateProgressWindow`), cu un pas in plus in text
/// ("Se dezarhivează…") pentru ca aici sursa e un .zip, nu un .pkg gol.
@MainActor
final class UpdateProgressWindow {
    private let window: NSWindow
    private let statusLabel: NSTextField
    private let spinner: NSProgressIndicator

    init(version: String) {
        let contentRect = NSRect(x: 0, y: 0, width: 380, height: 110)
        window = NSWindow(
            contentRect: contentRect,
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.title = L.t("update.title")
        window.isReleasedWhenClosed = false
        window.center()

        let container = NSView(frame: contentRect)

        let titleLabel = NSTextField(labelWithString: "GDC Plugin Manager \(version)")
        titleLabel.font = .boldSystemFont(ofSize: 13)
        titleLabel.frame = NSRect(x: 20, y: 70, width: 340, height: 20)
        container.addSubview(titleLabel)

        statusLabel = NSTextField(labelWithString: "")
        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.lineBreakMode = .byWordWrapping
        statusLabel.maximumNumberOfLines = 2
        statusLabel.frame = NSRect(x: 20, y: 30, width: 340, height: 34)
        container.addSubview(statusLabel)

        spinner = NSProgressIndicator(frame: NSRect(x: 20, y: 12, width: 340, height: 6))
        spinner.style = .bar
        spinner.isIndeterminate = true
        spinner.startAnimation(nil)
        container.addSubview(spinner)

        window.contentView = container
    }

    func show() {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func setStatus(_ text: String) {
        statusLabel.stringValue = text
    }

    func close() {
        spinner.stopAnimation(nil)
        window.close()
    }
}
