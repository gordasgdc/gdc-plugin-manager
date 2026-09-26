import SwiftUI

/// Butoanele GDC (DESIGN_SYSTEM.md, componenta 2). Accentul amber doar pe `.primary`.
/// Stări: hover, apăsat, dezactivat; ținta minimă `Size.minHitTarget`; animații oprite la Reduce Motion.
public struct GDCButtonStyle: ButtonStyle {
    public enum Role: Sendable { case primary, secondary, destructive, plain }
    public var role: Role = .secondary
    public var fullWidth = false

    public init(role: Role = .secondary, fullWidth: Bool = false) {
        self.role = role
        self.fullWidth = fullWidth
    }

    public func makeBody(configuration: Configuration) -> some View {
        StyledBody(configuration: configuration, role: role, fullWidth: fullWidth)
    }

    private struct StyledBody: View {
        let configuration: Configuration
        let role: Role
        let fullWidth: Bool
        @Environment(\.isEnabled) private var isEnabled
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @State private var hovering = false

        var body: some View {
            configuration.label
                .font(role == .primary ? .callout.weight(.semibold) : .callout.weight(.medium))
                .lineLimit(1)
                .foregroundStyle(foreground)
                .padding(.horizontal, role == .plain ? 0 : GDCTokens.Space.m)
                .frame(minHeight: GDCTokens.Size.minHitTarget)
                .frame(maxWidth: fullWidth ? .infinity : nil)
                .background { background }
                .overlay { border }
                .contentShape(RoundedRectangle(cornerRadius: GDCTokens.Radius.control))
                .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.45)
                .onHover { hovering = $0 }
                .animation(GDCTokens.Motion.animation(GDCTokens.Motion.fast, reduceMotion: reduceMotion), value: hovering)
        }

        private var foreground: Color {
            switch role {
            case .primary: return GDCTokens.Palette.onAccent
            case .secondary: return GDCTokens.Palette.textPrimary
            case .destructive: return GDCTokens.Palette.destructive
            case .plain: return GDCTokens.Palette.textSecondary
            }
        }

        @ViewBuilder private var background: some View {
            let shape = RoundedRectangle(cornerRadius: GDCTokens.Radius.control)
            switch role {
            case .primary:
                shape.fill(GDCTokens.Palette.accent)
                    .overlay(shape.fill(Color.white.opacity(hovering && isEnabled ? 0.10 : 0)))
                    .overlay(alignment: .top) {
                        // Muchia de lumină a finisajului lucios (prototip A+B).
                        shape.strokeBorder(LinearGradient(colors: [.white.opacity(0.28), .clear], startPoint: .top, endPoint: .center),
                                           lineWidth: GDCTokens.Border.hairline)
                    }
            case .secondary:
                shape.fill(GDCTokens.Palette.textPrimary.opacity(hovering && isEnabled ? 0.12 : 0.07))
            case .destructive:
                shape.fill(GDCTokens.Palette.destructive.opacity(hovering && isEnabled ? 0.10 : 0))
            case .plain:
                EmptyView()
            }
        }

        @ViewBuilder private var border: some View {
            let shape = RoundedRectangle(cornerRadius: GDCTokens.Radius.control)
            switch role {
            case .secondary: shape.strokeBorder(GDCTokens.Palette.separator, lineWidth: GDCTokens.Border.hairline)
            case .destructive: shape.strokeBorder(GDCTokens.Palette.destructive.opacity(0.45), lineWidth: GDCTokens.Border.hairline)
            default: EmptyView()
            }
        }
    }
}

public extension ButtonStyle where Self == GDCButtonStyle {
    static var gdcPrimary: GDCButtonStyle { GDCButtonStyle(role: .primary) }
    static var gdcSecondary: GDCButtonStyle { GDCButtonStyle(role: .secondary) }
    static var gdcDestructive: GDCButtonStyle { GDCButtonStyle(role: .destructive) }
}
