import SwiftUI
import GDCPluginManagerCore

/// Stil comun pentru TOATE cardurile din grile (glassmorphism nativ macOS):
/// material subțire, colț 12pt, bordură fină albă, umbră difuză.
/// Valorile vin din `GDCTokens` (aceleași ca înainte — aspect neschimbat).
extension View {
    func glassCardBackground() -> some View {
        self
            .background(GDCTokens.Surface.card, in: RoundedRectangle(cornerRadius: GDCTokens.Radius.card))
            .overlay(RoundedRectangle(cornerRadius: GDCTokens.Radius.card)
                .stroke(GDCTokens.Border.cardColor, lineWidth: GDCTokens.Border.hairline))
            .gdcElevation(.card)
    }
}
