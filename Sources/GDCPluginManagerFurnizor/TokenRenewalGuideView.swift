import SwiftUI

/// Static, always-available how-to for rotating the embedded GitHub
/// token — written so this can be done in a few minutes a year from now
/// without hunting for the steps again. Reachable anytime from the
/// toolbar, not just when the token is close to expiring.
struct TokenRenewalGuideView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Cum reînnoiesc token-ul GitHub?").font(.title2).fontWeight(.semibold)
                Spacer()
                Button("Închide") { dismiss() }
            }
            .padding(24)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    step(
                        number: 1,
                        title: "Generează un token nou",
                        body: "Pe github.com, sus-dreapta → poza de profil → Settings → în meniul din stânga, jos de tot, Developer settings → Personal access tokens → Fine-grained tokens → Generate new token."
                    )
                    step(
                        number: 2,
                        title: "Completează formularul",
                        body: "Token name: orice (ex. „gdc-plugin-manager-files 2028”). Expiration: cel mai lung interval disponibil (max. 1 an — GitHub nu permite mai mult la token-urile fine-grained). Resource owner: gordasgdc. Repository access: Only select repositories → alege DOAR „gdc-plugin-manager-files”."
                    )
                    step(
                        number: 3,
                        title: "Permisiuni (Permissions)",
                        body: "Repository permissions → Contents → Read-only. Nimic altceva nu trebuie bifat — exact ca la token-ul curent, ca să limităm ce poate face dacă ar ajunge vreodată în mâini greșite."
                    )
                    step(
                        number: 4,
                        title: "Generate token → copiază-l",
                        body: "GitHub îl arată o singură dată. Copiază-l imediat (butonul de copiere de lângă el)."
                    )
                    step(
                        number: 5,
                        title: "Pune-l în cod (comandă gata de lipit în Terminal)",
                        body: "cd ~/Developer/gdc-plugin-manager-catalog-vendor && sed -i '' 's#public static let token = \".*\"#public static let token = \"TOKENUL_TAU_NOU_AICI\"#' Sources/GDCPluginManagerCore/PrivateCatalogAuth.swift — înlocuiește TOKENUL_TAU_NOU_AICI cu tokenul copiat la pasul 4 (păstrează ghilimelele), apoi Enter."
                    )
                    step(
                        number: 6,
                        title: "Verifică, apoi bump versiune (comandă gata de lipit)",
                        body: "grep 'public static let token' Sources/GDCPluginManagerCore/PrivateCatalogAuth.swift — confirmă că apare noul token. Apoi deschide Info.plist (Client) și crește CFBundleShortVersionString + CFBundleVersion cu 1 (ex. 1.27.3 → 1.27.4), la fel în CHANGELOG.md (o linie: „Reînnoire token intern de acces la fișiere”)."
                    )
                    step(
                        number: 7,
                        title: "Build + republicare (comenzi gata de lipit, în ordine)",
                        body: "./build_app.sh && ./build_furnizor_app.sh   (rebuild ambele — regula CLAUDE.md 0). Apoi git add -A && git commit -m \"Reînnoire token GitHub intern\" && git push. În final, urcă build-ul nou pe releases/latest ca la orice release normal (build_installer.sh / fluxul CI + gh release upload)."
                    )
                    step(
                        number: 8,
                        title: "Confirmă + curăță",
                        body: "Deschide clientul rebuild-uit, instalează orice produs din catalog — dacă merge, tokenul nou funcționează. Abia apoi șterge/revocă tokenul vechi din GitHub (pasul văzut la generare, secțiunea Fine-grained tokens). Important: clienții deja instalați tot folosesc tokenul VECHI până actualizează — dacă acesta expiră înainte ca ei să updateze, le va da eroare de autentificare la instalare de produse. Fă asta cu câteva săptămâni înainte de expirare, nu în ultima zi."
                    )
                }
                .padding(24)
            }
        }
        .frame(width: 620, height: 660)
    }

    private func step(number: Int, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text("\(number)")
                .font(.system(.body, design: .rounded).weight(.bold))
                .frame(width: 26, height: 26)
                .background(Circle().fill(Color.accentColor.opacity(0.15)))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(body).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
