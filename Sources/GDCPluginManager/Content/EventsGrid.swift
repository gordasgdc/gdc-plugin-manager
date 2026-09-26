import SwiftUI
import AppKit
import GDCPluginManagerCore

struct EventsGrid: View {
    let events: [Event]

    // Mai lat decât înainte (260→300): cardurile au acum copertă și
    // descrierea se vede întreagă, deci au nevoie de spațiu ca să nu se
    // înghesuie textul pe rânduri de 3 cuvinte.
    private let columns = [GridItem(.adaptive(minimum: 300, maximum: 400), spacing: 16)]

    var body: some View {
        // Bara de filtre comuna (2026-09-11) — shadowing pe `events`,
        // deci corpul de mai jos ramane neschimbat, dar primeste lista
        // deja filtrata. Vezi CatalogFilterBar.swift.
        FilteredCatalogSection(items: events, options: .content) { events in
        ScrollView {
            if events.isEmpty {
                Text(L.t("events.empty")).foregroundStyle(.secondary).padding(40)
            } else {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(events) { event in
                        EventCard(event: event)
                    }
                }
                .padding(16)
            }
        }
        }
    }
}

struct EventCard: View {
    let event: Event

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Afișul evenimentului. Mai înalt decât la restul cardurilor:
            // afișul chiar poartă informație (dată, program, invitați), deci
            // merită spațiu — și e cazul în care lightbox-ul contează cel
            // mai mult.
            CoverThumbnail(
                url: event.coverImageURL,
                fallbackSymbol: "calendar",
                tint: .accentColor,
                height: 190,
                lightboxTitle: event.title
            )
            HStack {
                Spacer()
                if let urlString = event.youtubeURL, let url = URL(string: urlString) {
                    Button { NSWorkspace.shared.open(url) } label: {
                        Image(systemName: "play.circle")
                    }
                    .buttonStyle(.plain)
                    .help(L.t("card.youtubeLink"))
                }
            }
            Text(event.title).font(.headline)
            CountdownBadge(scheduling: event.scheduling)
            HStack(spacing: 6) {
                Text("\(event.dateDisplay) · \(event.location)")
                    .font(.caption).foregroundStyle(.secondary)
                MapButton(mapsURL: event.mapsURL)
            }
            // Multi-Locație (2026-09-05) — locații/perioade/prețuri
            // suplimentare, câte un rând per ocurență. Un eveniment fără
            // nicio ocurență suplimentară arată identic ca înainte.
            ForEach(event.occurrences) { occurrence in
                HStack(spacing: 6) {
                    Text([occurrence.dateDisplay, occurrence.location]
                        .filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.caption).foregroundStyle(.secondary)
                    MapButton(mapsURL: occurrence.mapsURL)
                    if let priceDisplay = occurrence.priceDisplay {
                        Text(priceDisplay)
                            .font(.caption2).fontWeight(.medium)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(.background.tertiary))
                    }
                }
            }
            CollapsibleDescription(text: event.description)
            Spacer(minLength: 0)
            if let url = URL(string: event.externalURL) {
                Button(L.t("events.details")) { NSWorkspace.shared.open(url) }
                    .controlSize(.small)
            }
            SocialLinksRow(event.socialLinks)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 220, alignment: .leading)
        .glassCardBackground()
    }
}
