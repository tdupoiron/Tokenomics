import Foundation

// MARK: - Connector pipeline kind

/// Engineering classification of a connector's internal flow shape. Distinct
/// from the user-facing "Quick setup / Guided setup" badge in the provider
/// chooser — that label is decided per-provider in `ProviderChooserView` based
/// on user-perceived effort, not on whether the connector has internal steps.
///
/// E.g. CodexConnector has a `.multiStep` pipeline (detect → install → login →
/// awaitOAuth) but its chooser badge is "Quick setup" because Tokenomics hides
/// every step from the user behind a single sign-in click.
enum ConnectorPipelineKind: Sendable {
    /// Single-shot flow: detect the existing tool's auth and we're done.
    /// Used for Cursor, Copilot, Claude (direct OAuth), and API-key providers.
    case singleShot

    /// Multi-step state machine that the connector view drives through
    /// detecting → installing → awaitingOAuth → connected. Used for Codex
    /// and Gemini, which install a CLI and then run an OAuth handoff.
    case multiStep
}

// MARK: - Connector step

/// The state machine driving a single provider's "from zero to connected" flow.
///
/// Built on top of `ProviderConnectionState` (`Provider.swift:372`) but adds
/// the in-progress states (downloading / installing / waitingForOAuth) that
/// the new flow needs to surface in UI.
enum ConnectorStep: Sendable, Equatable {
    /// Initial — checking whether the provider is already connected.
    case detecting

    /// Provider is not installed/connected. Show the primary install or sign-in CTA.
    case needsAction

    /// User started an external app install (e.g., Cursor.app from cursor.com).
    /// Polling for the bundle to appear.
    case waitingForExternalApp

    /// Tokenomics is running a hidden CLI install (Guided mode, V1 bundled-Node flow).
    /// `progress` is 0–1 if known, nil for indeterminate.
    case installing(progress: Double?)

    /// OAuth handoff — browser is open. Optional device code for guided flows.
    case awaitingOAuth(code: String?)

    /// The connector's subprocess is asking for explicit user confirmation
    /// before proceeding (e.g. gemini's "Open browser? [Y/n]"). The view
    /// surfaces this as a Tokenomics-native confirm step rather than
    /// auto-answering, so the user's consent to launch the external auth
    /// flow is captured by an explicit click in our UI.
    case awaitingUserConfirm(message: String)

    /// Successfully connected.
    case connected(plan: String)

    /// Asks the user to confirm an install action before it begins. Rendered with
    /// `ConfirmInstallStep` (Continue / skip link).
    ///
    /// - Parameters:
    ///   - title: Short headline. E.g. "Install Homebrew"
    ///   - body: Explanation of why this is needed.
    ///   - commandPreview: The exact shell command Tokenomics will run. Nil hides the card.
    ///   - footnote: Source/runtime/disk disclosure shown below the command card.
    ///   - skipLabel: Text for the skip link. E.g. "Already have Homebrew? Skip this step"
    case confirmingInstall(
        title: String,
        body: String,
        commandPreview: String? = nil,
        footnote: String? = nil,
        skipLabel: String = "I already have this"
    )

    /// Tokenomics is installing a prerequisite (Homebrew, Node.js, etc.) — distinct
    /// from `.installing(progress:)` which is reserved for the primary CLI install
    /// (codex, gemini). Lets the view label "Installing Node.js…" vs "Installing Codex CLI…".
    case installingDependency(name: String, progress: Double?)

    /// Preview screen: explains a multi-step thing the user is about to do
    /// somewhere outside Tokenomics (e.g. Claude Code's sign-in wizard).
    /// Used for Windows 3 and 4 of the Anthropic flow.
    /// `primaryLabel` controls the button text — "Continue" for Window 3,
    /// "Open Terminal" for Window 4.
    /// `headsUp` is an optional advisory callout shown below the step list (Window 4 only).
    case previewExternalSteps(
        headline: String,
        body: String,
        items: [String],
        primaryLabel: String,
        headsUp: String? = nil
    )

    /// Tokenomics has handed off to an external CLI auth flow and is polling
    /// for the credentials file to appear. Used for Window 5 of the Anthropic flow.
    case awaitingExternalAuth(headline: String, body: String)

    /// Something went wrong; show recovery affordance.
    case failed(ConnectorError)
}

// MARK: - Connector error

/// Recoverable failures a connector may surface. Each carries a recovery action
/// so the connector view can render a single concrete next-step button.
enum ConnectorError: Sendable, Equatable {
    case oauthCancelled
    case oauthFailed(String)
    case cliInstallFailed(String)
    case detectionTimeout
    case appNotFound(bundleId: String)
    case keychainWriteFailed
    case unknown(String)

    // MARK: Install-specific errors (Step 5)

    /// User dismissed the macOS admin authorization dialog for the Homebrew install script.
    case homebrewInstallCancelled

    /// Network failure during `brew install` — the install script couldn't reach
    /// GitHub or Homebrew's CDN.
    case homebrewNotReachable

    /// `brew install --cask <name>` failed for a reason other than network.
    /// Carries the last stderr line for logging; not shown verbatim to users.
    case caskInstallFailed(String)

    /// macOS Automation (TCC) denied Tokenomics the right to control Terminal.app
    /// via AppleScript. The user needs to grant it in System Settings.
    case automationPermissionDenied

    /// A binary we expected to find after an install step wasn't there.
    /// Carries the human-readable name of the missing tool.
    case missingPrerequisite(String)

    var userFacingMessage: String {
        switch self {
        case .oauthCancelled:
            return "Sign-in was cancelled."
        case .oauthFailed(let detail):
            return "Sign-in didn't complete. \(detail)"
        case .cliInstallFailed(let detail):
            return "Setup couldn't finish. \(detail)"
        case .detectionTimeout:
            return "We didn't detect a sign-in. If you finished signing in, tap Check now."
        case .appNotFound(let bundleId):
            return "We couldn't find that app on your Mac. (\(bundleId))"
        case .keychainWriteFailed:
            return "We couldn't securely store your sign-in. Check Keychain Access permissions."
        case .unknown(let detail):
            return detail
        case .homebrewInstallCancelled:
            return "Homebrew install was cancelled. You'll need to approve the admin prompt to continue."
        case .homebrewNotReachable:
            return "Homebrew couldn't download. Check your internet connection and try again."
        case .caskInstallFailed:
            return "The install didn't complete. Check that Homebrew is working and try again."
        case .automationPermissionDenied:
            return "Tokenomics needs permission to open Terminal. Go to System Settings → Privacy & Security → Automation and allow it."
        case .missingPrerequisite(let name):
            return "We couldn't find \(name) after installing it. Try re-running detection."
        }
    }

    /// What the recovery button should say. Single concrete action — never a dead end.
    var recoveryActionLabel: String {
        switch self {
        case .oauthCancelled, .oauthFailed: return "Try sign-in again"
        case .cliInstallFailed: return "Try setup again"
        case .detectionTimeout: return "Check now"
        case .appNotFound: return "Show me how"
        case .keychainWriteFailed: return "Try again"
        case .unknown: return "Try again"
        case .homebrewInstallCancelled: return "Try install again"
        case .homebrewNotReachable: return "Retry"
        case .caskInstallFailed: return "Retry"
        case .automationPermissionDenied: return "Open System Settings"
        case .missingPrerequisite: return "Re-detect"
        }
    }
}

// MARK: - Connector protocol

/// One concrete connector per provider. Encapsulates the "from zero to connected"
/// state machine and presents a uniform surface to `ConnectorViewModel`.
///
/// Conformers are typically `actor`s so detection/install work runs off the main
/// thread; the view model marshals state back to MainActor.
protocol ProviderConnector: Actor {
    /// Which provider this connector handles.
    nonisolated var id: ProviderId { get }

    /// The connector's internal flow shape. Engineering classification only —
    /// see `ConnectorPipelineKind` for why this is separate from the chooser's
    /// user-facing "Quick / Guided" badge.
    nonisolated var pipelineKind: ConnectorPipelineKind { get }

    /// One-shot detection. Called by the view model on appear and after the user
    /// taps the recovery action. Should return quickly (no long network waits).
    func currentStep() async -> ConnectorStep

    /// Performs the primary action for the current step (e.g., open a download URL,
    /// kick off OAuth, run the bundled CLI install). The view model polls
    /// `currentStep()` afterward to advance the state machine.
    func performPrimaryAction() async

    /// User cancelled or backed out. Connectors should clean up any in-flight work
    /// (kill subprocess, dismiss browser handoff state, etc.).
    func cancel() async

    /// User tapped "Continue" on the `.confirmingInstall` step. The connector
    /// should proceed with the install it was waiting to start.
    func confirmInstall() async

    /// User tapped "I already have this" on the `.confirmingInstall` step. The
    /// connector should skip the pending install and re-run prerequisite detection.
    func skipInstall() async

    /// User tapped Continue / the primary button on a `.previewExternalSteps` step.
    /// The connector advances its internal phase to the next preview or hands off
    /// to an external tool. Default implementation is a no-op so connectors that
    /// don't use preview steps don't need to implement this.
    func advancePreview() async

    /// Clears any recorded failure so the connector returns a live step on the
    /// next `currentStep()` call. Called by `ConnectorViewModel.tappedRecovery()`
    /// before restarting the polling loop — without this, the first poll after
    /// retry immediately sees the stale `failedState` and bounces back to `.failed`.
    func clearFailure() async
}

// MARK: - Default no-op implementations

extension ProviderConnector {
    /// Default no-op — connectors that don't use `.confirmingInstall` don't need this.
    func confirmInstall() async {}

    /// Default no-op — connectors that don't use `.confirmingInstall` don't need this.
    func skipInstall() async {}

    /// Default no-op — only `ClaudeConnector` currently uses preview steps.
    func advancePreview() async {}

    /// Default no-op — connectors that never set `failedState` don't need this.
    func clearFailure() async {}
}
