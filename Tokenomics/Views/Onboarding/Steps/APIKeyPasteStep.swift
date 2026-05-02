import SwiftUI

/// "Paste your API key" screen — Pattern E step 2.
///
/// Renders a secure text field with monospaced font, an inline "Paste" button-in-field,
/// and a "Generate a new one →" text link.
///
/// Layout matches mockup section 11 (.secure-input, lines ~820–858):
///   - Headline h2 "Paste your API key"
///   - Lede "Saved to macOS Keychain..."
///   - Secure input: surface bg, border-strong, r-sm, mono 13px
///     Focus: border accent, shadow ring
///   - Inline "Paste" button: .tokenInField style
///   - Helper "Generate a new one →" text link
///   - Footer: Back ghost | "Save & connect" primary
struct APIKeyPasteStep: View {
    /// The provider's display name — used in helper text.
    var providerName: String

    /// URL to the provider's API key generation page.
    var helpURL: URL?

    /// Called when the user taps "Save & connect" with a non-empty key.
    var onSubmit: (String) -> Void

    /// Called when the user taps Back.
    var onBack: (() -> Void)?

    @State private var apiKey: String = ""
    @State private var isSubmitting: Bool = false
    @State private var isFocused: Bool = false

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(alignment: .leading, spacing: Tokens.Spacing.s4) {
                // Headline + body — centered
                VStack(alignment: .leading, spacing: Tokens.Spacing.s2) {
                    Text("Paste your API key")
                        .font(Tokens.Typography.Onboarding.h2)
                        .foregroundStyle(Tokens.Color.text(scheme))
                        .frame(maxWidth: .infinity, alignment: .center)

                    Text("Saved to macOS Keychain. Tokenomics reads it only when checking your usage — never sends it anywhere else.")
                        .font(Tokens.Typography.Onboarding.lede)
                        .foregroundStyle(Tokens.Color.textMuted(scheme))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }

                // Secure input row with inline Paste button
                secureInputRow

                // "Generate a new one →" text link
                if let url = helpURL {
                    HStack {
                        Spacer()
                        Link(destination: url) {
                            Text("Lost your key? Generate a new one →")
                                .font(Tokens.Typography.Onboarding.small)
                                .foregroundStyle(Tokens.Color.accent(scheme))
                        }
                        Spacer()
                    }
                }
            }
            // No outer page padding — ConnectorView wraps content with the
            // mockup .winbody inset (32 top / 40 sides / 28 bottom).

            Spacer()

            // Footer: Back ghost | Save & connect primary
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Secure input row

    /// Monospaced secure field with an inline "Paste" shortcut button.
    /// mockup .secure-input (lines 820–858):
    ///   bg surface, border 1px border-strong, r-sm, mono 13px
    ///   focus: border accent + shadow-ring (0 0 0 4px accent@18%)
    private var secureInputRow: some View {
        HStack(spacing: Tokens.Spacing.s1 + 2) { // 6pt gap
            SecureField("sk-••••••••••••••••••••••••••••", text: $apiKey)
                .font(.system(size: 13, design: .monospaced))
                .textFieldStyle(.plain)
                .frame(maxWidth: .infinity)
                .onSubmit {
                    submitIfValid()
                }

            // Inline "Paste" button — .tokenInField style
            Button("Paste") {
                if let clip = NSPasteboard.general.string(forType: .string) {
                    apiKey = clip.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            .buttonStyle(.tokenInField)
        }
        // Container: padding 8px 8px 8px 14px (mockup)
        .padding(.leading, Tokens.Spacing.s4 - 2)   // 14pt
        .padding(.trailing, Tokens.Spacing.s2)       // 8pt
        .padding(.vertical, Tokens.Spacing.s2)       // 8pt
        .background(Tokens.Color.surface(scheme))
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.sm)
                .strokeBorder(
                    isFocused ? Tokens.Color.accent(scheme) : Tokens.Color.borderStrong(scheme),
                    lineWidth: 1
                )
        )
        // Focus ring: 0 0 0 4px accent@18% — mockup --shadow-ring
        .shadow(
            color: isFocused ? Tokens.Color.accent(scheme).opacity(0.18) : .clear,
            radius: 4, x: 0, y: 0
        )
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.sm))
        // Track focus state via onAppear + keyboard observation isn't clean in macOS;
        // using a simple FocusState binding approach.
        .onTapGesture { isFocused = true }
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

            Button {
                submitIfValid()
            } label: {
                if isSubmitting {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text("Save & connect")
                }
            }
            .buttonStyle(.tokenPrimary)
            .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
        }
        .padding(.top, Tokens.Spacing.s5)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Tokens.Color.border(scheme))
                .frame(height: 1)
        }
        // No outer page padding — ConnectorView's winbody inset handles it.
    }

    // MARK: - Helpers

    private func submitIfValid() {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isSubmitting = true
        onSubmit(apiKey)
    }
}

// MARK: - Preview

#Preview("Paste API key — empty — light") {
    APIKeyPasteStep(
        providerName: "Stability AI",
        helpURL: URL(string: "https://platform.stability.ai/account/keys"),
        onSubmit: { _ in },
        onBack: {}
    )
    .frame(width: 680, height: 580)
    .background(Tokens.DynamicColor.bg)
    .preferredColorScheme(.light)
}

#Preview("Paste API key — empty — dark") {
    APIKeyPasteStep(
        providerName: "Stability AI",
        helpURL: URL(string: "https://platform.stability.ai/account/keys"),
        onSubmit: { _ in },
        onBack: {}
    )
    .frame(width: 680, height: 580)
    .background(Tokens.DynamicColor.bg)
    .preferredColorScheme(.dark)
}

#Preview("Paste API key — ElevenLabs — light") {
    APIKeyPasteStep(
        providerName: "ElevenLabs",
        helpURL: URL(string: "https://elevenlabs.io/app/settings/api-keys"),
        onSubmit: { _ in },
        onBack: {}
    )
    .frame(width: 680, height: 580)
    .background(Tokens.DynamicColor.bg)
    .preferredColorScheme(.light)
}
