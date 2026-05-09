import SwiftUI

/// Explainer step that primes the two macOS permission prompts triggered by
/// reading Claude Code's session token from the keychain. Sits between Welcome
/// and ProviderChooser so users know what's coming before macOS interrupts.
///
/// On Continue, fires `KeychainService.readAccessToken()` synchronously — that
/// single read produces the keychain ACL prompt and (on macOS 15+) the "data
/// from another app" prompt. The result is discarded; we only care about the
/// side-effect of triggering the system prompts at a predictable moment.
///
/// Layout matches DetectStep's checklist pattern: left-aligned h2 + lede,
/// two surface cards, WindowFooter with Back + Continue.
struct PermissionsStep: View {
    var onContinue: () -> Void
    var onBack: () -> Void

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: Tokens.Spacing.s2) {
                Text("macOS will ask twice")
                    .font(Tokens.Typography.Onboarding.h2)
                    .foregroundStyle(Tokens.Color.text(scheme))

                Text("Tokenomics reads where your AI tools store their session info so it can show usage. macOS protects you with two confirmations the first time.")
                    .font(Tokens.Typography.Onboarding.lede)
                    .foregroundStyle(Tokens.Color.textMuted(scheme))
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: Tokens.Spacing.s2) {
                permissionRow(
                    icon: "key.fill",
                    title: "Keychain access",
                    detail: "Lets Tokenomics read your Claude Code sign-in. Choose Always Allow so it doesn't ask again."
                )
                permissionRow(
                    icon: "rectangle.on.rectangle",
                    title: "Information from another app",
                    detail: "macOS treats Claude Code's keychain entry as cross-app data. One tap to allow."
                )
            }
            .padding(.top, Tokens.Spacing.s5)

            Spacer(minLength: Tokens.Spacing.s5)

            WindowFooter {
                BackLink(action: onBack)
            } trailing: {
                Button("Continue", action: triggerPromptsAndContinue)
                    .buttonStyle(.tokenPrimary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Permission row

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

    // MARK: - Actions

    /// Reading the Claude Code keychain item is what trips both prompts. Result
    /// is discarded — the read is purely side-effectful for permission gating.
    /// If the user already authorized in a previous session, this is a no-op.
    private func triggerPromptsAndContinue() {
        _ = KeychainService.readAccessToken()
        onContinue()
    }
}

// MARK: - Preview

private let permissionsStepperItems: [OnboardingStepperItem] = [
    .init(label: "Permissions",      state: .active),
    .init(label: "Pick a tool",      state: .upcoming),
    .init(label: "Connect",          state: .upcoming),
    .init(label: "Done",             state: .upcoming)
]

#Preview("Permissions — light") {
    WindowChromePreview(title: "Tokenomics setup", stepperItems: permissionsStepperItems) {
        PermissionsStep(onContinue: {}, onBack: {})
    }
    .frame(width: 720, height: 560)
    .preferredColorScheme(.light)
}

#Preview("Permissions — dark") {
    WindowChromePreview(title: "Tokenomics setup", stepperItems: permissionsStepperItems) {
        PermissionsStep(onContinue: {}, onBack: {})
    }
    .frame(width: 720, height: 560)
    .preferredColorScheme(.dark)
}
