import Foundation
import CryptoKit

/// Instalarea ATOMICĂ a pachetelor `.ofx.bundle` într-un folder de pluginuri (de obicei `/Library/OFX/Plugins`, deținut de root).
/// Pachetele se pregătesc întâi într-un folder temporar al utilizatorului (descărcate, verificate SHA-256, identitate / versiune citite din Info.plist);
/// apoi UN SINGUR script (rulat direct dacă folderul e scriibil, altfel cu o singură autorizare de administrator):
///   1. copiază fiecare pachet lângă destinație (`.gdc-<token>-<i>.new`) și verifică din nou hash-ul arborelui, identitatea și versiunea pe copie;
///   2. abia apoi mută vechile pachete (și cele de scos) deoparte (`.old`) și pune noile pachete în locul lor;
///   3. orice eșec la pasul 1 nu atinge nimic; un eșec la pasul 2 readuce tot ce s-a mutat (rollback); la final șterge doar copiile de rezervă.
/// Nu schimbă niciodată proprietarul sau drepturile folderului de pluginuri ori ale pachetelor altor producători: doar pachetele scrise primesc `root:wheel`
/// (când scriptul rulează ca root) și drepturi 755 / 644.
public enum OFXAtomicInstall {
    public struct Write: Equatable {
        public let staged: String        // folderul pachetului pregătit (cale absolută, în folderul temporar al utilizatorului)
        public let folder: String        // numele pachetului sub rădăcină (ex. „GDC Look — ACES.ofx.bundle”)
        public let identifier: String    // CFBundleIdentifier așteptat ("" = nu se verifică)
        public let version: String       // CFBundleShortVersionString așteptat ("" = nu se verifică)
        public let treeSHA: String       // hash-ul arborelui pregătit (treeHash)
        public init(staged: String, folder: String, identifier: String, version: String, treeSHA: String) {
            self.staged = staged; self.folder = folder; self.identifier = identifier; self.version = version; self.treeSHA = treeSHA
        }
    }

    public struct HashError: Error, Equatable { public let message: String }

    /// O cale relativă sigură sub rădăcină: componente nevide, fără „.” / „..”, fără caractere de control.
    public static func isSafeRelative(_ p: String) -> Bool {
        guard !p.isEmpty, !p.hasPrefix("/"), p.count <= 1024 else { return false }
        for c in p.split(separator: "/", omittingEmptySubsequences: false) {
            if c.isEmpty || c == "." || c == ".." { return false }
        }
        return !p.unicodeScalars.contains { $0.value < 0x20 || $0.value == 0x7F }
    }

    /// Hash determinist al unui folder: SHA-256 al listei „<sha256 fișier>␣␣./<cale>” sortată bytewise; același algoritm îl calculează scriptul cu
    /// `find . -type f -print0 | LC_ALL=C sort -z | xargs -0 shasum -a 256 | shasum -a 256`. Legături simbolice / fișiere speciale ⇒ eroare.
    public static func treeHash(_ path: String, fm: FileManager = .default) throws -> String {
        var lines: [(String, String)] = []
        guard let en = fm.enumerator(atPath: path) else { throw HashError(message: "folder ilizibil") }
        for case let rel as String in en {
            let full = path + "/" + rel
            guard let attrs = try? fm.attributesOfItem(atPath: full), let type = attrs[.type] as? FileAttributeType else { throw HashError(message: "intrare ilizibilă: \(rel)") }
            switch type {
            case .typeDirectory: continue
            case .typeRegular:
                guard isSafeRelative(rel) else { throw HashError(message: "nume nesigur: \(rel)") }
                guard let h = FileHandle(forReadingAtPath: full) else { throw HashError(message: "fișier ilizibil: \(rel)") }
                defer { try? h.close() }
                var hasher = SHA256()
                while let chunk = try? h.read(upToCount: 1 << 20), !chunk.isEmpty { hasher.update(data: chunk) }
                lines.append(("./" + rel, hasher.finalize().map { String(format: "%02x", $0) }.joined()))
            default: throw HashError(message: "legătură simbolică / fișier special: \(rel)")
            }
        }
        lines.sort { Array($0.0.utf8).lexicographicallyPrecedes(Array($1.0.utf8)) }
        let listing = lines.map { "\($0.1)  \($0.0)\n" }.joined()
        return SHA256.hash(data: Data(listing.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    static func quote(_ s: String) -> String { "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'" }
    static func isToken(_ s: String) -> Bool { !s.isEmpty && s.count <= 40 && s.unicodeScalars.allSatisfy { ($0.value >= 97 && $0.value <= 122) || ($0.value >= 48 && $0.value <= 57) } }

    /// Motivul pentru care planul e refuzat (nil = valid). Un plan refuzat nu produce niciun script.
    public static func violation(root: String, writes: [Write], removals: [String], token: String) -> String? {
        guard root.hasPrefix("/"), !root.contains("/../"), !root.hasSuffix("/..") else { return "rădăcină nevalidă" }
        guard isToken(token) else { return "token nevalid" }
        guard !writes.isEmpty || !removals.isEmpty else { return "plan gol" }
        var dests = Set<String>()
        for w in writes {
            guard isSafeRelative(w.folder), !w.folder.contains("/"), w.folder.hasSuffix(".ofx.bundle") else { return "destinație nevalidă: \(w.folder)" }
            guard w.staged.hasPrefix("/"), isSafeRelative(String(w.staged.dropFirst())) else { return "sursă nevalidă: \(w.staged)" }
            guard w.treeSHA.count == 64, w.treeSHA.unicodeScalars.allSatisfy({ CharacterSet(charactersIn: "0123456789abcdef").contains($0) }) else { return "hash nevalid" }
            guard dests.insert(w.folder).inserted else { return "destinație dublă: \(w.folder)" }
        }
        for r in removals {
            guard isSafeRelative(r), r.hasSuffix(".ofx.bundle") else { return "cale de scos nevalidă: \(r)" }
            guard !dests.contains(r) else { return "aceeași cale scrisă și scoasă: \(r)" }
        }
        return nil
    }

    /// Scriptul POSIX sh complet sau nil dacă planul e refuzat. Datele intră doar ca argumente citate; programul e constant.
    public static func script(root: String, writes: [Write], removals: [String], token: String) -> String? {
        guard violation(root: root, writes: writes, removals: removals, token: token) == nil else { return nil }
        var s = program + "ROOT=\(quote(root)); TOK=\(quote(token))\nsetup\n"
        for (i, w) in writes.enumerated() { s += "stage \(i) \(quote(w.staged)) \(quote(w.folder)) \(quote(w.identifier)) \(quote(w.version)) \(quote(w.treeSHA))\n" }
        s += "commit_start\n"
        for (i, w) in writes.enumerated() { s += "swap_in \(i) \(quote(w.folder))\n" }
        for (i, r) in removals.enumerated() { s += "remove \(i) \(quote(r))\n" }
        s += "commit_end\n"
        return s
    }

    /// PROGRAMUL (constant, testat cu /bin/sh pe un folder temporar). Codul de ieșire: 0 = tot aplicat; 3 = refuzat înainte de orice schimbare; 4 = eșec la aplicare, rollback făcut.
    public static let program = #"""
    PATH=/usr/bin:/bin:/usr/sbin:/sbin; export PATH
    LC_ALL=C; export LC_ALL
    umask 022
    MOVED=""
    die_clean() { echo "gdc-ofx: $1" >&2; rm -rf "$ROOT"/.gdc-"$TOK"-* 2>/dev/null; exit 3; }
    plist() { /usr/libexec/PlistBuddy -c "Print :$2" "$1/Contents/Info.plist" 2>/dev/null; }
    treehash() {
      ( cd "$1" 2>/dev/null || exit 1
        [ -z "$(find . ! -type f ! -type d -print -quit 2>/dev/null)" ] || exit 2
        find . -type f -print0 | sort -z | xargs -0 /usr/bin/shasum -a 256 | /usr/bin/shasum -a 256 | cut -d' ' -f1 )
    }
    safepath() {
      p="$ROOT"; oldifs=$IFS; IFS=/; set -f
      for c in $1; do
        case "$c" in ""|.|..) IFS=$oldifs; set +f; return 1;; esac
        p="$p/$c"
        if [ -L "$p" ]; then IFS=$oldifs; set +f; return 1; fi
      done
      IFS=$oldifs; set +f; return 0
    }
    setup() {
      if [ -L "$ROOT" ]; then die_clean root_symlink; fi
      if [ ! -d "$ROOT" ]; then /bin/mkdir -p "$ROOT" 2>/dev/null || die_clean root_missing; fi
    }
    stage() {
      i=$1; src=$2; dest=$3; eid=$4; ever=$5; sha=$6
      [ -d "$src" ] && [ ! -L "$src" ] || die_clean "source_missing $i"
      [ -L "$ROOT/$dest" ] && die_clean "dest_symlink $i"
      new="$ROOT/.gdc-$TOK-$i.new"; rm -rf "$new"
      /usr/bin/ditto "$src" "$new" 2>/dev/null || die_clean "copy_failed $i"
      [ "$(treehash "$new")" = "$sha" ] || die_clean "hash $i"
      if [ -n "$eid" ]; then [ "$(plist "$new" CFBundleIdentifier)" = "$eid" ] || die_clean "identity $i"; fi
      if [ -n "$ever" ]; then [ "$(plist "$new" CFBundleShortVersionString)" = "$ever" ] || die_clean "version $i"; fi
      /usr/bin/xattr -cr "$new" 2>/dev/null
      /bin/chmod -R u=rwX,go=rX "$new" 2>/dev/null || die_clean "chmod $i"
      if [ "$(id -u)" = 0 ]; then /usr/sbin/chown -R root:wheel "$new" 2>/dev/null || die_clean "chown $i"; fi
    }
    rollback() {
      printf '%s\n' "$MOVED" | while IFS= read -r m; do
        [ -n "$m" ] || continue
        k=${m%%:*}; rest=${m#*:}; kind=${rest%%:*}; path=${rest#*:}
        if [ "$kind" = w ]; then rm -rf "$ROOT/$path" 2>/dev/null; fi
        if [ -e "$ROOT/.gdc-$TOK-$k.old" ]; then mv "$ROOT/.gdc-$TOK-$k.old" "$ROOT/$path" 2>/dev/null; fi
      done
      echo "gdc-ofx: $1 (rollback)" >&2
      rm -rf "$ROOT"/.gdc-"$TOK"-* 2>/dev/null
      exit 4
    }
    commit_start() { :; }
    swap_in() {
      i=$1; dest=$2; t="$ROOT/$dest"; key="w$i"
      if [ -e "$t" ] || [ -L "$t" ]; then mv "$t" "$ROOT/.gdc-$TOK-$key.old" 2>/dev/null || rollback "swap_old $i"; fi
      MOVED=$(printf '%s:w:%s\n%s' "$key" "$dest" "$MOVED")
      mv "$ROOT/.gdc-$TOK-$i.new" "$t" 2>/dev/null || rollback "swap_new $i"
    }
    remove() {
      i=$1; path=$2; key="r$i"
      safepath "$path" || rollback "unsafe_path $i"
      t="$ROOT/$path"
      [ -e "$t" ] || [ -L "$t" ] || return 0
      [ -d "$t" ] && [ ! -L "$t" ] || rollback "not_bundle $i"
      case "$(plist "$t" CFBundleIdentifier)" in dev.gordas.*) ;; *) rollback "foreign $i";; esac
      mv "$t" "$ROOT/.gdc-$TOK-$key.old" 2>/dev/null || rollback "remove $i"
      MOVED=$(printf '%s:r:%s\n%s' "$key" "$path" "$MOVED")
    }
    commit_end() { rm -rf "$ROOT"/.gdc-"$TOK"-* 2>/dev/null; exit 0; }

    """#
}
