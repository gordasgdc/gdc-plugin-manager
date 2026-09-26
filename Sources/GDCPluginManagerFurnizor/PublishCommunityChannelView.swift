import SwiftUI
import GDCPluginManagerCore

/// Editorul canalelor din secțiunea Comunitate a clientului.
///
/// Nu se încarcă niciun fișier și nu se atinge niciun repo privat: un canal e
/// doar un link plus textul din jurul lui, publicat în `catalog.json` prin
/// același flux ca orice altă secțiune.
struct PublishCommunityChannelView: View {
    @State private var channels: [CommunityChannel] = []
    @State private var editingID: String?

    @State private var id = ""
    @State private var title = ""
    @State private var descriptionText = ""
    @State private var url = ""
    @State private var kind: CommunityKind = .community
    @State private var icon = "facebook"
    @State private var orderText = "0"

    @State private var isPublishing = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    /// Cheile de iconiță pe care clientul le știe desena. Lista e aici, nu în
    /// `BrandIcon`, fiindcă acela trăiește în target-ul Client: Furnizorul nu
    /// îl poate importa. Dacă adaugi un brand acolo, adaugă-l și aici —
    /// altfel poți publica o cheie pe care clientul o va afișa cu simbolul
    /// neutru de rezervă.
    private static let iconKeys = ["facebook", "whatsapp", "youtube", "discord",
                                   "telegram", "instagram", "tiktok", "linkedin",
                                   "github", "web"]

    var body: some View {
        HSplitView {
            form.frame(minWidth: 420)
            list.frame(minWidth: 280)
        }
        .task { load() }
    }

    // MARK: Formular

    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GDCTokens.Space.l) {
                Text(editingID == nil ? "Canal nou" : "Editezi „\(editingID ?? "")”")
                    .font(.title3).fontWeight(.semibold)

                labeled("Identificator", "ex. facebook-community") {
                    TextField("", text: $id).disabled(editingID != nil)
                }
                labeled("Titlu", "Ce vede utilizatorul pe card") {
                    TextField("", text: $title)
                }
                labeled("Descriere", "Maxim două rânduri — restul se taie pe card") {
                    TextField("", text: $descriptionText, axis: .vertical).lineLimit(2...3)
                }
                labeled("Adresă", "Trebuie să înceapă cu https://") {
                    TextField("", text: $url)
                }

                if let warning = urlWarning {
                    Label(warning.text, systemImage: warning.blocking ? "xmark.octagon.fill" : "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(warning.blocking ? .red : .orange)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: GDCTokens.Space.l) {
                    VStack(alignment: .leading, spacing: GDCTokens.Space.xs) {
                        Text("Tip (dă eticheta butonului)").font(.caption).foregroundStyle(.secondary)
                        Picker("", selection: $kind) {
                            ForEach(CommunityKind.allCases, id: \.self) { value in
                                Text(label(for: value)).tag(value)
                            }
                        }
                        .labelsHidden()
                    }
                    VStack(alignment: .leading, spacing: GDCTokens.Space.xs) {
                        Text("Iconiță").font(.caption).foregroundStyle(.secondary)
                        Picker("", selection: $icon) {
                            ForEach(Self.iconKeys, id: \.self) { key in
                                Text(key.capitalized).tag(key)
                            }
                        }
                        .labelsHidden()
                    }
                    VStack(alignment: .leading, spacing: GDCTokens.Space.xs) {
                        Text("Ordine").font(.caption).foregroundStyle(.secondary)
                        TextField("", text: $orderText).frame(width: 60)
                    }
                }

                Text("Butonul va scrie „\(previewButtonLabel)” — tradus automat în engleză și spaniolă pentru clienții care folosesc acele limbi.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let errorMessage {
                    Label(errorMessage, systemImage: "xmark.octagon.fill")
                        .foregroundStyle(GDCTokens.Palette.error).font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let successMessage {
                    Label(successMessage, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(GDCTokens.Palette.success).font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack {
                    Button(editingID == nil ? "Publică" : "Salvează") {
                        Task { await publish() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canPublish || isPublishing)

                    if editingID != nil {
                        Button("Renunță la editare") { clearForm() }
                    }
                    if isPublishing { ProgressView().controlSize(.small) }
                }
            }
            .padding(20)
        }
    }

    // MARK: Lista

    private var list: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Publicate (\(channels.count))")
                .font(.headline).padding(GDCTokens.Space.l)
            Divider()
            if channels.isEmpty {
                Text("Niciun canal publicat încă.")
                    .font(.callout).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(channels) { channel in
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(channel.title).font(.callout)
                                Spacer()
                                Text("#\(channel.order)").font(.caption2).foregroundStyle(.secondary)
                            }
                            Text(channel.url)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(1).truncationMode(.middle)
                            HStack(spacing: 10) {
                                Text("\(label(for: channel.kind)) · \(channel.icon)")
                                    .font(.caption2).foregroundStyle(.secondary)
                                Spacer()
                                Button("Editează") { startEditing(channel) }
                                    .buttonStyle(.link).font(.caption)
                                Button("Șterge") { Task { await remove(channel) } }
                                    .buttonStyle(.link).font(.caption).foregroundStyle(GDCTokens.Palette.error)
                            }
                        }
                        .padding(.vertical, GDCTokens.Space.xs)
                    }
                }
            }
        }
    }

    // MARK: Validare

    /// Regula cerută: `https://` obligatoriu. `http://` nu e blocat complet —
    /// e avertizat vizibil și roșu, fiindcă un link nesecurizat publicat către
    /// toți clienții e o decizie, nu o scăpare; dar publicarea lui rămâne
    /// oprită până se corectează, ca să nu treacă din grabă.
    private var urlWarning: (text: String, blocking: Bool)? {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.hasPrefix("https://") { return nil }
        if trimmed.hasPrefix("http://") {
            return ("Adresă nesecurizată (http://). Folosește https:// — aproape toate serviciile îl acceptă.", true)
        }
        return ("Adresa trebuie să înceapă cu https://", true)
    }

    private var canPublish: Bool {
        !id.trimmingCharacters(in: .whitespaces).isEmpty
            && !title.trimmingCharacters(in: .whitespaces).isEmpty
            && urlWarning == nil
            && !url.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: Acțiuni

    private func load() {
        channels = (try? CatalogEditor.load().communityChannels) ?? []
    }

    private func startEditing(_ channel: CommunityChannel) {
        editingID = channel.id
        id = channel.id
        title = channel.title
        descriptionText = channel.description
        url = channel.url
        kind = channel.kind
        icon = Self.iconKeys.contains(channel.icon) ? channel.icon : Self.iconKeys[0]
        orderText = String(channel.order)
        errorMessage = nil
        successMessage = nil
    }

    private func clearForm() {
        editingID = nil
        id = ""; title = ""; descriptionText = ""; url = ""
        kind = .community; icon = Self.iconKeys[0]; orderText = "0"
        errorMessage = nil
    }

    private func publish() async {
        isPublishing = true
        errorMessage = nil
        successMessage = nil
        defer { isPublishing = false }
        do {
            try GitOps.pull(at: RepoCheckoutPaths.publicCatalogRepo)
            let channel = CommunityChannel(
                id: id.trimmingCharacters(in: .whitespaces),
                kind: kind,
                icon: icon,
                title: title.trimmingCharacters(in: .whitespaces),
                description: descriptionText.trimmingCharacters(in: .whitespaces),
                url: url.trimmingCharacters(in: .whitespaces),
                order: Int(orderText.trimmingCharacters(in: .whitespaces)) ?? 0)
            try CatalogEditor.upsertCommunityChannel(channel)
            try GitOps.commitAndPush(at: RepoCheckoutPaths.publicCatalogRepo,
                                     message: "Canal comunitate: \(channel.title)",
                                     paths: ["docs/catalog.json"])
            successMessage = "„\(channel.title)” e publicat — apare la clienți la următorul refresh de catalog."
            clearForm()
            load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func remove(_ channel: CommunityChannel) async {
        isPublishing = true
        errorMessage = nil
        successMessage = nil
        defer { isPublishing = false }
        do {
            try GitOps.pull(at: RepoCheckoutPaths.publicCatalogRepo)
            try CatalogEditor.removeCommunityChannel(id: channel.id)
            try GitOps.commitAndPush(at: RepoCheckoutPaths.publicCatalogRepo,
                                     message: "Sterge canal comunitate: \(channel.title)",
                                     paths: ["docs/catalog.json"])
            successMessage = "„\(channel.title)” a fost șters."
            if editingID == channel.id { clearForm() }
            load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: Ajutoare

    private var previewButtonLabel: String {
        switch kind {
        case .community: return "Intră în grup"
        case .chat: return "Deschide chat-ul"
        case .video: return "Deschide canalul"
        case .docs: return "Deschide ghidul"
        case .feedback: return "Raportează o problemă"
        }
    }

    private func label(for kind: CommunityKind) -> String {
        switch kind {
        case .community: return "Grup / comunitate"
        case .chat: return "Chat / suport"
        case .video: return "Video"
        case .docs: return "Documentație"
        case .feedback: return "Feedback / bug-uri"
        }
    }

    private func labeled<Content: View>(_ title: String, _ hint: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: GDCTokens.Space.xs) {
            Text(title).font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
            content()
                .textFieldStyle(.roundedBorder)
            Text(hint).font(.caption2).foregroundStyle(.secondary)
        }
    }
}
