import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case ro, en, es
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .ro: return "Română"
        case .en: return "English"
        case .es: return "Español"
        }
    }
}

/// Tiny in-app translation table, independent of system locale — same
/// RO-default / EN / ES pattern as CursorPro GDC / GDC License Manager.
enum L {
    static var current: AppLanguage {
        get {
            if let raw = UserDefaults.standard.string(forKey: "gdcpm_lang"),
               let lang = AppLanguage(rawValue: raw) {
                return lang
            }
            return .ro
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "gdcpm_lang") }
    }

    static func t(_ key: String) -> String {
        table[key]?[current] ?? table[key]?[.ro] ?? key
    }

    private static let table: [String: [AppLanguage: String]] = [
        "app.name": [.ro: "GDC Plugin Manager", .en: "GDC Plugin Manager", .es: "GDC Plugin Manager"],
        "app.tagline": [.ro: "Aplicație gratuită pentru Mac — instalează DCTL-uri, LUT-uri și Fuse-uri direct în DaVinci Resolve. Cumperi doar produsele pe care le vrei.", .en: "Free Mac app — install DCTLs, LUTs and Fuses straight into DaVinci Resolve. You only pay for the products you want.", .es: "Aplicación gratuita para Mac — instala DCTLs, LUTs y Fuses directamente en DaVinci Resolve. Solo pagas por los productos que quieres."],

        "sidebar.all": [.ro: "Toate", .en: "All", .es: "Todos"],
        "sidebar.dctl": [.ro: "DCTL", .en: "DCTL", .es: "DCTL"],
        "sidebar.lut": [.ro: "LUT", .en: "LUT", .es: "LUT"],
        "sidebar.fuse": [.ro: "Fuse", .en: "Fuse", .es: "Fuse"],
        "sidebar.license": [.ro: "Licență", .en: "License", .es: "Licencia"],
        "sidebar.help": [.ro: "Ajutor", .en: "Help", .es: "Ayuda"],
        "sidebar.courses": [.ro: "Cursuri", .en: "Courses", .es: "Cursos"],
        "sidebar.apps": [.ro: "Aplicații", .en: "Apps", .es: "Aplicaciones"],

        "catalog.loading": [.ro: "Se încarcă catalogul…", .en: "Loading catalog…", .es: "Cargando catálogo…"],
        "catalog.empty": [.ro: "Niciun produs în această categorie.", .en: "No items in this category.", .es: "No hay elementos en esta categoría."],
        "catalog.error": [.ro: "Nu am putut încărca catalogul. Verifică conexiunea la internet.", .en: "Couldn't load the catalog. Check your internet connection.", .es: "No se pudo cargar el catálogo. Comprueba tu conexión a internet."],
        "catalog.refresh": [.ro: "Reîmprospătează", .en: "Refresh", .es: "Actualizar"],

        "card.install": [.ro: "Instalează", .en: "Install", .es: "Instalar"],
        "card.installing": [.ro: "Se instalează…", .en: "Installing…", .es: "Instalando…"],
        "card.installed": [.ro: "Instalat", .en: "Installed", .es: "Instalado"],
        "card.update": [.ro: "Actualizează", .en: "Update", .es: "Actualizar"],
        "card.remove": [.ro: "Elimină", .en: "Remove", .es: "Eliminar"],
        "card.version": [.ro: "versiunea", .en: "version", .es: "versión"],
        "card.buy": [.ro: "Cumpără", .en: "Buy", .es: "Comprar"],
        "card.free": [.ro: "Gratuit", .en: "Free", .es: "Gratis"],
        "card.trial": [.ro: "Probă", .en: "Trial", .es: "Prueba"],

        "courses.empty": [.ro: "Niciun curs disponibil momentan.", .en: "No courses available right now.", .es: "Ningún curso disponible por ahora."],
        "courses.contact": [.ro: "Contactează", .en: "Contact", .es: "Contactar"],
        "courses.contact.message": [.ro: "Salut! Vreau să rezerv cursul %@ — %@ (%@).", .en: "Hi! I'd like to book the course %@ — %@ (%@).", .es: "¡Hola! Quiero reservar el curso %@ — %@ (%@)."],

        "apps.empty": [.ro: "Nicio aplicație listată momentan.", .en: "No apps listed right now.", .es: "Ninguna aplicación listada por ahora."],
        "apps.open": [.ro: "Deschide", .en: "Open", .es: "Abrir"],

        "resolve.running.title": [.ro: "DaVinci Resolve rulează", .en: "DaVinci Resolve is running", .es: "DaVinci Resolve está abierto"],
        "resolve.running.body": [.ro: "Închide DaVinci Resolve înainte de a instala sau elimina plugin-uri — Resolve le încarcă doar la pornire.", .en: "Quit DaVinci Resolve before installing or removing plugins — Resolve only loads them at launch.", .es: "Cierra DaVinci Resolve antes de instalar o eliminar plugins — Resolve solo los carga al iniciar."],
        "resolve.running.ok": [.ro: "Am înțeles", .en: "Got it", .es: "Entendido"],

        "license.pane.title": [.ro: "Licență", .en: "License", .es: "Licencia"],
        "license.status.none": [.ro: "Niciun produs deblocat încă", .en: "No products unlocked yet", .es: "Ningún producto desbloqueado todavía"],
        "license.status.none.body": [.ro: "Aplicația e gratuită — răsfoiește catalogul și cumpără doar ce vrei să folosești.", .en: "The app is free — browse the catalog and buy only what you want to use.", .es: "La aplicación es gratuita — explora el catálogo y compra solo lo que quieras usar."],
        "license.status.owned": [.ro: "Produse deblocate", .en: "Products unlocked", .es: "Productos desbloqueados"],
        "license.status.owned.body": [.ro: "Ai %d produs(e) deblocat(e) pe viață, pe acest calculator.", .en: "You own %d product(s), unlocked for life on this computer.", .es: "Tienes %d producto(s) desbloqueado(s) de por vida en este ordenador."],
        "license.machineID.title": [.ro: "ID-ul acestui calculator", .en: "This computer's ID", .es: "ID de este ordenador"],
        "license.machineID.body": [.ro: "Trimite acest ID când cumperi licența — codul e legat de acest calculator.", .en: "Send this ID when you buy the license — the code is locked to this computer.", .es: "Envía este ID al comprar la licencia — el código queda vinculado a este ordenador."],
        "license.machineID.copy": [.ro: "Copiază", .en: "Copy", .es: "Copiar"],
        "license.machineID.copied": [.ro: "Copiat.", .en: "Copied.", .es: "Copiado."],
        "license.field.placeholder": [.ro: "Cod serial", .en: "Serial code", .es: "Código serial"],
        "license.activate": [.ro: "Activează", .en: "Activate", .es: "Activar"],
        "license.activated.success": [.ro: "Activat cu succes!", .en: "Activated successfully!", .es: "¡Activado correctamente!"],
        "license.deactivate": [.ro: "Dezactivează", .en: "Deactivate", .es: "Desactivar"],
        "license.mylicenses.title": [.ro: "Licențele mele", .en: "My licenses", .es: "Mis licencias"],
        "license.buy.title": [.ro: "Vrei să deblochezi un produs?", .en: "Want to unlock a product?", .es: "¿Quieres desbloquear un producto?"],
        "license.buy.price": [.ro: "Prețul de pe fiecare card e o donație, o singură dată, care mă ajută să dezvolt în continuare produsele.", .en: "The price on each card is a one-time donation that helps me keep developing these products.", .es: "El precio de cada tarjeta es una donación única que me ayuda a seguir desarrollando estos productos."],
        "license.buy.button": [.ro: "Scrie-ne pe WhatsApp", .en: "Message us on WhatsApp", .es: "Escríbenos por WhatsApp"],
        "card.donation": [.ro: "donație", .en: "donation", .es: "donación"],

        "license.error.malformed": [.ro: "Codul nu e valid — verifică să-l fi copiat complet.", .en: "That code isn't valid — check you copied all of it.", .es: "Ese código no es válido — comprueba que lo copiaste completo."],
        "license.error.badSignature": [.ro: "Codul nu e valid.", .en: "That code isn't valid.", .es: "Ese código no es válido."],
        "license.error.wrongProduct": [.ro: "Acest cod nu se potrivește cu niciun produs din catalogul curent.", .en: "This code doesn't match any product in the current catalog.", .es: "Este código no coincide con ningún producto del catálogo actual."],
        "license.error.wrongMachine": [.ro: "Acest cod e activat pentru alt calculator.", .en: "This code is activated for a different Mac.", .es: "Este código está activado para otro Mac."],
        "license.error.expired": [.ro: "Acest cod a expirat.", .en: "This code has expired.", .es: "Este código ha caducado."],
        "license.error.catalogNotLoaded": [.ro: "Catalogul nu s-a încărcat încă — reîmprospătează și încearcă din nou.", .en: "The catalog hasn't loaded yet — refresh and try again.", .es: "El catálogo aún no se ha cargado — actualiza e inténtalo de nuevo."],

        "help.title": [.ro: "Ajutor", .en: "Help", .es: "Ayuda"],
        "help.what.title": [.ro: "Ce este GDC Plugin Manager", .en: "What is GDC Plugin Manager", .es: "Qué es GDC Plugin Manager"],
        "help.what.body": [.ro: "Un catalog cu produsele mele (DCTL, LUT, Fuse) pentru DaVinci Resolve. Aplicație nativă doar pentru Mac (Apple Silicon), gratuită — o descarci și răsfoiești catalogul oricând, fără cont și fără nicio taxă.", .en: "A catalog of my own products (DCTL, LUT, Fuse) for DaVinci Resolve. A native Mac-only app (Apple Silicon), free — download it and browse the catalog anytime, no account, no fee.", .es: "Un catálogo de mis propios productos (DCTL, LUT, Fuse) para DaVinci Resolve. Aplicación nativa solo para Mac (Apple Silicon), gratuita — descárgala y explora el catálogo cuando quieras, sin cuenta ni coste."],
        "help.buy.title": [.ro: "Cum deblochezi un produs", .en: "How to unlock a product", .es: "Cómo desbloquear un producto"],
        "help.buy.body": [.ro: "Prețul de pe fiecare card e o donație, o singură dată, care mă ajută să dezvolt în continuare produsele — nu un abonament. Apeși „Cumpără” pe cardul produsului, se deschide WhatsApp cu mesajul completat — îți trimit înapoi un cod legat de calculatorul tău, pe care îl lipești în pagina „Licență”.", .en: "The price on each card is a one-time donation that helps me keep developing these products — not a subscription. Tap “Buy” on the product's card, WhatsApp opens with the message pre-filled — I send back a code locked to your computer, which you paste into the “License” page.", .es: "El precio de cada tarjeta es una donación única que me ayuda a seguir desarrollando estos productos — no una suscripción. Pulsa “Comprar” en la tarjeta del producto, se abre WhatsApp con el mensaje ya escrito — te envío de vuelta un código vinculado a tu ordenador, que pegas en la página “Licencia”."],
        "help.install.title": [.ro: "Cum funcționează instalarea", .en: "How installing works", .es: "Cómo funciona la instalación"],
        "help.install.body": [.ro: "După activare, apeși „Instalează” și fișierul ajunge direct în folderul corect al DaVinci Resolve — nu trebuie să cauți nimic manual. Dacă Resolve e deschis, aplicația te anunță să-l închizi întâi (Resolve încarcă plugin-urile doar la pornire).", .en: "After activating, tap “Install” and the file goes straight into DaVinci Resolve's correct folder — no manual hunting for folders. If Resolve is open, the app tells you to close it first (Resolve only loads plugins at launch).", .es: "Después de activar, pulsa “Instalar” y el archivo va directo a la carpeta correcta de DaVinci Resolve — sin buscar nada manualmente. Si Resolve está abierto, la app te avisa que lo cierres primero (Resolve solo carga los plugins al iniciar)."],
        "help.machine.title": [.ro: "ID-ul calculatorului", .en: "Your computer's ID", .es: "El ID de tu ordenador"],
        "help.machine.body": [.ro: "Fiecare cod de activare e legat de un singur calculator, identificat printr-un ID afișat în pagina „Licență”. Trimite acel ID când cumperi, ca să primești un cod care funcționează pe calculatorul tău.", .en: "Each activation code is locked to one computer, identified by an ID shown on the “License” page. Send that ID when buying, so you get a code that works on your computer.", .es: "Cada código de activación está vinculado a un único ordenador, identificado por un ID que aparece en la página “Licencia”. Envía ese ID al comprar, para recibir un código que funcione en tu ordenador."],
        "help.updates.title": [.ro: "Actualizări", .en: "Updates", .es: "Actualizaciones"],
        "help.updates.body": [.ro: "Aplicația verifică automat dacă există o versiune nouă și te anunță printr-un banner cu link de descărcare. Catalogul de produse se actualizează singur ori de câte ori apeși „Reîmprospătează”.", .en: "The app automatically checks for a newer version and shows a banner with a download link. The product catalog refreshes on its own whenever you tap “Refresh”.", .es: "La app comprueba automáticamente si hay una versión nueva y te avisa con un banner con enlace de descarga. El catálogo de productos se actualiza solo cada vez que pulsas “Actualizar”."],
        "help.support.title": [.ro: "Suport", .en: "Support", .es: "Soporte"],
        "help.support.body": [.ro: "Ai o problemă sau o întrebare? Scrie-mi pe WhatsApp din pagina „Licență” — răspund direct.", .en: "Have a problem or a question? Message me on WhatsApp from the “License” page — I reply directly.", .es: "¿Tienes un problema o una pregunta? Escríbeme por WhatsApp desde la página “Licencia” — respondo directamente."],

        "update.title": [.ro: "Versiune nouă disponibilă", .en: "New version available", .es: "Nueva versión disponible"],
        "update.download": [.ro: "Descarcă", .en: "Download", .es: "Descargar"],
        "update.dismiss": [.ro: "Închide", .en: "Dismiss", .es: "Cerrar"],

        "menu.quit": [.ro: "Închide GDC Plugin Manager", .en: "Quit GDC Plugin Manager", .es: "Salir de GDC Plugin Manager"],
    ]
}
