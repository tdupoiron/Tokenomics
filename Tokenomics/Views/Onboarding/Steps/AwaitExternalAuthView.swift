import SwiftUI

/// "We're waiting for your successful login" screen shown while Terminal is open
/// and Tokenomics polls for `~/.claude/.credentials.json`.
///
/// Window 5 of the Anthropic / Claude Code flow. The user has left to finish
/// Anthropic's wizard in Terminal; this screen keeps them oriented and gives
/// them a manual check-now escape hatch in case the file appeared before the
/// next poll tick.
///
/// Includes a static terminal mini-preview showing the Claude Code chat prompt
/// with the caption "When your Terminal looks like this, you're signed in."
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

                // Terminal mini-preview + caption
                VStack(spacing: 8) {
                    terminalMiniPreview
                    Text("When your Terminal looks like this, you're signed in.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

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

    // MARK: - Terminal mini-preview

    /// Static styled rectangle showing Claude Code's startup chat prompt.
    /// Not a live terminal embed — this is a visual cue so the user knows
    /// what "done" looks like in Terminal.
    private var terminalMiniPreview: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Fake terminal title bar
            HStack(spacing: 5) {
                Circle().fill(Color(nsColor: .systemRed)).frame(width: 8, height: 8)
                Circle().fill(Color(nsColor: .systemYellow)).frame(width: 8, height: 8)
                Circle().fill(Color(nsColor: .systemGreen)).frame(width: 8, height: 8)
                Spacer()
                Text("Terminal — claude")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                // Balance
                Circle().opacity(0).frame(width: 8 * 3 + 5 * 2, height: 8)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color(nsColor: .separatorColor).opacity(0.5))

            // Terminal content body
            VStack(alignment: .leading, spacing: 2) {
                monoLine("  ██████╗ ██╗      █████╗ ██╗   ██╗██████╗ ███████╗", color: .secondary)
                monoLine("  ██╔════╝██║     ██╔══██╗██║   ██║██╔══██╗██╔════╝", color: .secondary)
                monoLine("  ██║     ██║     ███████║██║   ██║██║  ██║█████╗  ", color: .secondary)
                monoLine("  ╚██████╗███████╗██║  ██║╚██████╔╝██████╔╝███████╗", color: .secondary)
                monoLine("  ╚══════╝╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚═════╝ ╚══════╝", color: .secondary)
                    .padding(.bottom, 4)
                monoLine("  > How can I help you today?", color: .primary)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .background(Color.black.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
        )
    }

    private func monoLine(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 7, design: .monospaced))
            .foregroundStyle(color == .primary ? Color.green.opacity(0.9) : Color.white.opacity(0.35))
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
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
    .frame(width: 320, height: 440)
}
