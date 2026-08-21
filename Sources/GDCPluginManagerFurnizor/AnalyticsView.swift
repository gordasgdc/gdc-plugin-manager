import SwiftUI

/// Download/registration analytics, read from Supabase (see
/// AnalyticsAdminClient.swift). Three views on the same raw data: totals
/// per product, a daily history, and the customer list — the last one
/// joined client-side to each device's downloads by machine_id, since
/// there's no server-side join needed at this scale.
struct AnalyticsView: View {
    @State private var devices: [DeviceRecord] = []
    @State private var events: [DownloadEventRecord] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var searchText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Statistici").font(.title2).fontWeight(.semibold)
                Spacer()
                if isLoading { ProgressView().controlSize(.small) }
                Button { Task { await load() } } label: {
                    Label("Reîmprospătează", systemImage: "arrow.clockwise")
                }
            }
            .padding([.horizontal, .top], 24)
            .padding(.bottom, 12)

            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red).padding(.horizontal, 24).padding(.bottom, 12)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    revenueSection
                    if !events.isEmpty || !isLoading {
                        productTotalsSection
                        dailyHistorySection
                        devicesSection
                    }
                }
                .padding(24)
            }
        }
        .task { await load() }
    }

    // MARK: - Revenue (from SalesLog — the same data as tab-ul "Clienți")

    private struct ProductRevenue: Identifiable {
        let id: String // product name (SalesLog keeps no separate product_id column)
        let productName: String
        let count: Int
        let totalEUR: Double
    }

    private var salesEntries: [SalesLog.Entry] { SalesLog.readAll() }

    private var totalRevenueEUR: Double { salesEntries.reduce(0) { $0 + $1.priceEUR } }

    private var revenueByProduct: [ProductRevenue] {
        var totals: [String: (count: Int, sum: Double)] = [:]
        for entry in salesEntries {
            totals[entry.productName, default: (0, 0)].count += 1
            totals[entry.productName, default: (0, 0)].sum += entry.priceEUR
        }
        return totals.map { ProductRevenue(id: $0.key, productName: $0.key, count: $0.value.count, totalEUR: $0.value.sum) }
            .sorted { $0.totalEUR > $1.totalEUR }
    }

    private var mostPopularByLicenses: ProductRevenue? {
        revenueByProduct.max { $0.count < $1.count }
    }

    private var revenueSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Venituri").font(.headline)
            HStack(spacing: 24) {
                statCard(title: "Venituri totale", value: totalRevenueEUR.formatted(.currency(code: "EUR")))
                statCard(title: "Licențe acordate", value: "\(salesEntries.count)")
                statCard(title: "Cel mai popular", value: mostPopularByLicenses?.productName ?? "—")
            }
            if revenueByProduct.isEmpty {
                Text("Niciun cod generat încă.").foregroundStyle(.secondary)
            } else {
                Table(revenueByProduct) {
                    TableColumn("Produs") { row in Text(row.productName) }
                    TableColumn("Licențe") { row in Text("\(row.count)") }
                    TableColumn("Venituri") { row in Text(row.totalEUR.formatted(.currency(code: "EUR"))) }
                }
                .frame(minHeight: CGFloat(min(revenueByProduct.count, 8)) * 28 + 40)
            }
        }
    }

    private func statCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title3).fontWeight(.semibold)
        }
        .padding(12)
        .frame(minWidth: 140, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor)))
    }

    // MARK: - Totals per product

    private struct ProductTotal: Identifiable {
        let id: String // product_id
        let productName: String
        let count: Int
    }

    private var productTotals: [ProductTotal] {
        var counts: [String: (name: String, count: Int)] = [:]
        for event in events {
            counts[event.product_id, default: (event.product_name, 0)].count += 1
        }
        return counts.map { ProductTotal(id: $0.key, productName: $0.value.name, count: $0.value.count) }
            .sorted { $0.count > $1.count }
    }

    private var productTotalsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Descărcări totale per produs").font(.headline)
            if productTotals.isEmpty {
                Text("Niciun eveniment de descărcare încă.").foregroundStyle(.secondary)
            } else {
                Table(productTotals) {
                    TableColumn("Produs") { row in Text(row.productName) }
                    TableColumn("Descărcări") { row in Text("\(row.count)") }
                }
                .frame(minHeight: CGFloat(min(productTotals.count, 8)) * 28 + 40)
            }
        }
    }

    // MARK: - Daily history

    private struct DailyCount: Identifiable {
        let id: Date // the day itself
        var day: Date { id }
        let count: Int
    }

    private var dailyCounts: [DailyCount] {
        let calendar = Calendar.current
        var counts: [Date: Int] = [:]
        for event in events {
            guard let date = SupabaseDate.parse(event.downloaded_at) else { continue }
            let day = calendar.startOfDay(for: date)
            counts[day, default: 0] += 1
        }
        return counts.map { DailyCount(id: $0.key, count: $0.value) }.sorted { $0.day > $1.day }
    }

    private var dailyHistorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Descărcări pe zi").font(.headline)
            if dailyCounts.isEmpty {
                Text("Niciun eveniment de descărcare încă.").foregroundStyle(.secondary)
            } else {
                Table(dailyCounts) {
                    TableColumn("Dată") { row in Text(shortDate(row.day)) }
                    TableColumn("Descărcări") { row in Text("\(row.count)") }
                }
                .frame(minHeight: CGFloat(min(dailyCounts.count, 10)) * 28 + 40)
            }
        }
    }

    // MARK: - Devices / customers

    private struct DeviceRow: Identifiable {
        let id: String
        let name: String
        let email: String
        let machineID: String
        let firstSeen: String
        let downloadCount: Int
    }

    private var deviceRows: [DeviceRow] {
        var downloadCountByMachine: [String: Int] = [:]
        for event in events {
            guard let machineID = event.machine_id else { continue }
            downloadCountByMachine[machineID, default: 0] += 1
        }
        let rows = devices.map { device in
            DeviceRow(
                id: device.machine_id,
                name: device.name?.isEmpty == false ? device.name! : "—",
                email: device.email?.isEmpty == false ? device.email! : "—",
                machineID: device.machine_id,
                firstSeen: shortDate(SupabaseDate.parse(device.first_seen_at)),
                downloadCount: downloadCountByMachine[device.machine_id] ?? 0
            )
        }
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return rows }
        return rows.filter {
            $0.name.localizedCaseInsensitiveContains(trimmed) || $0.email.localizedCaseInsensitiveContains(trimmed)
        }
    }

    private var devicesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Clienți înregistrați (\(devices.count))").font(.headline)
                Spacer()
                TextField("Caută nume/email…", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 240)
            }
            if deviceRows.isEmpty {
                Text(devices.isEmpty ? "Niciun client înregistrat încă — înregistrarea e opțională la prima lansare." : "Niciun rezultat.")
                    .foregroundStyle(.secondary)
            } else {
                Table(deviceRows) {
                    TableColumn("Nume") { row in Text(row.name) }
                    TableColumn("Email") { row in Text(row.email) }
                    TableColumn("ID Mașină") { row in
                        Text(row.machineID).font(.system(.caption, design: .monospaced))
                    }
                    TableColumn("Prima dată văzut") { row in Text(row.firstSeen) }
                    TableColumn("Descărcări") { row in Text("\(row.downloadCount)") }
                }
                .frame(minHeight: CGFloat(min(deviceRows.count, 10)) * 28 + 40)
            }
        }
    }

    // MARK: - Loading

    private func load() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            async let devicesTask = AnalyticsAdminClient.fetchDevices()
            async let eventsTask = AnalyticsAdminClient.fetchDownloadEvents()
            devices = try await devicesTask
            events = try await eventsTask
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func shortDate(_ date: Date?) -> String {
        guard let date else { return "—" }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
