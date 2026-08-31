#!/usr/bin/env python3
"""
Genereaza cele 3 fisiere HTML sursa (RO/EN/ES) pentru ghidurile PDF ale
GDC Production Manager, folosind acelasi sablon vizual ca versiunea
anterioara (titlu, sectiuni numerotate cu antet portocaliu, casete
"Nota"), dar actualizate cu tot ce s-a schimbat: trial + licenta
lifetime, recuperare parola, Touch ID/Windows Hello, pagina de Ajutor
din aplicatie, verificare actualizari, arhive .zip cu PDF inclus.
"""

import html as htmlmod
import os

AMBER = "#C9752B"

CSS = """
@page{size:595pt 842pt;margin:0;}
html,body{width:595pt;}
body{font-family:-apple-system,'Helvetica Neue',Arial,sans-serif;color:#222;font-size:12px;line-height:1.55;margin:0;padding:0;}
.page{width:595pt;box-sizing:border-box;padding:48px 60px;page-break-after:always;}
.page:last-child{page-break-after:auto;}
h3{page-break-inside:avoid;page-break-after:avoid;}
li{page-break-inside:avoid;}
.titlepage{padding-top:260px;}
.titlepage h1{font-size:34px;margin:0 0 14px;font-weight:800;}
.titlepage .sub{font-size:16px;color:#555;margin:0 0 28px;}
.titlepage .author{font-size:13px;color:#333;margin:0 0 4px;}
.titlepage .note{font-size:11px;color:#888;}
h2{color:%(amber)s;font-size:20px;margin:0 0 14px;}
h3{font-size:14px;margin:20px 0 6px;}
p{margin:0 0 10px;}
ul{margin:0 0 12px;padding-left:20px;}
li{margin-bottom:5px;}
.callout{background:#F4F4F2;border-radius:6px;padding:10px 14px;font-size:11px;color:#444;margin-top:10px;}
.callout b{color:#222;}
table.install{width:100%%;border-collapse:collapse;margin:8px 0 14px;font-size:11.5px;}
table.install td{padding:4px 6px;vertical-align:top;}
table.install td:first-child{font-weight:700;white-space:nowrap;padding-right:14px;}
""" % {"amber": AMBER}


def esc(s):
    return htmlmod.escape(s, quote=False)


def render_page(inner_html, is_title=False):
    cls = "page titlepage" if is_title else "page"
    return f'<div class="{cls}">{inner_html}</div>'


def render_bullets(items):
    return "<ul>" + "".join(f"<li>{esc(i)}</li>" for i in items) + "</ul>"


def render_section(num, title, body_html):
    return render_page(f"<h2>{num}. {esc(title)}</h2>{body_html}")


def build_html(lang, data):
    pages = []

    pages.append(render_page(f"""
      <h1>GDC Production Manager</h1>
      <p class="sub">{esc(data['subtitle'])}</p>
      <p class="author">{esc(data['by'])}</p>
      <p class="note">{esc(data['updated_note'])}</p>
    """, is_title=True))

    # 1. Ce este
    body = f"""
      <p>{esc(data['what_p1'])}</p>
      <p>{esc(data['what_p2'])}</p>
      <h3>{esc(data['what_can_title'])}</h3>
      {render_bullets(data['what_can'])}
      <h3>{esc(data['what_not_title'])}</h3>
      {render_bullets(data['what_not'])}
      <div class="callout"><b>{esc(data['note_label'])}:</b> {esc(data['what_license_note'])}</div>
    """
    pages.append(render_section(1, data['sec1_title'], body))

    # 2. Instalare
    rows = "".join(
        f"<tr><td>{esc(k)}</td><td>{esc(v)}</td></tr>" for k, v in data['install_rows']
    )
    body = f"""
      <table class="install">{rows}</table>
      <h3>{esc(data['install_first_run_title'])}</h3>
      <p>{esc(data['install_first_run_p'])}</p>
      <div class="callout"><b>{esc(data['note_label'])}:</b> {esc(data['install_note'])}</div>
    """
    pages.append(render_section(2, data['sec2_title'], body))

    # 3. Functionalitati
    feat_html = "".join(
        f"<h3>{esc(t)}</h3><p>{esc(d)}</p>" for t, d in data['features']
    )
    pages.append(render_section(3, data['sec3_title'], feat_html))

    # 4. Cont si securitate (nou)
    acc_html = "".join(
        f"<h3>{esc(t)}</h3><p>{esc(d)}</p>" for t, d in data['account']
    )
    pages.append(render_section(4, data['sec4_title'], acc_html))

    # 5. Exemple
    ex_html = "".join(
        f"<h3>{esc(t)}</h3>{render_bullets(items)}" for t, items in data['examples']
    )
    pages.append(render_section(5, data['sec5_title'], ex_html))

    # 6. Probleme frecvente
    faq_html = "".join(
        f"<h3>{esc(q)}</h3>{render_bullets(a) if isinstance(a, list) else f'<p>{esc(a)}</p>'}"
        for q, a in data['faq']
    )
    pages.append(render_section(6, data['sec6_title'], faq_html))

    # 7. Licenta
    body = f"""
      <p>{esc(data['license_p1'])}</p>
      <p>{esc(data['license_p2'])}</p>
      <div class="callout"><b>{esc(data['note_label'])}:</b> {esc(data['license_note'])}</div>
    """
    pages.append(render_section(7, data['sec7_title'], body))

    return f"""<!DOCTYPE html>
<html lang="{lang}">
<head><meta charset="UTF-8"><style>{CSS}</style></head>
<body>{''.join(pages)}</body>
</html>"""


RO = {
    "subtitle": "Ghid complet: instalare, funcționalități explicate, exemple, depanare",
    "by": "de Cristi Gordas",
    "updated_note": "Ghid actualizat pentru versiunea 1.1.2 a aplicației",
    "note_label": "Notă",
    "sec1_title": "Ce este GDC Production Manager",
    "what_p1": "GDC Production Manager e o aplicație desktop, de sine stătătoare, pentru gestionarea proiectelor de producție video — filme, reclame, nunți, documentare, broadcast, videoclipuri muzicale, corporate. Fiecare utilizator o instalează pe propriul laptop; datele rămân 100% locale, nimic nu pleacă pe internet fără voia ta.",
    "what_p2": "Tehnic, aplicația pornește un server local (Flask + SQLite) și deschide automat interfața într-un tab de browser, la o adresă de tipul http://127.0.0.1:xxxx — arată și se folosește ca un site web, dar rulează complet pe calculatorul tău, fără cont online, fără cloud obligatoriu.",
    "what_can_title": "Ce poate face",
    "what_can": [
        "Urmărește proiecte prin toate etapele lor: planificare → filmare → montaj → colorizare → review → final → predat.",
        "Ține evidența clienților, cursurilor 1-la-1, și a produselor digitale (DCTL-uri, LUT-uri, presetări) pe care le vinzi.",
        "Checklist-uri reutilizabile per proiect, reminder-uri pentru termene și facturi, calendar lunar.",
        "Rapoarte PDF, export/import JSON pentru backup, temă light/dark.",
        "Pagină de Ajutor încorporată în aplicație, cu tot ce poate face — nu trebuie să cauți pe internet.",
        "Interfață completă în română, engleză și spaniolă.",
    ],
    "what_not_title": "Ce NU face",
    "what_not": [
        "Nu e un sistem cloud multi-utilizator la distanță — sincronizarea între laptopuri e opțională și self-hosted, nu printr-un server terț.",
        "Nu emite facturi fiscale oficiale — facturarea din aplicație e simplă, pentru evidență proprie (buget, sumă încasată, status).",
        "Nu are versiune Linux momentan — doar Mac și Windows.",
    ],
    "what_license_note": "Codul sursă e deschis (licență MIT), disponibil integral pe GitHub. Aplicația compilată, distribuită ca instalator, are 7 zile de probă gratuită, apoi necesită activare — vezi secțiunea 7 pentru detalii.",
    "sec2_title": "Instalare",
    "install_rows": [
        ("macOS", "Descarcă GDCProductionManager-mac.zip din pagina de Releases, dezarhivează, apoi dublu-click pe fișierul .pkg și urmează pașii instalatorului standard macOS."),
        ("Windows", "Descarcă GDCProductionManager-windows.zip din pagina de Releases, dezarhivează, apoi dublu-click pe .exe pentru a rula direct — nu necesită instalare separată."),
    ],
    "install_first_run_title": "La prima pornire",
    "install_first_run_p": "Aplicația deschide automat interfața într-un tab nou de browser, la o adresă locală (http://127.0.0.1:xxxx). Dacă browserul nu se deschide automat, verifică adresa afișată în fereastra aplicației și copiaz-o manual într-un browser. Primul pas e crearea unui cont local — primești atunci un cod de recuperare, afișat o singură dată (vezi secțiunea 4).",
    "install_note": "Fiecare arhivă (.zip) include și acest ghid PDF, în toate cele 3 limbi — nu trebuie descărcat separat.",
    "sec3_title": "Funcționalitățile, explicate în detaliu",
    "features": [
        ("Proiecte și etape de lucru", "Fiecare proiect are un tip (film, reclamă, nuntă, documentar, broadcast, videoclip muzical, corporate), locație de filmare, și date de filmare/predare. Etapele sunt fixe: planificare → filmare → montaj → colorizare → review → final → predat. Butonul “Next Step” avansează automat proiectul, cu o bară vizuală de progres. Fiecare etapă are propriul câmp de notițe, păstrat separat."),
        ("Clienți", "Evidența clienților, cu date de contact și numărul de proiecte/cursuri asociate fiecăruia."),
        ("Cursuri 1-la-1", "Fiecare curs are subiect, dată și oră, durată, preț, status plată, status curs (programat/confirmat/finalizat/anulat), și locație (online/fizic) — legat de clientul respectiv."),
        ("Produse digitale", "DCTL-uri, PowerGrade-uri, LUT-uri, presetări sau șabloane: preț, versiune, compatibilitate, cale locală și link de descărcare."),
        ("Monedă selectabilă (EUR / RON)", "Fiecare proiect, curs sau produs poate avea propria monedă. Totalurile din dashboard sunt calculate SEPARAT pe fiecare monedă — nu amestecate."),
        ("Checklist-uri și șabloane", "Un șablon e o listă de item-uri reutilizabilă, creată o singură dată din Setări → Checklist-uri (nume, tip - pre-filmare/post-filmare/general, opțional un tip de proiect, și item-urile, câte unul pe linie). Pe orice proiect, în câmpul Checklist-uri, alegi șablonul dintr-un meniu și apeși “+ Checklist nou” — item-urile apar automat, gata de bifat, cu bară de progres. Un proiect poate avea mai multe checklist-uri. Vin incluse din start 4 șabloane (Pre-filmare Nuntă, Post-filmare Nuntă, Pre-filmare Reclamă, Post-filmare Reclamă), complet editabile sau ștergibile — poți crea oricâte altele. Modificarea unui șablon nu schimbă checklist-urile deja create din el, doar pe cele viitoare."),
        ("Reminder-uri și notificări", "Reminder-uri pentru termene, facturi neplătite, sau întâlniri, cu rezumat pe dashboard. Notificări în aplicație plus notificări native de browser (dacă acorzi permisiunea)."),
        ("Calendar și export .ics", "Calendar lunar cu filmări și predări, exportabil ca fișier .ics către Apple Calendar, Outlook sau Google Calendar."),
        ("Rapoarte PDF", "Rapoarte per proiect și per checklist, printabile direct din aplicație."),
        ("Backup: Export / Import JSON", "Din Setări, exporți toate datele într-un fișier JSON — folosește-l ca backup periodic sau ca să muți datele pe alt laptop."),
        ("Sincronizare opțională self-hosted", "Leagă două instalări ale aplicației, de obicei pe aceeași rețea locală, ca să sincronizezi datele, fără niciun server terț."),
        ("Multi-utilizator local", "Mai multe conturi pot exista pe același laptop, fiecare cu propriile date, complet separate."),
        ("Verificare actualizări din aplicație", "Din Setări, un buton “Verifică actualizări” îți spune dacă există o versiune mai nouă și te duce direct la descărcare."),
    ],
    "sec4_title": "Cont și securitate",
    "account": [
        ("Cod de recuperare", "La înregistrare primești o singură dată un cod de recuperare (gen XXXX-XXXX-XXXX-XXXX) — salvează-l undeva sigur. E singura cale de a-ți reseta parola dacă o uiți, fiindcă aplicația nu are email și nu trimite nimic pe internet. Folosești link-ul “Ai uitat parola?” de pe ecranul de autentificare. După un reset reușit, primești un cod nou (cel vechi nu mai funcționează). Îl poți regenera oricând din Setări, cu parola curentă."),
        ("Touch ID / Windows Hello", "Din Setări, poți activa o logare rapidă cu amprentă (Mac) sau Windows Hello, pe acest calculator. Parola rămâne mereu funcțională, ca variantă de rezervă — Touch ID e opțional, nu o obligație."),
        ("Conturi locale multiple", "Mai multe persoane pot folosi aceeași instalare, fiecare cu cont și date separate complet, pe același calculator."),
    ],
    "sec5_title": "Exemple practice de utilizare",
    "examples": [
        ("Proiect nou de la zero", [
            "Adaugă proiect nou → alege tipul (ex: nuntă) → completează client, date de filmare/predare, monedă.",
            "Aplică șablonul de checklist “Pre-filmare Nuntă” — vine deja populat cu item-uri standard.",
            "Pe măsură ce avansezi, apasă “Next Step” la fiecare etapă finalizată.",
            "La final, generează raportul PDF și predă-l clientului.",
        ]),
        ("Backup înainte de un laptop nou", [
            "Setări → Export JSON — salvează fișierul într-un loc sigur (cloud personal, USB).",
            "Pe laptopul nou, instalează aplicația, apoi Setări → Import JSON.",
            "Toate proiectele, clienții, cursurile și produsele revin exact cum erau.",
        ]),
        ("Am uitat parola", [
            "Pe ecranul de autentificare, apasă “Ai uitat parola?”",
            "Introdu username-ul și codul de recuperare primit la înregistrare.",
            "Alege o parolă nouă — primești imediat un cod de recuperare nou, de salvat.",
        ]),
    ],
    "sec6_title": "Probleme frecvente și soluții",
    "faq": [
        ("Aplicația nu deschide browserul automat", "Verifică fereastra aplicației — adresa locală (http://127.0.0.1:xxxx) e afișată acolo. Copiaz-o manual într-un browser."),
        ("Am pierdut datele după o reinstalare", "Datele sunt locale, în baza de date SQLite. Fă export JSON periodic din Setări, mai ales înainte de o reinstalare majoră sau schimbare de laptop."),
        ("Am uitat parola și codul de recuperare", "Din păcate, fără codul de recuperare, contul local nu poate fi recuperat automat — aplicația nu are email/server. Contactează-mă direct dacă ai nevoie de ajutor."),
        ("Totalurile din dashboard arată ciudat", "Se calculează separat pe EUR și RON, nu amestecate — verifică dacă ai proiecte în ambele monede."),
        ("Sincronizarea între două laptopuri nu merge", "Necesită ca ambele instalări să poată comunica direct, de obicei pe aceeași rețea locală."),
    ],
    "sec7_title": "Licență și activare",
    "license_p1": "GDC Production Manager are 7 zile de probă completă, fără nicio limitare — poți testa absolut tot. După aceea, aplicația necesită o activare pe viață: 25€, o singură dată, fără abonament, fără reînnoiri.",
    "license_p2": "Activarea o faci din Setări → Licență (sau din ecranul de activare, dacă proba a expirat) — oricând vrei, nu doar la expirare. Acolo găsești ID-ul calculatorului tău și un buton de donație pe WhatsApp: trimiți ID-ul, primești manual codul serial, îl introduci și gata. Codul e legat de acel calculator — nu funcționează pe altul.",
    "license_note": "Codul sursă rămâne deschis (licență MIT) pe GitHub — plătești activarea aplicației compilate, gata de folosit, nu codul în sine.",
}

EN = {
    "subtitle": "Complete guide: installation, features explained, examples, troubleshooting",
    "by": "by Cristi Gordas",
    "updated_note": "Guide updated for app version 1.1.2",
    "note_label": "Note",
    "sec1_title": "What is GDC Production Manager",
    "what_p1": "GDC Production Manager is a standalone desktop app for managing video production projects — films, commercials, weddings, documentaries, broadcast, music videos, corporate. Each user installs it on their own laptop; data stays 100% local, nothing leaves your machine without your say-so.",
    "what_p2": "Technically, the app starts a local server (Flask + SQLite) and automatically opens the interface in a browser tab, at an address like http://127.0.0.1:xxxx — it looks and works like a website, but runs entirely on your computer, with no online account and no mandatory cloud.",
    "what_can_title": "What it can do",
    "what_can": [
        "Track projects through every stage: planning → filming → editing → coloring → review → final → delivered.",
        "Keep records of clients, 1-on-1 courses, and digital products (DCTLs, LUTs, presets) you sell.",
        "Reusable per-project checklists, reminders for deadlines and invoices, a monthly calendar.",
        "PDF reports, JSON export/import for backup, light/dark theme.",
        "A built-in Help page inside the app, covering everything it can do — no need to search online.",
        "Full interface in Romanian, English and Spanish.",
    ],
    "what_not_title": "What it does NOT do",
    "what_not": [
        "It's not a remote multi-user cloud system — syncing between laptops is optional and self-hosted, not through a third-party server.",
        "It doesn't issue official tax invoices — billing in the app is simple, for your own record-keeping (budget, amount received, status).",
        "No Linux version yet — Mac and Windows only.",
    ],
    "what_license_note": "The source code is open (MIT license), fully available on GitHub. The compiled, distributed app has a 7-day free trial, then requires activation — see section 7 for details.",
    "sec2_title": "Installation",
    "install_rows": [
        ("macOS", "Download GDCProductionManager-mac.zip from the Releases page, unzip it, then double-click the .pkg file and follow the standard macOS installer steps."),
        ("Windows", "Download GDCProductionManager-windows.zip from the Releases page, unzip it, then double-click the .exe to run it directly — no separate installation needed."),
    ],
    "install_first_run_title": "First run",
    "install_first_run_p": "The app automatically opens the interface in a new browser tab, at a local address (http://127.0.0.1:xxxx). If the browser doesn't open automatically, check the address shown in the app window and copy it manually into a browser. The first step is creating a local account — you'll get a recovery code shown once (see section 4).",
    "install_note": "Each archive (.zip) also includes this PDF guide, in all 3 languages — no need to download it separately.",
    "sec3_title": "Features, explained in detail",
    "features": [
        ("Projects & stages", "Every project has a type (film, commercial, wedding, documentary, broadcast, music video, corporate), a shoot location, and shoot/delivery dates. The stages are fixed: planning → filming → editing → coloring → review → final → delivered. The “Next Step” button advances the project automatically, with a visual progress bar. Every stage keeps its own separate note field."),
        ("Clients", "Contact details and how many projects/courses each client has."),
        ("1-on-1 courses", "Each course has a topic, date/time, duration, price, payment status, course status (scheduled/confirmed/completed/cancelled), and location (online/in person) — linked to a client."),
        ("Digital products", "DCTLs, PowerGrades, LUTs, presets or templates: price, version, compatibility, local path and download link."),
        ("Selectable currency (EUR / RON)", "Every project, course or product can have its own currency. Dashboard totals are calculated SEPARATELY per currency — never mixed."),
        ("Checklists & templates", "A template is a reusable list of items, created once from Settings → Checklists (name, type - pre-shoot/post-shoot/general, an optional project type, and the items, one per line). On any project, in the Checklists field, pick the template from a menu and click “+ New checklist” — the items appear automatically, ready to check off, with a progress bar. A project can have several checklists. 4 templates come built in (Pre-shoot Wedding, Post-shoot Wedding, Pre-shoot Commercial, Post-shoot Commercial), fully editable or deletable — you can create as many more as you like. Editing a template doesn't change checklists already created from it, only future ones."),
        ("Reminders & notifications", "Reminders for deadlines, unpaid invoices, or meetings, with a dashboard summary. In-app notifications plus native browser notifications (if you grant the permission)."),
        ("Calendar & .ics export", "A monthly calendar of shoots and deliveries, exportable as an .ics file to Apple Calendar, Outlook or Google Calendar."),
        ("PDF reports", "Per-project and per-checklist reports, printable straight from the app."),
        ("Backup: Export / Import JSON", "From Settings, export all your data to a JSON file — use it as a periodic backup or to move data to another laptop."),
        ("Optional self-hosted sync", "Link two installs of the app, usually on the same local network, to sync data, with no third-party server."),
        ("Local multi-user", "Several accounts can exist on the same laptop, each with fully separate data."),
        ("In-app update checker", "From Settings, a “Check for updates” button tells you if a newer version is available and takes you straight to the download."),
    ],
    "sec4_title": "Account & security",
    "account": [
        ("Recovery code", "At registration you get a recovery code shown once (like XXXX-XXXX-XXXX-XXXX) — save it somewhere safe. It's the only way to reset your password if you forget it, since the app has no email and sends nothing over the internet. Use the “Forgot your password?” link on the login screen. After a successful reset, you get a new code (the old one stops working). You can regenerate it anytime from Settings, with your current password."),
        ("Touch ID / Windows Hello", "From Settings, you can enable a quick fingerprint (Mac) or Windows Hello login, on this computer. Your password always stays available as a fallback — Touch ID is optional, never mandatory."),
        ("Multiple local accounts", "Several people can use the same install, each with a fully separate account and data, on the same computer."),
    ],
    "sec5_title": "Practical usage examples",
    "examples": [
        ("A new project from scratch", [
            "Add new project → choose the type (e.g. wedding) → fill in client, shoot/delivery dates, currency.",
            "Apply the “Pre-shoot Wedding” checklist template — comes pre-filled with standard items.",
            "As you go, click “Next Step” for each finished stage.",
            "At the end, generate the PDF report and hand it to the client.",
        ]),
        ("Backup before a new laptop", [
            "Settings → Export JSON — save the file somewhere safe (personal cloud, USB).",
            "On the new laptop, install the app, then Settings → Import JSON.",
            "All projects, clients, courses and products come back exactly as they were.",
        ]),
        ("I forgot my password", [
            "On the login screen, click “Forgot your password?”",
            "Enter your username and the recovery code you got at registration.",
            "Choose a new password — you immediately get a new recovery code to save.",
        ]),
    ],
    "sec6_title": "Common issues & solutions",
    "faq": [
        ("Browser doesn't open automatically", "Check the app window — the local address (http://127.0.0.1:xxxx) is shown there. Copy it manually into a browser."),
        ("Lost data after reinstalling", "Data is local, in a SQLite database. Do periodic JSON exports from Settings, especially before a major reinstall or a new laptop."),
        ("I forgot my password AND my recovery code", "Unfortunately, without the recovery code, the local account can't be recovered automatically — the app has no email or server. Contact me directly if you need help."),
        ("Dashboard totals look off", "They're calculated separately for EUR and RON, not mixed — check if you have projects in both currencies."),
        ("Sync between two laptops isn't working", "Requires both installs to be able to communicate directly, usually on the same local network."),
    ],
    "sec7_title": "License & activation",
    "license_p1": "GDC Production Manager has a 7-day full trial, with no limitations — you can test absolutely everything. After that, the app requires a lifetime activation: 25€, one time, no subscription, no renewals.",
    "license_p2": "You activate from Settings → License (or from the activation screen, if the trial has expired) — whenever you want, not only once it expires. There you'll find your computer's ID and a WhatsApp purchase button: you send the ID, get the serial code back manually, enter it, and you're done. The code is locked to that computer — it won't work on another.",
    "license_note": "The source code stays open (MIT license) on GitHub — you're paying for the activation of the compiled, ready-to-use app, not for the code itself.",
}

ES = {
    "subtitle": "Guía completa: instalación, funciones explicadas, ejemplos, solución de problemas",
    "by": "por Cristi Gordas",
    "updated_note": "Guía actualizada para la versión 1.1.2 de la app",
    "note_label": "Nota",
    "sec1_title": "Qué es GDC Production Manager",
    "what_p1": "GDC Production Manager es una app de escritorio independiente para gestionar proyectos de producción de vídeo — películas, anuncios, bodas, documentales, broadcast, videoclips musicales, corporativo. Cada usuario la instala en su propio portátil; los datos se quedan 100% en local, nada sale a internet sin tu permiso.",
    "what_p2": "Técnicamente, la app arranca un servidor local (Flask + SQLite) y abre automáticamente la interfaz en una pestaña del navegador, en una dirección como http://127.0.0.1:xxxx — se ve y se usa como un sitio web, pero funciona por completo en tu ordenador, sin cuenta online ni nube obligatoria.",
    "what_can_title": "Qué puede hacer",
    "what_can": [
        "Sigue proyectos por todas sus etapas: planificación → rodaje → montaje → etalonaje → revisión → final → entregado.",
        "Lleva el registro de clientes, cursos 1 a 1, y productos digitales (DCTLs, LUTs, presets) que vendes.",
        "Checklists reutilizables por proyecto, recordatorios de plazos y facturas, calendario mensual.",
        "Informes PDF, exportación/importación JSON para backup, tema claro/oscuro.",
        "Página de Ayuda integrada en la app, con todo lo que puede hacer — no hace falta buscar en internet.",
        "Interfaz completa en rumano, inglés y español.",
    ],
    "what_not_title": "Qué NO hace",
    "what_not": [
        "No es un sistema en la nube multiusuario remoto — la sincronización entre portátiles es opcional y self-hosted, no a través de un servidor externo.",
        "No emite facturas fiscales oficiales — la facturación en la app es simple, para tu propio registro (presupuesto, importe cobrado, estado).",
        "No tiene versión Linux por ahora — solo Mac y Windows.",
    ],
    "what_license_note": "El código fuente es abierto (licencia MIT), disponible por completo en GitHub. La app compilada y distribuida tiene 7 días de prueba gratuita, luego requiere activación — ver la sección 7 para más detalles.",
    "sec2_title": "Instalación",
    "install_rows": [
        ("macOS", "Descarga GDCProductionManager-mac.zip desde la página de Releases, descomprímelo, luego haz doble clic en el archivo .pkg y sigue los pasos del instalador estándar de macOS."),
        ("Windows", "Descarga GDCProductionManager-windows.zip desde la página de Releases, descomprímelo, luego haz doble clic en el .exe para ejecutarlo directamente — no requiere instalación aparte."),
    ],
    "install_first_run_title": "Primer inicio",
    "install_first_run_p": "La app abre automáticamente la interfaz en una nueva pestaña del navegador, en una dirección local (http://127.0.0.1:xxxx). Si el navegador no se abre automáticamente, comprueba la dirección que se muestra en la ventana de la app y cópiala manualmente en un navegador. El primer paso es crear una cuenta local — recibirás entonces un código de recuperación, mostrado una sola vez (ver sección 4).",
    "install_note": "Cada archivo (.zip) incluye también esta guía en PDF, en los 3 idiomas — no hace falta descargarla aparte.",
    "sec3_title": "Las funciones, explicadas en detalle",
    "features": [
        ("Proyectos y etapas", "Cada proyecto tiene un tipo (película, anuncio, boda, documental, broadcast, videoclip musical, corporativo), ubicación de rodaje, y fechas de rodaje/entrega. Las etapas son fijas: planificación → rodaje → montaje → etalonaje → revisión → final → entregado. El botón “Next Step” avanza el proyecto automáticamente, con una barra visual de progreso. Cada etapa guarda su propio campo de notas por separado."),
        ("Clientes", "Datos de contacto y cuántos proyectos/cursos tiene asociados cada cliente."),
        ("Cursos 1 a 1", "Cada curso tiene tema, fecha y hora, duración, precio, estado de pago, estado del curso (programado/confirmado/finalizado/cancelado), y ubicación (online/presencial) — vinculado a un cliente."),
        ("Productos digitales", "DCTLs, PowerGrades, LUTs, presets o plantillas: precio, versión, compatibilidad, ruta local y enlace de descarga."),
        ("Moneda seleccionable (EUR / RON)", "Cada proyecto, curso o producto puede tener su propia moneda. Los totales del panel se calculan POR SEPARADO para cada moneda — nunca mezclados."),
        ("Checklists y plantillas", "Una plantilla es una lista de ítems reutilizable, creada una sola vez desde Ajustes → Checklists (nombre, tipo - pre-rodaje/post-rodaje/general, un tipo de proyecto opcional, y los ítems, uno por línea). En cualquier proyecto, en el campo Checklists, eliges la plantilla en un menú y pulsas “+ Checklist nuevo” — los ítems aparecen automáticamente, listos para marcar, con barra de progreso. Un proyecto puede tener varios checklists. Vienen incluidas 4 plantillas (Pre-rodaje Boda, Post-rodaje Boda, Pre-rodaje Anuncio, Post-rodaje Anuncio), totalmente editables o eliminables — puedes crear todas las que quieras. Editar una plantilla no cambia los checklists ya creados a partir de ella, solo los futuros."),
        ("Recordatorios y notificaciones", "Recordatorios de plazos, facturas pendientes, o reuniones, con resumen en el panel. Notificaciones en la app además de notificaciones nativas del navegador (si concedes el permiso)."),
        ("Calendario y exportación .ics", "Calendario mensual de rodajes y entregas, exportable como archivo .ics a Apple Calendar, Outlook o Google Calendar."),
        ("Informes PDF", "Informes por proyecto y por checklist, imprimibles directamente desde la app."),
        ("Backup: Exportar / Importar JSON", "Desde Ajustes, exporta todos tus datos a un archivo JSON — úsalo como backup periódico o para mover los datos a otro portátil."),
        ("Sincronización self-hosted opcional", "Conecta dos instalaciones de la app, normalmente en la misma red local, para sincronizar datos, sin ningún servidor externo."),
        ("Multiusuario local", "Varias cuentas pueden existir en el mismo portátil, cada una con sus propios datos, completamente separados."),
        ("Verificación de actualizaciones en la app", "Desde Ajustes, un botón “Buscar actualizaciones” te dice si hay una versión más nueva y te lleva directo a la descarga."),
    ],
    "sec4_title": "Cuenta y seguridad",
    "account": [
        ("Código de recuperación", "Al registrarte recibes una sola vez un código de recuperación (tipo XXXX-XXXX-XXXX-XXXX) — guárdalo en un lugar seguro. Es la única forma de restablecer tu contraseña si la olvidas, ya que la app no tiene email y no envía nada por internet. Usa el enlace “¿Olvidaste tu contraseña?” en la pantalla de inicio de sesión. Tras un restablecimiento exitoso, recibes un código nuevo (el anterior deja de funcionar). Puedes regenerarlo en cualquier momento desde Ajustes, con tu contraseña actual."),
        ("Touch ID / Windows Hello", "Desde Ajustes, puedes activar un inicio de sesión rápido con huella (Mac) o Windows Hello, en este ordenador. Tu contraseña siempre queda disponible como alternativa — Touch ID es opcional, nunca obligatorio."),
        ("Varias cuentas locales", "Varias personas pueden usar la misma instalación, cada una con su propia cuenta y datos completamente separados, en el mismo ordenador."),
    ],
    "sec5_title": "Ejemplos prácticos de uso",
    "examples": [
        ("Un proyecto nuevo desde cero", [
            "Añadir proyecto nuevo → elige el tipo (ej: boda) → completa cliente, fechas de rodaje/entrega, moneda.",
            "Aplica la plantilla de checklist “Pre-rodaje Boda” — viene ya rellena con ítems estándar.",
            "A medida que avanzas, pulsa “Next Step” en cada etapa terminada.",
            "Al final, genera el informe PDF y entrégaselo al cliente.",
        ]),
        ("Backup antes de un portátil nuevo", [
            "Ajustes → Exportar JSON — guarda el archivo en un lugar seguro (nube personal, USB).",
            "En el portátil nuevo, instala la app, luego Ajustes → Importar JSON.",
            "Todos los proyectos, clientes, cursos y productos vuelven exactamente como estaban.",
        ]),
        ("Olvidé mi contraseña", [
            "En la pantalla de inicio de sesión, pulsa “¿Olvidaste tu contraseña?”",
            "Introduce tu usuario y el código de recuperación que recibiste al registrarte.",
            "Elige una contraseña nueva — recibes de inmediato un código de recuperación nuevo para guardar.",
        ]),
    ],
    "sec6_title": "Problemas frecuentes y soluciones",
    "faq": [
        ("El navegador no se abre automáticamente", "Comprueba la ventana de la app — la dirección local (http://127.0.0.1:xxxx) se muestra ahí. Cópiala manualmente en un navegador."),
        ("Perdí los datos tras reinstalar", "Los datos son locales, en una base de datos SQLite. Haz exportaciones JSON periódicas desde Ajustes, sobre todo antes de una reinstalación importante o un portátil nuevo."),
        ("Olvidé mi contraseña Y mi código de recuperación", "Por desgracia, sin el código de recuperación, la cuenta local no se puede recuperar automáticamente — la app no tiene email ni servidor. Contáctame directamente si necesitas ayuda."),
        ("Los totales del panel se ven raros", "Se calculan por separado para EUR y RON, no mezclados — comprueba si tienes proyectos en ambas monedas."),
        ("La sincronización entre dos portátiles no funciona", "Requiere que ambas instalaciones puedan comunicarse directamente, normalmente en la misma red local."),
    ],
    "sec7_title": "Licencia y activación",
    "license_p1": "GDC Production Manager tiene 7 días de prueba completa, sin ninguna limitación — puedes probar absolutamente todo. Después, la app requiere una activación de por vida: 25€, pago único, sin suscripción, sin renovaciones.",
    "license_p2": "Activas desde Ajustes → Licencia (o desde la pantalla de activación, si la prueba ha caducado) — cuando quieras, no solo al caducar. Ahí encuentras el ID de tu ordenador y un botón de compra por WhatsApp: envías el ID, recibes el código serial manualmente, lo introduces y listo. El código queda vinculado a ese ordenador — no funciona en otro.",
    "license_note": "El código fuente sigue siendo abierto (licencia MIT) en GitHub — pagas la activación de la app compilada y lista para usar, no el código en sí.",
}

if __name__ == "__main__":
    out_dir = os.path.join(os.path.dirname(__file__))
    for lang, data, fname in [
        ("ro", RO, "GDC_Production_Manager_Ghid_RO.html"),
        ("en", EN, "GDC_Production_Manager_Guide_EN.html"),
        ("es", ES, "GDC_Production_Manager_Guia_ES.html"),
    ]:
        html_out = build_html(lang, data)
        path = os.path.join(out_dir, fname)
        with open(path, "w", encoding="utf-8") as f:
            f.write(html_out)
        print("Wrote", path)
