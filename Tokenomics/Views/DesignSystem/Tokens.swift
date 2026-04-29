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
// Onboarding type scale from mockup CSS — the *applied* class sizes, not the
// :root variables (lines 53–59 define some variables that no class consumes;
// the .h1/.h3/.lede classes at lines 335–344 redefine the rendered sizes):
//   .h1   → 30px  (serif, regular weight)        [line 335; used line 1139, 1822]
//   .h2   → 22px  (sans, weight 600)             [line 336]
//   .h3   → 17px  (sans, weight 600)             [line 337]
//   .lede → 15px  (sans, weight 400, 1.55 lh)    [lines 338–344]
//   --fs-body:  15px                              [line 57; used in body { }]
//   --fs-small: 13px                              [line 58]
//   --fs-micro: 11px                              [line 59]
//
// PostScript family names verified against font binaries via fontTools nameID 16:
//   HedvigLettersSerif.ttf  → "Hedvig Letters Serif"
//   DMSans.ttf              → "DM Sans"
//
// Each uses `relativeTo:` so Dynamic Type and Display zoom scale the base size
// (per mockup line 1101-1103).

extension Font {
    /// Welcome hero and Done celebration headline.
    /// Mockup: `.h-serif h1` — Hedvig Letters Serif 30px (line 335).
    static let tokenSerifH1 = Font.custom("Hedvig Letters Serif", size: 30, relativeTo: .title)

    /// Every flow-screen headline (Detect, Install Homebrew, Sign in…).
    /// Mockup: `.h-sans h2` — DM Sans 22px weight 600 (line 336).
    static let tokenSansH2 = Font.custom("DM Sans", size: 22, relativeTo: .title2).weight(.semibold)

    /// Sub-section headings inside a screen.
    /// Mockup: `.h-sans h3` — DM Sans 17px weight 600 (line 337).
    static let tokenSansH3 = Font.custom("DM Sans", size: 17, relativeTo: .title3).weight(.semibold)

    /// Body lead paragraph under a headline (`.lede` in the mockup).
    /// Mockup: 15px / 1.55 line-height (lines 338–344).
    static let tokenLede = Font.custom("DM Sans", size: 15, relativeTo: .body)

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

private struct BrandSwatch: Identifiable {
    let id: String
    let color: Color
}

private let brandPalette: [BrandSwatch] = [
    .init(id: "BrandBg",            color: .brandBg),
    .init(id: "BrandBg2",           color: .brandBg2),
    .init(id: "BrandSurface",       color: .brandSurface),
    .init(id: "BrandSurface2",      color: .brandSurface2),
    .init(id: "BrandBorder",        color: .brandBorder),
    .init(id: "BrandBorderStrong",  color: .brandBorderStrong),
    .init(id: "BrandText",          color: .brandText),
    .init(id: "BrandTextMuted",     color: .brandTextMuted),
    .init(id: "BrandTextSubtle",    color: .brandTextSubtle),
    .init(id: "BrandAccent",        color: .brandAccent),
    .init(id: "BrandAccentInk",     color: .brandAccentInk),
    .init(id: "BrandSuccess",       color: .brandSuccess),
    .init(id: "BrandWarning",       color: .brandWarning),
    .init(id: "BrandDanger",        color: .brandDanger),
]

#Preview("Brand color palette") {
    ScrollView {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(brandPalette) { swatch in
                HStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(swatch.color)
                        .frame(width: 60, height: 32)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.brandBorder, lineWidth: 1)
                        )
                    Text(swatch.id).font(.tokenSmall)
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
