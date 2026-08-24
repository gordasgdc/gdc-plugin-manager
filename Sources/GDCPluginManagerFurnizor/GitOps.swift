import Foundation

/// Shells out to the Mac's own `git`, reusing whatever credential helper
/// already lets `gh`/`git push` work in Terminal (confirmed working,
/// logged in as gordasgdc) — no separate auth handling needed here.
/// Same Process()-based shell-out pattern as InstallManager's elevation
/// code, but plain (no `osascript`/admin-privileges wrapper — pushing to
/// these repos never needs elevation).
enum GitOps {
    struct GitError: Error, LocalizedError {
        let command: String
        let output: String
        var errorDescription: String? { "git \(command) a eșuat:\n\(output)" }
    }

    @discardableResult
    static func run(_ args: [String], at directory: URL) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = args
        process.currentDirectoryURL = directory
        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe
        try process.run()
        process.waitUntilExit()

        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        let combined = (String(data: outData, encoding: .utf8) ?? "") + (String(data: errData, encoding: .utf8) ?? "")

        guard process.terminationStatus == 0 else {
            throw GitError(command: args.joined(separator: " "), output: combined)
        }
        return combined
    }

    /// Pulls latest before editing, so the vendor app never works from a
    /// stale local checkout (e.g. after publishing from another Mac).
    static func pull(at directory: URL) throws {
        try run(["pull", "--ff-only"], at: directory)
    }

    /// Stages, commits, and pushes — stops (throws) at the first failing
    /// step rather than silently continuing.
    ///
    /// `paths`: which paths to stage, relative to `directory`. Pass `nil`
    /// (the default) to stage everything (`git add -A`) — appropriate for
    /// `privateFilesRepo`, which never holds anything BUT product files.
    ///
    /// PITFALL FIXED 2026-08-24: every caller against `publicCatalogRepo`
    /// used to pass `nil` here too, meaning `git add -A` staged the ENTIRE
    /// app repo — `publicCatalogRepo` is the SAME checkout as the app's own
    /// source code (`Sources/`, `twa/`, etc.), not a docs-only clone. Any
    /// unrelated file left modified in that checkout (a work-in-progress
    /// code edit, a doc still being drafted) would get silently swept into
    /// whatever catalog commit Furnizor made next — e.g. a "Material: X"
    /// commit that also contains half-finished Swift changes. Every
    /// `publicCatalogRepo` call site now passes an explicit `paths` list
    /// (`docs/catalog.json` + `docs/covers`) instead. If a new kind of
    /// asset needs staging here, add its path explicitly — don't revert to
    /// `nil`/`-A` for this repo.
    static func commitAndPush(at directory: URL, message: String, paths: [String]? = nil) throws {
        // `git add <path>` throws (exit 128, "pathspec did not match any
        // files") if the path doesn't exist yet — e.g. `docs/covers/` before
        // the first cover image is ever published. Filter to paths that
        // currently exist; a path that legitimately needs staging always
        // exists by the time this runs (callers write it to disk first).
        let existingPaths = (paths ?? []).filter {
            FileManager.default.fileExists(atPath: directory.appendingPathComponent($0).path)
        }
        let addArgs = paths == nil ? ["-A"] : existingPaths
        guard paths == nil || !existingPaths.isEmpty else {
            // Every candidate path was missing — nothing to stage, and an
            // empty `git add` with no args would (dangerously) mean `-A`.
            try run(["push"], at: directory)
            return
        }
        try run(["add"] + addArgs, at: directory)
        // Nothing to commit is not an error (e.g. re-publishing the same
        // bytes) — git exits non-zero for "nothing to commit", so check
        // status first and skip the commit step if there's nothing staged.
        //
        // PITFALL FIXED 2026-08-24 (bug raportat: "Șterge" pe DCTL eșua cu
        // "unknown switch 'A'"): `addArgs` e corect pentru `git add` (unde
        // `-A` înseamnă "tot", sau o listă de path-uri), dar era reciclat
        // AICI ca argument pentru `git status --porcelain` — `-A` nu există
        // ca flag la `git status` (doar la `git add`/`git commit`). Apărea
        // DOAR pe fluxul `privateFilesRepo` (`paths: nil` → `addArgs =
        // ["-A"]`), deci exact la ștergerea unei resurse vandabile
        // (DCTL/LUT/PowerGrade), nu la Materiale/Evenimente/etc. (care
        // folosesc `paths` explicit — acelea sunt pathspec-uri valide și
        // pentru `git status`, de-aia nu pica pe fluxul lor). Fix: la
        // `status`, `-A` devine "niciun argument" (arată tot repo-ul,
        // exact ce am adăugat oricum mai sus cu `git add -A`) — dar
        // pentru path-urile explicite, restricția la `status` rămâne
        // (nu doar la `add`), ca să NU declanșăm fals un commit doar
        // pentru că altceva, neinclus în `paths`, e murdar în checkout-ul
        // ăsta (vezi WARNING de mai sus despre docs-only vs. sursă).
        let statusArgs = paths == nil ? [] : existingPaths
        let status = try run(["status", "--porcelain"] + statusArgs, at: directory)
        if !status.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            try run(["commit", "-m", message], at: directory)
        }
        try run(["push"], at: directory)
    }
}
