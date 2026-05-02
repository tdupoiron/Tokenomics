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

            // Stepper
            OnboardingStepper(items: stepperItems)
                .padding(.horizontal, Tokens.Spacing.s4)
                .padding(.bottom, Tokens.Spacing.s2 + 2)

            // Header / stepper divider
            Rectangle()
                .fill(Tokens.Color.border(scheme))
                .frame(height: 1)

            // Content body — same inset ConnectorView applies
            content
                .padding(.horizontal, Tokens.Spacing.s5)
                .padding(.vertical, Tokens.Spacing.s4)
        }
        .background(Tokens.DynamicColor.bg)
    }
}
