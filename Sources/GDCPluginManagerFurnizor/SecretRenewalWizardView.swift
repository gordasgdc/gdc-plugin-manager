import SwiftUI

/// Asistentul de reînnoire a unui secret, pas cu pas — gândit pentru
/// situația în care nu ai pe nimeni și nimic de întrebat: fără internet
/// pentru documentație, fără AI, doar aplicația și tu.
///
/// Fiecare pas face un singur lucru, în ordinea în care se face și în
/// realitate. Pasul de salvare NU scrie nimic până când valoarea nouă nu a
/// fost verificată printr-un apel real — vezi `SecretValidator` pentru de ce.
struct SecretRenewalWizardView: View {
    let secret: ManagedSecret
    @Environment(\.dismiss) private var dismiss

    @State private var step = 1
    @State private var newValue = ""
    @State private var isValidating = false
    @State private var validation: ValidationResult?
    @State private var writeReport: [WriteOutcome] = []
    @State private var writeFailed = false
    @State private var mirrorSelection: Set<String> = []
    @State private var doneSteps: Set<Int> = []

    private struct WriteOutcome: Identifiable {
        let id = UUID()
        let target: String
        let ok: Bool
        let note: String
    }

    private var totalSteps: Int { 4 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    switch step {
                    case 1: stepGenerate
                    case 2: stepPermissions
                    case 3: stepPaste
                    default: stepAfter
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Divider()
            footer
        }
        .frame(width: 660, height: 620)
        .onAppear {
            // Implicit se actualizează TOATE oglinzile: varianta în care una
            // rămâne pe valoarea veche e exact defectul pe care modulul ăsta
            // există ca să-l prevină.
            mirrorSelection = Set(secret.mirrors.map(\.label))
        }
    }

    // MARK: Antet & subsol

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Reînnoire: \(secret.name)").font(.title3).fontWeight(.semibold)
                    Text("Pasul \(step) din \(totalSteps)").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Închide") { dismiss() }
            }
            ProgressView(value: Double(step), total: Double(totalSteps))
        }
        .padding(20)
    }

    private var footer: some View {
        HStack {
            if step > 1 {
                Button("Înapoi") { step -= 1 }
            }
            Spacer()
            switch step {
            case 1, 2:
                Button("Continuă") { step += 1 }.keyboardShortcut(.defaultAction)
            case 3:
                if secret.location.isWritableFromApp {
                    Button(isValidating ? "Se verifică…" : "Verifică și salvează") {
                        Task { await validateAndSave() }
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(isValidating || newValue.isEmpty)
                } else {
                    Button("Continuă") { step += 1 }.keyboardShortcut(.defaultAction)
                }
            default:
                Button("Gata") { dismiss() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
    }

    // MARK: Pasul 1 — generează

    private var stepGenerate: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("1. Generează valoarea nouă")
            Text(secret.purpose).font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let url = secret.renewURL {
                Link(destination: url) {
                    Label("Deschide pagina de generare", systemImage: "arrow.up.right.square")
                        .font(.headline)
                }
                Text(url.absoluteString)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                Text("Dacă ești pe alt dispozitiv, tastează adresa de mai sus — sau folosește ghidul PDF exportat din dashboard.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Text("Acest secret nu se generează dintr-o pagină web — urmează pașii de mai jos.")
                    .font(.callout)
            }

            calloutBox(title: "Dacă expiră", text: secret.impact, color: .orange)
        }
    }

    // MARK: Pasul 2 — permisiuni

    private var stepPermissions: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("2. Bifează exact aceste permisiuni")
            if secret.requiredScopes.isEmpty {
                Text("Nu sunt permisiuni de ales pentru acest secret.")
                    .font(.callout).foregroundStyle(.secondary)
            } else {
                ForEach(Array(secret.requiredScopes.enumerated()), id: \.offset) { _, scope in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "checkmark.square").foregroundStyle(.tint)
                        Text(scope).font(.callout).fixedSize(horizontal: false, vertical: true)
                    }
                }
                calloutBox(
                    title: "Mai puțin înseamnă mai sigur",
                    text: "Nu bifa nimic peste ce scrie aici. Dacă valoarea ajunge vreodată în mâini greșite, atât va putea face.",
                    color: .blue
                )
            }
        }
    }

    // MARK: Pasul 3 — lipește, verifică, salvează

    @ViewBuilder
    private var stepPaste: some View {
        if !secret.location.isWritableFromApp {
            VStack(alignment: .leading, spacing: 14) {
                sectionTitle("3. Instalează valoarea nouă")
                calloutBox(
                    title: "Nu se poate face din aplicație",
                    text: "Acest secret nu e un text dintr-un fișier, ci ceva instalat în sistem (\(secret.location.humanDescription)). "
                        + "Instalează-l pe calea lui obișnuită — pentru certificate: Xcode → Settings → Accounts → Manage Certificates, "
                        + "sau dublu-click pe fișierul descărcat de pe portalul Apple. Apoi întoarce-te și apasă „Reverifică tot" + "” în dashboard.",
                    color: .blue
                )
            }
        } else {
            pasteForm
        }
    }

    private var pasteForm: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("3. Lipește valoarea nouă")
            SecureField("Lipește aici", text: $newValue)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))

            Text("Se verifică printr-un apel real înainte de a fi salvată. Nimic nu se scrie dacă verificarea nu trece.")
                .font(.caption).foregroundStyle(.secondary)

            if !secret.mirrors.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Actualizează aceeași valoare și în:")
                        .font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
                    ForEach(secret.mirrors, id: \.label) { mirror in
                        Toggle(isOn: Binding(
                            get: { mirrorSelection.contains(mirror.label) },
                            set: { on in
                                if on { mirrorSelection.insert(mirror.label) }
                                else { mirrorSelection.remove(mirror.label) }
                            }
                        )) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(mirror.label).font(.callout)
                                Text(mirror.location.humanDescription)
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            if let validation {
                calloutBox(
                    title: validation.ok ? "Verificare trecută" : "Verificare picată",
                    text: validation.message,
                    color: validation.ok ? .green : .red
                )
            }

            if !writeReport.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Rezultatul scrierii").font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
                    ForEach(writeReport) { outcome in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: outcome.ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(outcome.ok ? .green : .red)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(outcome.target).font(.callout)
                                Text(outcome.note).font(.caption).foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: Pasul 4 — ce urmează

    private var stepAfter: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("4. Ce mai trebuie făcut")

            if writeFailed {
                calloutBox(
                    title: "Nu toate scrierile au reușit",
                    text: "Vezi pasul anterior. Rezolvă locurile marcate cu roșu înainte de a continua — o valoare pusă doar pe jumătate e mai greu de depanat decât una deloc schimbată.",
                    color: .red
                )
            }

            if secret.afterRenewal.isEmpty {
                Text("Nimic altceva — schimbarea are efect imediat.")
                    .font(.callout)
            } else {
                Text("Bifează pe măsură ce le faci. Lista rămâne aici cât timp fereastra e deschisă.")
                    .font(.caption).foregroundStyle(.secondary)
                ForEach(Array(secret.afterRenewal.enumerated()), id: \.offset) { index, item in
                    Toggle(isOn: Binding(
                        get: { doneSteps.contains(index) },
                        set: { on in if on { doneSteps.insert(index) } else { doneSteps.remove(index) } }
                    )) {
                        Text(item).font(.callout).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    // MARK: Acțiunea

    private func validateAndSave() async {
        isValidating = true
        writeReport = []
        defer { isValidating = false }

        let result = await SecretValidator.validate(newValue, kind: secret.validation)
        validation = result
        guard result.ok else { return }

        var report: [WriteOutcome] = []

        // Locul principal întâi: dacă acesta pică, oglinzile n-au ce oglindi.
        do {
            let backup = try SecretWriter.write(newValue, to: secret.location)
            let note = backup.map { "Salvat. Copie de siguranță: \($0.lastPathComponent)" } ?? "Salvat."
            report.append(WriteOutcome(target: secret.location.humanDescription, ok: true, note: note))
        } catch {
            report.append(WriteOutcome(target: secret.location.humanDescription, ok: false,
                                       note: error.localizedDescription))
            writeReport = report
            writeFailed = true
            return
        }

        for mirror in secret.mirrors where mirrorSelection.contains(mirror.label) {
            do {
                try SecretWriter.write(newValue, to: mirror.location)
                report.append(WriteOutcome(target: mirror.label, ok: true, note: "Actualizat."))
            } catch {
                report.append(WriteOutcome(target: mirror.label, ok: false, note: error.localizedDescription))
            }
        }

        writeReport = report
        writeFailed = report.contains { !$0.ok }

        // Starea din dashboard trebuie să reflecte imediat ce tocmai s-a
        // schimbat — altfel rămâne afișată expirarea tokenului vechi.
        await SecretRegistry.shared.refreshAll()
        step = 4
    }

    // MARK: Elemente comune

    private func sectionTitle(_ text: String) -> some View {
        Text(text).font(.headline)
    }

    private func calloutBox(title: String, text: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).fontWeight(.semibold).foregroundStyle(color)
            Text(text).font(.callout).fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.10)))
    }
}
