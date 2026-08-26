import SwiftUI
import AppKit
import GDCPluginManagerCore

/// Indicator global 🔴/🟢 + panou dedicat de dependinte de sistem — vezi
/// CLAUDE.md, Partea 1, Regula 4 ("Manager de Dependinte, Standard GDC").
/// Port al arhitecturii deja construite la CGConvertor
/// (DependencyBadge/DependencyPanel), adaptat aici: dependintele proprii
/// acestei aplicatii sunt DaVinci Resolve + folderele de instalare +
/// Scripting API (vezi SystemDependencyChecker.swift), nu FFmpeg.
///
/// Verde DOAR daca toate componentele OBLIGATORII (isOptional == false)
/// sunt prezente — componentele optionale (foldere, Scripting API) nu
/// blocheaza starea globala, doar informeaza.
struct DependencyBadge: View {
    let dependencies: [SystemDependency]
    @Binding var showPanel: Bool

    private var isReady: Bool {
        dependencies.filter { !$0.isOptional }.allSatisfy(\.isPresent)
    }

    var body: some View {
        Button { showPanel = true } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(isReady ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                Text(isReady ? L.t("deps.badge.ready") : L.t("deps.badge.attention"))
                    .font(.caption)
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
    }
}

/// Sheet-ul deschis la click pe `DependencyBadge` — cate un rand per
/// componenta, cu status + descriere + buton de actiune daca lipseste.
struct DependencyPanel: View {
    @Binding var isPresented: Bool
    @State private var dependencies: [SystemDependency]

    init(isPresented: Binding<Bool>, dependencies: [SystemDependency]) {
        self._isPresented = isPresented
        self._dependencies = State(initialValue: dependencies)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(L.t("deps.panel.title")).font(.title3).fontWeight(.semibold)
                Text(L.t("deps.panel.subtitle")).font(.caption).foregroundStyle(.secondary)
            }

            VStack(spacing: 0) {
                ForEach(dependencies) { dep in
                    DependencyRow(dep: dep)
                    if dep.id != dependencies.last?.id {
                        Divider()
                    }
                }
            }
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            HStack {
                Button(L.t("deps.panel.recheck")) { dependencies = SystemDependencyChecker.checkAll() }
                Spacer()
                Button(L.t("deps.panel.close")) { isPresented = false }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 460)
    }
}

private struct DependencyRow: View {
    let dep: SystemDependency

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(dep.isPresent ? Color.green : (dep.isOptional ? Color.orange : Color.red))
                .frame(width: 9, height: 9)
            VStack(alignment: .leading, spacing: 2) {
                Text(dep.name).font(.subheadline).fontWeight(.medium)
                Text(dep.detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(dep.isPresent ? L.t("deps.state.ok") : (dep.isOptional ? L.t("deps.state.optionalMissing") : L.t("deps.state.missing")))
                .font(.caption)
                .foregroundStyle(dep.isPresent ? .green : (dep.isOptional ? .orange : .red))
            if !dep.isPresent, let url = dep.downloadURL {
                Button(L.t("prefs.dependencies.install")) { NSWorkspace.shared.open(url) }
                    .controlSize(.small)
            }
        }
        .padding(12)
    }
}
