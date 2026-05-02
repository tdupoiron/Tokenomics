import SwiftUI

/// Reusable bottom-of-window footer used by every onboarding step view.
///
/// Mockup .winfoot (guided-onboarding-mockup.html lines 562–572):
///   margin-top: auto; padding-top: 24px; border-top: 1px solid var(--border);
///   display: flex; justify-content: space-between;
///
/// Layout: 1px divider on top, then a horizontal row with `leading` slot
/// (typically a "← Back" ghost button) and `trailing` slot (typically a
/// primary or secondary CTA). Either slot can be empty — Spacer fills the gap.
///
/// Use this from any step view that needs the standard footer chrome rather
/// than building it inline. Eliminates per-screen drift in divider color,
/// padding, and button placement.
struct WindowFooter<Leading: View, Trailing: View>: View {
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Tokens.Color.border(scheme))
                .frame(height: 1)

            HStack {
                leading
                Spacer()
                trailing
            }
            .padding(.top, Tokens.Spacing.s5) // 24pt — mockup padding-top: 24px
        }
    }
}

// MARK: - Convenience: standard "← Back" button

/// Mockup "← Back" .btn-ghost — arrow + label, text-muted (tuned lighter
/// per visual review), smaller arrow than text. Drop into a `WindowFooter`'s
/// leading slot via `BackLink(action: onBack)`.
struct BackLink: View {
    let action: () -> Void

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Button(action: action) {
            HStack(spacing: Tokens.Spacing.s1) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 10, weight: .medium)) // smaller than label
                Text("Back")
                    .font(Tokens.Typography.Onboarding.small) // 13pt regular (lighter than the medium-weight ghost default)
            }
            .foregroundStyle(Tokens.Color.textMuted(scheme))
            .padding(.horizontal, Tokens.Spacing.s3)
            .padding(.vertical, Tokens.Spacing.s2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview("WindowFooter — Back + Continuing — light") {
    VStack {
        Spacer()
        WindowFooter {
            BackLink {}
        } trailing: {
            Button("Continuing…") {}
                .buttonStyle(.tokenSecondary)
                .disabled(true)
                .opacity(0.6)
        }
    }
    .padding(.horizontal, Tokens.Spacing.s5)
    .padding(.bottom, Tokens.Spacing.s5)
    .frame(width: 720, height: 200)
    .background(Tokens.DynamicColor.bg)
    .preferredColorScheme(.light)
}

#Preview("WindowFooter — Back + Continuing — dark") {
    VStack {
        Spacer()
        WindowFooter {
            BackLink {}
        } trailing: {
            Button("Continuing…") {}
                .buttonStyle(.tokenSecondary)
                .disabled(true)
                .opacity(0.6)
        }
    }
    .padding(.horizontal, Tokens.Spacing.s5)
    .padding(.bottom, Tokens.Spacing.s5)
    .frame(width: 720, height: 200)
    .background(Tokens.DynamicColor.bg)
    .preferredColorScheme(.dark)
}

#Preview("WindowFooter — Back + Install — light") {
    VStack {
        Spacer()
        WindowFooter {
            BackLink {}
        } trailing: {
            Button("Install Homebrew") {}
                .buttonStyle(.tokenPrimary)
        }
    }
    .padding(.horizontal, Tokens.Spacing.s5)
    .padding(.bottom, Tokens.Spacing.s5)
    .frame(width: 720, height: 200)
    .background(Tokens.DynamicColor.bg)
    .preferredColorScheme(.light)
}

#Preview("WindowFooter — Back + Install — dark") {
    VStack {
        Spacer()
        WindowFooter {
            BackLink {}
        } trailing: {
            Button("Install Homebrew") {}
                .buttonStyle(.tokenPrimary)
        }
    }
    .padding(.horizontal, Tokens.Spacing.s5)
    .padding(.bottom, Tokens.Spacing.s5)
    .frame(width: 720, height: 200)
    .background(Tokens.DynamicColor.bg)
    .preferredColorScheme(.dark)
}
