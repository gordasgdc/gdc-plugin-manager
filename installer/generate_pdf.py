# Genereaza Ghid-GDCPluginManager-{ro,en,es}.pdf, cu reportlab. Foloseste
# Arial (nu Helvetica standard-14) pentru diacriticele romanesti (s-comma,
# t-comma) — WinAnsiEncoding-ul fonturilor PDF standard nu are glyph-uri
# pentru ele, ies ca patrate goale fara font TTF embedat.
#
# STANDARD (CLAUDE.md, Partea 1, Regula 8): sectiunea de Dependinte redactata
# ultra-detaliat, pas-cu-pas, zero presupuneri — ce inseamna 🔴/🟢, unde da
# clic userul, ce se deschide, ce buton apasa.
#
# Continutul sectiunilor 1-6 si 8 e portat identic din PDF-urile anterioare
# (verificat prin extragere text inainte de rescriere) — DOAR sectiunea 7
# (Dependinte de sistem) e rescrisa complet dupa noul standard.
#
# Ruleaza cu: python3 installer/generate_pdf.py
# (necesita `pip install reportlab` intr-un venv)
import os
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import cm
from reportlab.lib import colors
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import SimpleDocTemplate, Paragraph, ListFlowable, ListItem

OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Sources", "GDCPluginManager", "Resources")

pdfmetrics.registerFont(TTFont("Arial", "/System/Library/Fonts/Supplemental/Arial.ttf"))
pdfmetrics.registerFont(TTFont("Arial-Bold", "/System/Library/Fonts/Supplemental/Arial Bold.ttf"))
styles = getSampleStyleSheet()
ACCENT = colors.HexColor("#B96A1E")
MUTED = colors.HexColor("#6a6a6a")

title_style = ParagraphStyle("Title", parent=styles["Title"], fontName="Arial-Bold", fontSize=17, spaceAfter=14, textColor=colors.HexColor("#1a1a1a"))
h2_style = ParagraphStyle("H2", parent=styles["Heading2"], fontName="Arial-Bold", fontSize=12.5, textColor=ACCENT, spaceBefore=12, spaceAfter=5)
h3_style = ParagraphStyle("H3", parent=styles["Heading3"], fontName="Arial-Bold", fontSize=10.5, textColor=colors.HexColor("#1a1a1a"), spaceBefore=6, spaceAfter=2)
body_style = ParagraphStyle("Body", parent=styles["Normal"], fontName="Arial", fontSize=10, leading=14, textColor=colors.HexColor("#1a1a1a"), spaceAfter=5)
step_style = ParagraphStyle("Step", parent=body_style, leftIndent=4, spaceAfter=4)


def numbered(items):
    return ListFlowable(
        [ListItem(Paragraph(it, step_style), leftIndent=16) for it in items],
        bulletType="1", start="1", leftIndent=16, spaceBefore=2, spaceAfter=6,
    )


def h3(text):
    return Paragraph(text, h3_style)


def build(lang, out_path, d):
    doc = SimpleDocTemplate(out_path, pagesize=A4, leftMargin=2 * cm, rightMargin=2 * cm, topMargin=2 * cm, bottomMargin=2 * cm)
    flow = [Paragraph(d["title"], title_style)]
    for h, body in d["sections"]:
        flow.append(Paragraph(h, h2_style))
        if isinstance(body, list):
            for item in body:
                if isinstance(item, tuple):
                    flow.append(h3(item[0]))
                    flow.append(numbered(item[1]))
                else:
                    flow.append(Paragraph(item, body_style))
        else:
            flow.append(Paragraph(body, body_style))
    doc.build(flow)
    print("wrote", out_path)


RO = dict(
    title="Ghid de utilizare — GDC Plugin Manager",
    sections=[
        ("1. Ce este GDC Plugin Manager", "Aplicație GRATUITĂ pentru instalarea, actualizarea și licențierea produselor GDC (LUT-uri, DCTL-uri, PowerGrade-uri, plugin-uri OFX și Fuse) pentru DaVinci Resolve."),
        ("2. Donație și activare", "Alege un produs din catalog, apasă „Donează”, apoi introdu codul serial primit în secțiunea Licență."),
        ("3. Instalare produse", "Apasă „Instalează” pe orice card din catalog. Aplicația copiază fișierele direct în folderele corecte pentru DaVinci Resolve."),
        ("4. PowerGrade-uri", "Se importă automat în Galeria Resolve dacă aplicația e deschisă. Dacă nu, urmează instrucțiunile afișate."),
        ("5. Machine ID", "Codurile licențiate pe o singură mașină folosesc un identificator hardware unic, afișat în secțiunea Licență."),
        ("6. Actualizări automate", [
            "Aplicația verifică automat, la fiecare lansare, dacă există o versiune mai nouă (poți verifica și manual din meniu: GDC Plugin Manager → Check for Updates...).",
            ("Ce se întâmplă când există o versiune nouă:", [
                "Apare o fereastră pop-up cu numărul versiunii și un scurt rezumat al noutăților (\"Noutăți\").",
                "Butonul „Actualizează acum” deschide direct pagina de descărcare a noului pachet — trebuie să-l descarci și să-l instalezi peste versiunea curentă (nu e o actualizare automată în fundal; aplicația nu-și poate înlocui singură propriile fișiere cât timp rulează).",
                "Butonul „Mai târziu” închide fereastra — vei fi reamintit din nou la o versiune viitoare, nu la fiecare pornire pentru aceeași versiune deja respinsă.",
            ]),
        ]),
        ("7. Panoul de Dependențe (indicatorul roșu/verde)", [
            "În partea de sus a ferestrei aplicației vezi un mic punct colorat, urmat de un text scurt („Sistem pregătit” sau „Necesită atenție”). Acesta îți spune dacă tot ce ai nevoie pentru DaVinci Resolve e prezent pe acest calculator.",
            ("🔴 Punct roșu — „Necesită atenție”", [
                "Înseamnă că lipsește o componentă OBLIGATORIE (DaVinci Resolve însuși, sau — pe Windows — Visual C++ Redistributable). Fără ele, instalarea de pluginuri nu are unde să scrie fișierele.",
            ]),
            ("🟢 Punct verde — „Sistem pregătit”", [
                "Înseamnă că tot ce e obligatoriu e prezent — poți instala orice produs din catalog fără probleme.",
            ]),
            ("Ce faci exact când vezi punctul roșu:", [
                "Dă click pe indicatorul din partea de sus a ferestrei. Se deschide o fereastră nouă, numită „Verificare & Dependențe Sistem”.",
                "În această fereastră vezi o listă cu componente, fiecare cu propriul punct colorat. O componentă lipsă are, lângă ea, un buton „Instalează...”.",
                "Apasă acel buton — se deschide pagina oficială de descărcare a componentei lipsă (de exemplu DaVinci Resolve, de pe site-ul Blackmagic Design). Aplicația NU instalează nimic automat aici — DaVinci Resolve e ~5 GB și cere acceptarea unui acord de licență propriu, deci descărcarea și instalarea rămân pasul tău.",
                "După ce ai instalat componenta lipsă, revino în panou și apasă „Reverifică tot” — punctul ar trebui să devină verde.",
            ]),
            "Componentele marcate „Opțional” (foldere LUT/DCTL/OFX/Fusion, sau Scripting API pentru PowerGrade) NU blochează nimic — apar automat la prima instalare a unui produs de tipul respectiv, sau doar fac importul de PowerGrade automat în loc de manual.",
        ]),
        ("8. Suport", "Pentru orice problemă, folosește butonul de contact din aplicație."),
    ],
)

EN = dict(
    title="User Guide — GDC Plugin Manager",
    sections=[
        ("1. What is GDC Plugin Manager", "A FREE app for installing, updating, and licensing GDC products (LUTs, DCTLs, PowerGrades, OFX and Fuse plugins) for DaVinci Resolve."),
        ("2. Purchase and activation", "Pick a product from the catalog, click \"Buy\", then enter the received serial code in the License section."),
        ("3. Installing products", "Click \"Install\" on any catalog card. The app copies the files directly into the correct DaVinci Resolve folders."),
        ("4. PowerGrades", "Automatically imported into Resolve's Gallery if the app is open. If not, follow the on-screen instructions."),
        ("5. Machine ID", "Machine-locked codes use a unique hardware identifier, shown in the License section."),
        ("6. Automatic updates", [
            "The app checks automatically, at every launch, whether a newer version exists (you can also check manually from the menu: GDC Plugin Manager → Check for Updates...).",
            ("What happens when a new version exists:", [
                "A pop-up window appears with the version number and a short summary of what's new (\"What's new\").",
                "The \"Update now\" button opens directly the download page for the new package — you need to download and install it over the current version (this is not a silent background update; the app cannot replace its own files while running).",
                "The \"Later\" button closes the window — you'll be reminded again on a future version, not at every launch for the same already-dismissed version.",
            ]),
        ]),
        ("7. Dependency Panel (the red/green indicator)", [
            "At the top of the app window you'll see a small colored dot followed by a short label (“System ready” or “Needs attention”). It tells you whether everything DaVinci Resolve needs is present on this computer.",
            ("🔴 Red dot — “Needs attention”", [
                "Means a REQUIRED component is missing (DaVinci Resolve itself, or — on Windows — the Visual C++ Redistributable). Without them, plugin installs have nowhere to write their files.",
            ]),
            ("🟢 Green dot — “System ready”", [
                "Means everything required is present — you can install any product from the catalog without issues.",
            ]),
            ("Exactly what to do when you see the red dot:", [
                "Click the indicator at the top of the window. A new window opens, called “System Check & Dependencies”.",
                "In this window you'll see a list of components, each with its own colored dot. A missing component shows an “Install...” button next to it.",
                "Press that button — it opens the official download page for the missing component (e.g. DaVinci Resolve, on the Blackmagic Design site). The app does NOT install anything automatically here — DaVinci Resolve is ~5 GB and requires accepting its own license agreement, so downloading and installing stays your step.",
                "After installing the missing component, go back to the panel and press “Recheck all” — the dot should turn green.",
            ]),
            "Components marked “Optional” (LUT/DCTL/OFX/Fusion folders, or the Scripting API for PowerGrade) don't block anything — they appear automatically on the first install of that product type, or just make PowerGrade import automatic instead of manual.",
        ]),
        ("8. Support", "For issues, use the contact button in the app."),
    ],
)

ES = dict(
    title="Guía de uso — GDC Plugin Manager",
    sections=[
        ("1. Qué es GDC Plugin Manager", "Aplicación GRATUITA para instalar, actualizar y licenciar productos GDC (LUTs, DCTLs, PowerGrades, plugins OFX y Fuse) para DaVinci Resolve."),
        ("2. Compra y activación", "Elige un producto del catálogo, pulsa \"Comprar\" e introduce el código serial recibido en la sección Licencia."),
        ("3. Instalación de productos", "Pulsa \"Instalar\" en cualquier tarjeta del catálogo. La aplicación copia los archivos directamente en las carpetas correctas de DaVinci Resolve."),
        ("4. PowerGrades", "Se importan automáticamente en la Galería de Resolve si la aplicación está abierta. Si no, sigue las instrucciones en pantalla."),
        ("5. Machine ID", "Los códigos vinculados a una máquina usan un identificador de hardware único, mostrado en la sección Licencia."),
        ("6. Actualizaciones automáticas", [
            "La aplicación verifica automáticamente, en cada inicio, si existe una versión más nueva (también puedes verificar manualmente desde el menú: GDC Plugin Manager → Check for Updates...).",
            ("Qué ocurre cuando existe una versión nueva:", [
                "Aparece una ventana emergente con el número de versión y un breve resumen de las novedades (\"Novedades\").",
                "El botón \"Actualizar ahora\" abre directamente la página de descarga del nuevo paquete — debes descargarlo e instalarlo sobre la versión actual (no es una actualización silenciosa en segundo plano; la app no puede reemplazar sus propios archivos mientras se ejecuta).",
                "El botón \"Más tarde\" cierra la ventana — se te recordará de nuevo en una versión futura, no en cada inicio para la misma versión ya descartada.",
            ]),
        ]),
        ("7. Panel de Dependencias (el indicador rojo/verde)", [
            "En la parte superior de la ventana de la app verás un pequeño punto de color seguido de un texto breve (“Sistema listo” o “Requiere atención”). Te indica si todo lo que DaVinci Resolve necesita está presente en este ordenador.",
            ("🔴 Punto rojo — “Requiere atención”", [
                "Significa que falta un componente OBLIGATORIO (DaVinci Resolve en sí, o — en Windows — Visual C++ Redistributable). Sin ellos, la instalación de plugins no tiene dónde escribir los archivos.",
            ]),
            ("🟢 Punto verde — “Sistema listo”", [
                "Significa que todo lo obligatorio está presente — puedes instalar cualquier producto del catálogo sin problemas.",
            ]),
            ("Qué hacer exactamente cuando ves el punto rojo:", [
                "Haz clic en el indicador en la parte superior de la ventana. Se abre una ventana nueva llamada “Comprobación y Dependencias del Sistema”.",
                "En esta ventana verás una lista de componentes, cada uno con su propio punto de color. Un componente faltante muestra un botón “Instalar...” junto a él.",
                "Pulsa ese botón — se abre la página oficial de descarga del componente faltante (por ejemplo DaVinci Resolve, en el sitio de Blackmagic Design). La app NO instala nada automáticamente aquí — DaVinci Resolve pesa ~5 GB y requiere aceptar su propio acuerdo de licencia, así que descargar e instalar sigue siendo tu paso.",
                "Después de instalar el componente faltante, vuelve al panel y pulsa “Volver a verificar todo” — el punto debería ponerse verde.",
            ]),
            "Los componentes marcados “Opcional” (carpetas LUT/DCTL/OFX/Fusion, o la API de scripting para PowerGrade) no bloquean nada — aparecen automáticamente en la primera instalación de ese tipo de producto, o simplemente hacen que la importación de PowerGrade sea automática en vez de manual.",
        ]),
        ("8. Soporte", "Para cualquier problema, usa el botón de contacto en la aplicación."),
    ],
)

if __name__ == "__main__":
    build("ro", os.path.join(OUT_DIR, "Ghid-GDCPluginManager-ro.pdf"), RO)
    build("en", os.path.join(OUT_DIR, "Ghid-GDCPluginManager-en.pdf"), EN)
    build("es", os.path.join(OUT_DIR, "Ghid-GDCPluginManager-es.pdf"), ES)
