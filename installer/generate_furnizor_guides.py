# Genereaza cele 4 ghiduri PDF dedicate Furnizorului — Cursuri, Produse,
# Licente, Backup — [NOU 2026-09-03], primul PDF pe care aplicatia Furnizor
# il are vreodata (pana acum avea doar TokenRenewalGuideView.swift, un ghid
# IN-APP, nu un PDF descarcabil/deschis din Ajutor). Reutilizeaza integral
# stilul + fonturile + helper-ii din generate_pdf.py (Client) — acelasi
# limbaj vizual (coperta cu banda INK_DARK+accent, casete "Important"/
# "Sfat", footer cu numar de pagina), ca sa nu existe doua identitati
# vizuale diferite intre ghidurile Client si Furnizor.
#
# Furnizorul e exclusiv pentru Cristi (Regula Partea 2, "Cristi-only tool"
# din Package.swift) — spre deosebire de Client, aceste ghiduri sunt DOAR
# in romana, fara RO/EN/ES.
#
# Ruleaza cu: python3 installer/generate_furnizor_guides.py
import os
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import cm
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, PageBreak

from generate_pdf import (
    title_style, h2_style, body_style, cover_app_style, cover_sub_style, cover_ver_style,
    numbered, h3, note_box, _cover_canvas, _content_canvas,
)

OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Sources", "GDCPluginManagerFurnizor", "Resources")
APP_VERSION = "1.30.1"


def build_furnizor(out_path, guide_title, cover_subtitle, sections):
    doc = SimpleDocTemplate(out_path, pagesize=A4, leftMargin=2 * cm, rightMargin=2 * cm, topMargin=2 * cm, bottomMargin=2 * cm)
    flow = [
        Spacer(1, 3.4 * cm),
        Paragraph("GDC Plugin Manager", cover_app_style),
        Paragraph("Furnizor", cover_app_style),
        Paragraph(cover_subtitle, cover_sub_style),
        Spacer(1, 2.6 * cm),
        Paragraph(f"Versiunea {APP_VERSION}", cover_ver_style),
        Paragraph("Document intern — doar pentru Cristi, nu se distribuie clienților.", cover_ver_style),
        PageBreak(),
        Paragraph(guide_title, title_style),
    ]
    for h, body in sections:
        flow.append(Paragraph(h, h2_style))
        for item in body:
            if isinstance(item, tuple) and len(item) == 2 and item[0] == "__note__":
                flow.append(note_box(item[1][0], item[1][1]))
            elif isinstance(item, tuple) and len(item) == 2 and item[0] == "__steps__":
                flow.append(numbered(item[1]))
            elif isinstance(item, tuple) and len(item) == 2 and item[0] == "__h3__":
                flow.append(h3(item[1]))
            else:
                flow.append(Paragraph(item, body_style))

    footer_text = "GDC Plugin Manager Furnizor — document intern"

    def on_first(canvas, doc_):
        _cover_canvas(canvas, doc_, {})

    def on_later(canvas, doc_):
        _content_canvas(canvas, doc_, footer_text)

    doc.build(flow, onFirstPage=on_first, onLaterPages=on_later)
    print("wrote", out_path)


# ─────────────────────────────────────────────────────────────────────────
# 1. CURSURI — grounded in PublishCourseView.swift (Etapa 2026-09-03: model
#    de acces + format/durata + valabilitate, adaugate in aceeasi sesiune).
# ─────────────────────────────────────────────────────────────────────────
courses_sections = [
    ("1. Ce este un curs în catalog",
     [
         "Un curs nu e un fișier descărcabil — clientul îl vede pe cardul lui din aplicație, apasă „Contactează” (sau, dacă are Link Acces, „Acces / Școală Online”) și restul se stabilește direct cu tine, prin WhatsApp. Nu există cont, plată online sau verificare automată de acces — exact ca la restul catalogului.",
     ]),
    ("2. Câmpurile de bază",
     [
         ("__h3__", "ID, Nume, Descriere"),
         "ID-ul e fix după publicare (ex. „curs-color-grading”) — folosește un nume scurt, fără spații, pe care nu vrei să-l schimbi mai târziu. Nume și Descriere apar direct pe cardul din Client.",
     ]),
    ("3. Tip Curs (Model de Acces) — NOU",
     [
         "Patru opțiuni, alese din selectorul „Tip Curs”:",
         ("__steps__", [
             "<b>Gratuit</b> — acces direct, fără nicio plată, pentru orice utilizator Client.",
             "<b>Plată Unică</b> — prețul fix de pe opțiunile de mai jos, plătit o singură dată (comportamentul de până acum al cursurilor).",
             "<b>Abonament</b> — marchează cursul ca inclus într-un abonament/membership.",
             "<b>Live / Mentorat 1-la-1</b> — sesiune interactivă, în timp real (Zoom/Meet/etc.).",
         ]),
         ("__note__", ("Important:", "„Abonament” e DOAR o etichetă vizuală pe card — GDC Plugin Manager nu are (încă) un sistem real de membri/tiere care să verifice automat un abonament activ. Alegerea acestui tip nu schimbă nimic în ce vede/poate face clientul; e informativ, la fel ca și cum ai scrie „inclus în abonament” în descriere.")),
     ]),
    ("4. Detalii Desfășurare & Acces",
     [
         "<b>Link Acces / Școală Online</b> — opțional, orice URL (Zoom, Meet, o platformă proprie). Dacă e completat, clientul vede un buton „Acces / Școală Online” direct pe card, care deschide linkul fără login.",
         "<b>Format & Durată</b> — text liber, ex. „6 ore, 4 module” sau „1 sesiune 1-la-1”. Apare pe card lângă eticheta de tip acces.",
     ]),
    ("5. Valabilitate Acces",
     [
         "Alege între „Acces pe viață” (implicit) și „Limitată (zile)” — dacă alegi limitată, completezi numărul de zile (ex. 30, 90, 365), calculat de la data la care clientul te contactează, nu de la data publicării.",
         ("__note__", ("Notă:", "această valabilitate e tot informativă, afișată pe cardul din Client — nu există o expirare automată de acces, exact ca la „Abonament”. Comunici tu clientului termenul, la fel cum faci și cu prețul.")),
     ]),
    ("6. Opțiuni (durată/tip + preț)",
     [
         "Fiecare curs poate avea mai multe opțiuni — ex. „1 oră” / „2 ore” / „1 la 1” — fiecare cu propriul preț în EUR. Clientul alege una și apasă „Contactează”, iar mesajul WhatsApp pre-completat include automat numele opțiunii și prețul ei.",
         ("__note__", ("Important:", "un curs are nevoie de minim o opțiune de preț ca să poată fi publicat — chiar și un curs Gratuit are nevoie de o opțiune (ex. „Sesiune standard” cu prețul 0), pentru claritate pe card.")),
     ]),
    ("7. Copertă, Valabilitate temporală și Rețele sociale",
     [
         "Aceleași componente reutilizate din restul catalogului: Copertă (preset panoramic, se vede detaliat într-un preview mărit), Valabilitate temporală opțională (de la — până la o dată, cu ceas live opțional „Mai sunt Xz Yh”) și Rețele sociale (linkuri afișate pe card).",
     ]),
    ("8. Publicare, editare, ștergere",
     [
         "„Publică” (curs nou) sau „Actualizează” (curs existent, selectat din listă cu „Editează”) face automat: pull din git, scrie coperta (dacă s-a schimbat), scrie catalog.json, apoi commit + push — apare la clienți la următorul refresh de catalog, fără nicio acțiune suplimentară din partea ta.",
         "„Șterge” elimină definitiv cursul (și coperta lui) din catalog — ireversibil după push.",
     ]),
]

# ─────────────────────────────────────────────────────────────────────────
# 2. PRODUSE — grounded in PublishView.swift (DCTL/LUT/Fuse/OFX/PowerGrade).
# ─────────────────────────────────────────────────────────────────────────
products_sections = [
    ("1. Produs nou vs. Actualizare versiune existentă",
     [
         "Comutatorul de sus alege între a publica un produs complet nou sau a urca o versiune nouă a unuia deja existent (alegi produsul din „Produs existent” — restul câmpurilor se precompletează cu ce e deja publicat, îl poți edita liber).",
         ("__note__", ("Important:", "„Șterge acest produs definitiv” (vizibil doar la Actualizare) elimină produsul din catalog și fișierele lui din repo-ul privat — ireversibil, cere confirmare explicită.")),
     ]),
    ("2. Câmpurile de bază",
     [
         "ID (fix după publicare), Nume, Descriere, Categorie (DCTL/LUT/Fuse/OFX/PowerGrade — determină folderul de instalare la client), Versiune (obligatoriu la fiecare republicare — clienții văd „actualizare disponibilă” doar dacă numărul crește).",
         ("__note__", ("Sfat:", "pentru OFX, alege folderul ÎNTREG „NumePlugin.ofx.bundle”, nu doar un fișier din interior — Resolve identifică plugin-ul după numele exact al acelui folder.")),
     ]),
    ("3. Acces — Gratuit / Probă / Licență",
     [
         "<b>Gratuit</b> — clientul instalează direct, fără niciun cod de activare.",
         "<b>Probă</b> — instalare directă, fără cod, dar cu eticheta „Probă” pe card; produsul include watermark direct în fișier — publică-l separat de versiunea plătită (ex. „Nume Produs (Probă)”).",
         "<b>Licență</b> — clientul are nevoie de un cod, generat separat din „Generează serial” (vezi ghidul de Licențe) — completezi Prețul (EUR, donație) și, opțional, o Sumă promoțională temporară, activă doar în intervalul de valabilitate ales.",
     ]),
    ("4. Compatibilitate & extra",
     [
         "Compatibilitate: Doar Mac / Doar Windows / Ambele platforme — alege corect, produsul apare doar clienților de pe platforma potrivită.",
         "Icon (SF Symbol, opțional), Link tutorial YouTube (opțional, nelistat), și — pentru produse externe — Link Achiziție/Magazin extern + Link Demo/Preview.",
         ("__note__", ("Sfat:", "la o actualizare, poți edita doar linkul YouTube (sau alt câmp) fără să realegi fișierele — cele existente rămân neschimbate dacă nu selectezi altele noi.")),
     ]),
    ("5. Publicare",
     [
         "„Publică” face pull din git, copiază fișierele produsului în repo-ul privat, scrie catalog.json, apoi commit + push — la fel ca la Cursuri, fără niciun pas manual suplimentar.",
     ]),
]

# ─────────────────────────────────────────────────────────────────────────
# 3. LICENTE — grounded in GenerateSerialView.swift, RevocationsView.swift,
#    ExtendLicenseView.swift.
# ─────────────────────────────────────────────────────────────────────────
licenses_sections = [
    ("1. Generarea unei licențe noi",
     [
         "Din „Generează serial”: alegi produsul, completezi numele/emailul clientului și Machine ID-ul lui (îl trimite din secțiunea „Licență” a aplicației Client, cu butonul „Copiază”), apoi alegi Durata.",
         ("__h3__", "Durată — Zile / Luni / Ani / Pe viață (Lifetime)"),
         "Selector explicit, cu o cantitate (ex. „3 Luni”) — sau „Pe viață” pentru o licență fără expirare. Formatul e informativ pentru dată; codul rămâne un payload criptografic Ed25519, fără dependență de un server extern la activare.",
         ("__note__", ("Notă:", "poți completa și o „Notă versiune” (ex. „valabil până la versiunea 3.0”) — NU e o restricție criptografică (payload-ul nu are câmp de versiune), e doar o notă informativă în jurnalul de vânzări; aplicarea reală, dacă e cazul, se face manual, prin Revocare, când acea versiune chiar apare.")),
     ]),
    ("2. Trimiterea codului",
     [
         "Codul generat se trimite clientului (WhatsApp, email) — el îl lipește în câmpul „Cod serial” din secțiunea Licență a aplicației Client și apasă „Activează”. Activarea leagă codul de Machine ID-ul acelui calculator.",
     ]),
    ("3. Revocarea unei licențe",
     [
         "Din „Revocări licențe”: completezi Machine ID + ID produs (ambele din fișa clientului sau din secțiunea Licență a lui) și, opțional, un Motiv — apeși „Revocă”.",
         ("__note__", ("Important:", "revocarea e fail-open: clientul o pierde abia la următoarea verificare online reușită — fără conexiune la internet, o licență deja activată local CONTINUĂ să funcționeze, nu se blochează niciodată doar din cauza rețelei. „Anulează revocarea” din listă restaurează accesul.")),
     ]),
    ("4. Prelungirea unei licențe existente",
     [
         "Din fișa clientului (secțiunea „Clienți”), butonul „Prelungește…” generează un cod NOU, pentru același produs și dispozitiv, cu o durată nouă (Zile/Luni/Ani/Lifetime) — codul vechi rămâne neschimbat, valabil, dacă preferi să nu-l blochezi explicit (îl poți revoca separat, dacă vrei).",
     ]),
    ("5. Fișa clientului — acțiuni rapide",
     [
         "Din „Clienți”: filtrare pe produs, export 1-click al email-urilor/HWID-urilor din selecția curentă, copiere rapidă per-câmp direct din tabel, și Licențiere în Masă (paste o listă de email-uri/machine ID-uri → generează câte o licență per linie, pentru un produs/durată alese o singură dată).",
     ]),
]

# ─────────────────────────────────────────────────────────────────────────
# 4. BACKUP — grounded in BackupView.swift, BackupArchive.swift.
# ─────────────────────────────────────────────────────────────────────────
backup_sections = [
    ("1. De ce contează",
     [
         "Cheia privată de semnare a licențelor există într-un singur exemplar, pe acest Mac — dacă acest Mac se pierde/stricăsă fără backup, nu mai poți emite NICIO licență nouă, pentru niciun produs GDC, niciodată. Backup-ul e un singur fișier criptat cu tot ce ține de Furnizor.",
     ]),
    ("2. Ce conține un backup",
     [
         "Componente ESENȚIALE (bifate implicit, nu le debifa fără motiv):",
         ("__steps__", [
             "Cheia privată de semnare a licențelor — fără ea nu se mai poate emite nicio licență.",
             "Jurnalul de vânzări și clienți — toate licențele emise: client, email, produs, preț, expirare, Machine ID, serial.",
             "Tokenul GitHub de publicare și Cheia de administrare Supabase — fișiere sursă excluse din git, un clone nou al repo-ului NU le aduce.",
         ]),
         "Componente opționale (recuperabile și din alte surse): cheia publică, jurnalele vechi (moștenite din GDC License Manager), imaginile de copertă în lucru, catalogul publicat (docs/, recuperabil dintr-un git clone) și fișierele vandabile din repo-ul privat (zeci de MB, recuperabile din acel repo).",
         ("__note__", ("Atenție:", "dacă debifezi o componentă esențială, aplicația arată un avertisment explicit — „Backup-ul va fi incomplet.”")),
     ]),
    ("3. Generarea unui backup",
     [
         "Alegi componentele, setezi o Parolă master, apoi „Generează Backup Criptat…”.",
         ("__note__", ("Important:", "fără această parolă, arhiva nu poate fi decriptată de NIMENI — nici de tine, nici de Claude. Notează-o într-un loc sigur, separat de Mac-ul curent (ex. un manager de parole).")),
     ]),
    ("4. Restaurarea pe un Mac nou",
     [
         "Din „Importă backup / Restaurare”: alegi fișierul de backup, introduci parola — aplicația arată data creării și lista componentelor conținute înainte să confirmi.",
         "„Restaurează pe acest Mac” recreează structura completă. Fișierele existente cu același nume sunt păstrate alături (cu un sufix), nu suprascrise silențios.",
     ]),
]


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    build_furnizor(
        os.path.join(OUT_DIR, "Ghid-Furnizor-Cursuri.pdf"),
        "Ghid: Gestionarea Cursurilor",
        "Ghid: Gestionarea Cursurilor",
        courses_sections,
    )
    build_furnizor(
        os.path.join(OUT_DIR, "Ghid-Furnizor-Produse.pdf"),
        "Ghid: Gestionarea Produselor",
        "Ghid: Gestionarea Produselor",
        products_sections,
    )
    build_furnizor(
        os.path.join(OUT_DIR, "Ghid-Furnizor-Licente.pdf"),
        "Ghid: Licențe",
        "Ghid: Licențe (Generare, Revocare, Prelungire)",
        licenses_sections,
    )
    build_furnizor(
        os.path.join(OUT_DIR, "Ghid-Furnizor-Backup.pdf"),
        "Ghid: Backup & Securitate",
        "Ghid: Backup & Securitate",
        backup_sections,
    )


if __name__ == "__main__":
    main()
