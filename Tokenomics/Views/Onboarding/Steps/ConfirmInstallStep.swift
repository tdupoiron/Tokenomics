import SwiftUI

/// "Tokenomics will install X" confirmation screen.
///
/// Presented before any significant install so the user explicitly consents.
/// Includes an optional command preview surface (monospaced command card) and
/// an optional footnote explaining source/runtime/disk impact.
///
/// Layout matches mockup section 4 (ConfirmInstall frames, lines ~1440–1644):
///   - .surface card wrapping headline + lede + .cmd-preview + footnote
///   - helper "Already have X?" text-link skip
///   - winfoot: Back ghost | Install primary
///
/// Two actions: Continue (proceeds with the automated install) and
/// "Already have X? Skip this step" (text-link, skips the install step).
struct ConfirmInstallStep: View {
    /// Short headline. E.g. "Install Homebrew"
    var title: String

    /// One or two sentences explaining why this is needed.
    var description: String

    /// The exact shell command Tokenomics will run, shown in a monospaced card.
    /// E.g. `/bin/bash -c "$(curl -fsSL ...)"`. Nil hides the card.
    var commandPreview: String? = nil

    /// Muted footnote below the card — source, runtime, disk impact.
    var footnote: String? = nil

    /// Label for the skip text-link.
    var skipLabel: String = "I already have this"

    /// Label for the primary button.
    var primaryLabel: String = "Continue"

    /// Called when the user taps the primary button.
    var onContinue: () -> Void

    /// Called when the user taps the skip link.
    var onSkip: () -> Void

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Surface card containing the headline + description + command
            // mockup .surface: bg surface, 1px border, r-md, padding 16×18
            VStack(alignment: .leading, spacing: Tokens.Spacing.s3) {
                // Headline — h2
                Text(title)
                    .font(Tokens.Typography.Onboarding.h2)
                    .foregroundStyle(Tokens.Color.text(scheme))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                // Description lede
                Text(description)
                    .font(Tokens.Typography.Onboarding.lede)
                    .foregroundStyle(Tokens.Color.textMuted(scheme))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                // "Tokenomics will run:" label + command preview card
                if let cmd = commandPreview {
                    VStack(alignment: .leading, spacing: Tokens.Spacing.s1) {
                        Text("Tokenomics will run:")
                            .font(Tokens.Typography.Onboarding.small)
                            .foregroundStyle(Tokens.Color.textMuted(scheme))
                        commandCard(cmd)
                    }
                }

                // Source/runtime footnote
                if let note = footnote {
                    Text(note)
                        .font(Tokens.Typography.Onboarding.small)
                        .foregroundStyle(Tokens.Color.textMuted(scheme))
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, Tokens.Spacing.s4 + 2) // 18pt — mockup padding: 16px 18px
            .padding(.vertical, Tokens.Spacing.s4)        // 16pt
            .background(Tokens.Color.surface(scheme))
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.Radius.md)
                    .strokeBorder(Tokens.Color.border(scheme), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.md))
            // No outer page padding — ConnectorView wraps content with the
            // mockup .winbody inset (32 top / 40 sides / 28 bottom).

            // Helper skip link
            // mockup: center-aligned small text + text-link
            Button(skipLabel, action: onSkip)
                .buttonStyle(.tokenTextLink)
                .padding(.top, Tokens.Spacing.s3)
                .frame(maxWidth: .infinity)

            Spacer()

            // Footer: Back ghost | primary CTA
            // (back button owned by ConnectorView; we just provide the primary here
            //  in the same action-stack rhythm used across the flow)
            VStack(spacing: Tokens.Spacing.s2) {
                Button(primaryLabel, action: onContinue)
                    .buttonStyle(.tokenPrimary)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Command card

    /// Dashed-border monospaced card with a `$` prompt prefix.
    /// mockup .cmd-preview (lines 480–495):
    ///   bg surface-2, 1px DASHED border-strong, r-sm, padding 12×14, mono 13px
    ///   `$` prompt in text-subtle
    private func commandCard(_ command: String) -> some View {
        HStack(alignment: .top, spacing: Tokens.Spacing.s2 + 2) { // 10pt gap
            Text("$")
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(Tokens.Color.textSubtle(scheme))
                .padding(.top, 1)

            Text(command)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(Tokens.Color.text(scheme))
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(nil)
        }
        .padding(.horizontal, Tokens.Spacing.s4 - 2) // 14pt — mockup padding: 12px 14px
        .padding(.vertical, Tokens.Spacing.s3)        // 12pt
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tokens.Color.surface2(scheme))
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.sm)
                .stroke(
                    Tokens.Color.borderStrong(scheme),
                    style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.sm))
    }
}

// MARK: - Preview

#Preview("Install Homebrew — light") {
    ConfirmInstallStep(
        title: "Install Homebrew",
        description: "Tokenomics needs Homebrew to install Claude Code. Homebrew is the standard Mac package manager — about 2 minutes to install.",
        commandPreview: "/bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"",
        footnote: "We'll open Terminal and install Homebrew with your permission. You'll be asked for your password once.",
        skipLabel: "Already have Homebrew? Skip this step",
        onContinue: {},
        onSkip: {}
    )
    .frame(width: 680, height: 580)
    .background(Tokens.DynamicColor.bg)
    .preferredColorScheme(.light)
}

#Preview("Install Homebrew — dark") {
    ConfirmInstallStep(
        title: "Install Homebrew",
        description: "Tokenomics needs Homebrew to install Claude Code. Homebrew is the standard Mac package manager — about 2 minutes to install.",
        commandPreview: "/bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"",
        footnote: "We'll open Terminal and install Homebrew with your permission.",
        skipLabel: "Already have Homebrew? Skip this step",
        onContinue: {},
        onSkip: {}
    )
    .frame(width: 680, height: 580)
    .background(Tokens.DynamicColor.bg)
    .preferredColorScheme(.dark)
}

#Preview("Install Node.js — light") {
    ConfirmInstallStep(
        title: "Install Node.js",
        description: "Now we'll install Node.js using Homebrew. About 30 seconds, no extra permissions needed.",
        commandPreview: "brew install node",
        footnote: "Tokenomics installs Node.js into ~/.tokenomics-cli so it stays separate from any Node you might install later.",
        skipLabel: "Already have Node.js? Skip this step",
        onContinue: {},
        onSkip: {}
    )
    .frame(width: 680, height: 580)
    .background(Tokens.DynamicColor.bg)
    .preferredColorScheme(.light)
}

#Preview("Install Codex CLI — light") {
    ConfirmInstallStep(
        title: "Install Codex CLI",
        description: "Tokenomics will install OpenAI's command-line Codex tool. About 30 seconds.",
        commandPreview: "npm install -g @openai/codex",
        footnote: "Installed to ~/.tokenomics-cli — keeps Tokenomics' tools out of your global npm.",
        skipLabel: "Already have Codex? Skip this step",
        onContinue: {},
        onSkip: {}
    )
    .frame(width: 680, height: 580)
    .background(Tokens.DynamicColor.bg)
    .preferredColorScheme(.light)
}
