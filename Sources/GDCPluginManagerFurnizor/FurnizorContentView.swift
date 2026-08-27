import SwiftUI

enum FurnizorSection: Hashable {
    case publish
    case generateSerial
    case revocations
    case salesHistory
    case analytics
    case courses
    case educationalResources
    case events
    case partnerStores
    case serviceCenters
    case apps
    case audio
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
                Label("Revocări licențe", systemImage: "xmark.shield").tag(FurnizorSection.revocations)
                Label("Clienți", systemImage: "person.2").tag(FurnizorSection.salesHistory)
                Label("Statistici", systemImage: "chart.bar").tag(FurnizorSection.analytics)
                Divider()
                Label("Cursuri", systemImage: "graduationcap").tag(FurnizorSection.courses)
                Label("Materiale", systemImage: "book").tag(FurnizorSection.educationalResources)
                Label("Evenimente", systemImage: "calendar").tag(FurnizorSection.events)
                Label("Magazine partenere", systemImage: "storefront").tag(FurnizorSection.partnerStores)
                Label("Service & Reparații", systemImage: "wrench.and.screwdriver").tag(FurnizorSection.serviceCenters)
                Label("Aplicații", systemImage: "square.grid.2x2").tag(FurnizorSection.apps)
                Label("Audio", systemImage: "waveform").tag(FurnizorSection.audio)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 340)
            .safeAreaInset(edge: .bottom) {
                // Versiune vizibila in UI, obligatoriu si pe Furnizor
                // (cerut explicit 2026-08-26) - lipsea complet, Info-Furnizor.plist
                // era blocat la 1.0.0 din prima zi, in ciuda a zeci de
                // functionalitati noi adaugate de-atunci (Revocare, Durata
                // flexibila, Clienti/Tracker, etc.).
                Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 8)
            }
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
                case .revocations:
                    RevocationsView()
                case .salesHistory:
                    SalesHistoryView()
                case .analytics:
                    AnalyticsView()
                case .courses:
                    PublishCourseView()
                case .educationalResources:
                    PublishEducationalResourceView()
                case .events:
                    PublishEventView()
                case .partnerStores:
                    PublishPartnerStoreView()
                case .serviceCenters:
                    PublishServiceCenterView()
                case .apps:
                    PublishAppView()
                case .audio:
                    PublishAudioView()
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
