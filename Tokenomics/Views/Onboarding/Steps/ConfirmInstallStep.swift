import SwiftUI

/// "Tokenomics will install X" confirmation screen.
///
/// Presented before any significant install so the user explicitly consents.
/// Two actions: Continue (proceeds with the automated install) and
/// "I already have this" (skips the install step, moves forward in the flow).
///
/// Chrome mirrors ConnectorView: 16pt horizontal padding, borderedProminent
/// primary button, plain secondary button below it. Step 5 will polish copy
/// and add the "Run this in Terminal myself" escape hatch.
struct ConfirmInstallStep: View {
    /// Short headline describing what will be installed.
    /// E.g. "Tokenomics will install Homebrew"
    var title: String

    /// One or two sentences explaining why this is needed and what it means
    /// for the user's Mac. Keep it honest and concrete.
    /// E.g. "Homebrew is a package manager for macOS. Tokenomics uses it to
    /// install Node.js — this only happens once."
    var description: String

    /// Called when the user taps "Continue" — the connector should start the install.
    var onContinue: () -> Void

    /// Called when the user taps "I already have this" — the connector should
    /// skip this install step and attempt to proceed with what's on disk.
    var onSkip: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 12) {
                // Icon row — generic install glyph until Step 5 adds provider-specific art.
                Image(systemName: "arrow.down.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 44, height: 44)
                    .foregroundStyle(.tint)
                    .padding(.bottom, 4)

                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)

                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 16)

            Spacer()

            // Action stack — same vertical rhythm as ConnectorView.actionStack.
            VStack(spacing: 10) {
                Button("Continue", action: onContinue)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)

                Button("I already have this", action: onSkip)
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview

#Preview("Confirm Install — Homebrew") {
    ConfirmInstallStep(
        title: "Tokenomics will install Homebrew",
        description: "Homebrew is a package manager for macOS. Tokenomics uses it to install Node.js — this only happens once.",
        onContinue: {},
        onSkip: {}
    )
    .frame(width: 320, height: 300)
}

#Preview("Confirm Install — Node.js") {
    ConfirmInstallStep(
        title: "Tokenomics will install Node.js",
        description: "Node.js is needed to run the Codex and Gemini CLIs. Takes about 30 seconds.",
        onContinue: {},
        onSkip: {}
    )
    .frame(width: 320, height: 300)
}
