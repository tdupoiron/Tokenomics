import XCTest
@testable import Tokenomics

// MARK: - Bridge Wire Types — Codable Round-Trip Tests

final class BridgeWireTypesTests: XCTestCase {

    // MARK: - ProviderId.chatgpt

    func testChatGPT_rawValue() {
        XCTAssertEqual(ProviderId.chatgpt.rawValue, "chatgpt")
    }

    func testChatGPT_displayName() {
        XCTAssertEqual(ProviderId.chatgpt.displayName, "ChatGPT")
    }

    func testChatGPT_shortLabel() {
        XCTAssertEqual(ProviderId.chatgpt.shortLabel, "ChatGPT")
    }

    func testChatGPT_appearsInAllCases() {
        XCTAssertTrue(ProviderId.allCases.contains(.chatgpt))
    }

    // MARK: - ProviderVisibilitySetting round-trip

    func testProviderVisibilitySetting_roundTrip() throws {
        let original = ProviderVisibilitySetting(
            enabled: true,
            lastChangedAt: Date(timeIntervalSince1970: 1_747_000_000)
        )

        let data = try JSONEncoder.bridge.encode(original)
        let decoded = try JSONDecoder.bridge.decode(ProviderVisibilitySetting.self, from: data)

        XCTAssertEqual(decoded.enabled, original.enabled)
        // ISO 8601 serialization truncates sub-second precision — compare within 1 second
        XCTAssertEqual(
            decoded.lastChangedAt.timeIntervalSince1970,
            original.lastChangedAt.timeIntervalSince1970,
            accuracy: 1.0
        )
    }

    func testProviderVisibilitySetting_disabledState_roundTrip() throws {
        let original = ProviderVisibilitySetting(
            enabled: false,
            lastChangedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let data = try JSONEncoder.bridge.encode(original)
        let decoded = try JSONDecoder.bridge.decode(ProviderVisibilitySetting.self, from: data)

        XCTAssertEqual(decoded, original)
    }

    // MARK: - BridgeRequest round-trip

    func testBridgeRequest_fullPayload_roundTrip() throws {
        let capturedAt = Date(timeIntervalSince1970: 1_747_100_000)
        let resetsAt = Date(timeIntervalSince1970: 1_747_118_000)
        let sentAt = Date(timeIntervalSince1970: 1_747_100_001)
        let changedAt = Date(timeIntervalSince1970: 1_746_000_000)

        let window = BridgeWindow(
            label: "5h",
            utilization: 0.42,
            resetsAt: resetsAt,
            windowDurationSec: 18000,
            sublabelOverride: nil
        )

        let snapshot = BridgeSnapshot(
            provider: "midjourney",
            capturedAt: capturedAt,
            estimated: false,
            shortWindow: window,
            longWindow: nil,
            planLabel: "Pro"
        )

        let visibility: [String: ProviderVisibilitySetting] = [
            "claude": ProviderVisibilitySetting(enabled: true, lastChangedAt: changedAt),
            "chatgpt": ProviderVisibilitySetting(enabled: true, lastChangedAt: changedAt),
        ]

        let original = BridgeRequest(
            schemaVersion: 1,
            envelopeSentAt: sentAt,
            extensionId: "abc123",
            snapshots: [snapshot],
            settings: BridgeSettings(providerVisibility: visibility),
            requestedActions: BridgeRequestedActions(refreshNativeProviders: false)
        )

        let data = try JSONEncoder.bridge.encode(original)
        let decoded = try JSONDecoder.bridge.decode(BridgeRequest.self, from: data)

        XCTAssertEqual(decoded.schemaVersion, original.schemaVersion)
        XCTAssertEqual(decoded.extensionId, original.extensionId)
        XCTAssertEqual(decoded.snapshots.count, 1)
        XCTAssertEqual(decoded.snapshots[0].provider, "midjourney")
        XCTAssertEqual(decoded.snapshots[0].estimated, false)
        XCTAssertEqual(decoded.snapshots[0].shortWindow.utilization, 0.42, accuracy: 0.001)
        XCTAssertEqual(decoded.snapshots[0].planLabel, "Pro")
        XCTAssertNil(decoded.snapshots[0].longWindow)
        XCTAssertEqual(decoded.settings?.providerVisibility["claude"]?.enabled, true)
        XCTAssertEqual(decoded.settings?.providerVisibility["chatgpt"]?.enabled, true)
        XCTAssertEqual(decoded.requestedActions?.refreshNativeProviders, false)
    }

    func testBridgeRequest_optionalFieldsNil_roundTrip() throws {
        let original = BridgeRequest(
            schemaVersion: 1,
            envelopeSentAt: Date(timeIntervalSince1970: 1_747_100_000),
            extensionId: "test-id",
            snapshots: [],
            settings: nil,
            requestedActions: nil
        )

        let data = try JSONEncoder.bridge.encode(original)
        let decoded = try JSONDecoder.bridge.decode(BridgeRequest.self, from: data)

        XCTAssertNil(decoded.settings)
        XCTAssertNil(decoded.requestedActions)
        XCTAssertTrue(decoded.snapshots.isEmpty)
    }

    // MARK: - BridgeResponse round-trip

    func testBridgeResponse_withCommands_roundTrip() throws {
        let ackedAt = Date(timeIntervalSince1970: 1_747_100_010)
        let capturedAt = Date(timeIntervalSince1970: 1_747_099_900)
        let resetsAt = Date(timeIntervalSince1970: 1_747_117_900)

        let nativeWindow = BridgeWindow(
            label: "7d",
            utilization: 0.15,
            resetsAt: resetsAt,
            windowDurationSec: 604800,
            sublabelOverride: "Resets Sunday"
        )

        let nativeSnapshot = BridgeSnapshot(
            provider: "codex",
            capturedAt: capturedAt,
            estimated: nil,
            shortWindow: nativeWindow,
            longWindow: nil,
            planLabel: "GPT-5 Pro"
        )

        let original = BridgeResponse(
            ok: true,
            bridgeSchemaVersion: 1,
            macAppVersion: "2.9.0",
            ackedAt: ackedAt,
            nativeSnapshots: [nativeSnapshot],
            settings: nil,
            commands: [BridgeCommand(kind: "refreshWebProviders")],
            error: nil
        )

        let data = try JSONEncoder.bridge.encode(original)
        let decoded = try JSONDecoder.bridge.decode(BridgeResponse.self, from: data)

        XCTAssertTrue(decoded.ok)
        XCTAssertEqual(decoded.bridgeSchemaVersion, 1)
        XCTAssertEqual(decoded.macAppVersion, "2.9.0")
        XCTAssertEqual(decoded.nativeSnapshots.count, 1)
        XCTAssertEqual(decoded.nativeSnapshots[0].provider, "codex")
        XCTAssertEqual(decoded.nativeSnapshots[0].shortWindow.sublabelOverride, "Resets Sunday")
        XCTAssertEqual(decoded.commands.count, 1)
        XCTAssertEqual(decoded.commands[0].kind, "refreshWebProviders")
        XCTAssertNil(decoded.error)
    }

    func testBridgeResponse_errorPath_roundTrip() throws {
        let original = BridgeResponse(
            ok: false,
            bridgeSchemaVersion: 1,
            macAppVersion: "2.9.0",
            ackedAt: Date(timeIntervalSince1970: 1_747_100_000),
            nativeSnapshots: [],
            settings: nil,
            commands: [],
            error: "unsupported schema version"
        )

        let data = try JSONEncoder.bridge.encode(original)
        let decoded = try JSONDecoder.bridge.decode(BridgeResponse.self, from: data)

        XCTAssertFalse(decoded.ok)
        XCTAssertEqual(decoded.error, "unsupported schema version")
        XCTAssertTrue(decoded.commands.isEmpty)
    }

    // MARK: - BridgeWindow with longWindow present

    func testBridgeSnapshot_withLongWindow_roundTrip() throws {
        let resetsAt = Date(timeIntervalSince1970: 1_747_118_000)
        let capturedAt = Date(timeIntervalSince1970: 1_747_100_000)

        let shortWindow = BridgeWindow(
            label: "5h",
            utilization: 0.8,
            resetsAt: resetsAt,
            windowDurationSec: 18000,
            sublabelOverride: nil
        )
        let longWindow = BridgeWindow(
            label: "7d",
            utilization: 0.3,
            resetsAt: resetsAt,
            windowDurationSec: 604800,
            sublabelOverride: nil
        )

        let snapshot = BridgeSnapshot(
            provider: "claude",
            capturedAt: capturedAt,
            estimated: nil,
            shortWindow: shortWindow,
            longWindow: longWindow,
            planLabel: "Max 5"
        )

        let data = try JSONEncoder.bridge.encode(snapshot)
        let decoded = try JSONDecoder.bridge.decode(BridgeSnapshot.self, from: data)

        XCTAssertEqual(decoded.provider, "claude")
        XCTAssertNil(decoded.estimated)
        let longUtil = try XCTUnwrap(decoded.longWindow?.utilization)
        XCTAssertEqual(longUtil, 0.3, accuracy: 0.001)
        XCTAssertEqual(decoded.longWindow?.windowDurationSec, 604800)
        XCTAssertEqual(decoded.planLabel, "Max 5")
    }
}
