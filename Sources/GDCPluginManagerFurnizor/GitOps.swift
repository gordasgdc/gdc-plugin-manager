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

    // MARK: - D2 (2026-09-25): publicare DOAR pe `main`, din checkout-uri dedicate

    /// Ramura pe care ajunge ORICE publicare. Nu se deduce din checkout.
    static let publishBranch = "main"

    /// Ce repo trebuie să fie un checkout de publicare și ce poate conține nepublicat.
    /// `allowedDirtyPrefixes == nil` = orice fișier (repo-urile private, care conțin doar produse).
    struct PublishTarget: Equatable {
        let repoSlug: String                 // ex. "gordasgdc/gdc-plugin-manager"
        let allowedDirtyPrefixes: [String]?  // ex. ["docs/"] pentru catalogul public
    }

    struct PublishGuardError: Error, LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    /// "https://github.com/a/b.git", "git@github.com:a/b", "/tmp/x/a/b.git" → "a/b" (litere mici).
    static func repoSlug(fromRemoteURL url: String) -> String? {
        var u = url.trimmingCharacters(in: .whitespacesAndNewlines)
        while u.hasSuffix("/") { u.removeLast() }
        if u.hasSuffix(".git") { u.removeLast(4) }
        let parts = u.split(whereSeparator: { $0 == "/" || $0 == ":" }).map(String.init)
        guard parts.count >= 2 else { return nil }
        return "\(parts[parts.count - 2])/\(parts[parts.count - 1])".lowercased()
    }

    /// Verificările de dinaintea ORICĂREI operații git de publicare. Nu modifică nimic.
    static func verifyPublishCheckout(at directory: URL, target explicitTarget: PublishTarget? = nil) throws {
        let path = directory.path
        guard let target = explicitTarget ?? RepoCheckoutPaths.publishTarget(for: directory) else {
            throw PublishGuardError(message: "Publicare oprită: \(path) nu e un checkout de publicare cunoscut. Nimic nu s-a modificat.")
        }
        guard FileManager.default.fileExists(atPath: directory.appendingPathComponent(".git").path) else {
            throw PublishGuardError(message: RepoCheckoutPaths.missingCheckoutMessage(path: path, repoSlug: target.repoSlug))
        }
        let remote = (try? run(["remote", "get-url", "origin"], at: directory)) ?? ""
        guard repoSlug(fromRemoteURL: remote) == target.repoSlug.lowercased() else {
            throw PublishGuardError(message: "Publicare oprită: checkout-ul \(path) indică spre alt repo (\(remote.trimmingCharacters(in: .whitespacesAndNewlines))), nu spre \(target.repoSlug). Nimic nu s-a modificat.")
        }
        for marker in ["MERGE_HEAD", "CHERRY_PICK_HEAD", "REVERT_HEAD", "rebase-merge", "rebase-apply"] {
            let rel = try run(["rev-parse", "--git-path", marker], at: directory).trimmingCharacters(in: .whitespacesAndNewlines)
            let url = rel.hasPrefix("/") ? URL(fileURLWithPath: rel) : directory.appendingPathComponent(rel)
            if FileManager.default.fileExists(atPath: url.path) {
                throw PublishGuardError(message: "Publicare oprită: în \(path) e în curs o operație git neterminată (\(marker)). Termin-o sau anuleaz-o în Terminal, apoi reîncearcă. Nimic nu s-a modificat.")
            }
        }
        let branch = (try? run(["symbolic-ref", "--quiet", "--short", "HEAD"], at: directory))?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "(detașat)"
        guard branch == publishBranch else {
            throw PublishGuardError(message: "Publicare oprită: checkout-ul \(path) e pe ramura „\(branch)”, nu pe „\(publishBranch)”. Publicarea merge doar pe \(publishBranch). Nimic nu s-a modificat.")
        }
        if let allowed = target.allowedDirtyPrefixes {
            let status = try run(["status", "--porcelain", "--untracked-files=all"], at: directory)
            let foreign = status.split(separator: "\n").map { line -> String in
                var p = String(line.dropFirst(3))
                if let arrow = p.range(of: " -> ") { p = String(p[arrow.upperBound...]) }
                return p.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            }.filter { p in !allowed.contains { p.hasPrefix($0) } }
            guard foreign.isEmpty else {
                throw PublishGuardError(message: "Publicare oprită: checkout-ul \(path) conține modificări care nu țin de publicare:\n\(foreign.prefix(10).joined(separator: "\n"))\nNu le includ și nu le șterg. Mută-le sau anulează-le, apoi reîncearcă.")
            }
        }
    }

    /// `-u` nu doar impinge, ci si SCRIE configuratia de tracking lipsa —
    /// asa ca un checkout care a pornit fara ea se repara singur la prima
    /// publicare reusita, nu ramane defect pana cand cineva ruleaza manual
    /// `git branch --set-upstream-to`.
    /// D2: DOAR `main`, explicit, fără force. Un push respins (cineva a publicat între timp) oprește
    /// publicarea; commit-ul local rămâne, nu se pierde nimic.
    static func push(at directory: URL, target: PublishTarget? = nil) throws {
        try verifyPublishCheckout(at: directory, target: target)
        do {
            try run(["push", "-u", "origin", "\(publishBranch):\(publishBranch)"], at: directory)
        } catch let error as GitError {
            throw PublishGuardError(message: "Publicare oprită la push: serverul a respins \(publishBranch) (probabil o publicare mai nouă, de pe alt Mac). Commit-ul local e păstrat în \(directory.path); nu s-a forțat nimic.\n\(error.output)")
        }
    }

    /// Ramura curenta a checkout-ului (doar informativ; publicarea NU o mai folosește — vezi `publishBranch`).
    ///
    /// BUG REAL (2026-09-14, raportat din Furnizor la publicarea unui produs):
    /// `gdc-plugin-manager-files` avea `main` FARA upstream configurat, iar
    /// `git pull --ff-only` esua cu "There is no tracking information for the
    /// current branch" — publicarea se oprea inainte sa inceapa. De aceea
    /// remote-ul si ramura se dau EXPLICIT: comanda merge indiferent de ce e
    /// configurat local.
    static func currentBranch(at directory: URL) throws -> String {
        let name = try run(["rev-parse", "--abbrev-ref", "HEAD"], at: directory)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty || name == "HEAD" ? "main" : name
    }

    /// Pulls latest before editing, so the vendor app never works from a
    /// stale local checkout (e.g. after publishing from another Mac).
    /// D2: verificările de mai sus, apoi `fetch` + DOAR fast-forward pe `origin/main`.
    /// Istorie divergentă = oprire, fără merge/rebase automat și fără pierderi.
    static func pull(at directory: URL, target: PublishTarget? = nil) throws {
        try verifyPublishCheckout(at: directory, target: target)
        try run(["fetch", "origin", publishBranch], at: directory)
        do {
            try run(["merge", "--ff-only", "origin/\(publishBranch)"], at: directory)
        } catch let error as GitError {
            throw PublishGuardError(message: "Publicare oprită: \(directory.path) și serverul au istorii diferite pe \(publishBranch) (conflict de sincronizare). Nu am combinat și nu am șters nimic. Rezolvă în Terminal (ex. `git -C \"\(directory.path)\" pull --rebase origin \(publishBranch)`), apoi reîncearcă.\n\(error.output)")
        }
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
    /// `expectedDeletions`: fișiere a căror dispariție e cerută explicit de această publicare (ex. copertele unui lot
    /// de produse șterse) — nu se numără la garda anti-ștergere; orice altă ștergere rămâne limitată la 2.
    static func commitAndPush(at directory: URL, message: String, paths: [String]? = nil, expectedDeletions: Set<String> = [], target: PublishTarget? = nil) throws {
        try verifyPublishCheckout(at: directory, target: target)
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
            try push(at: directory, target: target)
            return
        }
        // GUARD REAL (2026-09-04): `git add docs/covers` (mai jos) prinde
        // ORICE stare curentă a folderului, inclusiv fișiere dispărute de
        // pe disc din motive care n-au NIMIC de-a face cu publicarea asta.
        // Incident real, de două ori (2026-08-31 și 2026-09-03): toate
        // cele 14 coperte din `docs/covers/` au dispărut de pe disc (cel
        // mai probabil CleanMyMac/Hazel, vezi Regula 1 — nu confirmat cu
        // certitudine, dar exact tiparul deja documentat în
        // `CoverImageStore.prepareLocal`), iar URMĂTOAREA publicare
        // oarecare din Furnizor (ex. "Banner Lansare: activat" — o
        // acțiune complet neînrudită) a văzut folderul gol, a făcut
        // `git add docs/covers`, și a COMIS + PUSH-UIT ștergerea tuturor
        // celor 14 imagini sub un mesaj care n-avea nicio treabă cu ele.
        // Toate cele 24 de locuri din Furnizor care publică pe
        // `publicCatalogRepo` trec prin ACEASTĂ funcție cu `paths`
        // incluzând "docs/covers" — o singură gardă aici le protejează pe
        // toate. O publicare normală șterge cel mult 1-2 fișiere din
        // covers/ (coperta veche a produsului tocmai editat/șters, plus
        // eventual `previous` — vezi `CoverImageStore.removeLocalFiles`);
        // orice număr mai mare de ștergeri neașteptate oprește publicarea
        // ÎNAINTE de orice `git add`, ca nimic să nu ajungă stage-uit.
        if paths != nil {
            try guardAgainstUnexpectedDeletions(at: directory, candidatePaths: existingPaths, expected: expectedDeletions)
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
        try push(at: directory, target: target)
    }

    /// Peste câte fișiere dispărute (nu atinse de publicarea curentă) e
    /// clar o anomalie externă, nu o ștergere intenționată — vezi comentariul
    /// din `commitAndPush`. 2 acoperă cazul legitim cel mai larg (coperta
    /// veche a produsului + `previous` de alt nume); orice publicare normală
    /// nu atinge niciodată mai mult de atât într-un singur pas.
    private static let maxExpectedDeletions = 2

    private static func guardAgainstUnexpectedDeletions(at directory: URL, candidatePaths: [String], expected: Set<String> = []) throws {
        guard !candidatePaths.isEmpty else { return }
        let status = try run(["status", "--porcelain"] + candidatePaths, at: directory)
        let deletedLines = status
            .split(separator: "\n")
            .filter { line in
                guard line.count >= 2 else { return false }
                let index = line.index(line.startIndex, offsetBy: 1)
                return line.first == "D" || line[index] == "D"
            }
            .filter { !expected.contains(String($0.dropFirst(3))) }
        guard deletedLines.count > maxExpectedDeletions else { return }
        let names = deletedLines.map { String($0.dropFirst(3)) }.joined(separator: "\n")
        throw GitError(
            command: "add (gardă anti-ștergere neașteptată)",
            output: "Publicarea a fost OPRITĂ înainte de orice modificare în git: "
                + "\(deletedLines.count) fișiere din \(candidatePaths.joined(separator: ", ")) "
                + "au dispărut de pe disc, fără legătură cu ce publici acum:\n\(names)\n\n"
                + "Probabil CleanMyMac/Hazel sau altă unealtă de curățare (vezi CLAUDE.md Regula 1) — "
                + "verifică Coșul de gunoi / backup-ul zilnic (~/.gdc-developer-backup) și restaurează "
                + "manual înainte de a republica. Nimic n-a fost șters din repo de această publicare."
        )
    }
}
