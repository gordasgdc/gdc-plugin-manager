import Foundation

/// Bridges to DaVinci Resolve's external scripting API to import/remove
/// PowerGrades directly in Resolve's Gallery — the only way to install a
/// `.drx` grade automatically, since Resolve has no plugin-style folder
/// for these (see `PluginType.powerGrade` in CatalogModel.swift).
///
/// Each published product gets its OWN PowerGrade album, named after the
/// product (see `albumName(for:)`) — never one shared bucket everything
/// gets dumped into. A pack (several `.drx` files published together)
/// imports every one of them into that same product album, so it stays
/// grouped exactly like a LUT/DCTL pack stays grouped in its own
/// subfolder. This mirrors what Cristi asked for after the first version
/// shipped: "nu pot crea separat altul care sa contina mai multe .drx?".
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
///   one. `remove(...)` therefore only ever empties the product's own
///   album (deletes every still in it), never removes the album itself
///   — an empty, oddly-named leftover album is the worst case, cleared
///   by hand from the Gallery if it bothers you.
enum PowerGradeImporter {
    enum ImportResult {
        /// Imported straight into Resolve's Gallery, into this
        /// product's own PowerGrade album.
        case importedToGallery(albumName: String)
        /// Scripting wasn't available (or failed) — the verified files
        /// are sitting at this folder, waiting for a manual import.
        case stagedOnly(folder: URL)
    }

    enum RemoveResult {
        case removedFromGallery
        /// Scripting wasn't available (or the album/stills weren't
        /// found) — the local staged files were still deleted; only the
        /// Gallery copy (if any) remains and needs removing by hand.
        case removedFilesOnly
    }

    /// Every product gets its own album, namespaced with "GDC
    /// PowerGrades — " so it can never collide with one of Cristi's own
    /// personal albums (his Gallery already has one literally named
    /// "GDC" — confirmed live before picking this prefix).
    static func albumName(for productName: String) -> String {
        "GDC PowerGrades — " + productName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// `files` are the already-downloaded, checksum-verified local
    /// copies for this product (its `.drx` file(s), possibly paired with
    /// thumbnails), already sitting in `stagingFolder`. Every `.drx` in
    /// the list is imported — not just the first — so a multi-grade pack
    /// lands together in the product's album.
    static func importIntoGallery(productName: String, files: [URL], stagingFolder: URL) -> ImportResult {
        let albumName = albumName(for: productName)
        guard ResolveProcessCheck.isRunning else { return .stagedOnly(folder: stagingFolder) }
        let drxPaths = files.filter { $0.pathExtension.lowercased() == "drx" }.map(\.path)
        guard !drxPaths.isEmpty else { return .stagedOnly(folder: stagingFolder) }
        guard let pythonPath = findPython3(), FileManager.default.fileExists(atPath: scriptModulesPath) else {
            return .stagedOnly(folder: stagingFolder)
        }

        let drxPathsLiteral = drxPaths.map { "r\"\($0)\"" }.joined(separator: ", ")
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

            ok = target.ImportStills([\(drxPathsLiteral)])
            print("OK" if ok else "FAIL:import_returned_false")
        except Exception as e:
            print("FAIL:" + str(e))
        """

        guard let output = runPython(pythonPath: pythonPath, script: script), output.hasPrefix("OK") else {
            return .stagedOnly(folder: stagingFolder)
        }
        return .importedToGallery(albumName: albumName)
    }

    /// Removes every still from this product's own album (the album
    /// itself can't be deleted — see file header) — safe because each
    /// product owns its album exclusively, so clearing it can never
    /// touch another product's grades or one of Cristi's own albums.
    static func removeFromGallery(productName: String) -> RemoveResult {
        let albumName = albumName(for: productName)
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
            if len(stills) == 0:
                print("OK")
                sys.exit(0)
            ok = target.DeleteStills(list(range(len(stills))))
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
    /// escaped) — every value passed this way is our own data (album
    /// name derived from the product name), never anything from the
    /// downloaded product file.
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
