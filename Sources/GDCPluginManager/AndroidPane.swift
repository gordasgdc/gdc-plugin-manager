import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins
import AppKit

// =============================================================================
// MobileAppPane (fost AndroidPane) — anunta aplicatia mobila companion.
// -----------------------------------------------------------------------------
// ARHITECTURA (schimbata 2026-08-24, cerut explicit de Cristi — "scapam
// complet de problemele cu certificatele, erorile de instalare pe Android
// si fisierele APK"): aplicatia mobila NU mai e distribuita ca APK (TWA).
// E direct PWA-ul de la gordas.dev/app.html, deschis in browser — merge
// IDENTIC pe Android SI iPhone, fara instalare, fara avertisment de
// certificat/"sursa necunoscuta". "Instalarea" ramasa e doar optionala:
// Adauga pe ecranul principal (Android Chrome / iOS Safari), care da un
// icon pe ecran fara sa fie un APK real.
//
// De aceea acest fisier NU mai face niciun fetch de retea (nu mai exista
// android.json/versiune/marime de APK) — link-ul e o constanta fixa, iar
// panoul functioneaza instant, chiar si offline (codul QR e generat local).
//
// Pipeline-ul vechi de build APK (twa/, bubblewrap, keystore) a fost retras
// din acest repo — vezi CLAUDE.md, intrarea din 2026-08-24, pentru istoric.
// =============================================================================

struct MobileAppPane: View {
    @ObservedObject private var lang = LanguageStore.shared
    @State private var copied = false

    private static let appURL = URL(string: "https://gordas.dev/app.html")!

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                HStack(alignment: .top, spacing: 24) {
                    qrBlock
                    VStack(alignment: .leading, spacing: 14) {
                        Text(L.t("mobileapp.url"))
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                        actions
                    }
                    Spacer(minLength: 0)
                }
                instructions
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // ── Titlu ───────────────────────────────────────────────────────────────
    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 9) {
                Image(systemName: "iphone.gen3")
                    .font(.title2)
                    .foregroundStyle(.tint)
                Text(L.t("mobileapp.title")).font(.title2.bold())
            }
            Text(L.t("mobileapp.subtitle"))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // ── Cod QR ──────────────────────────────────────────────────────────────
    private var qrBlock: some View {
        VStack(spacing: 8) {
            if let img = Self.qrImage(from: Self.appURL.absoluteString) {
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

    /// Genereaza codul QR local, cu CoreImage — fara serviciu extern si fara
    /// nicio cerere de retea, panoul functioneaza instant, chiar si offline.
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

    // ── Butoane ─────────────────────────────────────────────────────────────
    private var actions: some View {
        HStack(spacing: 10) {
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(Self.appURL.absoluteString, forType: .string)
                copied = true
                Task { try? await Task.sleep(for: .seconds(2)); copied = false }
            } label: {
                Label(copied ? L.t("android.copied") : L.t("android.copy"),
                      systemImage: copied ? "checkmark" : "link")
            }
            Button {
                NSWorkspace.shared.open(Self.appURL)
            } label: {
                Label(L.t("mobileapp.open"), systemImage: "arrow.up.right.square")
            }
        }
    }

    // ── Pasii de "instalare" (Adauga pe ecranul principal) ──────────────────
    private var instructions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L.t("mobileapp.steps.title")).font(.headline)

            VStack(alignment: .leading, spacing: 4) {
                Text(L.t("mobileapp.steps.android.title")).font(.subheadline).fontWeight(.semibold)
                ForEach(Array(["mobileapp.steps.android.1", "mobileapp.steps.android.2"].enumerated()), id: \.offset) { i, key in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(i + 1).").font(.caption.monospaced()).foregroundStyle(.tint)
                        Text(L.t(key)).font(.caption).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(L.t("mobileapp.steps.ios.title")).font(.subheadline).fontWeight(.semibold)
                ForEach(Array(["mobileapp.steps.ios.1", "mobileapp.steps.ios.2"].enumerated()), id: \.offset) { i, key in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(i + 1).").font(.caption.monospaced()).foregroundStyle(.tint)
                        Text(L.t(key)).font(.caption).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: 520, alignment: .leading)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
