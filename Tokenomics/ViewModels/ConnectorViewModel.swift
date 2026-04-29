import SwiftUI
import os

/// Drives one provider's connector flow. Owns the polling timer that re-checks
/// the connector's state machine, marshals state from the provider's actor back
/// to the main actor for SwiftUI, and manages post-connection chaining
/// (Add another provider / I'm all set).
@MainActor
final class ConnectorViewModel: ObservableObject, Identifiable {
    /// Stable identifier so SwiftUI's `.sheet(item:)` can uniquely track this VM.
    let id = UUID()

    private static let log = Logger(subsystem: "com.robstout.tokenomics", category: "ConnectorViewModel")

    // MARK: - Published state

    @Published private(set) var step: ConnectorStep = .detecting

    /// Display name shown in the connector header.
    let providerName: String

    let providerId: ProviderId

    let pipelineKind: ConnectorPipelineKind

    // MARK: - Stepper

    /// Maps the current step to the 4-segment onboarding stepper items shown
    /// across the top of every connector screen. Returns an empty array for
    /// steps that show no stepper (failed, waitingForExternalApp).
    var stepperItems: [OnboardingStepperItem] {
        typealias Item = OnboardingStepperItem
        typealias S = OnboardingStepperItem.State
        let c: S = .completed; let a: S = .active; let u: S = .upcoming
        switch step {
        case .detecting, .needsAction:
            return [Item(label: "Checking", state: a), Item(label: "Installing", state: u),
                    Item(label: "Signing in", state: u), Item(label: "Done", state: u)]
        case .confirmingInstall, .installingDependency, .installing:
            return [Item(label: "Checking", state: c), Item(label: "Installing", state: a),
                    Item(label: "Signing in", state: u), Item(label: "Done", state: u)]
        case .previewExternalSteps, .awaitingOAuth, .awaitingUserConfirm, .awaitingExternalAuth:
            return [Item(label: "Checking", state: c), Item(label: "Installing", state: c),
                    Item(label: "Signing in", state: a), Item(label: "Done", state: u)]
        case .connected:
            return [Item(label: "Checking", state: c), Item(label: "Installing", state: c),
                    Item(label: "Signing in", state: c), Item(label: "Done", state: a)]
        case .failed, .waitingForExternalApp:
            return []
        }
    }

    // MARK: - Outcome

    /// Emitted when the user chooses what to do after connecting.
    enum Outcome {
        /// User wants to connect another provider next.
        case addAnother
        /// User is done with onboarding.
        case allSet
    }

    private let onOutcome: (Outcome) -> Void

    // MARK: - Internal

    private let connector: any ProviderConnector
    private var pollingTask: Task<Void, Never>?

    /// Polling cadence while detection / install / OAuth is in progress.
    private static let pollInterval: TimeInterval = 1.5

    // No static stuckThreshold — per-state thresholds are computed by stuckThreshold(for:).

    // MARK: - Init

    init(connector: any ProviderConnector,
         onOutcome: @escaping (Outcome) -> Void) {
        self.connector = connector
        self.providerId = connector.id
        self.providerName = connector.id.displayName
        self.pipelineKind = connector.pipelineKind
        self.onOutcome = onOutcome
    }

    // MARK: - Lifecycle

    /// Call from `.onAppear`. Kicks off the detection / polling loop.
    func start() {
        guard pollingTask == nil else { return }
        pollingTask = Task { [weak self] in
            await self?.runPollingLoop()
        }
    }

    /// Call from `.onDisappear` so the polling task stops.
    func stop() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    // MARK: - User actions

    /// Tap on the primary CTA — kick off whatever the connector needs (open
    /// download URL, start OAuth, run hidden install, etc.) and re-poll.
    func tappedPrimary() {
        Task { [connector] in
            await connector.performPrimaryAction()
        }
        // Force an immediate state refresh — don't wait for the next poll tick.
        Task { [weak self] in
            guard let self else { return }
            let current = await self.connector.currentStep()
            self.step = current
        }
    }

    /// Tap on the secondary cancel button.
    func tappedCancel() {
        Task { [connector] in
            await connector.cancel()
        }
    }

    /// Tap on "Continue" in the `.confirmingInstall` step.
    func tappedConfirmInstall() {
        Task { [connector] in
            await connector.confirmInstall()
        }
    }

    /// Tap on "I already have this" in the `.confirmingInstall` step.
    func tappedSkipInstall() {
        Task { [connector] in
            await connector.skipInstall()
        }
        // Immediately show detecting so the UI doesn't stay on the confirm screen.
        step = .detecting
    }

    /// Tap Continue in `.previewExternalSteps` — connector advances its internal
    /// phase (e.g. Window 3 → Window 4 → opens Terminal → Window 5).
    func tappedAdvancePreview() {
        Task { [connector] in
            await connector.advancePreview()
        }
        Task { [weak self] in
            guard let self else { return }
            let current = await self.connector.currentStep()
            self.step = current
        }
    }

    /// Tap "I'm signed in — check now" in `.awaitingExternalAuth` — kicks the
    /// polling loop awake immediately instead of waiting for the next tick.
    func tappedRecheck() {
        Task { [weak self] in
            guard let self else { return }
            let current = await self.connector.currentStep()
            self.step = current
        }
    }

    /// Tap on the recovery button when in `.failed` state.
    func tappedRecovery() {
        // Clear-failure must complete before polling resumes — otherwise the very
        // first `currentStep()` call sees stale `failedState` and bounces back to
        // `.failed` before the connector can re-detect.
        Task { [connector, weak self] in
            await connector.clearFailure()
            guard let self else { return }
            self.step = .detecting
            if self.pollingTask == nil { self.start() }
        }
    }

    /// Connected — user wants to add another provider.
    func tappedAddAnother() {
        onOutcome(.addAnother)
    }

    /// Connected — user wants to finish.
    func tappedAllSet() {
        onOutcome(.allSet)
    }

    // MARK: - Polling

    private func runPollingLoop() async {
        var stateEnteredAt = Date()
        var lastStep: ConnectorStep = .detecting

        while !Task.isCancelled {
            let current = await connector.currentStep()
            await MainActor.run { self.step = current }

            // Terminal states — stop polling.
            if case .connected = current { return }
            if case .failed = current { return }

            // Reset the clock whenever the state changes so slow user-driven
            // flows (OAuth in browser, reading docs) don't fire a spurious timeout.
            if current != lastStep {
                lastStep = current
                stateEnteredAt = Date()
            }

            // Stuck-detection: if the step hasn't changed in the per-state threshold
            // and we're in a waiting state, surface a timeout so the user has an
            // actionable next step.
            if Date().timeIntervalSince(stateEnteredAt) > stuckThreshold(for: current),
               isWaitingState(current) {
                await MainActor.run { self.step = .failed(.detectionTimeout) }
                return
            }

            try? await Task.sleep(nanoseconds: UInt64(Self.pollInterval * 1_000_000_000))
        }
    }

    /// Per-state stuck threshold.
    /// User-driven auth states get 10 minutes because the user is in their browser.
    /// Install/detection states get 3 minutes — they should complete automatically.
    private nonisolated func stuckThreshold(for step: ConnectorStep) -> TimeInterval {
        switch step {
        case .awaitingOAuth, .awaitingExternalAuth, .awaitingUserConfirm:
            return 600  // 10 min — user is in their browser
        default:
            return 180  // 3 min — install/detection should be much faster
        }
    }

    private nonisolated func isWaitingState(_ step: ConnectorStep) -> Bool {
        switch step {
        case .waitingForExternalApp, .installing, .installingDependency,
             .awaitingOAuth, .awaitingUserConfirm, .confirmingInstall,
             .awaitingExternalAuth:
            return true
        default:
            return false
        }
    }
}
