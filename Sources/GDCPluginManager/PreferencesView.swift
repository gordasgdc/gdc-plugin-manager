import SwiftUI
import AppKit
import GDCPluginManagerCore

/// Continutul ferestrei native de Preferences (Cmd+,) — vezi Settings
/// scene din GDCPluginManagerApp.swift, care da automat intrarea de meniu
/// si shortcut-ul, SwiftUI-native, fara cod suplimentar de fereastra.
struct PreferencesView: View {
    @ObservedObject private var languageStore = LanguageStore.shared
    @ObservedObject private var updateChecker = UpdateChecker.shared
    @ObservedObject private var theme = ThemeManager.shared
    @State private var dependencies: [SystemDependency] = SystemDependencyChecker.checkAll()
    @State private var isCheckingUpdate = false
    @State private var showCheckResultAlert = false
    @State private var checkResultMessage = ""

    private var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    var body: some View {
        Form {
            Section(L.t("prefs.language.title")) {
                Picker("", selection: Binding(get: { L.current }, set: { L.current = $0 })) {
                    ForEach(AppLanguage.allCases) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
            }

            // Regula 18 (Partea 1): selector explicit Sistem/Light/Dark,
            // independent de setarea macOS. Aplicat instant, fără repornire
            // (ThemeManager scrie direct în NSApp.appearance).
            Section(L.t("prefs.theme.title")) {
                Picker("", selection: Binding(get: { theme.current }, set: { theme.set($0) })) {
                    Text(L.t("prefs.theme.system")).tag(AppTheme.system)
                    Text(L.t("prefs.theme.light")).tag(AppTheme.light)
                    Text(L.t("prefs.theme.dark")).tag(AppTheme.dark)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
            }

            Section(L.t("prefs.updates.title")) {
                HStack {
                    Text(L.t("prefs.updates.currentVersion"))
                    Spacer()
                    Text("v\(currentVersion)").foregroundStyle(.secondary)
                }
                HStack {
                    if isCheckingUpdate { ProgressView().controlSize(.small) }
                    Button(L.t("update.check.button")) { Task { await checkForUpdates() } }
                        .disabled(isCheckingUpdate)
                }
            }

            Section(L.t("prefs.dependencies.title")) {
                ForEach(dependencies) { dep in
                    HStack {
                        Circle()
                            .fill(dep.isPresent ? .green : .red)
                            .frame(width: 8, height: 8)
                        Text(dep.name)
                        Spacer()
                        if dep.isPresent {
                            Text(L.t("prefs.dependencies.installed")).foregroundStyle(.secondary).font(.callout)
                        } else if dep.isOptional {
                            Text(L.t("deps.state.optionalMissing")).foregroundStyle(.orange).font(.callout)
                        } else {
                            Text(L.t("prefs.dependencies.missing")).foregroundStyle(.red).font(.callout)
                            if let url = dep.downloadURL {
                                Button(L.t("prefs.dependencies.install")) { NSWorkspace.shared.open(url) }
                                    .controlSize(.small)
                            }
                        }
                    }
                }
                Button(L.t("prefs.dependencies.recheck")) { dependencies = SystemDependencyChecker.checkAll() }
                    .controlSize(.small)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 430)
        .alert(L.t("update.check.title"), isPresented: $showCheckResultAlert) {
            Button(L.t("common.ok"), role: .cancel) {}
        } message: {
            Text(checkResultMessage)
        }
    }

    private func checkForUpdates() async {
        isCheckingUpdate = true
        defer { isCheckingUpdate = false }

        await updateChecker.check()

        // PITFALL FIXED 2026-08-26: vezi comentariul din UpdateChecker.swift
        // — latestInfo, nu availableUpdate (care e filtrat de dismissal).
        if let update = updateChecker.latestInfo {
            checkResultMessage = String(format: L.t("update.check.available"), update.version)
        } else {
            checkResultMessage = L.t("update.check.upToDate")
        }
        showCheckResultAlert = true
    }
}
