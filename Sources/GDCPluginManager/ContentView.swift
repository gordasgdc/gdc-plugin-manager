import SwiftUI

enum SidebarSection: Hashable {
    case all
    case type(PluginType)
    case license
}

struct ContentView: View {
    @StateObject private var catalog = CatalogService.shared
    @StateObject private var installs = InstallManager.shared
    @ObservedObject private var license = LicenseManager.shared

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
                    .foregroundStyle(license.isUnlocked ? Color.primary : Color.orange)
            }
            .navigationSplitViewColumnWidth(180)
        } detail: {
            Group {
                switch selection {
                case .license, .none:
                    LicensePane()
                case .all:
                    CatalogGrid(items: catalog.items)
                case .type(let type):
                    CatalogGrid(items: catalog.items.filter { $0.type == type })
                }
            }
        }
        .navigationTitle(L.t("app.name"))
        .toolbar {
            ToolbarItem {
                Button {
                    Task { await catalog.refresh() }
                } label: {
                    Label(L.t("catalog.refresh"), systemImage: "arrow.clockwise")
                }
            }
        }
        .environmentObject(catalog)
        .environmentObject(installs)
        .task {
            await catalog.refresh()
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
    @State private var pendingAction: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: item.iconSymbol ?? "shippingbox")
                .font(.system(size: 22))
                .foregroundStyle(.tint)
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
        if !license.isUnlocked {
            Button(L.t("card.install")) {}
                .disabled(true)
                .help(L.t("trial.locked.body"))
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
