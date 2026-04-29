import Foundation
import os

// MARK: - Events

/// Progress events streamed while `npm install -g` is running.
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

/// Events streamed while a CLI is running (e.g. `codex login`).
enum RunEvent: Sendable {
    case stdout(String)
    case stderr(String)
    /// The runner spotted a device-code login URL in stdout.
    /// `code` is nil when the CLI shows a URL but no separate code string.
    case deviceCode(url: URL, code: String?)
    /// The process exited with the given status code.
    case exited(Int32)
}

/// Handle returned by `runCLI` — the event stream plus a thread-safe closure
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

// MARK: - Errors

enum EmbeddedCLIError: Error, LocalizedError {
    case nodeNotAvailable
    case binaryNotFound(URL)
    case processFailed(exitCode: Int32, stderr: String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .nodeNotAvailable:
            return "Embedded Node.js is not available. This is a build issue — please reinstall Tokenomics."
        case .binaryNotFound(let url):
            return "CLI binary not found at \(url.path)."
        case .processFailed(let code, let stderr):
            return "Process exited with code \(code). \(stderr)"
        case .cancelled:
            return "Operation cancelled."
        }
    }
}

// MARK: - EmbeddedCLIRunner

/// Actor wrapping `Process` for running CLI tools as hidden subprocesses.
///
/// All output is captured via pipes — no Terminal window is ever shown.
/// stdout/stderr are streamed back to the caller as typed events.
///
/// Environment isolation: npm installs land in a Tokenomics-private prefix
/// (`~/Library/Application Support/Tokenomics/embedded/`) rather than the
/// user's global npm prefix. This avoids polluting the user's environment.
///
/// Cancellation: keep the `Process` reference inside the actor and call
/// `process.terminate()` when cancelled — the process.waitUntilExit() call
/// on the monitoring task will then return cleanly.
actor EmbeddedCLIRunner {

    private static let log = Logger(subsystem: "com.robstout.tokenomics", category: "EmbeddedCLIRunner")

    // MARK: - Isolated npm prefix

    /// Where Tokenomics-managed npm installs land.
    /// Using Application Support (not /usr/local) so we don't need elevated permissions.
    private static var tokenomicsNpmPrefix: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("Tokenomics/embedded")
    }

    /// Where CLI binaries end up after `npm install -g` with our custom prefix.
    static var embeddedBinDir: URL {
        tokenomicsNpmPrefix.appendingPathComponent("bin")
    }

    // MARK: - In-flight process tracking

    /// The currently-running process, if any. Stored so `cancel()` can terminate it.
    private var runningProcess: Process?

    // MARK: - npm install

    /// Installs an npm package globally using the bundled Node.js runtime.
    ///
    /// Events are emitted on the calling task's continuation — the caller must
    /// consume or buffer them. Progress is indeterminate (npm doesn't expose
    /// a machine-readable progress stream in all versions).
    ///
    /// - Parameter npmPackage: The npm package name, e.g. `"@openai/codex"`.
    /// - Returns: An `AsyncStream<InstallEvent>` that terminates with
    ///   `.completed` or `.failed(reason)`.
    func install(npmPackage: String) async throws -> AsyncStream<InstallEvent> {
        guard EmbeddedNode.isAvailable() else {
            throw EmbeddedCLIError.nodeNotAvailable
        }

        // Ensure the prefix directory exists before npm tries to write to it.
        try createNpmPrefixIfNeeded()

        return AsyncStream<InstallEvent> { [weak self] continuation in
            guard let self else {
                continuation.finish()
                return
            }

            Task {
                do {
                    try await self.runInstall(
                        npmPackage: npmPackage,
                        continuation: continuation
                    )
                } catch {
                    let msg = error.localizedDescription
                    continuation.yield(.failed(msg))
                    continuation.finish()
                }
            }
        }
    }

    private func runInstall(
        npmPackage: String,
        continuation: AsyncStream<InstallEvent>.Continuation
    ) async throws {
        let process = Process()
        self.runningProcess = process

        // Use bundled Node to run the bundled npm.
        process.executableURL = EmbeddedNode.nodePath
        process.arguments = [
            EmbeddedNode.npmPath.path,
            "install",
            "--global",
            "--no-fund",
            "--no-audit",
            npmPackage
        ]
        process.environment = buildEnvironment()

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardInput = Pipe()    // stdin closed — process never prompts
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        continuation.yield(.progress(nil))   // indeterminate until complete

        try process.run()

        Self.log.info("[EmbeddedCLIRunner] npm install \(npmPackage) started (pid=\(process.processIdentifier))")

        // Read stderr in a separate Task so we don't deadlock when the pipe fills.
        var stderrLines: [String] = []
        let stderrTask = Task {
            let data = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            if let text = String(data: data, encoding: .utf8) {
                stderrLines = text.components(separatedBy: .newlines).filter { !$0.isEmpty }
                for line in stderrLines {
                    continuation.yield(.log("[npm stderr] \(line)"))
                }
            }
        }

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        if let text = String(data: stdoutData, encoding: .utf8) {
            for line in text.components(separatedBy: .newlines) where !line.isEmpty {
                continuation.yield(.log(line))
            }
        }

        process.waitUntilExit()
        _ = await stderrTask.result

        self.runningProcess = nil

        let exitCode = process.terminationStatus
        if exitCode == 0 {
            Self.log.info("[EmbeddedCLIRunner] npm install \(npmPackage) succeeded")
            continuation.yield(.completed)
        } else {
            let lastStderr = stderrLines.last ?? "npm exited with code \(exitCode)"
            Self.log.error("[EmbeddedCLIRunner] npm install \(npmPackage) failed (exit=\(exitCode)): \(lastStderr)")
            continuation.yield(.failed(lastStderr))
        }
        continuation.finish()
    }

    // MARK: - Run a CLI binary

    /// Runs a CLI binary and streams its output.
    ///
    /// Parses stdout/stderr for device-code login URLs (the pattern many OAuth
    /// CLIs print when they can't open a browser automatically). When found,
    /// emits a `.deviceCode(url:code:)` event so the connector can surface
    /// a native sign-in button instead of hoping the user reads the terminal.
    ///
    /// - Parameters:
    ///   - binary: Full path to the CLI executable.
    ///   - args: Arguments to pass (e.g. `["login"]`).
    /// - Returns: A `RunCLIHandle` exposing the event stream and a stdin writer.
    func runCLI(binary: URL, args: [String]) async throws -> RunCLIHandle {
        guard FileManager.default.isExecutableFile(atPath: binary.path) else {
            throw EmbeddedCLIError.binaryNotFound(binary)
        }

        // Create the stdin pipe up-front so the writer closure can capture its
        // write handle. FileHandle.write is thread-safe, so the closure is safe
        // to call from any actor context (or never call at all).
        let stdinPipe = Pipe()
        let stdinHandle = stdinPipe.fileHandleForWriting

        let stream = AsyncStream<RunEvent> { [weak self] continuation in
            guard let self else {
                continuation.finish()
                return
            }

            Task {
                do {
                    try await self.runProcess(
                        binary: binary,
                        args: args,
                        stdinPipe: stdinPipe,
                        continuation: continuation
                    )
                } catch {
                    continuation.yield(.stderr(error.localizedDescription))
                    continuation.yield(.exited(-1))
                    continuation.finish()
                }
            }
        }

        return RunCLIHandle(
            events: stream,
            writeStdin: { input in
                guard let data = input.data(using: .utf8) else { return }
                // try? swallows "broken pipe" if the subprocess exited before
                // we got here — that's a benign race, not a failure.
                try? stdinHandle.write(contentsOf: data)
            }
        )
    }

    private func runProcess(
        binary: URL,
        args: [String],
        stdinPipe: Pipe,
        continuation: AsyncStream<RunEvent>.Continuation
    ) async throws {
        let process = Process()
        self.runningProcess = process

        process.executableURL = binary
        process.arguments = args
        process.environment = buildEnvironment()
        process.standardInput = stdinPipe

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        Self.log.info("[EmbeddedCLIRunner] \(binary.lastPathComponent) \(args.joined(separator: " ")) (pid=\(process.processIdentifier))")

        // Stream stdout line-by-line, watching for device-code URLs.
        let stdoutTask = Task {
            await self.streamLines(from: stdoutPipe.fileHandleForReading) { line in
                continuation.yield(.stdout(line))
                // Check every stdout line for a device-code URL
                if let event = Self.parseDeviceCode(from: line) {
                    continuation.yield(event)
                }
            }
        }

        let stderrTask = Task {
            await self.streamLines(from: stderrPipe.fileHandleForReading) { line in
                continuation.yield(.stderr(line))
                // Some CLIs print the URL to stderr
                if let event = Self.parseDeviceCode(from: line) {
                    continuation.yield(event)
                }
            }
        }

        process.waitUntilExit()
        _ = await stdoutTask.result
        _ = await stderrTask.result

        self.runningProcess = nil

        let exitCode = process.terminationStatus
        Self.log.info("[EmbeddedCLIRunner] \(binary.lastPathComponent) exited with code \(exitCode)")
        continuation.yield(.exited(exitCode))
        continuation.finish()
    }

    // MARK: - Cancel

    /// Terminates the running process, if any. Safe to call multiple times.
    func cancel() {
        guard let process = runningProcess, process.isRunning else { return }
        Self.log.info("[EmbeddedCLIRunner] Cancelling process \(process.processIdentifier)")
        process.terminate()
        runningProcess = nil
    }

    // MARK: - Environment helpers

    /// Builds the minimal environment for the subprocess.
    ///
    /// Key variables:
    /// - PATH: puts Node's own bin directory first so npm can find `node`.
    /// - npm_config_prefix: redirects `npm install -g` output to our private
    ///   directory so we never touch /usr/local or the user's global prefix.
    /// - HOME: inherit from parent so CLIs can write their auth files to the
    ///   correct user home (e.g. ~/.codex/auth.json).
    private func buildEnvironment() -> [String: String] {
        let nodeDir = EmbeddedNode.nodePath.deletingLastPathComponent().path
        let currentPath = ProcessInfo.processInfo.environment["PATH"] ?? "/usr/bin:/bin"

        var env: [String: String] = [
            "PATH": "\(nodeDir):\(currentPath)",
            "npm_config_prefix": Self.tokenomicsNpmPrefix.path,
            "npm_config_cache": Self.tokenomicsNpmPrefix.appendingPathComponent(".npm-cache").path,
            "HOME": NSHomeDirectory(),
            "TERM": "dumb",          // disables interactive color/progress output
            "CI": "true",            // some CLIs behave more script-friendly when CI=true
        ]

        // Propagate locale so npm doesn't complain about missing locale.
        if let lang = ProcessInfo.processInfo.environment["LANG"] {
            env["LANG"] = lang
        }

        return env
    }

    // MARK: - Line streaming

    private func streamLines(
        from handle: FileHandle,
        handler: @Sendable (String) -> Void
    ) async {
        // Read available data in chunks, splitting on newlines.
        // We don't use AsyncBytes here because the FileHandle is from a Pipe
        // on macOS 14, and AsyncBytes requires FileDescriptor (available macOS 12+
        // but has edge cases with Pipe). Plain readDataToEndOfFile() is simpler
        // and sufficient since we're not rendering a live terminal.
        let data = handle.readDataToEndOfFile()
        if let text = String(data: data, encoding: .utf8) {
            for line in text.components(separatedBy: .newlines) where !line.isEmpty {
                handler(line)
            }
        }
    }

    // MARK: - Device-code parsing

    /// Scans a single line of CLI output for a device-authorization URL and
    /// an optional code string (e.g. "ABCD-1234").
    ///
    /// Pattern design:
    ///   - URL: any https:// URL containing "device", "oauth", or "auth" in the path.
    ///     This catches patterns like:
    ///       https://openai.com/oauth/device?code=...
    ///       https://accounts.google.com/o/oauth2/device/...
    ///   - Code: adjacent 4–8 uppercase alphanumeric tokens optionally separated
    ///     by a dash, as used by GitHub (ABCD-1234) and some Google flows.
    ///
    /// Returns nil if no URL is found on the line.
    static func parseDeviceCode(from line: String) -> RunEvent? {
        // URL pattern: https:// followed by non-whitespace characters, requiring
        // at least one of our sentinel path segments.
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

        // Try to find a code on the same line. If absent, emit url with nil code —
        // the view renders a browser-only CTA (no code to display).
        var code: String?
        if let codeMatch = codeRegex.firstMatch(in: line, range: range),
           let codeRange = Range(codeMatch.range(at: 1), in: line) {
            code = String(line[codeRange])
        }

        return .deviceCode(url: url, code: code)
    }

    // MARK: - Private helpers

    private func createNpmPrefixIfNeeded() throws {
        let prefix = Self.tokenomicsNpmPrefix
        let fm = FileManager.default
        if !fm.fileExists(atPath: prefix.path) {
            try fm.createDirectory(at: prefix, withIntermediateDirectories: true)
        }
    }
}
