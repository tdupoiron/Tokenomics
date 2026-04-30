import SwiftUI

/// First-launch screen — hero ring + serif headline + value prop +
/// "Get Started" primary button + privacy disclosure.
///
/// Layout matches mockup section 1 (guided-onboarding-mockup.html lines ~1108–1151):
///   - 72×72 hero-ring container (accent gradient bg, 18pt radius) centered
///   - Hedvig H1 serif headline "Track your AI usage."
///   - DM Sans lede (15pt) with 12pt top / 32pt bottom margins
///   - Primary button "Get started"
///   - Small disclosure (13pt) with "Learn more" accent link
struct WelcomeView: View {
    var onGetStarted: () -> Void
    var onSkip: () -> Void

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 0) {
                // Hero ring container — 72×72, radius 18, accent gradient
                // mockup .hero-ring: border-radius 18px, gradient accent@18% → accent@6%
                heroRingContainer
                    .padding(.bottom, Tokens.Spacing.s5 + 4) // 28pt — mockup margin-bottom: 28px

                // Serif headline — Hedvig 30pt
                Text("Track your AI usage.")
                    .font(Tokens.Typography.Onboarding.h1)
                    .foregroundStyle(Tokens.Color.text(scheme))
                    .multilineTextAlignment(.center)

                // Lede — DM Sans 15pt, margin 12pt top / 32pt bottom
                Text("At a glance, from the menu bar.\nTokenomics works with Claude, Codex, Gemini, Copilot, Cursor, and more.")
                    .font(Tokens.Typography.Onboarding.lede)
                    .foregroundStyle(Tokens.Color.textMuted(scheme))
                    .multilineTextAlignment(.center)
                    .padding(.top, Tokens.Spacing.s3)       // 12pt
                    .padding(.bottom, Tokens.Spacing.s6)    // 32pt — mockup margin-bottom: 32px

                // Primary CTA — "Get started"
                Button("Get Started", action: onGetStarted)
                    .buttonStyle(.tokenPrimary)

                // Privacy disclosure — DM Sans 13pt subtle, "Learn more" in accent
                // mockup: margin-top: 28px
                privacyDisclosure
                    .padding(.top, Tokens.Spacing.s5 + 4)  // 28pt — mockup margin-top: 28px
            }
            .padding(.horizontal, Tokens.Spacing.s5)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Hero ring container

    /// 72×72 rounded square with a linear gradient fill from accent@18% → accent@6%.
    /// Contains the dual-ring usage glyph at its natural size.
    /// mockup .hero-ring: width/height 72px, border-radius 18px, border 1px --border
    private var heroRingContainer: some View {
        ZStack {
            // Gradient background — accent@18% to accent@6%
            RoundedRectangle(cornerRadius: 18) // mockup: border-radius: 18px (between md=14 and lg=20)
                .fill(
                    LinearGradient(
                        colors: [
                            Tokens.Color.accent(scheme).opacity(0.18),
                            Tokens.Color.accent(scheme).opacity(0.06)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(Tokens.Color.border(scheme), lineWidth: 1)

            // Ring SVG at 56×56 — matches mockup: .hero-ring svg { width: 56px; height: 56px }
            WelcomeRingView(size: 56)
        }
        .frame(width: 72, height: 72)
    }

    // MARK: - Privacy disclosure

    /// Small disclosure line with inline "Learn more" accent link.
    private var privacyDisclosure: some View {
        Text(disclosureString)
            .font(Tokens.Typography.Onboarding.small)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .environment(\.openURL, OpenURLAction { url in
                NSWorkspace.shared.open(url)
                return .handled
            })
    }

    private var disclosureString: AttributedString {
        var base = AttributedString("Tokenomics reads usage data locally. Your tokens never leave your Mac.  ")
        base.foregroundColor = NSColor(Tokens.Color.textSubtle(scheme))

        var link = AttributedString("Learn more →")
        link.foregroundColor = NSColor(Tokens.Color.accent(scheme))
        link.link = URL(string: "https://trytokenomics.com")

        return base + link
    }
}

// MARK: - Preview

#Preview("Welcome — light") {
    WelcomeView(onGetStarted: {}, onSkip: {})
        .frame(width: 680, height: 580)
        .background(Tokens.DynamicColor.bg)
}

#Preview("Welcome — dark") {
    WelcomeView(onGetStarted: {}, onSkip: {})
        .frame(width: 680, height: 580)
        .background(Tokens.DynamicColor.bg)
        .preferredColorScheme(.dark)
}
