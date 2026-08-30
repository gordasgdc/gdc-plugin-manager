import SwiftUI

/// Panou nou (2026-08-30): "Pricing Manager" — programează dinainte
/// mai multe ferestre de preț per aplicație ("1-15 sept: preț X, Black
/// Friday: preț Y, Crăciun: preț Z"), fără nicio recompilare — aplicația
/// alege singură fereastra activă la momentul respectiv. Vezi PricingModel/
/// PricingEditor + PricingChecker (portat în fiecare aplicație client).
struct PricingManagerView: View {
    @State private var catalog: PricingCatalog?
    @State private var loadError: String?
    @State private var isPublishing = false
    @State private var publishError: String?
    @State private var lastPublishedAt: Date?

    @State private var selectedProductID: String?
    @State private var draftBasePrice: String = ""
    @State private var draftSchedule: [PricingPromo] = []
    @State private var showAddSheet = false

    var body: some View {
        HSplitView {
            productList
                .frame(minWidth: 260, idealWidth: 300)
            detailPane
                .frame(minWidth: 420, maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear(perform: reload)
    }

    private var productList: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Pricing Manager").font(.title2).bold()
                Spacer()
                Button { reload() } label: { Image(systemName: "arrow.clockwise") }
                    .help("Reîncarcă din pricing.json (git pull)")
            }
            .padding()

            if let loadError {
                Text(loadError).foregroundStyle(.red).font(.caption).padding(.horizontal)
            }

            List(selection: $selectedProductID) {
                ForEach(gdcStandaloneProducts) { product in
                    let pricing = catalog?.products[product.id]
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(product.name).bold()
                            if let pricing {
                                if let active = pricing.activePromo {
                                    Text("🔥 \(formatPrice(active.price, pricing.currency)) — \(active.label)")
                                        .font(.caption).foregroundStyle(.orange)
                                } else if let next = pricing.nextScheduledPromo {
                                    Text("\(formatPrice(pricing.basePrice, pricing.currency)) · „\(next.label)” programată \(next.startsAt.formatted(date: .abbreviated, time: .omitted))")
                                        .font(.caption).foregroundStyle(.secondary)
                                } else {
                                    Text(formatPrice(pricing.basePrice, pricing.currency))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            } else {
                                Text("Neconfigurat încă în pricing.json").font(.caption).foregroundStyle(.orange)
                            }
                        }
                        Spacer()
                    }
                    .tag(product.id)
                    .contentShape(Rectangle())
                }
            }
        }
        .onChange(of: selectedProductID) { _, newValue in
            loadDraft(for: newValue)
        }
    }

    @ViewBuilder
    private var detailPane: some View {
        if let id = selectedProductID, let product = gdcStandaloneProducts.first(where: { $0.id == id }) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(product.name).font(.title3).bold()
                    Text("productID: \(id)").font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)

                    Divider()

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Preț de bază (donație)").font(.headline)
                        HStack {
                            TextField("23", text: $draftBasePrice)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 100)
                            Text("EUR — folosit când nicio fereastră programată nu e activă.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }

                    Divider()

                    HStack {
                        Text("Program de oferte").font(.headline)
                        Spacer()
                        Button {
                            showAddSheet = true
                        } label: {
                            Label("Adaugă fereastră", systemImage: "plus.circle")
                        }
                    }
                    Text("Poți adăuga oricâte perioade dinainte — luna asta un preț, în Black Friday altul, de Crăciun altul. Aplicația comută automat la ora exactă, fără să te mai întorci să schimbi ceva.")
                        .font(.caption).foregroundStyle(.secondary)

                    if draftSchedule.isEmpty {
                        Text("Nicio fereastră programată — se folosește mereu prețul de bază.")
                            .font(.caption).foregroundStyle(.secondary).padding(.vertical, 4)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(sortedDraftSchedule) { promo in
                                scheduleRow(promo)
                            }
                        }
                    }

                    Divider()

                    if let publishError {
                        Text(publishError).foregroundStyle(.red).font(.caption)
                    }
                    if let lastPublishedAt {
                        Text("Publicat la \(lastPublishedAt.formatted(date: .omitted, time: .standard)) — vizibil pe toate aplicațiile în câteva secunde/minute (verifică la lansarea aplicației).")
                            .font(.caption).foregroundStyle(.green)
                    }

                    HStack {
                        Button("Anulează modificările") { loadDraft(for: id) }
                        Spacer()
                        Button {
                            publish(productID: id, name: product.name)
                        } label: {
                            if isPublishing {
                                ProgressView().controlSize(.small)
                            } else {
                                Text("Publică (git push)")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isPublishing || Double(draftBasePrice.replacingOccurrences(of: ",", with: ".")) == nil)
                    }
                }
                .padding(24)
            }
            .sheet(isPresented: $showAddSheet) {
                AddPromoWindowSheet { newPromo in
                    draftSchedule.append(newPromo)
                }
            }
        } else {
            VStack {
                Spacer()
                Text("Alege o aplicație din listă").foregroundStyle(.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var sortedDraftSchedule: [PricingPromo] {
        draftSchedule.sorted { $0.startsAt < $1.startsAt }
    }

    @ViewBuilder
    private func scheduleRow(_ promo: PricingPromo) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    if promo.isActiveNow {
                        Text("ACTIV ACUM").font(.caption2.bold()).foregroundStyle(.white)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.orange, in: Capsule())
                    }
                    Text(promo.label).bold()
                    if promo.showCountdown { Image(systemName: "timer").foregroundStyle(.secondary) }
                }
                Text("\(formatNumber(promo.price)) EUR · \(promo.startsAt.formatted(date: .abbreviated, time: .shortened)) → \(promo.endsAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button(role: .destructive) {
                draftSchedule.removeAll { $0.id == promo.id }
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(promo.isActiveNow ? Color.orange.opacity(0.12) : Color.gray.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }

    private func reload() {
        loadError = nil
        do {
            try GitOps.pull(at: RepoCheckoutPaths.publicCatalogRepo)
            catalog = try PricingEditor.load()
        } catch {
            // pricing.json poate lipsi la prima rulare pe o masina noua -
            // nu tratam asta ca eroare blocanta, doar afisam un catalog gol.
            catalog = catalog ?? PricingCatalog(updatedAt: "", products: [:])
            loadError = "Nu am putut sincroniza din git: \(error.localizedDescription)"
        }
        if let id = selectedProductID { loadDraft(for: id) }
    }

    private func loadDraft(for id: String?) {
        publishError = nil
        lastPublishedAt = nil
        guard let id, let pricing = catalog?.products[id] else {
            draftBasePrice = ""
            draftSchedule = []
            return
        }
        draftBasePrice = formatNumber(pricing.basePrice)
        draftSchedule = pricing.promoSchedule
    }

    private func publish(productID: String, name: String) {
        guard let base = Double(draftBasePrice.replacingOccurrences(of: ",", with: ".")) else { return }

        var updated = catalog ?? PricingCatalog(updatedAt: "", products: [:])
        let existingCurrency = updated.products[productID]?.currency ?? "EUR"
        updated.products[productID] = ProductPricing(name: name, basePrice: base, currency: existingCurrency, promoSchedule: draftSchedule)

        isPublishing = true
        publishError = nil
        let scheduleCount = draftSchedule.count
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try PricingEditor.publish(updated, message: "Pricing: \(name) — bază \(base) EUR, \(scheduleCount) fereastr\(scheduleCount == 1 ? "ă" : "e") programată")
                DispatchQueue.main.async {
                    catalog = updated
                    isPublishing = false
                    lastPublishedAt = Date()
                }
            } catch {
                DispatchQueue.main.async {
                    isPublishing = false
                    publishError = "Publicarea a eșuat: \(error.localizedDescription)"
                }
            }
        }
    }

    private func formatPrice(_ value: Double, _ currency: String) -> String {
        "\(formatNumber(value)) \(currency == "EUR" ? "€" : currency)"
    }

    private func formatNumber(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(value)) : String(value)
    }
}

/// Foaie separată pentru adăugarea unei ferestre noi — ținută simplă,
/// validează local înainte să adauge în draft (publicarea efectivă rămâne
/// la butonul "Publică" din view-ul părinte).
private struct AddPromoWindowSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onAdd: (PricingPromo) -> Void

    @State private var price: String = ""
    @State private var label: String = ""
    @State private var startsAt = Date()
    @State private var endsAt = Date().addingTimeInterval(4 * 86400)
    @State private var showCountdown = false

    private var isValid: Bool {
        Double(price.replacingOccurrences(of: ",", with: ".")) != nil
            && !label.trimmingCharacters(in: .whitespaces).isEmpty
            && endsAt > startsAt
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Fereastră nouă de preț").font(.title3).bold()

            HStack {
                Text("Preț:")
                TextField("15", text: $price).textFieldStyle(.roundedBorder).frame(width: 100)
                Text("EUR")
            }
            HStack {
                Text("Etichetă:")
                TextField("Black Friday -35%", text: $label).textFieldStyle(.roundedBorder)
            }
            DatePicker("Începe:", selection: $startsAt)
            DatePicker("Se termină:", selection: $endsAt)
            if endsAt <= startsAt {
                Label("Data de final trebuie să fie după data de început.", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption).foregroundStyle(.orange)
            }
            Toggle("Arată countdown live în aplicație", isOn: $showCountdown)
            Text("Creează urgență (\"Se termină în 2z 14h\") — util pentru Black Friday; lasă dezactivat pentru o reducere liniștită.")
                .font(.caption).foregroundStyle(.secondary)

            HStack {
                Button("Anulează") { dismiss() }
                Spacer()
                Button("Adaugă") {
                    guard let p = Double(price.replacingOccurrences(of: ",", with: ".")) else { return }
                    onAdd(PricingPromo(price: p, label: label, startsAt: startsAt, endsAt: endsAt, showCountdown: showCountdown))
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isValid)
            }
        }
        .padding(24)
        .frame(width: 420)
    }
}
