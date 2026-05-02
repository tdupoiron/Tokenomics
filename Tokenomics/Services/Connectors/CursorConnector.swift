import Foundation
import AppKit
import os

/// Guided-mode connector for Cursor.
///
/// Flow (Pattern D — "download an app, sign into it, wait for both"):
///   1. `currentStep()` checks for the Cursor.app bundle via NSWorkspace.
///   2. If not found + `.none` phase → `.needsAction`.
///   3. `performPrimaryAction()` from `.needsAction` → `.confirmingInstall`.
///   4. User taps "Open cursor.com" → `confirmInstall()` opens the browser
///      and transitions to `.waitingForBundle`.
///   5. Polling loop re-calls `currentStep()` every 1.5s. When the Cursor
///      bundle is detected AND the auth file exists, the flow is done.
///
/// Cursor is unique: Tokenomics does not manage the install. We hand off
/// to cursor.com and poll for two signals — the app bundle *and* the user's
/// sign-in (the JWT only appears in Cursor's local config after first launch).
actor CursorConnector: ProviderConnector {
    nonisolated let id: ProviderId = .cursor
    nonisolated let pipelineKind: ConnectorPipelineKind = .multiStep

    private static let log = Logger(subsystem: "com.robstout.tokenomics", category: "CursorConnector")
    private static let downloadURL = URL(string: "https://cursor.com/downloads")!
    private static let cursorBundleID = "com.todesktop.230313mzl4w4u92"

    private let provider: CursorProvider

    // MARK: - Internal state machine

    private enum ActivePhase {
        /// No action in progress — detect from scratch.
        case none
        /// Showing the "Install Cursor" confirm screen before opening cursor.com.
        case confirmingInstall
        /// Browser is open; polling for the app bundle + sign-in to appear.
        case waitingForBundle
    }

    private var activePhase: ActivePhase = .none

    // MARK: - Init

    init(provider: CursorProvider = CursorProvider()) {
        self.provider = provider
    }

    // MARK: - ProviderConnector

    nonisolated var stepperLabels: (step1: String, step2: String, step3: String, step4: String) {
        ("Checking tools", "Installing Cursor", "Signing in", "Connection check")
    }

    func currentStep() async -> ConnectorStep {
        switch activePhase {
        case .confirmingInstall:
            return .confirmingInstall(
                title: "Install Cursor",
                body: "Cursor is a separate Mac app. Once it's installed and you've signed in to it once, Tokenomics will pick up your usage automatically.",
                commandPreview: "https://cursor.com/downloads",
                footnote: "cursor.com/downloads is Cursor's official download page. We're just opening it for you — same place you'd land if you searched \"Cursor download.\"",
                skipLabel: "Already installed Cursor? Check now"
            )

        case .waitingForBundle:
            // Peek at provider — Cursor may have just been installed and signed in.
            let state = await provider.checkConnection()
            if case .connected(let plan) = state {
                activePhase = .none
                return .connected(plan: plan)
            }
            return .waitingForExternalApp

        case .none:
            break
        }

        // No active phase — delegate to provider.
        let state = await provider.checkConnection()
        switch state {
        case .connected(let plan):
            return .connected(plan: plan)
        case .notInstalled:
            return .needsAction
        case .installedNoAuth:
            // App bundle is present but sign-in hasn't completed. Surface the
            // confirm screen so user knows to sign in inside Cursor.
            activePhase = .confirmingInstall
            return .confirmingInstall(
                title: "Install Cursor",
                body: "Cursor is installed — sign in inside the app once and Tokenomics will pick up your usage automatically.",
                commandPreview: "https://cursor.com/downloads",
                footnote: "Open Cursor and sign in with your account. Tokenomics checks automatically.",
                skipLabel: "I've signed in — check now"
            )
        case .authExpired:
            return .needsAction
        case .unavailable(let reason):
            return .failed(.unknown(reason))
        }
    }

    func performPrimaryAction() async {
        switch activePhase {
        case .waitingForBundle:
            // "Check now" — just re-detect; polling loop handles it.
            return
        case .none:
            // Transition to confirm screen before opening the browser.
            activePhase = .confirmingInstall
        default:
            return
        }
    }

    func confirmInstall() async {
        guard case .confirmingInstall = activePhase else { return }
        // Open cursor.com in the default browser.
        await openOnMain(Self.downloadURL)
        activePhase = .waitingForBundle
    }

    func skipInstall() async {
        // "Already installed? Check now" — re-detect from scratch.
        activePhase = .none
    }

    func cancel() async {
        activePhase = .none
    }

    func clearFailure() async {
        activePhase = .none
    }

    // MARK: - Helpers

    @MainActor
    private func openOnMain(_ url: URL) {
        NSWorkspace.shared.open(url)
    }
}
