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
    nonisolated let mode: ConnectorMode = .guided

    private static let log = Logger(subsystem: "com.robstout.tokenomics", category: "GeminiConnector")
    private static let npmPackage = "@google/gemini-cli"

    private let provider: GeminiProvider
    private let runner: EmbeddedCLIRunner

    // MARK: - In-flight state

    private enum ActivePhase {
        case none
        case installing(progress: Double?)
        case awaitingOAuth(code: String?)
    }

    private var activePhase: ActivePhase = .none

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
        case .awaitingOAuth(let code):
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
        case .awaitingOAuth:
            // Reopen browser — re-launch the CLI which will re-print the URL.
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

        activePhase = .awaitingOAuth(code: nil)

        // Gemini CLI triggers OAuth on first invocation (no separate login subcommand).
        // Passing `--no-update-check` skips an update nag that can appear on first run
        // and delay the auth URL appearing. If the flag isn't supported, the CLI will
        // still work — it'll just print a warning we discard.
        let args = ["--no-update-check"]

        do {
            let events = try await runner.runCLI(binary: binary, args: args)
            for await event in events {
                switch event {
                case .stdout(let line):
                    Self.log.debug("[gemini stdout] \(line)")
                case .stderr(let line):
                    Self.log.debug("[gemini stderr] \(line)")
                case .deviceCode(let url, let code):
                    // Google's OAuth device flow: code is typically nil (no short code).
                    // We open the browser automatically and show "Waiting for sign-in…"
                    activePhase = .awaitingOAuth(code: code)
                    await openOnMain(url)
                    Self.log.info("Gemini auth URL detected: \(url)")
                case .exited(let code):
                    Self.log.info("gemini exited with code \(code)")
                    // Don't clear phase — let the polling loop detect oauth_creds.json.
                }
            }
        } catch {
            Self.log.error("gemini login error: \(error.localizedDescription)")
            activePhase = .none
        }
    }

    // MARK: - Helpers

    @MainActor
    private func openOnMain(_ url: URL) {
        NSWorkspace.shared.open(url)
    }
}
