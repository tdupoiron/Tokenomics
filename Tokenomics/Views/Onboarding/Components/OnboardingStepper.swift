import SwiftUI

// MARK: - Data model

/// One segment in the onboarding step indicator.
struct OnboardingStepperItem: Hashable {
    let label: String
    let state: State

    enum State: Hashable {
        /// Already done — filled accent circle with a checkmark.
        case completed
        /// Currently active — filled accent circle with a ring halo.
        case active
        /// Not yet reached — muted bordered circle.
        case upcoming
        /// Failed at this step — red circle and label; subsequent steps show as upcoming.
        case error
    }
}

// MARK: - View

/// 4-segment step indicator shown across the top of every connector screen.
///
/// Each segment is a 110pt fixed-width slot (matching the mockup's `.step { flex: 0 0 110px }`)
/// so labels never push their neighbors regardless of length or weight. Lines between
/// segments are 36pt wide and take the color of the lower-numbered (left) segment —
/// completed segments color their trailing line in accent; upcoming segments leave it muted.
///
/// Usage:
/// ```swift
/// OnboardingStepper(items: viewModel.stepperItems)
/// ```
struct OnboardingStepper: View {
    let items: [OnboardingStepperItem]

    // Fixed slot geometry — matches the mockup's CSS values.
    private let slotWidth: CGFloat = 110
    private let lineWidth: CGFloat = 36
    private let markSize: CGFloat = 22

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element) { index, item in
                // Step slot
                stepSlot(index: index + 1, item: item)
                    .frame(width: slotWidth)

                // Connector line — omit after the last item
                if index < items.count - 1 {
                    connectorLine(leftState: item.state)
                        .frame(width: lineWidth, height: markSize)
                        .padding(.top, 0)
                        // Optical center-alignment with the mark circles
                        .alignmentGuide(.top) { $0[.top] }
                }
            }
        }
        // The marks are 22pt; the labels hang below — total height ~40pt.
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Subviews

    private func stepSlot(index: Int, item: OnboardingStepperItem) -> some View {
        VStack(spacing: 6) {
            stepMark(index: index, state: item.state)
            stepLabel(item.label, state: item.state)
        }
    }

    private func stepMark(index: Int, state: OnboardingStepperItem.State) -> some View {
        ZStack {
            Circle()
                .fill(markFill(state))
                .frame(width: markSize, height: markSize)
                .overlay(
                    Circle()
                        .strokeBorder(markBorder(state), lineWidth: 1.5)
                )
                // Active halo ring — matches mockup's `box-shadow: 0 0 0 4px`
                .shadow(
                    color: state == .active ? Color.accentColor.opacity(0.22) : .clear,
                    radius: 0, x: 0, y: 0
                )
                .overlay(
                    Circle()
                        .stroke(state == .active ? Color.accentColor.opacity(0.22) : .clear, lineWidth: 4)
                        .frame(width: markSize + 8, height: markSize + 8)
                )

            switch state {
            case .completed:
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
            case .error:
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
            case .active, .upcoming:
                Text("\(index)")
                    .font(.system(size: 11, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(state == .upcoming ? Color.secondary : .white)
            }
        }
    }

    private func stepLabel(_ text: String, state: OnboardingStepperItem.State) -> some View {
        Text(text)
            .font(.system(size: 11, weight: state == .active ? .semibold : .medium))
            .foregroundStyle(labelColor(state))
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Horizontal line between two step slots. Color tracks the left segment's state.
    private func connectorLine(leftState: OnboardingStepperItem.State) -> some View {
        Rectangle()
            .fill(lineColor(leftState))
            .frame(height: 2)
            // Optical vertical alignment: center the line on the mark circles,
            // which are 22pt tall; the labels hang below.
            .padding(.top, (markSize - 2) / 2)
            .animation(.easeInOut(duration: 0.2), value: leftState)
    }

    private func lineColor(_ state: OnboardingStepperItem.State) -> Color {
        switch state {
        case .completed: return .accentColor
        case .error: return Color(nsColor: .systemRed)
        case .active, .upcoming: return Color(nsColor: .separatorColor)
        }
    }

    // MARK: - Color helpers

    private func markFill(_ state: OnboardingStepperItem.State) -> Color {
        switch state {
        case .completed, .active: return .accentColor
        case .error: return Color(nsColor: .systemRed)
        case .upcoming: return Color(nsColor: .controlBackgroundColor)
        }
    }

    private func markBorder(_ state: OnboardingStepperItem.State) -> Color {
        switch state {
        case .completed, .active: return .accentColor
        case .error: return Color(nsColor: .systemRed)
        case .upcoming: return Color(nsColor: .separatorColor)
        }
    }

    private func labelColor(_ state: OnboardingStepperItem.State) -> Color {
        switch state {
        case .active: return Color.primary
        case .completed: return Color.secondary
        case .error: return Color(nsColor: .systemRed)
        case .upcoming: return Color(nsColor: .tertiaryLabelColor)
        }
    }
}

// MARK: - Preview

#Preview("Stepper — Installing step active") {
    OnboardingStepper(items: [
        OnboardingStepperItem(label: "Checking", state: .completed),
        OnboardingStepperItem(label: "Installing", state: .active),
        OnboardingStepperItem(label: "Signing in", state: .upcoming),
        OnboardingStepperItem(label: "Done", state: .upcoming),
    ])
    .padding(24)
    .frame(width: 480)
}

#Preview("Stepper — Signing in active") {
    OnboardingStepper(items: [
        OnboardingStepperItem(label: "Checking", state: .completed),
        OnboardingStepperItem(label: "Installing", state: .completed),
        OnboardingStepperItem(label: "Signing in", state: .active),
        OnboardingStepperItem(label: "Done", state: .upcoming),
    ])
    .padding(24)
    .frame(width: 480)
}

#Preview("Stepper — All done") {
    OnboardingStepper(items: [
        OnboardingStepperItem(label: "Checking", state: .completed),
        OnboardingStepperItem(label: "Installing", state: .completed),
        OnboardingStepperItem(label: "Signing in", state: .completed),
        OnboardingStepperItem(label: "Connection check", state: .active),
    ])
    .padding(24)
    .frame(width: 480)
}

#Preview("Stepper — Install failed") {
    OnboardingStepper(items: [
        OnboardingStepperItem(label: "Checking", state: .completed),
        OnboardingStepperItem(label: "Installing", state: .error),
        OnboardingStepperItem(label: "Signing in", state: .upcoming),
        OnboardingStepperItem(label: "Connection check", state: .upcoming),
    ])
    .padding(24)
    .frame(width: 480)
}
