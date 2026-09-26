import SwiftUI
import AppKit
import GDCPluginManagerCore

struct AudioGrid: View {
    let tracks: [AudioTrack]

    private let columns = [GridItem(.adaptive(minimum: 220, maximum: 280), spacing: GDCTokens.Space.grid)]

    var body: some View {
        // Bara de filtre comuna (2026-09-11) — shadowing pe `tracks`,
        // deci corpul de mai jos ramane neschimbat, dar primeste lista
        // deja filtrata. Vezi CatalogFilterBar.swift.
        FilteredCatalogSection(items: tracks, options: .content) { tracks in
        ScrollView {
            if tracks.isEmpty {
                Text(L.t("audio.empty")).foregroundStyle(.secondary).padding(GDCTokens.Space.page)
            } else {
                LazyVGrid(columns: columns, spacing: GDCTokens.Space.grid) {
                    ForEach(tracks) { track in
                        AudioCard(track: track)
                    }
                }
                .padding(GDCTokens.Space.l)
            }
        }
        }
    }
}

struct AudioCard: View {
    let track: AudioTrack

    /// Nu e un `PluginType`, la fel ca Aplicații — culoare proprie,
    /// distinctă de tot ce e deja folosit (dctl=galben, lut=verde,
    /// fuse=roz, powerGrade=mov, ofx=cyan, apps=albastru).
    private let tint = Color.indigo

    var body: some View {
        VStack(alignment: .leading, spacing: GDCTokens.Space.s) {
            Text(L.t("audio.badge"))
                .font(.system(size: 9, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(tint)
                .padding(.horizontal, GDCTokens.Space.s)
                .padding(.vertical, 3)
                .background(Capsule().fill(tint.opacity(0.15)))
                .frame(maxWidth: .infinity, alignment: .center)
            CoverThumbnail(
                url: track.coverImageURL,
                fallbackSymbol: "waveform",
                tint: tint,
                height: 56,
                lightboxTitle: track.name
            )
            Text(track.name).font(.headline)
            CountdownBadge(scheduling: track.scheduling)
            CollapsibleDescription(text: track.description)
            Spacer(minLength: 0)
            if let url = URL(string: track.url) {
                Button(L.t("audio.open")) { NSWorkspace.shared.open(url) }
            }
        }
        .padding(GDCTokens.Space.m)
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
        .glassCardBackground()
        .overlay(alignment: .topTrailing) { infoButton }
    }

    @ViewBuilder
    private var infoButton: some View {
        if let urlString = track.youtubeURL, let url = URL(string: urlString) {
            Button { NSWorkspace.shared.open(url) } label: {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                    .background(Circle().fill(.background).frame(width: 16, height: 16))
            }
            .buttonStyle(.plain)
            .help(L.t("card.youtubeLink"))
            .padding(GDCTokens.Space.s)
            .help(L.t("card.tutorial"))
        }
    }
}
