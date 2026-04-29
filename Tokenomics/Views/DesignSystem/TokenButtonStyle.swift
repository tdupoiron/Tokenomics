import SwiftUI

// MARK: - TokenButtonStyle
//
// Matches the mockup's `.btn-primary`, `.btn-secondary`, `.btn-ghost` classes
// (guided-onboarding-mockup.html, button block ~lines 351–371).
// All use Capsule shape, DM Sans weight 500, padding 10×22 at regular size.

/// Three button styles that match the mockup's button variants.
struct TokenButtonStyle: ButtonStyle {
    enum Variant { case primary, secondary, ghost }
    enum Size { case regular, sm, lg }

    let variant: Variant
    var size: Size = .regular

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(buttonFont(for: size))
            .padding(.vertical, paddingV(size))
            .padding(.horizontal, paddingH(size, variant: variant))
            .foregroundStyle(foreground(variant))
            .background(background(variant, isPressed: configuration.isPressed))
            .overlay(border(variant))
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    // MARK: - Per-variant appearance

    private func foreground(_ variant: Variant) -> Color {
        switch variant {
        case .primary:   return Color.white
        case .secondary: return Color.brandText
        case .ghost:     return Color.brandTextMuted
        }
    }

    @ViewBuilder
    private func background(_ variant: Variant, isPressed: Bool) -> some View {
        switch variant {
        case .primary:
            PrimaryButtonBackground(isPressed: isPressed)
        case .secondary, .ghost:
            Color.clear
        }
    }

    @ViewBuilder
    private func border(_ variant: Variant) -> some View {
        switch variant {
        case .primary, .ghost:
            EmptyView()
        case .secondary:
            Capsule().stroke(Color.brandBorderStrong, lineWidth: 1)
        }
    }

    // MARK: - Size helpers

    private func buttonFont(for size: Size) -> Font {
        switch size {
        case .regular: return Font.custom("DM Sans", size: 14, relativeTo: .body).weight(.medium)
        case .sm:      return Font.custom("DM Sans", size: 12.5, relativeTo: .footnote).weight(.medium)
        case .lg:      return Font.custom("DM Sans", size: 16, relativeTo: .body).weight(.medium)
        }
    }

    private func paddingV(_ size: Size) -> CGFloat {
        switch size {
        case .regular: return 10
        case .sm:      return 6
        case .lg:      return 14
        }
    }

    private func paddingH(_ size: Size, variant: Variant) -> CGFloat {
        if variant == .ghost { return 14 }
        switch size {
        case .regular: return 22
        case .sm:      return 14
        case .lg:      return 28
        }
    }
}

// MARK: - Primary button background
//
// Light scheme: bg = --accent-ink (#0E334D) — dark navy on cream.
// Dark scheme:  bg = --brand-200  (#75CBF5) — sky blue on dark bg.
// BrandAccentInk and BrandAccent already encode those respective values
// per their light/dark asset definitions, so we just pick the right token
// per scheme rather than hard-coding hex.

private struct PrimaryButtonBackground: View {
    @Environment(\.colorScheme) private var scheme
    let isPressed: Bool

    var body: some View {
        let base: Color = (scheme == .dark) ? .brandAccent : .brandAccentInk
        base.opacity(isPressed ? 0.85 : 1.0)
    }
}

// MARK: - Convenience shorthands

extension ButtonStyle where Self == TokenButtonStyle {
    /// Dark navy / sky-blue filled pill — primary CTA.
    static var tokenPrimary: TokenButtonStyle { TokenButtonStyle(variant: .primary) }
    /// Bordered pill — secondary action.
    static var tokenSecondary: TokenButtonStyle { TokenButtonStyle(variant: .secondary) }
    /// Label-only — tertiary / skip actions.
    static var tokenGhost: TokenButtonStyle { TokenButtonStyle(variant: .ghost) }
    /// Large primary — used on Welcome and Done screens.
    static var tokenPrimaryLg: TokenButtonStyle { TokenButtonStyle(variant: .primary, size: .lg) }
    /// Small ghost — step-level skip / back.
    static var tokenGhostSm: TokenButtonStyle { TokenButtonStyle(variant: .ghost, size: .sm) }
}
