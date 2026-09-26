import SwiftUI
import AppKit
import GDCPluginManagerCore

/// Secțiunea Comunitate: canalele de suport și resursele publicate din
/// Furnizor, ca grilă de carduri.
///
/// Link-urile se deschid ÎNTOTDEAUNA în browserul sistemului
/// (`NSWorkspace.shared.open`), niciodată într-un webview încorporat: un grup
/// de Facebook sau WhatsApp cere sesiunea reală a utilizatorului, iar un
/// webview i-ar cere să se autentifice din nou, într-o fereastră în care n-are
/// niciun motiv să aibă încredere.
struct CommunityGrid: View {
    let channels: [CommunityChannel]

    private let columns = [GridItem(.adaptive(minimum: 260), spacing: GDCTokens.Space.l)]

    var body: some View {
        if channels.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: GDCTokens.Space.l) {
                    ForEach(channels) { channel in
                        CommunityChannelCard(channel: channel)
                    }
                }
                .padding(20)
            }
        }
    }

    /// Stare goală explicită: secțiunea există în bara laterală chiar și
    /// înainte ca vreun canal să fie publicat, iar o pagină complet albă ar
    /// părea o eroare de încărcare.
    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "person.2.wave.2")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text(L.t("community.empty.title")).font(.headline)
            Text(L.t("community.empty.subtitle"))
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct CommunityChannelCard: View {
    let channel: CommunityChannel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                icon
                Text(channel.title)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }

            Text(channel.description)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                // Rezervă locul pentru două rânduri chiar și când descrierea
                // are unul: altfel butoanele cardurilor de pe același rând
                // ies la înălțimi diferite.
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)

            if let destination = channel.destination {
                Button {
                    NSWorkspace.shared.open(destination)
                } label: {
                    Text(L.t(channel.kind.actionLabelKey))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .help(destination.absoluteString)
            }
        }
        .padding(GDCTokens.Space.l)
        .frame(minHeight: 172, alignment: .topLeading)
        .glassCardBackground()
    }

    /// Iconița de brand, cu retragere în trepte: SVG-ul brandului dacă cheia
    /// e cunoscută, altfel un simbol SF potrivit tipului de canal. Un card
    /// fără iconiță arată stricat, iar cheia vine din catalog — deci poate
    /// fi oricând una pe care versiunea asta n-o cunoaște.
    @ViewBuilder
    private var icon: some View {
        if let brand = SocialIconKind.named(channel.icon), let image = brand.image {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 28, height: 28)
        } else {
            Image(systemName: fallbackSymbol)
                .font(.system(size: 22))
                .frame(width: 28, height: 28)
                .foregroundStyle(.tint)
        }
    }

    private var fallbackSymbol: String {
        switch channel.kind {
        case .community: return "person.2"
        case .chat: return "bubble.left.and.bubble.right"
        case .video: return "play.rectangle"
        case .docs: return "doc.text"
        case .feedback: return "exclamationmark.bubble"
        }
    }
}
