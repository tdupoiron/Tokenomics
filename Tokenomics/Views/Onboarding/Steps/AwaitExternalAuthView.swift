import SwiftUI

/// "We're waiting for your successful login" screen shown while Terminal is open
/// and Tokenomics polls for `~/.claude/.credentials.json`.
///
/// Window 5 of the Anthropic / Claude Code flow. The user has left to finish
/// Anthropic's wizard in Terminal; this screen keeps them oriented and gives
/// them a manual check-now escape hatch.
///
/// Layout follows mockup section 12 Window 5 — centered stack with spinner,
/// terminal-mini illustration, polling indicator, and footer.
struct AwaitExternalAuthView: View {
    /// Short headline.
    var headline: String

    /// Instruction paragraph shown below the headline.
    var instructionText: String

    /// Called when the user taps "I'm signed in — check now".
    var onCheckNow: () -> Void

    /// Called when the user taps Back.
    var onBack: (() -> Void)?

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: Tokens.Spacing.s4) {
                // Spinner — signals active polling
                ProgressView()
                    .controlSize(.large)
                    .padding(.bottom, Tokens.Spacing.s1)

                // Headline — h2
                Text(headline)
                    .font(Tokens.Typography.Onboarding.h2)
                    .foregroundStyle(Tokens.Color.text(scheme))
                    .multilineTextAlignment(.center)

                // Body — lede
                Text(instructionText)
                    .font(Tokens.Typography.Onboarding.lede)
                    .foregroundStyle(Tokens.Color.textMuted(scheme))
                    .multilineTextAlignment(.center)

                // Terminal mini-preview + caption
                VStack(spacing: Tokens.Spacing.s2) {
                    terminalMiniPreview
                    Text("When your Terminal looks like this, you're signed in.")
                        .font(Tokens.Typography.Onboarding.small)
                        .foregroundStyle(Tokens.Color.textMuted(scheme))
                        .multilineTextAlignment(.center)
                }

                // Polling indicator
                pollingCaption
            }
            // No outer page padding — ConnectorView's winbody inset handles it.

            Spacer()

            // Footer — "I'm signed in" secondary + Back ghost
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Terminal mini-preview

    /// Static styled rectangle showing Claude Code's startup chat prompt.
    /// mockup .terminal-mini: dark bg, r-md, shadow-sm, monospaced 12px
    private var terminalMiniPreview: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Fake terminal title bar — always dark (real terminals are dark by default)
            // mockup .tbar: 22px height, #2a2a2a bg, border-bottom #0a0a0a
            HStack(spacing: 6) {
                Circle().fill(Color(hex: 0xFF5F57)).frame(width: 8, height: 8)
                Circle().fill(Color(hex: 0xFEBC2E)).frame(width: 8, height: 8)
                Circle().fill(Color(hex: 0x28C840)).frame(width: 8, height: 8)
                Spacer()
                Text("Terminal — claude")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Color(white: 0.53))
                Spacer()
                // Balance spacer
                Circle().opacity(0).frame(width: 8 * 3 + 6 * 2, height: 8)
            }
            .padding(.horizontal, Tokens.Spacing.s2 + 2)
            .padding(.vertical, 5)
            .background(Color(hex: 0x2A2A2A))

            // Terminal content body
            // mockup .tbody: padding 12×14, mono 12px, line-height 1.55
            VStack(alignment: .leading, spacing: 2) {
                monoLine("  ██████╗ ██╗      █████╗ ██╗   ██╗██████╗ ███████╗", muted: true)
                monoLine("  ██╔════╝██║     ██╔══██╗██║   ██║██╔══██╗██╔════╝", muted: true)
                monoLine("  ██║     ██║     ███████║██║   ██║██║  ██║█████╗  ", muted: true)
                monoLine("  ╚██████╗███████╗██║  ██║╚██████╔╝██████╔╝███████╗", muted: true)
                monoLine("  ╚══════╝╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚═════╝ ╚══════╝", muted: true)
                    .padding(.bottom, Tokens.Spacing.s1)
                monoLine("  > How can I help you today?", muted: false)
            }
            .padding(.horizontal, Tokens.Spacing.s2 + 2) // 10pt
            .padding(.vertical, Tokens.Spacing.s3)        // 12pt
        }
        .background(Color(hex: 0x1C1C1C))
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.md)
                .stroke(Color(hex: 0x0A0A0A), lineWidth: 1)
        )
    }

    private func monoLine(_ text: String, muted: Bool) -> some View {
        Text(text)
            .font(.system(size: 7, design: .monospaced))
            .foregroundStyle(
                muted
                    ? Color.white.opacity(0.35)
                    : Color(hex: 0x6FD18A).opacity(0.9) // terminal green
            )
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Polling caption

    /// Surface-2 bg pill showing the watch path.
    private var pollingCaption: some View {
        HStack(spacing: Tokens.Spacing.s1 + 2) { // 6pt
            ProgressView()
                .controlSize(.mini)
            Text("Watching ")
                .font(Tokens.Typography.Onboarding.small)
                .foregroundStyle(Tokens.Color.textMuted(scheme))
            + Text("~/.claude")
                .font(.custom("DM Sans", size: 13).monospaced())
                .foregroundStyle(Tokens.Color.textMuted(scheme))
            + Text(" for authentication…")
                .font(Tokens.Typography.Onboarding.small)
                .foregroundStyle(Tokens.Color.textMuted(scheme))
        }
        .padding(.horizontal, Tokens.Spacing.s3)
        .padding(.vertical, Tokens.Spacing.s2)
        .background(Tokens.Color.surface2(scheme))
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.sm))
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            if let onBack {
                Button(action: onBack) {
                    Text("← Back")
                }
                .buttonStyle(.tokenGhost)
            }

            Spacer()

            Button("I'm signed in — check now", action: onCheckNow)
                .buttonStyle(.tokenSecondary)
        }
        .padding(.top, Tokens.Spacing.s5)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Tokens.Color.border(scheme))
                .frame(height: 1)
        }
        .padding(.horizontal, Tokens.Spacing.s5)
        .padding(.bottom, Tokens.Spacing.s5)
    }
}

// MARK: - Color helper

private extension Color {
    /// Convenience init from a hex integer literal (e.g. `Color(hex: 0xFF5F57)`).
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >>  8) & 0xFF) / 255
        let b = Double( hex        & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Preview

#Preview("Window 5 — Awaiting auth — light") {
    AwaitExternalAuthView(
        headline: "Confirm login",
        instructionText: "We're waiting for your successful login. You'll know you're done when you see Claude's chat prompt — close Terminal then and come back here.",
        onCheckNow: {},
        onBack: {}
    )
    .frame(width: 680, height: 580)
    .background(Tokens.DynamicColor.bg)
    .preferredColorScheme(.light)
}

#Preview("Window 5 — Awaiting auth — dark") {
    AwaitExternalAuthView(
        headline: "Confirm login",
        instructionText: "We're waiting for your successful login. You'll know you're done when you see Claude's chat prompt — close Terminal then and come back here.",
        onCheckNow: {},
        onBack: {}
    )
    .frame(width: 680, height: 580)
    .background(Tokens.DynamicColor.bg)
    .preferredColorScheme(.dark)
}
