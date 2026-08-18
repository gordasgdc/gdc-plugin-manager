import SwiftUI
import AppKit
import GDCPluginManagerCore

enum SidebarSection: Hashable {
    case all
    case type(PluginType)
    case license
    case help
}

struct ContentView: View {
    @StateObject private var catalog = CatalogService.shared
    @StateObject private var installs = InstallManager.shared
    @ObservedObject private var license = LicenseManager.shared
    @StateObject private var updateChecker = UpdateChecker.shared

    @State private var selection: SidebarSection? = .all
    @State private var resolveWarningVisible = false

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Label(L.t("sidebar.all"), systemImage: "square.grid.2x2")
                    .tag(SidebarSection.all)
                ForEach(PluginType.allCases) { type in
                    Label(type.label, systemImage: symbol(for: type))
                        .tag(SidebarSection.type(type))
                }
                Divider()
                Label(L.t("sidebar.license"), systemImage: "key.fill")
                    .tag(SidebarSection.license)
                Label(L.t("sidebar.help"), systemImage: "questionmark.circle")
                    .tag(SidebarSection.help)
            }
            .navigationSplitViewColumnWidth(180)
        } detail: {
            VStack(spacing: 0) {
                if let update = updateChecker.availableUpdate {
                    UpdateBanner(update: update)
                }
                Group {
                    switch selection {
                    case .license:
                        LicensePane()
                    case .help:
                        HelpView()
                    case .all, .none:
                        CatalogGrid(items: catalog.items)
                    case .type(let type):
                        CatalogGrid(items: catalog.items.filter { $0.type == type })
                    }
                }
            }
        }
        .navigationTitle(L.t("app.name"))
        .toolbar {
            ToolbarItem {
                Button {
                    Task {
                        await catalog.refresh()
                        await updateChecker.check()
                    }
                } label: {
                    Label(L.t("catalog.refresh"), systemImage: "arrow.clockwise")
                }
            }
        }
        .environmentObject(catalog)
        .environmentObject(installs)
        .task {
            await catalog.refresh()
            await updateChecker.check()
        }
    }

    private func symbol(for type: PluginType) -> String {
        switch type {
        case .dctl: return "wand.and.stars"
        case .lut: return "eyedropper.halffull"
        case .fuse: return "puzzlepiece.extension"
        }
    }
}

private struct UpdateBanner: View {
    let update: UpdateInfo
    @ObservedObject private var updateChecker = UpdateChecker.shared

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.down.circle.fill").foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(L.t("update.title")).font(.subheadline).fontWeight(.semibold)
                Text("v\(update.version)" + (update.changes.map { " — \($0)" } ?? ""))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            if let urlString = update.download_url["mac"], let url = URL(string: urlString) {
                Button(L.t("update.download")) { NSWorkspace.shared.open(url) }
            }
            Button(L.t("update.dismiss")) { updateChecker.dismiss() }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color.accentColor.opacity(0.12))
    }
}

private struct CatalogGrid: View {
    let items: [PluginItem]
    @EnvironmentObject private var catalog: CatalogService

    private let columns = [GridItem(.adaptive(minimum: 220, maximum: 280), spacing: 14)]

    var body: some View {
        ScrollView {
            if catalog.isLoading && items.isEmpty {
                ProgressView(L.t("catalog.loading")).padding(40)
            } else if let error = catalog.loadError, items.isEmpty {
                Text(error).foregroundStyle(.secondary).padding(40)
            } else if items.isEmpty {
                Text(L.t("catalog.empty")).foregroundStyle(.secondary).padding(40)
            } else {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(items) { item in
                        PluginCard(item: item)
                    }
                }
                .padding(16)
            }
        }
    }
}

private struct PluginCard: View {
    let item: PluginItem
    @EnvironmentObject private var installs: InstallManager
    @ObservedObject private var license = LicenseManager.shared

    @State private var isBusy = false
    @State private var errorMessage: String?
    @State private var showResolveWarning = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Image(systemName: item.iconSymbol ?? "shippingbox")
                    .font(.system(size: 22))
                    .foregroundStyle(.tint)
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Text(item.priceDisplay)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(L.t("card.donation"))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            Text(item.name).font(.headline)
            Text(item.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
            Text("\(L.t("card.version")) \(item.version)")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            if let errorMessage {
                Text(errorMessage).font(.caption2).foregroundStyle(.red)
            }

            actionButton
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(.background.secondary))
        .alert(L.t("resolve.running.title"), isPresented: $showResolveWarning) {
            Button(L.t("resolve.running.ok")) {}
        } message: {
            Text(L.t("resolve.running.body"))
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        if !license.isUnlocked(for: item) {
            Button(L.t("card.buy")) { NSWorkspace.shared.open(buyURL) }
        } else if isBusy {
            ProgressView().controlSize(.small)
        } else if installs.hasUpdate(item) {
            HStack {
                Button(L.t("card.update")) { runGuarded { install() } }
                Button(L.t("card.remove"), role: .destructive) { runGuarded { remove() } }
            }
        } else if installs.isInstalled(item) {
            HStack {
                Label(L.t("card.installed"), systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
                Spacer()
                Button(L.t("card.remove"), role: .destructive) { runGuarded { remove() } }
            }
        } else {
            Button(L.t("card.install")) { runGuarded { install() } }
        }
    }

    private var buyURL: URL {
        let text = "Salut! Vreau să deblochez \(item.name) cu o donație de \(item.priceDisplay). ID calculator: \(MachineID.display)"
        return URL(string: "https://wa.me/34643109970?text=" + text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)!
    }

    private func runGuarded(_ action: @escaping () -> Void) {
        if ResolveProcessCheck.isRunning {
            showResolveWarning = true
            return
        }
        action()
    }

    private func install() {
        errorMessage = nil
        isBusy = true
        Task {
            do {
                try await installs.install(item)
            } catch {
                errorMessage = error.localizedDescription
            }
            isBusy = false
        }
    }

    private func remove() {
        errorMessage = nil
        do {
            try installs.remove(item)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
