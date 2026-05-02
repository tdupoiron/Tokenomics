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

            // Ring SVG at 56×56 — verbatim from mockup lines 1131–1136:
            //   <circle r="36" stroke-opacity="0.18"/>          ← outer track
            //   <circle r="22" stroke-opacity="0.18"/>          ← inner track
            //   <path d="M50,14 A36,36 0 0 1 86,50"/>           ← outer accent arc (12 → 3 o'clock, 90°)
            //   <path d="M50,28 A22,22 0 0 1 67,38"/>           ← inner accent arc (12 → ~2 o'clock, ~60°)
            // No percentage text, no full-fill arcs — just two thin accent strokes
            // riding subtle currentColor tracks.
            HeroRing()
                .frame(width: 56, height: 56)
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

// MARK: - Hero ring

/// Two simple accent arcs over subtle currentColor tracks. Verbatim port of the
/// mockup's hero SVG (guided-onboarding-mockup.html lines 1131–1136). Drawn in
/// a 100×100 viewBox via SwiftUI shapes — outer arc sweeps 12→3 o'clock (90°),
/// inner arc sweeps 12→~2 o'clock (~50°).
private struct HeroRing: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            Canvas { ctx, size in
                let s = size.width  // square canvas
                let scale = s / 100  // viewBox is 100×100
                let center = CGPoint(x: 50 * scale, y: 50 * scale)
                let strokeW = 6 * scale

                // Track color = currentColor at 18% (text in light, off-white in dark).
                let trackColor = (scheme == .dark
                    ? GraphicsContext.Shading.color(.white.opacity(0.18))
                    : GraphicsContext.Shading.color(Tokens.Color.text(.light).opacity(0.18)))

                let accentColor = GraphicsContext.Shading.color(Tokens.Color.accent(scheme))

                // Outer track (r=36, full circle)
                let outerR: CGFloat = 36 * scale
                let outerRect = CGRect(x: center.x - outerR, y: center.y - outerR, width: outerR * 2, height: outerR * 2)
                ctx.stroke(Path(ellipseIn: outerRect), with: trackColor, lineWidth: strokeW)

                // Inner track (r=22, full circle)
                let innerR: CGFloat = 22 * scale
                let innerRect = CGRect(x: center.x - innerR, y: center.y - innerR, width: innerR * 2, height: innerR * 2)
                ctx.stroke(Path(ellipseIn: innerRect), with: trackColor, lineWidth: strokeW)

                // Outer accent arc — 12 to 3 o'clock = -90° to 0° in std math, 0° to 90° clockwise from top.
                var outerArc = Path()
                outerArc.addArc(center: center, radius: outerR,
                                startAngle: .degrees(-90), endAngle: .degrees(0),
                                clockwise: false)
                ctx.stroke(outerArc, with: accentColor,
                           style: StrokeStyle(lineWidth: strokeW, lineCap: .round))

                // Inner accent arc — 12 to ~2 o'clock = ~50° clockwise from top.
                // Mockup endpoint (67,38): atan2(38-50, 67-50) = atan2(-12, 17) = -35.2° (std math),
                // i.e. 54.8° clockwise from 3 o'clock. So end angle in our coord system = -35.2°.
                var innerArc = Path()
                innerArc.addArc(center: center, radius: innerR,
                                startAngle: .degrees(-90), endAngle: .degrees(-35.2),
                                clockwise: false)
                ctx.stroke(innerArc, with: accentColor,
                           style: StrokeStyle(lineWidth: strokeW, lineCap: .round))
            }
        }
    }
}

// MARK: - Preview

#Preview("Welcome — light") {
    WelcomeView(onGetStarted: {}, onSkip: {})
        .frame(width: 680, height: 580)
        .background(Tokens.DynamicColor.bg)
        .preferredColorScheme(.light)
}

#Preview("Welcome — dark") {
    WelcomeView(onGetStarted: {}, onSkip: {})
        .frame(width: 680, height: 580)
        .background(Tokens.DynamicColor.bg)
        .preferredColorScheme(.dark)
}
