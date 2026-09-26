import SwiftUI
import AppKit
import GDCPluginManagerCore

/// Rând de iconițe pentru linkurile opționale ale unei resurse (Achiziție/
/// Demo/rețele sociale) — Etapa 2 (2026-08-29). Shared între `PluginCard`
/// și `DownloadResourceCard`, ca să nu dubleze aceeași logică. Nu se
/// randă deloc dacă niciun link nu e completat.
@ViewBuilder
func ExtraLinksRow(purchaseURL: String?, demoURL: String?, social: SocialLinks?) -> some View {
    let hasAny = purchaseURL != nil || demoURL != nil || !(social?.isEmpty ?? true)
    if hasAny {
        HStack(spacing: 10) {
            if let purchaseURL, let url = URL(string: purchaseURL) {
                LinkIconButton(systemImage: "cart", tooltip: L.t("card.purchaseLink"), url: url)
            }
            if let demoURL, let url = URL(string: demoURL) {
                LinkIconButton(systemImage: "play.circle", tooltip: L.t("card.demoLink"), url: url)
            }
            if let social {
                if let s = social.facebookURL, let url = URL(string: s) {
                    SocialIconButton(kind: .facebook, tooltip: L.t("social.facebook"), url: url)
                }
                if let s = social.youtubeURL, let url = URL(string: s) {
                    SocialIconButton(kind: .youtube, tooltip: L.t("social.youtube"), url: url)
                }
                if let s = social.instagramURL, let url = URL(string: s) {
                    SocialIconButton(kind: .instagram, tooltip: L.t("social.instagram"), url: url)
                }
                if let s = social.tiktokURL, let url = URL(string: s) {
                    SocialIconButton(kind: .tiktok, tooltip: L.t("social.tiktok"), url: url)
                }
                if let s = social.linkedinURL, let url = URL(string: s) {
                    SocialIconButton(kind: .linkedin, tooltip: L.t("social.linkedin"), url: url)
                }
            }
            Spacer()
        }
    }
}

/// Variantă doar-social a lui `ExtraLinksRow` — 2026-08-29, cerut explicit
/// ("rețelele sociale la toate rubricile", grupurile Comunitate & Educație
/// + Ecosistem GDC). NU dublează logica: e strict un wrapper peste
/// `ExtraLinksRow` pentru rubricile care nu au linkuri de achiziție/demo
/// (Cursuri, Materiale, Evenimente, Magazine, Service, Aplicații).
@ViewBuilder
func SocialLinksRow(_ social: SocialLinks?) -> some View {
    ExtraLinksRow(purchaseURL: nil, demoURL: nil, social: social)
}

func LinkIconButton(systemImage: String, tooltip: String, url: URL) -> some View {
    Button {
        NSWorkspace.shared.open(url)
    } label: {
        Image(systemName: systemImage)
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
    }
    .buttonStyle(.plain)
    .help(tooltip)
}

/// Iconițe reale de brand, colorate (Facebook/YouTube/Instagram/TikTok/
/// LinkedIn) — 2026-08-29, cerut explicit ("SF Symbols alb-negru sunt greu
/// de identificat, vreau culorile oficiale de brand"). SF Symbols n-are
/// glife de brand pentru terți (Apple nu livrează logo-uri), deci desenăm
/// SVG-uri proprii, mici, cu paleta oficială — decodate prin `NSImage(data:)`,
/// aceeași tehnică deja verificată pe filigranul sezonier (`ImageIO` are
/// suport SVG pe macOS 12+, INCLUSIV gradienți liniari — verificat direct
/// cu un test izolat înainte de a alege această cale pentru Instagram).
// `SocialIconKind` a fost mutat în BrandIcon.swift (2026-09-14): îl
// folosesc acum două ecrane — cardurile de produs și secțiunea Comunitate.

func SocialIconButton(kind: SocialIconKind, tooltip: String, url: URL) -> some View {
    Button {
        NSWorkspace.shared.open(url)
    } label: {
        Group {
            if let nsImage = NSImage(data: Data(kind.svg.utf8)) {
                Image(nsImage: nsImage).resizable().aspectRatio(contentMode: .fit)
            } else {
                // Fallback defensiv — n-ar trebui să se întâmple niciodată
                // (SVG-urile de mai sus sunt statice, testate), dar un card
                // nu trebuie să lase un gol/crash dacă decodarea eșuează.
                Image(systemName: "link.circle").foregroundStyle(.secondary)
            }
        }
        .frame(width: 16, height: 16)
    }
    .buttonStyle(.plain)
    .help(tooltip)
}

/// Buton compact "deschide în Google Maps" — Etapa 5 (2026-08-29). Nu se
/// randă deloc dacă `mapsURL` e nil (adresă lipsă/goală).
@ViewBuilder
func MapButton(mapsURL: URL?) -> some View {
    if let mapsURL {
        Button {
            NSWorkspace.shared.open(mapsURL)
        } label: {
            Label(L.t("maps.open"), systemImage: "map")
        }
        .controlSize(.small)
    }
}
