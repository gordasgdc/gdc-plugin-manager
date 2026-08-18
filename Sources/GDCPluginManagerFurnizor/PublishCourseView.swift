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

                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
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
            Button("Șterge definitiv", role: .destructive) { Task { await delete() } }
            Button("Anulează", role: .cancel) { pendingDelete = nil }
        }
        .task { loadExisting() }
    }

    private var isFormValid: Bool {
        !id.trimmingCharacters(in: .whitespaces).isEmpty
            && !name.trimmingCharacters(in: .whitespaces).isEmpty
            && !options.isEmpty
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
    }

    private func publish() async {
        errorMessage = nil
        successMessage = nil
        isBusy = true
        defer { isBusy = false }

        let course = Course(
            id: id.trimmingCharacters(in: .whitespaces), name: name,
            description: description, options: options
        )

        do {
            try GitOps.pull(at: RepoCheckoutPaths.publicCatalogRepo)
            try CatalogEditor.upsertCourse(course)
            try GitOps.commitAndPush(at: RepoCheckoutPaths.publicCatalogRepo, message: "Curs: \(course.name)")
            successMessage = "„\(course.name)” e publicat — apare la clienți la următorul refresh de catalog."
            clearForm()
            loadExisting()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func delete() async {
        guard let course = pendingDelete else { return }
        pendingDelete = nil
        errorMessage = nil
        successMessage = nil
        isBusy = true
        defer { isBusy = false }

        do {
            try GitOps.pull(at: RepoCheckoutPaths.publicCatalogRepo)
            try CatalogEditor.removeCourse(id: course.id)
            try GitOps.commitAndPush(at: RepoCheckoutPaths.publicCatalogRepo, message: "Sterg cursul: \(course.name)")
            successMessage = "„\(course.name)” a fost șters."
            if editingID == course.id { clearForm() }
            loadExisting()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
