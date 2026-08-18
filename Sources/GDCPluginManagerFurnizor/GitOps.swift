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

    /// Stages everything, commits, and pushes — stops (throws) at the
    /// first failing step rather than silently continuing.
    static func commitAndPush(at directory: URL, message: String) throws {
        try run(["add", "-A"], at: directory)
        // Nothing to commit is not an error (e.g. re-publishing the same
        // bytes) — git exits non-zero for "nothing to commit", so check
        // status first and skip the commit step if there's nothing staged.
        let status = try run(["status", "--porcelain"], at: directory)
        if !status.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            try run(["commit", "-m", message], at: directory)
        }
        try run(["push"], at: directory)
    }
}
