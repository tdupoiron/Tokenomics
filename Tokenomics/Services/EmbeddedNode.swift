import Foundation
import os

/// Single source of truth for the Node.js runtime bundled inside the app.
///
/// Why we bundle Node: Codex CLI and Gemini CLI both require Node.js, which is
/// not installed by default on macOS. Rather than dead-ending the user with
/// a "please install Node" prompt, Tokenomics ships its own minimal Node.js
/// arm64 binary extracted during the build (see scripts/fetch-node.sh).
///
/// The binary lives at:
///   Tokenomics.app/Contents/Resources/embedded-node/bin/node
///
/// It is signed with the same Developer ID identity as the app and passes
/// through Apple's notarization as part of the normal distribute.sh flow.
/// Use `scripts/check-embedded-node.sh` after a Release build to verify
/// the signature before submitting to notary.
enum EmbeddedNode {

    private static let log = Logger(subsystem: "com.robstout.tokenomics", category: "EmbeddedNode")

    // MARK: - Path Resolution

    /// Absolute URL to the `node` binary inside the app bundle.
    ///
    /// Returns the URL whether or not the file actually exists — callers should
    /// check `isAvailable()` before using this path.
    static var nodePath: URL {
        bundleResourceURL(filename: "embedded-node/bin/node")
    }

    /// Absolute URL to the `npm` script inside the app bundle.
    static var npmPath: URL {
        bundleResourceURL(filename: "embedded-node/bin/npm")
    }

    /// Absolute URL to the `npx` script inside the app bundle.
    static var npxPath: URL {
        bundleResourceURL(filename: "embedded-node/bin/npx")
    }

    // MARK: - Availability

    /// Returns true if both `node` and `npm` exist inside the bundle and are
    /// marked executable.
    ///
    /// This can return false in two scenarios:
    ///   1. A developer build where `fetch-node.sh` hasn't been run yet.
    ///   2. A notarized build where Apple's notary stripped the binary
    ///      (uncommon but documented — see Phase 2 notarization gate in the plan).
    ///
    /// If this returns false, `EmbeddedCLIRunner` will throw
    /// `EmbeddedCLIError.nodeNotAvailable` rather than crash.
    static func isAvailable() -> Bool {
        let fm = FileManager.default
        let nodeOK = fm.isExecutableFile(atPath: nodePath.path)
        let npmOK = fm.fileExists(atPath: npmPath.path)   // npm is a shell script, not a binary

        if !nodeOK {
            log.warning("Embedded Node binary not found or not executable at: \(nodePath.path)")
        }
        if !npmOK {
            log.warning("Embedded npm script not found at: \(npmPath.path)")
        }

        return nodeOK && npmOK
    }

    // MARK: - Private

    private static func bundleResourceURL(filename: String) -> URL {
        guard let resourcePath = Bundle.main.resourcePath else {
            // Shouldn't happen in a running app, but guard defensively.
            return URL(fileURLWithPath: "/dev/null")
        }
        return URL(fileURLWithPath: resourcePath).appendingPathComponent(filename)
    }
}
