import Foundation
#if os(macOS)
import AppKit
#endif

// MARK: - Provider Identity

/// Supported AI providers across coding, image, video, and audio categories
enum ProviderId: String, CaseIterable, Codable, Sendable, Identifiable {
    // Platforms (shared billing pools)
    case claude
    case codex
    case gemini
    // Coding Tools
    case copilot
    case cursor
    // Image Generation
    case stableDiffusion
    case midjourney
    // Video Generation
    case runway
    // Music / Audio / Voice
    case elevenlabs
    case suno
    case udio

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .claude: return "Anthropic"
        case .copilot: return "GitHub Copilot"
        case .cursor: return "Cursor"
        case .codex: return "OpenAI"
        case .gemini: return "Google AI"
        case .stableDiffusion: return "Stability AI"
        case .midjourney: return "Midjourney"
        case .runway: return "Runway"
        case .elevenlabs: return "ElevenLabs"
        case .suno: return "Suno"
        case .udio: return "Udio"
        }
    }

    /// Shorter name for tab bars where horizontal space is limited
    var tabLabel: String {
        switch self {
        case .claude: return "Claude"
        case .copilot: return "Copilot"
        case .cursor: return "Cursor"
        case .codex: return "OpenAI"
        case .gemini: return "Google AI"
        case .stableDiffusion: return "Stability"
        case .midjourney: return "Midjourney"
        case .runway: return "Runway"
        case .elevenlabs: return "ElevenLabs"
        case .suno: return "Suno"
        case .udio: return "Udio"
        }
    }

    /// Single-letter label for menu bar and tab icons
    var shortLabel: String {
        switch self {
        case .claude: return "C"
        case .copilot: return "P"
        case .cursor: return "U"
        case .codex: return "X"
        case .gemini: return "G"
        case .stableDiffusion: return "S"
        case .midjourney: return "M"
        case .runway: return "R"
        case .elevenlabs: return "E"
        case .suno: return "N"
        case .udio: return "D"
        }
    }

    /// Terminal command to authenticate (CLI-based providers only)
    var loginCommand: String {
        switch self {
        case .claude: return "claude"
        case .copilot: return "gh auth login"
        case .cursor: return "open -a Cursor"
        case .codex: return "codex login"
        case .gemini: return "gemini login"
        // API-key providers have no CLI auth
        case .stableDiffusion, .midjourney, .runway, .elevenlabs, .suno, .udio: return ""
        }
    }

    #if os(macOS)
    /// Opens Terminal and runs the login/auth command, reusing the frontmost window if possible
    func openLoginInTerminal() {
        guard !loginCommand.isEmpty else { return }

        let shellSetup = """
        [ -f "$HOME/.zprofile" ] && source "$HOME/.zprofile"; \
        [ -f "$HOME/.zshrc" ] && source "$HOME/.zshrc"; \
        export PATH="$HOME/.claude/bin:$HOME/.local/bin:/usr/local/bin:/opt/homebrew/bin:$PATH"
        """
        let fullCommand = "\(shellSetup); echo 'Signing in to \(displayName)...'; echo ''; \(loginCommand)"

        // Use AppleScript to reuse existing Terminal window instead of opening a new one
        let appleScript = """
        tell application "Terminal"
            if (count of windows) > 0 then
                do script "\(fullCommand.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))" in front window
            else
                do script "\(fullCommand.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))"
            end if
            activate
        end tell
        """

        if let script = NSAppleScript(source: appleScript) {
            var error: NSDictionary?
            script.executeAndReturnError(&error)
            if error != nil {
                // Fallback: open .command file (new window)
                openCommandFile(command: fullCommand)
            }
        } else {
            openCommandFile(command: fullCommand)
        }
    }

    private func openCommandFile(command: String) {
        let script = "#!/bin/zsh\n\(command)"
        let scriptFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("tokenomics-\(rawValue)-login.command")
        do {
            try script.write(to: scriptFile, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: scriptFile.path
            )
            // Remove quarantine so macOS doesn't flag the script as "damaged"
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
            process.arguments = ["-d", "com.apple.quarantine", scriptFile.path]
            try? process.run()
            process.waitUntilExit()
            NSWorkspace.shared.open(scriptFile)
        } catch {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(loginCommand, forType: .string)
        }
    }
    #endif

    /// Whether this provider exposes rate-limit / usage data
    var supportsUsageTracking: Bool {
        switch self {
        case .claude, .copilot, .cursor, .codex, .gemini: return true
        case .elevenlabs, .runway, .stableDiffusion: return true
        // When flipping any of these to `true`, update docs/PRIVACY.md —
        // the placeholder note currently tells users Tokenomics makes no
        // network calls or credential reads for these three.
        case .midjourney, .suno, .udio: return false
        }
    }

    /// Whether this provider uses a Personal Access Token instead of CLI-based auth
    var usesPATAuth: Bool {
        // All providers now have zero-friction auth or API key auth
        return false
    }

    /// Whether auth is handled automatically by the provider's own app (no CLI/PAT needed)
    var hasAutoAuth: Bool {
        switch self {
        case .cursor: return true
        default: return false
        }
    }

    /// Install command for CLI-based providers
    var installCommand: String {
        switch self {
        case .claude: return "npm install -g @anthropic-ai/claude-code"
        case .copilot: return "brew install gh"
        case .cursor: return "brew install --cask cursor"
        case .codex: return "npm install -g @openai/codex"
        case .gemini: return "npm install -g @google/gemini-cli"
        // API-key providers don't need installation
        case .stableDiffusion, .midjourney, .runway, .elevenlabs, .suno, .udio: return ""
        }
    }

    /// Whether this provider's install uses npm (vs. brew/cask)
    private var installUsesNpm: Bool {
        switch self {
        case .claude, .codex, .gemini: return true
        default: return false
        }
    }

    /// Direct download URL shown when neither brew nor npm is available.
    /// Cursor can always be downloaded directly; Node is the prerequisite for
    /// npm-based providers; `gh` has its own macOS pkg.
    private var manualDownloadURL: String {
        switch self {
        case .cursor: return "https://www.cursor.com/downloads"
        case .copilot: return "https://github.com/cli/cli/releases/latest"
        case .claude, .codex, .gemini: return "https://nodejs.org/en/download"
        default: return ""
        }
    }

    #if os(macOS)
    /// Opens Terminal and runs the install command, reusing the frontmost window if possible.
    /// Auto-installs Homebrew (for cask providers) or Node.js via the official pkg installer
    /// (for npm providers) when neither tool is present — so the user isn't dead-ended by a
    /// cryptic "brew not found" error.
    func openInstallInTerminal() {
        guard !installCommand.isEmpty else { return }

        let shellSetup = """
        [ -f "$HOME/.zprofile" ] && source "$HOME/.zprofile"; \
        [ -f "$HOME/.zshrc" ] && source "$HOME/.zshrc"; \
        export PATH="$HOME/.claude/bin:$HOME/.local/bin:/usr/local/bin:/opt/homebrew/bin:$PATH"
        """

        let installScript: String
        if installUsesNpm {
            // npm providers: try npm, fall back to brew-installed node, fall back to
            // the official Node.js pkg installer so users without brew aren't stuck.
            installScript = """
            if command -v npm >/dev/null 2>&1; then \
            echo 'Installing \(displayName)...'; echo ''; \(installCommand); \
            elif command -v brew >/dev/null 2>&1; then \
            echo 'npm not found — installing Node.js via Homebrew first...'; \
            brew install node && \(installCommand); \
            else \
            echo 'Node.js is required to install \(displayName).'; \
            echo 'Opening the official Node.js installer page — download and run it,'; \
            echo 'then return to Tokenomics and click Install again.'; \
            open '\(manualDownloadURL)'; \
            fi
            """
        } else {
            // brew/cask providers: offer a one-command Homebrew install, then fall
            // back to the provider's native installer if the user declines.
            installScript = """
            if command -v brew >/dev/null 2>&1; then \
            echo 'Installing \(displayName)...'; echo ''; \(installCommand); \
            else \
            echo 'Homebrew is not installed.'; \
            echo ''; \
            echo 'Option 1 — install Homebrew (recommended, one command):'; \
            echo '  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'; \
            echo ''; \
            echo 'Option 2 — download \(displayName) directly:'; \
            echo '  \(manualDownloadURL)'; \
            open '\(manualDownloadURL)'; \
            fi
            """
        }

        let fullCommand = "\(shellSetup); \(installScript)"

        let appleScript = """
        tell application "Terminal"
            if (count of windows) > 0 then
                do script "\(fullCommand.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))" in front window
            else
                do script "\(fullCommand.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))"
            end if
            activate
        end tell
        """

        if let script = NSAppleScript(source: appleScript) {
            var error: NSDictionary?
            script.executeAndReturnError(&error)
            if error != nil {
                openCommandFile(command: fullCommand)
            }
        } else {
            openCommandFile(command: fullCommand)
        }
    }
    #endif
}

// MARK: - Provider Categories

extension ProviderId {

    /// Groups providers into sections for the Connections page
    enum ProviderCategory: String, CaseIterable {
        case platforms       = "PLATFORMS"
        case codingTools     = "CODING TOOLS"
        case imageGeneration = "IMAGE GENERATION"
        case videoGeneration = "VIDEO GENERATION"
        case musicAudioVoice = "MUSIC / AUDIO / VOICE"
    }

    var category: ProviderCategory {
        switch self {
        case .claude, .codex, .gemini, .stableDiffusion: return .platforms
        case .copilot, .cursor: return .codingTools
        case .midjourney: return .imageGeneration
        case .runway: return .videoGeneration
        case .elevenlabs, .suno, .udio: return .musicAudioVoice
        }
    }

    /// Whether this provider has a working API integration (false = "Coming Soon")
    var hasAPI: Bool {
        switch self {
        case .midjourney, .suno, .udio: return false
        default: return true
        }
    }

    /// Subtitle shown under platform providers describing what's in their shared billing pool
    var sharedPoolDescription: String? {
        switch self {
        case .claude: return "Claude Chat · Claude Cowork · Claude Code"
        case .codex: return "ChatGPT · Codex · DALL-E · Sora"
        case .gemini: return "Gemini · Nano Banana · Veo"
        case .stableDiffusion: return "Stable Diffusion · Stable Image · Stable Video"
        default: return nil
        }
    }

    /// Anchor fragment that deep-links to the matching section of trytokenomics.com/setup.html
    var setupGuideAnchor: String {
        switch self {
        case .claude: return "#anthropic"
        case .codex: return "#openai"
        case .gemini: return "#google"
        case .copilot: return "#copilot"
        case .cursor: return "#cursor"
        case .stableDiffusion, .runway, .elevenlabs: return "#api-key"
        case .midjourney, .suno, .udio: return ""
        }
    }

    /// Whether this provider authenticates via an API key stored in Keychain
    var usesAPIKeyAuth: Bool {
        switch self {
        case .elevenlabs, .runway, .stableDiffusion: return true
        default: return false
        }
    }

    /// Base name for icon assets (without the -white/-black/-d.blue suffix).
    /// Maps enum rawValues to actual file names in Provider Icons/.
    var iconBaseName: String {
        switch self {
        case .claude: return "Claude"
        case .codex: return "Codex"
        case .copilot: return "Copilot"
        case .cursor: return "Cursor"
        case .gemini: return "Gemini"
        case .stableDiffusion: return "stability"
        case .midjourney: return "midjourney"
        case .runway: return "runway"
        case .elevenlabs: return "elevenlabs"
        case .suno: return "suno"
        case .udio: return "udio"
        }
    }
}

// MARK: - Connection State

/// Describes the current state of a provider's connection
enum ProviderConnectionState: Sendable, Equatable {
    case notInstalled
    case installedNoAuth
    case connected(plan: String)
    case authExpired
    case unavailable(reason: String)

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }

    var statusText: String {
        switch self {
        case .notInstalled: return "Not installed"
        case .installedNoAuth: return "Not signed in"
        case .connected(let plan): return "\(plan) — Connected"
        case .authExpired: return "Auth expired"
        case .unavailable(let reason): return reason
        }
    }
}

// MARK: - Usage Snapshot

/// Provider-agnostic usage data that the UI renders
struct ProviderUsageSnapshot: Codable, Sendable {
    let shortWindow: WindowUsage
    /// Nil for providers that only expose a single usage metric (e.g. Copilot premium requests).
    let longWindow: WindowUsage?
    let planLabel: String
    let extraUsage: ExtraUsage?
    let creditsBalance: String?
}

/// A single usage window (e.g. 5-hour or 7-day)
struct WindowUsage: Codable, Sendable {
    let label: String
    let utilization: Double
    let resetsAt: Date
    let windowDuration: TimeInterval
    let sublabelOverride: String?

    init(label: String, utilization: Double, resetsAt: Date, windowDuration: TimeInterval, sublabelOverride: String? = nil) {
        self.label = label
        self.utilization = utilization
        self.resetsAt = resetsAt
        self.windowDuration = windowDuration
        self.sublabelOverride = sublabelOverride
    }

    /// Pace: how far through the window we are (0–1).
    /// Returns 0 for non-time-based windows (e.g. context window) where pace is meaningless.
    var pace: Double {
        guard windowDuration > 0 else { return 0 }
        let remaining = max(resetsAt.timeIntervalSinceNow, 0)
        let elapsed = windowDuration - min(remaining, windowDuration)
        return min(max(elapsed / windowDuration, 0), 1)
    }

    /// Formatted time remaining until reset
    var timeUntilReset: String {
        if let override = sublabelOverride { return override }

        let interval = resetsAt.timeIntervalSinceNow
        guard interval > 0 else { return "Resetting now" }

        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60

        if hours >= 24 {
            let calendar = Calendar.current
            if calendar.isDateInToday(resetsAt) {
                return "Resets today"
            } else if calendar.isDateInTomorrow(resetsAt) {
                return "Resets tomorrow"
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "EEEE"
                return "Resets \(formatter.string(from: resetsAt))"
            }
        } else if hours > 0 {
            return "Resets in \(hours)h \(minutes)m"
        } else {
            return "Resets in \(minutes)m"
        }
    }
}

// MARK: - Per-Provider State (Published by ViewModel)

/// Everything the UI needs to render one provider's panel
struct ProviderState: Sendable {
    let connection: ProviderConnectionState
    let usage: ProviderUsageSnapshot?
    let error: AppError?
    let lastSynced: Date?
    let isLoading: Bool

    static let empty = ProviderState(
        connection: .notInstalled,
        usage: nil,
        error: nil,
        lastSynced: nil,
        isLoading: false
    )
}

// MARK: - Provider Protocol

/// Abstraction for any AI coding tool usage provider
protocol UsageProvider: Actor {
    var id: ProviderId { get }

    /// How often this provider should be polled (seconds).
    /// Local providers can use short intervals; remote APIs should use longer ones.
    var pollInterval: TimeInterval { get }

    /// Check whether the CLI is installed and authenticated
    func checkConnection() async -> ProviderConnectionState

    /// Fetch the latest usage data. Throws on failure.
    func fetchUsage() async throws -> ProviderUsageSnapshot
}
