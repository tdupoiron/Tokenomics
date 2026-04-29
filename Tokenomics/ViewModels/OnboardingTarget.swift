import Foundation

/// Shared signal that lets non-window callers ask the guided onboarding window
/// to skip the chooser and land directly on a specific provider's connector flow.
/// Set before calling openWindow(id: "onboarding"); ConnectorContainer reads + clears.
@MainActor
final class OnboardingTarget: ObservableObject {
    static let shared = OnboardingTarget()
    @Published var preselected: ProviderId?
    private init() {}
}
