import SwiftUI

enum FurnizorSection: Hashable {
    case publish
    case generateSerial
    case salesHistory
    case courses
    case apps
}

struct FurnizorContentView: View {
    @State private var selection: FurnizorSection? = .publish

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Label("Publică produs", systemImage: "arrow.up.doc").tag(FurnizorSection.publish)
                Label("Generează serial", systemImage: "key").tag(FurnizorSection.generateSerial)
                Label("Clienți", systemImage: "person.2").tag(FurnizorSection.salesHistory)
                Divider()
                Label("Cursuri", systemImage: "graduationcap").tag(FurnizorSection.courses)
                Label("Aplicații", systemImage: "square.grid.2x2").tag(FurnizorSection.apps)
            }
            .navigationSplitViewColumnWidth(200)
        } detail: {
            switch selection {
            case .publish, .none:
                PublishView()
            case .generateSerial:
                GenerateSerialView()
            case .salesHistory:
                SalesHistoryView()
            case .courses:
                PublishCourseView()
            case .apps:
                PublishAppView()
            }
        }
        .navigationTitle("GDC Plugin Manager Furnizor")
    }
}
