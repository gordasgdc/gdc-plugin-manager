#!/usr/bin/env python3
"""Generează pagina platformei GDC Plugin Manager (RO: docs/index.html, EN: docs/en/, ES: docs/es/).

Sursa unică de conținut e acest fișier; lista de aplicații vine din docs/catalog.json, iar versiunile
Managerului din docs/update.json — pagina nu poate contrazice catalogul sau canalul de actualizare.
Nu atinge paginile de produs, manifestele sau descărcările. Fără sume: prețurile nu apar pe această pagină.

    scripts/build_platform_site.py          # scrie cele trei pagini
    scripts/build_platform_site.py --check  # nu scrie; iese 1 dacă paginile de pe disc diferă de ce s-ar genera
"""
import html
import json
import os
import sys
import urllib.parse

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DOCS = os.path.join(ROOT, "docs")
LANGS = ("ro", "en", "es")
PATH = {"ro": "/", "en": "/en/", "es": "/es/"}
BASE = "https://gordas.dev"
MAC_DL = "https://github.com/gordasgdc/gdc-plugin-manager/releases/latest/download/GDCPluginManager-Mac.dmg"

T = {
 "ro": dict(
  title="GDC Plugin Manager — produsele GDC, într-un singur loc",
  desc="Aplicația gratuită prin care găsești, instalezi, deschizi și actualizezi produsele GDC: pluginuri pentru DaVinci Resolve și aplicații independente. Mac și Windows.",
  skip="Treci la conținut", menu="Meniu", langlabel="Limba",
  nav=[("platforma", "Platforma"), ("tipuri", "Aplicații și pluginuri"), ("produse", "Produse"), ("instalare", "Instalare"), ("sisteme", "Mac și Windows"), ("suport", "Suport")],
  dl="Descarcă",
  h1="Tot ce face GDC,<br>într-un singur loc.",
  lead="GDC Plugin Manager este aplicația gratuită prin care găsești produsele GDC — pluginuri pentru DaVinci Resolve și aplicații independente —, le instalezi sau le deschizi și afli când apare o versiune nouă.",
  dl_mac="Descarcă pentru Mac", dl_mac_s="macOS 14+ · Apple Silicon · versiunea {mac}",
  dl_win="Descarcă pentru Windows", dl_win_s="Windows pe 64 de biți · versiunea {win}",
  hero_fine="Aplicația este gratuită și nu cere cont. Produsele cu licență se activează separat.",
  hero_cap="Aplicațiile mele: aplicațiile GDC găsite pe acest Mac, cu versiunea instalată.",
  intro_big="Instrumentele GDC erau răspândite între pagini, arhive și foldere ascunse. Managerul le adună: vezi ce există, ce ai deja și ce s-a schimbat.",
  facts=[("Gratuit, fără cont", "Doar produsele care cer licență se activează, separat, printr-o donație sau un drept acordat."),
         ("Română, English, Español", "Interfața aplicației și paginile produselor sunt în aceleași trei limbi."),
         ("Mac și Windows", "Cu diferențe reale între ele; le numim în secțiunea Mac și Windows."),
         ("Catalog viu", "Produsele noi apar fără să reinstalezi Managerul.")],
  types_h="Aplicații și pluginuri nu sunt același lucru.",
  types_lead="Managerul le tratează diferit, pentru că ele se comportă diferit pe calculatorul tău.",
  types_cols=("Pluginuri", "Aplicații"),
  types_rows=[
   ("Ce sunt", "DCTL, LUT, Fuse, OFX, PowerGrade și scripturi care rulează în interiorul DaVinci Resolve.", "Programe de sine stătătoare, cu fereastra lor: de exemplu SADROG, DataMover sau GDC STYLE Client."),
   ("Unde ajung", "Managerul le pune în folderele pe care Resolve le citește la pornire.", "Se instalează ca orice aplicație, dintr-un DMG sau dintr-un installer. Managerul îți arată pagina și descărcarea."),
   ("Ce face Managerul", "Le instalează, le actualizează și le elimină cu un clic și te avertizează dacă Resolve este deschis.", "Le listează, le deschide și, pe Mac, recunoaște aplicațiile GDC de pe disc chiar dacă le-ai instalat singur."),
   ("Actualizare", "Cu un clic, din Manager.", "Managerul îți arată că există o versiune nouă și deschide pagina produsului. O aplicație deschisă nu este înlocuită."),
   ("Licență", "Fiecare produs cu licență are codul lui, introdus în pagina Licență.", "Fiecare aplicație își gestionează singură activarea. Managerul nu o arată și nu o schimbă."),
  ],
  disc_h="Descoperi produsele fără să le cauți pe rând.",
  disc_p=["Catalogul se încarcă la deschidere. Răsfoiești pe secțiuni — pluginuri după tip, aplicații, materiale, cursuri, evenimente, magazine partenere — și filtrezi după sistem și după tipul de acces.",
          "Fără conexiune, aplicația arată ultimul catalog salvat și spune clar că nu este cel curent."],
  disc_cap="Secțiunea Aplicații: SADROG apare printre celelalte aplicații GDC.",
  inst_h="Instalare, detectare, actualizare.",
  inst1_h="Pluginuri: instalate la locul lor",
  inst1_p=["Alegi produsul și apeși Instalează. Managerul scrie fișierele în folderul potrivit al Resolve și cere parola de administrator doar dacă scrierea directă este refuzată.",
           "Resolve încarcă pluginurile la pornire, așa că aplicația te avertizează când este deschis."],
  det_h="Aplicații: recunoscute, chiar dacă le-ai instalat singur",
  det_p=["Pagina Aplicațiile mele arată aplicațiile GDC găsite pe acest Mac, inclusiv cele descărcate și instalate direct, fără Manager. Recunoașterea se face după identitatea aplicației și semnătura Apple, nu după numele folderului; o copie de test sau un disc montat nu este luată drept instalarea ta.",
         "Vezi versiunea instalată, dacă aplicația rulează acum și dacă există una mai nouă. Instalat nu înseamnă activat: licența rămâne în aplicație. Managerul nu dezinstalează aplicațiile pe care nu le-a instalat el."],
  det_note="Funcția este în Managerul pentru Mac, de la versiunea 1.41.0. Versiunile mai vechi nu o au; actualizează-l din aplicație.",
  det_cap="Aplicațiile mele: SADROG, GDC STYLE Client și alte aplicații GDC găsite pe acest Mac.",
  upd_h="Actualizări, fără surprize",
  upd_p="Pluginurile se actualizează cu un clic. Pentru aplicații, Managerul îți arată insigna de versiune nouă și butonul Actualizează, care deschide pagina produsului. Dacă aplicația rulează, îți spune să o închizi înainte de a instala.",
  prod_h="Produsele disponibile acum.",
  prod_lead="Lista vine direct din catalogul public; pagina fiecărui produs spune ce face și ce cere.",
  os={"macOS": "Doar Mac", "windows": "Doar Windows", "crossPlatform": "Mac și Windows"},
  feat_h="SADROG",
  feat_p="Înregistrare și montaj video pentru Mac: ecranul, camera și sunetul ajung pe piste separate, într-un singur proiect. Cere macOS 15+ și Apple Silicon și nu există pentru Windows. Evaluare de 5 zile, apoi activare din aplicație.",
  feat_btn="Pagina SADROG", feat_dl="Descarcă SADROG", feat_alt="SADROG: editorul cu un proiect demonstrativ",
  steps_h="Cum începi.",
  steps=[("Descarcă Managerul", "Alege Mac sau Windows de sus."), ("Deschide catalogul", "Răsfoiește secțiunile sau caută după nume."), ("Instalează sau deschide", "Pluginurile se instalează din Manager; aplicațiile se descarcă de pe pagina lor."), ("Activează, dacă e nevoie", "Produsele cu licență cer un cod, introdus în pagina Licență sau în aplicația respectivă.")],
  sys_h="Mac și Windows: ce e la fel și ce nu.",
  sys_cols=("", "Mac", "Windows"),
  sys_rows=[("Versiunea Managerului", "{mac}", "{win}"),
            ("Cerințe", "macOS 14+, Apple Silicon", "Windows pe 64 de biți"),
            ("Catalog, instalare și actualizare pluginuri", "Da", "Da"),
            ("Aplicațiile mele (detectarea aplicațiilor instalate)", "Da, din 1.41.0", "Nu există"),
            ("SADROG, GDC STYLE Client", "Da", "Nu există pentru Windows"),
            ("Pe telefon", "Catalogul se deschide în browser, la gordas.dev/app.html", "Catalogul se deschide în browser, la gordas.dev/app.html")],
  sys_note="Un produs marcat doar pentru Mac nu apare ca instalabil în Managerul pentru Windows, și invers.",
  faq_h="Întrebări frecvente și suport.",
  faq=[("Costă ceva Managerul?", "Nu. Aplicația este gratuită și nu cere cont. Produsele care cer licență se activează separat, printr-o donație sau un drept acordat; sumele nu apar pe această pagină."),
       ("Am instalat SADROG direct din DMG. Îl vede Managerul?", "Pe Mac, da, din versiunea 1.41.0: apare în Aplicațiile mele cu versiunea instalată. Managerul nu îl instalează, nu îl dezinstalează și nu îi schimbă licența."),
       ("De ce nu văd o aplicație instalată în Aplicațiile mele?", "Managerul recunoaște aplicațiile GDC cunoscute, după identitatea și semnătura lor. O copie modificată, de test sau aflată pe o imagine de disc montată nu este recunoscută."),
       ("Instalarea unui plugin cere repornirea Resolve?", "Da. DaVinci Resolve citește pluginurile la pornire; Managerul te avertizează dacă este deschis."),
       ("Unde cer ajutor?", "Scrie la academiagdc@gmail.com. Pentru o aplicație anume, folosește pagina ei de produs.")],
  mail="Scrie-ne",
  legal="Platformă administrată de dezvoltatori independenți, oferită „ca atare”, cu contribuții opționale și donații.",
  terms="Termeni", priv="Confidențialitate", cookie="Cookie-uri", src="Cod sursă",
  font="Fontul Fraunces, licență SIL OFL.",
 ),
 "en": dict(
  title="GDC Plugin Manager — every GDC product, in one place",
  desc="The free app for finding, installing, opening and updating GDC products: plugins for DaVinci Resolve and standalone apps. Mac and Windows.",
  skip="Skip to content", menu="Menu", langlabel="Language",
  nav=[("platforma", "Platform"), ("tipuri", "Apps and plugins"), ("produse", "Products"), ("instalare", "Install"), ("sisteme", "Mac and Windows"), ("suport", "Support")],
  dl="Download",
  h1="Everything GDC makes,<br>in one place.",
  lead="GDC Plugin Manager is the free app where you find GDC products — plugins for DaVinci Resolve and standalone apps — install or open them, and learn when a new version arrives.",
  dl_mac="Download for Mac", dl_mac_s="macOS 14+ · Apple Silicon · version {mac}",
  dl_win="Download for Windows", dl_win_s="64-bit Windows · version {win}",
  hero_fine="The app is free and needs no account. Licensed products are activated separately.",
  hero_cap="My Apps: the GDC apps found on this Mac, with their installed version.",
  intro_big="GDC tools used to be scattered across pages, archives and hidden folders. The Manager brings them together: you see what exists, what you already have and what changed.",
  facts=[("Free, no account", "Only products that need a licence are activated, separately, through a donation or a granted right."),
         ("Română, English, Español", "The app interface and the product pages come in the same three languages."),
         ("Mac and Windows", "With real differences between them; we name them in the Mac and Windows section."),
         ("Live catalog", "New products appear without reinstalling the Manager.")],
  types_h="Apps and plugins are not the same thing.",
  types_lead="The Manager treats them differently because they behave differently on your computer.",
  types_cols=("Plugins", "Apps"),
  types_rows=[
   ("What they are", "DCTL, LUT, Fuse, OFX, PowerGrade and scripts that run inside DaVinci Resolve.", "Standalone programs with their own window — for example SADROG, DataMover or GDC STYLE Client."),
   ("Where they go", "The Manager places them in the folders Resolve reads at launch.", "They install like any app, from a DMG or an installer. The Manager shows you the page and the download."),
   ("What the Manager does", "Installs, updates and removes them with one click, and warns you if Resolve is open.", "Lists and opens them and, on Mac, recognises GDC apps already on disk even if you installed them yourself."),
   ("Updates", "One click, from the Manager.", "The Manager tells you a newer version exists and opens the product page. An open app is never replaced."),
   ("Licence", "Each licensed product has its own code, entered on the Licence page.", "Each app manages its own activation. The Manager neither shows nor changes it."),
  ],
  disc_h="Discover products without hunting for each one.",
  disc_p=["The catalog loads when you open the app. Browse by section — plugins by type, apps, materials, courses, events, partner stores — and filter by system and by type of access.",
          "Offline, the app shows the last saved catalog and says plainly that it is not the current one."],
  disc_cap="The Apps section: SADROG appears among the other GDC apps.",
  inst_h="Install, detect, update.",
  inst1_h="Plugins: installed where they belong",
  inst1_p=["Pick a product and press Install. The Manager writes the files into the right Resolve folder and asks for the administrator password only if a direct write is refused.",
           "Resolve loads plugins at launch, so the app warns you when it is open."],
  det_h="Apps: recognised even if you installed them yourself",
  det_p=["The My Apps page lists the GDC apps found on this Mac, including those downloaded and installed directly, without the Manager. Recognition uses the app’s identity and Apple signature, not the folder name; a test copy or a mounted disk image is not mistaken for your install.",
         "You see the installed version, whether the app is running right now and whether a newer one exists. Installed does not mean activated: the licence stays in the app. The Manager does not uninstall apps it did not install."],
  det_note="This is in the Mac Manager, from version 1.41.0. Older versions do not have it; update from within the app.",
  det_cap="My Apps: SADROG, GDC STYLE Client and other GDC apps found on this Mac.",
  upd_h="Updates, no surprises",
  upd_p="Plugins update with one click. For apps, the Manager shows a new-version badge and an Update button that opens the product page. If the app is running, it tells you to quit it before installing.",
  prod_h="Products available now.",
  prod_lead="The list comes straight from the public catalog; each product page says what it does and what it needs.",
  os={"macOS": "Mac only", "windows": "Windows only", "crossPlatform": "Mac and Windows"},
  feat_h="SADROG",
  feat_p="Screen recording and video editing for Mac: screen, camera and sound land on separate tracks in one project. Needs macOS 15+ and Apple Silicon; there is no Windows version. 5-day evaluation, then activation inside the app.",
  feat_btn="SADROG page", feat_dl="Download SADROG", feat_alt="SADROG: the editor with a demonstration project",
  steps_h="How to start.",
  steps=[("Download the Manager", "Pick Mac or Windows above."), ("Open the catalog", "Browse the sections or search by name."), ("Install or open", "Plugins install from the Manager; apps download from their own page."), ("Activate if needed", "Licensed products ask for a code, entered on the Licence page or in that app.")],
  sys_h="Mac and Windows: what is the same and what is not.",
  sys_cols=("", "Mac", "Windows"),
  sys_rows=[("Manager version", "{mac}", "{win}"),
            ("Requirements", "macOS 14+, Apple Silicon", "64-bit Windows"),
            ("Catalog, plugin install and update", "Yes", "Yes"),
            ("My Apps (detecting installed apps)", "Yes, from 1.41.0", "Not available"),
            ("SADROG, GDC STYLE Client", "Yes", "Not available for Windows"),
            ("On a phone", "The catalog opens in the browser at gordas.dev/app.html", "The catalog opens in the browser at gordas.dev/app.html")],
  sys_note="A product marked Mac-only does not show as installable in the Windows Manager, and the other way round.",
  faq_h="Questions and support.",
  faq=[("Does the Manager cost anything?", "No. The app is free and needs no account. Products that need a licence are activated separately, through a donation or a granted right; amounts do not appear on this page."),
       ("I installed SADROG straight from the DMG. Does the Manager see it?", "On Mac, yes, from version 1.41.0: it appears in My Apps with its installed version. The Manager does not install it, uninstall it or change its licence."),
       ("Why is an installed app missing from My Apps?", "The Manager recognises known GDC apps by their identity and signature. A modified copy, a test copy or one on a mounted disk image is not recognised."),
       ("Does installing a plugin require restarting Resolve?", "Yes. DaVinci Resolve reads plugins at launch; the Manager warns you if it is open."),
       ("Where do I ask for help?", "Write to academiagdc@gmail.com. For a specific app, use its product page.")],
  mail="Write to us",
  legal="Platform run by independent developers, provided “as is”, with optional contributions and donations.",
  terms="Terms", priv="Privacy", cookie="Cookies", src="Source code",
  font="Fraunces typeface, SIL OFL licence.",
 ),
 "es": dict(
  title="GDC Plugin Manager — todos los productos GDC, en un solo lugar",
  desc="La aplicación gratuita para encontrar, instalar, abrir y actualizar los productos GDC: plugins para DaVinci Resolve y aplicaciones independientes. Mac y Windows.",
  skip="Ir al contenido", menu="Menú", langlabel="Idioma",
  nav=[("platforma", "Plataforma"), ("tipuri", "Apps y plugins"), ("produse", "Productos"), ("instalare", "Instalación"), ("sisteme", "Mac y Windows"), ("suport", "Soporte")],
  dl="Descargar",
  h1="Todo lo que hace GDC,<br>en un solo lugar.",
  lead="GDC Plugin Manager es la aplicación gratuita donde encuentras los productos GDC —plugins para DaVinci Resolve y aplicaciones independientes—, los instalas o los abres y te enteras cuando sale una versión nueva.",
  dl_mac="Descargar para Mac", dl_mac_s="macOS 14+ · Apple Silicon · versión {mac}",
  dl_win="Descargar para Windows", dl_win_s="Windows de 64 bits · versión {win}",
  hero_fine="La aplicación es gratuita y no pide cuenta. Los productos con licencia se activan por separado.",
  hero_cap="Mis aplicaciones: las aplicaciones GDC halladas en este Mac, con su versión instalada.",
  intro_big="Las herramientas GDC estaban repartidas entre páginas, archivos y carpetas ocultas. El Manager las reúne: ves qué existe, qué tienes ya y qué ha cambiado.",
  facts=[("Gratis, sin cuenta", "Solo los productos que requieren licencia se activan, por separado, mediante una donación o un derecho concedido."),
         ("Română, English, Español", "La interfaz de la aplicación y las páginas de producto vienen en los mismos tres idiomas."),
         ("Mac y Windows", "Con diferencias reales entre ambos; las nombramos en la sección Mac y Windows."),
         ("Catálogo vivo", "Los productos nuevos aparecen sin reinstalar el Manager.")],
  types_h="Aplicaciones y plugins no son lo mismo.",
  types_lead="El Manager los trata de forma distinta porque se comportan de forma distinta en tu ordenador.",
  types_cols=("Plugins", "Aplicaciones"),
  types_rows=[
   ("Qué son", "DCTL, LUT, Fuse, OFX, PowerGrade y scripts que se ejecutan dentro de DaVinci Resolve.", "Programas independientes, con su propia ventana: por ejemplo SADROG, DataMover o GDC STYLE Client."),
   ("Dónde van", "El Manager los coloca en las carpetas que Resolve lee al arrancar.", "Se instalan como cualquier aplicación, desde un DMG o un instalador. El Manager te muestra la página y la descarga."),
   ("Qué hace el Manager", "Los instala, actualiza y elimina con un clic y te avisa si Resolve está abierto.", "Los lista, los abre y, en Mac, reconoce las aplicaciones GDC del disco aunque las hayas instalado tú."),
   ("Actualización", "Con un clic, desde el Manager.", "El Manager te indica que hay una versión nueva y abre la página del producto. Una aplicación abierta nunca se sustituye."),
   ("Licencia", "Cada producto con licencia tiene su código, que se introduce en la página Licencia.", "Cada aplicación gestiona su propia activación. El Manager ni la muestra ni la cambia."),
  ],
  disc_h="Descubre productos sin buscarlos uno a uno.",
  disc_p=["El catálogo se carga al abrir. Navega por secciones —plugins por tipo, aplicaciones, materiales, cursos, eventos, tiendas asociadas— y filtra por sistema y por tipo de acceso.",
          "Sin conexión, la aplicación muestra el último catálogo guardado y dice claramente que no es el actual."],
  disc_cap="La sección Aplicaciones: SADROG aparece entre las demás aplicaciones GDC.",
  inst_h="Instalar, detectar, actualizar.",
  inst1_h="Plugins: instalados en su sitio",
  inst1_p=["Eliges el producto y pulsas Instalar. El Manager escribe los archivos en la carpeta correcta de Resolve y pide la contraseña de administrador solo si la escritura directa es rechazada.",
           "Resolve carga los plugins al arrancar, por eso la aplicación te avisa cuando está abierto."],
  det_h="Aplicaciones: reconocidas aunque las hayas instalado tú",
  det_p=["La página Mis aplicaciones muestra las aplicaciones GDC que hay en este Mac, también las descargadas e instaladas directamente, sin el Manager. El reconocimiento usa la identidad de la aplicación y la firma de Apple, no el nombre de la carpeta; una copia de prueba o una imagen de disco montada no se toma por tu instalación.",
         "Ves la versión instalada, si la aplicación está en ejecución y si existe una más nueva. Instalado no significa activado: la licencia queda en la aplicación. El Manager no desinstala aplicaciones que no instaló él."],
  det_note="Esto está en el Manager para Mac, desde la versión 1.41.0. Las versiones anteriores no lo tienen; actualiza desde la propia aplicación.",
  det_cap="Mis aplicaciones: SADROG, GDC STYLE Client y otras aplicaciones GDC halladas en este Mac.",
  upd_h="Actualizaciones, sin sorpresas",
  upd_p="Los plugins se actualizan con un clic. En las aplicaciones, el Manager muestra la insignia de versión nueva y el botón Actualizar, que abre la página del producto. Si la aplicación está en ejecución, te pide cerrarla antes de instalar.",
  prod_h="Productos disponibles ahora.",
  prod_lead="La lista sale directamente del catálogo público; la página de cada producto explica qué hace y qué requiere.",
  os={"macOS": "Solo Mac", "windows": "Solo Windows", "crossPlatform": "Mac y Windows"},
  feat_h="SADROG",
  feat_p="Grabación y edición de vídeo para Mac: pantalla, cámara y sonido quedan en pistas separadas dentro de un proyecto. Requiere macOS 15+ y Apple Silicon; no existe versión para Windows. Evaluación de 5 días y después activación dentro de la aplicación.",
  feat_btn="Página de SADROG", feat_dl="Descargar SADROG", feat_alt="SADROG: el editor con un proyecto de demostración",
  steps_h="Cómo empezar.",
  steps=[("Descarga el Manager", "Elige Mac o Windows arriba."), ("Abre el catálogo", "Navega por las secciones o busca por nombre."), ("Instala o abre", "Los plugins se instalan desde el Manager; las aplicaciones se descargan de su página."), ("Activa si hace falta", "Los productos con licencia piden un código, que se introduce en la página Licencia o en esa aplicación.")],
  sys_h="Mac y Windows: qué es igual y qué no.",
  sys_cols=("", "Mac", "Windows"),
  sys_rows=[("Versión del Manager", "{mac}", "{win}"),
            ("Requisitos", "macOS 14+, Apple Silicon", "Windows de 64 bits"),
            ("Catálogo, instalación y actualización de plugins", "Sí", "Sí"),
            ("Mis aplicaciones (detección de aplicaciones instaladas)", "Sí, desde 1.41.0", "No existe"),
            ("SADROG, GDC STYLE Client", "Sí", "No existe para Windows"),
            ("En el teléfono", "El catálogo se abre en el navegador, en gordas.dev/app.html", "El catálogo se abre en el navegador, en gordas.dev/app.html")],
  sys_note="Un producto marcado solo para Mac no aparece como instalable en el Manager para Windows, y viceversa.",
  faq_h="Preguntas frecuentes y soporte.",
  faq=[("¿Cuesta algo el Manager?", "No. La aplicación es gratuita y no pide cuenta. Los productos que requieren licencia se activan por separado, mediante una donación o un derecho concedido; los importes no aparecen en esta página."),
       ("Instalé SADROG directamente desde el DMG. ¿Lo ve el Manager?", "En Mac, sí, desde la versión 1.41.0: aparece en Mis aplicaciones con su versión instalada. El Manager no lo instala, no lo desinstala ni cambia su licencia."),
       ("¿Por qué no veo una aplicación instalada en Mis aplicaciones?", "El Manager reconoce las aplicaciones GDC conocidas por su identidad y su firma. Una copia modificada, de prueba o situada en una imagen de disco montada no se reconoce."),
       ("¿Instalar un plugin exige reiniciar Resolve?", "Sí. DaVinci Resolve lee los plugins al arrancar; el Manager te avisa si está abierto."),
       ("¿Dónde pido ayuda?", "Escribe a academiagdc@gmail.com. Para una aplicación concreta, usa su página de producto.")],
  mail="Escríbenos",
  legal="Plataforma administrada por desarrolladores independientes, ofrecida «tal cual», con contribuciones opcionales y donaciones.",
  terms="Términos", priv="Privacidad", cookie="Cookies", src="Código fuente",
  font="Tipografía Fraunces, licencia SIL OFL.",
 ),
}

SHOTS = {"catalog": "Catalog", "apps": "Apps", "myapps": "MyApps"}


def brand_version():
    import hashlib
    return hashlib.sha256(open(os.path.join(DOCS, "icons", "icon-512.png"), "rb").read()).hexdigest()[:8]


def esc(s):
    return html.escape(s, quote=True)


def img(name, lang, alt, w, h, eager=False):
    base = f"/assets/img/{name}-{lang}"
    return (f'<img src="{base}-1800.webp" srcset="{base}-900.webp 900w, {base}-1800.webp 1800w" sizes="(max-width:860px) 92vw, 760px" '
            f'width="{w}" height="{h}" alt="{esc(alt)}"' + ('' if eager else ' loading="lazy"') + ' decoding="async">')


def sizes_of(name, lang):
    p = os.path.join(DOCS, "assets", "img", f"{name}-{lang}-1800.webp")
    try:
        import struct
        with open(p, "rb") as f:
            d = f.read(40)
        if d[12:16] == b"VP8 ":
            w, h = struct.unpack("<HH", d[26:30]); return w & 0x3fff, h & 0x3fff
        if d[12:16] == b"VP8L":
            b = d[21:25]; v = int.from_bytes(b, "little"); return (v & 0x3fff) + 1, ((v >> 14) & 0x3fff) + 1
        if d[12:16] == b"VP8X":
            return int.from_bytes(d[24:27], "little") + 1, int.from_bytes(d[27:30], "little") + 1
    except OSError:
        pass
    return 1800, 1125


def load():
    cat = json.load(open(os.path.join(DOCS, "catalog.json"), encoding="utf8"))
    upd = json.load(open(os.path.join(DOCS, "update.json"), encoding="utf8"))
    return cat, upd


def render(lang, cat, upd):
    t = T[lang]
    bv = brand_version()
    mac, win = upd["mac"]["version"], upd["windows"]["version"]
    apps = sorted(cat["apps"], key=lambda a: (a["id"] != "sadrog", a["name"].lower()))
    out = []
    a = out.append
    alts = "".join(f'<link rel="alternate" hreflang="{l}" href="{BASE}{PATH[l]}">' for l in LANGS) + f'<link rel="alternate" hreflang="x-default" href="{BASE}/">'
    a(f'<!DOCTYPE html>\n<html lang="{lang}">\n<head>\n<meta charset="UTF-8">\n<meta name="viewport" content="width=device-width, initial-scale=1">\n'
      f'<title>{esc(t["title"])}</title>\n<meta name="description" content="{esc(t["desc"])}">\n<link rel="canonical" href="{BASE}{PATH[lang]}">{alts}\n'
      f'<meta property="og:title" content="{esc(t["title"])}"><meta property="og:description" content="{esc(t["desc"])}"><meta property="og:type" content="website"><meta property="og:url" content="{BASE}{PATH[lang]}">\n'
      f'<meta name="theme-color" content="#f4f1ea">\n<link rel="icon" type="image/x-icon" href="/favicon.ico?v={bv}"><link rel="icon" type="image/png" sizes="32x32" href="/favicon-32.png?v={bv}"><link rel="apple-touch-icon" href="/apple-touch-icon.png?v={bv}">\n'
      f'<meta property="og:image" content="{BASE}/icons/icon-512.png?v={bv}"><meta property="og:image:width" content="512"><meta property="og:image:height" content="512"><meta name="twitter:card" content="summary"><meta name="twitter:image" content="{BASE}/icons/icon-512.png?v={bv}">\n'
      '<link rel="manifest" href="/manifest.webmanifest">\n<link rel="preload" href="/assets/fonts/fraunces-600-latin.woff2" as="font" type="font/woff2" crossorigin>\n<link rel="stylesheet" href="/assets/platform.css">\n</head>\n<body>')
    a(f'<a class="skip" href="#main">{esc(t["skip"])}</a>')
    nav = "".join(f'<a href="#{i}">{esc(n)}</a>' for i, n in t["nav"])
    sw = "".join(f'<a href="{PATH[l]}" hreflang="{l}" lang="{l}" aria-label="{n}"' + (' aria-current="true"' if l == lang else '') + f'>{l.upper()}</a>'
                 for l, n in (("ro", "Română"), ("en", "English"), ("es", "Español")))
    a(f'<header class="top"><div class="wrap bar"><a class="brand" href="{PATH[lang]}"><img src="/icons/icon-192.png?v={bv}" width="32" height="32" alt=""><span>GDC Plugin Manager</span></a>'
      f'<nav class="nav" id="nav" aria-label="{esc(t["menu"])}">{nav}</nav><div class="sw" role="group" aria-label="{esc(t["langlabel"])}">{sw}</div>'
      f'<button class="burger" aria-expanded="false" aria-controls="nav" aria-label="{esc(t["menu"])}">☰</button></div></header>')
    a('<main id="main">')
    w, h = sizes_of("shot-catalog", lang)
    a(f'<section class="hero" id="platforma"><div class="wrap"><div><h1>{t["h1"]}</h1><p class="lead">{esc(t["lead"])}</p>'
      f'<div class="cta"><a class="btn" href="{MAC_DL}">{esc(t["dl_mac"])}<small>{esc(t["dl_mac_s"].format(mac=mac))}</small></a>'
      f'<a class="btn alt" href="{esc(upd["windows"]["download_url"])}">{esc(t["dl_win"])}<small>{esc(t["dl_win_s"].format(win=win))}</small></a></div>'
      f'<p class="fine">{esc(t["hero_fine"])}</p></div><figure class="shot">{img("shot-catalog", lang, t["hero_cap"], w, h, True)}<figcaption>{esc(t["hero_cap"])}</figcaption></figure></div></section>')
    facts = "".join(f'<li><b>{esc(x)}</b>{esc(y)}</li>' for x, y in t["facts"])
    a(f'<section class="sec"><div class="wrap intro"><p class="big">{esc(t["intro_big"])}</p><ul class="facts">{facts}</ul></div></section>')
    rows = "".join(f'<tr><th scope="row">{esc(r[0])}</th><td data-h="{esc(t["types_cols"][0])}">{esc(r[1])}</td><td data-h="{esc(t["types_cols"][1])}">{esc(r[2])}</td></tr>' for r in t["types_rows"])
    a(f'<section class="sec" id="tipuri"><div class="wrap"><header class="head"><h2>{esc(t["types_h"])}</h2><p class="lead">{esc(t["types_lead"])}</p></header>'
      f'<table class="cmp"><thead><tr><th><span class="sr" hidden></span></th><th scope="col">{esc(t["types_cols"][0])}</th><th scope="col">{esc(t["types_cols"][1])}</th></tr></thead><tbody>{rows}</tbody></table></div></section>')
    w, h = sizes_of("shot-apps", lang)
    a(f'<section class="sec"><div class="wrap split rev"><div><h2>{esc(t["disc_h"])}</h2>' + "".join(f'<p>{esc(p)}</p>' for p in t["disc_p"]) +
      f'</div><figure class="shot">{img("shot-apps", lang, t["disc_cap"], w, h)}<figcaption>{esc(t["disc_cap"])}</figcaption></figure></div></section>')
    w, h = sizes_of("shot-myapps", lang)
    a(f'<section class="sec" id="instalare"><div class="wrap"><header class="head"><h2>{esc(t["inst_h"])}</h2></header>'
      f'<div class="two" style="margin-bottom:72px"><div><h3>{esc(t["inst1_h"])}</h3>' + "".join(f'<p>{esc(p)}</p>' for p in t["inst1_p"]) +
      f'</div><div><h3>{esc(t["upd_h"])}</h3><p>{esc(t["upd_p"])}</p></div></div>'
      f'<div class="split"><div><h3>{esc(t["det_h"])}</h3>' + "".join(f'<p>{esc(p)}</p>' for p in t["det_p"]) + f'<p class="note">{esc(t["det_note"])}</p></div>'
      f'<figure class="shot">{img("shot-myapps", lang, t["det_cap"], w, h)}<figcaption>{esc(t["det_cap"])}</figcaption></figure></div></div></section>')
    sad = next(x for x in apps if x["id"] == "sadrog")
    rowsp = ""
    for x in apps:
        ci = x.get("coverImage") or ""
        cover = ci if ci.startswith("http") else ("/" + ci if ci else "")
        osl = t["os"].get(x.get("supportedOS", "crossPlatform"), "")
        rowsp += (f'<a class="row" href="{esc(x["url"])}">' + (f'<img src="{esc(cover)}" width="48" height="48" alt="" loading="lazy">' if cover else '<span></span>') + f'<span class="n">{esc(x["name"])}</span>'
                  f'<span class="o">{esc(osl)}</span><span class="go" aria-hidden="true">→</span></a>')
    sp = {"ro": "/sadrog/", "en": "/sadrog/en/", "es": "/sadrog/es/"}[lang]
    a(f'<section class="sec" id="produse"><div class="wrap"><header class="head"><h2>{esc(t["prod_h"])}</h2><p class="lead">{esc(t["prod_lead"])}</p></header>'
      f'<div class="feat"><div><h3>{esc(t["feat_h"])}</h3><p>{esc(t["feat_p"])}</p><p><a class="btn" href="{sp}">{esc(t["feat_btn"])}</a> '
      f'<a class="btn alt" style="color:#fff;box-shadow:inset 0 0 0 1.5px #fff" href="{esc(sad["downloadURL"])}">{esc(t["feat_dl"])}</a></p></div>'
      f'<img src="/sadrog/assets/img/{lang}-01-editor-900.webp" width="900" height="563" alt="{esc(t["feat_alt"])}" loading="lazy" decoding="async"></div>'
      f'<nav class="prod" aria-label="{esc(t["prod_h"])}">{rowsp}</nav></div></section>')
    steps = "".join(f'<li><b>{esc(x)}</b><span>{esc(y)}</span></li>' for x, y in t["steps"])
    a(f'<section class="sec"><div class="wrap"><header class="head"><h2>{esc(t["steps_h"])}</h2></header><ol class="steps">{steps}</ol></div></section>')
    c = t["sys_cols"]
    srows = "".join(f'<tr><th scope="row">{esc(r[0])}</th><td data-h="{c[1]}">{esc(r[1].format(mac=mac, win=win))}</td><td data-h="{c[2]}">{esc(r[2].format(mac=mac, win=win))}</td></tr>' for r in t["sys_rows"])
    a(f'<section class="sec" id="sisteme"><div class="wrap"><header class="head"><h2>{esc(t["sys_h"])}</h2></header>'
      f'<table class="cmp"><thead><tr><th></th><th scope="col">{c[1]}</th><th scope="col">{c[2]}</th></tr></thead><tbody>{srows}</tbody></table><p class="note">{esc(t["sys_note"])}</p></div></section>')
    faq = "".join(f'<details><summary>{esc(q)}</summary><p>{esc(an)}</p></details>' for q, an in t["faq"])
    a(f'<section class="sec" id="suport"><div class="wrap"><header class="head"><h2>{esc(t["faq_h"])}</h2></header><div class="faq">{faq}</div>'
      f'<p style="margin-top:24px"><a class="btn" href="mailto:academiagdc@gmail.com">{esc(t["mail"])}<small>academiagdc@gmail.com</small></a></p></div></section>')
    a('</main>')
    a(f'<footer class="foot"><div class="wrap"><p class="flogo"><img src="/icons/icon-192.png?v={bv}" width="28" height="28" alt=""><span>GDC Plugin Manager</span></p><p>{esc(t["legal"])}</p><p><a href="/termeni">{esc(t["terms"])}</a> · <a href="/confidentialitate">{esc(t["priv"])}</a> · <a href="/cookie">{esc(t["cookie"])}</a> · '
      f'<a href="https://github.com/gordasgdc/gdc-plugin-manager">{esc(t["src"])}</a></p><p>{esc(t["font"])}</p></div></footer>')
    a('<script src="/assets/platform.js" defer></script>\n</body>\n</html>\n')
    return "".join(x if x.endswith("\n") else x + "\n" for x in out)


JS = """(function(){var b=document.querySelector('.burger'),n=document.getElementById('nav');if(!b||!n)return;
b.addEventListener('click',function(){var o=n.classList.toggle('open');b.setAttribute('aria-expanded',o?'true':'false')});
n.addEventListener('click',function(e){if(e.target.tagName==='A'){n.classList.remove('open');b.setAttribute('aria-expanded','false')}});
document.addEventListener('keydown',function(e){if(e.key==='Escape'&&n.classList.contains('open')){n.classList.remove('open');b.setAttribute('aria-expanded','false');b.focus()}})})();
"""


def main():
    check = "--check" in sys.argv
    cat, upd = load()
    targets = {os.path.join(DOCS, "index.html"): render("ro", cat, upd),
               os.path.join(DOCS, "en", "index.html"): render("en", cat, upd),
               os.path.join(DOCS, "es", "index.html"): render("es", cat, upd),
               os.path.join(DOCS, "assets", "platform.js"): JS}
    bad = 0
    for p, content in targets.items():
        if check:
            cur = open(p, encoding="utf8").read() if os.path.exists(p) else None
            if cur != content:
                print("DIFERĂ:", os.path.relpath(p, ROOT)); bad = 1
        else:
            os.makedirs(os.path.dirname(p), exist_ok=True)
            open(p, "w", encoding="utf8").write(content)
            print("scris", os.path.relpath(p, ROOT), len(content))
    sys.exit(bad)


if __name__ == "__main__":
    main()
