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

    struct Entry {
        let productID: String
        let productName: String
        let customer: String
        let email: String
        let priceEUR: Double
        let expiresDisplay: String
        let machineID: String
        let serial: String
    }

    static func append(_ entry: Entry) throws {
        let url = fileURL
        let fm = FileManager.default
        try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)

        if !fm.fileExists(atPath: url.path) {
            let header = columns.joined(separator: ",") + "\n"
            try header.write(to: url, atomically: true, encoding: .utf8)
        }

        let formatter = ISO8601DateFormatter()
        let row = [
            formatter.string(from: Date()),
            entry.productID,
            entry.productName,
            entry.customer,
            entry.email,
            String(format: "%.2f", entry.priceEUR),
            entry.expiresDisplay,
            entry.machineID,
            entry.serial
        ].map(csvEscape).joined(separator: ",") + "\n"

        guard let data = row.data(using: .utf8) else { return }
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        handle.seekToEndOfFile()
        handle.write(data)
    }

    private static func csvEscape(_ field: String) -> String {
        guard field.contains(",") || field.contains("\"") || field.contains("\n") else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
