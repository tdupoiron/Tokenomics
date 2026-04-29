import Foundation
import AppKit
import os

/// Guided-mode connector for OpenAI's Codex CLI.
///
/// Flow:
///   1. `currentStep()` delegates to `CodexProvider.checkConnection()` for the
///      initial detection. If the CLI and auth file both exist → `.connected`.
///   2. If the CLI is missing, `performPrimaryAction()` installs `@openai/codex`
///      via the bundled npm (EmbeddedCLIRunner) and transitions to
///      `.installing(progress:)`.
///   3. Once installed, we launch `codex login` as a hidden subprocess. Its
///      stdout is scanned for a device-code URL; when found we emit
///      `.awaitingOAuth(code:)` and open the URL automatically in the browser.
///   4. `ConnectorViewModel`'s polling loop (1.5s cadence) re-calls
///      `currentStep()`. When `~/.codex/auth.json` appears, `CodexProvider`
///      returns `.connected` and the connector flow is done.
///
/// Policy note: we call neither `api.openai.com` nor any OpenAI backend
/// directly. Tokenomics runs `codex login` (the official CLI auth flow) as a
/// subprocess and reads the local auth.json it produces. This is Path C from
/// the spike findings — safe and permitted.
actor CodexConnector: ProviderConnector {
    nonisolated let id: ProviderId = .codex
    nonisolated let pipelineKind: ConnectorPipelineKind = .multiStep

    private static let log = Logger(subsystem: "com.robstout.tokenomics", category: "CodexConnector")
    private static let npmPackage = "@openai/codex"

    private let provider: CodexProvider
    private let runner: EmbeddedCLIRunner

    // MARK: - In-flight state

    /// Tracks the active install/login phase so `currentStep()` can return the
    /// right state between provider-polling ticks.
    private enum ActivePhase {
        case none
        case installing(progress: Double?)
        case awaitingOAuth(code: String?)
    }

    private var activePhase: ActivePhase = .none

    // MARK: - Init

    init(provider: CodexProvider = CodexProvider()) {
        self.provider = provider
        self.runner = EmbeddedCLIRunner()
    }

    // MARK: - ProviderConnector

    func currentStep() async -> ConnectorStep {
        // Prefer in-flight phase state over provider-polling — the provider's
        // checkConnection() won't know we've started install/login yet.
        switch activePhase {
        case .installing(let progress):
            return .installing(progress: progress)
        case .awaitingOAuth(let code):
            // Peek at the provider before short-circuiting — auth.json may have
            // just appeared if the user completed the browser flow. The
            // `codex login` subprocess doesn't always exit promptly after the
            // user approves, so we can't rely on its exit to drive the state.
            let state = await provider.checkConnection()
            if case .connected(let plan) = state {
                activePhase = .none
                return .connected(plan: plan)
            }
            return .awaitingOAuth(code: code)
        case .none:
            break
        }

        // Delegate to the provider for terminal states.
        let state = await provider.checkConnection()
        switch state {
        case .connected(let plan):
            return .connected(plan: plan)
        case .notInstalled:
            // Check if the CLI is available via our embedded install path —
            // the provider's path check includes EmbeddedCLIRunner.embeddedBinDir.
            return .needsAction
        case .installedNoAuth:
            // CLI exists but no auth file — could be a partial state after install.
            // The user needs to run the login step; we'll handle that in performPrimaryAction.
            return .needsAction
        case .authExpired:
            return .needsAction
        case .unavailable(let reason):
            return .failed(.unknown(reason))
        }
    }

    /// Drives the install → login pipeline.
    ///
    /// Called by `ConnectorViewModel.tappedPrimary()`. May be called multiple
    /// times (e.g., the user taps "Reopen browser" while we're in awaitingOAuth).
    func performPrimaryAction() async {
        switch activePhase {
        case .awaitingOAuth:
            // User tapped "Reopen browser" — just re-open the browser if we have
            // a saved URL, or re-launch `codex login`.
            await launchLogin()
            return
        default:
            break
        }

        let state = await provider.checkConnection()

        switch state {
        case .connected:
            // Already connected — nothing to do.
            return
        case .notInstalled:
            // Install first, then login.
            await installAndLogin()
        case .installedNoAuth, .authExpired:
            // CLI is there but auth is missing or expired.
            await launchLogin()
        case .unavailable:
            // Surface the error via the state machine.
            return
        }
    }

    func cancel() async {
        await runner.cancel()
        activePhase = .none
    }

    // MARK: - Install pipeline

    private func installAndLogin() async {
        guard EmbeddedNode.isAvailable() else {
            activePhase = .none
            Self.log.error("Embedded Node not available — cannot install Codex CLI")
            // currentStep() will return .needsAction; the view will show the CTA again.
            // A more elaborate error path could be added here if needed.
            return
        }

        activePhase = .installing(progress: nil)

        do {
            let events = try await runner.install(npmPackage: Self.npmPackage)
            for await event in events {
                switch event {
                case .progress(let p):
                    activePhase = .installing(progress: p)
                case .log(let line):
                    Self.log.debug("[npm] \(line)")
                case .completed:
                    Self.log.info("Codex CLI installed successfully")
                    // Move on to login immediately.
                    await launchLogin()
                    return
                case .failed(let reason):
                    Self.log.error("Codex CLI install failed: \(reason)")
                    activePhase = .none
                    // ConnectorViewModel will re-check currentStep() and get
                    // .needsAction or a .failed state from the provider.
                    return
                }
            }
        } catch {
            Self.log.error("Codex install error: \(error.localizedDescription)")
            activePhase = .none
        }
    }

    // MARK: - Login pipeline

    /// Resolves the codex binary path — checks system PATH locations first so
    /// we prefer any existing install, falling back to our embedded prefix.
    private func codexBinaryURL() -> URL? {
        let systemPaths = [
            "/usr/local/bin/codex",
            "\(NSHomeDirectory())/.local/bin/codex",
            "/opt/homebrew/bin/codex"
        ]
        let fm = FileManager.default
        for path in systemPaths {
            if fm.isExecutableFile(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }
        let embeddedPath = EmbeddedCLIRunner.embeddedBinDir.appendingPathComponent("codex")
        if fm.isExecutableFile(atPath: embeddedPath.path) {
            return embeddedPath
        }
        return nil
    }

    private func launchLogin() async {
        guard let binary = codexBinaryURL() else {
            Self.log.error("codex binary not found — cannot launch login")
            activePhase = .none
            return
        }

        activePhase = .awaitingOAuth(code: nil)

        do {
            let handle = try await runner.runCLI(binary: binary, args: ["login"])
            for await event in handle.events {
                switch event {
                case .stdout(let line):
                    Self.log.debug("[codex stdout] \(line)")
                case .stderr(let line):
                    Self.log.debug("[codex stderr] \(line)")
                case .deviceCode(let url, let code):
                    // Surface the URL in the connector UI and open it automatically.
                    activePhase = .awaitingOAuth(code: code)
                    await openOnMain(url)
                    Self.log.info("Codex device-code URL detected: \(url)")
                case .exited(let code):
                    Self.log.info("codex login exited with code \(code)")
                    // Don't clear activePhase here — the polling loop will detect
                    // ~/.codex/auth.json and transition to .connected naturally.
                    // If the file never appears, the stuckThreshold kicks in.
                }
            }
        } catch {
            Self.log.error("codex login error: \(error.localizedDescription)")
            activePhase = .none
        }
    }

    // MARK: - Helpers

    @MainActor
    private func openOnMain(_ url: URL) {
        NSWorkspace.shared.open(url)
    }
}
