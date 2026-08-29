import SwiftUI
import AppKit
import GDCPluginManagerCore

/// The License destination in the main sidebar. The app itself is free;
/// this shows how many products are owned, this Mac's machine ID, an
/// activation field that works for ANY product's code (it tries every
/// product currently in the catalog — see LicenseManager.activate), a
/// list of individually-owned products, and a generic "contact to buy"
/// card (each catalog card also has its own per-product Buy button, this
/// is the fallback/general contact point).
struct LicensePane: View {
    @ObservedObject private var license = LicenseManager.shared
    @ObservedObject private var catalog = CatalogService.shared
    @State private var codeField = ""
    @State private var justActivated = false
    @State private var justCopiedMachineID = false

    private static let machineID = MachineID.display

    private static var whatsAppURL: URL {
        let text = "Salut! Vreau să deblochez un produs GDC Plugin Manager printr-o donație. ID calculator: \(machineID)"
        return WhatsAppLink.url(text: text)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(L.t("license.pane.title")).font(.title2).fontWeight(.semibold)

                languageCard
                statusCard

                if !license.licensedProducts.isEmpty {
                    myLicensesCard
                }

                machineIDCard
                activationCard
                buyCard

                Spacer(minLength: 0)
            }
            .padding(24)
            .frame(maxWidth: 520, alignment: .leading)
        }
    }

    private var languageCard: some View {
        HStack {
            Text(L.t("settings.language.title")).font(.headline)
            Spacer()
            Picker("", selection: Binding(get: { L.current }, set: { L.current = $0 })) {
                ForEach(AppLanguage.allCases) { lang in
                    Text(lang.displayName).tag(lang)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(width: 220)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(nsColor: .separatorColor), lineWidth: 1))
    }

    private var statusCard: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: license.isLicensed ? "checkmark.seal.fill" : "info.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(license.isLicensed ? .green : .secondary)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 4) {
                Text(statusTitle).font(.headline)
                Text(statusBody)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(nsColor: .separatorColor), lineWidth: 1))
    }

    private var statusTitle: String {
        license.isLicensed ? L.t("license.status.owned") : L.t("license.status.none")
    }

    private var statusBody: String {
        if license.isLicensed {
            return String(format: L.t("license.status.owned.body"), license.licensedProducts.count)
        }
        return L.t("license.status.none.body")
    }

    private var myLicensesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L.t("license.mylicenses.title")).font(.headline)
            ForEach(Array(license.licensedProducts.keys).sorted(), id: \.self) { productID in
                HStack {
                    Text(productName(for: productID))
                    Spacer()
                    Button(L.t("license.deactivate"), role: .destructive) {
                        license.deactivate(productID: productID)
                    }
                    .controlSize(.small)
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(nsColor: .separatorColor), lineWidth: 1))
    }

    private func productName(for productID: String) -> String {
        catalog.items.first(where: { $0.id == productID })?.name ?? productID
    }

    private var machineIDCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L.t("license.machineID.title")).font(.headline)
            Text(L.t("license.machineID.body"))
                .font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                Text(Self.machineID)
                    .font(.system(.body, design: .monospaced))
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .textBackgroundColor)))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(nsColor: .separatorColor), lineWidth: 1))
                Button(justCopiedMachineID ? L.t("license.machineID.copied") : L.t("license.machineID.copy")) {
                    let pb = NSPasteboard.general
                    pb.clearContents()
                    pb.setString(Self.machineID, forType: .string)
                    justCopiedMachineID = true
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(nsColor: .separatorColor), lineWidth: 1))
    }

    private var activationCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField(L.t("license.field.placeholder"), text: $codeField)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))

            if let error = license.activationError {
                Text(error).font(.callout).foregroundStyle(.red)
            }
            if justActivated {
                Label(L.t("license.activated.success"), systemImage: "checkmark.circle.fill")
                    .font(.callout).foregroundStyle(.green)
            }

            Button(L.t("license.activate")) {
                // Etapa 2 extinsă (2026-08-29): resursele de download
                // (LUT/SFX/VFX/Plugin) pot fi acum plătite la fel ca
                // produsele din catalog — trebuie incluse ca și candidați.
                let candidateIDs = catalog.items.map(\.id) + catalog.downloadableResources.map(\.id)
                justActivated = license.activate(code: codeField, candidateProductIDs: candidateIDs)
                if justActivated { codeField = "" }
            }
            .disabled(codeField.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || catalog.items.isEmpty)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(nsColor: .separatorColor), lineWidth: 1))
    }

    private var buyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L.t("license.buy.title")).font(.headline)
            Text(L.t("license.buy.price")).font(.callout).foregroundStyle(.secondary)
            Button(L.t("license.buy.button")) { NSWorkspace.shared.open(Self.whatsAppURL) }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(nsColor: .separatorColor), lineWidth: 1))
    }
}
