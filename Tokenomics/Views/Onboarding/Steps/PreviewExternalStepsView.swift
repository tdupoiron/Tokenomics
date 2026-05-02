import SwiftUI

/// Numbered-checklist preview screen shown before handing off to an external
/// tool's wizard. Used for Windows 3 and 4 of the Anthropic / Claude Code flow.
///
/// The numbered list tells the user exactly what they'll encounter in Claude Code's
/// own wizard, so there are no surprises when Terminal opens.
///
/// Layout matches mockup section 12 Windows 3+4 (.wizard-list pattern, lines ~860–899):
///   - Headline h2 + intro lede
///   - Numbered wizard rows: 22pt circle (accent@14% bg, accent text) + 12.5pt body text
///   - Optional heads-up callout (info block with surface-2 bg)
///   - Footer: Back ghost | primary CTA
struct PreviewExternalStepsView: View {
    /// Short headline.
    var headline: String

    /// One or two sentences setting context.
    var introText: String

    /// Ordered list of steps the user will take externally.
    var items: [String]

    /// Label for the primary action button.
    var primaryLabel: String

    /// Optional advisory callout shown below the step list.
    var headsUp: String? = nil

    /// Called when the user taps the primary button.
    var onPrimary: () -> Void

    /// Called when the user taps Back.
    var onBack: (() -> Void)?

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: 0) {
            // Headline + intro paragraph
            // mockup: h-sans h2 centered, lede text-muted
            VStack(spacing: Tokens.Spacing.s2) {
                Text(headline)
                    .font(Tokens.Typography.Onboarding.h2)
                    .foregroundStyle(Tokens.Color.text(scheme))
                    .multilineTextAlignment(.center)

                Text(introText)
                    .font(Tokens.Typography.Onboarding.lede)
                    .foregroundStyle(Tokens.Color.textMuted(scheme))
                    .multilineTextAlignment(.center)
            }
            .padding(.bottom, Tokens.Spacing.s4)

            // Numbered wizard list
            // mockup .wizard-list: gap 10px between items, 22pt circles
            VStack(alignment: .leading, spacing: Tokens.Spacing.s2 + 2) { // 10pt
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    wizardRow(number: index + 1, text: item)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Heads-up advisory callout — shown only when populated (Window 4)
            if let headsUp {
                headsUpCallout(headsUp)
                    .padding(.top, Tokens.Spacing.s3)
            }

            Spacer(minLength: Tokens.Spacing.s4)

            // Action footer
            // mockup .winfoot: padding-top 24px, border-top 1px border
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Wizard row

    /// 22pt numbered circle + step text.
    /// mockup .w-num: 22px circle, accent@14% bg, accent text, 11px semibold tabular
    /// mockup .w-text: 12.5px, var(--text)
    private func wizardRow(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: Tokens.Spacing.s3) { // 12pt gap
            // Numbered circle
            ZStack {
                Circle()
                    .fill(Tokens.Color.accent(scheme).opacity(0.14))
                    .frame(width: 22, height: 22)

                Text("\(number)")
                    .font(Tokens.Typography.Onboarding.stepperNumber)
                    .monospacedDigit()
                    .foregroundStyle(Tokens.Color.accent(scheme))
            }
            .padding(.top, 1) // optical alignment

            stepText(text)
                .font(.custom("DM Sans", size: 12.5)) // mockup .w-text: 12.5px
                .foregroundStyle(Tokens.Color.text(scheme))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Bolds the first clause of each step (up to the first " — " separator).
    @ViewBuilder
    private func stepText(_ text: String) -> some View {
        if let separatorRange = text.range(of: " — ") {
            Text(String(text[text.startIndex..<separatorRange.lowerBound])).bold()
                + Text(" — " + String(text[separatorRange.upperBound...]))
        } else {
            Text(text)
        }
    }

    // MARK: - Heads-up callout

    /// Muted advisory block — surface-2 bg, border, info icon.
    /// Uses the same .surface.muted pattern from the mockup (surface-2 bg, border, r-sm).
    private func headsUpCallout(_ text: String) -> some View {
        HStack(alignment: .top, spacing: Tokens.Spacing.s2) {
            Image(systemName: "info.circle")
                .font(Tokens.Typography.Onboarding.small)
                .foregroundStyle(Tokens.Color.textSubtle(scheme))
                .padding(.top, 1)

            Text(text)
                .font(Tokens.Typography.Onboarding.small)
                .foregroundStyle(Tokens.Color.textMuted(scheme))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, Tokens.Spacing.s4 - 2) // 14pt
        .padding(.vertical, Tokens.Spacing.s3)        // 12pt
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tokens.Color.surface2(scheme))
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.sm)
                .strokeBorder(Tokens.Color.border(scheme), lineWidth: 1)
        )
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

            Button(primaryLabel, action: onPrimary)
                .buttonStyle(.tokenPrimary)
        }
        .padding(.top, Tokens.Spacing.s5)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Tokens.Color.border(scheme))
                .frame(height: 1)
        }
    }
}

// MARK: - Preview sample data
// Hoisted outside #Preview to avoid Swift type-checker timeout on large literals.

private let window3Items: [String] = [
    "Pick login method — choose Claude account with subscription if you're on Pro or Max",
    "Sign in via browser — paste the email code Anthropic sends",
    "Authorize Claude Code to connect to your account",
    "Accept Anthropic's security notes",
]

private let window4Items: [String] = [
    "Pick a folder Claude can access — create a Projects folder in your Home folder if you don't have one",
    "Grant macOS permissions as Claude Code asks for them",
]

// MARK: - Preview

#Preview("Window 3 — Sign-in preview — light") {
    PreviewExternalStepsView(
        headline: "Finish installing Claude Code",
        introText: "We've installed Claude Code. You'll need to finish setup by walking through Anthropic's wizard — we're here to guide you.",
        items: window3Items,
        primaryLabel: "Continue",
        onPrimary: {},
        onBack: {}
    )
    .frame(width: 720, height: 560)
    .background(Tokens.DynamicColor.bg)
    .preferredColorScheme(.light)
}

#Preview("Window 3 — Sign-in preview — dark") {
    PreviewExternalStepsView(
        headline: "Finish installing Claude Code",
        introText: "We've installed Claude Code. You'll need to finish setup by walking through Anthropic's wizard — we're here to guide you.",
        items: window3Items,
        primaryLabel: "Continue",
        onPrimary: {},
        onBack: {}
    )
    .frame(width: 720, height: 560)
    .background(Tokens.DynamicColor.bg)
    .preferredColorScheme(.dark)
}

#Preview("Window 4 — Setup preview with headsUp — light") {
    PreviewExternalStepsView(
        headline: "Setup",
        introText: "After you sign in, Claude Code asks for two more things — a folder and macOS permissions. Finish those and you're done.",
        items: window4Items,
        primaryLabel: "Open Terminal",
        headsUp: "Heads up: Claude Code asks macOS for access to a bunch of folders during setup — Music, Photos, Downloads, Documents. Safe to decline anything outside your Projects folder.",
        onPrimary: {},
        onBack: {}
    )
    .frame(width: 720, height: 560)
    .background(Tokens.DynamicColor.bg)
    .preferredColorScheme(.light)
}

#Preview("Window 4 — Setup preview with headsUp — dark") {
    PreviewExternalStepsView(
        headline: "Setup",
        introText: "After you sign in, Claude Code asks for two more things — a folder and macOS permissions. Finish those and you're done.",
        items: window4Items,
        primaryLabel: "Open Terminal",
        headsUp: "Heads up: Claude Code asks macOS for access to a bunch of folders during setup.",
        onPrimary: {},
        onBack: {}
    )
    .frame(width: 720, height: 560)
    .background(Tokens.DynamicColor.bg)
    .preferredColorScheme(.dark)
}
