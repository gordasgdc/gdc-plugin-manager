import SwiftUI
import AppKit
import GDCPluginManagerCore

struct CountdownBadge: View {
    let scheduling: Scheduling?
    @State private var text: String?
    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            if let text {
                BadgePill(text: text, color: .orange)
            }
        }
        .onAppear { text = scheduling?.countdownText }
        .onReceive(timer) { _ in text = scheduling?.countdownText }
    }
}
