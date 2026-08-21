import SwiftUI
import AppKit
import GDCPluginManagerCore

enum SidebarSection: Hashable {
    case all
    case type(PluginType)
    case courses
    case educationalResources
    case events
    case partnerStores
    case apps
    case license
    case help
}

struct ContentView: View {
    @StateObject private var catalog = CatalogService.shared
    @StateObject private var installs = InstallManager.shared
    @ObservedObject private var license = LicenseManager.shared
    @StateObject private var updateChecker = UpdateChecker.shared
    // Observed here (the root view) so a language switch, made from
    // LicensePane's picker, redraws the entire app — not just that pane.
    @ObservedObject private var languageStore = LanguageStore.shared

    @State private var selection: SidebarSection? = .all
    @State private var resolveWarningVisible = false
    @State private var showOnboarding = false

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Label(L.t("sidebar.all"), systemImage: "square.grid.2x2")
                    .tag(SidebarSection.all)
                ForEach(PluginType.allCases) { type in
                    Label {
                        Text(type.label)
                    } icon: {
                        Image(systemName: type.defaultSymbol).foregroundStyle(type.tintColor)
                    }
                    .tag(SidebarSection.type(type))
                }
                Divider()
                Label(L.t("sidebar.courses"), systemImage: "graduationcap")
                    .tag(SidebarSection.courses)
                Label(L.t("sidebar.educationalResources"), systemImage: "book")
                    .tag(SidebarSection.educationalResources)
                Label(L.t("sidebar.events"), systemImage: "calendar")
                    .tag(SidebarSection.events)
                Label(L.t("sidebar.partnerStores"), systemImage: "storefront")
                    .tag(SidebarSection.partnerStores)
                Label(L.t("sidebar.apps"), systemImage: "app.badge")
                    .tag(SidebarSection.apps)
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
                    case .courses:
                        CoursesGrid(courses: catalog.courses)
                    case .educationalResources:
                        EducationalResourcesGrid(resources: catalog.educationalResources)
                    case .events:
                        EventsGrid(events: catalog.events)
                    case .partnerStores:
                        PartnerStoresGrid(stores: catalog.partnerStores)
                    case .apps:
                        AppsGrid(apps: catalog.apps)
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
            if !UserDefaults.standard.bool(forKey: "gdcpm_onboarded") {
                showOnboarding = true
            }
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView(isPresented: $showOnboarding)
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
    @State private var statusMessage: String?
    @State private var showResolveWarning = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            typeBadge
            HStack(alignment: .top) {
                Image(systemName: item.iconSymbol ?? item.type.defaultSymbol)
                    .font(.system(size: 22))
                    .foregroundStyle(item.type.tintColor)
                Spacer()
                // Stacked vertically (info button above the price/status
                // badge, not on top of it) — an absolute corner overlay
                // here used to land right on top of the badge.
                VStack(alignment: .trailing, spacing: 6) {
                    infoButton
                    if item.isFree && item.isTrial {
                        Text(L.t("card.trial"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.blue)
                    } else if item.isFree {
                        Text(L.t("card.free"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.green)
                    } else {
                        VStack(alignment: .trailing, spacing: 0) {
                            Text(item.priceDisplay)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(L.t("card.donation"))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
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
            if let statusMessage {
                Text(statusMessage).font(.caption2).foregroundStyle(.blue)
            }

            actionButton
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(.background.secondary))
        .alert(resolveWarningTitle, isPresented: $showResolveWarning) {
            Button(L.t("resolve.running.ok")) {}
        } message: {
            Text(resolveWarningBody)
        }
    }

    /// Centered tag at the top of the card naming the product's type
    /// (LUT / DCTL / Fuse / PowerGrade / OFX) — a quick, consistent way
    /// to tell categories apart in a mixed grid.
    private var typeBadge: some View {
        Text(item.type.label.uppercased())
            .font(.system(size: 9, weight: .bold))
            .tracking(0.5)
            .foregroundStyle(item.type.tintColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(item.type.tintColor.opacity(0.15)))
            .frame(maxWidth: .infinity, alignment: .center)
    }

    /// Tutorial link, editable anytime from Furnizor without touching the
    /// product's files — hidden entirely (not disabled) until one exists,
    /// so a not-yet-recorded tutorial doesn't clutter every card.
    @ViewBuilder
    private var infoButton: some View {
        if let urlString = item.youtubeURL, let url = URL(string: urlString) {
            Button { NSWorkspace.shared.open(url) } label: {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help(L.t("card.tutorial"))
        }
    }

    private var resolveWarningTitle: String {
        item.type == .powerGrade ? L.t("resolve.notrunning.title") : L.t("resolve.running.title")
    }

    private var resolveWarningBody: String {
        item.type == .powerGrade ? L.t("resolve.notrunning.body") : L.t("resolve.running.body")
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
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
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
        return WhatsAppLink.url(text: text)
    }

    private func runGuarded(_ action: @escaping () -> Void) {
        // Every other type must be closed (it only reads its plugin
        // folder at launch); PowerGrade is the opposite — it needs a
        // running, scriptable Resolve to import into (see
        // PowerGradeImporter.swift). Without Resolve running, the action
        // still proceeds for PowerGrade — it just falls back to staging
        // the files with a manual-import message instead of failing.
        if item.type != .powerGrade && ResolveProcessCheck.isRunning {
            showResolveWarning = true
            return
        }
        if item.type == .powerGrade && !ResolveProcessCheck.isRunning {
            showResolveWarning = true
        }
        action()
    }

    private func install() {
        errorMessage = nil
        statusMessage = nil
        isBusy = true
        Task {
            do {
                let outcome = try await installs.install(item)
                AnalyticsClient.logDownload(productID: item.id, productName: item.name)
                switch outcome {
                case .installedToGallery(let albumName):
                    statusMessage = String(format: L.t("powergrade.imported"), albumName)
                case .installedNeedsManualStep(let folder):
                    statusMessage = String(format: L.t("powergrade.manualstep"), folder.path)
                case .installed:
                    break
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isBusy = false
        }
    }

    private func remove() {
        errorMessage = nil
        statusMessage = nil
        do {
            let outcome = try installs.remove(item)
            if item.type == .powerGrade, outcome == .removedNeedsManualGalleryCleanup {
                statusMessage = L.t("powergrade.manualremove")
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct CoursesGrid: View {
    let courses: [Course]

    private let columns = [GridItem(.adaptive(minimum: 260, maximum: 340), spacing: 14)]

    var body: some View {
        ScrollView {
            if courses.isEmpty {
                Text(L.t("courses.empty")).foregroundStyle(.secondary).padding(40)
            } else {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(courses) { course in
                        CourseCard(course: course)
                    }
                }
                .padding(16)
            }
        }
    }
}

private struct CourseCard: View {
    let course: Course

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "graduationcap.fill")
                .font(.system(size: 22))
                .foregroundStyle(.tint)
            Text(course.name).font(.headline)
            Text(course.description)
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(course.options) { option in
                    HStack {
                        Text(option.label).font(.caption)
                        Spacer()
                        Text(option.priceDisplay).font(.caption).foregroundStyle(.secondary)
                        Button(L.t("courses.contact")) { NSWorkspace.shared.open(contactURL(for: option)) }
                            .controlSize(.small)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(.background.secondary))
    }

    private func contactURL(for option: CourseOption) -> URL {
        let text = String(format: L.t("courses.contact.message"), course.name, option.label, option.priceDisplay)
        return WhatsAppLink.url(text: text)
    }
}

private struct EducationalResourcesGrid: View {
    let resources: [EducationalResource]

    private let columns = [GridItem(.adaptive(minimum: 260, maximum: 340), spacing: 14)]

    var body: some View {
        ScrollView {
            if resources.isEmpty {
                Text(L.t("resources.empty")).foregroundStyle(.secondary).padding(40)
            } else {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(resources) { resource in
                        EducationalResourceCard(resource: resource)
                    }
                }
                .padding(16)
            }
        }
    }
}

private struct EducationalResourceCard: View {
    let resource: EducationalResource

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "book.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.tint)
                Spacer()
                Text(resource.kind.label)
                    .font(.caption2).fontWeight(.semibold)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(.tint.opacity(0.18)))
                if let urlString = resource.youtubeURL, let url = URL(string: urlString) {
                    Button { NSWorkspace.shared.open(url) } label: {
                        Image(systemName: "play.circle")
                    }
                    .buttonStyle(.plain)
                }
            }
            Text(resource.name).font(.headline)
            Text(resource.description)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            if let url = URL(string: resource.externalURL) {
                Button(L.t("resources.buy")) { NSWorkspace.shared.open(url) }
                    .controlSize(.small)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 140, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(.background.secondary))
    }
}

private struct EventsGrid: View {
    let events: [Event]

    private let columns = [GridItem(.adaptive(minimum: 260, maximum: 340), spacing: 14)]

    var body: some View {
        ScrollView {
            if events.isEmpty {
                Text(L.t("events.empty")).foregroundStyle(.secondary).padding(40)
            } else {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(events) { event in
                        EventCard(event: event)
                    }
                }
                .padding(16)
            }
        }
    }
}

private struct EventCard: View {
    let event: Event

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "calendar")
                    .font(.system(size: 22))
                    .foregroundStyle(.tint)
                Spacer()
                if let urlString = event.youtubeURL, let url = URL(string: urlString) {
                    Button { NSWorkspace.shared.open(url) } label: {
                        Image(systemName: "play.circle")
                    }
                    .buttonStyle(.plain)
                }
            }
            Text(event.title).font(.headline)
            Text("\(event.dateDisplay) · \(event.location)")
                .font(.caption).foregroundStyle(.secondary)
            Text(event.description)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            if let url = URL(string: event.externalURL) {
                Button(L.t("events.details")) { NSWorkspace.shared.open(url) }
                    .controlSize(.small)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 140, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(.background.secondary))
    }
}

private struct PartnerStoresGrid: View {
    let stores: [PartnerStore]

    private let columns = [GridItem(.adaptive(minimum: 260, maximum: 340), spacing: 14)]

    var body: some View {
        ScrollView {
            if stores.isEmpty {
                Text(L.t("stores.empty")).foregroundStyle(.secondary).padding(40)
            } else {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(stores) { store in
                        PartnerStoreCard(store: store)
                    }
                }
                .padding(16)
            }
        }
    }
}

private struct PartnerStoreCard: View {
    let store: PartnerStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "storefront.fill")
                .font(.system(size: 22))
                .foregroundStyle(.tint)
            Text(store.name).font(.headline)
            Text(store.description)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            if let url = URL(string: store.url) {
                Button(L.t("stores.visit")) { NSWorkspace.shared.open(url) }
                    .controlSize(.small)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(.background.secondary))
    }
}

private struct AppsGrid: View {
    let apps: [AppLink]

    private let columns = [GridItem(.adaptive(minimum: 220, maximum: 280), spacing: 14)]

    var body: some View {
        ScrollView {
            if apps.isEmpty {
                Text(L.t("apps.empty")).foregroundStyle(.secondary).padding(40)
            } else {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(apps) { app in
                        AppCard(app: app)
                    }
                }
                .padding(16)
            }
        }
    }
}

private struct AppCard: View {
    let app: AppLink

    /// Apps aren't a `PluginType` case, so they get their own fixed tint
    /// here instead of `PluginType.tintColor` — matches the blue Cristi
    /// asked for, distinct from every plugin category's color.
    private let tint = Color.blue

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L.t("apps.badge"))
                .font(.system(size: 9, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(tint)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(tint.opacity(0.15)))
                .frame(maxWidth: .infinity, alignment: .center)
            Image(systemName: "app.badge")
                .font(.system(size: 22))
                .foregroundStyle(tint)
            Text(app.name).font(.headline)
            Spacer(minLength: 0)
            if let url = URL(string: app.url) {
                Button(L.t("apps.open")) { NSWorkspace.shared.open(url) }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(.background.secondary))
        .overlay(alignment: .topTrailing) { infoButton }
    }

    @ViewBuilder
    private var infoButton: some View {
        if let urlString = app.youtubeURL, let url = URL(string: urlString) {
            Button { NSWorkspace.shared.open(url) } label: {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                    .background(Circle().fill(.background).frame(width: 16, height: 16))
            }
            .buttonStyle(.plain)
            .padding(8)
            .help(L.t("card.tutorial"))
        }
    }
}
