import Foundation
import Security
import os

/// Reads the OAuth credentials stored by Claude Code, preferring the credentials
/// file (~/.claude/.credentials.json) over the macOS Keychain to avoid
/// repeated keychain access prompts during development.
enum KeychainService {
    private static let serviceName = "Claude Code-credentials"
    private static let log = Logger(subsystem: "com.robstout.tokenomics", category: "KeychainService")

    private static let credentialsFileURL: URL = {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/.credentials.json")
    }()

    /// Full OAuth credentials needed for token refresh
    struct OAuthCredentials {
        let accessToken: String
        let refreshToken: String?
        let expiresAt: Date?
    }

    static func readAccessToken() -> String? {
        readCredentials()?.accessToken
    }

    /// Read full OAuth credentials (token + refresh token + expiry).
    /// Prefers file → security CLI → Security framework (last resort, may prompt).
    static func readCredentials() -> OAuthCredentials? {
        if let creds = readCredentialsFromFile() { return creds }
        if let creds = readCredentialsViaCLI() { return creds }
        return readCredentialsFromKeychain()
    }

    // MARK: - Permission probe (used by onboarding)

    /// Result of a one-shot permission probe used by `PermissionsStep`.
    enum AccessProbeResult: Sendable {
        /// Read worked, OR there's no keychain item to ask about (user hasn't
        /// run Claude Code on this machine yet). Either way, onboarding can
        /// safely advance — there's nothing the user has refused.
        case ok
        /// A keychain item exists but the data read was rejected — typically
        /// the user clicked "Don't Allow" on the macOS keychain or cross-app
        /// TCC prompt. Onboarding should pause and ask them to retry.
        case denied
    }

    /// Probes whether Tokenomics is allowed to read the Claude Code OAuth
    /// keychain item. Used by `PermissionsStep` to detect denial and surface
    /// a hard-stop error instead of silently sailing forward.
    ///
    /// Implementation: attempts the actual data read first (which is what
    /// triggers the macOS prompt(s) at a known UI moment). If that fails, a
    /// metadata-only lookup distinguishes "no item exists" from "item exists
    /// but access denied" — the latter is the only case we treat as denial.
    static func probeAccess() -> AccessProbeResult {
        // Trivially OK if the file path returned creds (no prompt fired).
        if readCredentialsFromFile() != nil { return .ok }

        // Data read — this is the prompt-triggering call.
        let dataExit = runSecurityCLI(args: ["find-generic-password", "-s", serviceName, "-w"])
        if dataExit == 0 { return .ok }

        // Distinguish missing item from denied access. Metadata-only lookup
        // (no -w) doesn't request the password content, so it doesn't trip
        // the keychain ACL prompt. If it succeeds, the item exists and the
        // earlier -w failure means the user denied access.
        let metaExit = runSecurityCLI(args: ["find-generic-password", "-s", serviceName])
        return metaExit == 0 ? .denied : .ok
    }

    /// Runs `/usr/bin/security` with the given args, discarding stdout/stderr,
    /// and returns the process exit status. -1 if the process couldn't launch.
    private static func runSecurityCLI(args: [String]) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = args
        process.standardOutput = Pipe()
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return -1
        }
        return process.terminationStatus
    }

    // MARK: - Credentials File

    private static func readCredentialsFromFile() -> OAuthCredentials? {
        guard let data = try? Data(contentsOf: credentialsFileURL) else { return nil }

        // Claude Code 2.1.x stopped writing `claudeAiOauth` to this file (it now
        // lives in the keychain only — the file holds `mcpOAuth` instead). Missing
        // key is expected on current Claude Code; fall through silently to the
        // keychain CLI path. Only log when the file is actually malformed JSON.
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            log.info("credentials file is not valid JSON — falling back to keychain")
            return nil
        }
        guard let oauth = json["claudeAiOauth"] as? [String: Any],
              let token = oauth["accessToken"] as? String,
              token.hasPrefix("sk-ant-") else {
            return nil
        }
        let refreshToken = oauth["refreshToken"] as? String
        let expiresAt: Date? = {
            guard let ms = oauth["expiresAt"] as? Double else { return nil }
            return Date(timeIntervalSince1970: ms / 1000)
        }()
        return OAuthCredentials(accessToken: token, refreshToken: refreshToken, expiresAt: expiresAt)
    }

    // MARK: - Security CLI (avoids keychain prompt)

    /// Reads credentials via /usr/bin/security, which is permanently trusted in the
    /// keychain ACL. This avoids the password prompt that occurs when Tokenomics's own
    /// binary signature changes between builds or when Claude Code rewrites the item.
    private static func readCredentialsViaCLI() -> OAuthCredentials? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["find-generic-password", "-s", serviceName, "-w"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            log.info("security CLI failed to launch: \(error.localizedDescription)")
            return nil
        }

        guard process.terminationStatus == 0 else {
            log.info("security CLI exited with status \(process.terminationStatus)")
            return nil
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let raw = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else {
            return nil
        }

        // The password value is JSON — parse it the same way as the keychain path
        guard let jsonData = raw.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let oauth = json["claudeAiOauth"] as? [String: Any],
              let token = oauth["accessToken"] as? String,
              token.hasPrefix("sk-ant-") else {
            return nil
        }

        let refreshToken = oauth["refreshToken"] as? String
        let expiresAt: Date? = {
            guard let ms = oauth["expiresAt"] as? Double else { return nil }
            return Date(timeIntervalSince1970: ms / 1000)
        }()
        return OAuthCredentials(accessToken: token, refreshToken: refreshToken, expiresAt: expiresAt)
    }

    // MARK: - Keychain (last resort, may prompt)

    private static func readCredentialsFromKeychain() -> OAuthCredentials? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let raw = String(data: data, encoding: .utf8) else {
            return nil
        }

        // Parse as JSON for full credential access
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let oauth = json["claudeAiOauth"] as? [String: Any],
           let token = oauth["accessToken"] as? String,
           token.hasPrefix("sk-ant-") {
            let refreshToken = oauth["refreshToken"] as? String
            let expiresAt: Date? = {
                guard let ms = oauth["expiresAt"] as? Double else { return nil }
                return Date(timeIntervalSince1970: ms / 1000)
            }()
            return OAuthCredentials(accessToken: token, refreshToken: refreshToken, expiresAt: expiresAt)
        }

        // Legacy string-parsing fallback
        guard let startRange = raw.range(of: "\"accessToken\":\"") else {
            return nil
        }
        let tokenStart = startRange.upperBound
        guard let endQuote = raw[tokenStart...].firstIndex(of: "\"") else {
            return nil
        }
        let token = String(raw[tokenStart..<endQuote])
        guard token.hasPrefix("sk-ant-") else { return nil }
        return OAuthCredentials(accessToken: token, refreshToken: nil, expiresAt: nil)
    }
}
