# Tokenomics Web Companion — Phased Build Spec

**Companion to:** `docs/web-companion-plan.md` (the *what* and *why*).
**This doc is the *how*:** ordered phases, exact files, exact design tokens, exact tests. Every UI element is grounded in `~/projects/trytokenomics-site/design-system.md` — never in ad-hoc values.

**Last updated:** 2026-05-03

---

## 0. Design-system contract (read this first)

This contract applies to *every* phase. Whenever a phase says "card" or "button" or "ring," it means the version specified in `design-system.md`. No improvisation, no Apple defaults, no Tailwind primitives.

### 0.1 Source of truth and how we enforce it

| Concern | Source of truth | Where it lives in the extension repo |
|---|---|---|
| Tokens (color, typography, space, radius, shadow, motion) | `design-system.md` §"Quick start: CSS variables" | `web-companion/src/styles/tokens.css` (verbatim mirror) |
| Components (button, card, ring, usage bar, status pill, plan badge, segmented tabs) | `design-system.md` §06 + ported Mac views (see §0.3) | `web-companion/src/styles/components.css` + per-component TSX in `web-companion/src/popup/` |
| Widget visual language (rings, fills, theme gradients) | `design-system.md` §07 | reused in popup provider cards |
| Per-screen layout templates | `docs/guided-onboarding-mockup.html` windows 1–3 + 12 | popup welcome wizard + settings |
| Anti-patterns to avoid | `design-system.md` §"Anti-patterns (Swift)" | apply the equivalents in CSS too — no `system-ui`-only stacks, no system colors, no naked `1rem` |

**Enforcement:** `tests/design-system-regression.sh` already runs 51 checks across the MD ↔ HTML pair. Phase 1 extends it to **53 checks**:
- Check 52 — `tokens.css` `:root` block matches `design-system.md` `:root` byte-for-byte (excluding leading/trailing whitespace).
- Check 53 — `tokens.css` `[data-theme="dark"]` block matches the MD dark block.
CI runs the script on every PR. A failing check blocks merge.

### 0.2 Token cheat sheet (the ones the extension uses most)

| Use | Token |
|---|---|
| Primary background (light) | `var(--bg)` → `#F3EFE5` (cream-50) |
| Primary background (dark) | `var(--bg)` → `#07101a` |
| Card surface | `var(--surface)` |
| Card border | `1px solid var(--border)` |
| Card radius | `var(--r-md)` (14px) |
| Card padding | `var(--s-4)` (16px) |
| Card shadow | `var(--shadow-sm)` |
| Body text | `var(--text)` |
| Muted text (sublabels, "updated Xm ago") | `var(--text-muted)` |
| Subtle text (placeholders) | `var(--text-subtle)` |
| Brand accent (rings, links) | `var(--brand-600)` light · `var(--brand-200)` dark |
| Success / connected | `var(--success)` (#2F8F4F) |
| Warning / stale / estimated | `var(--warning)` (#C26A1F — burnt amber, NOT yellow) |
| Danger / parser drift | `var(--danger)` (#B33A3A) |
| Heading font | `var(--font-serif)` Hedvig Letters Serif |
| Body font | `var(--font-sans)` DM Sans |
| Numerics in cards | `var(--font-sans)` with `font-variant-numeric: tabular-nums` |
| Spacing scale | `--s-1` 4 · `--s-2` 8 · `--s-3` 12 · `--s-4` 16 · `--s-5` 24 · `--s-6` 32 |
| Motion easing | `var(--ease)` cubic-bezier(.2,.7,.2,1) |
| Motion duration | `var(--dur)` 220ms (default) · `var(--dur-fast)` 120ms |

**Rule:** any time you'd type a hex code, a font name, or a magic number — stop and use a token. Same posture as the Swift app.

### 0.3 Components inherited from the design system + Mac app

Two sources. Pure design-system primitives (buttons, pills, etc.) live in `design-system.md` §06. Composite Tokenomics-specific components (usage bar, segmented tabs, plan badge, sync footer) live in the Mac app's `Views/` — port those line-for-line to TSX/CSS, don't reinvent them.

| Component | Source | Notes |
|---|---|---|
| **Buttons** (Primary / Secondary / Ghost / TextLink) | `design-system.md` §06 Buttons | Extension uses Secondary for "Open Tokenomics," TextLink for "Settings." |
| **Status pill** | `design-system.md` §06 Pills | Small rounded badge — used for inline warning markers. |
| **Plan badge** | `Tokenomics/Views/PlanBadgeView.swift` | Header pill showing "Pro" / "Max" / "Free" / etc. Replaces the originally-drafted "● N connected" aggregate pill, which doesn't exist on Mac. |
| **Usage bar** | `Tokenomics/Views/UsageBarView.swift` | Track-fill bar + single pace-circle marker. **Replaces the originally-drafted 10-dot pace row** — that pattern was invented, not from the Mac app. |
| **Segmented tabs** | `Tokenomics/Views/ProviderTabView.swift` | The one-provider-at-a-time tab strip. Collapses to icon-only at 4+ providers. |
| **Sync footer** | `Tokenomics/Views/SyncFooterView.swift` | Last-synced timestamp, refresh, display mode, settings, share — bottom bar of every popup state. |
| **Ring icon** | `design-system.md` §07 Widgets, ring | Small circular progress glyph — used as a per-provider visual marker on tabs and (eventually) the toolbar badge. |

**Rule of thumb:** if a Mac SwiftUI view exists for the visual, port THAT view's structure. If only a design-system primitive applies, use that. **Don't invent a one-off design that doesn't exist in either place** — the Phase 5 visual-parity check explicitly compares popup screens to Mac counterparts, and inventions will fail it.

If a phase needs something neither has, that's a signal to *add it to `design-system.md` and the Mac app first* — never invent a one-off in the extension.

---

## 1. Phase 1 — Foundation

**Goal:** an empty extension that builds for Chrome and Safari, opens a 400×560 popup that renders the design-system shell with no data, and proves the bridge contract end-to-end with a static fixture.

**Estimated:** Claude ~2h, Rob ~1h test.

### 1.1 Files to create

```
web-companion/
├── package.json                      # wxt + react + typescript
├── wxt.config.ts                     # Chrome + Safari targets
├── tsconfig.json
├── public/
│   ├── icon-16-light.png             # toolbar icon, light theme
│   ├── icon-16-dark.png
│   ├── icon-32-light.png
│   └── icon-32-dark.png
├── src/
│   ├── shared/
│   │   └── snapshot-schema.ts        # TS source of truth for the JSON contract
│   ├── styles/
│   │   ├── tokens.css                # verbatim mirror of design-system.md :root
│   │   └── components.css            # button/card/pill/dots — pulls from tokens
│   ├── popup/
│   │   ├── index.html
│   │   ├── App.tsx                   # renders empty state from a fixture
│   │   ├── ProviderCard.tsx
│   │   ├── HeaderBar.tsx
│   │   ├── FooterBar.tsx
│   │   └── styles.module.css
│   └── background/
│       └── index.ts                  # service worker stub
└── tests/
    └── fixtures/
        └── snapshot-mock.json        # one of each provider for visual QA

tests/design-system-regression.sh    # extended with checks 52 + 53
```

Tokenomics-side additions (Mac):

```
TokenomicsBridge/                     # NEW Swift CLI target
├── Package.swift                     # SPM, links to AppKit for App Group writes
└── main.swift                        # ~150 LOC: stdin frames → schema check → App Group write

Tokenomics/Services/
└── WebCompanionService.swift         # NEW — observes App Group, merges into UsageService
```

`project.yml` — new target stanza for `TokenomicsBridge` (signed Developer ID, embedded as a helper inside `Tokenomics.app/Contents/Helpers/`).

### 1.2 Design touchpoints (Phase 1)

The empty popup must already be visually correct — wrong tokens here propagate.

- **Window dimensions:** 400×560 (matches plan §5.3).
- **Background:** `var(--bg)`. Body padding `var(--s-4)`.
- **Header:** flex row, `padding-block var(--s-4)`, `border-bottom 1px solid var(--border)`. Title "Tokenomics" in `var(--font-serif)`, 18px, weight 400, color `var(--text)`. Status pill on right: `font-sans` 12px weight 500, `var(--success)` background at 16% alpha, `var(--success)` text, `var(--r-pill)` (999px) radius, padding `var(--s-1) var(--s-3)`.
- **Empty card placeholder × 4:** `var(--surface)` background, `1px solid var(--border)`, `var(--r-md)` radius, `var(--s-4)` padding, `var(--shadow-sm)` shadow. Stack with `gap: var(--s-3)` (12px between cards).
- **Footer:** `border-top 1px solid var(--border)`, `padding var(--s-3) var(--s-4)`, flex space-between. Settings on left = TextLink button (DM Sans 14px, `var(--accent)`). "Open Tokenomics" on right = Secondary button (DM Sans 14px medium, `var(--surface-2)` background, `1px solid var(--border-strong)`, `var(--r-sm)` radius, padding `8px 16px`).
- **Light/dark:** popup root reads `prefers-color-scheme`, sets `data-theme="dark"` on `<html>`. Both themes must render correctly from this phase forward.

### 1.3 Tests

- `bash tests/design-system-regression.sh` → "Passed: 53, Failed: 0".
- Manual: open popup in Chrome dev mode, screenshot light + dark — both must match the visual chrome of `guided-onboarding-mockup.html` window 1.
- Manual: feed `tests/fixtures/snapshot-mock.json` to the bridge via `cat snapshot-mock.json | TokenomicsBridge`. Verify App Group UserDefaults `webCompanionSnapshot` key contains the JSON. Verify `WebCompanionService` logs the parsed snapshot.

### 1.4 Definition of done

- [ ] `wxt dev` opens an extension with the empty popup visually matching the design system in light + dark.
- [ ] `xcodegen generate` produces a project that builds the new `TokenomicsBridge` target without errors.
- [ ] Bridge smoke test passes (fixture JSON → App Group).
- [ ] Regression test 51 → 53 all pass.

---

## 2. Phase 2 — Claude provider end-to-end

**Goal:** a real provider rendering live, real data through the full pipeline. After this phase, you can sign into claude.ai, open the popup, and see your actual five-hour and seven-day utilization. The Tokenomics popover also reflects it.

**Estimated:** Claude ~2h, Rob ~1h test.

### 2.1 Files to create / modify

```
web-companion/src/
├── background/
│   ├── claude.ts                     # poller: org id (24h cache) + usage every 5/30 min
│   └── bridge-chrome.ts              # Native Messaging client; reconnect; schema validate
├── content/
│   └── claude-sse.ts                 # MAIN-world script on /chat/* — listens to message_limit SSE
├── popup/
│   └── ProviderCard.tsx              # render real data
└── shared/
    └── providers/
        └── claude.ts                 # parser + types for the response shape

TokenomicsBridge/main.swift           # finalize: schema validation, App Group write
Tokenomics/Services/
└── WebCompanionService.swift         # merge into UsageService with source-priority rule
```

### 2.2 Provider body design (single-tab-visible pattern)

The popup shows ONE provider at a time via `ProviderTabView`. The per-provider body is the visual primitive — Phases 3–4.5 reuse it for ChatGPT / Gemini / MJ. Get this *right* before building the others.

**Port `Views/UsageBarView.swift` line-for-line to TS/CSS.** That's the canonical Mac usage display; the extension uses the same component, not a reinvention.

**Anatomy** (mirrors `PopoverView`'s per-tab content area):

```
5-Hour Window                    36%      ← window label + utilization%
────●─────────────────────────────         ← track-fill bar + single pace circle
                                            (NOT 10 pace dots)

7-Day Window                     72%      ← same pattern for each window
────────────●─────────────────────

Resets Tue at 6:00 PM                     ← reset microcopy
```

**Tokens (match `UsageBarView.swift` exactly):**

| Element | Token / value |
|---|---|
| Window label | `var(--font-sans)`, 13px, weight 500, `var(--text)` |
| Utilization% | `var(--font-sans)`, 13px, weight 500, `tabular-nums`, `var(--accent)` |
| Track (background) | `var(--brand-600)` at 18% alpha, height 4px, `var(--r-pill)` |
| Fill (utilization) | `var(--brand-600)`, height 4px, width = utilization%, `var(--r-pill)` |
| Pace circle | 8×8 circle, `var(--brand-600)`, positioned at `paceFraction%` along the track. Single circle, not a row of dots. Indicates whether the user is on pace through the window. |
| No color shift based on utilization — alerting is handled by per-provider notification thresholds in the Mac app, not by implicit color rules in the bar.
| Reset microcopy | `var(--font-sans)`, 12px, `var(--text-muted)` |

**Anti-patterns:**
- ❌ 10-dot pace row with threshold-tinted colors — that was an invented pattern; `UsageBarView` uses a single track + single pace circle.
- ❌ Per-card expand drawer — the tab IS the surface; extras (Opus 7-day, GPU minutes, etc.) render as additional `UsageBarView` instances stacked vertically within the same tab body.
- ❌ Hover-shadow card chrome — the popover's body is flat; the `ProviderTabView` tabs are the only chrome.

**Multi-window display:** stack multiple `UsageBarView` instances vertically — primary (5-hour or daily), then secondary (7-day), then any provider-specific extras (Opus 7d for Claude Max, GPU minutes for MJ, etc.).

### 2.3 Background flow

```
service worker boot
  → chrome.alarms.create('claude-poll', { periodInMinutes: 5 })
  → on alarm: if claude.ai cookie present → fetchUsage()
  → on visibility change (chrome.tabs.onUpdated): pause/resume cadence
fetchUsage:
  → GET /api/organizations  (cache id 24h via chrome.storage.local)
  → GET /api/organizations/{id}/usage
  → map to Snapshot, postMessage to bridge
content script (claude.ai/chat/*):
  → inject MAIN-world script that hooks the page's existing SSE EventSource
  → on 'message_limit' event: postMessage to background → bridge override
```

### 2.4 Tests

- Visual: light + dark snapshots of the popup with one Claude card showing live data. Compare to `guided-onboarding-mockup.html` window 8 popover row pattern.
- Functional: log out of claude.ai → card switches to "Sign in to claude.ai" empty state, no errors in console.
- Stale handling: throttle the SW alarm to never fire → after 30 min, card opacity reduces to 50%, "Updated 31m ago" in `var(--warning)`.
- Bridge: kill `TokenomicsBridge` mid-flow → extension reconnects on next alarm; no data loss.
- App-side: Tokenomics popover shows the Claude row sourced from web companion (globe icon next to the label).

### 2.5 Definition of done

- [ ] Real claude.ai usage visible in popup, light + dark.
- [ ] SSE override updates utilization in real time during a chat.
- [ ] Source-priority merge into `UsageService` works (web companion overrides API key when fresh).
- [ ] Logged-out empty state ships in this phase, not deferred.

---

## 3. Phase 3 — ChatGPT

**Goal:** ChatGPT card renders live, and the MAIN-world fetch patch captures both `/wham/usage` body and `x-ratelimit-*` headers from `/conversation` calls.

**Estimated:** Claude ~2h, Rob ~1h test.

### 3.1 Files to create

```
web-companion/src/
├── background/
│   └── chatgpt.ts                    # poller: /backend-api/wham/usage every 5 min
├── content/
│   └── chatgpt-fetch-patch.ts        # MAIN-world fetch + XHR monkey-patch
└── shared/providers/
    └── chatgpt.ts                    # parser, model-quota fallback table
```

### 3.2 Design touchpoints

- **Provider card:** identical visual recipe to Phase 2 — same tokens, same components. The card spec is defined once and reused.
- **Headline numbers when fallback active:** "10 of 80 msgs (estimated)" — `(estimated)` in the warning pill style (§06 Pills, `var(--warning)` 16% alpha bg, `var(--warning)` text, 11px, weight 500, `var(--r-pill)`).
- **Logged-out state:** "Sign in to chatgpt.com" (TextLink to https://chatgpt.com).

### 3.3 Tests

- Open `chatgpt.com`, send a message, watch popup card update within 5s (header observation) and within 5min (poll).
- Disable `/wham/usage` (network tab block) → falls back to local counter, card shows `(estimated)` pill.
- Beta DMG ships at end of this phase. Recruit ~5 testers from the Tokenomics Discord to confirm the wham response shape across plans (Free / Plus / Pro). Capture parser baselines.

### 3.4 Definition of done

- [ ] ChatGPT card live in popup with real data.
- [ ] Fallback counter mode validated when primary path blocked.
- [ ] At least 3 different plan tiers' wham responses captured as parser fixtures.

---

## 4. Phase 4 — Gemini estimated

**Goal:** Gemini card with a clearly-labeled estimated counter.

**Estimated:** Claude ~1.5h, Rob ~1h test.

### 4.1 Files to create

```
web-companion/src/
├── content/
│   └── gemini-counter.ts             # observes BardChatUiServer batchexecute, increments per model
└── shared/providers/
    └── gemini.ts                     # quota tables, model detection
```

### 4.2 Design touchpoints

- **`(estimated)` pill** in the title row, never hidden. Same warning pill recipe as Phase 3 fallback.
- **Tooltip on hover** of the pill: "Counter is estimated — Gemini doesn't expose live usage. Resets daily at midnight Pacific."

### 4.3 Tests

- Send 3 Gemini Pro messages, see counter tick up.
- Switch to Gemini Flash mid-session, see model attribution change in the expanded detail.
- Counter rolls over correctly at the configured daily reset time.

### 4.4 Definition of done

- [ ] Gemini card live with `(estimated)` pill.
- [ ] Tooltip explains why.
- [ ] Counter survives popup close + browser restart (persisted via `chrome.storage.local`).

---

## 4.5. Phase 4.5 — Midjourney

**Goal:** Midjourney card with Fast Hours and GPU Minutes — first working MJ tracker on any platform.

**Estimated:** Claude ~1.5h, Rob ~1h test.

### 4.5.1 Files to create

```
web-companion/src/
├── background/
│   └── midjourney.ts                 # poller: /api/app/billing/balance every 10/60 min
├── content/
│   └── midjourney-observer.ts        # baseline-capture from active session, saves first response shape
└── shared/providers/
    └── midjourney.ts                 # parser + plan-tier quota table
```

### 4.5.2 Design touchpoints

- **Card title row:** "Midjourney" + headline `7.2h Fast / 73% GPU` (Fast hours remaining + GPU% used). Numbers in `tabular-nums`.
- **Detail rows:** Fast %, GPU %, Plan tier (Standard / Pro / Mega) shown via the small status pill in `var(--accent)` 14% alpha bg.
- **Reset microcopy:** "Resets May 29" — billing-cycle date.

### 4.5.3 Tests

- Visit `midjourney.com/app`, observe popup card populate within 10 min.
- Verify Fast / Relax / GPU values match what the MJ web app shows on the billing page.
- Plan-tier detection correct for Standard / Pro / Mega test accounts (or simulated via fixture if testers unavailable).

### 4.5.4 Definition of done

- [ ] MJ card live in popup with real data.
- [ ] Roadmap entry flips from Placeholder → Shipped via web companion.
- [ ] Beta DMG goes out at the end of this phase to ~10 testers covering all four providers.

---

## 5. Phase 5 — Safari target

**Goal:** Safari Web Extension ships inside the Tokenomics .app, writes directly to App Group UserDefaults, no separate bridge process.

**Estimated:** Claude ~1.5h, Rob ~1h test.

### 5.1 Files to create / modify

```
web-companion/wxt.config.ts            # add safari target

TokenomicsSafariExtension/             # NEW Xcode target inside Tokenomics.xcodeproj
├── Info.plist
├── SafariWebExtensionHandler.swift   # receives messages from JS, writes to App Group
└── Resources/                         # copied from wxt safari build output

project.yml                            # new target stanza for the Safari extension
```

### 5.2 Design touchpoints

- **Identical popup.** Safari renders the same `popup.html` from the same wxt build. Tokens, components, and layout are byte-identical to the Chrome version.
- **One subtlety:** Safari's popup width is sometimes constrained by the toolbar. Confirm 400px renders without horizontal scroll on every Safari-supporting Mac (15", 13", external display).

### 5.3 Tests

- Install the Safari extension via Tokenomics → Settings → "Enable Safari Extension." Toggle on in Safari Settings.
- All four providers populate identically to Chrome.
- App Group write path verified: `defaults read group.com.robstout.tokenomics webCompanionSnapshot` shows the latest JSON.

### 5.4 Definition of done

- [ ] Safari extension ships inside the existing notarized .app — no new pipeline.
- [ ] Visual parity with Chrome on Mac across all four providers.
- [ ] Source-attribution icon in the Tokenomics popover correctly distinguishes Safari- vs Chrome-sourced data.

---

## 5.5 Phase 5.5 — Paired install flow

**Goal:** the app and the extensions install and turn on together when the user wants pairing — and gracefully solo when they don't.

**Estimated:** Claude ~2h, Rob ~1h test (real install/uninstall passes on a clean Mac).

### 5.5.1 Files to create / modify

**Integrates with the existing `ConnectorContainer` flow** — does NOT append a separate Connect-Web-Companion screen. The Phase 3 onboarding scaffolding already on `main` (committed in `2fe8bfe`) is the slot:

```
Tokenomics/Views/Onboarding/
├── ConnectorContainer.swift          # MODIFY — wire MultiSelectStep + SetupPlanStep
│                                       (dormant scaffolding already present).
│                                       Browser extension becomes ONE of the
│                                       batched setup steps when chosen.
└── Steps/
    ├── MultiSelectStep.swift         # EXISTS — already on main (dormant).
    │                                   "AI you chat with" group includes the
    │                                   web-companion providers (Claude / ChatGPT
    │                                   / Gemini / Midjourney consumer tiers).
    └── SetupPlanStep.swift           # EXISTS — already on main (dormant).
                                        Renders the extension install as a
                                        single step: "1. Install browser
                                        extension — covers N of the providers
                                        you picked at once."

Tokenomics/Views/Settings/
└── WebCompanionSettingsView.swift    # NEW — Settings → Connections → Web Companion

Tokenomics/Services/
├── WebCompanionService.swift         # NEW — detect Safari extension state via
│                                       SFSafariExtensionManager; read NMH
│                                       heartbeat from App Group UserDefaults
│                                       for Chrome/Edge/Firefox.
├── ExtensionDataReader.swift         # NEW — Phase 2's NMH bridge already wrote
│                                       this; surface its data into
│                                       UsageViewModel alongside CLI/API-key
│                                       providers.
└── BrowserDetector.swift             # NEW — which browsers are installed
                                        (used to scope the install plan + show
                                        "Install in Chrome / Safari" etc.).

web-companion/src/options/
└── PairAppStep.tsx                   # NEW — final step of the extension's
                                        new-tab onboarding (per plan §5.7).
                                        "Get the menu bar app" with download
                                        link + tokenomics:// deep-link probe.
```

### 5.5.2 Design touchpoints

- **App-side onboarding integration:** the `MultiSelectStep` + `SetupPlanStep` flow already shipped (`2fe8bfe`) becomes user-reachable. `ConnectorContainer.Screen` enum gains a `.multiSelect` / `.setupPlan` route between Permissions and the per-provider connector. When the user picks browser-based providers (Claude consumer, ChatGPT, Gemini, Midjourney), the setup plan groups them into a single "Install browser extension" step that opens Chrome Web Store / Safari Extensions. **No standalone `ConnectWebCompanionStep` view** — the work is data + routing, not a new screen.
- **App-side Settings entry (`WebCompanionSettingsView`):** new row in `Settings → Connections` between "Coding Tools" and "Image Generation" sections (per `AIConnectionsView`'s existing grouping — same pattern, just one new group). Title "Web Companion." States:
  - *Not installed* — "Install the browser extension to track Claude, ChatGPT, Gemini, and Midjourney" + Secondary button per detected browser.
  - *Installed but not connected* — "Extension installed but not running. Open browser to activate." + status pill `var(--warning)`.
  - *Connected* — "Connected via Chrome · last update 2m ago" + status pill `var(--success)`. Per-browser breakdown if multiple.
- **Extension-side `PairAppStep`:** final step of the new-tab onboarding wizard (per plan §5.7). Hedvig serif H2 "Get the Tokenomics menu bar app," body copy, Primary button "Download" (links to `trytokenomics.com`), TextLink "Skip — extension works on its own."
- **Connection status in popup footer (`SyncFooter`):** small dot + label, `var(--font-sans)` 11px, `var(--text-muted)`. "Tokenomics: detected ✓" (success dot) / "Tokenomics: not detected" (no dot, TextLink "Install").

**Anti-pattern:** the older draft of this section called for a standalone `ConnectWebCompanionStep.swift` appended to onboarding. That diverges from the Phase 3 synthesis flow (multi-select → batched plan) already on `main`. Don't add a new step; wire the existing scaffolding.

### 5.5.3 Detection logic

**App detects extension presence:**
- Safari: `SFSafariExtensionManager.getStateOfSafariExtension(withIdentifier:)` — direct, synchronous answer.
- Chrome/Edge/Firefox: extension calls `chrome.runtime.connectNative("com.robstout.tokenomics")` on first run; the bridge writes a heartbeat into App Group UserDefaults (`webCompanionLastConnect: { browser, timestamp }`). App reads heartbeat; "connected" = heartbeat within last 30 min.

**Extension detects app presence:**
- `chrome.runtime.connectNative("com.robstout.tokenomics")` succeeds = app's bridge manifest is installed = app is installed (or was). On successful connect, store `lastConnectAt` in `chrome.storage.local`. "Detected" = successful connect within last 24 h.
- `tokenomics://` deep link in the popup wizard: app handles → app is *running*; fails → app may or may not be installed (we can't tell from JS), so fall back to the trytokenomics.com download link.

### 5.5.4 Tests

- Clean Mac, install Tokenomics first → onboarding offers extension install, both Safari toggle and Chrome Web Store flow end with "connected" state in app Settings.
- Clean Mac, install extension first → popup wizard offers app install via `tokenomics://` (fails on clean Mac, so falls back to website link); after app install, both surfaces show paired connected state.
- App installed, extension uninstalled → app Settings shows "Web Companion: not connected — [Install extension]." No alarms, no errors.
- Extension installed, app uninstalled → popup footer shows "Tokenomics: not detected — [Install]." Popup remains fully functional.
- Multiple browsers (Chrome + Edge + Safari) all running the extension → app Settings shows three rows under Web Companion, one per browser, each with its own last-update timestamp.

### 5.5.5 Definition of done

- [ ] First-launch flow on a clean Mac: app + extension paired in <2 minutes with the user clicking through the onboarding offers.
- [ ] First-launch flow from a clean Web Store install: extension popup → app install → return → both connected in <3 minutes.
- [ ] Either surface uninstalled → other surface gracefully degrades, never errors.
- [ ] Settings page in app shows per-browser connection state with last-update timestamps.

---

## 6. Phase 6 — Polish + publish

**Goal:** ship to Chrome Web Store and Microsoft Edge Add-ons. Lawyer review pass. Privacy doc on `trytokenomics.com`. Source-available release.

**Estimated:** Claude ~1h, Rob ~3h (store assets + listing copy + screenshots).

### 6.1 Deliverables

- **Chrome Web Store listing:**
  - Name: per the answer to `web-companion-plan.md` §10 question 1
  - Promo screenshots (5 required, 1280×800): popup with each provider, settings page, in-page Claude widget, light + dark
  - Permissions justification text (under 1000 chars)
  - Source-available link in description
- **Microsoft Edge Add-ons listing:** same `.zip` re-uploaded; their review takes ~2x longer (~5–7 days). Listing copy matches Chrome with `Edge` substituted.
- **Privacy doc:** new page on trytokenomics.com at `/extension-privacy`. Mirror the language of `~/projects/Tokenomics/docs/PRIVACY.md` adapted for the extension.
- **Sideload zip:** attached to the GitHub Release for the corresponding Tokenomics version.
- **Lawyer review:** Agent pass on ToS posture + privacy policy + permissions justification. Block submission until cleared.

### 6.2 Screenshot specs (these are marketing assets, take time)

- Render popup at 2x DPR (800×1120) so screenshots are crisp at 1280×800 cropped.
- Use the same demo data across all four screenshots (consistent narrative).
- Light theme on a `var(--bg-2)` macOS desktop background; dark theme on a dark macOS desktop background. Show the toolbar icon + badge in at least one shot.
- Include one shot of the Tokenomics menu bar app showing the same data with the globe-icon source attribution — this is the "extension + app working together" hero.

### 6.3 Definition of done

- [ ] Listings live on Chrome Web Store and Edge Add-ons.
- [ ] Privacy doc live at `trytokenomics.com/extension-privacy`.
- [ ] GitHub Release includes the sideload zip and updated `Casks/tokenomics.rb` if the Mac side bumped a version.
- [ ] Tokenomics changelog entry mentions the web companion.

---

## 7. Phase 7 (deferred) — Firefox

Mozilla AMO listing. wxt produces the build for free. Costs only the AMO submission process (~1 week review). No code changes from Phase 6 baseline. Ship after a quarter of stability on Chrome + Safari + Edge.

---

## 8. Windows runway (when Tokenomics ships on Windows)

Reference: `web-companion-plan.md` §6.5.

The extension does not change. The Windows desktop app brings its own native bridge. Order of operations when Windows is greenlit:

### 8.1 Bridge — `TokenomicsBridge.exe`

- New repo target: `TokenomicsBridge.Windows/` (separate from the Mac Swift target). Language: **C# / .NET 8**, single-file deploy via `dotnet publish -c Release --self-contained false /p:PublishSingleFile=true`. Authenticode-signed.
- Same input as the Mac bridge (4-byte length + JSON frames on stdin).
- Validates against `bridge-schema.json` (same file, copied into the build output).
- Writes to two sinks:
  - **Named pipe** `\\.\pipe\TokenomicsWebCompanion` for live nudges (the desktop app keeps a server end open).
  - **JSON file** at `%LOCALAPPDATA%\Tokenomics\webCompanionSnapshot.json` for cold-start reads.
- Manifest install: registry keys per browser
  - Chrome — `HKEY_CURRENT_USER\Software\Google\Chrome\NativeMessagingHosts\com.robstout.tokenomics`
  - Edge — `HKEY_CURRENT_USER\Software\Microsoft\Edge\NativeMessagingHosts\com.robstout.tokenomics`
  - Firefox — `HKEY_CURRENT_USER\Software\Mozilla\NativeMessagingHosts\com.robstout.tokenomics`

### 8.2 Desktop app — Tauri (recommended) or WinUI 3

Recommend **Tauri**:
- Reuses `tokens.css`, the popup HTML/CSS, and the TS schema verbatim. Zero design-system port cost.
- Native Windows tray support via `tauri-plugin-system-tray`.
- Smaller binary than Electron, signed with the same Authenticode cert as the bridge.

Alternative: WinUI 3 if the visual fidelity story drives Rob to want native XAML. More code, more port effort, no benefit unless we want native Win11 mica/acrylic chrome. Start with Tauri; fall back if Tauri proves limiting.

### 8.3 Sequence

1. Bridge first — get the JSON contract flowing into a named pipe with no UI on the receiving end. Validate via `cat snapshot.json | TokenomicsBridge.exe` end-to-end.
2. Tauri tray app, popup view consuming the pipe.
3. Provider parity comes for free — all four web-companion providers light up on day one of the Windows app.
4. CLI providers (Claude Code / Codex / Gemini / Copilot / Cursor) added in Windows v2 — each is a separate workstream, scoped per OS file-system conventions.

---

## 9. Build dependency graph

```
Phase 1 (Foundation)
   │
   ├──→ Phase 2 (Claude)            ◄── critical path; canonical card recipe
   │       │
   │       └──→ Phase 3 (ChatGPT)   ◄── reuses card; tests fallback path
   │              │
   │              └──→ Phase 4 (Gemini)        ◄── tests `(estimated)` pill
   │                     │
   │                     └──→ Phase 4.5 (MJ)   ◄── flips placeholder
   │                            │
   │                            └──→ Phase 5 (Safari) ◄── visual parity check
   │                                   │
   │                                   └──→ Phase 5.5 (Paired install) ◄── app onboarding + Settings entry
   │                                          │
   │                                          └──→ Phase 6 (Publish)
   │                                          │
   │                                          ├──→ Phase 7 (Firefox, deferred)
   │                                          └──→ Windows runway (separate workstream)
   │
   └─ regression test 53 must pass at every phase boundary
```

Phase 5 (Safari) could in principle parallelize with Phase 4 / 4.5, but I recommend keeping it sequential — the visual parity check is the cleanest at the end when all four providers are stable.

---

## 10. Tracking and quality gates

- **Each phase ends with a tagged commit** on `feat/web-companion`, named `web-companion-phase-N`. Easier to bisect and easier to roll back.
- **Each phase requires** `bash tests/design-system-regression.sh` to pass before merge.
- **Each phase that adds a new provider card** requires a paired light + dark screenshot in the PR description. Reviewer (Rob) compares to `guided-onboarding-mockup.html` window 8 (popover) for chrome consistency.
- **No phase ships without** the empty / stale / logged-out / parser-drift states designed and built — no "happy path only" merges. The states are a feature, not polish.
- **Phase 6 publish** is gated on lawyer-agent review of the privacy posture and ToS rationale. Not a perfunctory step.

---

## 11. References

- `web-companion-plan.md` — strategic and architectural plan (the *what* and *why*)
- `~/projects/trytokenomics-site/design-system.md` — token + component source of truth
- `~/projects/Tokenomics/docs/guided-onboarding-mockup.html` — per-screen visual reference
- `tests/design-system-regression.sh` — MD ↔ HTML parity, extended to cover the extension
- `roadmap.md` Current Focus — Web Companion section
