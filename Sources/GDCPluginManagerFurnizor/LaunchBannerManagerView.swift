import SwiftUI
import GDCPluginManagerCore

/// Panoul "Banner Lansare" — controlează bannerul de lansare publică
/// afișat jos de tot pe ecranul principal al Clientului (Mac + Windows),
/// FĂRĂ nicio recompilare (cerut explicit de Cristi, 2026-08-31, după
/// modelul `docs/pricing.json`/Regula 27). Un singur "produs" (nu o listă
/// ca restul catalogului) — id fix `"launch-banner"` pentru imagine.
struct LaunchBannerManagerView: View {
    @State private var config: LaunchBannerConfig?
    @State private var draftEnabled = false
    @State private var draftTopText = "LANSARE"
    @State private var draftMainText = "PREȚURI SPECIALE DE DESCHIDERE"
    @State private var coverSelection: CoverImageSelection = .none
    @State private var draftTextOnTop = true
    @State private var scheduling: Scheduling?
    /// Incrementat la fiecare `reload()` reușit - vezi `.id()` de mai jos.
    /// Fără el, `SchedulingPicker` (view persistent, nu recreat) și-ar
    /// inițializa starea internă o singură dată, ÎNAINTE ca `reload()`
    /// asincron să apuce să seteze `scheduling` real din git — exact bug-ul
    /// deja documentat și reparat sistemic în cele 11 `Publish*View.swift`.
    @State private var loadGeneration = 0

    @State private var isBusy = false
    @State private var loadError: String?
    @State private var publishError: String?
    @State private var lastPublishedAt: Date?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Banner Lansare").font(.title2).fontWeight(.semibold)
                Text("Vizibil jos de tot pe ecranul principal al Clientului (Mac + Windows). Modificările apar la clienți deja instalați în câteva minute, fără actualizare de aplicație.")
                    .font(.callout).foregroundStyle(.secondary)

                if let loadError {
                    Label(loadError, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Arată bannerul la clienți", isOn: $draftEnabled)
                        TextField("Text mic, sus (ex. LANSARE)", text: $draftTopText)
                            .textFieldStyle(.roundedBorder)
                        TextField("Text mare, principal (ex. PREȚURI SPECIALE DE DESCHIDERE)", text: $draftMainText)
                            .textFieldStyle(.roundedBorder)
                        Picker("Poziția textului", selection: $draftTextOnTop) {
                            Text("Deasupra imaginii").tag(true)
                            Text("Sub imagine").tag(false)
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(8)
                }

                CoverImagePicker(preset: .cover, selection: $coverSelection)
                SchedulingPicker(scheduling: $scheduling)
                    .id(loadGeneration)

                if let publishError {
                    Label(publishError, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red)
                }
                if let lastPublishedAt {
                    Label("Publicat \(lastPublishedAt.formatted(date: .omitted, time: .shortened))", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }

                Button {
                    publish()
                } label: {
                    if isBusy { ProgressView().controlSize(.small) } else { Text("Publică") }
                }
                .disabled(isBusy)
                .buttonStyle(.borderedProminent)
            }
            .padding(24)
        }
        .onAppear(perform: reload)
    }

    private func reload() {
        loadError = nil
        do {
            try GitOps.pull(at: RepoCheckoutPaths.publicCatalogRepo)
            let loaded = try LaunchBannerEditor.load()
            config = loaded
            draftEnabled = loaded.enabled
            draftTopText = loaded.topText.isEmpty ? draftTopText : loaded.topText
            draftMainText = loaded.mainText.isEmpty ? draftMainText : loaded.mainText
            coverSelection = loaded.imagePath.isEmpty ? .none : .existing(loaded.imagePath)
            draftTextOnTop = loaded.textOnTop
            scheduling = loaded.scheduling
            loadGeneration += 1
        } catch {
            // launch-banner.json poate lipsi la prima rulare — nu e o
            // eroare blocantă, doar un formular gol/implicit.
            loadError = "Nu am putut sincroniza din git: \(error.localizedDescription)"
        }
    }

    private func publish() {
        isBusy = true
        publishError = nil
        let previousImagePath = config?.imagePath
        let enabled = draftEnabled
        let topText = draftTopText
        let mainText = draftMainText
        let selection = coverSelection
        let schedulingValue = scheduling
        let textOnTop = draftTextOnTop

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let imagePath = try CoverImageStore.commit(selection, id: "launch-banner", previous: previousImagePath) ?? ""
                let updated = LaunchBannerConfig(enabled: enabled, imagePath: imagePath, topText: topText, mainText: mainText, scheduling: schedulingValue, textOnTop: textOnTop)
                try LaunchBannerEditor.publish(updated, message: "Banner Lansare: \(enabled ? "activat" : "dezactivat")")
                DispatchQueue.main.async {
                    config = updated
                    isBusy = false
                    lastPublishedAt = Date()
                }
            } catch {
                DispatchQueue.main.async {
                    isBusy = false
                    publishError = "Publicarea a eșuat: \(error.localizedDescription)"
                }
            }
        }
    }
}
