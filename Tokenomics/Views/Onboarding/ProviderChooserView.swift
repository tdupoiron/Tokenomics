import SwiftUI

/// "Pick a provider" screen — flat list of all providers grouped by category,
/// each row tagged with a Quick / Guided / Connected badge.
///
/// Layout matches mockup section 2 (guided-onboarding-mockup.html lines ~1153–1273):
///   - Centered h2 "Add a provider" + subtitle
///   - Scrollable .chooser region with group labels + provider rows
///   - Pinned .winfoot: "← Back" ghost | "I'm all set" secondary
struct ProviderChooserView: View {
    @ObservedObject var viewModel: UsageViewModel
    var onPick: (ProviderId) -> Void
    var onAllSet: () -> Void
    /// Called when the user taps ← Back; nil if there is no back destination.
    var onBack: (() -> Void)? = nil

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: 0) {
            // Header: centered h2 + subtitle
            // mockup lines 1173–1176: h-sans h2 centered, 13px text-muted
            VStack(spacing: Tokens.Spacing.s1) {
                Text("Add a provider")
                    .font(Tokens.Typography.Onboarding.h2)
                    .foregroundStyle(Tokens.Color.text(scheme))
                    .multilineTextAlignment(.center)

                Text("We'll walk you through any setup that's needed.")
                    .font(Tokens.Typography.Onboarding.small)
                    .foregroundStyle(Tokens.Color.textMuted(scheme))
                    .multilineTextAlignment(.center)
            }
            .padding(.bottom, Tokens.Spacing.s3)

            // Scrollable chooser region — flex 1, scrolls when content overflows
            // mockup .chooser: flex: 1 1 auto, overflow-y: auto
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(ProviderId.ProviderCategory.allCases, id: \.self) { category in
                        let providers = ProviderId.allCases.filter { $0.category == category }
                        if !providers.isEmpty {
                            groupLabel(category.rawValue)

                            VStack(spacing: 0) {
                                ForEach(providers, id: \.self) { provider in
                                    providerRow(provider)
                                }
                            }
                        }
                    }

                    // Legend hint at bottom of scroll area
                    // mockup .legend: surface-2 bg, border, sm radius, 12.5px, text-muted
                    legendHint
                        .padding(.top, Tokens.Spacing.s3)
                }
                .padding(.bottom, Tokens.Spacing.s2)
            }

            // Pinned footer — divider + Back ghost + All set secondary
            // mockup .winfoot: margin-top auto, padding-top 24px, border-top 1px border
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Group label

    /// Uppercase micro label above each provider group.
    /// mockup .group-label: 11px, weight 600, tracking 0.14em, uppercase, text-subtle
    private func groupLabel(_ title: String) -> some View {
        Text(title)
            .font(Tokens.Typography.Onboarding.micro.weight(.semibold))
            .foregroundStyle(Tokens.Color.textSubtle(scheme))
            .textCase(.uppercase)
            .tracking(1.5) // 0.14em ≈ 1.5pt at 11px
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, Tokens.Spacing.s3)
            .padding(.bottom, Tokens.Spacing.s1 + 2) // 6pt — mockup: margin 18px 0 6px
    }

    // MARK: - Provider row

    /// 32pt icon | name + scope | end badge or chevron.
    /// mockup .provider-row: grid 32px 1fr auto, gap 14px, padding 12×14, radius sm
    @ViewBuilder
    private func providerRow(_ provider: ProviderId) -> some View {
        let state = viewModel.providerStates[provider]
        let isConnected = state?.connection.isConnected ?? false
        let isAvailable = provider.hasAPI

        Button { onPick(provider) } label: {
            HStack(alignment: .center, spacing: Tokens.Spacing.s4 - 2) { // 14pt — mockup gap: 14px
                // 32×32 provider icon
                ProviderIcon(provider: provider, isConnected: isConnected)
                    .frame(width: 32, height: 32)

                // Name + scope
                VStack(alignment: .leading, spacing: 2) {
                    Text(provider.displayName)
                        .font(Tokens.Typography.Onboarding.body.weight(.semibold))
                        .foregroundStyle(
                            isAvailable || isConnected
                                ? Tokens.Color.text(scheme)
                                : Tokens.Color.textMuted(scheme)
                        )

                    if let scope = provider.scopeDescription {
                        Text(scope)
                            .font(Tokens.Typography.Onboarding.micro)
                            .foregroundStyle(Tokens.Color.textSubtle(scheme))
                    }
                }

                Spacer(minLength: 0)

                // End: connected badge OR setup badge + chevron
                rowEnd(provider: provider, isConnected: isConnected)
            }
            // mockup .provider-row: padding 12px 14px, radius sm on hover
            .padding(.vertical, Tokens.Spacing.s3)       // 12pt
            .padding(.horizontal, Tokens.Spacing.s4 - 2) // 14pt
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Radius.sm)
                .fill(Color.clear) // hover handled by .buttonStyle interaction
        )
        .disabled(!isAvailable && !isConnected)
    }

    @ViewBuilder
    private func rowEnd(provider: ProviderId, isConnected: Bool) -> some View {
        if isConnected {
            // Connected badge: success variant
            // mockup .badge.success.dot: success@12% bg, success text, success@25% border
            HStack(spacing: Tokens.Spacing.s1 + 2) {
                Circle()
                    .fill(Tokens.Color.success(scheme))
                    .frame(width: 6, height: 6)
                Text("Connected")
                    .font(Tokens.Typography.Onboarding.micro.weight(.medium))
                    .foregroundStyle(Tokens.Color.success(scheme))
            }
            .padding(.horizontal, Tokens.Spacing.s2 + 2) // 10pt
            .padding(.vertical, Tokens.Spacing.s1 - 1)   // 3pt
            .background(Tokens.Color.success(scheme).opacity(0.12))
            .overlay(
                Capsule().strokeBorder(Tokens.Color.success(scheme).opacity(0.25), lineWidth: 1)
            )
            .clipShape(Capsule())
        } else if !provider.hasAPI {
            Text("Coming Soon")
                .font(Tokens.Typography.Onboarding.micro)
                .foregroundStyle(Tokens.Color.textSubtle(scheme))
        } else {
            // Setup badge + chevron
            // mockup .badge: accent@12% bg, accent text, accent@25% border, 11px weight 500
            HStack(spacing: Tokens.Spacing.s2 + 2) {
                Text(setupBadgeLabel(for: provider))
                    .font(Tokens.Typography.Onboarding.micro.weight(.medium))
                    .foregroundStyle(Tokens.Color.accent(scheme))
                    .padding(.horizontal, Tokens.Spacing.s2 + 2) // 10pt
                    .padding(.vertical, Tokens.Spacing.s1 - 1)   // 3pt
                    .background(Tokens.Color.accent(scheme).opacity(0.12))
                    .overlay(
                        Capsule().strokeBorder(Tokens.Color.accent(scheme).opacity(0.25), lineWidth: 1)
                    )
                    .clipShape(Capsule())

                // Chevron ›
                Text("›")
                    .font(Tokens.Typography.Onboarding.body)
                    .foregroundStyle(Tokens.Color.textSubtle(scheme))
            }
        }
    }

    // MARK: - Legend

    /// "Quick = one sign-in, Guided = step-by-step" callout.
    /// mockup .legend: surface-2 bg, border, sm radius, 12.5px, text-muted
    private var legendHint: some View {
        Text("Some providers connect with one sign-in (**Quick**). Others take a few steps — we walk you through every one (**Guided**). No Terminal either way.")
            .font(Tokens.Typography.Onboarding.small)
            .foregroundStyle(Tokens.Color.textMuted(scheme))
            .multilineTextAlignment(.leading)
            .padding(.horizontal, Tokens.Spacing.s4 - 2) // 14pt
            .padding(.vertical, Tokens.Spacing.s3)        // 12pt
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Tokens.Color.surface2(scheme))
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.Radius.sm)
                    .strokeBorder(Tokens.Color.border(scheme), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.sm))
    }

    // MARK: - Footer

    /// Pinned winfoot: divider + "← Back" ghost on left, "I'm all set" secondary on right.
    /// mockup .winfoot: padding-top 24px, border-top 1px border, justify space-between
    private var footer: some View {
        HStack {
            if let onBack {
                Button(action: onBack) {
                    Text("← Back")
                }
                .buttonStyle(.tokenGhost)
            }

            Spacer()

            Button("I'm all set — show my usage", action: onAllSet)
                .buttonStyle(.tokenSecondary)
        }
        .padding(.top, Tokens.Spacing.s5)   // 24pt — mockup padding-top: 24px
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Tokens.Color.border(scheme))
                .frame(height: 1)
        }
    }

    // MARK: - Per-provider setup badge label

    /// User-facing badge label shown next to each provider in the chooser.
    private func setupBadgeLabel(for provider: ProviderId) -> String {
        switch provider {
        case .codex, .gemini, .cursor, .copilot:
            return "Quick setup"
        case .claude, .stableDiffusion, .runway, .elevenlabs:
            return "Guided setup"
        case .midjourney, .suno, .udio:
            return ""
        }
    }
}

// MARK: - Preview

#Preview("Provider chooser — light") {
    ProviderChooserView(
        viewModel: UsageViewModel(),
        onPick: { _ in },
        onAllSet: {},
        onBack: {}
    )
    .frame(width: 680, height: 580)
    .background(Tokens.DynamicColor.bg)
    .preferredColorScheme(.light)
}

#Preview("Provider chooser — dark") {
    ProviderChooserView(
        viewModel: UsageViewModel(),
        onPick: { _ in },
        onAllSet: {},
        onBack: {}
    )
    .frame(width: 680, height: 580)
    .background(Tokens.DynamicColor.bg)
    .preferredColorScheme(.dark)
}
