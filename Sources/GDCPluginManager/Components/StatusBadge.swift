import SwiftUI
import GDCPluginManagerCore

/// Insignă de stare (DESIGN_SYSTEM.md, componenta 1): culoare + iconiță + text,
/// niciodată doar culoare. Pe imagine primește material dedesubt, ca să rămână lizibilă.
struct StatusBadge: View {
    enum Kind: Equatable {
        case free, trial, promo, license, installed, update, installing, error, incompatible, offline
        case custom(String, Color, symbol: String? = nil)
    }

    let kind: Kind
    var text: String?
    var onArtwork = false

    var body: some View {
        HStack(spacing: GDCTokens.Space.xs) {
            if let symbol { Image(systemName: symbol).imageScale(.small) }
            Text(label).lineLimit(1)
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(color)
        .padding(.horizontal, GDCTokens.Space.s)
        .frame(height: GDCTokens.Size.badgeHeight)
        .background {
            RoundedRectangle(cornerRadius: GDCTokens.Radius.badge)
                .fill(onArtwork ? AnyShapeStyle(.regularMaterial) : AnyShapeStyle(.clear))
            RoundedRectangle(cornerRadius: GDCTokens.Radius.badge).fill(color.opacity(0.14))
        }
        .overlay(RoundedRectangle(cornerRadius: GDCTokens.Radius.badge)
            .strokeBorder(color.opacity(0.35), lineWidth: GDCTokens.Border.hairline))
        .fixedSize()
        .accessibilityElement(children: .combine)
    }

    private var label: String {
        if let text { return text }
        switch kind {
        case .free: return L.t("card.free")
        case .trial: return L.t("card.trial")
        case .promo: return L.t("card.promo")
        case .license: return L.t("card.paid")
        case .installed: return L.t("card.installed")
        case .update: return L.t("card.update")
        case .installing: return L.t("card.installing")
        case .error: return L.t("card.failed")
        case .incompatible: return L.t("card.incompatible")
        case .offline: return L.t("card.offline")
        case .custom(let t, _, _): return t
        }
    }

    private var color: Color {
        switch kind {
        case .free, .installed: return GDCTokens.Palette.success
        case .trial, .installing: return GDCTokens.Palette.info
        case .promo, .error: return GDCTokens.Palette.error
        case .license: return GDCTokens.Palette.accent
        case .update: return GDCTokens.Palette.warning
        case .incompatible, .offline: return GDCTokens.Palette.textSecondary
        case .custom(_, let c, _): return c
        }
    }

    private var symbol: String? {
        switch kind {
        case .free: return "gift"
        case .trial: return "clock"
        case .promo: return "tag"
        case .license: return "heart"
        case .installed: return "checkmark.circle.fill"
        case .update: return "arrow.down.circle"
        case .installing: return "arrow.down.to.line"
        case .error: return "exclamationmark.triangle.fill"
        case .incompatible: return "nosign"
        case .offline: return "wifi.slash"
        case .custom(_, _, let s): return s
        }
    }
}
