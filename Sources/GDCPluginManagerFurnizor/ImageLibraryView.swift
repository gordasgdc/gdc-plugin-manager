import SwiftUI
import GDCPluginManagerCore
import AppKit

/// Bancul de imagini: tot ce s-a publicat vreodată ca imagine de prezentare,
/// cu cine folosește fiecare.
///
/// Refolosirea propriu-zisă („alege o imagine deja urcată în loc s-o încarci
/// din nou") exista deja, în `CoverImagePicker` → „Din bibliotecă…", pe toate
/// cele douăsprezece ecrane de publicare. Ce lipsea era vederea de ansamblu:
/// ce există, cât ocupă, ce nu mai folosește nimeni — și posibilitatea de a
/// face curat fără să ghicești dacă o imagine mai e legată de ceva.
struct ImageLibraryView: View {
    @State private var images: [ImageLibraryScanner.LibraryImage] = []
    @State private var showOnlyUnused = false
    @State private var selected: ImageLibraryScanner.LibraryImage?
    @State private var deleteError: String?
    @State private var isWorking = false

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: GDCTokens.Space.l)]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            if visibleImages.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: GDCTokens.Space.l) {
                        ForEach(visibleImages) { image in card(image) }
                    }
                    .padding(20)
                }
            }
        }
        .task { reload() }
        .sheet(item: $selected) { image in detailSheet(image) }
        .alert("Nu am putut șterge imaginea", isPresented: Binding(
            get: { deleteError != nil },
            set: { if !$0 { deleteError = nil } }
        )) {
            Button("Am înțeles", role: .cancel) { deleteError = nil }
        } message: {
            Text(deleteError ?? "")
        }
    }

    private var visibleImages: [ImageLibraryScanner.LibraryImage] {
        showOnlyUnused ? images.filter(\.isUnused) : images
    }

    private var unusedCount: Int { images.filter(\.isUnused).count }

    // MARK: Antet

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: GDCTokens.Space.xs) {
                Text("Banc de imagini").font(.title2).fontWeight(.semibold)
                Text(summary).font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: GDCTokens.Space.s) {
                Button {
                    reload()
                } label: {
                    Label("Rescanează", systemImage: "arrow.clockwise")
                }
                if unusedCount > 0 {
                    Toggle("Doar cele nefolosite", isOn: $showOnlyUnused)
                        .toggleStyle(.checkbox)
                        .font(.caption)
                }
            }
        }
        .padding(20)
    }

    private var summary: String {
        let total = images.reduce(Int64(0)) { $0 + $1.bytes }
        let size = ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
        if images.isEmpty { return "Nicio imagine publicată încă." }
        return unusedCount == 0
            ? "\(images.count) imagini · \(size) · toate sunt folosite"
            : "\(images.count) imagini · \(size) · \(unusedCount) nefolosite"
    }

    private var emptyState: some View {
        VStack(spacing: GDCTokens.Space.s) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 34)).foregroundStyle(.secondary)
            Text(showOnlyUnused ? "Toate imaginile sunt folosite." : "Nicio imagine publicată încă.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Cartonașul unei imagini

    private func card(_ image: ImageLibraryScanner.LibraryImage) -> some View {
        Button { selected = image } label: {
            VStack(alignment: .leading, spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: GDCTokens.Radius.control).fill(Color.secondary.opacity(0.10))
                    if let nsImage = NSImage(contentsOf: image.fileURL) {
                        Image(nsImage: nsImage).resizable().scaledToFit().padding(GDCTokens.Space.xs)
                    } else {
                        Image(systemName: "exclamationmark.triangle").foregroundStyle(GDCTokens.Palette.warning)
                    }
                }
                .frame(height: 110)

                Text(image.filename).font(.caption).lineLimit(1).truncationMode(.middle)

                HStack(spacing: 6) {
                    if image.isUnused {
                        Text("nefolosită")
                            .font(.caption2)
                            .padding(.horizontal, 6).padding(.vertical, GDCTokens.Space.xxs)
                            .background(Capsule().fill(GDCTokens.Palette.warning.opacity(0.18)))
                    } else {
                        Text("\(image.usages.count) ×")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(ByteCountFormatter.string(fromByteCount: image.bytes, countStyle: .file))
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Detaliu

    private func detailSheet(_ image: ImageLibraryScanner.LibraryImage) -> some View {
        VStack(alignment: .leading, spacing: GDCTokens.Space.l) {
            HStack {
                Text(image.filename).font(.title3).fontWeight(.semibold)
                    .lineLimit(1).truncationMode(.middle)
                Spacer()
                Button("Închide") { selected = nil }
            }

            if let nsImage = NSImage(contentsOf: image.fileURL) {
                Image(nsImage: nsImage)
                    .resizable().scaledToFit()
                    .frame(maxHeight: 240)
                    .clipShape(RoundedRectangle(cornerRadius: GDCTokens.Radius.control))
            }

            HStack(spacing: 22) {
                detailMetric("Dimensiune", ByteCountFormatter.string(fromByteCount: image.bytes, countStyle: .file))
                if let size = image.pixelSize {
                    detailMetric("Pixeli", "\(Int(size.width)) × \(Int(size.height))")
                }
                detailMetric("Folosită de", image.isUnused ? "nimeni" : "\(image.usages.count)")
            }

            if image.isUnused {
                Text("Nicio intrare din catalog nu o mai referă. Poate fi ștearsă — ștergerea se publică imediat, ca fișierul să dispară și de pe site.")
                    .font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(alignment: .leading, spacing: GDCTokens.Space.xs) {
                    Text("Folosită de").font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
                    ForEach(image.usages) { usage in
                        Text("• \(usage.ownerName)").font(.callout)
                    }
                }
            }

            Spacer()

            HStack {
                Button("Arată în Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([image.fileURL])
                }
                Spacer()
                if image.isUnused {
                    Button(role: .destructive) {
                        delete(image)
                    } label: {
                        if isWorking { ProgressView().controlSize(.small) }
                        else { Text("Șterge și publică") }
                    }
                    .disabled(isWorking)
                }
            }
        }
        .padding(22)
        .frame(width: 520, height: 540)
    }

    private func detailMetric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: GDCTokens.Space.xxs) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.callout)
        }
    }

    // MARK: Acțiuni

    private func reload() {
        images = ImageLibraryScanner.scan()
        if showOnlyUnused, images.allSatisfy({ !$0.isUnused }) { showOnlyUnused = false }
    }

    private func delete(_ image: ImageLibraryScanner.LibraryImage) {
        isWorking = true
        defer { isWorking = false }
        do {
            try ImageLibraryScanner.delete(image)
            selected = nil
            reload()
        } catch {
            deleteError = error.localizedDescription
        }
    }
}
