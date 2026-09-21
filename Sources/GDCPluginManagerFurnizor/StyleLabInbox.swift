import Foundation

/// Căsuța de intrare din GDC STYLE Lab: pachetele OFX validate și trimise de STYLE Lab (cod intern oficial, nume, versiune, cale) apar aici
/// și completează singure formularul de publicare — fără scriere manuală, deci fără nume sau coduri eronate.
struct StyleLabSubmission: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var version: String
    var type: String
    var description: String
    var supportedOS: String
    var bundleFolderName: String
    var bundlePath: String
    var source: String
    var createdAt: String
    var licensing: String
    var coverFile: String?
    /// Pachet Demo (id = `<cod>-demo`): publicat gratuit. `autoPublish` = STYLE Lab cere publicarea directă (fără formular), vezi DemoPublisher.
    var demo: Bool?
    var autoPublish: Bool?
}

enum StyleLabInbox {
    static var folder: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/GDC/PluginInbox", isDirectory: true)
    }

    /// Trimiterile în așteptare, cele mai noi primele; cele al căror pachet nu mai există pe disc se ignoră.
    static func pending() -> [StyleLabSubmission] {
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        return files.filter { $0.pathExtension == "json" }
            .compactMap { try? JSONDecoder().decode(StyleLabSubmission.self, from: Data(contentsOf: $0)) }
            .filter { FileManager.default.fileExists(atPath: $0.bundlePath) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    /// După publicare, trimiterea se scoate din căsuță.
    static func remove(id: String) {
        try? FileManager.default.removeItem(at: folder.appendingPathComponent(id + ".json"))
        try? FileManager.default.removeItem(at: folder.appendingPathComponent(id + ".png"))
    }
}
