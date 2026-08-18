import SwiftUI

enum FurnizorSection: Hashable {
    case publish
    case generateSerial
}

struct FurnizorContentView: View {
    @State private var selection: FurnizorSection? = .publish

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Label("Publică produs", systemImage: "arrow.up.doc").tag(FurnizorSection.publish)
                Label("Generează serial", systemImage: "key").tag(FurnizorSection.generateSerial)
            }
            .navigationSplitViewColumnWidth(200)
        } detail: {
            switch selection {
            case .publish, .none:
                PublishView()
            case .generateSerial:
                GenerateSerialView()
            }
        }
        .navigationTitle("GDC Plugin Manager Furnizor")
    }
}
