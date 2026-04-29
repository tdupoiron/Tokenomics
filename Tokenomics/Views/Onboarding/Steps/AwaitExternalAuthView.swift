import SwiftUI

/// "We're waiting for your successful login" screen shown while Terminal is open
/// and Tokenomics polls for `~/.claude/.credentials.json`.
///
/// Window 5 of the Anthropic / Claude Code flow. The user has left to finish
/// Anthropic's wizard in Terminal; this screen keeps them oriented and gives
/// them a manual check-now escape hatch in case the file appeared before the
/// next poll tick.
///
/// Chrome matches `ConfirmInstallStep` and `PreviewExternalStepsView`:
/// 16pt horizontal padding, same button stack. Step 5 will add the terminal
/// preview decoration visible in the mockup (the "you're done when you see this"
/// cue with the stylized Claude Code chat prompt).
struct AwaitExternalAuthView: View {
    /// Short headline. E.g. "Confirm login".
    var headline: String

    /// Instruction paragraph shown below the headline.
    var instructionText: String

    /// Called when the user taps "I'm signed in — check now".
    var onCheckNow: () -> Void

    /// Called when the user taps Back. Optional — omit to hide the back button.
    var onBack: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 16) {
                // Spinner — signals active polling
                ProgressView()
                    .controlSize(.large)
                    .padding(.bottom, 4)

                // Headline
                Text(headline)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)

                // Body
                Text(instructionText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                // Polling caption
                pollingCaption
            }
            .padding(.horizontal, 20)

            Spacer()

            // Action stack
            VStack(spacing: 10) {
                Button("I'm signed in — check now", action: onCheckNow)
                    .buttonStyle(.bordered)
                    .controlSize(.regular)

                if let onBack {
                    Button("← Back", action: onBack)
                        .buttonStyle(.plain)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Polling caption

    private var pollingCaption: some View {
        HStack(spacing: 6) {
            ProgressView()
                .controlSize(.mini)
            Text("Watching ")
                .font(.caption)
                .foregroundStyle(.secondary)
            + Text("~/.claude")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
            + Text(" for authentication…")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .quaternaryLabelColor).opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Preview

#Preview("Window 5 — Awaiting auth") {
    AwaitExternalAuthView(
        headline: "Confirm login",
        instructionText: "We're waiting for your successful login. You'll know you're done when you see Claude's chat prompt — close Terminal then and come back here.",
        onCheckNow: {},
        onBack: {}
    )
    .frame(width: 320, height: 340)
}
