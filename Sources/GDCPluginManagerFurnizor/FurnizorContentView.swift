import SwiftUI

enum FurnizorSection: Hashable {
    case publish
    case generateSerial
    case salesHistory
    case analytics
    case courses
    case educationalResources
    case apps
}

struct FurnizorContentView: View {
    @State private var selection: FurnizorSection? = .publish
    @StateObject private var tokenStatus = GitHubTokenStatus.shared
    @State private var showTokenPopover = false
    @State private var showRenewalGuide = false
    @State private var bannerDismissed = false

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Label("Publică produs", systemImage: "arrow.up.doc").tag(FurnizorSection.publish)
                Label("Generează serial", systemImage: "key").tag(FurnizorSection.generateSerial)
                Label("Clienți", systemImage: "person.2").tag(FurnizorSection.salesHistory)
                Label("Statistici", systemImage: "chart.bar").tag(FurnizorSection.analytics)
                Divider()
                Label("Cursuri", systemImage: "graduationcap").tag(FurnizorSection.courses)
                Label("Materiale", systemImage: "book").tag(FurnizorSection.educationalResources)
                Label("Aplicații", systemImage: "square.grid.2x2").tag(FurnizorSection.apps)
            }
            .navigationSplitViewColumnWidth(200)
        } detail: {
            VStack(spacing: 0) {
                if !bannerDismissed, tokenStatus.severity == .warning || tokenStatus.severity == .critical {
                    tokenBanner
                }
                switch selection {
                case .publish, .none:
                    PublishView()
                case .generateSerial:
                    GenerateSerialView()
                case .salesHistory:
                    SalesHistoryView()
                case .analytics:
                    AnalyticsView()
                case .courses:
                    PublishCourseView()
                case .educationalResources:
                    PublishEducationalResourceView()
                case .apps:
                    PublishAppView()
                }
            }
        }
        .navigationTitle("GDC Plugin Manager Furnizor")
        .toolbar {
            ToolbarItem {
                Button { showTokenPopover = true } label: {
                    Label(tokenLabel, systemImage: "key.fill")
                        .foregroundStyle(tokenColor)
                }
                .popover(isPresented: $showTokenPopover) {
                    tokenPopover
                }
            }
        }
        .sheet(isPresented: $showRenewalGuide) {
            TokenRenewalGuideView()
        }
        .task {
            await tokenStatus.check()
        }
    }

    private var tokenLabel: String {
        if let days = tokenStatus.daysRemaining {
            return days >= 0 ? "Token GitHub: \(days) zile" : "Token GitHub: EXPIRAT"
        }
        return "Token GitHub"
    }

    private var tokenColor: Color {
        switch tokenStatus.severity {
        case .critical: return .red
        case .warning: return .orange
        case .ok: return .secondary
        case .unknown: return .secondary
        }
    }

    private var tokenPopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let expiresAt = tokenStatus.expiresAt {
                let days = tokenStatus.daysRemaining ?? 0
                Text(days >= 0 ? "Token-ul GitHub expiră în \(days) zile" : "Token-ul GitHub a EXPIRAT")
                    .font(.headline)
                    .foregroundStyle(tokenColor)
                Text("Data exactă: \(expiresAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption).foregroundStyle(.secondary)
            } else if tokenStatus.checkFailed {
                Text("Nu am putut verifica data de expirare acum.")
                    .font(.callout).foregroundStyle(.secondary)
            } else {
                ProgressView().controlSize(.small)
            }
            Button("Cum reînnoiesc token-ul?") {
                showTokenPopover = false
                showRenewalGuide = true
            }
            Button("Reverifică") { Task { await tokenStatus.check() } }
                .controlSize(.small)
        }
        .padding(16)
        .frame(width: 280)
    }

    private var tokenBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: tokenStatus.severity == .critical ? "exclamationmark.triangle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(tokenColor)
            VStack(alignment: .leading, spacing: 2) {
                Text("Atenție: token-ul GitHub expiră în \(tokenStatus.daysRemaining ?? 0) zile")
                    .font(.subheadline).fontWeight(.semibold)
                Text("După expirare, clienții nu mai pot descărca produse.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Cum reînnoiesc?") { showRenewalGuide = true }
            Button("Am înțeles") { bannerDismissed = true }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background((tokenStatus.severity == .critical ? Color.red : Color.orange).opacity(0.12))
    }
}
