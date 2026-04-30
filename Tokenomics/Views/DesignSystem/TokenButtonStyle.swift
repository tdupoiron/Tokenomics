import SwiftUI

// MARK: - Button styles
//
// Five button variants from design-system.md section 06 (Components → Buttons).
// All use pill radius, DM Sans 16px medium (onboarding context). Hover surface
// is unified across all variants — `Tokens.Color.surface2(scheme)`.
//
// Use these via `.buttonStyle(.tokenPrimary)` etc. Anti-pattern: never use
// SwiftUI's default Button styling — that pulls Apple gray rounded chrome.

/// Primary — pill, accent-ink fill (light) / brand-200 (dark), white text (light) / ink-900 text (dark).
/// `.btn-primary` in the mockup. Used for Continue, Install, Save & connect, etc.
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var scheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Tokens.Typography.Onboarding.body.weight(.medium))
            .padding(.horizontal, Tokens.Spacing.s5)
            .padding(.vertical, Tokens.Spacing.s3)
            .foregroundStyle(scheme == .dark ? Tokens.Color.ink900 : Color.white)
            .background(Tokens.Color.accentInk(scheme))
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: Tokens.Motion.fast), value: configuration.isPressed)
    }
}

/// Secondary — transparent fill, `border-strong` 1px outline, hovers to surface-2.
/// `.btn-secondary` in the mockup. Used for "I'm all set", "Try again", etc.
struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var scheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Tokens.Typography.Onboarding.body.weight(.medium))
            .padding(.horizontal, Tokens.Spacing.s5)
            .padding(.vertical, Tokens.Spacing.s3)
            .foregroundStyle(Tokens.Color.text(scheme))
            .background(
                Capsule().fill(configuration.isPressed
                    ? Tokens.Color.surface2(scheme)
                    : Color.clear)
            )
            .overlay(
                Capsule().strokeBorder(Tokens.Color.borderStrong(scheme), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: Tokens.Motion.fast), value: configuration.isPressed)
    }
}

/// Ghost — transparent, text-muted, smaller padding (10×14).
/// `.btn-ghost` in the mockup. Used for "← Back" and tertiary actions.
struct GhostButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var scheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Tokens.Typography.Onboarding.small.weight(.medium))
            .padding(.horizontal, Tokens.Spacing.s4)
            .padding(.vertical, Tokens.Spacing.s2 + 2) // 10pt
            .foregroundStyle(Tokens.Color.textMuted(scheme))
            .background(
                Capsule().fill(configuration.isPressed
                    ? Tokens.Color.surface2(scheme)
                    : Color.clear)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: Tokens.Motion.fast), value: configuration.isPressed)
    }
}

/// Text link — naked link styling, accent color, optional inline arrow.
/// `.btn-text` in the mockup.
struct TextLinkButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var scheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Tokens.Typography.Onboarding.small.weight(.medium))
            .foregroundStyle(Tokens.Color.accent(scheme))
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(.easeOut(duration: Tokens.Motion.fast), value: configuration.isPressed)
    }
}

/// Button-in-field — small chip that sits inside an input or code field
/// (e.g. "Copy", "Paste"). 5pt vertical / 10pt horizontal padding, `--r-xs`
/// corners, surface-2 hover. `.btn-in-field` in the mockup.
struct InFieldButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var scheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Tokens.Typography.Onboarding.small.weight(.medium))
            .padding(.horizontal, Tokens.Spacing.s3 - 2) // 10pt
            .padding(.vertical, Tokens.Spacing.s1 + 1)   // 5pt
            .foregroundStyle(Tokens.Color.textMuted(scheme))
            .background(
                RoundedRectangle(cornerRadius: Tokens.Radius.xs)
                    .fill(configuration.isPressed
                        ? Tokens.Color.surface2(scheme)
                        : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: Tokens.Radius.xs)
                            .stroke(Tokens.Color.borderStrong(scheme), lineWidth: 1)
                    )
            )
            .animation(.easeOut(duration: Tokens.Motion.fast), value: configuration.isPressed)
    }
}

// MARK: - Convenience shorthand

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var tokenPrimary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
    static var tokenSecondary: SecondaryButtonStyle { SecondaryButtonStyle() }
}

extension ButtonStyle where Self == GhostButtonStyle {
    static var tokenGhost: GhostButtonStyle { GhostButtonStyle() }
}

extension ButtonStyle where Self == TextLinkButtonStyle {
    static var tokenTextLink: TextLinkButtonStyle { TextLinkButtonStyle() }
}

extension ButtonStyle where Self == InFieldButtonStyle {
    static var tokenInField: InFieldButtonStyle { InFieldButtonStyle() }
}

// MARK: - Preview

private var buttonGallery: some View {
    VStack(alignment: .leading, spacing: Tokens.Spacing.s4) {
        Button("Install Codex CLI") {}
            .buttonStyle(.tokenPrimary)

        Button("I'm all set — show my usage") {}
            .buttonStyle(.tokenSecondary)

        Button("← Back") {}
            .buttonStyle(.tokenGhost)

        Button("Open the guided setup →") {}
            .buttonStyle(.tokenTextLink)

        Button("Paste") {}
            .buttonStyle(.tokenInField)
    }
    .padding(Tokens.Spacing.s5)
    .background(Tokens.DynamicColor.bg)
}

#Preview("Button variants — light") {
    buttonGallery
        .frame(width: 360, height: 320)
}

#Preview("Button variants — dark") {
    buttonGallery
        .preferredColorScheme(.dark)
        .frame(width: 360, height: 320)
}
