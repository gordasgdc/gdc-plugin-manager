import Foundation
import AppKit
import CoreText
import UniformTypeIdentifiers

/// Ghidul de urgență: toate procedurile manuale de reînnoire, într-un PDF
/// generat ACUM, din același inventar pe care îl afișează dashboard-ul.
///
/// DE CE GENERAT LA RULARE și nu împachetat la build, ca ghidurile din
/// `FurnizorGuidePDF`: un PDF bundle-uit îngheață la conținutul de la
/// momentul build-ului. Adaugi un secret nou sau schimbi permisiunile cerute
/// și ghidul rămâne în urmă tăcut — exact în ziua în care îl deschizi de pe
/// telefon pentru că nu mai ai acces la Mac. Aici nu poate exista drift:
/// sursa e `SecretRegistry.allSecrets()`, aceeași care alimentează UI-ul.
///
/// CE NU CONȚINE: nicio valoare de secret. Ghidul spune UNDE stă fiecare și
/// CUM se înlocuiește; e făcut ca să poată fi ținut pe telefon sau tipărit.
@MainActor
enum EmergencyGuidePDF {

    private static let pageSize = CGSize(width: 595, height: 842)   // A4
    private static let margin: CGFloat = 54

    /// Deschide panoul de salvare și scrie PDF-ul. Întoarce calea, dacă s-a salvat.
    @discardableResult
    static func export(statuses: [String: SecretStatus]) -> URL? {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType.pdf]
        panel.nameFieldStringValue = "Ghid-Urgenta-Tokenuri-GDC.pdf"
        panel.message = "Ghid complet de reînnoire manuală — nu conține nicio valoare de token."
        guard panel.runModal() == .OK, let url = panel.url else { return nil }

        let data = makeData(statuses: statuses)
        do {
            try data.write(to: url)
            return url
        } catch {
            let alert = NSAlert()
            alert.messageText = "Nu am putut salva ghidul"
            alert.informativeText = error.localizedDescription
            alert.runModal()
            return nil
        }
    }

    // MARK: Compunerea documentului

    static func makeData(statuses: [String: SecretStatus]) -> Data {
        let text = composeDocument(statuses: statuses)
        return render(text)
    }

    private static func composeDocument(statuses: [String: SecretStatus]) -> NSAttributedString {
        let doc = NSMutableAttributedString()

        doc.append(styled("Ghid de urgență — token-uri și chei\n", .title))
        doc.append(styled("GDC Plugin Manager · generat \(Date().formatted(date: .long, time: .shortened))\n\n", .caption))
        doc.append(styled(
            "Documentul acesta conține procedura manuală completă pentru fiecare secret de care depinde ecosistemul. " +
            "E făcut ca să poată fi urmat de pe alt dispozitiv, fără acces la Mac și fără ajutor extern. " +
            "Nu conține nicio valoare de token — doar unde stă fiecare și cum se înlocuiește.\n\n", .body))

        for secret in SecretRegistry.allSecrets() {
            let status = statuses[secret.id]

            doc.append(styled("\(secret.name)\n", .heading))

            if let status {
                doc.append(styled("Stare la generarea ghidului: \(status.headline)\n", .caption))
            }

            doc.append(styled("La ce folosește: ", .bodyBold))
            doc.append(styled("\(secret.purpose)\n", .body))

            doc.append(styled("Dacă expiră: ", .bodyBold))
            doc.append(styled("\(secret.impact)\n", .body))

            doc.append(styled("Unde e stocat: ", .bodyBold))
            doc.append(styled("\(secret.location.humanDescription)\n", .mono))

            if let url = secret.renewURL {
                doc.append(styled("Pagina de generare: ", .bodyBold))
                doc.append(styled("\(url.absoluteString)\n", .mono))
            }

            if !secret.requiredScopes.isEmpty {
                doc.append(styled("Permisiuni de bifat, exact acestea:\n", .bodyBold))
                for scope in secret.requiredScopes {
                    doc.append(styled("   •  \(scope)\n", .body))
                }
            }

            if !secret.mirrors.isEmpty {
                doc.append(styled("Aceeași valoare trebuie pusă și în:\n", .bodyBold))
                for mirror in secret.mirrors {
                    doc.append(styled("   •  \(mirror.label) — \(mirror.location.humanDescription)\n", .body))
                }
            }

            if !secret.afterRenewal.isEmpty {
                doc.append(styled("După înlocuire:\n", .bodyBold))
                for (index, item) in secret.afterRenewal.enumerated() {
                    doc.append(styled("   \(index + 1).  \(item)\n", .body))
                }
            }

            doc.append(styled("\n", .body))
        }

        doc.append(styled("Dacă nu ai deloc acces la aplicație\n", .heading))
        doc.append(styled(
            "Toate valorile stau în fișiere text obișnuite, în checkout-ul de surse de pe Mac (căile de mai sus). " +
            "Se pot înlocui cu orice editor: deschizi fișierul, înlocuiești valoarea dintre ghilimele, salvezi, " +
            "reconstruiești aplicația. Copiile de siguranță făcute de asistentul din aplicație stau în " +
            "~/Library/Application Support/GDCPluginManagerFurnizor/secret-backups/.\n", .body))

        return doc
    }

    // MARK: Stiluri

    private enum Style { case title, heading, body, bodyBold, caption, mono }

    private static func styled(_ text: String, _ style: Style) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 2

        var attributes: [NSAttributedString.Key: Any] = [.paragraphStyle: paragraph]
        switch style {
        case .title:
            attributes[.font] = NSFont.systemFont(ofSize: 22, weight: .bold)
            paragraph.paragraphSpacing = 4
        case .heading:
            attributes[.font] = NSFont.systemFont(ofSize: 14, weight: .semibold)
            paragraph.paragraphSpacingBefore = 12
            paragraph.paragraphSpacing = 4
        case .body:
            attributes[.font] = NSFont.systemFont(ofSize: 10.5)
        case .bodyBold:
            attributes[.font] = NSFont.systemFont(ofSize: 10.5, weight: .semibold)
        case .caption:
            attributes[.font] = NSFont.systemFont(ofSize: 9)
            attributes[.foregroundColor] = NSColor.secondaryLabelColor
        case .mono:
            attributes[.font] = NSFont.monospacedSystemFont(ofSize: 9.5, weight: .regular)
        }
        return NSAttributedString(string: text, attributes: attributes)
    }

    // MARK: Paginare

    /// Paginare cu CoreText: se taie textul pe pagini după cât încape în
    /// cadrul fiecăreia (`CTFrameGetVisibleStringRange`), nu după o estimare
    /// de înălțime — deci nicio linie nu se pierde între pagini.
    private static func render(_ text: NSAttributedString) -> Data {
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data as CFMutableData) else { return Data() }
        var mediaBox = CGRect(origin: .zero, size: pageSize)
        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { return Data() }

        let framesetter = CTFramesetterCreateWithAttributedString(text)
        let textRect = CGRect(x: margin, y: margin,
                              width: pageSize.width - margin * 2,
                              height: pageSize.height - margin * 2)
        let path = CGPath(rect: textRect, transform: nil)

        var location = 0
        var pageNumber = 1
        let total = text.length

        while location < total {
            context.beginPDFPage(nil)

            let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: location, length: 0), path, nil)
            CTFrameDraw(frame, context)

            let visible = CTFrameGetVisibleStringRange(frame)
            // Gardă împotriva unei bucle infinite: dacă pe o pagină nu încape
            // nici măcar un caracter (un stil patologic), ne oprim în loc să
            // generăm pagini goale la nesfârșit.
            guard visible.length > 0 else {
                context.endPDFPage()
                break
            }
            location += visible.length

            drawFooter(pageNumber: pageNumber, in: context)
            context.endPDFPage()
            pageNumber += 1
        }

        context.closePDF()
        return data as Data
    }

    private static func drawFooter(pageNumber: Int, in context: CGContext) {
        let footer = NSAttributedString(
            string: "GDC Plugin Manager — ghid de urgență · pagina \(pageNumber)",
            attributes: [
                .font: NSFont.systemFont(ofSize: 8),
                .foregroundColor: NSColor.tertiaryLabelColor,
            ])
        let line = CTLineCreateWithAttributedString(footer)
        context.textPosition = CGPoint(x: margin, y: margin / 2)
        CTLineDraw(line, context)
    }
}
