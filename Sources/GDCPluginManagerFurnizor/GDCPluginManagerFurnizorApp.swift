import SwiftUI

@main
struct GDCPluginManagerFurnizorApp: App {
    var body: some Scene {
        WindowGroup {
            FurnizorContentView()
                .frame(minWidth: 720, minHeight: 560)
        }
        .windowStyle(.titleBar)
        .commands { CommandGroup(replacing: .appInfo) {} }
    }
}
