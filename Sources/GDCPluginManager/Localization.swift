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
        "sidebar.tutorials": [.ro: "Tutoriale", .en: "Tutorials", .es: "Tutoriales"],
        "tutorials.allCategories": [.ro: "Toate", .en: "All", .es: "Todas"],
        "tutorials.search": [.ro: "Caută tutoriale (titlu, taguri)…", .en: "Search tutorials (title, tags)…", .es: "Buscar tutoriales (título, etiquetas)…"],
        "tutorials.showDescription": [.ro: "Descriere", .en: "Description", .es: "Descripción"],
        "tutorials.watch": [.ro: "Vezi pe YouTube", .en: "Watch on YouTube", .es: "Ver en YouTube"],
        "sidebar.events": [.ro: "Evenimente", .en: "Events", .es: "Eventos"],
        "sidebar.partnerStores": [.ro: "Magazine partenere", .en: "Partner stores", .es: "Tiendas asociadas"],
        "sidebar.serviceCenters": [.ro: "Service & Reparații", .en: "Service & Repairs", .es: "Servicio y Reparaciones"],
        "servicecenters.empty": [.ro: "Niciun service partener momentan.", .en: "No partner service centers right now.", .es: "Ningún centro de servicio asociado por ahora."],
        "servicecenters.contact": [.ro: "Contact rapid", .en: "Quick contact", .es: "Contacto rápido"],
        "servicecenters.website": [.ro: "Website / Locație", .en: "Website / Location", .es: "Sitio web / Ubicación"],
        "servicecategory.drone": [.ro: "Reparații Drone", .en: "Drone Repairs", .es: "Reparación de Drones"],
        "servicecategory.camera": [.ro: "Service Camere & Senzori", .en: "Camera & Sensor Service", .es: "Servicio de Cámaras y Sensores"],
        "servicecategory.optics": [.ro: "Service Obiective / Optică", .en: "Lens / Optics Service", .es: "Servicio de Objetivos / Óptica"],
        "servicecategory.urgent": [.ro: "Suport Rapid / Urgențe", .en: "Rapid Support / Emergencies", .es: "Soporte Rápido / Emergencias"],
        "update.check.button": [.ro: "Verifică actualizări...", .en: "Check for Updates...", .es: "Buscar actualizaciones..."],
        "update.check.title": [.ro: "Actualizări", .en: "Updates", .es: "Actualizaciones"],
        "update.check.available": [.ro: "Versiunea %@ este disponibilă!", .en: "Version %@ is available!", .es: "¡La versión %@ está disponible!"],
        "update.check.upToDate": [.ro: "Sunteți pe cea mai nouă versiune.", .en: "You're on the latest version.", .es: "Tienes la última versión."],
        "common.ok": [.ro: "OK", .en: "OK", .es: "OK"],
        "dependency.missing.title": [.ro: "Dependință de sistem lipsă", .en: "Missing system dependency", .es: "Falta una dependencia del sistema"],
        "dependency.install.button": [.ro: "Instalează %@", .en: "Install %@", .es: "Instalar %@"],
        "prefs.language.title": [.ro: "Limbă / Language", .en: "Language", .es: "Idioma"],
        // Selector de temă — Regula 18 (Partea 1). Vezi AppTheme.swift (Core).
        "prefs.theme.title": [.ro: "Temă", .en: "Theme", .es: "Tema"],
        "prefs.theme.system": [.ro: "Sistem", .en: "System", .es: "Sistema"],
        "prefs.theme.light": [.ro: "Luminoasă", .en: "Light", .es: "Clara"],
        "prefs.theme.dark": [.ro: "Întunecată", .en: "Dark", .es: "Oscura"],
        "prefs.textSize.title": [.ro: "Mărime text", .en: "Text size", .es: "Tamaño de texto"],
        "prefs.textSize.small": [.ro: "Mic", .en: "Small", .es: "Pequeño"],
        "prefs.textSize.normal": [.ro: "Normal", .en: "Normal", .es: "Normal"],
        "prefs.textSize.large": [.ro: "Mare", .en: "Large", .es: "Grande"],
        "prefs.textSize.xlarge": [.ro: "Foarte mare", .en: "Extra large", .es: "Muy grande"],
        "prefs.updates.title": [.ro: "Actualizări", .en: "Updates", .es: "Actualizaciones"],
        "prefs.updates.currentVersion": [.ro: "Versiune curentă", .en: "Current version", .es: "Versión actual"],
        "prefs.dependencies.title": [.ro: "Dependențe de sistem", .en: "System dependencies", .es: "Dependencias del sistema"],
        "prefs.dependencies.installed": [.ro: "Instalat", .en: "Installed", .es: "Instalado"],
        "prefs.dependencies.missing": [.ro: "Lipsește", .en: "Missing", .es: "Falta"],
        "prefs.dependencies.install": [.ro: "Instalează...", .en: "Install...", .es: "Instalar..."],
        "prefs.dependencies.recheck": [.ro: "Reverifică", .en: "Recheck", .es: "Volver a verificar"],
        "deps.badge.ready": [.ro: "Sistem pregătit", .en: "System ready", .es: "Sistema listo"],
        "deps.badge.attention": [.ro: "Necesită atenție", .en: "Needs attention", .es: "Requiere atención"],
        "deps.panel.title": [.ro: "Verificare & Dependențe Sistem", .en: "System Check & Dependencies", .es: "Comprobación y Dependencias del Sistema"],
        "deps.panel.subtitle": [.ro: "Stare live a componentelor necesare instalării de pluginuri DaVinci Resolve.", .en: "Live status of the components needed to install DaVinci Resolve plugins.", .es: "Estado en vivo de los componentes necesarios para instalar plugins de DaVinci Resolve."],
        "deps.panel.close": [.ro: "Închide", .en: "Close", .es: "Cerrar"],
        "deps.panel.recheck": [.ro: "Reverifică tot", .en: "Recheck all", .es: "Volver a verificar todo"],
        "deps.state.ok": [.ro: "OK", .en: "OK", .es: "OK"],
        "deps.state.missing": [.ro: "Lipsește", .en: "Missing", .es: "Falta"],
        "deps.state.optionalMissing": [.ro: "Opțional — neinstalat", .en: "Optional — not installed", .es: "Opcional — no instalado"],
        "profile.anonymous": [.ro: "Anonim", .en: "Anonymous", .es: "Anónimo"],
        "profile.editor.title": [.ro: "Profil utilizator (opțional)", .en: "User profile (optional)", .es: "Perfil de usuario (opcional)"],
        "sidebar.apps": [.ro: "Aplicații", .en: "Apps", .es: "Aplicaciones"],
        "sidebar.audio": [.ro: "Audio", .en: "Audio", .es: "Audio"],
        "sidebar.mobileApp": [.ro: "Aplicație mobilă", .en: "Mobile app", .es: "App móvil"],

        // Panoul aplicatiei mobile companion (MobileAppPane.swift, fost
        // AndroidPane.swift — APK/TWA retras 2026-08-24, acum e direct
        // PWA-ul gordas.dev/app.html, deschis in browser, Android + iPhone).
        "mobileapp.title": [.ro: "Aplicația mobilă", .en: "The mobile app", .es: "La app móvil"],
        "mobileapp.subtitle": [.ro: "Ai catalogul GDC și pe telefon — produse, cursuri, evenimente și magazine partenere, cu funcționare offline. Scanează codul de mai jos, direct din browser, fără instalare — merge pe Android și pe iPhone.", .en: "The GDC catalog on your phone too — products, courses, events and partner stores, working offline. Scan the code below, right in your browser, no install needed — works on Android and iPhone.", .es: "El catálogo GDC también en tu teléfono — productos, cursos, eventos y tiendas asociadas, con funcionamiento offline. Escanea el código de abajo, directo en el navegador, sin instalar — funciona en Android y en iPhone."],
        "mobileapp.url": [.ro: "gordas.dev/app.html", .en: "gordas.dev/app.html", .es: "gordas.dev/app.html"],
        "mobileapp.copy": [.ro: "Copiază linkul", .en: "Copy link", .es: "Copiar enlace"],
        "mobileapp.open": [.ro: "Deschide", .en: "Open", .es: "Abrir"],
        "android.qr.hint": [.ro: "Scanează cu camera telefonului", .en: "Scan with your phone camera", .es: "Escanea con la cámara del móvil"],
        "android.copy": [.ro: "Copiază linkul", .en: "Copy link", .es: "Copiar enlace"],
        "android.copied": [.ro: "Link copiat", .en: "Link copied", .es: "Enlace copiado"],
        "mobileapp.steps.title": [.ro: "Adaugă pe ecranul principal (opțional)", .en: "Add to Home Screen (optional)", .es: "Añadir a la pantalla de inicio (opcional)"],
        "mobileapp.steps.android.title": [.ro: "Android (Chrome)", .en: "Android (Chrome)", .es: "Android (Chrome)"],
        "mobileapp.steps.android.1": [.ro: "Deschide linkul în Chrome, apoi apasă meniul (⋮) din dreapta sus.", .en: "Open the link in Chrome, then tap the (⋮) menu top-right.", .es: "Abre el enlace en Chrome, luego pulsa el menú (⋮) arriba a la derecha."],
        "mobileapp.steps.android.2": [.ro: "Alege „Adaugă pe ecranul principal” — primești un icon, ca o aplicație instalată.", .en: "Choose \"Add to Home screen\" — you get an icon, just like an installed app.", .es: "Elige «Añadir a pantalla de inicio» — obtienes un icono, como una app instalada."],
        "mobileapp.steps.ios.title": [.ro: "iPhone (Safari)", .en: "iPhone (Safari)", .es: "iPhone (Safari)"],
        "mobileapp.steps.ios.1": [.ro: "Deschide linkul în Safari, apoi apasă butonul de partajare (pătratul cu săgeata în sus).", .en: "Open the link in Safari, then tap the Share button (square with an arrow up).", .es: "Abre el enlace en Safari, luego pulsa el botón de compartir (el cuadrado con la flecha hacia arriba)."],
        "mobileapp.steps.ios.2": [.ro: "Alege „Adaugă pe ecranul principal” din listă.", .en: "Choose \"Add to Home Screen\" from the list.", .es: "Elige «Añadir a pantalla de inicio» en la lista."],

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
        "card.buy": [.ro: "Donează", .en: "Donate", .es: "Donar"],
        "card.incompatibleOS": [.ro: "Incompatibil cu sistemul tău", .en: "Incompatible with your system", .es: "Incompatible con tu sistema"],
        "card.free": [.ro: "Gratuit", .en: "Free", .es: "Gratis"],
        "card.trial": [.ro: "Probă", .en: "Trial", .es: "Prueba"],
        "card.paid": [.ro: "Licență", .en: "License", .es: "Licencia"],
        "card.promo": [.ro: "Susținere promoțională", .en: "Promotional support", .es: "Apoyo promocional"],
        "maps.open": [.ro: "Hartă", .en: "Map", .es: "Mapa"],
        "download.location.set": [.ro: "Unde l-ai salvat?", .en: "Where did you save it?", .es: "¿Dónde lo guardaste?"],
        "download.location.open": [.ro: "Deschide folderul", .en: "Open folder", .es: "Abrir carpeta"],
        "download.location.change": [.ro: "Schimbă", .en: "Change", .es: "Cambiar"],
        "card.trustMessage": [
            .ro: "Dezvoltat și susținut de comunitate. Licență Lifetime la preț promoțional de lansare.",
            .en: "Developed and supported by the community. Lifetime license at a launch-promo price.",
            .es: "Desarrollado y respaldado por la comunidad. Licencia de por vida a precio promocional de lanzamiento."
        ],
        "filter.price.all": [.ro: "Toate", .en: "All", .es: "Todo"],
        "filter.price.free": [.ro: "Gratuite", .en: "Free", .es: "Gratis"],
        "filter.price.paid": [.ro: "Premium", .en: "Premium", .es: "Premium"],
        "filter.price.empty": [.ro: "Niciun produs în această categorie", .en: "No products in this category", .es: "Ningún producto en esta categoría"],
        // Etapa 1 (2026-08-29) — căutare fuzzy + filtru OS (CatalogGrid).
        "search.placeholder": [.ro: "Caută (nume, descriere, ID)…", .en: "Search (name, description, ID)…", .es: "Buscar (nombre, descripción, ID)…"],
        "filter.os.all": [.ro: "Toate", .en: "All", .es: "Todo"],
        "filter.os.mac": [.ro: "Mac", .en: "Mac", .es: "Mac"],
        "filter.os.windows": [.ro: "Windows", .en: "Windows", .es: "Windows"],
        "search.noResults": [.ro: "Niciun rezultat în nicio secțiune", .en: "No results in any section", .es: "Ningún resultado en ninguna sección"],
        "card.purchaseLink": [.ro: "Magazin extern", .en: "External store", .es: "Tienda externa"],
        "card.demoLink": [.ro: "Demo / Preview", .en: "Demo / Preview", .es: "Demo / Vista previa"],
        "card.youtubeLink": [.ro: "Vezi tutorialul / prezentarea pe YouTube", .en: "Watch the tutorial / walkthrough on YouTube", .es: "Ver el tutorial / la presentación en YouTube"],
        "social.facebook": [.ro: "Deschide pagina de Facebook", .en: "Open the Facebook page", .es: "Abrir la página de Facebook"],
        "social.youtube": [.ro: "Vezi canalul de YouTube", .en: "See the YouTube channel", .es: "Ver el canal de YouTube"],
        "social.instagram": [.ro: "Deschide pagina de Instagram", .en: "Open the Instagram page", .es: "Abrir la página de Instagram"],
        "social.tiktok": [.ro: "Deschide contul de TikTok", .en: "Open the TikTok account", .es: "Abrir la cuenta de TikTok"],
        "social.linkedin": [.ro: "Deschide pagina de LinkedIn", .en: "Open the LinkedIn page", .es: "Abrir la página de LinkedIn"],
        "sidebar.download.lut": [.ro: "LUT-uri (download)", .en: "LUTs (download)", .es: "LUTs (descarga)"],
        "sidebar.download.sfx": [.ro: "Efecte Audio / SFX", .en: "Audio Effects / SFX", .es: "Efectos de Audio / SFX"],
        "sidebar.download.vfx": [.ro: "VFX / Overlays", .en: "VFX / Overlays", .es: "VFX / Overlays"],
        "sidebar.download.plugin": [.ro: "Plugin-uri", .en: "Plugins", .es: "Plugins"],
        "download.empty": [.ro: "Nicio resursă publicată în această categorie", .en: "No resources published in this category", .es: "Ningún recurso publicado en esta categoría"],
        "sidebar.section.resolveInstall": [.ro: "INSTALARE DAVINCI RESOLVE", .en: "DAVINCI RESOLVE INSTALL", .es: "INSTALACIÓN DAVINCI RESOLVE"],
        "sidebar.section.downloadResources": [.ro: "RESURSE DOWNLOAD (Premiere / Final Cut / Resolve)", .en: "DOWNLOAD RESOURCES (Premiere / Final Cut / Resolve)", .es: "RECURSOS DE DESCARGA (Premiere / Final Cut / Resolve)"],
        "sidebar.section.community": [.ro: "COMUNITATE & EDUCAȚIE", .en: "COMMUNITY & EDUCATION", .es: "COMUNIDAD Y EDUCACIÓN"],
        "sidebar.section.ecosystem": [.ro: "ECOSISTEM GDC", .en: "GDC ECOSYSTEM", .es: "ECOSISTEMA GDC"],
        "sidebar.section.account": [.ro: "CONTUL TĂU", .en: "YOUR ACCOUNT", .es: "TU CUENTA"],
        "sidebar.partnerOffers": [.ro: "Oferte Parteneri", .en: "Partner Offers", .es: "Ofertas de Socios"],
        "partnerOffers.empty": [.ro: "Nicio ofertă activă momentan", .en: "No active offers right now", .es: "Ninguna oferta activa por ahora"],
        "partnerOffers.coupon": [.ro: "Cod cupon:", .en: "Coupon code:", .es: "Código de cupón:"],
        "partnerOffers.open": [.ro: "Vezi oferta", .en: "See offer", .es: "Ver oferta"],
        "sidebar.bundles": [.ro: "Pachete / Bundle-uri", .en: "Bundles", .es: "Paquetes"],
        "bundles.empty": [.ro: "Niciun pachet activ momentan", .en: "No active bundles right now", .es: "Ningún paquete activo por ahora"],
        "bundles.includes": [.ro: "Include:", .en: "Includes:", .es: "Incluye:"],
        "bundles.buy": [.ro: "Cumpără pachetul", .en: "Buy bundle", .es: "Comprar paquete"],
        "sidebar.myApps": [.ro: "Aplicațiile Mele", .en: "My Apps", .es: "Mis Aplicaciones"],
        "myApps.section.gdc": [.ro: "Aplicații GDC instalate", .en: "Installed GDC Apps", .es: "Aplicaciones GDC instaladas"],
        "myApps.section.custom": [.ro: "Scurtături personalizate", .en: "Custom Shortcuts", .es: "Accesos personalizados"],
        "myApps.addCustom": [.ro: "Adaugă scurtătură", .en: "Add Shortcut", .es: "Añadir acceso"],
        "myApps.custom.empty": [.ro: "Nicio scurtătură adăugată încă — apasă „Adaugă scurtătură” și alege o aplicație (DaVinci Resolve, Premiere, Photoshop…).", .en: "No shortcuts added yet — tap “Add Shortcut” and pick an app (DaVinci Resolve, Premiere, Photoshop…).", .es: "Aún no hay accesos añadidos — pulsa “Añadir acceso” y elige una aplicación (DaVinci Resolve, Premiere, Photoshop…)."],
        "myApps.open": [.ro: "Deschide", .en: "Open", .es: "Abrir"],
        "myApps.notInstalled": [.ro: "Neinstalat pe acest Mac", .en: "Not installed on this Mac", .es: "No instalado en este Mac"],
        "myApps.updateAvailable": [.ro: "ACTUALIZARE", .en: "UPDATE", .es: "ACTUALIZAR"],
        // Coperți de produs + preview mărit (vezi CoverImageViews.swift).
        "cover.zoom.hint": [.ro: "Click pentru a mări imaginea", .en: "Click to enlarge", .es: "Clic para ampliar"],
        "cover.failed": [.ro: "Imaginea nu a putut fi încărcată", .en: "The image could not be loaded", .es: "No se pudo cargar la imagen"],
        "cover.reset": [.ro: "Mărime normală", .en: "Actual size", .es: "Tamaño normal"],
        "card.tutorial": [.ro: "Vezi tutorialul explicativ pentru acest produs", .en: "See the explainer tutorial for this product", .es: "Ver el tutorial explicativo de este producto"],

        "courses.empty": [.ro: "Niciun curs disponibil momentan.", .en: "No courses available right now.", .es: "Ningún curso disponible por ahora."],
        "courses.contact": [.ro: "Contactează", .en: "Contact", .es: "Contactar"],
        "courses.contact.message": [.ro: "Salut! Vreau să rezerv cursul %@ — %@ (%@).", .en: "Hi! I'd like to book the course %@ — %@ (%@).", .es: "¡Hola! Quiero reservar el curso %@ — %@ (%@)."],
        "resources.empty": [.ro: "Niciun material disponibil momentan.", .en: "No materials available right now.", .es: "Ningún material disponible por ahora."],
        "resources.buy": [.ro: "Donează", .en: "Donate", .es: "Donar"],
        "events.empty": [.ro: "Niciun eveniment momentan.", .en: "No events right now.", .es: "Ningún evento por ahora."],
        "events.details": [.ro: "Detalii/Înscriere", .en: "Details/Register", .es: "Detalles/Inscribirse"],
        "stores.empty": [.ro: "Niciun magazin partener momentan.", .en: "No partner stores right now.", .es: "Ninguna tienda asociada por ahora."],
        "stores.visit": [.ro: "Vizitează", .en: "Visit", .es: "Visitar"],

        "apps.empty": [.ro: "Nicio aplicație listată momentan.", .en: "No apps listed right now.", .es: "Ninguna aplicación listada por ahora."],
        "apps.open": [.ro: "Deschide", .en: "Open", .es: "Abrir"],
        "apps.badge": [.ro: "Aplicație", .en: "App", .es: "Aplicación"],
        "audio.empty": [.ro: "Niciun element audio listat momentan.", .en: "No audio listed right now.", .es: "Ningún audio listado por ahora."],
        "audio.open": [.ro: "Descarcă", .en: "Download", .es: "Descargar"],
        "audio.badge": [.ro: "Audio", .en: "Audio", .es: "Audio"],

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
        "license.error.wrongPlatform": [.ro: "Acest cod e valabil pentru altă platformă (Mac/Windows).", .en: "This code is valid for a different platform (Mac/Windows).", .es: "Este código es válido para otra plataforma (Mac/Windows)."],
        "license.error.wrongMachine": [.ro: "Acest cod e activat pentru alt calculator.", .en: "This code is activated for a different Mac.", .es: "Este código está activado para otro Mac."],
        "license.error.hwidUnavailable": [.ro: "Nu am putut citi identificatorul hardware acum — încearcă din nou.", .en: "Couldn't read this Mac's hardware ID just now — try again.", .es: "No se pudo leer el identificador de hardware ahora — inténtalo de nuevo."],
        "license.error.expired": [.ro: "Acest cod a expirat.", .en: "This code has expired.", .es: "Este código ha caducado."],
        "license.error.catalogNotLoaded": [.ro: "Catalogul nu s-a încărcat încă — reîmprospătează și încearcă din nou.", .en: "The catalog hasn't loaded yet — refresh and try again.", .es: "El catálogo aún no se ha cargado — actualiza e inténtalo de nuevo."],

        "help.title": [.ro: "Ajutor", .en: "Help", .es: "Ayuda"],
        "help.what.title": [.ro: "Ce este GDC Plugin Manager", .en: "What is GDC Plugin Manager", .es: "Qué es GDC Plugin Manager"],
        "help.what.body": [.ro: "Un catalog cu produsele mele (DCTL, LUT, Fuse) pentru DaVinci Resolve. Aplicație nativă doar pentru Mac (Apple Silicon), gratuită — o descarci și răsfoiești catalogul oricând, fără cont și fără nicio taxă.", .en: "A catalog of my own products (DCTL, LUT, Fuse) for DaVinci Resolve. A native Mac-only app (Apple Silicon), free — download it and browse the catalog anytime, no account, no fee.", .es: "Un catálogo de mis propios productos (DCTL, LUT, Fuse) para DaVinci Resolve. Aplicación nativa solo para Mac (Apple Silicon), gratuita — descárgala y explora el catálogo cuando quieras, sin cuenta ni coste."],
        "help.buy.title": [.ro: "Cum deblochezi un produs", .en: "How to unlock a product", .es: "Cómo desbloquear un producto"],
        "help.buy.body": [.ro: "Suma de pe fiecare card e o donație, o singură dată, care mă ajută să dezvolt în continuare produsele — nu un preț de vânzare, nu un abonament. Apeși „Donează” pe cardul produsului, se deschide WhatsApp cu mesajul completat — îți trimit înapoi un cod legat de calculatorul tău, pe care îl lipești în pagina „Licență”.", .en: "The price on each card is a one-time donation that helps me keep developing these products — not a subscription. Tap “Buy” on the product's card, WhatsApp opens with the message pre-filled — I send back a code locked to your computer, which you paste into the “License” page.", .es: "El precio de cada tarjeta es una donación única que me ayuda a seguir desarrollando estos productos — no una suscripción. Pulsa “Comprar” en la tarjeta del producto, se abre WhatsApp con el mensaje ya escrito — te envío de vuelta un código vinculado a tu ordenador, que pegas en la página “Licencia”."],
        "help.install.title": [.ro: "Cum funcționează instalarea", .en: "How installing works", .es: "Cómo funciona la instalación"],
        "help.install.body": [.ro: "După activare, apeși „Instalează” și fișierul ajunge direct în folderul corect al DaVinci Resolve — nu trebuie să cauți nimic manual. Dacă Resolve e deschis, aplicația te anunță să-l închizi întâi (Resolve încarcă plugin-urile doar la pornire).", .en: "After activating, tap “Install” and the file goes straight into DaVinci Resolve's correct folder — no manual hunting for folders. If Resolve is open, the app tells you to close it first (Resolve only loads plugins at launch).", .es: "Después de activar, pulsa “Instalar” y el archivo va directo a la carpeta correcta de DaVinci Resolve — sin buscar nada manualmente. Si Resolve está abierto, la app te avisa que lo cierres primero (Resolve solo carga los plugins al iniciar)."],
        "help.search.title": [.ro: "Căutare globală", .en: "Global search", .es: "Búsqueda global"],
        "help.search.body": [.ro: "Bara de căutare din partea de sus caută în TOATE rubricile deodată — produse, resurse, cursuri, evenimente, magazine, service. Nu trebuie să știi dinainte unde se află ceva.", .en: "The search bar at the top searches ALL sections at once — products, resources, courses, events, stores, services. You don't need to know in advance where something lives.", .es: "La barra de búsqueda superior busca en TODAS las secciones a la vez — productos, recursos, cursos, eventos, tiendas, servicios. No necesitas saber de antemano dónde está algo."],
        "help.resources.title": [.ro: "Resurse Download (Premiere, Final Cut, Resolve)", .en: "Downloadable Resources (Premiere, Final Cut, Resolve)", .es: "Recursos Descargables (Premiere, Final Cut, Resolve)"],
        "help.resources.body": [.ro: "LUT-uri, Efecte Audio/SFX, VFX/Overlays și Plugin-uri care se descarcă direct, fără instalare automată — gândite să funcționeze și în alte aplicații de montaj, nu doar în Resolve. Aplicația reține unde ai salvat fiecare fișier.", .en: "LUTs, Audio Effects/SFX, VFX/Overlays and Plugins you download directly, with no automatic install — meant to work in other editing apps too, not just Resolve. The app remembers where you saved each file.", .es: "LUTs, Efectos de Audio/SFX, VFX/Overlays y Plugins que descargas directamente, sin instalación automática — pensados para funcionar también en otras apps de edición, no solo Resolve. La app recuerda dónde guardaste cada archivo."],
        "help.community.title": [.ro: "Comunitate, Aplicațiile Mele, Oferte & Pachete", .en: "Community, My Apps, Offers & Bundles", .es: "Comunidad, Mis Apps, Ofertas y Paquetes"],
        "help.community.body": [.ro: "Cursuri, Materiale, Evenimente, Magazine partenere și Service — plus „Aplicațiile Mele” (lansare rapidă a celorlalte aplicații GDC), „Oferte Parteneri” (promoții de la branduri terțe) și „Pachete” (produse GDC combinate la un preț total avantajos).", .en: "Courses, Learning materials, Events, Partner stores and Service — plus \"My Apps\" (quick launch for the other GDC apps), \"Partner Offers\" (promotions from third-party brands) and \"Bundles\" (GDC products combined at a better total price).", .es: "Cursos, Materiales, Eventos, Tiendas asociadas y Servicio — además de \"Mis Apps\" (acceso rápido a las demás apps de GDC), \"Ofertas de Socios\" (promociones de marcas de terceros) y \"Paquetes\" (productos GDC combinados a un precio total más ventajoso)."],
        "help.appearance.title": [.ro: "Temă și Mărime Text", .en: "Theme and Text Size", .es: "Tema y Tamaño de texto"],
        "help.appearance.body": [.ro: "Din Preferințe (⌘,) alegi tema — Sistem/Luminoasă/Întunecată — și mărimea textului — Mic/Normal/Mare/Foarte mare. Ambele se aplică instant, fără repornire.", .en: "From Preferences (⌘,) pick the theme — System/Light/Dark — and the text size — Small/Normal/Large/Extra large. Both apply instantly, no restart needed.", .es: "Desde Preferencias (⌘,) elige el tema — Sistema/Claro/Oscuro — y el tamaño del texto — Pequeño/Normal/Grande/Muy grande. Ambos se aplican al instante, sin reiniciar."],
        "help.powergrade.title": [.ro: "PowerGrade-uri", .en: "PowerGrades", .es: "PowerGrades"],
        "help.powergrade.body": [.ro: "Diferit de DCTL/LUT/Fuse: aici Resolve trebuie SĂ FIE DESCHIS, nu închis. Cu DaVinci Resolve Studio deschis, „Instalează” creează automat un album propriu în Gallery pentru fiecare produs (numit „GDC — <nume produs>”), fără să amestece produsele între ele — dacă un produs are mai multe .drx, intră toate în același album. Pe Resolve gratuit, cu Resolve închis sau dacă automatul eșuează, fișierele tot se descarcă și se verifică — le imporți manual din Gallery într-un pas (click-dreapta pe album → Import).", .en: "Different from DCTL/LUT/Fuse: here Resolve needs to be OPEN, not closed. With DaVinci Resolve Studio open, “Install” automatically creates its own Gallery album per product (named “GDC — <product name>”), so products never mix — if one product has several .drx files, they all land in that same album. On the free edition, with Resolve closed, or if the automatic step fails, the files still download and get verified — you import them manually from the Gallery in one step (right-click the album → Import).", .es: "A diferencia de DCTL/LUT/Fuse: aquí Resolve debe estar ABIERTO, no cerrado. Con DaVinci Resolve Studio abierto, “Instalar” crea automáticamente un álbum propio en la Gallery para cada producto (llamado “GDC — <nombre del producto>”), sin mezclar productos — si un producto tiene varios .drx, todos entran en el mismo álbum. En la edición gratuita, con Resolve cerrado, o si el paso automático falla, los archivos igual se descargan y se verifican — los importas manualmente desde la Gallery en un paso (clic derecho en el álbum → Importar)."],
        "help.ofx.title": [.ro: "Plugin-uri OFX (DaVinci Resolve Studio)", .en: "OFX plugins (DaVinci Resolve Studio)", .es: "Plugins OFX (DaVinci Resolve Studio)"],
        "help.ofx.body": [.ro: "Se instalează în /Library/OFX/Plugins, folderul standard citit de Resolve la pornire — la fel ca DCTL/LUT/Fuse, Resolve trebuie să fie închis. Dacă e prima instalare a unui plugin OFX pe acest Mac, poate cere o singură dată parola de administrator. Un plugin OFX nesemnat de Apple poate fi blocat inițial de Gatekeeper — dacă apare un avertisment, deschide-l o dată din Preferințe Sistem → Confidențialitate și Securitate.", .en: "Installs into /Library/OFX/Plugins, the standard folder Resolve reads at launch — same as DCTL/LUT/Fuse, Resolve needs to be closed. If it's the first OFX plugin installed on this Mac, it may ask for the admin password once. An OFX plugin not signed by Apple may initially be blocked by Gatekeeper — if a warning appears, allow it once from System Settings → Privacy & Security.", .es: "Se instala en /Library/OFX/Plugins, la carpeta estándar que Resolve lee al iniciar — igual que DCTL/LUT/Fuse, Resolve debe estar cerrado. Si es el primer plugin OFX instalado en este Mac, puede pedir la contraseña de administrador una vez. Un plugin OFX no firmado por Apple puede ser bloqueado inicialmente por Gatekeeper — si aparece un aviso, permítelo una vez desde Ajustes del Sistema → Privacidad y Seguridad."],

        "help.machine.title": [.ro: "ID-ul calculatorului", .en: "Your computer's ID", .es: "El ID de tu ordenador"],
        "help.machine.body": [.ro: "Fiecare cod de activare e legat de un singur calculator, identificat printr-un ID afișat în pagina „Licență”. Trimite acel ID când cumperi, ca să primești un cod care funcționează pe calculatorul tău.", .en: "Each activation code is locked to one computer, identified by an ID shown on the “License” page. Send that ID when buying, so you get a code that works on your computer.", .es: "Cada código de activación está vinculado a un único ordenador, identificado por un ID que aparece en la página “Licencia”. Envía ese ID al comprar, para recibir un código que funcione en tu ordenador."],
        "help.updates.title": [.ro: "Actualizări", .en: "Updates", .es: "Actualizaciones"],
        "help.updates.body": [.ro: "Aplicația verifică automat dacă există o versiune nouă și te anunță printr-un banner cu link de descărcare. Catalogul de produse se actualizează singur ori de câte ori apeși „Reîmprospătează”.", .en: "The app automatically checks for a newer version and shows a banner with a download link. The product catalog refreshes on its own whenever you tap “Refresh”.", .es: "La app comprueba automáticamente si hay una versión nueva y te avisa con un banner con enlace de descarga. El catálogo de productos se actualiza solo cada vez que pulsas “Actualizar”."],
        "help.dependencies.title": [.ro: "Panoul de Dependențe (indicatorul roșu/verde)", .en: "Dependency Panel (the red/green indicator)", .es: "Panel de Dependencias (el indicador rojo/verde)"],
        "help.dependencies.body": [.ro: "Punctul din partea de sus a ferestrei arată dacă tot ce e nevoie pentru DaVinci Resolve e prezent — roșu înseamnă că lipsește ceva OBLIGATORIU (ex. Resolve însuși), verde înseamnă „Sistem pregătit”. Click pe indicator deschide „Verificare & Dependențe Sistem”, cu buton „Instalează...” pe orice componentă lipsă și „Reverifică tot” după ce o instalezi.", .en: "The dot at the top of the window shows whether everything DaVinci Resolve needs is present — red means a REQUIRED component is missing (e.g. Resolve itself), green means “System ready”. Click the indicator to open “System Check & Dependencies”, with an “Install...” button on any missing component and “Recheck all” after installing it.", .es: "El punto en la parte superior de la ventana muestra si todo lo que necesita DaVinci Resolve está presente — rojo significa que falta un componente OBLIGATORIO (p. ej. Resolve mismo), verde significa “Sistema listo”. Haz clic en el indicador para abrir “Comprobación y Dependencias del Sistema”, con un botón “Instalar...” en cualquier componente faltante y “Volver a verificar todo” tras instalarlo."],
        "help.mobile.title": [.ro: "Aplicația pentru telefon", .en: "The phone app", .es: "La app para el teléfono"],
        "help.mobile.body": [.ro: "Deschide gordas.dev de pe telefon (Android sau iPhone) — catalogul complet e disponibil direct în browser, fără magazin de aplicații. Din meniul browserului alege „Adaugă pe ecranul principal” pentru o iconiță ca o aplicație obișnuită.", .en: "Open gordas.dev on your phone (Android or iPhone) — the full catalog is available directly in the browser, no app store needed. From the browser menu, choose “Add to Home Screen” for an icon that behaves like a regular app.", .es: "Abre gordas.dev en tu teléfono (Android o iPhone) — el catálogo completo está disponible directamente en el navegador, sin tienda de apps. Desde el menú del navegador, elige “Añadir a pantalla de inicio” para un icono que se comporta como una app normal."],
        "help.support.title": [.ro: "Suport", .en: "Support", .es: "Soporte"],
        "help.support.body": [.ro: "Ai o problemă sau o întrebare? Scrie-mi pe WhatsApp din pagina „Licență” — răspund direct.", .en: "Have a problem or a question? Message me on WhatsApp from the “License” page — I reply directly.", .es: "¿Tienes un problema o una pregunta? Escríbeme por WhatsApp desde la página “Licencia” — respondo directamente."],

        "update.title": [.ro: "Versiune nouă disponibilă", .en: "New version available", .es: "Nueva versión disponible"],
        // "update.download": buton care acum descarca SI instaleaza direct
        // (SelfUpdater), nu mai deschide browserul.
        "update.download": [.ro: "Descarcă și instalează", .en: "Download & Install", .es: "Descargar e instalar"],
        "update.downloading": [.ro: "Se descarcă actualizarea…", .en: "Downloading the update…", .es: "Descargando la actualización…"],
        "update.extracting": [.ro: "Se dezarhivează…", .en: "Extracting…", .es: "Descomprimiendo…"],
        "update.installing": [.ro: "Se instalează — introdu parola de administrator când ți se cere", .en: "Installing — enter your administrator password when asked", .es: "Instalando — introduce tu contraseña de administrador cuando se te pida"],
        "update.installFailed.title": [.ro: "Actualizarea a eșuat", .en: "Update failed", .es: "La actualización falló"],
        "update.installFailed.body": [.ro: "%@\n\nPoți descărca manual ultima versiune de pe pagina de GitHub.", .en: "%@\n\nYou can download the latest version manually from the GitHub page.", .es: "%@\n\nPuedes descargar manualmente la última versión desde la página de GitHub."],
        "update.installFailed.openPage": [.ro: "Deschide pagina", .en: "Open page", .es: "Abrir página"],
        "update.dismiss": [.ro: "Închide", .en: "Dismiss", .es: "Cerrar"],
        // Pop-up modal (ContentView.swift), separat de bannerul de mai sus.
        // Explica raspicat ca nu e self-update — vezi cererea din 2026-08-24.
        "update.popup.title": [.ro: "Actualizare disponibilă", .en: "Update available", .es: "Actualización disponible"],
        "update.popup.message": [.ro: "Este disponibilă o nouă versiune! Apeși Actualizează acum și se instalează automat — o să-ți ceară parola de administrator.", .en: "A new version is available! Click Update now and it installs automatically — you'll be asked for your admin password.", .es: "¡Hay una nueva versión disponible! Pulsa Actualizar ahora y se instala automáticamente — se te pedirá tu contraseña de administrador."],
        "update.popup.later": [.ro: "Mai târziu", .en: "Later", .es: "Más tarde"],
        "update.popup.now": [.ro: "Actualizează acum", .en: "Update now", .es: "Actualizar ahora"],
        "update.popup.changes": [.ro: "Noutăți", .en: "What's new", .es: "Novedades"],

        "menu.quit": [.ro: "Închide GDC Plugin Manager", .en: "Quit GDC Plugin Manager", .es: "Salir de GDC Plugin Manager"],
    ]
}
