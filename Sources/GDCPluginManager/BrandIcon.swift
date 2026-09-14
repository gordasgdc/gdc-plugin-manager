import SwiftUI
import AppKit

/// Iconițele de brand folosite în aplicație, ca SVG-uri inline.
///
/// DE CE SVG ÎN COD, nu fișiere din bundle: iconițele astea apar pe cardurile
/// de produs (`ExtraLinksRow`) și în secțiunea Comunitate, adică în locuri
/// randate înainte ca orice resursă externă să fie disponibilă. Inline nu pot
/// lipsi dintr-un build, nu pot fi uitate la copierea resurselor în .app (bug
/// real, vezi comentariul din `FurnizorGuidePDF`) și nu costă nicio cerere de
/// rețea. Sunt desene simple, fără dependințe.
///
/// [2026-09-14] Mutat din ContentView.swift: îl folosesc acum două ecrane.

enum SocialIconKind {
    case facebook, youtube, instagram, tiktok, linkedin
    case whatsapp, discord, telegram, github, web

    var svg: String {
        switch self {
        case .facebook:
            return ##"<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><circle cx="12" cy="12" r="12" fill="#1877F2"/><path fill="#fff" d="M15.1 12.7h-2.1v6.8h-2.8v-6.8H8.6v-2.4h1.6V8.7c0-1.9 1-3 3.1-3h1.9v2.4h-1.2c-.8 0-.9.3-.9 1v1.2h2.2z"/></svg>"##
        case .youtube:
            return ##"<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><rect x="1" y="4" width="22" height="16" rx="5" fill="#FF0000"/><path fill="#fff" d="M10 8.3l6.2 3.7-6.2 3.7z"/></svg>"##
        case .instagram:
            return ##"<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><defs><linearGradient id="igGrad" x1="0" y1="1" x2="1" y2="0"><stop offset="0%" stop-color="#FEDA75"/><stop offset="30%" stop-color="#FA7E1E"/><stop offset="55%" stop-color="#D62976"/><stop offset="80%" stop-color="#962FBF"/><stop offset="100%" stop-color="#4F5BD5"/></linearGradient></defs><rect x="1.5" y="1.5" width="21" height="21" rx="6.3" fill="url(#igGrad)"/><rect x="6.7" y="6.7" width="10.6" height="10.6" rx="3.4" fill="none" stroke="#fff" stroke-width="1.6"/><circle cx="12" cy="12" r="3" fill="none" stroke="#fff" stroke-width="1.6"/><circle cx="17.1" cy="6.9" r="1.1" fill="#fff"/></svg>"##
        case .tiktok:
            return ##"<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><rect x="1" y="1" width="22" height="22" rx="6.5" fill="#010101"/><path fill="#25F4EE" d="M14.8 4.4c.4 2 1.9 3.4 3.9 3.6v2.5c-1.4 0-2.8-.4-3.9-1.2v6c0 3-2.4 5.4-5.3 5.4-2.9 0-5.3-2.4-5.3-5.4 0-2.9 2.3-5.2 5.1-5.4v2.6c-1.3.2-2.3 1.3-2.3 2.7 0 1.5 1.3 2.8 2.8 2.8 1.6 0 2.8-1.3 2.8-2.8V4.4h2.2z"/><path fill="#FE2C55" d="M13.5 4.4c.4 2 1.9 3.4 3.9 3.6v2.5c-1.4 0-2.8-.4-3.9-1.2v6c0 3-2.4 5.4-5.3 5.4-1.1 0-2.2-.4-3-1 .8.3 1.7.4 2.6.2 1.9-.3 3.4-1.9 3.5-3.8V4.4h2.2z" opacity=".8"/></svg>"##
        case .linkedin:
            return ##"<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><rect x="1" y="1" width="22" height="22" rx="4.5" fill="#0A66C2"/><circle cx="7.2" cy="7.6" r="1.7" fill="#fff"/><rect x="5.7" y="10.3" width="3" height="8.1" fill="#fff"/><path fill="#fff" d="M11.1 10.3h2.9v1.3h.04c.4-.75 1.4-1.5 2.9-1.5 3.1 0 3.6 2 3.6 4.6v4.7h-3v-4.2c0-1 0-2.3-1.4-2.3-1.4 0-1.6 1.1-1.6 2.2v4.3h-3z"/></svg>"##
        case .whatsapp:
            return ##"<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><circle cx="12" cy="12" r="12" fill="#25D366"/><path fill="#fff" d="M12 5.4c-3.6 0-6.6 2.9-6.6 6.6 0 1.2.3 2.3.9 3.3l-1 3.5 3.6-.9c.9.5 2 .8 3.1.8 3.6 0 6.6-2.9 6.6-6.6S15.6 5.4 12 5.4zm3.8 9.3c-.2.5-.9.9-1.4.9-.4 0-.8.1-2.7-.7-2.3-.9-3.7-3.2-3.8-3.4-.1-.2-.9-1.2-.9-2.2s.5-1.5.7-1.7c.2-.2.4-.3.6-.3h.4c.1 0 .3 0 .5.4l.7 1.6c.1.1.1.3 0 .4l-.2.3-.3.3c-.1.1-.2.2-.1.4.1.2.5.9 1.1 1.4.8.7 1.4.9 1.6 1 .2.1.3.1.4 0l.6-.7c.1-.2.3-.2.4-.1l1.5.7c.2.1.4.2.4.3.1.1.1.5-.1 1z"/></svg>"##
        case .discord:
            return ##"<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><rect x="1" y="1" width="22" height="22" rx="6.5" fill="#5865F2"/><path fill="#fff" d="M16.5 7.9c-.9-.4-1.8-.7-2.8-.9l-.4.7c-1-.1-1.9-.1-2.8 0l-.4-.7c-1 .2-1.9.5-2.8.9-1.7 2.6-2.2 5.1-2 7.6 1.2.9 2.3 1.4 3.4 1.7l.8-1.2c-.4-.2-.9-.4-1.3-.6l.3-.2c2.5 1.2 5.2 1.2 7.7 0l.3.2c-.4.3-.8.5-1.3.6l.8 1.2c1.1-.3 2.2-.9 3.4-1.7.3-2.9-.5-5.4-2-7.6zM9.7 14c-.7 0-1.2-.6-1.2-1.4s.5-1.4 1.2-1.4 1.2.6 1.2 1.4-.5 1.4-1.2 1.4zm4.6 0c-.7 0-1.2-.6-1.2-1.4s.5-1.4 1.2-1.4 1.2.6 1.2 1.4-.5 1.4-1.2 1.4z"/></svg>"##
        case .telegram:
            return ##"<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><circle cx="12" cy="12" r="12" fill="#2AABEE"/><path fill="#fff" d="M5.6 11.9l11-4.2c.5-.2 1 .1.8.9l-1.9 8.8c-.1.6-.5.8-1 .5l-2.8-2.1-1.3 1.3c-.2.2-.3.3-.6.3l.2-3 5.4-4.9c.2-.2 0-.3-.3-.1l-6.7 4.2-2.9-.9c-.6-.2-.6-.6.1-.8z"/></svg>"##
        case .github:
            return ##"<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><circle cx="12" cy="12" r="12" fill="#181717"/><path fill="#fff" d="M12 4.6a7.4 7.4 0 00-2.3 14.4c.4.1.5-.2.5-.4v-1.3c-2.1.4-2.5-1-2.5-1-.3-.9-.8-1.1-.8-1.1-.7-.5 0-.4 0-.4.7 0 1.1.8 1.1.8.7 1.1 1.8.8 2.2.6.1-.5.3-.8.5-1-1.7-.2-3.4-.8-3.4-3.7 0-.8.3-1.5.8-2-.1-.2-.4-1 .1-2 0 0 .6-.2 2 .8a7 7 0 013.7 0c1.4-1 2-.8 2-.8.5 1 .2 1.8.1 2 .5.5.8 1.2.8 2 0 2.9-1.7 3.5-3.4 3.7.3.2.5.7.5 1.4v2c0 .2.1.5.6.4A7.4 7.4 0 0012 4.6z"/></svg>"##
        case .web:
            return ##"<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><circle cx="12" cy="12" r="10.5" fill="none" stroke="#6E7781" stroke-width="1.6"/><ellipse cx="12" cy="12" rx="4.6" ry="10.5" fill="none" stroke="#6E7781" stroke-width="1.6"/><path d="M2.2 9h19.6M2.2 15h19.6" stroke="#6E7781" stroke-width="1.6"/></svg>"##
        }
    }

    var label: String {
        switch self {
        case .facebook: return "Facebook"
        case .youtube: return "YouTube"
        case .instagram: return "Instagram"
        case .tiktok: return "TikTok"
        case .linkedin: return "LinkedIn"
        case .whatsapp: return "WhatsApp"
        case .discord: return "Discord"
        case .telegram: return "Telegram"
        case .github: return "GitHub"
        case .web: return "Web"
        }
    }

    /// Cheia din `catalog.json` → iconița. Necunoscut sau gol → `nil`, iar
    /// apelantul cade pe un simbol SF neutru. O iconiță nouă publicată din
    /// Furnizor nu are voie să lase un card gol pe un client vechi.
    static func named(_ key: String?) -> SocialIconKind? {
        guard let key = key?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !key.isEmpty else { return nil }
        switch key {
        case "facebook", "fb": return .facebook
        case "youtube", "yt": return .youtube
        case "instagram", "ig": return .instagram
        case "tiktok": return .tiktok
        case "linkedin": return .linkedin
        case "whatsapp", "wa": return .whatsapp
        case "discord": return .discord
        case "telegram": return .telegram
        case "github", "git": return .github
        case "web", "site", "website": return .web
        default: return nil
        }
    }

    /// Imaginea randabilă, sau `nil` dacă decodarea SVG-ului eșuează.
    var image: NSImage? { NSImage(data: Data(svg.utf8)) }
}

