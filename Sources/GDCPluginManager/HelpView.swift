import SwiftUI

/// Static in-app explainer — how the app works, how buying/activating a
/// product works, how installs interact with DaVinci Resolve.
struct HelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(L.t("help.title")).font(.title2).fontWeight(.semibold)

                section(icon: "square.grid.2x2", title: "help.what.title", body: "help.what.body")
                section(icon: "cart", title: "help.buy.title", body: "help.buy.body")
                section(icon: "arrow.down.circle", title: "help.install.title", body: "help.install.body")
                section(icon: "paintpalette", title: "help.powergrade.title", body: "help.powergrade.body")
                section(icon: "camera.filters", title: "help.ofx.title", body: "help.ofx.body")
                section(icon: "desktopcomputer", title: "help.machine.title", body: "help.machine.body")
                section(icon: "arrow.triangle.2.circlepath", title: "help.updates.title", body: "help.updates.body")
                section(icon: "questionmark.circle", title: "help.support.title", body: "help.support.body")

                Spacer(minLength: 0)
            }
            .padding(24)
            .frame(maxWidth: 560, alignment: .leading)
        }
    }

    private func section(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(.tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(L.t(title)).font(.headline)
                Text(L.t(body))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(nsColor: .separatorColor), lineWidth: 1))
    }
}
