import SwiftUI

/// "Checking your Mac…" screen shown while prerequisite detection runs.
///
/// This is a read-only display — the connector's view model drives detection
/// and advances past this screen automatically. There are no buttons here.
///
/// Layout follows mockup section 3 "Detect" — headline + lede centered, spinner.
/// The full checklist (Homebrew / Node / CLI status rows) is a deferred post-beta
/// feature; a spinner is acceptable for the current release.
struct DetectStep: View {
    /// Displayed below the spinner. E.g. "Checking for Homebrew, Node.js,
    /// and the Codex CLI…"
    var message: String

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: Tokens.Spacing.s3) {
                ProgressView()
                    .controlSize(.large)
                    .padding(.bottom, Tokens.Spacing.s1)

                // Headline — mockup: h-sans h2
                Text("Checking your Mac…")
                    .font(Tokens.Typography.Onboarding.h2)
                    .foregroundStyle(Tokens.Color.text(scheme))
                    .multilineTextAlignment(.center)

                // Sub-message — mockup: .lede color text-muted
                Text(message)
                    .font(Tokens.Typography.Onboarding.lede)
                    .foregroundStyle(Tokens.Color.textMuted(scheme))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Tokens.Spacing.s5)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview

#Preview("Detect Step — light") {
    DetectStep(message: "Checking for Homebrew, Node.js, and the Codex CLI…")
        .frame(width: 680, height: 580)
        .background(Tokens.DynamicColor.bg)
    .preferredColorScheme(.light)
}

#Preview("Detect Step — dark") {
    DetectStep(message: "Checking for Homebrew, Node.js, and the Codex CLI…")
        .frame(width: 680, height: 580)
        .background(Tokens.DynamicColor.bg)
        .preferredColorScheme(.dark)
}
