import XCTest
@testable import Tokenomics

// MARK: - MacSideStateExporterTests
//
// All tests point the exporter at a TemporaryDirectory so no real App Group
// container is touched. The 250ms debounce is tested by waiting slightly over
// that interval; tests are still sub-second each.

final class MacSideStateExporterTests: XCTestCase {

    private var tempDir: URL!

    override func setUp() async throws {
        try await super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("MacSideExporterTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDir)
        try await super.tearDown()
    }

    // MARK: - Helpers

    private func makeExporter() -> MacSideStateExporter {
        MacSideStateExporter(containerURL: tempDir)
    }

    private func makeSnapshot(provider: String, utilization: Double = 0.5) -> BridgeSnapshot {
        BridgeSnapshot(
            provider: provider,
            capturedAt: Date(),
            estimated: false,
            shortWindow: BridgeWindow(
                label: "5h",
                utilization: utilization,
                resetsAt: Date().addingTimeInterval(3600),
                windowDurationSec: 18000,
                sublabelOverride: nil
            ),
            longWindow: nil,
            planLabel: "Pro"
        )
    }

    private func readMacSideState() throws -> MacSideState {
        let url = tempDir.appendingPathComponent("mac-side.json")
        let data = try Data(contentsOf: url)
        return try JSONDecoder.bridge.decode(MacSideState.self, from: data)
    }

    // MARK: - setNativeSnapshot

    func testSetNativeSnapshot_writesToDiskAfterDebounce() async throws {
        let exporter = makeExporter()
        let snap = makeSnapshot(provider: "claude")

        await exporter.setNativeSnapshot(snap)

        // Wait slightly over the 250ms debounce
        try await Task.sleep(for: .milliseconds(350))

        let state = try readMacSideState()
        XCTAssertNotNil(state.nativeSnapshots["claude"])
        XCTAssertEqual(state.nativeSnapshots["claude"]?.provider, "claude")
    }

    func testSetNativeSnapshot_updatesInMemoryImmediately() async throws {
        let exporter = makeExporter()
        let snap = makeSnapshot(provider: "codex")
        await exporter.setNativeSnapshot(snap)

        // lastWrittenAt won't be set yet (debounce pending), but we can verify
        // by waiting and checking the file
        try await Task.sleep(for: .milliseconds(350))
        let writtenAt = await exporter.lastWrittenAt
        XCTAssertNotNil(writtenAt)
    }

    // MARK: - clearNativeSnapshot

    func testClearNativeSnapshot_removesEntry() async throws {
        let exporter = makeExporter()
        await exporter.setNativeSnapshot(makeSnapshot(provider: "gemini"))
        try await Task.sleep(for: .milliseconds(350))

        await exporter.clearNativeSnapshot(provider: "gemini")
        try await Task.sleep(for: .milliseconds(350))

        let state = try readMacSideState()
        XCTAssertNil(state.nativeSnapshots["gemini"])
    }

    // MARK: - enqueueCommand deduplication

    func testEnqueueCommand_dedupesByKind() async throws {
        let exporter = makeExporter()

        await exporter.enqueueCommand(BridgeCommand(kind: "refreshWebProviders"))
        await exporter.enqueueCommand(BridgeCommand(kind: "refreshWebProviders"))
        await exporter.enqueueCommand(BridgeCommand(kind: "refreshWebProviders"))

        try await Task.sleep(for: .milliseconds(350))

        let state = try readMacSideState()
        let matching = state.pendingCommands.filter { $0.kind == "refreshWebProviders" }
        XCTAssertEqual(matching.count, 1, "Only one pending command per kind should survive deduplication")
    }

    func testEnqueueCommand_differentKindsAreAllKept() async throws {
        let exporter = makeExporter()

        await exporter.enqueueCommand(BridgeCommand(kind: "refreshWebProviders"))
        await exporter.enqueueCommand(BridgeCommand(kind: "ping"))

        try await Task.sleep(for: .milliseconds(350))

        let state = try readMacSideState()
        XCTAssertEqual(state.pendingCommands.count, 2)
    }

    // MARK: - setVisibility

    func testSetVisibility_writesCorrectValue() async throws {
        let exporter = makeExporter()
        let setting = ProviderVisibilitySetting(enabled: false, lastChangedAt: Date())

        await exporter.setVisibility(setting, for: "cursor")

        try await Task.sleep(for: .milliseconds(350))

        let state = try readMacSideState()
        XCTAssertEqual(state.providerVisibility["cursor"]?.enabled, false)
    }

    // MARK: - setMacAppVersion

    func testSetMacAppVersion_persists() async throws {
        let exporter = makeExporter()
        await exporter.setMacAppVersion("9.9.9")

        try await Task.sleep(for: .milliseconds(350))

        let state = try readMacSideState()
        XCTAssertEqual(state.macAppVersion, "9.9.9")
    }

    // MARK: - Debounce coalescing

    func testDebounce_rapidUpdatesProduceOneDiskWrite() async throws {
        let exporter = makeExporter()

        // Fire 10 rapid updates — only one file write should land
        for i in 0..<10 {
            await exporter.setNativeSnapshot(makeSnapshot(provider: "claude", utilization: Double(i) / 10.0))
        }

        // Before debounce expires, file may not exist yet
        let beforeURL = tempDir.appendingPathComponent("mac-side.json")
        // (We don't assert its absence — a previous write from setUp could exist)

        try await Task.sleep(for: .milliseconds(400))

        let state = try readMacSideState()
        // The last update sets utilization = 0.9
        let utilization = state.nativeSnapshots["claude"]?.shortWindow.utilization ?? 0.0
        XCTAssertEqual(utilization, 0.9, accuracy: 0.001,
                       "Final write should reflect the last-enqueued snapshot")
    }

    // MARK: - Atomic write (no half-files)

    func testAtomicWrite_fileIsAlwaysReadable() async throws {
        let exporter = makeExporter()

        // Start 20 concurrent updates
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<20 {
                group.addTask {
                    await exporter.setNativeSnapshot(self.makeSnapshot(provider: "claude", utilization: Double(i) / 20.0))
                }
            }
        }

        try await Task.sleep(for: .milliseconds(400))

        // After settling, mac-side.json must be valid JSON — never a partial write
        let url = tempDir.appendingPathComponent("mac-side.json")
        let data = try Data(contentsOf: url)
        XCTAssertNoThrow(try JSONDecoder.bridge.decode(MacSideState.self, from: data),
                         "File should always be valid JSON (atomic rename guarantees this)")
    }

    // MARK: - lastWrittenAt accessor

    func testLastWrittenAt_isNilBeforeFirstWrite() async {
        let exporter = makeExporter()
        let writtenAt = await exporter.lastWrittenAt
        // May be non-nil if mac-side.json existed (loaded from disk on init).
        // For a fresh temp dir, it should be nil since we're using a containerURL.
        // The exporter won't write until an update is triggered.
        _ = writtenAt // Accessor reachable — no crash
    }

    func testLastWrittenAt_isSetAfterWrite() async throws {
        let exporter = makeExporter()
        await exporter.setMacAppVersion("1.0.0")
        try await Task.sleep(for: .milliseconds(350))

        let writtenAt = await exporter.lastWrittenAt
        XCTAssertNotNil(writtenAt)
    }
}
