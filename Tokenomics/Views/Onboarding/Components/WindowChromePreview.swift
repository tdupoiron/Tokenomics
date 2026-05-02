import SwiftUI

/// Preview-only wrapper that renders a step view inside the same chrome the
/// production `ConnectorView` provides — title bar, stepper, dividers, body
/// padding. Used by step view `#Preview` blocks so the canvas matches what
/// the user actually sees inside the onboarding window.
///
/// Not intended for production use. Step views render INSIDE this wrapper
/// at preview time only; in production they're injected into ConnectorView's
/// slot and don't draw their own chrome.
struct WindowChromePreview<Content: View>: View {
    /// Window title text — shown centered in the title bar (e.g. "Connect OpenAI").
    let title: String

    /// Stepper labels — passed through to `OnboardingStepper`.
    let stepperItems: [OnboardingStepperItem]

    /// The step view content.
    @ViewBuilder var content: Content

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: 0) {
            // Title bar (mimics macOS chrome — real window uses .windowStyle(.titleBar))
            Text(title)
                .font(Tokens.Typography.Onboarding.windowTitle)
                .foregroundStyle(Tokens.Color.textMuted(scheme))
                .frame(maxWidth: .infinity)
                .padding(.vertical, Tokens.Spacing.s3)

            // Divider — sits BETWEEN titlebar and stepper (mockup pattern,
            // not between stepper and content).
            Rectangle()
                .fill(Tokens.Color.border(scheme))
                .frame(height: 1)

            // Stepper
            OnboardingStepper(items: stepperItems)
                .padding(.horizontal, Tokens.Spacing.s4)
                .padding(.top, Tokens.Spacing.s4)
                .padding(.bottom, Tokens.Spacing.s2)

            // Content body — mockup .winbody: padding 32px 40px 28px
            content
                .padding(.top, Tokens.Spacing.s6)        // 32pt
                .padding(.horizontal, 40)                // 40pt — mockup literal
                .padding(.bottom, Tokens.Spacing.s5 + 4) // 28pt
        }
        .background(Tokens.DynamicColor.bg)
    }
}
