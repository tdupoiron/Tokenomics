import SwiftUI

/// Explainer step that primes the two macOS permission prompts triggered by
/// reading Claude Code's session token from the keychain. Sits between Welcome
/// and ProviderChooser so users know what's coming before macOS interrupts.
///
/// On Continue, calls `KeychainService.probeAccess()` — that triggers the
/// keychain ACL prompt and (on macOS 15+) the "data from another app" prompt
/// at a known UI moment. The probe distinguishes three outcomes:
///   - granted (or no item exists yet) → advance to chooser
///   - denied → switch to a hard-stop error state with a "Try again" CTA
///
/// Layout: same surface cards in both states. The error state swaps the
/// header, lede, and primary button label so the user understands why we
/// can't move on without their explicit consent.
struct PermissionsStep: View {
    var onContinue: () -> Void
    var onBack: () -> Void

    @State private var didDeny = false

    var body: some View {
        PermissionsStepBody(
            didDeny: didDeny,
            onContinue: triggerPromptsAndContinue,
            onBack: onBack
        )
    }

    /// Probes keychain access and either advances or surfaces the denied state.
    /// "Try again" routes through here too — re-firing the read so macOS can
    /// re-prompt (it does, unless the user resolved it in System Settings).
    private func triggerPromptsAndContinue() {
        switch KeychainService.probeAccess() {
        case .ok:
            didDeny = false
            onContinue()
        case .denied:
            didDeny = true
        }
    }
}

// MARK: - Stateless body
//
// Pulled out so previews can render both the initial and denied states by
// passing `didDeny` directly. PermissionsStep owns the @State flag that
// drives this in production.

private struct PermissionsStepBody: View {
    let didDeny: Bool
    let onContinue: () -> Void
    let onBack: () -> Void

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: Tokens.Spacing.s2) {
                Text(didDeny ? "Permissions required" : "Permissions needed to start tracking…")
                    .font(Tokens.Typography.Onboarding.h2)
                    .foregroundStyle(didDeny
                                     ? Tokens.Color.danger(scheme)
                                     : Tokens.Color.text(scheme))

                Text(didDeny
                     ? "Tokenomics can't function without these. We only use them to coordinate your computer with the AI providers for usage tracking — your information never leaves your Mac."
                     : "Tokenomics reads where your AI tools store their session info so it can show usage. macOS protects you with two confirmations the first time.")
                    .font(Tokens.Typography.Onboarding.lede)
                    .foregroundStyle(Tokens.Color.textMuted(scheme))
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: Tokens.Spacing.s2) {
                permissionRow(
                    icon: "key.fill",
                    title: "Keychain access",
                    detail: "Lets Tokenomics read your AI provider's sign-in. Choose Always Allow so it doesn't ask again."
                )
                permissionRow(
                    icon: "rectangle.on.rectangle",
                    title: "Information from another app",
                    detail: "macOS treats your AI provider's keychain entry as cross-app data. One tap to allow."
                )
            }
            .padding(.top, Tokens.Spacing.s5)

            // Escape hatch shown only after a denial. macOS sometimes records the
            // denial at the system level — Try again will re-fail until the user
            // flips the toggle in Privacy & Security manually.
            if didDeny, let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy") {
                Link(destination: url) {
                    HStack(spacing: 4) {
                        Text("Open Privacy Settings")
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .font(Tokens.Typography.Onboarding.small)
                    .foregroundStyle(Tokens.Color.accent(scheme))
                }
                .buttonStyle(.plain)
                .padding(.top, Tokens.Spacing.s3)
            }

            Spacer(minLength: Tokens.Spacing.s5)

            WindowFooter {
                BackLink(action: onBack)
            } trailing: {
                Button(didDeny ? "Try again" : "Continue", action: onContinue)
                    .buttonStyle(.tokenPrimary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// Surface card matching DetectStep's `.check-row` (22pt icon · name + sublabel
    /// column · 14pt gap · 12×16 padding · 1px border · sm radius). No right
    /// meta column — these rows are explainers, not status.
    private func permissionRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: Tokens.Spacing.s4 - 2) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Tokens.Color.accent(scheme))
                .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Tokens.Typography.Onboarding.body.weight(.medium))
                    .foregroundStyle(Tokens.Color.text(scheme))

                Text(detail)
                    .font(.custom("DM Sans", size: 12))
                    .foregroundStyle(Tokens.Color.textMuted(scheme))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, Tokens.Spacing.s4)
        .padding(.horizontal, Tokens.Spacing.s5 - 4)
        .background(Tokens.Color.surface(scheme))
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.sm)
                .strokeBorder(Tokens.Color.border(scheme), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.sm))
    }
}

// MARK: - Preview
//
// No stepper — Permissions runs once across the whole app, while the stepper
// (Checking tools → Installing → Signing in → Connection check) is per-provider
// chrome that lives inside ConnectorView. Welcome and Chooser preview the same way.

private struct PermissionsPreviewWrapper: View {
    let didDeny: Bool

    var body: some View {
        PermissionsStepBody(didDeny: didDeny, onContinue: {}, onBack: {})
            .padding(.top, Tokens.Spacing.s6)
            .padding(.horizontal, 40)
            .padding(.bottom, Tokens.Spacing.s5 + 4)
            .frame(width: 720, height: 560)
            .background(Tokens.DynamicColor.bg)
    }
}

#Preview("Permissions — initial — light") {
    PermissionsPreviewWrapper(didDeny: false)
        .preferredColorScheme(.light)
}

#Preview("Permissions — initial — dark") {
    PermissionsPreviewWrapper(didDeny: false)
        .preferredColorScheme(.dark)
}

#Preview("Permissions — denied — light") {
    PermissionsPreviewWrapper(didDeny: true)
        .preferredColorScheme(.light)
}

#Preview("Permissions — denied — dark") {
    PermissionsPreviewWrapper(didDeny: true)
        .preferredColorScheme(.dark)
}
