import XCTest
@testable import Tokenomics

// MARK: - Helpers

private func makeDate(_ isoString: String) -> Date {
    let formatter = ISO8601DateFormatter()
    return formatter.date(from: isoString)!
}

private func makeSnapshot(provider: String, capturedAt: Date) -> BridgeSnapshot {
    BridgeSnapshot(
        provider: provider,
        capturedAt: capturedAt,
        estimated: false,
        shortWindow: BridgeWindow(
            label: "5h",
            utilization: 0.5,
            resetsAt: capturedAt.addingTimeInterval(3600),
            windowDurationSec: 18000,
            sublabelOverride: nil
        ),
        longWindow: nil,
        planLabel: "Pro"
    )
}

private func makeRequest(
    snapshots: [BridgeSnapshot] = [],
    settings: BridgeSettings? = nil,
    schemaVersion: Int = 1
) -> BridgeRequest {
    BridgeRequest(
        schemaVersion: schemaVersion,
        envelopeSentAt: Date(),
        extensionId: "test-ext",
        snapshots: snapshots,
        settings: settings,
        requestedActions: nil
    )
}

private func makeExtState(
    snapshots: [String: BridgeSnapshot] = [:],
    visibility: [String: ProviderVisibilitySetting] = [:],
    updatedAt: Date = Date()
) -> ExtSideState {
    ExtSideState(updatedAt: updatedAt, snapshots: snapshots, providerVisibility: visibility)
}

private func makeMacState(
    nativeSnapshots: [String: BridgeSnapshot] = [:],
    visibility: [String: ProviderVisibilitySetting] = [:],
    commands: [BridgeCommand] = [],
    version: String = "2.9.0"
) -> MacSideState {
    MacSideState(
        updatedAt: Date(),
        macAppVersion: version,
        nativeSnapshots: nativeSnapshots,
        providerVisibility: visibility,
        pendingCommands: commands
    )
}

// MARK: - BridgeCoreTests

final class BridgeCoreTests: XCTestCase {

    // MARK: NMH Framing

    /// Test 1: framing round-trip — encode then decode returns the original payload.
    func testFramingRoundTrip() throws {
        let original = Data(#"{"ok":true}"#.utf8)
        let frame = BridgeFraming.encode(jsonData: original)
        let decoded = try BridgeFraming.decode(from: frame)
        XCTAssertEqual(decoded, original)
    }

    /// Test 2: declared length > 64 KB is rejected before reading the body.
    func testFramingRejectsOversizedMessage() {
        // Craft a 4-byte header that declares 70 KB (70 * 1024 = 71680).
        let oversized: UInt32 = 71_680
        var little = oversized.littleEndian
        let header = Data(bytes: &little, count: 4)

        XCTAssertThrowsError(try BridgeFraming.parseLength(from: header)) { error in
            guard case BridgeFraming.FramingError.messageTooLarge(let declared, _) = error else {
                return XCTFail("expected messageTooLarge, got \(error)")
            }
            XCTAssertEqual(declared, 71_680)
        }
    }

    /// Test 3: decode on a buffer with fewer than 4 bytes reports EOF cleanly.
    func testFramingHandlesEmptyBuffer() {
        XCTAssertThrowsError(try BridgeFraming.decode(from: Data())) { error in
            guard case BridgeFraming.FramingError.unexpectedEOF = error else {
                return XCTFail("expected unexpectedEOF, got \(error)")
            }
        }
    }

    // MARK: BridgeMerger — snapshot merging

    /// Test 4: incoming snapshot with later capturedAt replaces existing.
    func testMergerSnapshotIncomingNewerWins() {
        let t0 = makeDate("2026-05-14T10:00:00Z")
        let t1 = makeDate("2026-05-14T11:00:00Z")

        let existing = makeExtState(snapshots: ["midjourney": makeSnapshot(provider: "midjourney", capturedAt: t0)])
        let request = makeRequest(snapshots: [makeSnapshot(provider: "midjourney", capturedAt: t1)])

        let merged = BridgeMerger.merge(existing: existing, request: request)
        XCTAssertEqual(merged.snapshots["midjourney"]?.capturedAt, t1)
    }

    /// Test 5: existing snapshot with later capturedAt is preserved when incoming is older.
    func testMergerSnapshotExistingNewerWins() {
        let t0 = makeDate("2026-05-14T10:00:00Z")
        let t1 = makeDate("2026-05-14T11:00:00Z")

        let existing = makeExtState(snapshots: ["midjourney": makeSnapshot(provider: "midjourney", capturedAt: t1)])
        let request = makeRequest(snapshots: [makeSnapshot(provider: "midjourney", capturedAt: t0)])

        let merged = BridgeMerger.merge(existing: existing, request: request)
        XCTAssertEqual(merged.snapshots["midjourney"]?.capturedAt, t1)
    }

    // MARK: BridgeMerger — settings merging

    /// Test 6a: incoming visibility setting with later lastChangedAt wins.
    func testMergerSettingsIncomingNewerWins() {
        let t0 = makeDate("2026-05-14T09:00:00Z")
        let t1 = makeDate("2026-05-14T10:00:00Z")

        let existing = makeExtState(visibility: ["claude": ProviderVisibilitySetting(enabled: true, lastChangedAt: t0)])
        let incomingSettings = BridgeSettings(providerVisibility: [
            "claude": ProviderVisibilitySetting(enabled: false, lastChangedAt: t1)
        ])
        let request = makeRequest(settings: incomingSettings)

        let merged = BridgeMerger.merge(existing: existing, request: request)
        XCTAssertEqual(merged.providerVisibility["claude"]?.enabled, false)
        XCTAssertEqual(merged.providerVisibility["claude"]?.lastChangedAt, t1)
    }

    /// Test 6b: existing visibility setting with later lastChangedAt is preserved.
    func testMergerSettingsExistingNewerWins() {
        let t0 = makeDate("2026-05-14T09:00:00Z")
        let t1 = makeDate("2026-05-14T10:00:00Z")

        let existing = makeExtState(visibility: ["claude": ProviderVisibilitySetting(enabled: false, lastChangedAt: t1)])
        let incomingSettings = BridgeSettings(providerVisibility: [
            "claude": ProviderVisibilitySetting(enabled: true, lastChangedAt: t0)
        ])
        let request = makeRequest(settings: incomingSettings)

        let merged = BridgeMerger.merge(existing: existing, request: request)
        XCTAssertEqual(merged.providerVisibility["claude"]?.enabled, false)
    }

    /// Test 7: merge with nil existing state (missing ext-side.json) starts from empty.
    func testMergerHandlesMissingExistingFile() {
        let t0 = makeDate("2026-05-14T12:00:00Z")
        let request = makeRequest(snapshots: [makeSnapshot(provider: "codex", capturedAt: t0)])

        let merged = BridgeMerger.merge(existing: nil, request: request)
        XCTAssertEqual(merged.snapshots.count, 1)
        XCTAssertNotNil(merged.snapshots["codex"])
    }

    /// Test 8: providers not mentioned in the request are preserved unchanged.
    func testMergerPreservesUnrelatedProviders() {
        let t0 = makeDate("2026-05-14T12:00:00Z")
        let t1 = makeDate("2026-05-14T13:00:00Z")

        let existing = makeExtState(snapshots: [
            "claude": makeSnapshot(provider: "claude", capturedAt: t0),
            "midjourney": makeSnapshot(provider: "midjourney", capturedAt: t0)
        ])
        // Incoming touches only "claude".
        let request = makeRequest(snapshots: [makeSnapshot(provider: "claude", capturedAt: t1)])

        let merged = BridgeMerger.merge(existing: existing, request: request)
        XCTAssertNotNil(merged.snapshots["midjourney"], "unrelated provider should be preserved")
        XCTAssertEqual(merged.snapshots["claude"]?.capturedAt, t1)
    }

    // MARK: BridgeResponseComposer

    /// Test 9: composer pulls nativeSnapshots and pendingCommands from MacSideState.
    func testComposerPullsMacSideData() {
        let t0 = makeDate("2026-05-14T15:00:00Z")
        let macSide = makeMacState(
            nativeSnapshots: ["codex": makeSnapshot(provider: "codex", capturedAt: t0)],
            commands: [BridgeCommand(kind: "refreshWebProviders")]
        )
        let request = makeRequest()
        let response = BridgeResponseComposer.compose(macSide: macSide, request: request, macAppVersion: "2.9.0")

        XCTAssertTrue(response.ok)
        XCTAssertEqual(response.nativeSnapshots.count, 1)
        XCTAssertEqual(response.nativeSnapshots.first?.provider, "codex")
        XCTAssertEqual(response.commands.count, 1)
        XCTAssertEqual(response.commands.first?.kind, "refreshWebProviders")
        XCTAssertEqual(response.macAppVersion, "2.9.0")
    }

    /// Test 10: composer with nil mac-side returns empty nativeSnapshots and commands.
    func testComposerHandlesMissingMacSide() {
        let request = makeRequest()
        let response = BridgeResponseComposer.compose(macSide: nil, request: request, macAppVersion: "unknown")

        XCTAssertTrue(response.ok)
        XCTAssertTrue(response.nativeSnapshots.isEmpty)
        XCTAssertTrue(response.commands.isEmpty)
        XCTAssertNil(response.settings)
    }
}
