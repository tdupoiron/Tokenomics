import SwiftUI

/// "Checking your Mac…" screen shown while prerequisite detection runs.
///
/// This is a read-only display — the connector's view model drives detection
/// and advances past this screen automatically. There are no buttons here.
///
/// Step 3 wires this into the Codex/Gemini connector flows. For now it renders
/// stand-alone so we can eyeball the chrome.
struct DetectStep: View {
    /// Displayed below the spinner. E.g. "Checking for Homebrew, Node.js,
    /// and the Codex CLI…"
    var message: String

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            ProgressView()
                .controlSize(.large)
                .padding(.bottom, 4)

            VStack(spacing: 6) {
                Text("Checking your Mac…")
                    .font(.headline)
                    .fontWeight(.semibold)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview

#Preview("Detect Step") {
    DetectStep(message: "Checking for Homebrew, Node.js, and the Codex CLI…")
        .frame(width: 320, height: 240)
}
