import SwiftUI
import GDCPluginManagerCore

/// Starea de formular a celor 5 linkuri sociale (2026-08-29).
///
/// DELIBERAT un singur `@State` per formular, nu 5 câmpuri separate: la 10
/// formulare de publicare (Produse, Resurse Download, Cursuri, Materiale,
/// Evenimente, Magazine, Service, Aplicații, Oferte Parteneri, Pachete)
/// varianta cu 5 `@State private var ...URL = ""` fiecare ar fi însemnat 50
/// de declarații + 50 de resetări + 50 de încărcări duplicate. Aici sunt
/// trei metode, folosite identic peste tot.
struct SocialLinksFormState: Equatable {
    var facebook = ""
    var youtube = ""
    var instagram = ""
    var tiktok = ""
    var linkedin = ""

    init() {}

    /// Încarcă din modelul deja publicat (la editarea unei intrări existente).
    init(_ links: SocialLinks?) {
        facebook = links?.facebookURL ?? ""
        youtube = links?.youtubeURL ?? ""
        instagram = links?.instagramURL ?? ""
        tiktok = links?.tiktokURL ?? ""
        linkedin = links?.linkedinURL ?? ""
    }

    /// `nil` dacă niciun câmp nu e completat — ca să nu scriem în
    /// `catalog.json` un obiect `socialLinks` gol pe fiecare intrare.
    var model: SocialLinks? {
        let links = SocialLinks(
            facebookURL: Self.trimmed(facebook),
            youtubeURL: Self.trimmed(youtube),
            instagramURL: Self.trimmed(instagram),
            tiktokURL: Self.trimmed(tiktok),
            linkedinURL: Self.trimmed(linkedin)
        )
        return links.isEmpty ? nil : links
    }

    mutating func reset() { self = SocialLinksFormState() }

    private static func trimmed(_ value: String) -> String? {
        let t = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}

/// Cele 5 câmpuri, fără container — pentru formularele care au deja propriul
/// `DisclosureGroup` ("Linkuri suplimentare & rețele sociale").
struct SocialLinksFields: View {
    @Binding var state: SocialLinksFormState
    /// Formularele cu tutorial YouTube propriu au nevoie de dezambiguizare.
    var youtubeLabel = "YouTube (canal)"

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Rețele sociale").font(.caption).foregroundStyle(.secondary).padding(.top, 4)
            TextField("Facebook", text: $state.facebook).textFieldStyle(.roundedBorder)
            TextField(youtubeLabel, text: $state.youtube).textFieldStyle(.roundedBorder)
            TextField("Instagram", text: $state.instagram).textFieldStyle(.roundedBorder)
            TextField("TikTok", text: $state.tiktok).textFieldStyle(.roundedBorder)
            TextField("LinkedIn", text: $state.linkedin).textFieldStyle(.roundedBorder)
        }
    }
}

/// `DisclosureGroup` gata făcut — pentru formularele care NU aveau deloc o
/// secțiune de linkuri (Cursuri, Materiale, Evenimente, Magazine, Service,
/// Aplicații). Închis implicit: nu îngroașă formularul pentru cine nu-l vrea.
struct SocialLinksSection: View {
    @Binding var state: SocialLinksFormState
    var youtubeLabel = "YouTube (canal)"

    var body: some View {
        DisclosureGroup("Rețele sociale (opțional)") {
            SocialLinksFields(state: $state, youtubeLabel: youtubeLabel)
                .padding(.top, 6)
        }
    }
}
