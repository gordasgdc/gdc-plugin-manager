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
        "app.tagline": [.ro: "Instalează DCTL-uri, LUT-uri și Fuse-uri direct în DaVinci Resolve", .en: "Install DCTLs, LUTs and Fuses straight into DaVinci Resolve", .es: "Instala DCTLs, LUTs y Fuses directamente en DaVinci Resolve"],

        "sidebar.all": [.ro: "Toate", .en: "All", .es: "Todos"],
        "sidebar.dctl": [.ro: "DCTL", .en: "DCTL", .es: "DCTL"],
        "sidebar.lut": [.ro: "LUT", .en: "LUT", .es: "LUT"],
        "sidebar.fuse": [.ro: "Fuse", .en: "Fuse", .es: "Fuse"],
        "sidebar.license": [.ro: "Licență", .en: "License", .es: "Licencia"],

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

        "resolve.running.title": [.ro: "DaVinci Resolve rulează", .en: "DaVinci Resolve is running", .es: "DaVinci Resolve está abierto"],
        "resolve.running.body": [.ro: "Închide DaVinci Resolve înainte de a instala sau elimina plugin-uri — Resolve le încarcă doar la pornire.", .en: "Quit DaVinci Resolve before installing or removing plugins — Resolve only loads them at launch.", .es: "Cierra DaVinci Resolve antes de instalar o eliminar plugins — Resolve solo los carga al iniciar."],
        "resolve.running.ok": [.ro: "Am înțeles", .en: "Got it", .es: "Entendido"],

        "license.pane.title": [.ro: "Licență", .en: "License", .es: "Licencia"],
        "license.status.trial": [.ro: "Probă gratuită", .en: "Free trial", .es: "Prueba gratuita"],
        "license.status.trial.daysLeft": [.ro: "Mai ai %d zile din proba gratuită.", .en: "%d days left in your free trial.", .es: "Te quedan %d días de prueba gratuita."],
        "license.status.trial.lastDay": [.ro: "Ultima zi de probă gratuită.", .en: "Last day of your free trial.", .es: "Último día de tu prueba gratuita."],
        "license.status.expired": [.ro: "Proba a expirat", .en: "Trial expired", .es: "La prueba ha caducado"],
        "license.status.expired.body": [.ro: "Activează licența ca să poți continua să instalezi și să actualizezi plugin-uri.", .en: "Activate your license to keep installing and updating plugins.", .es: "Activa tu licencia para seguir instalando y actualizando plugins."],
        "license.status.licensed": [.ro: "Licență activă", .en: "License active", .es: "Licencia activa"],
        "license.status.licensed.body": [.ro: "Acces pe viață la tot catalogul, pe acest calculator.", .en: "Lifetime access to the whole catalog, on this computer.", .es: "Acceso de por vida a todo el catálogo, en este ordenador."],
        "license.machineID.title": [.ro: "ID-ul acestui calculator", .en: "This computer's ID", .es: "ID de este ordenador"],
        "license.machineID.body": [.ro: "Trimite acest ID când cumperi licența — codul e legat de acest calculator.", .en: "Send this ID when you buy the license — the code is locked to this computer.", .es: "Envía este ID al comprar la licencia — el código queda vinculado a este ordenador."],
        "license.machineID.copy": [.ro: "Copiază", .en: "Copy", .es: "Copiar"],
        "license.machineID.copied": [.ro: "Copiat.", .en: "Copied.", .es: "Copiado."],
        "license.field.placeholder": [.ro: "Cod serial", .en: "Serial code", .es: "Código serial"],
        "license.activate": [.ro: "Activează", .en: "Activate", .es: "Activar"],
        "license.activated.success": [.ro: "Activat cu succes!", .en: "Activated successfully!", .es: "¡Activado correctamente!"],
        "license.deactivate": [.ro: "Dezactivează", .en: "Deactivate", .es: "Desactivar"],
        "license.buy.title": [.ro: "Cumpără acces pe viață", .en: "Buy lifetime access", .es: "Comprar acceso de por vida"],
        "license.buy.price": [.ro: "O singură dată, acces la tot catalogul, prezent și viitor.", .en: "One time, access to the whole catalog, now and in the future.", .es: "Pago único, acceso a todo el catálogo, ahora y en el futuro."],
        "license.buy.button": [.ro: "Cumpără pe WhatsApp", .en: "Buy on WhatsApp", .es: "Comprar por WhatsApp"],

        "license.error.malformed": [.ro: "Codul nu e valid — verifică să-l fi copiat complet.", .en: "That code isn't valid — check you copied all of it.", .es: "Ese código no es válido — comprueba que lo copiaste completo."],
        "license.error.badSignature": [.ro: "Codul nu e valid.", .en: "That code isn't valid.", .es: "Ese código no es válido."],
        "license.error.wrongProduct": [.ro: "Acest cod e pentru altă aplicație.", .en: "This code is for a different app.", .es: "Este código es para otra aplicación."],
        "license.error.wrongMachine": [.ro: "Acest cod e activat pentru alt calculator.", .en: "This code is activated for a different Mac.", .es: "Este código está activado para otro Mac."],
        "license.error.expired": [.ro: "Acest cod a expirat.", .en: "This code has expired.", .es: "Este código ha caducado."],

        "trial.locked.title": [.ro: "Proba de 7 zile s-a încheiat", .en: "Your 7-day trial has ended", .es: "Tu prueba de 7 días ha terminado"],
        "trial.locked.body": [.ro: "Activează licența din pagina „Licență” ca să continui să instalezi și să actualizezi plugin-uri.", .en: "Activate your license from the “License” page to keep installing and updating plugins.", .es: "Activa tu licencia desde la página “Licencia” para seguir instalando y actualizando plugins."],

        "menu.quit": [.ro: "Închide GDC Plugin Manager", .en: "Quit GDC Plugin Manager", .es: "Salir de GDC Plugin Manager"],
    ]
}
