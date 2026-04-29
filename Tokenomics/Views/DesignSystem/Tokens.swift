import SwiftUI

// MARK: - Brand colors
//
// Color tokens lifted verbatim from docs/guided-onboarding-mockup.html (`:root`
// and `[data-theme="dark"]` blocks). Each is backed by a Color Set in the asset
// catalog so light/dark resolves automatically via the system color scheme.

extension Color {
    static let brandBg           = Color("Brand/BrandBg")
    static let brandBg2          = Color("Brand/BrandBg2")
    static let brandSurface      = Color("Brand/BrandSurface")
    static let brandSurface2     = Color("Brand/BrandSurface2")
    static let brandBorder       = Color("Brand/BrandBorder")
    static let brandBorderStrong = Color("Brand/BrandBorderStrong")
    static let brandText         = Color("Brand/BrandText")
    static let brandTextMuted    = Color("Brand/BrandTextMuted")
    static let brandTextSubtle   = Color("Brand/BrandTextSubtle")
    static let brandAccent       = Color("Brand/BrandAccent")
    static let brandAccentInk    = Color("Brand/BrandAccentInk")
    static let brandSuccess      = Color("Brand/BrandSuccess")
    static let brandWarning      = Color("Brand/BrandWarning")
    static let brandDanger       = Color("Brand/BrandDanger")
}

// MARK: - Typography
//
// Onboarding type scale verbatim from mockup CSS (lines 53–59):
//   --fs-h1:      28px  (serif, regular weight)
//   --fs-h2:      22px  (sans, weight 600)
//   --fs-h3:      18px  (sans, weight 600)
//   --fs-body-lg: 17px  (sans, weight 400)
//   --fs-body:    15px  (sans, weight 400, 1.55 line-height)
//   --fs-small:   13px  (sans, weight 400)
//   --fs-micro:   11px  (sans, weight 500)
//
// PostScript family names verified against font binaries via fontTools nameID 16:
//   HedvigLettersSerif.ttf  → "Hedvig Letters Serif"
//   DMSans.ttf              → "DM Sans"
//
// Each uses `relativeTo:` so Dynamic Type and Display zoom scale the base size
// (per mockup line 1101-1103).

extension Font {
    /// Welcome hero and Done celebration headline.
    /// Mockup: `.h-serif h1` — Hedvig Letters Serif, --fs-h1 28px.
    static let tokenSerifH1 = Font.custom("Hedvig Letters Serif", size: 28, relativeTo: .title)

    /// Every flow-screen headline (Detect, Install Homebrew, Sign in…).
    /// Mockup: `.h-sans h2` — DM Sans --fs-h2 22px weight 600.
    static let tokenSansH2 = Font.custom("DM Sans", size: 22, relativeTo: .title2).weight(.semibold)

    /// Sub-section headings inside a screen.
    /// Mockup: `.h-sans h3` — DM Sans --fs-h3 18px weight 600.
    static let tokenSansH3 = Font.custom("DM Sans", size: 18, relativeTo: .title3).weight(.semibold)

    /// Body lead paragraph under a headline (`.lede` in the mockup).
    /// Mockup: --fs-body-lg 17px.
    static let tokenLede = Font.custom("DM Sans", size: 17, relativeTo: .body)

    /// Default body copy. Mockup: --fs-body 15px.
    static let tokenBody = Font.custom("DM Sans", size: 15, relativeTo: .body)

    /// Helper text, sublabels, button-sm. Mockup: --fs-small 13px.
    static let tokenSmall = Font.custom("DM Sans", size: 13, relativeTo: .footnote)

    /// Step labels, badges, group labels. Mockup: --fs-micro 11px weight 500.
    static let tokenMicro = Font.custom("DM Sans", size: 11, relativeTo: .caption).weight(.medium)

    /// Command previews, log lines.
    static let tokenMono = Font.system(size: 13, design: .monospaced)
}

// MARK: - Spacing (8pt grid)
//
// Verbatim from mockup CSS: --s-1 through --s-8.

enum BrandSpacing {
    static let s1: CGFloat = 4
    static let s2: CGFloat = 8
    static let s3: CGFloat = 12
    static let s4: CGFloat = 16
    static let s5: CGFloat = 24
    static let s6: CGFloat = 32
    static let s7: CGFloat = 48
    static let s8: CGFloat = 64
}

// MARK: - Radii
//
// Verbatim from mockup CSS: --r-xs through --r-pill.

enum BrandRadius {
    static let xs: CGFloat   = 6
    static let sm: CGFloat   = 10
    static let md: CGFloat   = 14
    static let lg: CGFloat   = 20
    static let xl: CGFloat   = 28
    static let pill: CGFloat = 999
}

// MARK: - Preview

#Preview("Brand color palette") {
    ScrollView {
        VStack(alignment: .leading, spacing: 8) {
            ForEach([
                ("BrandBg", Color.brandBg),
                ("BrandBg2", Color.brandBg2),
                ("BrandSurface", Color.brandSurface),
                ("BrandSurface2", Color.brandSurface2),
                ("BrandBorder", Color.brandBorder),
                ("BrandBorderStrong", Color.brandBorderStrong),
                ("BrandText", Color.brandText),
                ("BrandTextMuted", Color.brandTextMuted),
                ("BrandTextSubtle", Color.brandTextSubtle),
                ("BrandAccent", Color.brandAccent),
                ("BrandAccentInk", Color.brandAccentInk),
                ("BrandSuccess", Color.brandSuccess),
                ("BrandWarning", Color.brandWarning),
                ("BrandDanger", Color.brandDanger),
            ], id: \.0) { name, color in
                HStack {
                    RoundedRectangle(cornerRadius: 6).fill(color).frame(width: 60, height: 32)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.brandBorder, lineWidth: 1))
                    Text(name).font(.tokenSmall)
                }
            }
        }
        .padding(24)
    }
    .frame(width: 320, height: 600)
}

#Preview("Brand typography") {
    VStack(alignment: .leading, spacing: 16) {
        Text("Track your AI usage.").font(.tokenSerifH1)
        Text("Install Homebrew").font(.tokenSansH2)
        Text("Tokenomics will run:").font(.tokenSansH3)
        Text("Tokenomics needs Homebrew to install Node.js.").font(.tokenLede)
        Text("Body copy default size.").font(.tokenBody)
        Text("Helper / sublabel text.").font(.tokenSmall)
        Text("MICRO LABEL").font(.tokenMicro).tracking(1.5)
        Text("brew install node").font(.tokenMono)
    }
    .foregroundStyle(Color.brandText)
    .padding(24)
    .background(Color.brandBg)
    .frame(width: 320, height: 400)
}
