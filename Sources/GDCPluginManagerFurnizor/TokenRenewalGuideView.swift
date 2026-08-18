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
                        title: "Pune-l în cod",
                        body: "Deschide Sources/GDCPluginManagerCore/PrivateCatalogAuth.swift (în GDCPluginManager, folderul de cod, nu Furnizor) și înlocuiește valoarea lui „token” cu cel nou."
                    )
                    step(
                        number: 6,
                        title: "Build + versiune nouă + republicare",
                        body: "Bumpează versiunea aplicației (Info.plist), rulează ./build_app.sh, apoi ./build_installer.sh (sau fluxul CI existent, tag vX.Y.Z). Important: clienții care au deja aplicația instalată tot folosesc token-ul VECHI până actualizează — bannerul de „versiune nouă” din aplicație îi anunță, dar dacă tot nu actualizează până expiră token-ul vechi, instalarea de produse le va da eroare de autentificare. Ideal: fă asta cu câteva săptămâni înainte de expirare, nu chiar în ultima zi."
                    )
                    step(
                        number: 7,
                        title: "Șterge token-ul vechi din GitHub",
                        body: "Din aceeași pagină (Fine-grained tokens), după ce ai confirmat că noul token funcționează (deschide clientul rebuild-uit, instalează ceva), poți șterge/revoca token-ul vechi."
                    )
                }
                .padding(24)
            }
        }
        .frame(width: 560, height: 560)
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
