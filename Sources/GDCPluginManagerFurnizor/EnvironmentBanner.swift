import SwiftUI
import GDCPluginManagerCore

/// 1.52.5: mediul e mereu vizibil, sus, ca frate în VStack (nu suprapus — Regula 24).
/// - STAGING: banner roșu.
/// - PRODUCȚIE după o sesiune STAGING: banner portocaliu, scrierile blocate până la confirmare
///   (dialogul apare singur la pornire; „Anulează” lasă aplicația fără scrieri).
/// - PRODUCȚIE confirmată: indicator permanent „PRODUCȚIE”.
struct EnvironmentBanner: View {
    @State private var pending = FurnizorEnvironment.productionConfirmationPending
    @State private var askConfirmation = FurnizorEnvironment.productionConfirmationPending

    var body: some View {
        Group {
            if FurnizorEnvironment.active == .staging {
                bar("MEDIU DE TEST — STAGING · publicările merg DOAR în repo-urile *-staging; Supabase, secretele și registrul de vânzări sunt blocate",
                    color: .red)
            } else if pending {
                HStack(spacing: GDCTokens.Space.m) {
                    Text("PRODUCȚIE — ultima sesiune a fost STAGING. Toate scrierile sunt BLOCATE până confirmi.")
                        .font(.callout.weight(.bold))
                    Button("Continuă în PRODUCȚIE…") { askConfirmation = true }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(GDCTokens.Palette.warning)
            } else {
                bar("PRODUCȚIE", color: Color(nsColor: .systemGreen))
            }
        }
        .confirmationDialog("Ultima sesiune a Furnizorului a fost STAGING (mediu de test).",
                            isPresented: $askConfirmation, titleVisibility: .visible) {
            Button("Continuă în PRODUCȚIE") {
                FurnizorEnvironment.confirmProduction()
                pending = false
            }
            Button("Anulează (rămân fără scrieri)", role: .cancel) {}
        } message: {
            Text("Acum rulezi în PRODUCȚIE: publicările ajung la clienți. Dacă voiai staging, închide aplicația și pornește-o cu scripts/furnizor-env.sh staging.")
        }
    }

    private func bar(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.callout.weight(.bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(color)
    }
}
