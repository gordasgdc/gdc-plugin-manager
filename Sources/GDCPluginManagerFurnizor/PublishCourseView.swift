import SwiftUI
import GDCPluginManagerCore

/// Manages the "Cursuri" catalog section — bookable sessions, not
/// downloadable products. No files, no license, no private repo
/// involved at all; this only ever touches docs/catalog.json in the
/// public repo checkout.
struct PublishCourseView: View {
    @State private var existingCourses: [Course] = []
    @State private var editingID: String?

    @State private var id = ""
    @State private var name = ""
    @State private var description = ""
    @State private var options: [CourseOption] = []
    @State private var newOptionLabel = ""
    @State private var newOptionPrice = ""
    /// Coperta cursului. Preset `.cover` — se vede în preview mărit.
    @State private var coverSelection: CoverImageSelection = .none
    // Etapa 4 (2026-08-29) — valabilitate temporală opțională.
    @State private var scheduling: Scheduling?
    // Rețele sociale opționale (2026-08-29) — vezi SocialLinksEditor.swift.
    @State private var socialForm = SocialLinksFormState()

    @State private var isBusy = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var pendingDelete: Course?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Cursuri").font(.title2).fontWeight(.semibold)

                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        TextField("ID curs (ex. curs-color-grading, nu se mai poate schimba)", text: $id)
                            .textFieldStyle(.roundedBorder)
                            .disabled(editingID != nil)
                        TextField("Nume", text: $name).textFieldStyle(.roundedBorder)
                        TextField("Descriere", text: $description).textFieldStyle(.roundedBorder)

                        Divider()
                        Text("Opțiuni (durată / tip + preț)").font(.subheadline).fontWeight(.medium)

                        ForEach(options) { option in
                            HStack {
                                Text(option.label)
                                Spacer()
                                Text(option.priceDisplay).foregroundStyle(.secondary)
                                Button(role: .destructive) {
                                    options.removeAll { $0.id == option.id }
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.red)
                            }
                        }

                        HStack {
                            TextField("ex. 1 oră, 2 ore, 1 la 1…", text: $newOptionLabel)
                                .textFieldStyle(.roundedBorder)
                            TextField("Preț (EUR)", text: $newOptionPrice)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: 120)
                            Button("Adaugă") { addOption() }
                                .disabled(newOptionLabel.trimmingCharacters(in: .whitespaces).isEmpty || Double(newOptionPrice) == nil)
                        }
                    }
                    .padding(8)
                }

                CoverImagePicker(preset: .cover, selection: $coverSelection)
                SchedulingPicker(scheduling: $scheduling)
                SocialLinksSection(state: $socialForm)

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                if let successMessage {
                    Label(successMessage, systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                }

                HStack {
                    if isBusy { ProgressView().controlSize(.small) }
                    Button(editingID == nil ? "Publică" : "Actualizează") { Task { await publish() } }
                        .disabled(isBusy || !isFormValid)
                    if editingID != nil {
                        Button("Curs nou") { clearForm() }
                    }
                }
                if !isFormValid && !isBusy {
                    Text(validationHint).font(.caption).foregroundStyle(.orange)
                }

                if !existingCourses.isEmpty {
                    Divider()
                    Text("Cursuri publicate").font(.headline)
                    ForEach(existingCourses) { course in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(course.name).fontWeight(.medium)
                                Text("\(course.options.count) opțiune(i)").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Editează") { load(course) }
                            Button("Șterge", role: .destructive) { pendingDelete = course }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(24)
            .frame(maxWidth: 640, alignment: .leading)
        }
        .confirmationDialog(
            "Ștergi definitiv cursul „\(pendingDelete?.name ?? "")”?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Șterge definitiv", role: .destructive) {
                let toDelete = pendingDelete
                Task { await delete(toDelete) }
            }
            Button("Anulează", role: .cancel) { pendingDelete = nil }
        }
        .task { loadExisting() }
    }

    private var isFormValid: Bool {
        !id.trimmingCharacters(in: .whitespaces).isEmpty
            && !name.trimmingCharacters(in: .whitespaces).isEmpty
            && !options.isEmpty
    }

    private var validationHint: String {
        var missing: [String] = []
        if id.trimmingCharacters(in: .whitespaces).isEmpty { missing.append("ID") }
        if name.trimmingCharacters(in: .whitespaces).isEmpty { missing.append("Nume") }
        if options.isEmpty { missing.append("Minim o opțiune de preț (adaugă cu butonul de adăugare opțiune)") }
        return "Lipsește: " + missing.joined(separator: ", ")
    }

    private func addOption() {
        guard let price = Double(newOptionPrice) else { return }
        options.append(CourseOption(label: newOptionLabel.trimmingCharacters(in: .whitespaces), priceEUR: price))
        newOptionLabel = ""
        newOptionPrice = ""
    }

    private func loadExisting() {
        if let catalog = try? CatalogEditor.load() {
            existingCourses = catalog.courses.sorted { $0.name < $1.name }
        }
    }

    private func load(_ course: Course) {
        editingID = course.id
        id = course.id
        name = course.name
        description = course.description
        options = course.options
        // `.existing`: imaginea e deja publicată, nu se rescrie dacă
        // furnizorul n-o atinge.
        coverSelection = course.coverImage.map { .existing($0) } ?? .none
        scheduling = course.scheduling
        socialForm = SocialLinksFormState(course.socialLinks)
        successMessage = nil
        errorMessage = nil
    }

    private func clearForm() {
        editingID = nil
        id = ""
        name = ""
        description = ""
        options = []
        newOptionLabel = ""
        newOptionPrice = ""
        coverSelection = .none
        scheduling = nil
        socialForm.reset()
    }

    private func publish() async {
        errorMessage = nil
        successMessage = nil
        isBusy = true
        defer { isBusy = false }

        let courseID = id.trimmingCharacters(in: .whitespaces)

        do {
            // Pull ÎNAINTE de a scrie coperta pe disc, ca fișierul nou să nu
            // fie prins într-un merge cu ce s-a publicat între timp.
            try GitOps.pull(at: RepoCheckoutPaths.publicCatalogRepo)

            // Coperta se scrie în docs/covers/ ÎNAINTE de commit, altfel
            // catalogul ar referi o imagine încă nepublicată (404 la clienți
            // până la următorul push) — vezi WARNING în CoverImageStore.
            let previousCover = existingCourses.first { $0.id == courseID }?.coverImage
            let coverImage = try CoverImageStore.commit(coverSelection, id: courseID, previous: previousCover)

            let course = Course(
                id: courseID, name: name,
                description: description, options: options,
                coverImage: coverImage, scheduling: scheduling,
                socialLinks: socialForm.model
            )

            try CatalogEditor.upsertCourse(course)
            try GitOps.commitAndPush(at: RepoCheckoutPaths.publicCatalogRepo, message: "Curs: \(course.name)", paths: ["docs/catalog.json", "docs/covers"])
            successMessage = "„\(course.name)” e publicat — apare la clienți la următorul refresh de catalog."
            clearForm()
            loadExisting()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // PITFALL FIXED 2026-08-24: elementul de sters vine ca PARAMETRU,
    // capturat sincron in butonul dialogului — NU se mai citeste
    // pendingDelete aici. SwiftUI goleste pendingDelete (prin binding-ul
    // custom de mai jos, la inchiderea dialogului) in paralel cu pornirea
    // acestui Task; cine citea pendingDelete direct in delete() risca sa-l
    // gaseasca deja nil si sa iasa fara sa faca nimic — fara eroare, fara
    // mesaj, exact simptomul "apas Sterge si nu se intampla nimic".
    private func delete(_ course: Course?) async {
        guard let course else { return }
        pendingDelete = nil
        errorMessage = nil
        successMessage = nil
        isBusy = true
        defer { isBusy = false }

        do {
            try GitOps.pull(at: RepoCheckoutPaths.publicCatalogRepo)
            // Ștergem și coperta, altfel ar rămâne orfană în repo pentru
            // totdeauna (nimic n-o mai referă după ce iese din catalog).
            try CoverImageStore.commit(.none, id: course.id, previous: course.coverImage)
            try CatalogEditor.removeCourse(id: course.id)
            try GitOps.commitAndPush(at: RepoCheckoutPaths.publicCatalogRepo, message: "Sterg cursul: \(course.name)", paths: ["docs/catalog.json", "docs/covers"])
            successMessage = "„\(course.name)” a fost șters."
            if editingID == course.id { clearForm() }
            loadExisting()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
