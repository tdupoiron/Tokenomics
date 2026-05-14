import SwiftUI

/// Branded circular spinner — full-circle ring at color@25% + rotating trim arc
/// at full color. Matches mockup `.spinner` CSS (lines 999–1006):
/// `border: 2px solid accent@25%; border-top-color: accent;`
///
/// Use this anywhere onboarding shows a "checking / waiting" state — keeps
/// the language consistent with Tokenomics' menu-bar usage rings.
/// Outside onboarding, the system `ProgressView` is appropriate for native UI.
///
/// Honors `accessibilityReduceMotion` — renders a static arc when the user
/// has Reduce Motion enabled in System Settings.
struct CircularSpinner: View {
    /// Outer diameter in points.
    var size: CGFloat = 14

    /// Stroke width.
    var lineWidth: CGFloat = 2

    /// Accent color. Defaults to `Tokens.DynamicColor.accent` which auto-flips
    /// with the colorScheme; pass `Tokens.Color.accent(scheme)` explicitly when
    /// the calling view already reads `colorScheme` for sibling logic, or pass
    /// any other color when contrast needs tuning on a colored surface.
    var color: Color = Tokens.DynamicColor.accent

    /// Visible portion of the rotating arc as a fraction of the circle (0…1).
    /// 0.25 = quarter arc — matches the mockup's single-side border.
    var arcFraction: Double = 0.25

    /// Rotation period in seconds.
    var period: Double = 1.0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var rotation: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.25), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: arcFraction)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(rotation))
        }
        .frame(width: size, height: size)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: period).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}

// MARK: - Preview

#Preview("CircularSpinner — sizes — light") {
    HStack(spacing: 24) {
        CircularSpinner(size: 14)
        CircularSpinner(size: 22)
        CircularSpinner(size: 32, lineWidth: 3)
        CircularSpinner(size: 48, lineWidth: 4)
    }
    .padding(40)
    .background(Tokens.DynamicColor.bg)
    .preferredColorScheme(.light)
}

#Preview("CircularSpinner — sizes — dark") {
    HStack(spacing: 24) {
        CircularSpinner(size: 14)
        CircularSpinner(size: 22)
        CircularSpinner(size: 32, lineWidth: 3)
        CircularSpinner(size: 48, lineWidth: 4)
    }
    .padding(40)
    .background(Tokens.DynamicColor.bg)
    .preferredColorScheme(.dark)
}
