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
    /// `ConfirmInstallStep` (Continue / "I already have this").
    case confirmingInstall(title: String, body: String)

    /// Tokenomics is installing a prerequisite (Homebrew, Node.js, etc.) — distinct
    /// from `.installing(progress:)` which is reserved for the primary CLI install
    /// (codex, gemini). Lets the view label "Installing Node.js…" vs "Installing Codex CLI…".
    case installingDependency(name: String, progress: Double?)

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
}

// MARK: - Default no-op implementations

extension ProviderConnector {
    /// Default no-op — connectors that don't use `.confirmingInstall` don't need this.
    func confirmInstall() async {}

    /// Default no-op — connectors that don't use `.confirmingInstall` don't need this.
    func skipInstall() async {}
}
