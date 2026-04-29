import Foundation

// MARK: - Install events

/// Progress events streamed while an install command (`npm install`, `brew install`) is running.
enum InstallEvent: Sendable {
    /// Fractional progress 0–1, or nil when indeterminate.
    case progress(Double?)
    /// A line of stdout/stderr text (for debug logging — not shown to users).
    case log(String)
    /// The install completed successfully.
    case completed
    /// The install failed. `reason` is the last stderr line or a generic message.
    case failed(String)
}

// MARK: - Run events

/// Events streamed while a CLI is running (e.g. `codex login`, `gemini`).
enum RunEvent: Sendable {
    case stdout(String)
    case stderr(String)
    /// The runner spotted a device-code login URL in stdout or stderr.
    /// `code` is nil when the CLI shows a URL but no separate code string.
    case deviceCode(url: URL, code: String?)
    /// The process exited with the given status code.
    case exited(Int32)
}

// MARK: - Run handle

/// Handle returned by `runCommand` — the event stream plus a thread-safe closure
/// for writing to the subprocess's stdin at any time after launch. Used by
/// connectors that need to respond to interactive prompts (e.g. gemini's
/// "Do you want to continue? [Y/n]").
struct RunCLIHandle: Sendable {
    let events: AsyncStream<RunEvent>
    /// Writes UTF-8 bytes to the subprocess's stdin. Safe to call from any
    /// isolation context (FileHandle.write is thread-safe). No-op if the
    /// process has already exited.
    let writeStdin: @Sendable (String) -> Void
}

// MARK: - Output parser

/// Stateless parser for CLI output lines. Extracted from the runner so it can
/// be used by both `GuidedInstallRunner` and tests without depending on either
/// runner implementation.
enum CLIOutputParser {

    /// Scans a single line of CLI output for a device-authorization URL and
    /// an optional code string (e.g. "ABCD-1234").
    ///
    /// Pattern design:
    ///   - URL: any https:// URL containing "device", "oauth", "auth", or "login"
    ///     in the path, covering patterns like:
    ///       https://openai.com/oauth/device?code=...
    ///       https://accounts.google.com/o/oauth2/device/...
    ///   - Code: adjacent 4–8 uppercase alphanumeric tokens optionally separated
    ///     by a dash, as used by GitHub (ABCD-1234) and some Google flows.
    ///
    /// Returns nil if no URL is found on the line.
    static func parseDeviceCode(from line: String) -> RunEvent? {
        let urlPattern = #"https://[^\s]*(?:device|oauth|auth|login)[^\s]*"#
        let codePattern = #"\b([A-Z0-9]{4,8}(?:-[A-Z0-9]{4,8})+)\b"#

        guard let urlRegex = try? NSRegularExpression(pattern: urlPattern, options: .caseInsensitive),
              let codeRegex = try? NSRegularExpression(pattern: codePattern) else {
            return nil
        }

        let range = NSRange(line.startIndex..., in: line)

        guard let urlMatch = urlRegex.firstMatch(in: line, range: range),
              let urlRange = Range(urlMatch.range, in: line),
              let url = URL(string: String(line[urlRange])) else {
            return nil
        }

        var code: String?
        if let codeMatch = codeRegex.firstMatch(in: line, range: range),
           let codeRange = Range(codeMatch.range(at: 1), in: line) {
            code = String(line[codeRange])
        }

        return .deviceCode(url: url, code: code)
    }
}
