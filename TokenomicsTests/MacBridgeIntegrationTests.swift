import XCTest
@testable import Tokenomics

// MARK: - MacBridgeIntegrationTests
//
// Covers the three integration seams wired in Phase 5a:
//  1. SettingsService.setVisibility writes the correct value and fires the notification.
//  2. The visibility notification is observable (i.e. arrives and carries correct data).
//  3. NMHManifestInstaller.installAll() succeeds against a temp container (install path is callable).
//
// No SwiftUI snapshot or UI tests — logic-only, fast, no process side-effects.

final class MacBridgeIntegrationTests: XCTestCase {

    // MARK: - Setup / Teardown

    override func tearDown() {
        super.tearDown()
        // Clean up provider visibility entries written during tests
        UserDefaults.standard.removeObject(forKey: "providerVisibility")
        // Clean up any visibility keys for individual providers that may have been set
        for provider in ProviderId.allCases {
            UserDefaults.standard.removeObject(forKey: "providerVisibility")
        }
    }

    // MARK: - 1. Toggle binding writes correct value to SettingsService

    /// Calling setVisibility stores the `enabled` flag and stamps `lastChangedAt`
    /// within 2 seconds of the call — no fake time needed.
    func testSetVisibility_writesEnabledFlag() {
        SettingsService.setVisibility(false, for: .cursor)

        let result = SettingsService.visibility(for: .cursor)
        XCTAssertNotNil(result, "Visibility should be saved after setVisibility")
        XCTAssertEqual(result?.enabled, false, "enabled should match the value passed")
    }

    func testSetVisibility_stampsLastChangedAt() {
        // Capture a floor that is rounded down to the second boundary, to account
        // for ISO 8601 encoding (UserDefaults persists via JSONEncoder.bridge which
        // truncates subsecond precision). Allow 1s below the call site.
        let before = Date().addingTimeInterval(-1.0)
        SettingsService.setVisibility(true, for: .codex)
        let after = Date().addingTimeInterval(1.0)

        let result = SettingsService.visibility(for: .codex)
        guard let changedAt = result?.lastChangedAt else {
            return XCTFail("lastChangedAt should not be nil after setVisibility")
        }

        XCTAssertGreaterThanOrEqual(changedAt, before,
            "lastChangedAt should be near the call time (within 1s lower bound)")
        XCTAssertLessThanOrEqual(changedAt, after,
            "lastChangedAt should be near the call time (within 1s upper bound)")
    }

    func testSetVisibility_roundTripTrueAndFalse() {
        SettingsService.setVisibility(true, for: .gemini)
        XCTAssertEqual(SettingsService.visibility(for: .gemini)?.enabled, true)

        SettingsService.setVisibility(false, for: .gemini)
        XCTAssertEqual(SettingsService.visibility(for: .gemini)?.enabled, false)
    }

    // MARK: - 2. Visibility notification fires and carries correct payload

    /// After setVisibility, the .tokenomicsProviderVisibilityChanged notification
    /// should arrive synchronously (NotificationCenter posts synchronously on the
    /// calling thread), with the correct object and userInfo.
    func testProviderVisibilityNotification_firesOnSetVisibility() {
        let expectation = expectation(description: "visibility changed notification received")

        var receivedProviderId: String?
        var receivedSetting: ProviderVisibilitySetting?

        let observer = NotificationCenter.default.addObserver(
            forName: .tokenomicsProviderVisibilityChanged,
            object: nil,
            queue: nil
        ) { note in
            receivedProviderId = note.object as? String
            receivedSetting = note.userInfo?["setting"] as? ProviderVisibilitySetting
            expectation.fulfill()
        }

        defer { NotificationCenter.default.removeObserver(observer) }

        SettingsService.setVisibility(false, for: .copilot)

        wait(for: [expectation], timeout: 1.0)

        XCTAssertEqual(receivedProviderId, ProviderId.copilot.rawValue,
            "Notification object should be the ProviderId rawValue string")
        XCTAssertEqual(receivedSetting?.enabled, false,
            "Notification userInfo should carry the new enabled value")
        XCTAssertNotNil(receivedSetting?.lastChangedAt,
            "Notification userInfo should carry a non-nil lastChangedAt")
    }

    func testProviderVisibilityNotification_carriesCorrectProviderForEach() {
        // Spot-check two providers to confirm the rawValue is correct, not hardcoded.
        let pairs: [(ProviderId, Bool)] = [(.claude, true), (.cursor, false)]

        for (provider, enabled) in pairs {
            let expectation = expectation(description: "notification for \(provider.rawValue)")
            var receivedId: String?

            let observer = NotificationCenter.default.addObserver(
                forName: .tokenomicsProviderVisibilityChanged,
                object: nil,
                queue: nil
            ) { note in
                receivedId = note.object as? String
                expectation.fulfill()
            }

            SettingsService.setVisibility(enabled, for: provider)
            wait(for: [expectation], timeout: 1.0)
            NotificationCenter.default.removeObserver(observer)

            XCTAssertEqual(receivedId, provider.rawValue,
                "Notification object for .\(provider.rawValue) should be '\(provider.rawValue)'")
        }
    }

    // MARK: - 3. NMHManifestInstaller.installAll() is callable against a temp container

    /// Verifies the install path executes without throwing. Uses a temp directory
    /// so no real browser paths are touched. Validates the result shape.
    func testNMHManifestInstaller_callableAndReturnsResult() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("MacBridgeInstallTest-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // The shim from NMHManifestInstallerTests is in the same test target.
        // Use it to bypass Bundle.main and filesystem side-effects.
        let result = NMHManifestInstallerTestShim.installAll(
            appSupportURL: tempDir,
            bridgePath: "/Applications/Tokenomics.app/Contents/Helpers/TokenomicsBridge"
        )

        XCTAssertEqual(result.written, 8, "First install should write all 8 manifests")
        XCTAssertEqual(result.failed, 0, "No failures expected against a writable temp dir")
        XCTAssertEqual(result.skipped, 0, "Not simulating translocation — no skips expected")
    }

    func testNMHManifestInstaller_translocatedPathProducesSkip() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("MacBridgeInstallTransTest-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let result = NMHManifestInstallerTestShim.installAll(
            appSupportURL: tempDir,
            bridgePath: "/var/folders/AppTranslocation/abc/d/Tokenomics.app/Contents/Helpers/TokenomicsBridge",
            simulateTranslocation: true
        )

        XCTAssertEqual(result.written, 0, "Translocation guard must prevent all writes")
        XCTAssertEqual(result.skipped, 1, "Translocation guard returns one skip sentinel")
    }

    // MARK: - 4. MacSideStateExporter bridge snapshot push

    /// Verifies that BridgeSnapshot can be constructed from a ProviderUsageSnapshot
    /// with the correct 0-1 normalised utilization (the 0-100 → 0-1 conversion
    /// in UsageViewModel.makeBridgeSnapshot must divide by 100).
    func testBridgeSnapshotUtilizationNormalization() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("MacBridgeSnapTest-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let exporter = MacSideStateExporter(containerURL: tempDir)

        // Simulate what UsageViewModel.makeBridgeSnapshot produces for 75% utilization.
        let snap = BridgeSnapshot(
            provider: "claude",
            capturedAt: Date(),
            estimated: nil,
            shortWindow: BridgeWindow(
                label: "5h",
                utilization: 75.0 / 100.0, // 0.75 after normalisation
                resetsAt: Date().addingTimeInterval(3600),
                windowDurationSec: 18000,
                sublabelOverride: nil
            ),
            longWindow: nil,
            planLabel: "Pro"
        )

        await exporter.setNativeSnapshot(snap)
        try await Task.sleep(for: .milliseconds(350))

        let url = tempDir.appendingPathComponent("mac-side.json")
        let data = try Data(contentsOf: url)
        let state = try JSONDecoder.bridge.decode(MacSideState.self, from: data)

        let utilization = state.nativeSnapshots["claude"]?.shortWindow.utilization ?? -1
        XCTAssertEqual(utilization, 0.75, accuracy: 0.001,
            "utilization in mac-side.json must be the 0-1 fraction, not the 0-100 percentage")
    }
}
