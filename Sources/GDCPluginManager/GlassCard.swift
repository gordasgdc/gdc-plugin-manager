import SwiftUI

/// Stil comun pentru TOATE cardurile din grile (glassmorphism nativ macOS):
/// material subțire, colț 12pt, bordură fină albă, umbră difuză.
extension View {
    func glassCardBackground() -> some View {
        self
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.2), lineWidth: 1))
            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 4)
    }
}
