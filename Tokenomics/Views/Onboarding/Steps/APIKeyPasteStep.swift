import SwiftUI

/// "Paste your API key" screen — Pattern E step 2.
///
/// Renders a secure text field with monospaced font, an inline "Save & connect"
/// button, and a "Generate a new one →" link back to the provider's key page.
///
/// Called when the connector is in the `.pasteAPIKey` step.
struct APIKeyPasteStep: View {
    /// The provider's display name — used in helper text.
    var providerName: String

    /// URL to the provider's API key generation page (shown as "Generate a new one →").
    var helpURL: URL?

    /// Called when the user taps "Save & connect" with a non-empty key.
    var onSubmit: (String) -> Void

    /// Called when the user taps Back.
    var onBack: (() -> Void)?

    @State private var apiKey: String = ""
    @State private var isSubmitting: Bool = false
    @Environment(\.tokenomicsTextSize) private var textSize

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(alignment: .leading, spacing: 16) {
                // Headline + body
                VStack(alignment: .leading, spacing: 8) {
                    Text("Paste your API key")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, alignment: .center)

                    Text("Saved to macOS Keychain. Tokenomics reads it only when checking your usage — never sends it anywhere else.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }

                // Secure input field + paste shortcut
                secureInputRow

                // "Generate a new one →" link
                if let url = helpURL {
                    HStack {
                        Spacer()
                        Link(destination: url) {
                            Text("Generate a new one →")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
            }
            .padding(.horizontal, 16)

            Spacer()

            // Action stack
            VStack(spacing: 8) {
                Button {
                    guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                    isSubmitting = true
                    onSubmit(apiKey)
                } label: {
                    if isSubmitting {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("Save & connect")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)

                if let onBack {
                    Button("Back", action: onBack)
                        .buttonStyle(.plain)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Secure input row

    /// Monospaced secure field with an inline "Paste" shortcut button.
    private var secureInputRow: some View {
        HStack(spacing: 8) {
            SecureField("sk-••••••••••••••••••••••••••••", text: $apiKey)
                .font(.system(.callout, design: .monospaced))
                .textFieldStyle(.plain)
                .frame(maxWidth: .infinity)

            Button("Paste") {
                if let clip = NSPasteboard.general.string(forType: .string) {
                    apiKey = clip.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(nsColor: .controlBackgroundColor))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    Color(nsColor: .separatorColor),
                    style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Preview

#Preview("Paste API key — empty") {
    APIKeyPasteStep(
        providerName: "Stability AI",
        helpURL: URL(string: "https://platform.stability.ai/account/keys"),
        onSubmit: { _ in },
        onBack: {}
    )
    .frame(width: 360, height: 420)
}

#Preview("Paste API key — with key") {
    APIKeyPasteStep(
        providerName: "ElevenLabs",
        helpURL: URL(string: "https://elevenlabs.io/app/settings/api-keys"),
        onSubmit: { _ in },
        onBack: {}
    )
    .frame(width: 360, height: 420)
}
