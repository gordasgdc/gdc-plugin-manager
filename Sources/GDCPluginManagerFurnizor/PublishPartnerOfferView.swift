import SwiftUI
import GDCPluginManagerCore

/// Gestionează secțiunea "Oferte Parteneri" — Etapa 4 din Planul Integrat
/// de Upgrade v2.0 (2026-08-29). Promoții de la branduri terțe (ex.
/// discount echipament foto/video/lămpi), cu cod cupon, link magazin,
/// discount afișat ca badge, rețele sociale și valabilitate temporală.
struct PublishPartnerOfferView: View {
    @State private var existingOffers: [PartnerOffer] = []
    @State private var editingID: String?

    @State private var id = ""
    @State private var brandName = ""
    @State private var description = ""
    @State private var discountText = ""
    @State private var couponCode = ""
    @State private var url = ""
    @State private var youtubeURL = ""
    @State private var socialForm = SocialLinksFormState()
    @State private var scheduling: Scheduling?
    @State private var coverSelection: CoverImageSelection = .none

    @State private var isBusy = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var pendingDelete: PartnerOffer?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Oferte Parteneri").font(.title2).fontWeight(.semibold)
                Text("Promoții de la branduri partenere (ex. discount la echipament foto/video). Limbaj de discount/preț PERMIS aici — relație comercială cu terți, distinctă de produsele proprii GDC.")
                    .font(.caption).foregroundStyle(.secondary)

                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        TextField("ID ofertă (ex. aputure-black-friday-2026, nu se mai poate schimba)", text: $id)
                            .textFieldStyle(.roundedBorder)
                            .disabled(editingID != nil)
                        AutocompleteTextField(placeholder: "Nume brand/partener", text: $brandName,
                                               existingValues: existingOffers.map(\.brandName))
                        TextField("Link magazin/produs (https://…)", text: $url).textFieldStyle(.roundedBorder)
                        TextEditor(text: $description)
                            .frame(minHeight: 80)
                            .overlay(alignment: .topLeading) {
                                if description.isEmpty {
                                    Text("Descrierea ofertei…")
                                        .foregroundStyle(.secondary)
                                        .padding(.top, 8).padding(.leading, 5)
                                        .allowsHitTesting(false)
                                }
                            }
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(.separator))
                        HStack {
                            TextField("Badge discount (ex. -20%, SPECIAL OFFER)", text: $discountText).textFieldStyle(.roundedBorder)
                            TextField("Cod cupon (opțional)", text: $couponCode).textFieldStyle(.roundedBorder)
                        }
                        TextField("Link tutorial/prezentare YouTube (opțional)", text: $youtubeURL).textFieldStyle(.roundedBorder)

                        SocialLinksFields(state: $socialForm, youtubeLabel: "YouTube")
                    }
                    .padding(8)
                }

                CoverImagePicker(preset: .cover, selection: $coverSelection)
                SchedulingPicker(scheduling: $scheduling)
                    .id(editingID ?? "new")

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
                        Button("Ofertă nouă") { clearForm() }
                    }
                }
                // Cerut explicit (2026-08-29): butonul dezactivat, fără
                // niciun mesaj, nu spunea CE lipsește — userul nu avea
                // cum să știe de ce nu poate publica.
                if !isFormValid && !isBusy {
                    Text(validationHint).font(.caption).foregroundStyle(.orange)
                }

                if !existingOffers.isEmpty {
                    Divider()
                    Text("Oferte publicate").font(.headline)
                    ForEach(existingOffers) { offer in
                        HStack {
                            VStack(alignment: .leading) {
                                HStack(spacing: 6) {
                                    Text(offer.brandName).fontWeight(.medium)
                                    if let discountText = offer.discountText {
                                        Text(discountText.uppercased())
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 6).padding(.vertical, 2)
                                            .background(Capsule().fill(Color.red))
                                    }
                                }
                                Text(offer.url).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                            Spacer()
                            Button("Editează") { load(offer) }
                            Button("Șterge", role: .destructive) { pendingDelete = offer }
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
            "Ștergi definitiv oferta „\(pendingDelete?.brandName ?? "")”?",
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
            && !brandName.trimmingCharacters(in: .whitespaces).isEmpty
            && URL(string: url) != nil
            && (url.hasPrefix("http://") || url.hasPrefix("https://"))
    }

    /// Explică EXACT ce lipseste — butonul dezactivat fără mesaj nu
    /// spune userului dacă lipsește ID-ul, numele sau linkul greșit format.
    private var validationHint: String {
        var missing: [String] = []
        if id.trimmingCharacters(in: .whitespaces).isEmpty { missing.append("ID ofertă") }
        if brandName.trimmingCharacters(in: .whitespaces).isEmpty { missing.append("Nume brand/partener") }
        if !url.hasPrefix("http://") && !url.hasPrefix("https://") {
            missing.append("Link magazin (trebuie să înceapă cu http:// sau https://)")
        } else if URL(string: url) == nil {
            missing.append("Link magazin (format invalid)")
        }
        return "Lipsește: " + missing.joined(separator: ", ")
    }

    private func loadExisting() {
        if let catalog = try? CatalogEditor.load() {
            existingOffers = catalog.partnerOffers.sorted { $0.brandName < $1.brandName }
        }
    }

    private func load(_ offer: PartnerOffer) {
        editingID = offer.id
        id = offer.id
        brandName = offer.brandName
        description = offer.description
        discountText = offer.discountText ?? ""
        couponCode = offer.couponCode ?? ""
        url = offer.url
        youtubeURL = offer.youtubeURL ?? ""
        socialForm = SocialLinksFormState(offer.socialLinks)
        scheduling = offer.scheduling
        coverSelection = offer.coverImage.map { .existing($0) } ?? .none
        successMessage = nil
        errorMessage = nil
    }

    private func clearForm() {
        editingID = nil
        id = ""
        brandName = ""
        description = ""
        discountText = ""
        couponCode = ""
        url = ""
        youtubeURL = ""
        socialForm.reset()
        scheduling = nil
        coverSelection = .none
    }

    private func publish() async {
        errorMessage = nil
        successMessage = nil
        isBusy = true
        defer { isBusy = false }

        func nilIfEmpty(_ s: String) -> String? {
            let t = s.trimmingCharacters(in: .whitespaces)
            return t.isEmpty ? nil : t
        }
        let offerID = id.trimmingCharacters(in: .whitespaces)

        do {
            try GitOps.pull(at: RepoCheckoutPaths.publicCatalogRepo)

            let previousCover = existingOffers.first { $0.id == offerID }?.coverImage
            let coverImage = try CoverImageStore.commit(coverSelection, id: offerID, previous: previousCover)

            let offer = PartnerOffer(
                id: offerID, brandName: brandName, description: description,
                discountText: nilIfEmpty(discountText), couponCode: nilIfEmpty(couponCode),
                url: url, youtubeURL: nilIfEmpty(youtubeURL), coverImage: coverImage,
                socialLinks: socialForm.model, scheduling: scheduling
            )
            try CatalogEditor.upsertPartnerOffer(offer)
            try GitOps.commitAndPush(at: RepoCheckoutPaths.publicCatalogRepo, message: "Ofertă parteneră: \(offer.brandName)", paths: ["docs/catalog.json", "docs/covers"])
            successMessage = "„\(offer.brandName)” e publicat — apare la clienți la următorul refresh de catalog."
            clearForm()
            loadExisting()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func delete(_ offer: PartnerOffer?) async {
        guard let offer else { return }
        pendingDelete = nil
        errorMessage = nil
        successMessage = nil
        isBusy = true
        defer { isBusy = false }

        do {
            try GitOps.pull(at: RepoCheckoutPaths.publicCatalogRepo)
            try CoverImageStore.commit(.none, id: offer.id, previous: offer.coverImage)
            try CatalogEditor.removePartnerOffer(id: offer.id)
            try GitOps.commitAndPush(at: RepoCheckoutPaths.publicCatalogRepo, message: "Sterg ofertă parteneră: \(offer.brandName)", paths: ["docs/catalog.json", "docs/covers"])
            successMessage = "„\(offer.brandName)” a fost șters."
            if editingID == offer.id { clearForm() }
            loadExisting()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
