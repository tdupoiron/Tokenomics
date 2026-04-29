import SwiftUI

/// Numbered-checklist preview screen shown before handing off to an external
/// tool's wizard. Used for Windows 3 and 4 of the Anthropic / Claude Code flow.
///
/// The numbered list tells the user exactly what they'll encounter in Claude Code's
/// own wizard, so there are no surprises when Terminal opens. Design mirrors
/// `ConfirmInstallStep`: same padding, same button rhythm.
///
/// The optional `headsUp` callout (Window 4) surfaces a mild macOS permissions
/// advisory so the user knows what to expect from Claude Code's permission dialogs.
struct PreviewExternalStepsView: View {
    /// Short headline. E.g. "Finish installing Claude Code" or "Setup".
    var headline: String

    /// One or two sentences setting context.
    var introText: String

    /// Ordered list of steps the user will take externally. Rendered with
    /// numbered circles matching the mockup's wizard-list pattern.
    var items: [String]

    /// Label for the primary action button. "Continue" or "Open Terminal".
    var primaryLabel: String

    /// Optional advisory callout shown below the step list.
    /// E.g. "Heads up: Claude Code asks macOS for access to a bunch of folders…"
    var headsUp: String? = nil

    /// Called when the user taps the primary button.
    var onPrimary: () -> Void

    /// Called when the user taps Back. Optional — omit to hide the back button.
    var onBack: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            // Icon
            Image(systemName: "checklist")
                .resizable()
                .scaledToFit()
                .frame(width: 40, height: 40)
                .foregroundStyle(.tint)
                .padding(.top, 20)
                .padding(.bottom, 12)

            // Headline + intro paragraph
            VStack(spacing: 8) {
                Text(headline)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)

                Text(introText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 16)

            // Numbered step list
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    wizardRow(number: index + 1, text: item)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .frame(maxWidth: .infinity, alignment: .leading)

            // "Heads up" advisory callout — shown only when populated (Window 4).
            if let headsUp {
                headsUpCallout(headsUp)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
            }

            Spacer(minLength: 16)

            // Action stack — same vertical rhythm as ConnectorView.
            VStack(spacing: 10) {
                Button(primaryLabel, action: onPrimary)
                    .buttonStyle(.borderedProminent)
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

    // MARK: - Heads-up callout

    /// Muted advisory block with an info icon — matches the mockup's callout pattern.
    private func headsUpCallout(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 1)

            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
        )
    }

    // MARK: - Wizard list row

    /// Numbered circle + step text, matching the mockup's `wizard-list` pattern.
    private func wizardRow(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            // Numbered circle
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 22, height: 22)

                Text("\(number)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.tint)
            }
            .padding(.top, 1)   // optical alignment with first line of text

            stepText(text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Bolds the first clause of each step (up to the first " — " separator),
    /// matching the mockup's strong-label pattern. Falls back to plain text if
    /// there's no separator.
    @ViewBuilder
    private func stepText(_ text: String) -> some View {
        if let separatorRange = text.range(of: " — ") {
            Text(String(text[text.startIndex..<separatorRange.lowerBound])).bold()
                + Text(" — " + String(text[separatorRange.upperBound...]))
        } else {
            Text(text)
        }
    }
}

// MARK: - Preview

#Preview("Window 3 — Sign-in preview") {
    PreviewExternalStepsView(
        headline: "Finish installing Claude Code",
        introText: "We've installed Claude Code. You'll need to finish setup by walking through Anthropic's wizard — we're here to guide you.",
        items: [
            "Pick login method — choose Claude account with subscription if you're on Pro or Max",
            "Sign in via browser — paste the email code Anthropic sends",
            "Authorize Claude Code to connect to your account",
            "Accept Anthropic's security notes"
        ],
        primaryLabel: "Continue",
        onPrimary: {},
        onBack: {}
    )
    .frame(width: 320, height: 440)
}

#Preview("Window 4 — Setup preview with headsUp") {
    PreviewExternalStepsView(
        headline: "Setup",
        introText: "After you sign in, Claude Code asks for two more things — a folder and macOS permissions. Finish those and you're done.",
        items: [
            "Pick a folder Claude can access — create a Projects folder in your Home folder if you don't have one",
            "Grant macOS permissions as Claude Code asks for them"
        ],
        primaryLabel: "Open Terminal",
        headsUp: "Heads up: Claude Code asks macOS for access to a bunch of folders during setup — Music, Photos, Downloads, Documents. Safe to decline anything outside your Projects folder. Claude works fine without them.",
        onPrimary: {},
        onBack: {}
    )
    .frame(width: 320, height: 420)
}
