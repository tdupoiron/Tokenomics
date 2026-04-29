import SwiftUI

/// Universal connector view — handles every provider's "from zero to connected"
/// flow with consistent chrome. Currently implements Quick mode; Guided mode
/// (multi-step wizard with progress + device-code surface) lives behind the
/// same view model and will be added in a follow-up.
struct ConnectorView: View {
    @ObservedObject var viewModel: ConnectorViewModel
    var onBack: (() -> Void)? = nil

    @Environment(\.tokenomicsTextSize) private var textSize

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

            // 4-segment step indicator — hidden on states that don't warrant it.
            if !viewModel.stepperItems.isEmpty {
                OnboardingStepper(items: viewModel.stepperItems)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.2), value: viewModel.stepperItems)
            }

            Divider()

            ScrollView {
                content
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
            }
        }
        .navigationTitle("Connect \(viewModel.providerName)")
        .onAppear { viewModel.start() }
        .onDisappear { viewModel.stop() }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            if let onBack {
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .scaledFont(.caption)
                    .padding(.vertical, 4)
                    .padding(.trailing, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Text("Connect \(viewModel.providerName)")
                .scaledFont(.headline)
                .fontWeight(.medium)

            Spacer()

            // Invisible balance for centering when there's a back button.
            if onBack != nil {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
                .scaledFont(.caption)
                .hidden()
            }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch viewModel.step {
        case .connected(let plan):
            connectedState(plan: plan)
        case .failed(let error):
            errorState(error: error)
        case .detecting:
            DetectStep(message: detectMessage(for: viewModel.providerId))
        case .confirmingInstall(let title, let body, let commandPreview, let footnote, let skipLabel):
            ConfirmInstallStep(
                title: title,
                description: body,
                commandPreview: commandPreview,
                footnote: footnote,
                skipLabel: skipLabel,
                onContinue: { viewModel.tappedConfirmInstall() },
                onSkip: { viewModel.tappedSkipInstall() }
            )
        case .previewExternalSteps(let headline, let body, let items, let primaryLabel, let headsUp):
            PreviewExternalStepsView(
                headline: headline,
                introText: body,
                items: items,
                primaryLabel: primaryLabel,
                headsUp: headsUp,
                onPrimary: { viewModel.tappedAdvancePreview() },
                onBack: onBack
            )
        case .awaitingExternalAuth(let headline, let body):
            AwaitExternalAuthView(
                headline: headline,
                instructionText: body,
                onCheckNow: { viewModel.tappedRecheck() },
                onBack: onBack
            )
        default:
            inProgressState
        }
    }

    /// The shared "before connected" body — header row + status pill + CTA stack.
    private var inProgressState: some View {
        VStack(alignment: .leading, spacing: 0) {
            connectorHeader

            statusPill

            helpLink
                .padding(.top, 2)

            // 36pt breathing room above the primary CTA — matches the mockup.
            actionStack
                .padding(.top, 36)
        }
    }

    private var connectorHeader: some View {
        HStack(alignment: .center, spacing: 11) {
            ProviderIcon(provider: viewModel.providerId, size: .lg)

            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.providerName)
                    .scaledFont(.subheadline)
                    .fontWeight(.semibold)
                Text(headerSubtext)
                    .scaledFont(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.bottom, 8)
    }

    /// Sub-line under the provider name — varies by step.
    private var headerSubtext: String {
        switch viewModel.step {
        case .detecting:
            return "Checking your Mac…"
        case .needsAction:
            return needsActionSubtext(for: viewModel.providerId)
        case .waitingForExternalApp:
            return "Waiting for \(viewModel.providerName) to install…"
        case .installingDependency(let name, _):
            return "Installing \(name)…"
        case .installing:
            return "Setting up — only happens once."
        case .confirmingInstall:
            return "Almost there."
        case .awaitingUserConfirm:
            return "One quick confirmation before we continue."
        case .awaitingOAuth:
            return "Sign in in your browser to continue."
        case .previewExternalSteps:
            // Full-screen replacement — subtext not shown.
            return ""
        case .awaitingExternalAuth:
            // Full-screen replacement — subtext not shown.
            return ""
        case .connected:
            return "Connected."
        case .failed:
            return "Something didn't go through."
        }
    }

    @ViewBuilder
    private var statusPill: some View {
        switch viewModel.step {
        // These steps are full-screen replacements — no status pill.
        case .detecting, .confirmingInstall, .previewExternalSteps, .awaitingExternalAuth:
            EmptyView()
        case .needsAction:
            // No pill — primary CTA explains the next action.
            EmptyView()
        case .waitingForExternalApp:
            statusBadge(icon: .waiting, text: "Waiting for \(viewModel.providerName) — we'll detect it as soon as it's installed.")
        case .installingDependency(_, let progress):
            installingPill(progress: progress)
        case .installing(let progress):
            installingPill(progress: progress)
        case .awaitingUserConfirm(let message):
            statusBadge(icon: .waiting, text: message)
        case .awaitingOAuth(let code):
            statusBadge(icon: .waiting, text: "Waiting for you to approve in your browser…")
            if let code, !code.isEmpty {
                deviceCodeRow(code)
                    .padding(.top, 8)
            }
        case .connected, .failed:
            EmptyView()
        }
    }

    private var helpLink: some View {
        let anchor = viewModel.providerId.setupGuideAnchor
        let url = URL(string: "https://trytokenomics.com/setup.html\(anchor)")
        return HStack {
            Spacer()
            if let url {
                Link(destination: url) {
                    Text("Need help? Step-by-step guide")
                        .scaledFont(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
        }
    }

    @ViewBuilder
    private var actionStack: some View {
        VStack(spacing: 10) {
            Button(primaryCTALabel) {
                viewModel.tappedPrimary()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)

            // `.plain` style avoids the focus-loss that dismisses the
            // MenuBarExtra(.window) panel on click. Matches LoginView's
            // secondary "Refresh" pattern.
            Button("Cancel") {
                viewModel.tappedCancel()
                onBack?()
            }
            .buttonStyle(.plain)
            .scaledFont(.caption)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var primaryCTALabel: String {
        switch viewModel.step {
        // These steps own their own buttons — the action stack won't render for them
        // because `content` routes them to dedicated full-screen views.
        case .detecting, .confirmingInstall, .previewExternalSteps, .awaitingExternalAuth:
            return ""
        case .needsAction:
            return primaryCTA(for: viewModel.providerId)
        case .waitingForExternalApp:
            return "Check now"
        case .installingDependency:
            return "Installing…"
        case .installing:
            return "Setting up…"
        case .awaitingUserConfirm:
            return "Open browser to sign in"
        case .awaitingOAuth:
            return "Reopen browser"
        case .connected:
            return "Continue"
        case .failed(let error):
            return error.recoveryActionLabel
        }
    }

    // MARK: - Connected state

    private func connectedState(plan: String) -> some View {
        VStack(spacing: 0) {
            Image(systemName: "checkmark.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 48, height: 48)
                .foregroundStyle(.green)
                .padding(.top, 6)
                .padding(.bottom, 14)

            Text("\(viewModel.providerName) is connected.")
                .scaledFont(.headline)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)

            Text("Want to add another, or jump in?")
                .scaledFont(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
                .multilineTextAlignment(.center)

            VStack(spacing: 10) {
                Button("Add another provider") {
                    viewModel.tappedAddAnother()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)

                // `.plain` keeps the panel from dismissing on click.
                Button("I'm all set — show my usage") {
                    viewModel.tappedAllSet()
                }
                .buttonStyle(.plain)
                .scaledFont(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.top, 36)

            Text("Add or remove anytime in **Settings → Connections**.")
                .scaledFont(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.top, 12)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Error state

    private func errorState(error: ConnectorError) -> some View {
        VStack(spacing: 0) {
            connectorHeader

            statusBadge(icon: .warning, text: error.userFacingMessage)

            VStack(spacing: 10) {
                Button(error.recoveryActionLabel) {
                    if case .automationPermissionDenied = error {
                        // Open the Automation section in System Settings directly.
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
                            NSWorkspace.shared.open(url)
                        }
                    } else {
                        viewModel.tappedRecovery()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)

                if let onBack {
                    Button("Cancel") { onBack() }
                        .buttonStyle(.plain)
                        .scaledFont(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 36)
        }
    }

    // MARK: - Pieces

    private enum BadgeIcon { case waiting, success, warning }

    private func statusBadge(icon: BadgeIcon, text: String) -> some View {
        HStack(alignment: .center, spacing: 9) {
            Group {
                switch icon {
                case .waiting:
                    ProgressView().controlSize(.small)
                case .success:
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                case .warning:
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }
            .frame(width: 14, height: 14)

            Text(text)
                .scaledFont(.caption)
                .foregroundStyle(.primary)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .background(Color(nsColor: .quaternaryLabelColor).opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func installingPill(progress: Double?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .tint(.accentColor)
            HStack {
                Text("Almost there")
                    .scaledFont(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                if let progress {
                    Text("\(Int(progress * 100))%")
                        .scaledFont(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .background(Color(nsColor: .quaternaryLabelColor).opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func deviceCodeRow(_ code: String) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("If asked for a code")
                    .scaledFont(.caption2)
                    .foregroundStyle(.tertiary)
                    .textCase(.uppercase)
                Text(code)
                    .font(.system(.title3, design: .monospaced))
                    .fontWeight(.semibold)
                    .textSelection(.enabled)
            }
            Spacer()
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(code, forType: .string)
            } label: {
                Image(systemName: "doc.on.doc")
                    .scaledFont(.caption)
            }
            .buttonStyle(.borderless)
            .help("Copy code")
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.6), style: StrokeStyle(lineWidth: 0.5, dash: [3]))
        )
    }

    // MARK: - Per-provider copy helpers
    //
    // Lightweight string mapping until each connector overrides its own copy.
    // Centralizing here keeps the view file standalone for the first iteration.

    private func needsActionSubtext(for provider: ProviderId) -> String {
        switch provider {
        case .cursor: return "Tokenomics reads usage from the Cursor app on your Mac."
        case .copilot: return "Sign in once and we'll track your Copilot usage."
        case .claude: return "Sign in to your Anthropic account."
        case .codex: return "Sign in with your ChatGPT account."
        case .gemini: return "Sign in with your Google account."
        case .stableDiffusion, .runway, .elevenlabs: return "Paste an API key from the provider's website."
        default: return "Connect this provider to track its usage."
        }
    }

    private func primaryCTA(for provider: ProviderId) -> String {
        switch provider {
        case .cursor: return "Connect Cursor"
        case .copilot: return "Sign in with GitHub"
        case .claude: return "Sign in with Anthropic"
        case .codex: return "Sign in with OpenAI"
        case .gemini: return "Sign in with Google"
        case .stableDiffusion, .runway, .elevenlabs: return "Enter API key"
        default: return "Connect"
        }
    }

    private func detectMessage(for provider: ProviderId) -> String {
        switch provider {
        case .codex: return "Checking for Homebrew, Node.js, and the Codex CLI…"
        case .gemini: return "Checking for Homebrew, Node.js, and the Gemini CLI…"
        default: return "Checking your Mac…"
        }
    }
}
