import SwiftUI
import AppKit
import GDCPluginManagerCore

/// Păstrat ca API pentru cardurile de conținut; desenat acum ca `StatusBadge` (prototip A+B),
/// ca toate insignele din aplicație să arate la fel.
struct BadgePill: View {
    let text: String
    let color: Color

    var body: some View {
        StatusBadge(kind: .custom(text, color), onArtwork: true)
    }
}
