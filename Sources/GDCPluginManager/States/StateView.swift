import SwiftUI
import GDCPluginManagerCore

/// Stările de ecran (DESIGN_SYSTEM.md, componenta 5; prototip aprobat 2026-09-26):
/// LOADING (schelet de carduri), EMPTY, ERROR. OFFLINE e un `Banner` peste catalogul din cache.
struct StateView: View {
    enum Kind { case loading, empty, error }
    struct Action {
        let title: String
        var isPrimary = false
        let perform: () -> Void
    }

    let kind: Kind
    var title: String?
    var message: String
    var symbol: String?
    var actions: [Action] = []

    var body: some View {
        switch kind {
        case .loading: LoadingSkeleton(label: message)
        case .empty, .error: content
        }
    }

    private var content: some View {
        VStack(spacing: GDCTokens.Space.m) {
            Image(systemName: symbol ?? (kind == .error ? "exclamationmark.triangle" : "shippingbox"))
                .font(.system(size: GDCTokens.Size.iconM + 6, weight: .regular))
                .foregroundStyle(tint)
                .frame(width: 56, height: 56)
                .background(tint.opacity(0.12), in: Circle())
                .accessibilityHidden(true)
            if let title {
                Text(title).font(GDCTokens.Typography.sectionTitle)
                    .multilineTextAlignment(.center)
            }
            Text(message)
                .font(GDCTokens.Typography.secondary)
                .foregroundStyle(GDCTokens.Palette.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
                .fixedSize(horizontal: false, vertical: true)
            if !actions.isEmpty {
                HStack(spacing: GDCTokens.Space.s) {
                    ForEach(actions.indices, id: \.self) { i in
                        Button(actions[i].title, action: actions[i].perform)
                            .buttonStyle(actions[i].isPrimary ? GDCButtonStyle(role: .primary) : GDCButtonStyle(role: .secondary))
                    }
                }
                .padding(.top, GDCTokens.Space.xs)
            }
        }
        .padding(GDCTokens.Space.xxl)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
    }

    private var tint: Color { kind == .error ? GDCTokens.Palette.error : GDCTokens.Palette.textSecondary }
}

/// Schelet de carduri cât se încarcă catalogul. Pulsația se oprește complet la Reduce Motion;
/// anunțul pentru VoiceOver se face o singură dată per apariție, nu la fiecare redesenare.
private struct LoadingSkeleton: View {
    let label: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase = false
    @State private var announced = false

    var body: some View {
        VStack(alignment: .leading, spacing: GDCTokens.Space.m) {
            HStack(spacing: GDCTokens.Space.s) {
                ProgressView().controlSize(.small)
                Text(label).font(GDCTokens.Typography.metadata).foregroundStyle(GDCTokens.Palette.textSecondary)
            }
            .accessibilityElement(children: .combine)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: GDCTokens.Size.cardMinWidth), spacing: GDCTokens.Space.grid)],
                      spacing: GDCTokens.Space.grid) {
                ForEach(0..<6, id: \.self) { _ in skeletonCard }
            }
            .accessibilityHidden(true)
        }
        .padding(GDCTokens.Space.l)
        .onAppear {
            if !reduceMotion {
                withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { phase = true }
            }
            guard !announced else { return }
            announced = true
            AccessibilityNotification.Announcement(label).post()
        }
    }

    private var skeletonCard: some View {
        VStack(alignment: .leading, spacing: GDCTokens.Space.s) {
            block.frame(height: GDCTokens.Size.cardArtworkHeight)
            block.frame(width: 60, height: 10)
            block.frame(height: 14)
            block.frame(width: 160, height: 10)
        }
        .padding(GDCTokens.Space.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(RoundedRectangle(cornerRadius: GDCTokens.Radius.card)
            .strokeBorder(GDCTokens.Border.cardColor, lineWidth: GDCTokens.Border.hairline))
    }

    private var block: some View {
        RoundedRectangle(cornerRadius: GDCTokens.Radius.control)
            .fill(GDCTokens.Palette.textPrimary.opacity(phase ? 0.11 : 0.06))
    }
}
