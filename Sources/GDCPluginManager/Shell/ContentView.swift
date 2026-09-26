import SwiftUI
import AppKit
import GDCPluginManagerCore

struct ContentView: View {
    @StateObject private var catalog = CatalogService.shared
    @StateObject private var installs = InstallManager.shared
    @ObservedObject private var license = LicenseManager.shared
    @StateObject private var updateChecker = UpdateChecker.shared
    // Observed here (the root view) so a language switch, made from
    // LicensePane's picker, redraws the entire app — not just that pane.
    @ObservedObject private var languageStore = LanguageStore.shared

    @State private var selection: SidebarSection? = .all

    /// Deschide secțiunea din care face parte rubrica dată. Nu strânge
    /// niciodată altceva: o secțiune deschisă manual de utilizator rămâne
    /// deschisă, fiindcă a deschis-o el.
    private func expandSection(containing section: SidebarSection?) {
        guard let section else { return }
        switch section {
        case .all, .type:
            expandResolveInstall = true
        case .audio, .download:
            expandDownloadResources = true
        case .courses, .educationalResources, .tutorials, .events,
             .partnerOffers, .bundles, .partnerStores, .serviceCenters, .community:
            expandCommunity = true
        case .apps, .android, .myApps:
            expandEcosystem = true
        case .license, .help:
            expandAccount = true
        case .developer:
            expandDeveloper = true
        }
    }

    // Secțiuni pliabile în bara laterală (2026-09-14). @AppStorage, nu @State:
    // preferința trebuie să supraviețuiască repornirii — altfel fiecare
    // pornire ar reface aceleași click-uri de restrângere.
    //
    // Implicit doar prima e deschisă: meniul pornește compact, dar niciodată
    // complet gol — un sidebar în care nu se vede nimic la pornire pare stricat.
    @AppStorage("sidebar.expanded.resolveInstall") private var expandResolveInstall = true
    @AppStorage("sidebar.expanded.downloadResources") private var expandDownloadResources = false
    @AppStorage("sidebar.expanded.community") private var expandCommunity = false
    @AppStorage("sidebar.expanded.ecosystem") private var expandEcosystem = false
    @AppStorage("sidebar.expanded.account") private var expandAccount = false
    @AppStorage("sidebar.expanded.developer") private var expandDeveloper = false
    @State private var showOnboarding = false
    @State private var missingDependencies: [SystemDependency] = []
    @State private var allDependencies: [SystemDependency] = []
    @State private var showDependencyPanel = false
    @State private var showManualUpdateCheckAlert = false
    @State private var manualUpdateCheckMessage = ""
    @State private var globalSearchText = ""

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    /// Nume din TOATE categoriile — folosit ca sugestii live pentru bara
    /// de căutare globală (istoricul recent se adaugă separat, în SearchBar).
    /// Fiecare categorie nouă își are cheia ei de catalog — vezi
    /// `Catalog.pdfResources` / `Catalog.scriptResources` pentru motiv.
    private func resourcesFor(_ category: DownloadCategory) -> [DownloadableResource] {
        switch category {
        case .pdf: return catalog.pdfResources
        case .script: return catalog.scriptResources
        default: return catalog.downloadableResources
        }
    }

    /// Toate produsele instalabile, indiferent în ce cheie de catalog stau.
    /// Scripturile au cheia lor (`scriptItems`) din motive de
    /// retrocompatibilitate, dar pentru UI sunt produse ca oricare altele.
    private var allInstallableItems: [PluginItem] { catalog.items + catalog.scriptItems }

    private var globalSearchSuggestions: [String] {
        // Acumulator, nu un lung lanț de `+` (Swift a depășit timeout-ul de
        // type-check pe expresia unică după adăugarea celui de-al 12-lea
        // termen — vezi comentariul de mai jos despre `detailContent`).
        var names: [String] = allInstallableItems.map(\.name)
        names += catalog.apps.map(\.name)
        names += catalog.courses.map(\.name)
        names += catalog.audioTracks.map(\.name)
        names += catalog.events.map(\.title)
        names += catalog.educationalResources.map(\.name)
        names += catalog.tutorials.map(\.title)
        names += catalog.partnerStores.map(\.name)
        names += catalog.serviceCenters.map(\.name)
        names += catalog.downloadableResources.map(\.name)
        names += catalog.pdfResources.map(\.name)
        names += catalog.scriptResources.map(\.name)
        names += catalog.partnerOffers.map(\.brandName)
        names += catalog.productBundles.map(\.name)
        return names
    }

    // Extras din body — switch cu multe cazuri inline facea type-check-ul
    // Swift sa depaseasca timeout-ul ("unable to type-check in reasonable
    // time") dupa adaugarea cazului .serviceCenters.
    @ViewBuilder
    private var detailContent: some View {
        switch selection {
        case .license:
            LicensePane()
        case .help:
            HelpView()
        case .courses:
            // Etapa 4 (2026-08-29): filtrat pe valabilitate temporală —
            // conținut nescheduled (nil) rămâne mereu vizibil, identic cu
            // înainte.
            CoursesGrid(courses: catalog.courses.filter { $0.scheduling?.isActiveNow ?? true })
        case .educationalResources:
            EducationalResourcesGrid(resources: catalog.educationalResources.filter { $0.scheduling?.isActiveNow ?? true })
        case .community:
            CommunityGrid(channels: catalog.communityChannels.publishedSorted)
        case .tutorials:
            TutorialsGrid(tutorials: catalog.tutorials.filter { $0.scheduling?.isActiveNow ?? true })
        case .events:
            EventsGrid(events: catalog.events.filter { $0.scheduling?.isActiveNow ?? true })
        case .partnerOffers:
            PartnerOffersGrid(offers: catalog.partnerOffers.filter { $0.scheduling?.isActiveNow ?? true })
        case .bundles:
            BundleGrid(bundles: catalog.productBundles.filter { $0.scheduling?.isActiveNow ?? true }, catalog: catalog)
        case .partnerStores:
            PartnerStoresGrid(stores: catalog.partnerStores.filter { $0.scheduling?.isActiveNow ?? true })
        case .serviceCenters:
            ServiceCentersGrid(centers: catalog.serviceCenters.filter { $0.scheduling?.isActiveNow ?? true })
        case .apps:
            AppsGrid(apps: catalog.apps.filter {
                ($0.scheduling?.isActiveNow ?? true) && !$0.resolvedAccess.tags.contains(DeveloperShelf.appsTag)
            })
        case .developer(let shelf):
            switch shelf {
            case .apps:
                AppsGrid(apps: catalog.apps.filter {
                    ($0.scheduling?.isActiveNow ?? true) && $0.resolvedAccess.tags.contains(DeveloperShelf.appsTag)
                })
            case .scripts, .sdk:
                DownloadResourceGrid(resources: (catalog.downloadableResources + catalog.scriptResources + catalog.pdfResources)
                    .filter { ($0.scheduling?.isActiveNow ?? true) && $0.resolvedAccess.tags.contains(shelf.tag) })
            }
        case .myApps:
            MyAppsGrid()
        case .audio:
            AudioGrid(tracks: catalog.audioTracks.filter { $0.scheduling?.isActiveNow ?? true })
        case .download(let category):
            // PDF-urile stau intr-o cheie separata de catalog (vezi
            // Catalog.pdfResources) — nu se filtreaza din lista comuna.
            DownloadResourceGrid(resources: resourcesFor(category)
                .filter { $0.category == category && ($0.scheduling?.isActiveNow ?? true) })
        case .android:
            MobileAppPane()
        case .all, .none:
            CatalogGrid(items: allInstallableItems.filter { $0.scheduling?.isActiveNow ?? true })
        case .type(let type):
            // Scripturile vin din cheia LOR de catalog — vezi
            // Catalog.scriptItems pentru motivul retrocompatibilitatii.
            CatalogGrid(items: (type == .scripts ? catalog.scriptItems : catalog.items)
                .filter { $0.type == type && ($0.scheduling?.isActiveNow ?? true) })
        }
    }

    var body: some View {
        NavigationSplitView {
            // [2026-08-29, corectat] Profilul era atasat cu `.safeAreaInset`
            // DIRECT pe `List` — la redimensionare RAPIDA a ferestrei (tras
            // de colt), List-ul (un NSScrollView sub capota) nu-si recalcula
            // mereu la timp content-inset-ul fata de safe-area-ul suprapus,
            // asa ca profilul putea sa ramana temporar "suspendat" peste
            // ultimele randuri din sidebar in loc sa fie sub ele. Fix:
            // List si blocul de profil sunt acum FRATI intr-un VStack simplu
            // — layout-ul e calculat direct de VStack la fiecare cadru, fara
            // sa depinda de sincronizarea safe-area/scroll-inset a List-ului.
            VStack(spacing: 0) {
            List(selection: $selection) {
                // Grup 1: instalare AUTOMATĂ, exclusiv DaVinci Resolve
                // (Scripting API / foldere native Resolve). Separat vizual
                // explicit de grupul de mai jos — cerut de Cristi 2026-08-29:
                // "să nu se încurce lumea" cu resursele de download direct.
                Section(isExpanded: $expandResolveInstall) {
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
                } header: {
                    Text(L.t("sidebar.section.resolveInstall"))
                }

                // Grup 2: RESURSE DE DOWNLOAD DIRECT — Premiere Pro/Final Cut/
                // DaVinci Resolve, NU se instalează automat nicăieri (userul
                // descarcă și importă manual). Include Audio (deja exista) +
                // cele 4 categorii noi din Etapa 2 (2026-08-29).
                Section(isExpanded: $expandDownloadResources) {
                    Label {
                        Text(L.t("sidebar.audio"))
                    } icon: {
                        Image(systemName: "waveform").foregroundStyle(Color.indigo)
                    }
                    .tag(SidebarSection.audio)
                    ForEach(DownloadCategory.allCases) { category in
                        Label {
                            Text(L.t("sidebar.download.\(category.rawValue)"))
                        } icon: {
                            Image(systemName: category.defaultSymbol).foregroundStyle(category.tintColor)
                        }
                        .tag(SidebarSection.download(category))
                    }
                } header: {
                    Text(L.t("sidebar.section.downloadResources"))
                }

                // Grup 3: comunitate & educație — conținut informativ, fără
                // fișiere/instalare, doar link-uri externe (Cursuri/Materiale/
                // Evenimente) sau contact (Magazine/Service).
                Section(isExpanded: $expandCommunity) {
                    Label(L.t("sidebar.courses"), systemImage: "graduationcap")
                        .tag(SidebarSection.courses)
                    Label(L.t("sidebar.educationalResources"), systemImage: "book")
                        .tag(SidebarSection.educationalResources)
                    Label(L.t("sidebar.tutorials"), systemImage: "play.rectangle")
                        .tag(SidebarSection.tutorials)
                    Label(L.t("sidebar.events"), systemImage: "calendar")
                        .tag(SidebarSection.events)
                    // Etapa 4 (2026-08-29) — Oferte Parteneri.
                    Label(L.t("sidebar.partnerOffers"), systemImage: "tag")
                        .tag(SidebarSection.partnerOffers)
                    // Etapa 9 (2026-08-29) — Pachete/Bundle-uri.
                    Label(L.t("sidebar.bundles"), systemImage: "shippingbox")
                        .tag(SidebarSection.bundles)
                    Label(L.t("sidebar.partnerStores"), systemImage: "storefront")
                        .tag(SidebarSection.partnerStores)
                    Label(L.t("sidebar.serviceCenters"), systemImage: "wrench.and.screwdriver")
                        .tag(SidebarSection.serviceCenters)
                    // [2026-09-14] Hub de grupuri și canale de suport.
                    Label(L.t("sidebar.community"), systemImage: "person.2.wave.2")
                        .tag(SidebarSection.community)
                } header: {
                    Text(L.t("sidebar.section.community"))
                }

                // Grup 4: ecosistemul GDC — alte aplicații ale lui Cristi.
                Section(isExpanded: $expandEcosystem) {
                    Label(L.t("sidebar.apps"), systemImage: "app.badge")
                        .tag(SidebarSection.apps)
                    // Aplicatia mobila companion (PWA, gordas.dev/app.html —
                    // fost APK/TWA, retras 2026-08-24) — vezi AndroidPane.swift.
                    Label(L.t("sidebar.mobileApp"), systemImage: "iphone.gen3")
                        .tag(SidebarSection.android)
                    // Etapa 3 (2026-08-29) — lansator rapid, vezi MyAppsLauncher.swift.
                    Label(L.t("sidebar.myApps"), systemImage: "square.grid.3x1.folder.badge.plus")
                        .tag(SidebarSection.myApps)
                } header: {
                    Text(L.t("sidebar.section.ecosystem"))
                }

                // Grup 4b: DEVELOPER — unelte pentru dezvoltatori (GDC LUT Lab etc.).
                Section(isExpanded: $expandDeveloper) {
                    ForEach(DeveloperShelf.allCases, id: \.self) { shelf in
                        Label(L.t(shelf.titleKey), systemImage: shelf.symbol)
                            .tag(SidebarSection.developer(shelf))
                    }
                } header: {
                    Text(L.t("sidebar.section.developer"))
                }

                // Grup 5: contul tău — licență + ajutor, mereu ultimul.
                Section(isExpanded: $expandAccount) {
                    Label(L.t("sidebar.license"), systemImage: "key.fill")
                        .tag(SidebarSection.license)
                    Label(L.t("sidebar.help"), systemImage: "questionmark.circle")
                        .tag(SidebarSection.help)
                } header: {
                    Text(L.t("sidebar.section.account"))
                }
            }
            // Secțiunea care conține rubrica selectată se deschide singură.
            // Fără asta, o navigare venită din altă parte (butonul de licență,
            // o restaurare de selecție la pornire) ar lăsa lista pe o rubrică
            // invizibilă, într-o secțiune strânsă — ar părea că aplicația nu
            // a reacționat la click.
            .onChange(of: selection) { _, newValue in
                expandSection(containing: newValue)
            }
            .onAppear { expandSection(containing: selection) }
            // BUG REAL gasit 2026-08-26: navigationSplitViewColumnWidth(180)
            // (valoare unica) FIXEAZA latimea coloanei, nu o seteaza doar ca
            // implicita - sidebar-ul nu era deloc redimensionabil prin
            // tragere de mouse, desi NavigationSplitView suporta asta nativ.
            // Fix: supraincarcarea min/ideal/max, care lasa AppKit sa
            // deseneze diviziunea trasabila intre coloane.
            Divider()
            VStack(spacing: 6) {
                ProfileSidebarBlock()
                HStack(spacing: 6) {
                    Text("v\(appVersion)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    SidebarUpdateButton()
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 8)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 380)
        } detail: {
            // LaunchOfferBanner e FRATE cu conținutul scrollabil, nu
            // `.safeAreaInset` direct pe listă — vezi Regula 24
            // (CLAUDE.md): safeAreaInset atașat direct pe un List/ScrollView
            // nu se resincronizează mereu instant la resize rapid.
            VStack(spacing: 0) {
            VStack(spacing: 0) {
                if !missingDependencies.isEmpty {
                    DependencyBanner(missing: missingDependencies)
                }
                if let update = updateChecker.availableUpdate {
                    UpdateBanner(update: update)
                } else if updateChecker.checkFailed {
                    CheckFailedBanner()
                }
                // Bară de căutare GLOBALĂ (Etapa 1, extinsă 2026-08-29 —
                // cerut explicit: "trebuie să cuprindă tot ce există în
                // aplicație"). Vizibilă pe ORICE rubrică, indiferent de
                // secțiunea aleasă în sidebar — cât timp userul tastează
                // ceva, rezultatele unificate din TOATE categoriile
                // (Produse/Aplicații/Cursuri/Audio/Evenimente/Materiale/
                // Magazine/Service) înlocuiesc conținutul rubricii curente;
                // câmp gol → se revine exact la rubrica selectată, ca înainte.
                SearchBar(text: $globalSearchText, historyKey: "gdcpm_search_history_global",
                          liveSuggestions: globalSearchSuggestions)
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                if globalSearchText.trimmingCharacters(in: .whitespaces).isEmpty {
                    detailContent
                } else {
                    GlobalSearchResults(catalog: catalog, query: globalSearchText)
                }
            }
            // Etapa 6 (2026-08-29) — filigran sezonier. Clarificare
            // EXPLICITĂ de la Cristi: "nu neapărat numai banner... să
            // apară ca o imagine mai mare... ca și cum ar fi sculptat/
            // imprimat în fundal" — deci NU un icon mic suprapus, ci un
            // strat mare, discret, ÎN SPATELE conținutului (opacitate
            // mică, non-interactiv), nu deasupra lui.
            // Fără `alignment:` fix aici: fiecare filigran își poartă
            // propria poziție (2026-08-29) — vezi SeasonalBackgroundsLayer.
            .background { SeasonalBackgroundsLayer(configs: catalog.seasonalBackgrounds.activeNowDeduplicated) }
            LaunchOfferBanner()
            }
        }
        .navigationTitle(L.t("app.name"))
        .toolbar {
            ToolbarItem {
                DependencyBadge(dependencies: allDependencies, showPanel: $showDependencyPanel)
            }
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
            await license.refreshRevocations()
            allDependencies = SystemDependencyChecker.checkAll()
            missingDependencies = allDependencies.filter { !$0.isPresent && !$0.isOptional }
            if !UserDefaults.standard.bool(forKey: "gdcpm_onboarded") {
                showOnboarding = true
            }
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView(isPresented: $showOnboarding)
        }
        .sheet(isPresented: $showDependencyPanel) {
            DependencyPanel(isPresented: $showDependencyPanel, dependencies: allDependencies)
        }
        // "Check for Updates..." din meniul nativ (vezi GDCPluginManagerApp.swift)
        // — separat de check-ul automat de la lansare, mereu urmat de un
        // rezultat vizibil (pop-up nativ), niciodata silentios.
        .onReceive(NotificationCenter.default.publisher(for: .gdcCheckForUpdatesRequested)) { _ in
            Task {
                await updateChecker.check()
                // PITFALL FIXED 2026-08-26: citea availableUpdate (filtrat
                // de dismissal) — o versiune respinsa candva facea
                // verificarea manuala sa minta "esti la zi". latestInfo nu
                // e filtrat — vezi comentariul din UpdateChecker.swift.
                // [2026-09-03] Adaugat checkFailed: fara el, o verificare
                // esuata (retea/parsare) minea la fel "esti la zi" ca un
                // caz de succes real — vezi UpdateChecker.checkFailed.
                if updateChecker.checkFailed {
                    manualUpdateCheckMessage = L.t("update.check.failed")
                } else if let update = updateChecker.latestInfo {
                    manualUpdateCheckMessage = String(format: L.t("update.check.available"), update.version)
                } else {
                    manualUpdateCheckMessage = L.t("update.check.upToDate")
                }
                showManualUpdateCheckAlert = true
            }
        }
        .alert(L.t("update.check.title"), isPresented: $showManualUpdateCheckAlert) {
            Button(L.t("common.ok"), role: .cancel) {}
        } message: {
            Text(manualUpdateCheckMessage)
        }
        // Pop-up modal, pe langa bannerul din header (nu in locul lui):
        // bannerul e discret si poate fi ratat; pop-up-ul intrerupe o
        // singura data, la aparitia unei versiuni noi, si explica raspicat
        // ca nu e self-update automat — vezi WARNING din UpdateChecker.swift.
        // isPresented citeste `availableUpdate != nil` direct, deci apare
        // o singura data per versiune (UpdateChecker.dismiss() persista
        // versiunea inchisa in UserDefaults, la fel ca bannerul).
        .alert(
            L.t("update.popup.title"),
            isPresented: Binding(
                get: { updateChecker.availableUpdate != nil },
                set: { if !$0 { updateChecker.dismiss() } }
            ),
            presenting: updateChecker.availableUpdate
        ) { info in
            // "Actualizeaza acum" (Faza 4, vezi CLAUDE.md Partea 1 Regula 13):
            // deschide direct link-ul de descarcare (releases/latest/download/...)
            // — tot NU e self-update silentios (vezi WARNING din
            // UpdateChecker.swift), dar butonul e explicit denumit ca actiune
            // 1-click, nu doar "Descarca" generic. Inchide popup-ul dupa click
            // — userul si-a luat deja actiunea.
            // Nu mai deschide browserul — vezi SelfUpdater.swift. Nu mai
            // apelam dismiss() imediat: daca instalarea esueaza si userul
            // mai are nevoie sa vada popup-ul din nou, availableUpdate
            // ramane populat (SelfUpdater arata propria alerta de eroare).
            // Garda pe download_url pastrata ca inainte — butonul nu apare
            // deloc daca update.json n-are link pentru Mac.
            if !info.download_url.isEmpty {
                Button(L.t("update.popup.now")) {
                    Task { await SelfUpdater.downloadAndInstall(info: info) }
                }
            }
            // Update marcat mandatory (docs/update.json): fara "Mai tarziu"
            // — vezi UpdateChecker.dismiss(), nu se mai persista inchiderea
            // pentru mandatory, deci butonul ar fi oricum inutil aici.
            if info.mandatory != true {
                Button(L.t("update.popup.later"), role: .cancel) { updateChecker.dismiss() }
            }
        } message: { info in
            // Rezumatul modificarilor (Release Notes), din update.json
            // (`changes`) - camp optional, degradeaza elegant daca lipseste.
            if let changes = info.changes, !changes.isEmpty {
                Text(L.t("update.popup.message") + " (v\(info.version))\n\n" + L.t("update.popup.changes") + ":\n" + changes)
            } else {
                Text(L.t("update.popup.message") + " (v\(info.version))")
            }
        }
    }

}
