import SwiftUI
import GDCPluginManagerCore

/// Bannerul unificat (DESIGN_SYSTEM.md, componenta 6; prototip aprobat 2026-09-26): suprafață
/// care plutește (material + muchie de lumină), culoarea stării doar pe iconiță, amberul doar pe
/// acțiunea principală, închidere consecventă. Anunțat o singură dată pentru VoiceOver.
struct Banner: View {
    enum Kind { case info, warning, error, offline }
    struct Action {
        let title: String
        var isPrimary = false
        let perform: () -> Void
    }

    let kind: Kind
    let title: String
    var message: String?
    var actions: [Action] = []
    var dismiss: Action?

    @State private var announced = false

    var body: some View {
        HStack(alignment: .top, spacing: GDCTokens.Space.m) {
            Image(systemName: symbol)
                .font(.system(size: GDCTokens.Size.iconS, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: GDCTokens.Size.minHitTarget, height: GDCTokens.Size.minHitTarget)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: GDCTokens.Radius.control))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: GDCTokens.Space.xxs) {
                Text(title).font(GDCTokens.Typography.label.weight(.semibold))
                if let message {
                    Text(message)
                        .font(GDCTokens.Typography.metadata)
                        .foregroundStyle(GDCTokens.Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            HStack(spacing: GDCTokens.Space.s) {
                ForEach(actions.indices, id: \.self) { i in
                    Button(actions[i].title, action: actions[i].perform)
                        .buttonStyle(actions[i].isPrimary ? GDCButtonStyle(role: .primary) : GDCButtonStyle(role: .secondary))
                }
                if let dismiss {
                    Button(dismiss.title, action: dismiss.perform).buttonStyle(GDCButtonStyle(role: .plain))
                }
            }
            .fixedSize()
        }
        .padding(.horizontal, GDCTokens.Space.m + 2)
        .padding(.vertical, GDCTokens.Space.m)
        .background(GDCTokens.Surface.floating, in: RoundedRectangle(cornerRadius: GDCTokens.Radius.inset))
        .overlay(RoundedRectangle(cornerRadius: GDCTokens.Radius.inset)
            .strokeBorder(GDCTokens.Border.cardColor, lineWidth: GDCTokens.Border.hairline))
        .overlay(alignment: .top) {
            RoundedRectangle(cornerRadius: GDCTokens.Radius.inset)
                .strokeBorder(LinearGradient(colors: [GDCTokens.Finish.edge, .clear], startPoint: .top, endPoint: .init(x: 0.5, y: 0.15)),
                              lineWidth: GDCTokens.Border.hairline)
                .allowsHitTesting(false)
        }
        .gdcElevation(.floating)
        .padding(.horizontal, GDCTokens.Space.l)
        .padding(.top, GDCTokens.Space.s)
        .accessibilityElement(children: .contain)
        .onAppear {
            guard !announced else { return }
            announced = true
            AccessibilityNotification.Announcement(message.map { "\(title). \($0)" } ?? title).post()
        }
    }

    private var tint: Color {
        switch kind {
        case .info: return GDCTokens.Palette.info
        case .warning: return GDCTokens.Palette.warning
        case .error: return GDCTokens.Palette.error
        case .offline: return GDCTokens.Palette.textSecondary
        }
    }

    private var symbol: String {
        switch kind {
        case .info: return "arrow.down.circle"
        case .warning: return "exclamationmark.triangle"
        case .error: return "exclamationmark.circle"
        case .offline: return "wifi.slash"
        }
    }
}
