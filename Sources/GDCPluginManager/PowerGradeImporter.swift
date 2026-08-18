import Foundation

/// Bridges to DaVinci Resolve's external scripting API to import/remove
/// PowerGrades directly in Resolve's Gallery — the only way to install a
/// `.drx` grade automatically, since Resolve has no plugin-style folder
/// for these (see `PluginType.powerGrade` in CatalogModel.swift).
///
/// This only works when Resolve Studio is running with external
/// scripting enabled. Whenever any precondition fails (Free edition,
/// Resolve closed, python3 missing, script error/timeout), every method
/// here returns a "staged only" result instead of throwing — the files
/// are still verified and on disk, the client just needs one manual
/// import step. Never a hard failure.
///
/// Every fact this bridge relies on (env var names, exact method names,
/// the Gallery/PowerGrade album quirks below) was verified live against
/// a running DaVinci Resolve Studio 21 on this Mac before writing this
/// file — not assumed from documentation alone:
/// - `Gallery` exposes separate PowerGrade-album methods
///   (`GetGalleryPowerGradeAlbums`/`CreateGalleryPowerGradeAlbum`),
///   distinct from the still-album ones — PowerGrades are their own
///   album kind, not a still repurposed.
/// - `CreateGalleryPowerGradeAlbum()` creates an unnamed album (Resolve
///   auto-labels it "PowerGrade N"); it must be found afterwards and
///   renamed with `SetAlbumName`, there's no "create with name" call.
/// - `GetGalleryPowerGradeAlbums()` can come back empty on the very
///   first call right after Resolve's scripting bridge itself has just
///   started (observed once, empty on call 1, correct list on call 2
///   moments later) — so the album lookup below retries once before
///   deciding "doesn't exist yet" and creating a duplicate.
/// - There is no API to delete a Gallery album — only the stills inside
///   one. `remove(...)` therefore only ever removes the one still that
///   belongs to the given product (tagged with its catalog id via
///   `SetLabel` at import time), never the shared "GDC PowerGrades"
///   album itself.
enum PowerGradeImporter {
    static let albumName = "GDC PowerGrades"

    enum ImportResult {
        /// Imported straight into Resolve's Gallery, under the shared
        /// "GDC PowerGrades" PowerGrade album.
        case importedToGallery
        /// Scripting wasn't available (or failed) — the verified files
        /// are sitting at this folder, waiting for a manual import.
        case stagedOnly(folder: URL)
    }

    enum RemoveResult {
        case removedFromGallery
        /// Scripting wasn't available (or the still wasn't found) — the
        /// local staged files were still deleted; only the Gallery copy
        /// (if any) remains and needs removing by hand.
        case removedFilesOnly
    }

    /// `files` are the already-downloaded, checksum-verified local
    /// copies for this product (its `.drx` + paired thumbnail, already
    /// sitting in `stagingFolder`).
    static func importIntoGallery(id: String, files: [URL], stagingFolder: URL) -> ImportResult {
        guard ResolveProcessCheck.isRunning else { return .stagedOnly(folder: stagingFolder) }
        guard let drxPath = files.first(where: { $0.pathExtension.lowercased() == "drx" })?.path else {
            return .stagedOnly(folder: stagingFolder)
        }
        guard let pythonPath = findPython3(), FileManager.default.fileExists(atPath: scriptModulesPath) else {
            return .stagedOnly(folder: stagingFolder)
        }

        let script = """
        import sys
        sys.path.append(r"\(scriptModulesPath)")
        try:
            import DaVinciResolveScript as dvr
            resolve = dvr.scriptapp("Resolve")
            if resolve is None:
                print("FAIL:no_scripting_access")
                sys.exit(0)
            project = resolve.GetProjectManager().GetCurrentProject()
            gallery = project.GetGallery()

            def find_album():
                for album in gallery.GetGalleryPowerGradeAlbums():
                    if gallery.GetAlbumName(album) == \(pyString(albumName)):
                        return album
                return None

            target = find_album() or find_album()  # one retry - see file header
            if target is None:
                before = len(gallery.GetGalleryPowerGradeAlbums())
                gallery.CreateGalleryPowerGradeAlbum()
                albums = gallery.GetGalleryPowerGradeAlbums()
                if len(albums) <= before:
                    print("FAIL:create_album_failed")
                    sys.exit(0)
                target = albums[-1]
                gallery.SetAlbumName(target, \(pyString(albumName)))

            before_count = len(target.GetStills())
            ok = target.ImportStills([r"\(drxPath)"])
            if not ok:
                print("FAIL:import_returned_false")
                sys.exit(0)
            after_count = len(target.GetStills())
            if after_count > before_count:
                target.SetLabel(after_count - 1, \(pyString(id)))
            print("OK")
        except Exception as e:
            print("FAIL:" + str(e))
        """

        guard let output = runPython(pythonPath: pythonPath, script: script), output.hasPrefix("OK") else {
            return .stagedOnly(folder: stagingFolder)
        }
        return .importedToGallery
    }

    static func removeFromGallery(id: String) -> RemoveResult {
        guard ResolveProcessCheck.isRunning,
              let pythonPath = findPython3(), FileManager.default.fileExists(atPath: scriptModulesPath) else {
            return .removedFilesOnly
        }

        let script = """
        import sys
        sys.path.append(r"\(scriptModulesPath)")
        try:
            import DaVinciResolveScript as dvr
            resolve = dvr.scriptapp("Resolve")
            if resolve is None:
                print("FAIL:no_scripting_access")
                sys.exit(0)
            project = resolve.GetProjectManager().GetCurrentProject()
            gallery = project.GetGallery()

            target = None
            for album in gallery.GetGalleryPowerGradeAlbums():
                if gallery.GetAlbumName(album) == \(pyString(albumName)):
                    target = album
                    break
            if target is None:
                print("FAIL:album_not_found")
                sys.exit(0)

            stills = target.GetStills()
            match_index = None
            for i in range(len(stills)):
                if target.GetLabel(i) == \(pyString(id)):
                    match_index = i
                    break
            if match_index is None:
                print("FAIL:still_not_found")
                sys.exit(0)

            ok = target.DeleteStills([match_index])
            print("OK" if ok else "FAIL:delete_returned_false")
        except Exception as e:
            print("FAIL:" + str(e))
        """

        guard let output = runPython(pythonPath: pythonPath, script: script), output.hasPrefix("OK") else {
            return .removedFilesOnly
        }
        return .removedFromGallery
    }

    // MARK: - Resolve scripting environment (verified paths/vars, macOS)

    private static let scriptAPIPath = "/Library/Application Support/Blackmagic Design/DaVinci Resolve/Developer/Scripting/"
    private static var scriptModulesPath: String { scriptAPIPath + "Modules/" }
    private static let scriptLibPath = "/Applications/DaVinci Resolve/DaVinci Resolve.app/Contents/Libraries/Fusion/fusionscript.so"

    private static func findPython3() -> String? {
        for candidate in ["/usr/bin/python3", "/opt/homebrew/bin/python3", "/usr/local/bin/python3"] {
            if FileManager.default.isExecutableFile(atPath: candidate) { return candidate }
        }
        return nil
    }

    /// A Python string literal for the given Swift string, safe to splice
    /// into the embedded scripts above (single-quoted, backslash/quote
    /// escaped) — every value passed this way (album name, catalog id)
    /// is our own data, never anything from the downloaded product file.
    private static func pyString(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "'", with: "\\'") + "'"
    }

    /// Runs one embedded script with a hard timeout — the Resolve
    /// scripting bridge can hang (observed with the MCP server's own
    /// bridge this session), so a stuck call must not freeze the app.
    private static func runPython(pythonPath: String, script: String, timeout: TimeInterval = 20) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: pythonPath)
        process.arguments = ["-c", script]
        process.environment = [
            "RESOLVE_SCRIPT_API": scriptAPIPath,
            "RESOLVE_SCRIPT_LIB": scriptLibPath,
            "PYTHONPATH": scriptModulesPath,
            "PATH": ProcessInfo.processInfo.environment["PATH"] ?? "/usr/bin:/bin",
        ]
        let stdoutPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return nil
        }

        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.2)
        }
        if process.isRunning {
            process.terminate()
            return nil
        }
        guard process.terminationStatus == 0 else { return nil }
        let data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
