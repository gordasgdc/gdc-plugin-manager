import SwiftUI
import GDCPluginManagerCore

/// Rând de progres (DESIGN_SYSTEM.md, componenta 7). `InstallManager` nu expune încă
/// procente, deci azi e doar nedeterminat; `value` e pregătit pentru progres real.
struct ProgressRow: View {
    let label: String
    var value: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: GDCTokens.Space.xs) {
            Group {
                if let value { ProgressView(value: value) } else { ProgressView() }
            }
            .progressViewStyle(.linear)
            .tint(GDCTokens.Palette.accent)
            Text(label)
                .font(GDCTokens.Typography.metadata)
                .foregroundStyle(GDCTokens.Palette.textSecondary)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
    }
}
