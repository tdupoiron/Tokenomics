import SwiftUI

// MARK: - Detection item

/// One row in the Detect step's prerequisite checklist.
///
/// Used by `DetectStep` to render the per-prereq status (Homebrew, Node.js,
/// Codex CLI, etc.) as a list of white surface cards with check / pending icons.
struct DetectionItem: Hashable {
    /// Primary label. E.g. "Homebrew", "Node.js", "Codex CLI".
    let name: String

    /// Optional muted suffix appended to the name. E.g. "(includes npm)".
    /// Rendered in `text-subtle` next to the bold `name`.
    let nameSuffix: String?

    /// Secondary line below the name. Path when installed (`/opt/homebrew/bin/brew`),
    /// description or package name when not (`@openai/codex`, "Package manager for macOS").
    let sublabel: String

    /// Detection result.
    let status: Status

    enum Status: Hashable {
        case installed     // ✓ green check, "Installed" right meta
        case notInstalled  // ○ pending circle, "Not installed" right meta
        case checking      // muted spinner, "Checking…" right meta (transient)
    }

    init(name: String, nameSuffix: String? = nil, sublabel: String, status: Status) {
        self.name = name
        self.nameSuffix = nameSuffix
        self.sublabel = sublabel
        self.status = status
    }
}

// MARK: - DetectStep

/// "Checking your Mac…" screen. When `items` is non-empty, renders the rich
/// checklist (one card per prerequisite) per mockup section 3 (`.check-list`,
/// lines 461–477). When empty, falls back to a centered spinner — used for
/// connectors with no prereq chain (Cursor app-bundle wait, API-key paste).
///
/// Layout (rich mode):
///   - Left-aligned `h2` headline + `lede` subtitle
///   - 3 (or N) `.check-row` cards (white surface, 1px border, sm radius)
///   - Spacer
///   - Footer: disabled `tokenSecondary` "Continuing…" button (auto-advance
///     happens in the connector; the button is just visual confirmation)
///
/// All chrome (titlebar, stepper, Back button) is supplied by `ConnectorView`.
struct DetectStep: View {
    /// Per-prereq detection results. When empty, the view falls back to a
    /// centered spinner (legacy behavior for connectors without checklists).
    var items: [DetectionItem] = []

    /// Subtitle below "Checking your Mac…". E.g. "Looking for the tools needed
    /// to connect Codex." Used in both the spinner fallback and the rich layout.
    var subtitle: String

    /// Tapped on the "← Back" link in the footer. Optional — omit to hide
    /// the back affordance (e.g. when DetectStep is the very first screen).
    var onBack: (() -> Void)? = nil

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        if items.isEmpty {
            spinnerFallback
        } else {
            checklistLayout
        }
    }

    // MARK: - Rich checklist

    private var checklistLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Headline + subtitle — left-aligned per mockup section 3 frames
            VStack(alignment: .leading, spacing: Tokens.Spacing.s2) {
                Text("Checking your Mac…")
                    .font(Tokens.Typography.Onboarding.h2)
                    .foregroundStyle(Tokens.Color.text(scheme))

                Text(subtitle)
                    .font(Tokens.Typography.Onboarding.lede)
                    .foregroundStyle(Tokens.Color.textMuted(scheme))
            }

            // Check list — mockup .check-list margin: 24px 0 0 0
            VStack(spacing: Tokens.Spacing.s2) {
                ForEach(items, id: \.self) { item in
                    checkRow(item)
                }
            }
            .padding(.top, Tokens.Spacing.s5)

            Spacer(minLength: Tokens.Spacing.s5)

            // Footer — divider + Back link + disabled "Continuing…" secondary.
            // Standard component shared across every step view.
            WindowFooter {
                if let onBack {
                    BackLink(action: onBack)
                }
            } trailing: {
                Button("Continuing…") {}
                    .buttonStyle(.tokenSecondary)
                    .disabled(true)
                    .opacity(0.6)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Check row

    /// One white surface card with status icon, name + sublabel, right meta.
    /// mockup .check-row (lines 462–477):
    ///   grid 22px 1fr auto · gap 14px · padding 12×16 · bg surface · 1px border · r-sm
    private func checkRow(_ item: DetectionItem) -> some View {
        HStack(alignment: .center, spacing: Tokens.Spacing.s4 - 2) { // 14pt gap
            // Status icon — 22pt slot
            statusIcon(for: item.status)
                .frame(width: 22, height: 22)

            // Name + sublabel column
            VStack(alignment: .leading, spacing: 2) {
                nameWithSuffix(item)
                Text(item.sublabel)
                    // Mockup .check-row .sublabel: 12pt text-muted (line 476).
                    // Use a literal 12pt DM Sans here — Tokens.Typography.Onboarding.small
                    // is 13pt which reads slightly large in this row context.
                    .font(.custom("DM Sans", size: 12))
                    .foregroundStyle(Tokens.Color.textMuted(scheme))
            }

            Spacer(minLength: 0)

            // Right meta — "Installed" / "Not installed" / "Checking…"
            // Mockup .check-row .right: 12pt text-muted (line 477)
            Text(rightMetaText(for: item.status))
                .font(.custom("DM Sans", size: 12))
                .foregroundStyle(Tokens.Color.textMuted(scheme))
        }
        .padding(.vertical, Tokens.Spacing.s4)        // 16pt — bumped from 12pt for thicker rows
        .padding(.horizontal, Tokens.Spacing.s5 - 4)  // 20pt — slightly more breathing room than 16pt
        .background(Tokens.Color.surface(scheme))
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.sm)
                .strokeBorder(Tokens.Color.border(scheme), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.sm))
    }

    /// Bold name + optional muted suffix in one line. Uses Text concatenation
    /// so the line wraps as a single block if long.
    private func nameWithSuffix(_ item: DetectionItem) -> some View {
        // Mockup .check-row .label: 14pt, font-weight 500 (medium).
        let nameText = Text(item.name)
            .font(Tokens.Typography.Onboarding.body.weight(.medium))
            .foregroundColor(Tokens.Color.text(scheme))

        if let suffix = item.nameSuffix {
            // Suffix uses textMuted (0.64), not textSubtle (0.44). Mockup HTML
            // inline-styles it text-subtle but the actual rendered target reads
            // closer to textMuted — go with the visual reference.
            return nameText + Text(" \(suffix)")
                .font(Tokens.Typography.Onboarding.body)
                .foregroundColor(Tokens.Color.textMuted(scheme))
        } else {
            return nameText
        }
    }

    @ViewBuilder
    private func statusIcon(for status: DetectionItem.Status) -> some View {
        switch status {
        case .installed:
            Image(systemName: "checkmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Tokens.Color.success(scheme))
        case .notInstalled:
            // Mockup `.ico.pending` shows an unfilled circle.
            Circle()
                .strokeBorder(Tokens.Color.textSubtle(scheme), lineWidth: 1.5)
                .frame(width: 14, height: 14)
        case .checking:
            ProgressView()
                .controlSize(.small)
        }
    }

    private func rightMetaText(for status: DetectionItem.Status) -> String {
        switch status {
        case .installed:    return "Installed"
        case .notInstalled: return "Not installed"
        case .checking:     return "Checking…"
        }
    }

    // MARK: - Spinner fallback

    private var spinnerFallback: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: Tokens.Spacing.s3) {
                ProgressView()
                    .controlSize(.large)
                    .padding(.bottom, Tokens.Spacing.s1)

                Text("Checking your Mac…")
                    .font(Tokens.Typography.Onboarding.h2)
                    .foregroundStyle(Tokens.Color.text(scheme))
                    .multilineTextAlignment(.center)

                Text(subtitle)
                    .font(Tokens.Typography.Onboarding.lede)
                    .foregroundStyle(Tokens.Color.textMuted(scheme))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Tokens.Spacing.s5)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview

private let codexDevMacItems: [DetectionItem] = [
    .init(name: "Homebrew",
          sublabel: "/opt/homebrew/bin/brew",
          status: .installed),
    .init(name: "Node.js",
          nameSuffix: "(includes npm)",
          sublabel: "/opt/homebrew/bin/node · v20.10.0",
          status: .installed),
    .init(name: "Codex CLI",
          sublabel: "@openai/codex",
          status: .notInstalled),
]

private let codexFreshMacItems: [DetectionItem] = [
    .init(name: "Homebrew",
          sublabel: "Package manager for macOS",
          status: .notInstalled),
    .init(name: "Node.js",
          nameSuffix: "(includes npm)",
          sublabel: "Required by the Codex CLI",
          status: .notInstalled),
    .init(name: "Codex CLI",
          sublabel: "@openai/codex",
          status: .notInstalled),
]

/// Stepper state when DetectStep is the active screen — "Checking tools" active,
/// rest upcoming. Reused across all DetectStep previews.
private let detectStepperItems: [OnboardingStepperItem] = [
    .init(label: "Checking tools",   state: .active),
    .init(label: "Installing tools", state: .upcoming),
    .init(label: "Signing in",       state: .upcoming),
    .init(label: "Connection check", state: .upcoming),
]

#Preview("Detect — Dev's Mac (light)") {
    WindowChromePreview(title: "Connect OpenAI", stepperItems: detectStepperItems) {
        DetectStep(items: codexDevMacItems,
                   subtitle: "Looking for the tools needed to connect Codex.",
                   onBack: {})
    }
    .frame(width: 680, height: 580)
    .preferredColorScheme(.light)
}

#Preview("Detect — Dev's Mac (dark)") {
    WindowChromePreview(title: "Connect OpenAI", stepperItems: detectStepperItems) {
        DetectStep(items: codexDevMacItems,
                   subtitle: "Looking for the tools needed to connect Codex.",
                   onBack: {})
    }
    .frame(width: 680, height: 580)
    .preferredColorScheme(.dark)
}

#Preview("Detect — Fresh Mac (light)") {
    WindowChromePreview(title: "Connect OpenAI", stepperItems: detectStepperItems) {
        DetectStep(items: codexFreshMacItems,
                   subtitle: "Looking for the tools needed to connect Codex.",
                   onBack: {})
    }
    .frame(width: 680, height: 580)
    .preferredColorScheme(.light)
}

#Preview("Detect — Spinner fallback (light)") {
    WindowChromePreview(title: "Connect Cursor", stepperItems: detectStepperItems) {
        DetectStep(subtitle: "Checking for Cursor.app…", onBack: {})
    }
    .frame(width: 680, height: 580)
    .preferredColorScheme(.light)
}
