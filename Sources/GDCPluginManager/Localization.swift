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

/// Backs `L.current` with an `@Published` value so SwiftUI actually
/// redraws when the language changes — a plain UserDefaults-backed
/// computed property (the original implementation) persists correctly
/// but gives SwiftUI nothing to observe, so no view would ever refresh
/// after a language switch without this.
final class LanguageStore: ObservableObject {
    static let shared = LanguageStore()

    @Published var current: AppLanguage {
        didSet { UserDefaults.standard.set(current.rawValue, forKey: "gdcpm_lang") }
    }

    private init() {
        if let raw = UserDefaults.standard.string(forKey: "gdcpm_lang"), let lang = AppLanguage(rawValue: raw) {
            current = lang
        } else {
            current = .ro
        }
    }
}

/// Tiny in-app translation table, independent of system locale — same
/// RO-default / EN / ES pattern as CursorPro GDC / GDC License Manager.
enum L {
    static var current: AppLanguage {
        get { LanguageStore.shared.current }
        set { LanguageStore.shared.current = newValue }
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
        "sidebar.educationalResources": [.ro: "Materiale", .en: "Materials", .es: "Materiales"],
        "sidebar.events": [.ro: "Evenimente", .en: "Events", .es: "Eventos"],
        "sidebar.partnerStores": [.ro: "Magazine partenere", .en: "Partner stores", .es: "Tiendas asociadas"],
        "sidebar.apps": [.ro: "Aplicații", .en: "Apps", .es: "Aplicaciones"],
        "sidebar.android": [.ro: "Android", .en: "Android", .es: "Android"],

        // Panoul aplicatiei companion de Android (AndroidPane.swift).
        "android.title": [.ro: "Aplicația de Android", .en: "The Android app", .es: "La app de Android"],
        "android.subtitle": [.ro: "Ai catalogul GDC și pe telefon: produse, cursuri, evenimente și magazine partenere, cu funcționare offline. Scanează codul de mai jos cu telefonul ca să descarci aplicația.", .en: "The GDC catalog on your phone too: products, courses, events and partner stores, working offline. Scan the code below with your phone to download the app.", .es: "El catálogo GDC también en tu teléfono: productos, cursos, eventos y tiendas asociadas, con funcionamiento offline. Escanea el código con el móvil para descargar la app."],
        "android.qr.hint": [.ro: "Scanează cu camera telefonului", .en: "Scan with your phone camera", .es: "Escanea con la cámara del móvil"],
        "android.meta.version": [.ro: "Versiune", .en: "Version", .es: "Versión"],
        "android.meta.size": [.ro: "Mărime", .en: "Size", .es: "Tamaño"],
        "android.meta.min": [.ro: "Necesită", .en: "Requires", .es: "Requiere"],
        "android.meta.date": [.ro: "Publicat", .en: "Released", .es: "Publicado"],
        "android.copy": [.ro: "Copiază linkul", .en: "Copy link", .es: "Copiar enlace"],
        "android.copied": [.ro: "Link copiat", .en: "Link copied", .es: "Enlace copiado"],
        "android.open": [.ro: "Deschide pagina", .en: "Open page", .es: "Abrir página"],
        "android.error": [.ro: "Nu am putut afla ultima versiune de Android. Verifică conexiunea și încearcă din nou.", .en: "Couldn't fetch the latest Android version. Check your connection and try again.", .es: "No se pudo obtener la última versión de Android. Comprueba tu conexión e inténtalo de nuevo."],
        "android.steps.title": [.ro: "Cum se instalează", .en: "How to install", .es: "Cómo instalar"],
        "android.steps.1": [.ro: "Scanează codul QR sau deschide linkul copiat, în Chrome pe telefon.", .en: "Scan the QR code, or open the copied link in Chrome on your phone.", .es: "Escanea el código QR o abre el enlace copiado en Chrome en el móvil."],
        "android.steps.2": [.ro: "Descarcă fișierul .apk — dacă apare un avertisment, alege „Descarcă oricum”.", .en: "Download the .apk file — if a warning appears, choose \"Download anyway\".", .es: "Descarga el archivo .apk — si aparece un aviso, elige «Descargar de todos modos»."],
        "android.steps.3": [.ro: "Deschide fișierul descărcat. Android va cere o permisiune: activează „Permite din această sursă”.", .en: "Open the downloaded file. Android will ask for a permission: allow installs from this source.", .es: "Abre el archivo descargado. Android pedirá un permiso: permite la instalación desde esta fuente."],
        "android.steps.4": [.ro: "Apasă „Instalează”. Aplicația nu vine din Play Store, deci pașii de mai sus sunt normali.", .en: "Tap \"Install\". The app doesn't come from the Play Store, so the steps above are expected.", .es: "Pulsa «Instalar». La app no viene de Play Store, por lo que los pasos anteriores son normales."],

        "catalog.loading": [.ro: "Se încarcă catalogul…", .en: "Loading catalog…", .es: "Cargando catálogo…"],
        "catalog.empty": [.ro: "Niciun produs în această categorie.", .en: "No items in this category.", .es: "No hay elementos en esta categoría."],
        "catalog.error": [.ro: "Nu am putut încărca catalogul. Verifică conexiunea la internet.", .en: "Couldn't load the catalog. Check your internet connection.", .es: "No se pudo cargar el catálogo. Comprueba tu conexión a internet."],
        "catalog.error.parse": [.ro: "Nu am putut înțelege catalogul primit — încearcă să actualizezi aplicația la ultima versiune.", .en: "Couldn't understand the catalog we received — try updating the app to the latest version.", .es: "No se pudo interpretar el catálogo recibido — intenta actualizar la aplicación a la última versión."],
        "catalog.error.server": [.ro: "Serverul catalogului a răspuns cu o eroare (cod %d) — încearcă din nou peste puțin.", .en: "The catalog server responded with an error (code %d) — try again in a bit.", .es: "El servidor del catálogo respondió con un error (código %d) — inténtalo de nuevo en un momento."],
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
        "card.paid": [.ro: "Licență", .en: "License", .es: "Licencia"],
        "card.trustMessage": [
            .ro: "Dezvoltat și susținut de comunitate. Licență Lifetime la preț promoțional de lansare.",
            .en: "Developed and supported by the community. Lifetime license at a launch-promo price.",
            .es: "Desarrollado y respaldado por la comunidad. Licencia de por vida a precio promocional de lanzamiento."
        ],
        "filter.price.all": [.ro: "Toate", .en: "All", .es: "Todo"],
        "filter.price.free": [.ro: "Gratuite", .en: "Free", .es: "Gratis"],
        "filter.price.paid": [.ro: "Premium", .en: "Premium", .es: "Premium"],
        "filter.price.empty": [.ro: "Niciun produs în această categorie", .en: "No products in this category", .es: "Ningún producto en esta categoría"],
        // Coperți de produs + preview mărit (vezi CoverImageViews.swift).
        "cover.zoom.hint": [.ro: "Click pentru a mări imaginea", .en: "Click to enlarge", .es: "Clic para ampliar"],
        "cover.failed": [.ro: "Imaginea nu a putut fi încărcată", .en: "The image could not be loaded", .es: "No se pudo cargar la imagen"],
        "cover.reset": [.ro: "Mărime normală", .en: "Actual size", .es: "Tamaño normal"],
        "card.tutorial": [.ro: "Vezi tutorialul explicativ pentru acest produs", .en: "See the explainer tutorial for this product", .es: "Ver el tutorial explicativo de este producto"],

        "courses.empty": [.ro: "Niciun curs disponibil momentan.", .en: "No courses available right now.", .es: "Ningún curso disponible por ahora."],
        "courses.contact": [.ro: "Contactează", .en: "Contact", .es: "Contactar"],
        "courses.contact.message": [.ro: "Salut! Vreau să rezerv cursul %@ — %@ (%@).", .en: "Hi! I'd like to book the course %@ — %@ (%@).", .es: "¡Hola! Quiero reservar el curso %@ — %@ (%@)."],
        "resources.empty": [.ro: "Niciun material disponibil momentan.", .en: "No materials available right now.", .es: "Ningún material disponible por ahora."],
        "resources.buy": [.ro: "Cumpără", .en: "Buy", .es: "Comprar"],
        "events.empty": [.ro: "Niciun eveniment momentan.", .en: "No events right now.", .es: "Ningún evento por ahora."],
        "events.details": [.ro: "Detalii/Înscriere", .en: "Details/Register", .es: "Detalles/Inscribirse"],
        "stores.empty": [.ro: "Niciun magazin partener momentan.", .en: "No partner stores right now.", .es: "Ninguna tienda asociada por ahora."],
        "stores.visit": [.ro: "Vizitează", .en: "Visit", .es: "Visitar"],

        "apps.empty": [.ro: "Nicio aplicație listată momentan.", .en: "No apps listed right now.", .es: "Ninguna aplicación listada por ahora."],
        "apps.open": [.ro: "Deschide", .en: "Open", .es: "Abrir"],
        "apps.badge": [.ro: "Aplicație", .en: "App", .es: "Aplicación"],

        "resolve.running.title": [.ro: "DaVinci Resolve rulează", .en: "DaVinci Resolve is running", .es: "DaVinci Resolve está abierto"],
        "resolve.running.body": [.ro: "Închide DaVinci Resolve înainte de a instala sau elimina plugin-uri — Resolve le încarcă doar la pornire.", .en: "Quit DaVinci Resolve before installing or removing plugins — Resolve only loads them at launch.", .es: "Cierra DaVinci Resolve antes de instalar o eliminar plugins — Resolve solo los carga al iniciar."],
        "resolve.running.ok": [.ro: "Am înțeles", .en: "Got it", .es: "Entendido"],
        "resolve.notrunning.title": [.ro: "DaVinci Resolve nu rulează", .en: "DaVinci Resolve isn't running", .es: "DaVinci Resolve no está abierto"],
        "resolve.notrunning.body": [.ro: "Deschide DaVinci Resolve pentru import automat în Gallery. Continui oricum — fișierele se descarcă și le poți importa manual.", .en: "Open DaVinci Resolve for automatic import into the Gallery. Continuing anyway — the files will download so you can import them manually.", .es: "Abre DaVinci Resolve para la importación automática en la Gallery. Continuando de todos modos — los archivos se descargarán para que los importes manualmente."],

        "powergrade.imported": [.ro: "Adăugat automat în Gallery, albumul „%@”.", .en: "Added automatically to the Gallery, in the \"%@\" album.", .es: "Añadido automáticamente a la Gallery, en el álbum \"%@\"."],
        "powergrade.manualstep": [.ro: "Fișierele sunt verificate în %@ — deschide Gallery-ul din Resolve și importă-le manual (album nou, PowerGrade → Import).", .en: "The files are verified in %@ — open Resolve's Gallery and import them manually (new PowerGrade album → Import).", .es: "Los archivos están verificados en %@ — abre la Gallery de Resolve e impórtalos manualmente (álbum PowerGrade nuevo → Importar)."],
        "powergrade.manualremove": [.ro: "Fișierele locale au fost șterse — elimină-le și din Gallery manual (Resolve închis sau scripting indisponibil).", .en: "The local files were removed — remove them from the Gallery manually too (Resolve was closed or scripting wasn't available).", .es: "Los archivos locales se eliminaron — elimínalos también de la Gallery manualmente (Resolve estaba cerrado o el scripting no estaba disponible)."],

        "install.paidresource.error": [.ro: "A apărut o eroare la încărcarea resursei. Te rugăm să contactezi suportul pentru asistență.", .en: "There was an error loading the paid resource. Please contact support for assistance.", .es: "Se produjo un error al cargar el recurso. Ponte en contacto con soporte para recibir ayuda."],
        "install.contact.support": [.ro: "Contactează suportul", .en: "Contact support", .es: "Contactar con soporte"],

        "settings.language.title": [.ro: "Limbă", .en: "Language", .es: "Idioma"],

        "onboarding.title": [.ro: "Bine ai venit!", .en: "Welcome!", .es: "¡Bienvenido!"],
        "onboarding.body": [.ro: "Aplicația rămâne complet gratuită și fără cont — asta e doar opțional, ca să te pot contacta dacă apare ceva important legat de produsele tale. Poți sări peste.", .en: "The app stays completely free and account-free — this is just optional, so I can reach you if something important comes up about your products. Feel free to skip it.", .es: "La aplicación sigue siendo completamente gratuita y sin cuenta — esto es solo opcional, para poder contactarte si surge algo importante sobre tus productos. Puedes saltarlo."],
        "onboarding.name": [.ro: "Nume", .en: "Name", .es: "Nombre"],
        "onboarding.email": [.ro: "Email (opțional)", .en: "Email (optional)", .es: "Email (opcional)"],
        "onboarding.skip": [.ro: "Sari peste", .en: "Skip", .es: "Omitir"],
        "onboarding.send": [.ro: "Trimite", .en: "Send", .es: "Enviar"],

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
        "help.powergrade.title": [.ro: "PowerGrade-uri", .en: "PowerGrades", .es: "PowerGrades"],
        "help.powergrade.body": [.ro: "Diferit de DCTL/LUT/Fuse: aici Resolve trebuie SĂ FIE DESCHIS, nu închis. Cu DaVinci Resolve Studio deschis, „Instalează” creează automat un album propriu în Gallery pentru fiecare produs (numit „GDC — <nume produs>”), fără să amestece produsele între ele — dacă un produs are mai multe .drx, intră toate în același album. Pe Resolve gratuit, cu Resolve închis sau dacă automatul eșuează, fișierele tot se descarcă și se verifică — le imporți manual din Gallery într-un pas (click-dreapta pe album → Import).", .en: "Different from DCTL/LUT/Fuse: here Resolve needs to be OPEN, not closed. With DaVinci Resolve Studio open, “Install” automatically creates its own Gallery album per product (named “GDC — <product name>”), so products never mix — if one product has several .drx files, they all land in that same album. On the free edition, with Resolve closed, or if the automatic step fails, the files still download and get verified — you import them manually from the Gallery in one step (right-click the album → Import).", .es: "A diferencia de DCTL/LUT/Fuse: aquí Resolve debe estar ABIERTO, no cerrado. Con DaVinci Resolve Studio abierto, “Instalar” crea automáticamente un álbum propio en la Gallery para cada producto (llamado “GDC — <nombre del producto>”), sin mezclar productos — si un producto tiene varios .drx, todos entran en el mismo álbum. En la edición gratuita, con Resolve cerrado, o si el paso automático falla, los archivos igual se descargan y se verifican — los importas manualmente desde la Gallery en un paso (clic derecho en el álbum → Importar)."],
        "help.ofx.title": [.ro: "Plugin-uri OFX (DaVinci Resolve Studio)", .en: "OFX plugins (DaVinci Resolve Studio)", .es: "Plugins OFX (DaVinci Resolve Studio)"],
        "help.ofx.body": [.ro: "Se instalează în /Library/OFX/Plugins, folderul standard citit de Resolve la pornire — la fel ca DCTL/LUT/Fuse, Resolve trebuie să fie închis. Dacă e prima instalare a unui plugin OFX pe acest Mac, poate cere o singură dată parola de administrator. Un plugin OFX nesemnat de Apple poate fi blocat inițial de Gatekeeper — dacă apare un avertisment, deschide-l o dată din Preferințe Sistem → Confidențialitate și Securitate.", .en: "Installs into /Library/OFX/Plugins, the standard folder Resolve reads at launch — same as DCTL/LUT/Fuse, Resolve needs to be closed. If it's the first OFX plugin installed on this Mac, it may ask for the admin password once. An OFX plugin not signed by Apple may initially be blocked by Gatekeeper — if a warning appears, allow it once from System Settings → Privacy & Security.", .es: "Se instala en /Library/OFX/Plugins, la carpeta estándar que Resolve lee al iniciar — igual que DCTL/LUT/Fuse, Resolve debe estar cerrado. Si es el primer plugin OFX instalado en este Mac, puede pedir la contraseña de administrador una vez. Un plugin OFX no firmado por Apple puede ser bloqueado inicialmente por Gatekeeper — si aparece un aviso, permítelo una vez desde Ajustes del Sistema → Privacidad y Seguridad."],

        "help.machine.title": [.ro: "ID-ul calculatorului", .en: "Your computer's ID", .es: "El ID de tu ordenador"],
        "help.machine.body": [.ro: "Fiecare cod de activare e legat de un singur calculator, identificat printr-un ID afișat în pagina „Licență”. Trimite acel ID când cumperi, ca să primești un cod care funcționează pe calculatorul tău.", .en: "Each activation code is locked to one computer, identified by an ID shown on the “License” page. Send that ID when buying, so you get a code that works on your computer.", .es: "Cada código de activación está vinculado a un único ordenador, identificado por un ID que aparece en la página “Licencia”. Envía ese ID al comprar, para recibir un código que funcione en tu ordenador."],
        "help.updates.title": [.ro: "Actualizări", .en: "Updates", .es: "Actualizaciones"],
        "help.updates.body": [.ro: "Aplicația verifică automat dacă există o versiune nouă și te anunță printr-un banner cu link de descărcare. Catalogul de produse se actualizează singur ori de câte ori apeși „Reîmprospătează”.", .en: "The app automatically checks for a newer version and shows a banner with a download link. The product catalog refreshes on its own whenever you tap “Refresh”.", .es: "La app comprueba automáticamente si hay una versión nueva y te avisa con un banner con enlace de descarga. El catálogo de productos se actualiza solo cada vez que pulsas “Actualizar”."],
        "help.support.title": [.ro: "Suport", .en: "Support", .es: "Soporte"],
        "help.support.body": [.ro: "Ai o problemă sau o întrebare? Scrie-mi pe WhatsApp din pagina „Licență” — răspund direct.", .en: "Have a problem or a question? Message me on WhatsApp from the “License” page — I reply directly.", .es: "¿Tienes un problema o una pregunta? Escríbeme por WhatsApp desde la página “Licencia” — respondo directamente."],

        "update.title": [.ro: "Versiune nouă disponibilă", .en: "New version available", .es: "Nueva versión disponible"],
        "update.download": [.ro: "Descarcă", .en: "Download", .es: "Descargar"],
        "update.dismiss": [.ro: "Închide", .en: "Dismiss", .es: "Cerrar"],
        // Pop-up modal (ContentView.swift), separat de bannerul de mai sus.
        // Explica raspicat ca nu e self-update — vezi cererea din 2026-08-24.
        "update.popup.title": [.ro: "Actualizare disponibilă", .en: "Update available", .es: "Actualización disponible"],
        "update.popup.message": [.ro: "Este disponibilă o nouă versiune! Te rugăm să descarci ultimul installer și să îl instalezi peste versiunea actuală.", .en: "A new version is available! Please download the latest installer and install it over your current version.", .es: "¡Hay una nueva versión disponible! Por favor, descarga el último instalador e instálalo sobre la versión actual."],
        "update.popup.later": [.ro: "Mai târziu", .en: "Later", .es: "Más tarde"],

        "menu.quit": [.ro: "Închide GDC Plugin Manager", .en: "Quit GDC Plugin Manager", .es: "Salir de GDC Plugin Manager"],
    ]
}
