import Foundation

/// A clean, new sales log for GDC Plugin Manager — intentionally NOT
/// extending gdc-license-system/customers.csv, which has a known header
/// drift bug (7 columns in the header, 8 in newer rows). Both the header
/// and each written row are built from the same `columns` constant, so
/// they can never drift apart the way the old file did.
enum SalesLog {
    static let columns = ["data_utc", "produs_id", "produs_nume", "client", "email", "pret_eur", "expira", "id_masina", "cod_serial"]

    private static var fileURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("GDC License Manager", isDirectory: true)
            .appendingPathComponent("furnizor_sales.csv")
    }

    struct Entry: Identifiable {
        let dateUTC: String
        let productID: String
        let productName: String
        let customer: String
        let email: String
        let priceEUR: Double
        let expiresDisplay: String
        let machineID: String
        let serial: String

        /// Serials are unique per issued code, so they double as a
        /// stable row identity for SwiftUI lists/tables.
        var id: String { serial }

        var priceDisplay: String {
            priceEUR.formatted(.currency(code: "EUR"))
        }
    }

    static func append(productID: String, productName: String, customer: String, email: String,
                        priceEUR: Double, expiresDisplay: String, machineID: String, serial: String) throws {
        let entry = Entry(
            dateUTC: ISO8601DateFormatter().string(from: Date()), productID: productID, productName: productName,
            customer: customer, email: email, priceEUR: priceEUR, expiresDisplay: expiresDisplay,
            machineID: machineID, serial: serial
        )

        let url = fileURL
        let fm = FileManager.default
        try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)

        if !fm.fileExists(atPath: url.path) {
            let header = columns.joined(separator: ",") + "\n"
            try header.write(to: url, atomically: true, encoding: .utf8)
        }

        guard let data = (rowString(for: entry) + "\n").data(using: .utf8) else { return }
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        handle.seekToEndOfFile()
        handle.write(data)
    }

    /// Reads every logged sale back, newest first. Returns `[]` if the
    /// log doesn't exist yet (no sales recorded) rather than throwing —
    /// an empty history is a normal, expected state, not an error.
    static func readAll() -> [Entry] {
        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { return [] }
        var lines = content.components(separatedBy: "\n").filter { !$0.isEmpty }
        guard !lines.isEmpty else { return [] }
        lines.removeFirst() // header row

        let entries: [Entry] = lines.compactMap { line in
            let fields = parseCSVLine(line)
            guard fields.count == columns.count else { return nil }
            return Entry(
                dateUTC: fields[0], productID: fields[1], productName: fields[2],
                customer: fields[3], email: fields[4], priceEUR: Double(fields[5]) ?? 0,
                expiresDisplay: fields[6], machineID: fields[7], serial: fields[8]
            )
        }
        return entries.reversed()
    }

    /// Removes one entry from the log only — this is bookkeeping, not
    /// revocation: a serial already sent to a customer keeps activating
    /// normally (the log has no bearing on LicenseCore's verification),
    /// exactly like GDC License Manager's own "Șterge acest cod" history
    /// row deletion.
    static func delete(serial: String) throws {
        let remaining = readAll().filter { $0.serial != serial }.reversed() // back to chronological order
        var content = columns.joined(separator: ",") + "\n"
        for entry in remaining {
            content += rowString(for: entry) + "\n"
        }
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    /// Corrects a bookkeeping mistake (wrong name, email, or price typed
    /// in at generation time) — replaces the row matching `serial` with
    /// `updated` in place. Purely a log edit, exactly like `delete`: the
    /// serial itself keeps validating however it was signed, unaffected
    /// by anything in this file.
    static func update(serial: String, with updated: Entry) throws {
        let all = readAll().reversed() // chronological order, oldest first
        var content = columns.joined(separator: ",") + "\n"
        for entry in all {
            content += rowString(for: entry.serial == serial ? updated : entry) + "\n"
        }
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    private static func rowString(for entry: Entry) -> String {
        [
            entry.dateUTC, entry.productID, entry.productName, entry.customer, entry.email,
            String(format: "%.2f", entry.priceEUR), entry.expiresDisplay, entry.machineID, entry.serial
        ].map(csvEscape).joined(separator: ",")
    }

    private static func csvEscape(_ field: String) -> String {
        guard field.contains(",") || field.contains("\"") || field.contains("\n") else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    /// A small hand-rolled CSV field splitter that understands quoted
    /// fields (commas/newlines inside quotes, `""` as an escaped quote)
    /// — the exact inverse of `csvEscape` above.
    private static func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        var i = line.startIndex
        while i < line.endIndex {
            let char = line[i]
            if inQuotes {
                if char == "\"" {
                    let next = line.index(after: i)
                    if next < line.endIndex, line[next] == "\"" {
                        current.append("\"")
                        i = line.index(after: next)
                        continue
                    } else {
                        inQuotes = false
                        i = line.index(after: i)
                        continue
                    }
                } else {
                    current.append(char)
                }
            } else if char == "\"" {
                inQuotes = true
            } else if char == "," {
                fields.append(current)
                current = ""
            } else {
                current.append(char)
            }
            i = line.index(after: i)
        }
        fields.append(current)
        return fields
    }
}
