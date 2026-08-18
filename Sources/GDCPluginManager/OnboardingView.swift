import SwiftUI

/// Shown once, on first launch only — never blocks using the app either
/// way ("Sari peste" or "Trimite" both dismiss it for good). Keeps the
/// app's own "100% free, no account" promise (see docs/index.html)
/// literally true: this is a courtesy ask, not a gate.
struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var name = ""
    @State private var email = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "hand.wave.fill")
                .font(.system(size: 32))
                .foregroundStyle(.tint)
            Text(L.t("onboarding.title")).font(.title3).fontWeight(.semibold)
            Text(L.t("onboarding.body"))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            TextField(L.t("onboarding.name"), text: $name).textFieldStyle(.roundedBorder)
            TextField(L.t("onboarding.email"), text: $email).textFieldStyle(.roundedBorder)

            HStack {
                Button(L.t("onboarding.skip")) { finish(registered: false) }
                Spacer()
                Button(L.t("onboarding.send")) { finish(registered: true) }
                    .buttonStyle(.borderedProminent)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(28)
        .frame(width: 420)
    }

    private func finish(registered: Bool) {
        if registered {
            AnalyticsClient.registerDevice(name: name, email: email)
        }
        UserDefaults.standard.set(true, forKey: "gdcpm_onboarded")
        isPresented = false
    }
}
