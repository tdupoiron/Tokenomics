import Foundation

/// Per-provider visibility state with a timestamp for last-writer-wins reconciliation
/// across the Mac app <-> web extension bridge.
struct ProviderVisibilitySetting: Codable, Sendable, Equatable {
    var enabled: Bool
    var lastChangedAt: Date
}
