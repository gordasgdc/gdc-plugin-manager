# Genereaza Ghid-GDCPluginManager-{ro,en,es}.pdf, cu reportlab. Foloseste
# Arial (nu Helvetica standard-14) pentru diacriticele romanesti (s-comma,
# t-comma) — WinAnsiEncoding-ul fonturilor PDF standard nu are glyph-uri
# pentru ele, ies ca patrate goale fara font TTF embedat.
#
# STANDARD (CLAUDE.md, Partea 1, Regula 8): sectiunea de Dependinte redactata
# ultra-detaliat, pas-cu-pas, zero presupuneri — ce inseamna 🔴/🟢, unde da
# clic userul, ce se deschide, ce buton apasa.
#
# [REDESENAT COMPLET 2026-08-29] Versiunea veche (8 sectiuni, text simplu
# negru-pe-alb, fara coperta) descria doar aplicatia de acum cateva luni —
# lipseau complet cele 9 etape de upgrade v2.0 (cautare globala, Resurse
# Download separate, Aplicatiile Mele, Oferte & Susținere promotionala,
# Pachete, harti, tema, marime text). Cristi a cerut explicit "mai detaliate
# si aspect profesional, vizual". Acum: coperta cu banner de brand, bara
# colorata pe fiecare pagina, footer cu numar de pagina, casete evidentiate
# ("Sfat"/"Important") pentru puncte cheie, si 16 sectiuni (fata de 8),
# acoperind tot ce exista azi in aplicatie.
#
# Ruleaza cu: python3 installer/generate_pdf.py
# (necesita `pip install reportlab` intr-un venv)
import os
from PIL import Image as PILImage
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import cm
from reportlab.lib import colors
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, ListFlowable, ListItem, Spacer, PageBreak, Table, TableStyle, Image,
)

OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Sources", "GDCPluginManager", "Resources")
SCREENSHOTS_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "screenshots")
APP_VERSION = "1.19.14"

pdfmetrics.registerFont(TTFont("Arial", "/System/Library/Fonts/Supplemental/Arial.ttf"))
pdfmetrics.registerFont(TTFont("Arial-Bold", "/System/Library/Fonts/Supplemental/Arial Bold.ttf"))
pdfmetrics.registerFont(TTFont("Arial-Italic", "/System/Library/Fonts/Supplemental/Arial Italic.ttf"))

styles = getSampleStyleSheet()
INK = colors.HexColor("#1A1A1A")
ACCENT = colors.HexColor("#B96A1E")
ACCENT_LIGHT = colors.HexColor("#FDF3E9")
INK_DARK = colors.HexColor("#14161A")
MUTED = colors.HexColor("#6a6a6a")

title_style = ParagraphStyle("Title", parent=styles["Title"], fontName="Arial-Bold", fontSize=17, spaceAfter=14, textColor=INK)
h2_style = ParagraphStyle("H2", parent=styles["Heading2"], fontName="Arial-Bold", fontSize=12.5, textColor=ACCENT, spaceBefore=14, spaceAfter=6)
h3_style = ParagraphStyle("H3", parent=styles["Heading3"], fontName="Arial-Bold", fontSize=10.5, textColor=INK, spaceBefore=6, spaceAfter=2)
body_style = ParagraphStyle("Body", parent=styles["Normal"], fontName="Arial", fontSize=10, leading=14, textColor=INK, spaceAfter=5)
step_style = ParagraphStyle("Step", parent=body_style, leftIndent=4, spaceAfter=4)
note_style = ParagraphStyle("Note", parent=body_style, fontName="Arial", fontSize=9.5, textColor=INK, spaceAfter=0)
cover_app_style = ParagraphStyle("CoverApp", fontName="Arial-Bold", fontSize=26, textColor=colors.white, leading=30)
cover_sub_style = ParagraphStyle("CoverSub", fontName="Arial", fontSize=13, textColor=colors.HexColor("#F2C89A"), spaceBefore=6)
cover_ver_style = ParagraphStyle("CoverVer", fontName="Arial", fontSize=10, textColor=colors.HexColor("#C7CBD1"), spaceBefore=4)
caption_style = ParagraphStyle("Caption", fontName="Arial-Italic", fontSize=8.5, textColor=MUTED, spaceBefore=3, spaceAfter=10, alignment=1)

# Capturi reale (2026-08-29, la cererea explicita a lui Cristi: "aspect
# profesional, vizual" — ghidul vechi era text simplu, fara nicio imagine
# a aplicatiei reale). Toate 4 din aceeasi sesiune, Mac, tema Intunecata
# (cea mai lizibila in tipar, contrast bun cu accentul amber al brandului).
MAX_IMG_W = 16.5 * cm


def screenshot(filename, caption_text):
    """Image flowable scalata proportional la latimea continutului + o
    legenda mica italic dedesubt. Daca fisierul lipseste (build pe alta
    masina, fara capturile locale), sare peste — ghidul tot se genereaza,
    doar fara acea imagine, in loc sa pice cu FileNotFoundError."""
    path = os.path.join(SCREENSHOTS_DIR, filename)
    if not os.path.exists(path):
        return []
    with PILImage.open(path) as im:
        w, h = im.size
    # Nu upscalam peste rezolutia nativa (ex. dialogul de Setari, 532px
    # latime) doar ca sa umplem latimea paginii — ar iesi vizibil neclar la
    # print. Tinta ~150dpi echivalent, plafonata la latimea continutului.
    native_w = w * 2.54 / 150 * cm
    target_w = min(MAX_IMG_W, native_w)
    scaled_h = target_w * h / w
    img = Image(path, width=target_w, height=scaled_h)
    img.hAlign = "CENTER"
    return [img, Paragraph(caption_text, caption_style)]


def numbered(items):
    return ListFlowable(
        [ListItem(Paragraph(it, step_style), leftIndent=16) for it in items],
        bulletType="1", start="1", leftIndent=16, spaceBefore=2, spaceAfter=6,
    )


def h3(text):
    return Paragraph(text, h3_style)


def note_box(label, text):
    """Caseta evidentiata (fundal amber deschis, bara stanga plina) pentru
    un punct cheie — 'Sfat'/'Important'/'Tip'/'Nota', dupa limba. Table cu
    o singura celula, nu un Flowable custom — mai simplu, la fel de robust."""
    p = Paragraph(f"<b>{label}</b> {text}", note_style)
    t = Table([[p]], colWidths=[16.5 * cm])
    t.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), ACCENT_LIGHT),
        ("BOX", (0, 0), (-1, -1), 0, ACCENT_LIGHT),
        ("LINEBEFORE", (0, 0), (0, -1), 3, ACCENT),
        ("LEFTPADDING", (0, 0), (-1, -1), 12),
        ("RIGHTPADDING", (0, 0), (-1, -1), 10),
        ("TOPPADDING", (0, 0), (-1, -1), 8),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 8),
    ]))
    return t


def _cover_canvas(canvas, doc, cover_texts):
    canvas.saveState()
    w, h = A4
    band_h = 8.5 * cm
    canvas.setFillColor(INK_DARK)
    canvas.rect(0, h - band_h, w, band_h, fill=1, stroke=0)
    canvas.setFillColor(ACCENT)
    canvas.rect(0, h - band_h - 0.18 * cm, w, 0.18 * cm, fill=1, stroke=0)
    canvas.restoreState()


def _content_canvas(canvas, doc, footer_text):
    canvas.saveState()
    w, h = A4
    canvas.setFillColor(ACCENT)
    canvas.rect(0, h - 0.4 * cm, w, 0.4 * cm, fill=1, stroke=0)
    canvas.setFont("Arial", 8)
    canvas.setFillColor(MUTED)
    canvas.drawString(2 * cm, 1.2 * cm, footer_text)
    canvas.drawRightString(w - 2 * cm, 1.2 * cm, f"{canvas.getPageNumber()}")
    canvas.restoreState()


def build(lang, out_path, d):
    doc = SimpleDocTemplate(out_path, pagesize=A4, leftMargin=2 * cm, rightMargin=2 * cm, topMargin=2 * cm, bottomMargin=2 * cm)
    flow = [
        Spacer(1, 3.4 * cm),
        Paragraph("GDC Plugin Manager", cover_app_style),
        Paragraph(d["cover_subtitle"], cover_sub_style),
        Spacer(1, 3.2 * cm),
        Paragraph(f"{d['cover_version_label']} {APP_VERSION}", cover_ver_style),
        Paragraph(d["cover_lang_label"], cover_ver_style),
        PageBreak(),
        Paragraph(d["title"], title_style),
    ]
    for h, body in d["sections"]:
        flow.append(Paragraph(h, h2_style))
        if isinstance(body, list):
            for item in body:
                if isinstance(item, tuple) and len(item) == 2 and item[0] == "__note__":
                    flow.append(note_box(item[1][0], item[1][1]))
                elif isinstance(item, tuple) and len(item) == 2 and item[0] == "__img__":
                    flow.extend(screenshot(item[1][0], item[1][1]))
                elif isinstance(item, tuple):
                    flow.append(h3(item[0]))
                    flow.append(numbered(item[1]))
                else:
                    flow.append(Paragraph(item, body_style))
        else:
            flow.append(Paragraph(body, body_style))

    def on_first(canvas, doc_):
        _cover_canvas(canvas, doc_, d)

    def on_later(canvas, doc_):
        _content_canvas(canvas, doc_, d["footer"])

    doc.build(flow, onFirstPage=on_first, onLaterPages=on_later)
    print("wrote", out_path)


RO = dict(
    cover_subtitle="Ghid complet de utilizare",
    cover_version_label="Versiunea",
    cover_lang_label="Română",
    footer="GDC Plugin Manager — Ghid de utilizare",
    title="Ghid de utilizare — GDC Plugin Manager",
    sections=[
        ("1. Ce este GDC Plugin Manager",
         [
             "Aplicație GRATUITĂ pentru Mac și Windows — catalog unic pentru tot ce oferă GDC: plugin-uri și preseturi pentru DaVinci Resolve (instalare automată), resurse de descărcare directă pentru Premiere/Final Cut/Resolve, cursuri, materiale educaționale, evenimente, magazine și service-uri partenere, plus celelalte aplicații GDC. Toate produsele proprii GDC se deblochează printr-o donație unică, niciodată printr-un abonament.",
             ("__img__", ("main-window.png", "Fereastra principală — bara laterală grupată pe secțiuni, catalogul de evenimente")),
         ]),
        ("2. Căutare globală",
         "Bara de căutare din partea de sus a ferestrei caută simultan în TOATE rubricile aplicației (produse, resurse, cursuri, evenimente, magazine, service) — nu trebuie să știi dinainte în ce secțiune se află ceva. Tastează orice — nume, tip, descriere — și rezultatele din toate categoriile apar sub bara de căutare. Câmpul reține și ultimele căutări, ca sugestii rapide."),
        ("3. Instalare produse pentru DaVinci Resolve",
         [
             "Secțiunile DCTL / LUT / Fuse / PowerGrade / OFX din bara laterală conțin plugin-uri care se instalează AUTOMAT, direct în folderele pe care DaVinci Resolve le citește la pornire. Apasă „Instalează” pe orice card — nu trebuie să cauți foldere sau să copiezi fișiere manual. La actualizare, apasă din nou „Instalează” — versiunea nouă suprascrie automat cea veche.",
             ("__img__", ("plugins-grid.png", "Cardul unui produs — status Gratuit/Licență, buton Instalează/Donează")),
         ]),
        ("4. Resurse Download (Premiere, Final Cut, Resolve)",
         [
             "Secțiunea „RESURSE DOWNLOAD” din bara laterală (LUT-uri, Efecte Audio/SFX, VFX/Overlays, Plugin-uri, Audio) conține fișiere care se DESCARCĂ direct, fără instalare automată — pentru că sunt gândite să funcționeze și în alte aplicații de montaj (Premiere, Final Cut), nu doar în Resolve.",
             ("__note__", ("Notă:", "după ce descarci o resursă, aplicația îți oferă un buton „Unde l-ai salvat?” — alegi folderul, iar aplicația reține calea, ca să găsești rapid fișierul mai târziu cu „Deschide folderul”.")),
         ]),
        ("5. Comunitate & Educație",
         "Cursuri (rezervare directă prin WhatsApp, cu opțiuni de preț), Materiale educaționale (cărți/cursuri online/ghiduri recomandate, cu link extern), Evenimente (workshop-uri și festivaluri, cu buton de hartă dacă au adresă fizică), Magazine partenere și Service & Reparații (echipament foto-video) — toate în bara laterală, grupul „COMUNITATE & EDUCAȚIE”."),
        ("6. Aplicațiile Mele",
         "Detectează automat celelalte aplicații GDC deja instalate pe acest calculator (DataMover, CursorPro GDC, GDC Vault, MediaFlow Monitor) și le arată cu buton de lansare rapidă + indicator dacă există o versiune mai nouă. Poți adăuga și scurtături proprii către orice altă aplicație (ex. DaVinci Resolve, Premiere) cu „Adaugă scurtătură”."),
        ("7. Oferte Parteneri & Susținere promoțională",
         "„Oferte Parteneri” arată promoții temporare de la branduri terțe de echipament foto-video (nu produse GDC) — pot avea cod de cupon. Produsele proprii GDC pot avea, temporar, o sumă de „Susținere promoțională” mai mică decât cea obișnuită (ex. de Black Friday) — rămâne tot o donație, afișată cu suma veche tăiată."),
        ("8. Pachete / Bundle-uri",
         "Combinații de produse GDC (plugin-uri, resurse, cursuri, audio) la un preț total mai avantajos decât suma individuală a fiecărui produs. Lista completă de produse incluse e vizibilă direct pe cardul pachetului."),
        ("9. Donație și activare",
         "Alege un produs din catalog, apasă „Donează”, apoi introdu codul serial primit în secțiunea Licență. Fiecare produs se activează separat, o singură dată, pe acest calculator."),
        ("10. PowerGrade-uri",
         "Se importă automat în Galeria Resolve dacă aplicația e deschisă. Dacă nu, urmează instrucțiunile afișate."),
        ("11. Machine ID",
         "Codurile licențiate pe o singură mașină folosesc un identificator hardware unic, afișat în secțiunea Licență — trimite-l când ceri activarea unui produs."),
        ("12. Temă și Mărime Text",
         [
             "Din Preferences (⌘,) pe Mac, sau butonul „Setări” din josul barei laterale pe Windows, poți alege limba (Română/English/Español), tema aplicației — Sistem, Luminoasă sau Întunecată — independent de setarea sistemului, și mărimea textului — Mic, Normal, Mare sau Foarte mare. Toate se aplică instant, fără repornire.",
             ("__img__", ("settings.png", "Fereastra de Setări — limbă, temă, mărime text, verificare actualizări")),
         ]),
        ("13. Actualizări automate", [
            "Aplicația verifică automat, la fiecare lansare, dacă există o versiune mai nouă (poți verifica și manual din meniu: GDC Plugin Manager → Check for Updates...).",
            ("Ce se întâmplă când există o versiune nouă:", [
                "Apare o fereastră pop-up cu numărul versiunii și un scurt rezumat al noutăților (\"Noutăți\").",
                "Butonul „Actualizează acum” deschide direct pagina de descărcare a noului pachet — trebuie să-l descarci și să-l instalezi peste versiunea curentă (nu e o actualizare automată în fundal; aplicația nu-și poate înlocui singură propriile fișiere cât timp rulează).",
                "Butonul „Mai târziu” închide fereastra — vei fi reamintit din nou la o versiune viitoare, nu la fiecare pornire pentru aceeași versiune deja respinsă.",
            ]),
        ]),
        ("14. Panoul de Dependențe (indicatorul roșu/verde)", [
            "În partea de sus a ferestrei aplicației vezi un mic punct colorat, urmat de un text scurt („Sistem pregătit” sau „Necesită atenție”). Acesta îți spune dacă tot ce ai nevoie pentru DaVinci Resolve e prezent pe acest calculator.",
            ("<font color=\"#D32F2F\">●</font> Punct roșu — „Necesită atenție”", [
                "Înseamnă că lipsește o componentă OBLIGATORIE (DaVinci Resolve însuși, sau — pe Windows — Visual C++ Redistributable). Fără ele, instalarea de pluginuri nu are unde să scrie fișierele.",
            ]),
            ("<font color=\"#2E7D32\">●</font> Punct verde — „Sistem pregătit”", [
                "Înseamnă că tot ce e obligatoriu e prezent — poți instala orice produs din catalog fără probleme.",
            ]),
            ("Ce faci exact când vezi punctul roșu:", [
                "Dă click pe indicatorul din partea de sus a ferestrei. Se deschide o fereastră nouă, numită „Verificare & Dependențe Sistem”.",
                "În această fereastră vezi o listă cu componente, fiecare cu propriul punct colorat. O componentă lipsă are, lângă ea, un buton „Instalează...”.",
                "Apasă acel buton — se deschide pagina oficială de descărcare a componentei lipsă (de exemplu DaVinci Resolve, de pe site-ul Blackmagic Design). Aplicația NU instalează nimic automat aici — DaVinci Resolve e ~5 GB și cere acceptarea unui acord de licență propriu, deci descărcarea și instalarea rămân pasul tău.",
                "După ce ai instalat componenta lipsă, revino în panou și apasă „Reverifică tot” — punctul ar trebui să devină verde.",
            ]),
            "Componentele marcate „Opțional” (foldere LUT/DCTL/OFX/Fusion, sau Scripting API pentru PowerGrade) NU blochează nimic — apar automat la prima instalare a unui produs de tipul respectiv, sau doar fac importul de PowerGrade automat în loc de manual.",
            ("__img__", ("dependency-check.png", "Fereastra „Verificare & Dependențe Sistem” — toate componentele OK")),
        ]),
        ("15. Aplicația pentru telefon (Android și iPhone)",
         "Deschide gordas.dev de pe telefon — catalogul complet (produse, resurse, cursuri, evenimente, comunitate) e disponibil direct în browser, fără instalare din magazinul de aplicații. Din meniul browserului alege „Adaugă pe ecranul principal” pentru o iconiță ca o aplicație obișnuită."),
        ("16. Suport", "Pentru orice problemă, folosește butonul de contact din aplicație (WhatsApp)."),
    ],
)

EN = dict(
    cover_subtitle="Complete User Guide",
    cover_version_label="Version",
    cover_lang_label="English",
    footer="GDC Plugin Manager — User Guide",
    title="User Guide — GDC Plugin Manager",
    sections=[
        ("1. What is GDC Plugin Manager",
         [
             "A FREE app for Mac and Windows — a single catalog for everything GDC offers: plugins and presets for DaVinci Resolve (automatic install), direct-download resources for Premiere/Final Cut/Resolve, courses, learning materials, events, partner stores and service centers, plus the other GDC apps. Every GDC product unlocks through a one-time donation, never a subscription.",
             ("__img__", ("main-window.png", "Main window — sidebar grouped by section, the events catalog")),
         ]),
        ("2. Global search",
         "The search bar at the top of the window searches ALL sections of the app at once (products, resources, courses, events, stores, services) — you don't need to know in advance where something lives. Type anything — a name, a type, a description — and results from every category appear below the search bar. The field also remembers your recent searches as quick suggestions."),
        ("3. Installing products for DaVinci Resolve",
         [
             "The DCTL / LUT / Fuse / PowerGrade / OFX sections in the sidebar contain plugins that install AUTOMATICALLY, straight into the folders DaVinci Resolve reads at launch. Press \"Install\" on any card — no folder hunting, no manual file copying. To update, press \"Install\" again — the new version overwrites the old one automatically.",
             ("__img__", ("plugins-grid.png", "A product card — Free/Licensed status, Install/Donate button")),
         ]),
        ("4. Downloadable Resources (Premiere, Final Cut, Resolve)",
         [
             "The \"DOWNLOADABLE RESOURCES\" section in the sidebar (LUTs, Audio Effects/SFX, VFX/Overlays, Plugins, Audio) contains files you DOWNLOAD directly, with no automatic install — because they're meant to work in other editing apps too (Premiere, Final Cut), not just Resolve.",
             ("__note__", ("Note:", "after downloading a resource, the app offers a \"Where did you save it?\" button — pick the folder, and the app remembers the path so you can find the file quickly later with \"Open folder\".")),
         ]),
        ("5. Community & Education",
         "Courses (booked directly via WhatsApp, with price options), Learning materials (recommended books/online courses/guides, with an external link), Events (workshops and festivals, with a map button if a physical address is set), Partner stores and Service & Repair (photo/video gear) — all in the sidebar, under the \"COMMUNITY & EDUCATION\" group."),
        ("6. My Apps",
         "Automatically detects the other GDC apps already installed on this computer (DataMover, CursorPro GDC, GDC Vault, MediaFlow Monitor) and shows them with a quick-launch button plus an indicator if a newer version exists. You can also add your own shortcuts to any other app (e.g. DaVinci Resolve, Premiere) with \"Add shortcut\"."),
        ("7. Partner Offers & Promotional Support",
         "\"Partner Offers\" shows temporary promotions from third-party photo/video gear brands (not GDC products) — some include a coupon code. GDC's own products may temporarily carry a lower \"Promotional support\" amount than usual (e.g. for Black Friday) — it's still a donation, shown with the old amount struck through."),
        ("8. Bundles",
         "Combinations of GDC products (plugins, resources, courses, audio) at a better total price than buying each item separately. The full list of included products is visible right on the bundle's card."),
        ("9. Purchase and activation",
         "Pick a product from the catalog, click \"Buy\", then enter the received serial code in the License section. Each product is activated separately, once, on this computer."),
        ("10. PowerGrades",
         "Automatically imported into Resolve's Gallery if the app is open. If not, follow the on-screen instructions."),
        ("11. Machine ID",
         "Machine-locked codes use a unique hardware identifier, shown in the License section — send it when requesting activation of a product."),
        ("12. Theme and Text Size",
         [
             "From Preferences (⌘,) on Mac, or the \"Settings\" button at the bottom of the sidebar on Windows, you can pick the language (Română/English/Español), the app's theme — System, Light or Dark — independently of your system setting, and the text size — Small, Normal, Large or Extra large. All apply instantly, no restart needed.",
             ("__img__", ("settings.png", "Settings window — language, theme, text size, update check")),
         ]),
        ("13. Automatic updates", [
            "The app checks automatically, at every launch, whether a newer version exists (you can also check manually from the menu: GDC Plugin Manager → Check for Updates...).",
            ("What happens when a new version exists:", [
                "A pop-up window appears with the version number and a short summary of what's new (\"What's new\").",
                "The \"Update now\" button opens directly the download page for the new package — you need to download and install it over the current version (this is not a silent background update; the app cannot replace its own files while running).",
                "The \"Later\" button closes the window — you'll be reminded again on a future version, not at every launch for the same already-dismissed version.",
            ]),
        ]),
        ("14. Dependency Panel (the red/green indicator)", [
            "At the top of the app window you'll see a small colored dot followed by a short label (“System ready” or “Needs attention”). It tells you whether everything DaVinci Resolve needs is present on this computer.",
            ("<font color=\"#D32F2F\">●</font> Red dot — “Needs attention”", [
                "Means a REQUIRED component is missing (DaVinci Resolve itself, or — on Windows — the Visual C++ Redistributable). Without them, plugin installs have nowhere to write their files.",
            ]),
            ("<font color=\"#2E7D32\">●</font> Green dot — “System ready”", [
                "Means everything required is present — you can install any product from the catalog without issues.",
            ]),
            ("Exactly what to do when you see the red dot:", [
                "Click the indicator at the top of the window. A new window opens, called “System Check & Dependencies”.",
                "In this window you'll see a list of components, each with its own colored dot. A missing component shows an “Install...” button next to it.",
                "Press that button — it opens the official download page for the missing component (e.g. DaVinci Resolve, on the Blackmagic Design site). The app does NOT install anything automatically here — DaVinci Resolve is ~5 GB and requires accepting its own license agreement, so downloading and installing stays your step.",
                "After installing the missing component, go back to the panel and press “Recheck all” — the dot should turn green.",
            ]),
            "Components marked “Optional” (LUT/DCTL/OFX/Fusion folders, or the Scripting API for PowerGrade) don't block anything — they appear automatically on the first install of that product type, or just make PowerGrade import automatic instead of manual.",
            ("__img__", ("dependency-check.png", "The “System Check & Dependencies” window — everything OK")),
        ]),
        ("15. Phone app (Android and iPhone)",
         "Open gordas.dev on your phone — the full catalog (products, resources, courses, events, community) is available directly in the browser, no app-store install needed. From the browser menu, choose \"Add to Home Screen\" for an icon that behaves like a regular app."),
        ("16. Support", "For any issue, use the contact button in the app (WhatsApp)."),
    ],
)

ES = dict(
    cover_subtitle="Guía completa de uso",
    cover_version_label="Versión",
    cover_lang_label="Español",
    footer="GDC Plugin Manager — Guía de uso",
    title="Guía de uso — GDC Plugin Manager",
    sections=[
        ("1. Qué es GDC Plugin Manager",
         [
             "Aplicación GRATUITA para Mac y Windows — catálogo único para todo lo que ofrece GDC: plugins y preajustes para DaVinci Resolve (instalación automática), recursos de descarga directa para Premiere/Final Cut/Resolve, cursos, materiales educativos, eventos, tiendas y servicios asociados, además de las demás apps de GDC. Todos los productos propios de GDC se desbloquean con una donación única, nunca con una suscripción.",
             ("__img__", ("main-window.png", "Ventana principal — barra lateral agrupada por sección, el catálogo de eventos")),
         ]),
        ("2. Búsqueda global",
         "La barra de búsqueda en la parte superior de la ventana busca simultáneamente en TODAS las secciones de la app (productos, recursos, cursos, eventos, tiendas, servicios) — no necesitas saber de antemano dónde está algo. Escribe cualquier cosa — un nombre, un tipo, una descripción — y aparecen resultados de todas las categorías debajo de la barra de búsqueda. El campo también recuerda tus búsquedas recientes como sugerencias rápidas."),
        ("3. Instalación de productos para DaVinci Resolve",
         [
             "Las secciones DCTL / LUT / Fuse / PowerGrade / OFX de la barra lateral contienen plugins que se instalan AUTOMÁTICAMENTE, directamente en las carpetas que DaVinci Resolve lee al iniciar. Pulsa \"Instalar\" en cualquier tarjeta — sin buscar carpetas ni copiar archivos a mano. Para actualizar, pulsa \"Instalar\" de nuevo — la versión nueva sobrescribe automáticamente la anterior.",
             ("__img__", ("plugins-grid.png", "Tarjeta de un producto — estado Gratis/Licencia, botón Instalar/Donar")),
         ]),
        ("4. Recursos Descargables (Premiere, Final Cut, Resolve)",
         [
             "La sección \"RECURSOS DESCARGABLES\" de la barra lateral (LUTs, Efectos de Audio/SFX, VFX/Overlays, Plugins, Audio) contiene archivos que se DESCARGAN directamente, sin instalación automática — porque están pensados para funcionar también en otras apps de edición (Premiere, Final Cut), no solo en Resolve.",
             ("__note__", ("Nota:", "después de descargar un recurso, la app ofrece un botón \"¿Dónde lo guardaste?\" — eliges la carpeta, y la app recuerda la ruta para que encuentres el archivo rápidamente después con \"Abrir carpeta\".")),
         ]),
        ("5. Comunidad y Educación",
         "Cursos (reserva directa por WhatsApp, con opciones de precio), Materiales educativos (libros/cursos online/guías recomendadas, con enlace externo), Eventos (talleres y festivales, con botón de mapa si tienen dirección física), Tiendas asociadas y Servicio y Reparación (equipo foto/video) — todo en la barra lateral, en el grupo \"COMUNIDAD Y EDUCACIÓN\"."),
        ("6. Mis Aplicaciones",
         "Detecta automáticamente las demás apps de GDC ya instaladas en este ordenador (DataMover, CursorPro GDC, GDC Vault, MediaFlow Monitor) y las muestra con un botón de acceso rápido más un indicador si existe una versión más nueva. También puedes añadir tus propios accesos directos a cualquier otra app (p. ej. DaVinci Resolve, Premiere) con \"Añadir acceso directo\"."),
        ("7. Ofertas de Socios y Apoyo promocional",
         "\"Ofertas de Socios\" muestra promociones temporales de marcas de equipo foto/video de terceros (no productos GDC) — algunas incluyen un código de cupón. Los productos propios de GDC pueden tener, temporalmente, un importe de \"Apoyo promocional\" menor que el habitual (p. ej. en Black Friday) — sigue siendo una donación, mostrada con el importe anterior tachado."),
        ("8. Paquetes",
         "Combinaciones de productos GDC (plugins, recursos, cursos, audio) a un precio total más ventajoso que comprar cada elemento por separado. La lista completa de productos incluidos es visible directamente en la tarjeta del paquete."),
        ("9. Compra y activación",
         "Elige un producto del catálogo, pulsa \"Comprar\" e introduce el código serial recibido en la sección Licencia. Cada producto se activa por separado, una sola vez, en este ordenador."),
        ("10. PowerGrades",
         "Se importan automáticamente en la Galería de Resolve si la aplicación está abierta. Si no, sigue las instrucciones en pantalla."),
        ("11. Machine ID",
         "Los códigos vinculados a una máquina usan un identificador de hardware único, mostrado en la sección Licencia — envíalo al solicitar la activación de un producto."),
        ("12. Tema y Tamaño de texto",
         [
             "Desde Preferencias (⌘,) en Mac, o el botón \"Ajustes\" en la parte inferior de la barra lateral en Windows, puedes elegir el idioma (Română/English/Español), el tema de la app — Sistema, Claro u Oscuro — independientemente de tu ajuste del sistema, y el tamaño del texto — Pequeño, Normal, Grande o Muy grande. Todo se aplica al instante, sin reiniciar.",
             ("__img__", ("settings.png", "Ventana de Ajustes — idioma, tema, tamaño de texto, verificación de actualizaciones")),
         ]),
        ("13. Actualizaciones automáticas", [
            "La aplicación verifica automáticamente, en cada inicio, si existe una versión más nueva (también puedes verificar manualmente desde el menú: GDC Plugin Manager → Check for Updates...).",
            ("Qué ocurre cuando existe una versión nueva:", [
                "Aparece una ventana emergente con el número de versión y un breve resumen de las novedades (\"Novedades\").",
                "El botón \"Actualizar ahora\" abre directamente la página de descarga del nuevo paquete — debes descargarlo e instalarlo sobre la versión actual (no es una actualización silenciosa en segundo plano; la app no puede reemplazar sus propios archivos mientras se ejecuta).",
                "El botón \"Más tarde\" cierra la ventana — se te recordará de nuevo en una versión futura, no en cada inicio para la misma versión ya descartada.",
            ]),
        ]),
        ("14. Panel de Dependencias (el indicador rojo/verde)", [
            "En la parte superior de la ventana de la app verás un pequeño punto de color seguido de un texto breve (“Sistema listo” o “Requiere atención”). Te indica si todo lo que DaVinci Resolve necesita está presente en este ordenador.",
            ("<font color=\"#D32F2F\">●</font> Punto rojo — “Requiere atención”", [
                "Significa que falta un componente OBLIGATORIO (DaVinci Resolve en sí, o — en Windows — Visual C++ Redistributable). Sin ellos, la instalación de plugins no tiene dónde escribir los archivos.",
            ]),
            ("<font color=\"#2E7D32\">●</font> Punto verde — “Sistema listo”", [
                "Significa que todo lo obligatorio está presente — puedes instalar cualquier producto del catálogo sin problemas.",
            ]),
            ("Qué hacer exactamente cuando ves el punto rojo:", [
                "Haz clic en el indicador en la parte superior de la ventana. Se abre una ventana nueva llamada “Comprobación y Dependencias del Sistema”.",
                "En esta ventana verás una lista de componentes, cada uno con su propio punto de color. Un componente faltante muestra un botón “Instalar...” junto a él.",
                "Pulsa ese botón — se abre la página oficial de descarga del componente faltante (por ejemplo DaVinci Resolve, en el sitio de Blackmagic Design). La app NO instala nada automáticamente aquí — DaVinci Resolve pesa ~5 GB y requiere aceptar su propio acuerdo de licencia, así que descargar e instalar sigue siendo tu paso.",
                "Después de instalar el componente faltante, vuelve al panel y pulsa “Volver a verificar todo” — el punto debería ponerse verde.",
            ]),
            "Los componentes marcados “Opcional” (carpetas LUT/DCTL/OFX/Fusion, o la API de scripting para PowerGrade) no bloquean nada — aparecen automáticamente en la primera instalación de ese tipo de producto, o simplemente hacen que la importación de PowerGrade sea automática en vez de manual.",
            ("__img__", ("dependency-check.png", "La ventana “Comprobación y Dependencias del Sistema” — todo OK")),
        ]),
        ("15. App para el teléfono (Android e iPhone)",
         "Abre gordas.dev en tu teléfono — el catálogo completo (productos, recursos, cursos, eventos, comunidad) está disponible directamente en el navegador, sin instalación desde una tienda de apps. Desde el menú del navegador, elige \"Añadir a pantalla de inicio\" para tener un icono que se comporta como una app normal."),
        ("16. Soporte", "Para cualquier problema, usa el botón de contacto en la aplicación (WhatsApp)."),
    ],
)

if __name__ == "__main__":
    build("ro", os.path.join(OUT_DIR, "Ghid-GDCPluginManager-ro.pdf"), RO)
    build("en", os.path.join(OUT_DIR, "Ghid-GDCPluginManager-en.pdf"), EN)
    build("es", os.path.join(OUT_DIR, "Ghid-GDCPluginManager-es.pdf"), ES)
