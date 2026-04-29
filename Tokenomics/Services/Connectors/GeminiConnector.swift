import Foundation
import AppKit
import os

/// Guided-mode connector for Google's Gemini CLI.
///
/// Flow is parallel to `CodexConnector` — see that file for architecture notes.
///
/// Gemini specifics vs Codex:
///   - npm package: `@google/gemini-cli`
///   - Auth file: `~/.gemini/oauth_creds.json`
///   - Login trigger: `gemini` (no explicit `login` subcommand — the CLI starts
///     an OAuth flow on first invocation when no creds are found). Alternatively,
///     `gemini --help` or any benign subcommand also triggers auth.
///   - Device code format: Google's device-code flow prints a URL like
///     `https://accounts.google.com/o/oauth2/device/...` and instructs the user
///     to open it. There is no separate short code displayed. We use
///     `.awaitingOAuth(code: nil)` and rely on the browser tab Gemini opens
///     automatically.
///
/// Policy note: we call neither `googleapis.com` nor any Google backend directly.
/// Tokenomics runs `gemini` as a subprocess (the official CLI auth flow) and
/// reads the local `oauth_creds.json` it produces. This is Path C — safe.
actor GeminiConnector: ProviderConnector {
    nonisolated let id: ProviderId = .gemini
    nonisolated let pipelineKind: ConnectorPipelineKind = .multiStep

    private static let log = Logger(subsystem: "com.robstout.tokenomics", category: "GeminiConnector")
    private static let npmPackage = "@google/gemini-cli"

    private let provider: GeminiProvider
    private let runner: EmbeddedCLIRunner

    // MARK: - In-flight state

    private enum ActivePhase {
        case none
        case installing(progress: Double?)
        case awaitingUserConfirm(message: String)
        case awaitingOAuth(code: String?)
    }

    private var activePhase: ActivePhase = .none

    /// Closure for writing to the running subprocess's stdin. Captured from
    /// the runner's `RunCLIHandle` after launch, cleared when the process
    /// exits or is cancelled.
    private var pendingStdinWrite: (@Sendable (String) -> Void)?

    /// Confirmation prompt we look for in gemini's stdout. The CLI prints
    /// "Opening authentication page in your browser. Do you want to continue? [Y/n]:"
    /// before any browser open, so seeing this substring is our signal to
    /// pause and ask the user explicitly via Tokenomics' UI.
    private static let geminiConfirmPromptMarker = "Do you want to continue?"

    /// Tokenomics-native message we surface in the awaitingUserConfirm step —
    /// rephrases gemini's terminal prompt for a GUI audience and makes the
    /// out-of-app side effect explicit.
    private static let confirmDisplayMessage =
        "Tokenomics will open Google's sign-in page in your browser to connect Gemini. Continue?"

    // MARK: - Init

    init(provider: GeminiProvider = GeminiProvider()) {
        self.provider = provider
        self.runner = EmbeddedCLIRunner()
    }

    // MARK: - ProviderConnector

    func currentStep() async -> ConnectorStep {
        switch activePhase {
        case .installing(let progress):
            return .installing(progress: progress)
        case .awaitingUserConfirm(let message):
            return .awaitingUserConfirm(message: message)
        case .awaitingOAuth(let code):
            // Peek at the provider before short-circuiting — oauth_creds.json
            // may have just appeared if the user completed the browser flow.
            // The `gemini` subprocess may not exit promptly after the user
            // approves, so we can't rely on its exit to drive the state.
            let state = await provider.checkConnection()
            if case .connected(let plan) = state {
                activePhase = .none
                return .connected(plan: plan)
            }
            return .awaitingOAuth(code: code)
        case .none:
            break
        }

        let state = await provider.checkConnection()
        switch state {
        case .connected(let plan):
            return .connected(plan: plan)
        case .notInstalled:
            return .needsAction
        case .installedNoAuth:
            return .needsAction
        case .authExpired:
            return .needsAction
        case .unavailable(let reason):
            return .failed(.unknown(reason))
        }
    }

    func performPrimaryAction() async {
        switch activePhase {
        case .awaitingUserConfirm:
            // User just clicked "Continue" — answer gemini's prompt and let
            // the CLI proceed with opening the browser. Transition state
            // before writing so polling immediately reflects the change.
            activePhase = .awaitingOAuth(code: nil)
            pendingStdinWrite?("y\n")
            return
        case .awaitingOAuth:
            // Reopen browser — re-launch the CLI which will re-print the prompt.
            await launchLogin()
            return
        default:
            break
        }

        let state = await provider.checkConnection()
        switch state {
        case .connected:
            return
        case .notInstalled:
            await installAndLogin()
        case .installedNoAuth, .authExpired:
            await launchLogin()
        case .unavailable:
            return
        }
    }

    func cancel() async {
        await runner.cancel()
        activePhase = .none
        pendingStdinWrite = nil
    }

    // MARK: - Install pipeline

    private func installAndLogin() async {
        guard EmbeddedNode.isAvailable() else {
            activePhase = .none
            Self.log.error("Embedded Node not available — cannot install Gemini CLI")
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
                    Self.log.info("Gemini CLI installed successfully")
                    await launchLogin()
                    return
                case .failed(let reason):
                    Self.log.error("Gemini CLI install failed: \(reason)")
                    activePhase = .none
                    return
                }
            }
        } catch {
            Self.log.error("Gemini install error: \(error.localizedDescription)")
            activePhase = .none
        }
    }

    // MARK: - Login pipeline

    /// Resolves the gemini binary — prefers system-installed, falls back to embedded.
    private func geminiBinaryURL() -> URL? {
        let systemPaths = [
            "/opt/homebrew/bin/gemini",
            "/usr/local/bin/gemini",
            "\(NSHomeDirectory())/.local/bin/gemini"
        ]
        let fm = FileManager.default
        for path in systemPaths {
            if fm.isExecutableFile(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }
        let embeddedPath = EmbeddedCLIRunner.embeddedBinDir.appendingPathComponent("gemini")
        if fm.isExecutableFile(atPath: embeddedPath.path) {
            return embeddedPath
        }
        return nil
    }

    private func launchLogin() async {
        guard let binary = geminiBinaryURL() else {
            Self.log.error("gemini binary not found — cannot launch login")
            activePhase = .none
            return
        }

        // ~/.gemini/settings.json must declare an auth method or the CLI exits
        // immediately with "Please set an Auth method…". We add the minimum
        // required key, preserving any existing user settings.
        ensureGeminiAuthSettings()

        // Start in awaitingOAuth — once we see gemini's confirm prompt in
        // stdout we'll downgrade to awaitingUserConfirm so the user explicitly
        // approves opening their browser via Tokenomics' UI rather than us
        // auto-answering gemini's terminal prompt.
        activePhase = .awaitingOAuth(code: nil)

        do {
            let handle = try await runner.runCLI(binary: binary, args: [])
            pendingStdinWrite = handle.writeStdin

            for await event in handle.events {
                switch event {
                case .stdout(let line):
                    Self.log.debug("[gemini stdout] \(line)")
                    if line.contains(Self.geminiConfirmPromptMarker) {
                        // Gemini is blocked on the [Y/n] prompt. Park in
                        // awaitingUserConfirm and let the user click through
                        // Tokenomics' confirmation UI.
                        if case .awaitingUserConfirm = activePhase { break }
                        activePhase = .awaitingUserConfirm(message: Self.confirmDisplayMessage)
                    }
                case .stderr(let line):
                    Self.log.debug("[gemini stderr] \(line)")
                case .deviceCode:
                    // Not expected for gemini — it opens the browser itself
                    // once the confirm prompt is answered.
                    break
                case .exited(let code):
                    Self.log.info("gemini exited with code \(code)")
                    pendingStdinWrite = nil
                    // Don't clear phase — let the polling loop detect
                    // oauth_creds.json for the success transition.
                }
            }
        } catch {
            Self.log.error("gemini login error: \(error.localizedDescription)")
            activePhase = .none
            pendingStdinWrite = nil
        }
    }

    /// Writes the minimum settings.json needed for `gemini` to attempt OAuth
    /// when launched without a TTY. Preserves any existing keys the user may
    /// already have set; only adds `security.auth.selectedType` if absent.
    private func ensureGeminiAuthSettings() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let dir = home.appendingPathComponent(".gemini")
        let file = dir.appendingPathComponent("settings.json")
        let fm = FileManager.default

        do {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            Self.log.error("Failed to create ~/.gemini: \(error.localizedDescription)")
            return
        }

        var root: [String: Any] = [:]
        if let data = try? Data(contentsOf: file),
           let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            root = parsed
        }

        var security = root["security"] as? [String: Any] ?? [:]
        var auth = security["auth"] as? [String: Any] ?? [:]
        let existing = auth["selectedType"] as? String
        if existing == nil || existing?.isEmpty == true {
            auth["selectedType"] = "oauth-personal"
            security["auth"] = auth
            root["security"] = security

            do {
                let data = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted])
                try data.write(to: file, options: [.atomic])
                Self.log.info("Wrote default oauth-personal auth method to \(file.path)")
            } catch {
                Self.log.error("Failed to write ~/.gemini/settings.json: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Helpers

    @MainActor
    private func openOnMain(_ url: URL) {
        NSWorkspace.shared.open(url)
    }
}
