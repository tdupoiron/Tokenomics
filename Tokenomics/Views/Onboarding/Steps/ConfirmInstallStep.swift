import SwiftUI

/// "Tokenomics will install X" confirmation screen.
///
/// Presented before any significant install so the user explicitly consents.
/// Includes an optional command preview surface (monospaced command card) and
/// an optional footnote explaining source/runtime/disk impact.
///
/// Two actions: Continue (proceeds with the automated install) and
/// "Already have X? Skip this step" (small text-link, skips the install step).
///
/// Chrome mirrors ConnectorView: 16pt horizontal padding, borderedProminent
/// primary button.
struct ConfirmInstallStep: View {
    /// Short headline. E.g. "Install Homebrew"
    var title: String

    /// One or two sentences explaining why this is needed.
    var description: String

    /// The exact shell command Tokenomics will run, shown in a monospaced card.
    /// E.g. `/bin/bash -c "$(curl -fsSL ...)"`. Nil hides the card.
    var commandPreview: String? = nil

    /// Muted footnote below the card — source, runtime, disk impact.
    /// E.g. "We'll open Terminal and install Homebrew with your permission."
    var footnote: String? = nil

    /// Label for the skip text-link. E.g. "Already have Homebrew? Skip this step".
    var skipLabel: String = "I already have this"

    /// Label for the primary button. Defaults to "Continue" for install flows;
    /// Pattern E (API key) uses "Open [Provider]" here.
    var primaryLabel: String = "Continue"

    /// Called when the user taps the primary button — the connector should proceed.
    var onContinue: () -> Void

    /// Called when the user taps the skip link — the connector should skip this step.
    var onSkip: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                // Command preview card — dashed border monospace surface
                if let cmd = commandPreview {
                    commandCard(cmd)
                }

                // Source/runtime footnote
                if let note = footnote {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 16)

            Spacer()

            // Action stack
            VStack(spacing: 8) {
                Button(primaryLabel, action: onContinue)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)

                // TODO Step 6+: power-user escape hatch — "Or run it in Terminal yourself"
                //   would open Terminal with the command pre-filled via AppleScript.

                Button(skipLabel, action: onSkip)
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

    // MARK: - Command card

    /// Dashed-border monospaced card with a `$` prompt prefix.
    /// Matches the mockup's `.cmd-preview` pattern: `surface-2` background,
    /// dashed border, monospaced font.
    private func commandCard(_ command: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("$")
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.semibold)
                .foregroundStyle(.tertiary)
                .padding(.top, 1)

            Text(command)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(nil)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    Color(nsColor: .separatorColor),
                    style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Preview

#Preview("Install Homebrew — full chrome") {
    ConfirmInstallStep(
        title: "Install Homebrew",
        description: "Tokenomics needs Homebrew to install Claude Code. Homebrew is the standard Mac package manager — about 2 minutes to install.",
        commandPreview: "/bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"",
        footnote: "We'll open Terminal and install Homebrew with your permission. You'll be asked for your password once. This is Homebrew's official installer, straight from brew.sh.",
        skipLabel: "Already have Homebrew? Skip this step",
        onContinue: {},
        onSkip: {}
    )
    .frame(width: 360, height: 420)
}

#Preview("Install Node.js") {
    ConfirmInstallStep(
        title: "Install Node.js",
        description: "Now we'll install Node.js using Homebrew. About 30 seconds, no extra permissions needed.",
        commandPreview: "brew install node",
        footnote: "Tokenomics installs Node.js into ~/.tokenomics-cli so it stays separate from any Node you might install later.",
        skipLabel: "Already have Node.js? Skip this step",
        onContinue: {},
        onSkip: {}
    )
    .frame(width: 360, height: 380)
}

#Preview("Install Codex CLI") {
    ConfirmInstallStep(
        title: "Install Codex CLI",
        description: "Tokenomics will install OpenAI's command-line Codex tool. About 30 seconds.",
        commandPreview: "npm install -g @openai/codex",
        footnote: "Installed to ~/.tokenomics-cli — keeps Tokenomics' tools out of your global npm.",
        skipLabel: "Already have Codex? Skip this step",
        onContinue: {},
        onSkip: {}
    )
    .frame(width: 360, height: 360)
}
