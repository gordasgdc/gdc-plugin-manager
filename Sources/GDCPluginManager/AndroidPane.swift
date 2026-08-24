import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins
import AppKit

// =============================================================================
// AndroidPane — anunta si distribuie aplicatia companion de Android (APK).
// -----------------------------------------------------------------------------
// DE CE EXISTA: aplicatia de Android e un PWA impachetat ca APK (TWA) peste
// gordas.dev. Nu se distribuie prin Play Store, deci utilizatorul trebuie sa
// ajunga la fisierul .apk pe telefon — de aici codul QR, cea mai scurta cale
// de la ecranul Mac-ului la telefon.
//
// ARCHITECTURE NOTE — de ce citim android.json si NU folosim
// "releases/latest/download/...": release-urile de APK sunt marcate deliberat
// ca non-latest, ca `latest` sa ramana al aplicatiei desktop (update.json /
// UpdateChecker.swift). Un link "latest" aici ar descarca .pkg-ul de Mac.
// Tagul fix exista intr-un SINGUR loc, docs/android.json, si e citit dinamic.
// Nu hardcoda niciodata versiunea sau tagul in acest fisier.
// =============================================================================

/// Ce publicam in docs/android.json. Camp nou acolo => camp nou aici.
struct AndroidRelease: Decodable {
    let version: String
    let releaseDate: String?
    let minAndroid: String?
    let sizeMB: Double?
    let apkURL: URL
    let releasePage: URL?
    let changes: String?

    enum CodingKeys: String, CodingKey {
        case version, minAndroid, sizeMB, apkURL, releasePage, changes
        case releaseDate = "release_date"
    }

    static let url = URL(string: "https://gordas.dev/android.json")!
}

@MainActor
final class AndroidReleaseLoader: ObservableObject {
    @Published var release: AndroidRelease?
    @Published var failed = false

    func load() async {
        do {
            var req = URLRequest(url: AndroidRelease.url)
            // Fara asta, un android.json vechi din cache-ul URL-ului ar ascunde
            // versiuni noi de APK zile intregi.
            req.cachePolicy = .reloadIgnoringLocalCacheData
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }
            release = try JSONDecoder().decode(AndroidRelease.self, from: data)
            failed = false
        } catch {
            // Eroarea nu e fatala: panoul isi arata varianta fara link.
            failed = true
        }
    }
}

struct AndroidPane: View {
    @StateObject private var loader = AndroidReleaseLoader()
    @ObservedObject private var lang = LanguageStore.shared
    @State private var copied = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                if let r = loader.release {
                    HStack(alignment: .top, spacing: 24) {
                        qrBlock(for: r)
                        VStack(alignment: .leading, spacing: 14) {
                            metaRows(for: r)
                            actions(for: r)
                        }
                        Spacer(minLength: 0)
                    }
                    instructions
                } else if loader.failed {
                    Text(L.t("android.error"))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    ProgressView().controlSize(.small)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .task { await loader.load() }
    }

    // ── Titlu ───────────────────────────────────────────────────────────────
    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 9) {
                Image(systemName: "iphone.gen3")
                    .font(.title2)
                    .foregroundStyle(.tint)
                Text(L.t("android.title")).font(.title2.bold())
            }
            Text(L.t("android.subtitle"))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // ── Cod QR ──────────────────────────────────────────────────────────────
    private func qrBlock(for r: AndroidRelease) -> some View {
        VStack(spacing: 8) {
            if let img = Self.qrImage(from: r.apkURL.absoluteString) {
                Image(nsImage: img)
                    .interpolation(.none)          // fara asta, QR-ul iese neclar la scalare
                    .resizable()
                    .frame(width: 168, height: 168)
                    .padding(10)
                    .background(Color.white)       // QR-ul are nevoie de fundal alb ca sa fie citit
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            Text(L.t("android.qr.hint"))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 188)
                .multilineTextAlignment(.center)
        }
    }

    /// Genereaza codul QR local, cu CoreImage — fara serviciu extern, deci
    /// panoul functioneaza si fara internet (odata ce android.json e citit).
    static func qrImage(from string: String) -> NSImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let out = filter.outputImage else { return nil }
        // CoreImage produce un QR mic (~30px); il scalam cu nearest-neighbor
        // ca modulele sa ramana cu muchii drepte.
        let scaled = out.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        let ctx = CIContext()
        guard let cg = ctx.createCGImage(scaled, from: scaled.extent) else { return nil }
        return NSImage(cgImage: cg, size: NSSize(width: scaled.extent.width, height: scaled.extent.height))
    }

    // ── Detalii versiune ────────────────────────────────────────────────────
    private func metaRows(for r: AndroidRelease) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            row(L.t("android.meta.version"), r.version)
            if let s = r.sizeMB { row(L.t("android.meta.size"), String(format: "%.1f MB", s)) }
            if let m = r.minAndroid { row(L.t("android.meta.min"), "Android \(m)+") }
            if let d = r.releaseDate { row(L.t("android.meta.date"), d) }
            if let c = r.changes, !c.isEmpty {
                Text(c)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            }
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(spacing: 8) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.caption.monospaced())
        }
    }

    // ── Butoane ─────────────────────────────────────────────────────────────
    private func actions(for r: AndroidRelease) -> some View {
        HStack(spacing: 10) {
            Button {
                // Copiem linkul ca sa poata fi trimis pe telefon prin orice canal.
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(r.apkURL.absoluteString, forType: .string)
                copied = true
                Task { try? await Task.sleep(for: .seconds(2)); copied = false }
            } label: {
                Label(copied ? L.t("android.copied") : L.t("android.copy"),
                      systemImage: copied ? "checkmark" : "link")
            }
            Button {
                NSWorkspace.shared.open(r.releasePage ?? r.apkURL)
            } label: {
                Label(L.t("android.open"), systemImage: "arrow.up.right.square")
            }
        }
    }

    // ── Pasii de instalare ──────────────────────────────────────────────────
    // Fara ei, utilizatorul se blocheaza la avertismentul Android pentru
    // aplicatii din surse necunoscute si crede ca APK-ul e defect.
    private var instructions: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(L.t("android.steps.title")).font(.headline)
            ForEach(Array(["android.steps.1", "android.steps.2", "android.steps.3", "android.steps.4"].enumerated()), id: \.offset) { i, key in
                HStack(alignment: .top, spacing: 8) {
                    Text("\(i + 1).").font(.caption.monospaced()).foregroundStyle(.tint)
                    Text(L.t(key)).font(.caption).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: 520, alignment: .leading)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
