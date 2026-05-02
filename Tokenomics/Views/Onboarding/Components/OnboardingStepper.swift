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

    @Environment(\.colorScheme) private var scheme

    // Fixed slot geometry — matches the mockup's CSS values.
    // .step { flex: 0 0 110px } | .step-line { flex: 0 0 36px } | .step-mark { 22×22 }
    private let slotWidth: CGFloat = 110
    private let lineWidth: CGFloat = 36
    private let markSize: CGFloat  = 22

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
                        .alignmentGuide(.top) { $0[.top] }
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Subviews

    private func stepSlot(index: Int, item: OnboardingStepperItem) -> some View {
        // 10pt gap between mark and label (mockup .step `gap: 8` bumped per
        // visual review for a touch more breathing room).
        VStack(spacing: 10) {
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
                // Active halo ring — mockup: `box-shadow: 0 0 0 4px color-mix(accent 22%, transparent)`
                .overlay(
                    Circle()
                        .stroke(
                            state == .active
                                ? Tokens.Color.accent(scheme).opacity(0.22)
                                : (state == .error
                                    ? Tokens.Color.danger(scheme).opacity(0.22)
                                    : Color.clear),
                            lineWidth: 4
                        )
                        .frame(width: markSize + 8, height: markSize + 8)
                )

            switch state {
            case .completed:
                // Inner check is dark on cyan in dark mode (cyan bg = dark text,
                // mirrors PrimaryButtonStyle); white on navy in light mode.
                // Semibold instead of bold — bold reads stocky inside the 22pt circle.
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(scheme == .dark ? Tokens.Color.ink900 : Color.white)
            case .error:
                // Mockup line 1866 uses literal "!" but the system glyph at heavy
                // weight reads as a thick pill. SF Symbol `exclamationmark` is a
                // designed symbol with cleaner proportions at small sizes.
                Image(systemName: "exclamationmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.white)
            case .active, .upcoming:
                Text("\(index)")
                    .font(Tokens.Typography.Onboarding.stepperNumber)
                    .monospacedDigit()
                    .foregroundStyle(activeNumberColor(state: state))
            }
        }
    }

    private func stepLabel(_ text: String, state: OnboardingStepperItem.State) -> some View {
        Text(text)
            .font(state == .active || state == .error
                  ? Tokens.Typography.Onboarding.micro.weight(.semibold)
                  : Tokens.Typography.Onboarding.micro)
            .foregroundStyle(labelColor(state))
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Horizontal line between two step slots.
    /// Color tracks the left segment's state.
    private func connectorLine(leftState: OnboardingStepperItem.State) -> some View {
        // mockup .step-line: height 2px, border-radius 2px
        // .step-line.done: background var(--accent)
        // else: background var(--border-strong)
        Rectangle()
            .fill(lineColor(leftState))
            .frame(height: 2)
            .padding(.top, (markSize - 2) / 2)
            .animation(.easeInOut(duration: Tokens.Motion.standard), value: leftState)
    }

    // MARK: - Color helpers

    private func lineColor(_ state: OnboardingStepperItem.State) -> Color {
        // mockup: .step-line.done → accent; else → border-strong (mockup line 311).
        // Note: error state uses border-strong (NOT danger). The line PRECEDING
        // an error step is colored by the previous (completed) step, which gives
        // the user a clear "this is where you got to" trail; the line LEAVING the
        // error step stays neutral so the error doesn't visually contaminate
        // downstream segments.
        switch state {
        case .completed: return Tokens.Color.accent(scheme)
        case .active, .upcoming, .error: return Tokens.Color.borderStrong(scheme)
        }
    }

    /// Inner number color for `.active` (filled) and `.upcoming` (bordered) states.
    /// In dark mode, the cyan-filled active circle gets dark text (mirrors the
    /// PrimaryButtonStyle dark-mode contract). Upcoming uses subtle text either way.
    private func activeNumberColor(state: OnboardingStepperItem.State) -> Color {
        if state == .upcoming { return Tokens.Color.textSubtle(scheme) }
        return scheme == .dark ? Tokens.Color.ink900 : Color.white
    }

    private func markFill(_ state: OnboardingStepperItem.State) -> Color {
        switch state {
        case .completed, .active: return Tokens.Color.accent(scheme)
        case .error:              return Tokens.Color.danger(scheme)
        case .upcoming:           return Tokens.Color.surface2(scheme)
        }
    }

    private func markBorder(_ state: OnboardingStepperItem.State) -> Color {
        switch state {
        case .completed, .active: return Tokens.Color.accent(scheme)
        case .error:              return Tokens.Color.danger(scheme)
        case .upcoming:           return Tokens.Color.borderStrong(scheme)
        }
    }

    private func labelColor(_ state: OnboardingStepperItem.State) -> Color {
        switch state {
        case .active:    return Tokens.Color.text(scheme)
        case .completed: return Tokens.Color.textMuted(scheme)
        case .error:     return Tokens.Color.danger(scheme)
        case .upcoming:  return Tokens.Color.textSubtle(scheme)
        }
    }
}

// MARK: - Preview

#Preview("Stepper — Installing step active — light") {
    OnboardingStepper(items: [
        OnboardingStepperItem(label: "Checking tools", state: .completed),
        OnboardingStepperItem(label: "Installing tools", state: .active),
        OnboardingStepperItem(label: "Signing in", state: .upcoming),
        OnboardingStepperItem(label: "Connection check", state: .upcoming),
    ])
    .padding(Tokens.Spacing.s5)
    .frame(width: 720, height: 80)
    .background(Tokens.DynamicColor.bg)
    .preferredColorScheme(.light)
}

#Preview("Stepper — Installing step active — dark") {
    OnboardingStepper(items: [
        OnboardingStepperItem(label: "Checking tools", state: .completed),
        OnboardingStepperItem(label: "Installing tools", state: .active),
        OnboardingStepperItem(label: "Signing in", state: .upcoming),
        OnboardingStepperItem(label: "Connection check", state: .upcoming),
    ])
    .padding(Tokens.Spacing.s5)
    .frame(width: 720, height: 80)
    .background(Tokens.DynamicColor.bg)
    .preferredColorScheme(.dark)
}

#Preview("Stepper — Signing in active — light") {
    OnboardingStepper(items: [
        OnboardingStepperItem(label: "Checking tools", state: .completed),
        OnboardingStepperItem(label: "Installing tools", state: .completed),
        OnboardingStepperItem(label: "Signing in", state: .active),
        OnboardingStepperItem(label: "Connection check", state: .upcoming),
    ])
    .padding(Tokens.Spacing.s5)
    .frame(width: 720, height: 80)
    .background(Tokens.DynamicColor.bg)
    .preferredColorScheme(.light)
}

#Preview("Stepper — All done — light") {
    OnboardingStepper(items: [
        OnboardingStepperItem(label: "Checking tools", state: .completed),
        OnboardingStepperItem(label: "Installing tools", state: .completed),
        OnboardingStepperItem(label: "Signing in", state: .completed),
        OnboardingStepperItem(label: "Connection check", state: .active),
    ])
    .padding(Tokens.Spacing.s5)
    .frame(width: 720, height: 80)
    .background(Tokens.DynamicColor.bg)
    .preferredColorScheme(.light)
}

#Preview("Stepper — Install failed — light") {
    OnboardingStepper(items: [
        OnboardingStepperItem(label: "Checking tools", state: .completed),
        OnboardingStepperItem(label: "Installing tools", state: .error),
        OnboardingStepperItem(label: "Signing in", state: .upcoming),
        OnboardingStepperItem(label: "Connection check", state: .upcoming),
    ])
    .padding(Tokens.Spacing.s5)
    .frame(width: 720, height: 80)
    .background(Tokens.DynamicColor.bg)
    .preferredColorScheme(.light)
}

#Preview("Stepper — Install failed — dark") {
    OnboardingStepper(items: [
        OnboardingStepperItem(label: "Checking tools", state: .completed),
        OnboardingStepperItem(label: "Installing tools", state: .error),
        OnboardingStepperItem(label: "Signing in", state: .upcoming),
        OnboardingStepperItem(label: "Connection check", state: .upcoming),
    ])
    .padding(Tokens.Spacing.s5)
    .frame(width: 720, height: 80)
    .background(Tokens.DynamicColor.bg)
    .preferredColorScheme(.dark)
}
