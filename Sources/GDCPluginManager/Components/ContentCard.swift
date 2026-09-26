import SwiftUI
import GDCPluginManagerCore

/// Cardul comun (DESIGN_SYSTEM.md, componenta 3; prototip A+B aprobat 2026-09-26):
/// suprafață translucidă, muchie fină, linie de lumină sus, elevație; la hover
/// `Elevation.hover`, fără mărire de scară, fără animație la Reduce Motion.
/// Toate cele 12 tipuri de conținut și cardul de produs trec prin el.
struct ContentCard<Content: View>: View {
    var minHeight: CGFloat?
    var fixedHeight: CGFloat?
    var alignment: Alignment = .topLeading
    @ViewBuilder var content: Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false

    var body: some View {
        content
            .padding(GDCTokens.Space.m)
            .frame(maxWidth: .infinity, minHeight: fixedHeight ?? minHeight, maxHeight: fixedHeight, alignment: alignment)
            .background(GDCTokens.Surface.card, in: RoundedRectangle(cornerRadius: GDCTokens.Radius.card))
            .overlay {
                RoundedRectangle(cornerRadius: GDCTokens.Radius.card)
                    .strokeBorder(GDCTokens.Border.cardColor, lineWidth: GDCTokens.Border.hairline)
            }
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: GDCTokens.Radius.card)
                    .strokeBorder(LinearGradient(colors: [GDCTokens.Finish.edge, .clear], startPoint: .top, endPoint: .init(x: 0.5, y: 0.08)),
                                  lineWidth: GDCTokens.Border.hairline)
                    .allowsHitTesting(false)
            }
            .gdcElevation(hovering ? .hover : .card)
            .onHover { hovering = $0 }
            .animation(GDCTokens.Motion.animation(GDCTokens.Motion.standard, reduceMotion: reduceMotion), value: hovering)
    }
}

extension View {
    /// Aplică `ContentCard` pe un conținut existent (cardurile vechi își păstrează layout-ul intern).
    func contentCard(minHeight: CGFloat? = nil, fixedHeight: CGFloat? = nil, alignment: Alignment = .topLeading) -> some View {
        ContentCard(minHeight: minHeight, fixedHeight: fixedHeight, alignment: alignment) { self }
    }
}
