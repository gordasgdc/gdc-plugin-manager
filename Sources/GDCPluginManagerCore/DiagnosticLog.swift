import Foundation

/// Log de diagnostic pe disc — SINGURA sursa reala pentru depanare de la
/// distanta (userul trimite fisierul, nu descrierea din memorie a ce a
/// vazut). Aceeasi cale/nume ca pe Windows (`DiagnosticLog.cs`,
/// `%TEMP%\gdcpm-crash.log`) — daca cineva investigheaza un bug pe ambele
/// platforme, stie deja unde sa caute pe oricare dintre ele.
///
/// ARCHITECTURE NOTE (2026-08-26): pana acum, `UpdateChecker.check()`
/// esua complet SILENTIOS la orice problema de retea/parsare — `try?` +
/// `else { return }`, fara nicio urma. Prins live: doi useri (Mac +
/// Windows) raportau "sunt la zi" desi serverul servea sigur o versiune
/// noua (verificat direct, de la 3 surse diferite: raw.githubusercontent,
/// gordas.dev cu cache-buster, si statusul de build GitHub Pages) — deci
/// esecul era garantat pe partea de client, dar fara niciun log, nu exista
/// nicio dovada CE anume picase (retea? parsare? un proxy corporate care
/// intercepteaza TLS?). Windows avea deja `DiagnosticLog`/`gdcpm-crash.log`
/// din investigatia PowerGrade — Mac nu avea echivalentul.
/// [2026-08-29] Mutat din `GDCPluginManager` (Client) în Core, ca să fie
/// reutilizat și de Furnizor — folosit acum și pentru diagnosticarea
/// bibliotecii de filigrane sezoniere (upload/publicare), nu doar
/// `UpdateChecker`. Un singur fișier de log, un singur loc de căutat,
/// indiferent care dintre cele două aplicații a scris ultima intrare.
public enum DiagnosticLog {
    private static let path = FileManager.default.temporaryDirectory
        .appendingPathComponent("gdcpm-crash.log")

    public static func write(_ tag: String, _ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let line = "[\(timestamp)] [\(tag)] \(message)\n"
        guard let data = line.data(using: .utf8) else { return }

        if FileManager.default.fileExists(atPath: path.path) {
            if let handle = try? FileHandle(forWritingTo: path) {
                handle.seekToEndOfFile()
                handle.write(data)
                try? handle.close()
            }
        } else {
            try? data.write(to: path)
        }
    }
}
