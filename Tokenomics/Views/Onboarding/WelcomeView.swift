import SwiftUI

/// First-launch screen — replaces the old OnboardingView's full-list layout
/// with a single-CTA welcome. Hero ring + serif headline + value prop +
/// Get Started button + privacy disclosure.
///
/// Routes to ProviderChooserView when the user taps Get Started.
struct WelcomeView: View {
    var onGetStarted: () -> Void
    var onSkip: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 14) {
                WelcomeRingView()
                    .padding(.top, 24)

                // Mockup: 28px serif headline + subtitle lede
                VStack(spacing: 6) {
                    Text("Track your AI usage.")
                        .font(.title2)
                        .fontDesign(.serif)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)

                    Text("At a glance, from the menu bar.")
                        .scaledFont(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Text("Works with Claude, Codex, Gemini, Copilot, Cursor, and more.")
                        .scaledFont(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Button("Get Started", action: onGetStarted)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .padding(.top, 8)

                privacyDisclosure
                    .padding(.top, 6)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 24)
        }
    }

    // MARK: - Privacy disclosure

    /// Replaces the old provider list footer. Gives first-time users the
    /// privacy framing the mockup emphasizes — local reads, no egress.
    /// Uses AttributedString so the "Learn more →" link sits inline with
    /// the static text without a separate layout container.
    private var privacyDisclosure: some View {
        Text(disclosureString)
            .scaledFont(.caption2)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .environment(\.openURL, OpenURLAction { url in
                NSWorkspace.shared.open(url)
                return .handled
            })
    }

    private var disclosureString: AttributedString {
        var base = AttributedString("Tokenomics reads usage data locally. Your tokens never leave your Mac.  ")
        base.foregroundColor = .secondary

        var link = AttributedString("Learn more →")
        link.foregroundColor = .accentColor
        link.link = URL(string: "https://trytokenomics.com")

        return base + link
    }
}
