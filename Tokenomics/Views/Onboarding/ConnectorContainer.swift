import SwiftUI

/// Orchestrates the new onboarding flow: Welcome → Chooser → ConnectorView.
/// Owns the lifecycle of the active `ConnectorViewModel` and routes outcome
/// callbacks (Add another / I'm all set) back into the chooser or out to
/// onboarding completion.
///
/// When `OnboardingTarget.shared.preselected` is set before the window opens,
/// the container skips Welcome and Chooser and lands directly on that provider's
/// connector flow. Both "Add another" and "I'm all set" outcomes close the window
/// in that case, since the chooser context doesn't apply.
struct ConnectorContainer: View {
    @ObservedObject var viewModel: UsageViewModel

    /// Called when the user finishes onboarding (either by tapping "I'm all set"
    /// after connecting or by skipping).
    var onComplete: () -> Void

    @State private var screen: Screen = .welcome
    @State private var activeConnector: ConnectorViewModel?
    /// True when the current session was started via a pre-targeted provider link
    /// (Install / Sign In / Reconnect from Settings or popover). Used to treat
    /// "Add another" as "close window" rather than routing back to chooser.
    @State private var isPreTargeted = false

    enum Screen {
        case welcome
        case chooser
        case connector
    }

    var body: some View {
        Group {
            switch screen {
            case .welcome:
                WelcomeView(
                    onGetStarted: { screen = .chooser },
                    onSkip: completeOnboarding
                )
            case .chooser:
                ProviderChooserView(
                    viewModel: viewModel,
                    onPick: open(provider:),
                    onAllSet: completeOnboarding,
                    onBack: { screen = .welcome }
                )
            case .connector:
                if let active = activeConnector {
                    ConnectorView(
                        viewModel: active,
                        onBack: { screen = .chooser }
                    )
                } else {
                    // Defensive — shouldn't be reachable.
                    Color.clear.onAppear { screen = .chooser }
                }
            }
        }
        // Reset to chooser on re-entry so users who completed or cancelled a
        // previous flow don't land on a stale connector screen.
        .onAppear {
            // Pre-target takes priority: if a provider was queued, route there now.
            if let targetProvider = OnboardingTarget.shared.preselected {
                OnboardingTarget.shared.preselected = nil
                isPreTargeted = true
                open(provider: targetProvider)
                return
            }

            if screen == .connector && activeConnector == nil {
                screen = .chooser
            }
            // If the user previously finished onboarding but re-opened via Settings,
            // land on the chooser instead of welcome so they can add more providers.
            if viewModel.hasCompletedOnboarding && screen == .welcome {
                screen = .chooser
            }
        }
        // Also react when the window is already open and a pre-target arrives live.
        .onReceive(OnboardingTarget.shared.$preselected) { targetProvider in
            guard let targetProvider else { return }
            OnboardingTarget.shared.preselected = nil
            isPreTargeted = true
            open(provider: targetProvider)
        }
    }

    // MARK: - Navigation

    private func open(provider: ProviderId) {
        let connector = makeConnector(for: provider)
        activeConnector = ConnectorViewModel(
            connector: connector,
            onOutcome: { [self] outcome in
                switch outcome {
                case .addAnother:
                    if isPreTargeted {
                        // Pre-targeted sessions have no chooser context — treat as done.
                        completeOnboarding()
                    } else {
                        screen = .chooser
                        activeConnector = nil
                        viewModel.redetectProviders()
                    }
                case .allSet:
                    completeOnboarding()
                }
            }
        )
        screen = .connector
    }

    private func completeOnboarding() {
        viewModel.completeOnboarding()
        activeConnector = nil
        isPreTargeted = false
        onComplete()
    }

    // MARK: - Connector factory

    private func makeConnector(for provider: ProviderId) -> any ProviderConnector {
        switch provider {
        case .cursor:
            return CursorConnector()
        case .copilot:
            // Guided window: no PAT callback — flow uses gh auth login.
            return CopilotConnector()
        case .claude:
            return ClaudeConnector()
        case .codex:
            return CodexConnector()
        case .gemini:
            return GeminiConnector()
        case .stableDiffusion:
            return APIKeyConnector(
                providerId: .stableDiffusion,
                provider: StableDiffusionProvider()
            )
        case .runway:
            return APIKeyConnector(
                providerId: .runway,
                provider: RunwayProvider()
            )
        case .elevenlabs:
            return APIKeyConnector(
                providerId: .elevenlabs,
                provider: ElevenLabsProvider()
            )
        case .midjourney, .suno, .udio:
            // Coming Soon — picker disables these rows. Defensive fallback.
            return ClaudeConnector()
        }
    }
}
