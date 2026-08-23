import SwiftUI
import AppKit
import GDCPluginManagerCore

/// Afisarea coperilor de produs in client + previewul marit (lightbox).
///
/// ARCHITECTURE NOTE: coperile se descarca de la un URL PUBLIC
/// (`gordas.dev/covers/...` sau CDN-ul furnizorului) — vezi `CatalogAssets`.
/// Spre deosebire de fisierele vandabile, NU trec prin `InstallManager` si
/// nu au nevoie de tokenul din `PrivateCatalogAuth`: sunt material de
/// prezentare, nu continut protejat. Deci `AsyncImage` simplu e suficient.
///
/// WARNING: o coperta poate lipsi din doua motive perfect normale —
/// produsul n-are inca una (`coverImage == nil`), sau e un URL extern pe
/// CDN-ul furnizorului care a disparut intre timp. In ambele cazuri cadem
/// pe simbolul SF (`iconSymbol`), niciodata pe un chenar spart sau pe o
/// eroare vizibila: e un card de magazin, nu un ecran de diagnostic.

// MARK: - Miniatura din card

/// Coperta afisata in capul unui card. Daca lipseste sau nu se incarca,
/// arata simbolul dat ca fallback, la aceeasi dimensiune — cardurile
/// raman aliniate in grila indiferent cate produse au imagine.
struct CoverThumbnail: View {
    let url: URL?
    let fallbackSymbol: String
    let tint: Color
    /// Inaltimea zonei de imagine. Latimea o da grila.
    var height: CGFloat = 120
    /// Titlul aratat in lightbox — de obicei numele produsului.
    var lightboxTitle: String = ""

    @State private var showLightbox = false
    /// Ramane fals daca imaginea n-a apucat (inca) sa se incarce; fara el
    /// am deschide un lightbox gol la click pe placeholder.
    @State private var didLoad = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(tint.opacity(0.10))

            if let url {
                AsyncImage(url: url, transaction: Transaction(animation: .easeOut(duration: 0.15))) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            // `.fill` + clip: cardurile au proportii fixe,
                            // dar coperile nu (un afis de eveniment e
                            // portret, o coperta de curs e peisaj). Umplem
                            // si taiem, ca sa nu ramana benzi goale.
                            .aspectRatio(contentMode: .fill)
                            .onAppear { didLoad = true }
                    case .failure:
                        // URL extern disparut de pe CDN — cadem pe simbol,
                        // fara sa aratam vreo eroare userului.
                        fallbackIcon
                    case .empty:
                        ProgressView().controlSize(.small)
                    @unknown default:
                        fallbackIcon
                    }
                }
            } else {
                fallbackIcon
            }
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
        .onTapGesture {
            guard didLoad, url != nil else { return }
            showLightbox = true
        }
        // Cursor de "click-abil" doar cand chiar e ceva de marit.
        .onHover { inside in
            guard didLoad, url != nil else { return }
            if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
        .help(didLoad && url != nil ? L.t("cover.zoom.hint") : "")
        .sheet(isPresented: $showLightbox) {
            if let url {
                ImageLightbox(url: url, title: lightboxTitle)
            }
        }
    }

    private var fallbackIcon: some View {
        Image(systemName: fallbackSymbol)
            .font(.system(size: 30))
            .foregroundStyle(tint)
    }
}

// MARK: - Lightbox

/// Previewul marit, deschis la click pe o coperta. Imaginea se vede
/// intreaga (`.fit`, nu `.fill` ca in card) si se poate mari cu scroll,
/// pinch pe trackpad, sau dublu-click.
struct ImageLightbox: View {
    let url: URL
    let title: String

    @Environment(\.dismiss) private var dismiss

    @State private var zoom: CGFloat = 1
    /// Zoom-ul "asezat" dintre gesturi — fara el, fiecare pinch nou ar
    /// reporni de la 1x in loc sa continue de unde s-a oprit.
    @State private var committedZoom: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var committedOffset: CGSize = .zero

    private static let minZoom: CGFloat = 1
    private static let maxZoom: CGFloat = 5

    var body: some View {
        VStack(spacing: 0) {
            header

            ZStack {
                Color.black.opacity(0.03)

                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .scaleEffect(zoom)
                            .offset(offset)
                            .gesture(magnification)
                            .gesture(drag)
                            .onTapGesture(count: 2) { toggleZoom() }
                    case .failure:
                        VStack(spacing: 8) {
                            Image(systemName: "photo.badge.exclamationmark")
                                .font(.system(size: 36)).foregroundStyle(.secondary)
                            Text(L.t("cover.failed")).foregroundStyle(.secondary)
                        }
                    case .empty:
                        ProgressView()
                    @unknown default:
                        EmptyView()
                    }
                }
                .padding(20)
            }
            .clipped()
        }
        .frame(minWidth: 620, idealWidth: 900, minHeight: 460, idealHeight: 680)
        // Escape inchide — o fereastra de preview trebuie sa se inchida cu
        // reflexul obisnuit, nu doar de la buton.
        .background(DismissOnEscape { dismiss() })
    }

    private var header: some View {
        HStack {
            if !title.isEmpty {
                Text(title).font(.headline)
            }
            Spacer()
            if zoom > Self.minZoom {
                Button(L.t("cover.reset")) { resetZoom() }
                    .controlSize(.small)
            }
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: Gesturi

    private var magnification: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                zoom = clampZoom(committedZoom * value.magnification)
            }
            .onEnded { _ in
                committedZoom = zoom
                if zoom <= Self.minZoom { resetZoom() }
            }
    }

    /// Mutarea imaginii are sens doar cand e marita — la 1x nu e nimic in
    /// afara cadrului de tras.
    private var drag: some Gesture {
        DragGesture()
            .onChanged { value in
                guard zoom > Self.minZoom else { return }
                offset = CGSize(
                    width: committedOffset.width + value.translation.width,
                    height: committedOffset.height + value.translation.height
                )
            }
            .onEnded { _ in committedOffset = offset }
    }

    private func toggleZoom() {
        withAnimation(.easeOut(duration: 0.2)) {
            if zoom > Self.minZoom {
                resetZoom()
            } else {
                zoom = 2
                committedZoom = 2
            }
        }
    }

    private func resetZoom() {
        withAnimation(.easeOut(duration: 0.2)) {
            zoom = Self.minZoom
            committedZoom = Self.minZoom
            offset = .zero
            committedOffset = .zero
        }
    }

    private func clampZoom(_ value: CGFloat) -> CGFloat {
        min(max(value, Self.minZoom), Self.maxZoom)
    }
}

/// Prinde tasta Escape intr-un sheet SwiftUI.
///
/// NOTE: `.keyboardShortcut(.cancelAction)` de pe butonul de inchidere
/// acopera deja cazul obisnuit, dar numai cat timp butonul are focus in
/// lantul de responder. Cand userul tocmai a tras de imagine, focusul e pe
/// zona de gesturi si Escape s-ar pierde — de-aici acest NSViewRepresentable
/// care asculta la nivel de fereastra.
private struct DismissOnEscape: NSViewRepresentable {
    let action: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = KeyCatcherView()
        view.action = action
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? KeyCatcherView)?.action = action
    }

    private final class KeyCatcherView: NSView {
        var action: (() -> Void)?
        private var monitor: Any?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard window != nil, monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                // 53 = Escape
                guard event.keyCode == 53 else { return event }
                self?.action?()
                return nil
            }
        }

        deinit {
            // Fara asta, fiecare deschidere de lightbox ar lasa in urma un
            // monitor global care raspunde in continuare la Escape.
            if let monitor { NSEvent.removeMonitor(monitor) }
        }
    }
}
