# Tokenomics Web Companion — Plan

**Status:** Draft (2026-05-03)
**Branch target:** new branch `feat/web-companion` off `main`
**Scope:** Chrome (MV3) + Safari Web Extension that read consumer-tier usage from the Claude, ChatGPT, Gemini, and Midjourney web apps and pipe it into the Tokenomics menu bar app. **After this ships, every provider Tokenomics supports has a working data path** — closing the last consumer-tier gap in the product.

---

## 1. Problem we're actually solving

The consumer tiers don't expose a stable public API:

- **Claude free / Pro / Max** — no public usage endpoint. Anthropic's token policy blocks proxying.
- **ChatGPT free / Plus / Pro** — no public usage endpoint. The web app polls an internal one.
- **Gemini free / AI Pro / AI Ultra** — no public usage endpoint at all. Even the web app doesn't show a clean number.
- **Midjourney** — no public API at all. Fast Hours / Relax Hours / GPU Minutes only visible inside the web app.

Right now Tokenomics either skips these tiers or asks the user to paste an API key (which doesn't reflect the *consumer* plan they actually pay for). A signed-in browser session already has every credential, cookie, and entitlement we'd need — we just can't reach it from a sandboxed Mac app. **A browser extension is the only legitimate bridge.**

### Coverage after this ships

| Provider | Pre-extension data path | Post-extension data path |
|---|---|---|
| Claude Code CLI | `~/.claude/` (kept) | `~/.claude/` |
| Claude consumer (free / Pro / Max) | **none** | **web extension** |
| Codex CLI | `~/.codex/` (kept) | `~/.codex/` |
| ChatGPT consumer (free / Plus / Pro) | **none** | **web extension** |
| DALL-E / Sora | API key only | **web extension** (shares OpenAI billing pool with ChatGPT) |
| Gemini CLI | `~/.gemini/` (kept) | `~/.gemini/` |
| Gemini Apps consumer | **none** | **web extension** |
| Nano Banana 2 / Veo | API key only | **web extension** (shares Google AI credits with Gemini) |
| GitHub Copilot | `gh` CLI (kept) | `gh` CLI |
| Cursor | local SQLite (kept) | local SQLite |
| ElevenLabs | API key (kept) | API key |
| Runway | API key (kept) | API key |
| Stability AI | API key (kept) | API key |
| **Midjourney** | **none** (placeholder) | **web extension — graduates from placeholder** |
| Suno / Udio | none (placeholder) | none (waiting on auth-stable web apps) |

After Mac extensions ship, **the only remaining placeholders are Suno and Udio**, both gated on external readiness — every Tokenomics provider has a working source.

This is also a *privacy posture* play. The team-tier roadmap (`roadmap.md` Phase 2) introduces an "org proxy" path for enterprises. The web companion gives the *individual* tier the same coverage *without* a proxy — keeping the "stays on your Mac" promise intact for free-forever users.

---

## 2. State of the art (May 2026)

I audited the working extensions in the wild before designing this.

### 2.1 Claude — solved problem, multiple working extensions

The canonical pattern (used by `sshnox/Claude-Usage-Tracker`, `lugia19/Claude-Usage-Extension`, the Chrome Web Store "Claude Usage Tracker"):

```
1. GET https://claude.ai/api/organizations         → discover org_id (cache 24h)
2. GET https://claude.ai/api/organizations/{id}/usage
   → { five_hour: { utilization, resets_at },
       seven_day: { utilization, resets_at },
       seven_day_opus: { utilization, resets_at } }
```

Session cookie rides along automatically — **no token extraction, no API key**.

`lugia19` supplements polling with the live SSE `message_limit` stream during chat for unrounded utilization. That's the highest-fidelity approach currently shipping.

Permissions needed are minimal: `storage`, `host_permissions: ["https://claude.ai/*"]`. No `<all_urls>`, no `cookies`, no `tabs`.

### 2.2 ChatGPT — partially solved, two competing approaches

**Approach A — Internal endpoint poll (best):**
The OpenAI Codex CLI calls `GET https://chatgpt.com/backend-api/wham/usage` every 60s (issue [openai/codex#10869](https://github.com/openai/codex/issues/10869)). Same auth flow as the web app — session cookie rides along. The endpoint is what `ChatWidget::prefetch_rate_limits` polls in the Codex source. No public extension uses this approach yet.

**Approach B — Local counter (what shipping extensions do):**
ChatGPT Usage Limit Tracker, Chatterclock, ChatGPT Toolbox all observe `POST /backend-api/conversation` calls, attribute to the active model, count locally against published quota tables. Drawbacks: drifts from reality (model-routing on ChatGPT free isn't observable), can't see the rolling-window reset, breaks when ChatGPT changes the request shape.

**We do A primarily, B as fallback** — see §4.

### 2.3 Gemini — unsolved

Nothing public works. Gemini's web app uses obfuscated `batchexecute` RPCs (`BardChatUiServer`) where the response payloads are `[[1,...]]`-style packed arrays without a stable usage field. The web app itself doesn't surface a quota counter. **The honest answer is: estimated counter, not a real reading.** See §4.3 for the design.

### 2.4 Midjourney — solvable via web, not Discord

Midjourney has been pushing users off Discord and onto `midjourney.com/app` for over a year. The web app exposes Fast Hours, Relax Hours, and GPU Minutes by polling `/api/app/billing/balance` (and adjacent endpoints) with the user's session cookie — same pattern as Claude.

**Why not Discord:** the Midjourney bot's `/info` command returns Fast Time Remaining, but a tracker would have to either (a) run an invited bot the user explicitly relays output to — only sees what it's told; (b) read the user's Discord account via "self-bot" / token scraping — explicit ToS violation, instant Discord-account ban; or (c) use Discord's official OAuth — bot can't read other bots' DM content with the user. The web path is strictly safer, passive, and stable.

No public extension currently tracks Midjourney usage. We'd be the first.

### 2.5 Cross-browser packaging

Both Chrome and Safari now use the WebExtensions API surface. `wxt.dev` and Plasmo both ship one TS codebase that builds Chrome MV3 + Safari Web Extension targets. **Decision:** use **wxt** — smaller, no runtime cost, mature MV3 service-worker handling, generates the Xcode-friendly Safari project skeleton.

### 2.6 Native bridge

| Path | Chrome | Safari |
|---|---|---|
| **Native Messaging Host** (stdio + 32-bit length-prefixed JSON) | ✅ canonical | ⚠️ allowed but Apple-discouraged |
| **App Group `UserDefaults`** | ❌ | ✅ canonical (extension is bundled in the .app) |
| **File-watched JSON drop** (`~/Library/Application Support/Tokenomics/web-bridge/*.json`) | ✅ fallback | ✅ fallback |

**Decision:** Chrome → Native Messaging Host. Safari → App Group UserDefaults. Both write the *same* `ProviderUsageSnapshot` shape (already used by `WidgetDataStore.swift`), so Tokenomics consumes one schema regardless of source.

---

## 3. What we do beyond the state of the art

Not just porting existing tracker patterns — these are real wins over what's shipping:

1. **Multi-provider in one extension.** Every existing tracker is single-provider. Ours covers Claude + ChatGPT + Gemini + Midjourney in one install. Lower friction → more adoption → more bottom-up funnel into Tokenomics proper.

2. **MAIN-world fetch/XHR patching for ChatGPT.** MV3 blocks reading response *bodies* via `webRequest`. But content scripts injected into the page's MAIN world via `chrome.scripting.executeScript({ world: 'MAIN' })` can monkey-patch `window.fetch` and `XMLHttpRequest` and read responses *before* they reach the React app. This unlocks the rich `/backend-api/wham/usage` body **and** the `x-ratelimit-*` headers on conversation calls. No public ChatGPT tracker does this — they all settled for the local counter because they didn't realize MAIN-world script injection sidesteps the body-reading restriction.

3. **SSE + REST together for Claude.** REST poll for the stable baseline (every 5 min when tab is visible, every 30 min when hidden); SSE listener for unrounded real-time updates while the user is actually chatting. Combining both gives sub-second freshness during active sessions and zero traffic when idle.

4. **First working Gemini tracker.** Honest "estimated" framing, model-aware (Pro vs Flash vs Ultra), 24h rolling window matching Google's policy table. Better than the current state of *nothing*.

4a. **First working Midjourney tracker via web (anywhere).** No public extension reads MJ usage today. We graduate Midjourney from a Tokenomics placeholder to a fully tracked provider — Fast Hours, Relax Hours, GPU Minutes, billing-cycle reset.

5. **Quiet polling.** Only poll when (a) the relevant tab is visible, or (b) Tokenomics asks for an update via the bridge. Avoids the "extension makes a network call every 60s while you're asleep" pattern that gets extensions delisted.

6. **Schema-versioned with fallback.** Each provider declares a parser version. If a response shape changes, the parser falls through to a degraded counter mode and reports `parserDrift: true` — Tokenomics surfaces a yellow "needs update" pill instead of going silent.

7. **Same privacy posture as the app.** Source-available, no remote sync, no analytics, no account, no `<all_urls>`. The extension is a permission-minimal companion, not a data harvester. This is a *marketing* asset — nobody else can credibly say this.

8. **Same design system as the app.** Hedvig serif headline, DM Sans body, brand palette, tokenized in CSS variables that mirror `Tokens.swift`. The extension popup looks like a Tokenomics surface, not a generic tracker. (See §5.)

---

## 4. Per-provider implementation

### 4.1 Claude

**Polling (background service worker):**
```
fetchOrgId()                      // cached 24h
fetchUsage(orgId)                 // every 5 min visible / 30 min hidden
→ ProviderUsageSnapshot {
    provider: .claude,
    shortWindow: { utilization, resetsAt },         // five_hour
    longWindow: { utilization, resetsAt },          // seven_day
    extras: { opusSevenDay: { utilization, resetsAt } },  // optional
    source: .webExtension,
    capturedAt: now,
  }
→ writeToBridge()
```

**Realtime SSE (content script in MAIN world, only on /chat/* routes):**
- Listen for `message_limit` events on the existing SSE stream the page already opens.
- Override the polled value in the bridge when an event arrives.
- Disconnects automatically when the tab closes.

### 4.2 ChatGPT

**Primary path — endpoint poll (background SW):**
```
fetch('https://chatgpt.com/backend-api/wham/usage', { credentials: 'include' })
→ parse JSON, map to ProviderUsageSnapshot
```

**Augmentation path — MAIN-world fetch patch (content script):**
```js
// Injected into MAIN world via chrome.scripting.executeScript
const orig = window.fetch;
window.fetch = async (...args) => {
  const res = await orig(...args);
  if (args[0].includes('/backend-api/conversation')) {
    const limit   = res.headers.get('x-ratelimit-limit-requests');
    const remain  = res.headers.get('x-ratelimit-remaining-requests');
    const reset   = res.headers.get('x-ratelimit-reset-requests');
    postMessage({ kind: 'chatgpt-headers', limit, remain, reset });
  }
  if (args[0].includes('/backend-api/wham/usage')) {
    res.clone().json().then(j => postMessage({ kind: 'chatgpt-wham', body: j }));
  }
  return res;
};
```

**Fallback — local counter** (when both above fail): observe `POST /backend-api/conversation`, attribute to model from request body, count against published quota table. Snapshot is flagged `estimated: true`.

### 4.3 Gemini

No clean endpoint exists. Honest design:

- Content script observes `POST` to `BardChatUiServer.GenerateChatResponse` (the batchexecute RPC).
- Detect model from the URL hash (`/app?model=gemini-2.5-pro`) or active model selector DOM attribute.
- Increment a local 24h-rolling counter per model.
- Map to published quota table (Free: ~10 Pro msgs/day, AI Pro: 100, AI Ultra: 500 — verify against current Google docs at build time).
- Surface as `ProviderUsageSnapshot` with `estimated: true` and a tooltip that explains why.

This is a degraded reading, but it's the first one that exists at all, and it's clearly labeled. Acceptable for a free-tier user who has *zero* visibility today.

### 4.4 Midjourney

**Polling (background service worker):**
```
fetch('https://www.midjourney.com/api/app/billing/balance', { credentials: 'include' })
→ {
    fast_time_remaining_min: 487,
    fast_time_total_min: 900,
    relax_time_used_min: 1240,           // unbounded for Standard / Pro / Mega; cap surfaced as ∞
    gpu_minutes_used: 73.4,
    gpu_minutes_included: 100,
    plan: "standard" | "pro" | "mega",
    cycle_resets_at: "2026-05-29T00:00:00Z",
  }
→ ProviderUsageSnapshot {
    provider: .midjourney,
    shortWindow: { utilization: fastUsedPct, resetsAt: cycle_resets_at },     // Fast Hours
    longWindow:  { utilization: gpuPct,     resetsAt: cycle_resets_at },      // GPU minutes (if metered)
    extras: { relaxMinutesUsed, plan },
    estimated: false,
    capturedAt: now,
  }
```

- Poll cadence: every 10 min when `midjourney.com/app` tab is visible, every 60 min when hidden, on-demand when Tokenomics asks.
- The exact endpoint shape needs verification at build time (MJ doesn't publish API docs); content script captures the live request shape from the user's first session and saves it as the parser baseline.
- `host_permissions: ["https://www.midjourney.com/*"]` — same minimal posture as the other providers.
- No DOM scraping. The web app polls the same endpoint we'd be polling — the extension just observes the same response.

---

## 5. UI design — extension popup + in-page widget

Three surfaces, all following `~/projects/trytokenomics-site/design-system.md` and the per-screen feel of `docs/guided-onboarding-mockup.html`:

1. **Toolbar popup** — fully functional usage surface. *Peer of the menu bar app, not a launcher.*
2. **Toolbar icon + badge** — passive at-a-glance signal in the browser chrome.
3. **In-page widget (Claude only, optional)** — embedded under the chat composer on `claude.ai/chat/*`.

### 5.1 CSS variables (drop-in mirror of Tokens.swift)

`web-companion/src/styles/tokens.css` — verbatim copy of the `:root` block from `design-system.md` §"Quick start: CSS variables", including the `[data-theme="dark"]` overrides. **Source of truth:** the MD file. The CSS block is auto-checked against it by `tests/design-system-regression.sh` (extend the existing 51-check script with a 52nd check for the extension's tokens.css). This guarantees the extension cannot drift from the app or the marketing site.

### 5.2 Toolbar popup — design intent

**Yes, the popup is a fully functional usage surface in its own right.** This is the dominant user expectation — every shipping tracker on the Web Store works this way, and many users will install the extension *before* they install the desktop app (or run it on a machine without Tokenomics). The popup must stand alone.

What "fully functional" means concretely:

- All providers visible with rings + utilization numbers + reset times — same information density as the menu bar popover.
- Per-provider expand-to-detail (tap a row → drawer with extras: Opus 7-day, GPU minutes, model breakdown for ChatGPT, etc.).
- Per-provider auth state — "Logged in" / "Logged out" / "Stale (5m ago)" / "Endpoint moved (needs update)".
- Settings access (poll cadence, in-page widget toggle, theme override).
- "Open Tokenomics" is **secondary**, not primary — the popup is *not* a launcher.
- Works identically when the desktop app is absent (badge: "Tokenomics not detected — [Install]").

### 5.3 Toolbar popup — layout

Single dimension: **400×560**. **Mirrors the Mac app's `PopoverView.swift` shape, not a separate invented design.** The TS/CSS port reuses every component of the Mac popover, line-for-line: header, segmented tabs, per-provider body, sync footer.

```
┌────────────────────────────────────────┐
│  Tokenomics              [Max]      ↗  │  ← header: app name + PlanBadgeView
│                                        │     + ShareLink (NOT an aggregate
│                                        │     "● N connected" pill)
│                                        │
│  ┌──────┬──────┬──────┬──────┬──────┐  │  ← ProviderTabView: segmented tabs
│  │Claude│GPT-4 │Gemini│ MJ   │ CLI  │  │     icon-only at 4+ providers
│  └──────┴──────┴──────┴──────┴──────┘  │
│                                        │
│  5-Hour Window                    36%  │  ← per-provider body: shows ONE
│  ────●─────────────────────────────    │     provider at a time (the one
│                                        │     whose tab is selected)
│  7-Day Window                     72%  │
│  ────────────●─────────────────────    │  ← UsageBarView: track-fill bar
│                                        │     + single pace-circle marker
│  Resets Tue at 6:00 PM                 │     (NOT a 10-dot row)
│                                        │
│                                        │
│  ────────────────────────────────────  │
│  Updated 2m ago  ⟳  ⚙  ↗               │  ← SyncFooterView: last-sync,
└────────────────────────────────────────┘     refresh, display mode, settings,
                                                share
```

**The popup is a 1:1 visual port of `PopoverView.swift`.** Components to mirror exactly:

| Mac app source | Port target | Notes |
|---|---|---|
| `Views/PopoverView.swift` | `popup/Popover.tsx` | Overall structure, header + tab + body + footer pattern |
| `Views/ProviderTabView.swift` | `popup/ProviderTabView.tsx` | Segmented tabs. Collapses to icon-only at 4+ visible providers. |
| `Views/UsageBarView.swift` | `popup/UsageBar.tsx` | The canonical usage display: 1px-tall track filled to utilization%, with a single circle marker indicating the user's *pace* through the window. No 10-dot row. No utilization-based color shifts — alerting comes from the user's per-provider notification thresholds (configured in app Settings), not implicit color rules. |
| `Views/PlanBadgeView.swift` | `popup/PlanBadge.tsx` | Small rounded pill: "Pro" / "Max" / "Free" / etc. Header-only. |
| `Views/SyncFooterView.swift` | `popup/SyncFooter.tsx` | Last-synced timestamp, refresh button, display mode picker (smart vs pinned), settings gear, share button. |

**Anti-patterns (do NOT introduce):**
- ❌ Stacked provider cards visible simultaneously — the Mac popover shows ONE provider at a time via tabs.
- ❌ Aggregate "● N connected" header pill — the Mac header has `PlanBadgeView` (per-provider plan label) + ShareLink only.
- ❌ Pace dots (10-dot row, threshold tints) — use `UsageBarView`'s bar + pace circle.
- ❌ Per-card expansion drawers — there's no "expand for more" on the Mac popover. The tab IS the surface for one provider's full data.

**Empty / error states** (rendered inside the selected tab's body, not as per-card states):
- *Logged out at provider*: "Sign in to claude.ai to start tracking" with inline link.
- *Stale (>30 min)*: opacity reduced to 50%, "Updated 47m ago" in `var(--warning)`.
- *Parser drift*: "Endpoint moved — extension update available" in `var(--danger)`, links to extension update flow.
- *No active session*: "Visit claude.ai to start tracking" — quiet, non-blocking.

**Light + dark:** resolved by `prefers-color-scheme: dark` flipping `data-theme="dark"` on `<html>`. Both modes ship from day one — no light-only beta. Same dual-theme expectation as the desktop app.

### 5.4 Toolbar icon + badge — passive at-a-glance signal

Even before the popup opens, the browser toolbar icon is itself a usage surface — analogous to the menu bar rings on Mac. The Mac app's `DisplayModeMenuView` lets users pick which provider's utilization drives the menu bar ring (smart-of-N or pinned); the extension's toolbar badge follows the same pattern for the browser toolbar.

**Status: Q2 still open.** Phase 1 ships **without a badge** (default Tokenomics mark only). Three options under consideration; pick before Phase 6 publish:

- **(a) Highest utilization as a number** — e.g., `93%` if any provider exceeds 50%. Honest at-a-glance signal but adds visual noise.
- **(b) Static dot when threshold crossed** — single brand-accent dot when ≥1 provider exceeds the user's configured notification threshold. Honors the "alerts come from notifications, not colors" rule. **Recommended.**
- **(c) No badge** — Phase 1 default; revisit only if users ask.

In all three: **no utilization-based color shifts**. The badge (when present) is a quiet signal, not a stoplight. Per-provider thresholds (configured in app Settings) drive alerting, not implicit color rules in the badge itself.

**When the badge ships, pick mode the same way the Mac menu bar does:**
- Smart mode → reflect highest utilization across visible providers (matches `worstOfNUsage()`).
- Pinned mode → reflect the pinned provider's utilization only.
- Stored in `chrome.storage.local` as `pinnedProvider: ProviderId | null` (radio behaviour — null = smart). Mirror of Mac's `SettingsService.pinnedProviders`. Phase 2's NMH bridge may eventually sync these two so the user has one consistent at-a-glance preference across menu bar + toolbar.

**Tooltip on hover** (always present, regardless of badge state): "Tokenomics — Claude 72%, ChatGPT 12%, Gemini 2% (est), MJ 73%".

### 5.5 In-page widget — DROPPED

**Status: removed from scope per open Q7 resolution.**

Original design proposed a single-row utilization widget injected below the chat composer on `claude.ai/chat/*` via a Shadow DOM. Dropped because: (a) it's a new UI surface inside someone else's product with no analogue in the Mac app, (b) it requires `host_permissions` we'd otherwise not need, (c) the popup is already a complete at-a-glance surface for users who want live numbers.

Reconsider only if a user explicitly asks for it — defer to Phase 7+ if so.

### 5.6 Settings page — accessible from popup footer

Opens in a full browser tab via `chrome.runtime.openOptionsPage()` (per open Q6 — multi-step is too cramped for the popup's 400px width).

**Mirrors `Views/AIConnectionsView.swift`'s structure, not an invented page.** The Mac app already groups providers by category (Coding Tools / Platforms / Image Generation / etc.) with show/hide toggles. The extension's options page ports that exact grouping pattern, with a single new "Browser Companion" group added.

| Group | Source | Contents |
|---|---|---|
| **Browser Companion** *(new)* | — | Per-browser connection state row(s) — Chrome / Edge / Safari each show "Connected · last update 2m ago" or "Not running." Mirror of the Mac app's `WebCompanionSettingsView` (planned for Phase 5.5, see build spec). |
| **AI assistants you chat with** | Mirrors `AIConnectionsView`'s "Platforms" group | Per-provider on/off toggle, per-provider poll cadence override (default 5 min). |
| **AI you code with** | Mirrors `AIConnectionsView`'s "Coding Tools" group | Read-only display of CLI providers tracked by the Mac app (extension doesn't track these). Shows source-attribution glyph (`terminal` for CLI, `globe` for web companion, `key` for API key — see open Q3). |
| **Privacy** | New page (no Mac analogue at section level) | Plain-text confirmation that data never leaves the device. Link to GitHub source. |
| **About** | Mirrors `AboutView.swift` pattern | Extension version, link to changelog, link to `trytokenomics.com`. |

**Anti-pattern:** do NOT introduce a separate "Providers / Privacy / About" section taxonomy that diverges from `AIConnectionsView`. The Mac app's grouping is the source of truth — the extension extends it, doesn't replace it.

### 5.7 Onboarding (extension first-run)

Per open Q6 resolution: **opens in a new browser tab via `chrome.runtime.openOptionsPage()` on extension install**, not as a multi-step popup wizard (the 400×560 popup is too cramped for full onboarding chrome).

**Mirrors the Mac app's onboarding components, not an invented wizard.** Port these to TS/CSS:

| Mac app component | Port target | Notes |
|---|---|---|
| `Views/Onboarding/WelcomeView.swift` | `options/Welcome.tsx` | Hedvig serif H1 ("Track your AI usage.") + DM Sans lede + tokenPrimaryLg "Get Started" + privacy disclosure. 1:1 visual port. |
| `Views/Onboarding/Components/OnboardingStepper.swift` | `options/OnboardingStepper.tsx` | The 4-segment stepper across the top — same labels, same active/completed/upcoming states. |
| `Views/Onboarding/Components/WindowFooter.swift` | `options/WindowFooter.tsx` | Bottom divider + Back link + primary CTA pattern. |
| `Views/Onboarding/Components/WindowChromePreview.swift` | (preview-only on Mac) | Skip — preview wrapper, not production. |

**Three-step new-tab wizard:**

1. **Welcome** — exact port of `WelcomeView.swift`. The pitch: "Track Claude, ChatGPT, Gemini, and Midjourney from your browser. Stays on your machine — same privacy posture as the menu bar app."
2. **Permissions** — explains why we need `host_permissions` for the four AI domains, no others. Confirm Chrome's permission prompts before requesting.
3. **Connect Tokenomics (optional)** — if Tokenomics is running (`tokenomics://web-companion-installed` deep link succeeds), confirm paired state. If not installed, link to `trytokenomics.com`. **Skippable** — extension works standalone (Phase 1's design intent: the popup is fully functional without the Mac app).

**Anti-pattern:** do not build separate "popup-onboarding" components that look almost-but-not-quite like the Mac onboarding. The visual parity check at the end of Phase 5 explicitly compares popup screens to Mac onboarding screens — invented chrome will fail it.

---

## 6. Native bridge

### 6.1 Schema (one shape, every browser, every OS)

The JSON contract is the only thing that crosses platforms. Native bridges in §6.2–6.4 each emit *exactly* this shape; the desktop apps each read *exactly* this shape. The schema lives in the extension repo as TypeScript types and is the single source of truth — see §6.6 for how we keep all consumers honest.

```json
{
  "schemaVersion": 1,
  "source": "chrome" | "edge" | "firefox" | "safari",
  "capturedAt": "2026-05-03T17:30:00Z",
  "providers": [
    {
      "id": "claude",
      "shortWindow": { "utilization": 0.36, "resetsAt": "2026-05-02T22:00:00Z" },
      "longWindow":  { "utilization": 0.72, "resetsAt": "2026-05-08T04:00:00Z" },
      "extras": { "opusSevenDay": { "utilization": 0.93, "resetsAt": "..." } },
      "estimated": false,
      "parserVersion": 1,
      "parserDrift": false
    },
    { "id": "chatgpt", ... },
    { "id": "gemini",  "estimated": true, ... },
    {
      "id": "midjourney",
      "shortWindow": { "utilization": 0.46, "resetsAt": "2026-05-29T00:00:00Z" },
      "longWindow":  { "utilization": 0.73, "resetsAt": "2026-05-29T00:00:00Z" },
      "extras": { "relaxMinutesUsed": 1240, "plan": "standard" },
      "estimated": false,
      "parserVersion": 1,
      "parserDrift": false
    }
  ]
}
```

Both browsers are first-class on Mac. Safari has ~17% market share — large enough that "Chrome-only" is not an option — and the Safari path is actually *simpler* on Mac because the extension already runs inside the notarized .app. Two paths converge on the same App Group destination:

```
Chrome / Edge / Firefox  ──→  TokenomicsBridge.swift CLI  ──┐
                              (Native Messaging Host,        │
                               separate process per browser) │
                                                             ├──→  App Group UserDefaults
                                                             │     "webCompanionSnapshot"
Safari                   ──→  SafariWebExtensionHandler ─────┘     (group.com.robstout.tokenomics)
                              (in-process inside .app,
                               no bridge binary needed)               │
                                                                      ▼
                                                          WebCompanionService.swift
                                                          (Tokenomics menu bar app)
```

### 6.2 Chrome / Edge / Firefox → Mac (Native Messaging Host)

- New **Swift** CLI binary: `TokenomicsBridge` — added as a target in `project.yml`, signed with the app's Developer ID, notarized through the existing `distribute.sh` pipeline.
- Lives inside the .app bundle at `Tokenomics.app/Contents/Helpers/TokenomicsBridge`. On first launch the main app writes the Native Messaging host manifest to:
  - Chrome: `~/Library/Application Support/Google/Chrome/NativeMessagingHosts/com.robstout.tokenomics.json`
  - Edge: `~/Library/Application Support/Microsoft Edge/NativeMessagingHosts/`
  - Firefox: `~/Library/Application Support/Mozilla/NativeMessagingHosts/`
  Each manifest contains `allowed_origins` for the extension's published ID(s).
- Bridge reads 4-byte-length-prefixed JSON frames on stdin, validates against `bridge-schema.json` (§6.6), writes to App Group UserDefaults. ~150 LOC of Swift.
- **Why Swift, not Rust:** App Group UserDefaults is one line in Swift vs ~30 lines of `objc` FFI in Rust. Rides the existing notarization pipeline with zero new toolchain. Rob can read and modify it. The bridge is plumbing, not value — it doesn't need to be cross-platform; the *schema* does.

### 6.3 Safari → Mac (in-process, no bridge binary)

- Extension is bundled inside `Tokenomics.app` as a Safari Web Extension target. xcodegen `project.yml` gets a new target with the App Group entitlement.
- `SafariWebExtensionHandler.swift` receives messages from JS via `NSExtensionContext` and writes directly to App Group UserDefaults — same key, same schema as the Chrome path.
- No separate process, no Native Messaging Host, no manifest install step. Apple's Safari Web Extension architecture handles all of this.
- This is one of the rare places where Safari's stricter sandbox makes the integration *cleaner* — the extension can't reach a CLI binary, so it doesn't have to.

### 6.4 App-side consumption (Mac)

New service `WebCompanionService.swift`:
- Reads `webCompanionSnapshot` from App Group on a `KVO` / `UserDefaults.didChange` observer.
- Maps each entry to existing `ProviderUsageSnapshot` and merges into the `UsageService`'s provider stream as a *new source priority*: web-companion overrides API-key/CLI sources for Claude / ChatGPT / Gemini when `parserDrift == false && capturedAt < 30 min ago`. Falls back to the existing source otherwise.
- Surfaces source in the popover row as a small icon (globe = web companion, terminal = CLI, key = API key).
- Doesn't care which browser the snapshot came from — the `source` field is informational only.

### 6.5 Windows readiness (future)

When the Windows Tokenomics tray app ships, it brings its own native bridge for Chromium browsers — but the **JSON contract is identical** to the Mac one, so the web extension code does not change.

- **Bridge:** new C# (.NET 8) single-file binary `TokenomicsBridge.exe`, Authenticode-signed. Functionally equivalent to the Swift bridge — reads stdin frames, validates schema, writes to platform sink.
- **Sink:** named pipe `\\.\pipe\TokenomicsWebCompanion` for live nudges, plus a JSON drop at `%LOCALAPPDATA%\Tokenomics\webCompanionSnapshot.json` for cold-start reads. (Windows has no App Group UserDefaults equivalent; named-pipe-plus-file is the idiomatic substitute.)
- **Manifest install paths:** Windows registers Native Messaging hosts via registry keys, not files:
  - Chrome: `HKEY_CURRENT_USER\Software\Google\Chrome\NativeMessagingHosts\com.robstout.tokenomics`
  - Edge: `HKEY_CURRENT_USER\Software\Microsoft\Edge\NativeMessagingHosts\com.robstout.tokenomics`
  - Firefox: `HKEY_CURRENT_USER\Software\Mozilla\NativeMessagingHosts\com.robstout.tokenomics`
  The Windows app installer writes these on first run.
- **Safari does not exist on Windows** — no second path needed.
- **No Tokenomics Mac changes required when Windows ships.** The Windows app is purely a new consumer of the same contract.

### 6.6 Schema enforcement (the only thing that must not drift)

The "two bridges in different languages" worry is real if either bridge re-marshals JSON. We avoid that by making the bridges pure relays plus one schema check.

- TypeScript types in `web-companion/src/shared/snapshot-schema.ts` are the source of truth.
- A CI step runs `ts-json-schema-generator` to emit `bridge-schema.json` from those types.
- Both bridges (Swift now, C# later) validate inbound payloads against `bridge-schema.json` at startup using each language's stdlib JSON-Schema validator. Mismatched `schemaVersion` → reject + log; structural drift → reject + emit a `parserDrift: true` snapshot so the app surfaces "needs update."
- The schema file is checked into the extension repo and copied into both bridge build outputs — *not* hand-translated. Drift is impossible by construction.

---

## 7. Distribution

Chrome and Safari are both first-class — Safari has ~17% market share on Mac, too large to skip. Edge and Firefox come along almost free because they consume the same WebExtensions bundle.

### Chrome (and Edge)
- Web Store listing under `Tokenomics — AI usage at a glance`. ~$5 one-time dev fee already paid.
- Edge takes the **same `.zip`** via the Microsoft Edge Add-ons store (free dev account, manual review). Same code, separate listing.
- Privacy policy page added to `trytokenomics-site` (`/extension-privacy`) — verbatim "no data leaves your machine, no analytics, source-available."
- Sideload zip on GitHub Releases for power users who don't want either store version.

### Safari
- Bundled inside the Tokenomics .app as a Web Extension target. **No App Store submission required** — Safari Web Extensions distribute fine via Developer-ID-signed apps as long as the extension is part of the app bundle. Users enable it from Safari → Settings → Extensions after installing Tokenomics.
- `distribute.sh` already handles notarization; just needs the new target in `project.yml`.
- Safari users get the simplest install of any browser: install Tokenomics, open Safari Settings → Extensions, toggle on. No store visit, no permission prompt theater.

### Firefox (Phase 7, optional)
- Mozilla Add-ons listing. wxt produces the build for free; only cost is a separate AMO submission (Mozilla review, ~1 week). My vote: ship after Chrome + Safari are stable.

### Paired install flow (the app and the extension are better together)

Both surfaces stand alone, but the app *gains* coverage from the extension (Claude/ChatGPT/Gemini/MJ consumer tiers — providers it can't reach on its own), and the extension *gains* a passive surface from the app (menu bar rings, notifications, widgets). The install flow encourages pairing without forcing it.

**Mac, app first (the dominant flow — `brew install --cask tokenomics` or DMG):**

1. User installs Tokenomics.app and runs it. Existing zero-Terminal onboarding completes.
2. **New onboarding step appended:** "Track Claude, ChatGPT, Gemini, and Midjourney in your browser?" — single screen, same chrome as `guided-onboarding-mockup.html` window 8. Two CTAs:
   - **Safari** → "Enable Safari Extension" — opens `SFSafariApplication.showPreferencesForExtension(withIdentifier: "com.robstout.tokenomics.SafariExtension")`. User toggles on. Done. App detects activation via the App Group write and shows green check.
   - **Chrome / Edge / Firefox** → "Open Web Store" — opens the appropriate store page for the extension. Browser handles install. On first run the extension's background SW connects to the Native Messaging Host (already installed by the app); the app sees the connect and marks the connection complete.
3. **Skippable.** "Not now" works — user can re-trigger from `Settings → Web Companion`.

**Mac, extension first (acquisition flow — user finds the extension on the Web Store):**

1. User installs from Chrome Web Store / Edge Add-ons / Mozilla AMO / Safari (the Safari case is rare since Safari users almost always come from the app).
2. Popup first-run wizard (plan §5.7) ends with **"Get the Tokenomics menu bar app"** screen.
   - If `tokenomics://` deep link succeeds → the app is already installed, just opens it.
   - If it fails → link to `trytokenomics.com` for download.
3. After app install + run, the existing app onboarding detects the extension at the Native Messaging connect handshake and shows "Web Companion: connected ✓" instead of asking to install the extension.

**Both installed, surfacing the connection:**

- App `Settings → Connections → Web Companion` shows: "Connected via Chrome (last update 2m ago)" or per-browser breakdown if multiple.
- Extension popup footer shows: "Tokenomics: detected ✓" with subtle dot.
- Neither surface alarms when the partner is missing — both are quietly informative.

**Windows (future, when the Windows tray app ships):**

Same logic, with installer-time integration:
- Windows installer auto-installs `TokenomicsBridge.exe` and registers Native Messaging registry keys for every Chromium browser detected on the system.
- Tray app onboarding has the same "Open Web Store" prompts for Chrome/Edge/Firefox. No Safari path on Windows.

**Why the app benefits from the extension (the strategic point):**

| Without extension | With extension |
|---|---|
| Claude consumer tier: untracked | Tracked, real-time via SSE |
| ChatGPT consumer tier: untracked | Tracked via internal endpoint |
| Gemini consumer tier: untracked | Tracked (estimated) |
| Midjourney: placeholder | Tracked, real billing data |
| DALL-E / Sora: API key only | Tracked under unified OpenAI provider |
| Nano Banana 2 / Veo: API key only | Tracked under unified Google AI provider |

For users on consumer plans without API keys, the extension is what makes Tokenomics a complete picture. The app *can* run without it, but it's only seeing 5 of 9+ trackable providers. The extension closes the gap.

### Repo layout

Two options, recommend **monorepo**:

```
~/projects/Tokenomics/
├── Tokenomics/                       # existing Mac app
├── TokenomicsWidgets/                # existing
├── web-companion/                    # NEW
│   ├── src/
│   │   ├── background/
│   │   │   ├── claude.ts
│   │   │   ├── chatgpt.ts
│   │   │   ├── gemini.ts
│   │   │   ├── midjourney.ts
│   │   │   └── bridge.ts
│   │   ├── content/
│   │   │   ├── claude-sse.ts
│   │   │   ├── chatgpt-fetch-patch.ts
│   │   │   ├── gemini-counter.ts
│   │   │   └── midjourney-observer.ts
│   │   ├── popup/
│   │   │   ├── App.tsx
│   │   │   ├── styles/tokens.css     # mirror of design-system.md :root
│   │   │   └── index.html
│   │   └── shared/
│   │       └── snapshot-schema.ts
│   ├── wxt.config.ts                 # builds chrome + safari targets
│   └── package.json
├── TokenomicsBridge/                 # NEW — Swift CLI native messaging host
│   └── main.swift
└── ...
```

---

## 8. Risks and how we handle them

| Risk | Mitigation |
|---|---|
| Anthropic / OpenAI / Google / Midjourney change internal endpoints | Schema-versioned parsers, automatic fallback to counter mode, `parserDrift: true` surfaces in app as "needs update" pill. CI smoke test hits the endpoints daily and opens an issue on failure. |
| Midjourney via Discord — tempting but wrong | Discord ToS forbid self-bots; bot-relay path can't read passively; user-account-token path is an instant ban. Web path is the only safe approach. We ship the web path and document Discord as explicitly out of scope. |
| ToS questions | We use only authenticated endpoints already called by the user's *own* signed-in browser. Same posture as every other usage tracker on the Web Store today. Privacy policy is explicit. **Not** scraping, **not** automating, **not** redistributing — read-only observation of the user's own session. Have lawyer agent review before public launch. |
| Chrome Web Store review | Permission-minimal manifest passes the standard review. Single-purpose declared as "AI usage tracking." Source-available URL in the listing. |
| User runs extension *without* the Mac app | Popup still works standalone — just shows the data in-extension. Gentle nudge to install Tokenomics. Acquisition surface, not a hard dep. |
| User runs Mac app *without* the extension | Status quo. Web companion is opt-in additive. |
| Privacy concerns from users | "Source-available, no analytics, no remote sync, audit the code yourself" — same line that works for the Mac app. Privacy doc lives next to the existing `docs/PRIVACY.md`. |

---

## 9. Build phasing

Concrete chunks sized for Claude-built / Rob-tested. Time estimates per the `CLAUDE.md` rubric.

### Phase 1 — Foundation (Claude ~2h, Rob ~1h test)
- `wxt` project skeleton in `web-companion/`
- `tokens.css` mirror + regression test (`tests/design-system-regression.sh` extended)
- Snapshot schema TS + matching Swift `Codable` struct
- Empty popup with the design-system shell rendering "No data yet"
- Add target to `project.yml`, run `xcodegen generate`

### Phase 2 — Claude provider end-to-end (Claude ~2h, Rob ~1h test)
- `background/claude.ts` polling org → usage
- `content/claude-sse.ts` SSE listener
- Bridge write path (Chrome native messaging only)
- `TokenomicsBridge` Swift CLI binary
- `WebCompanionService.swift` in app, merges into UsageService
- End-to-end: log into claude.ai, see live utilization in Tokenomics popover

### Phase 3 — ChatGPT (Claude ~2h, Rob ~1h test)
- `background/chatgpt.ts` poll `/wham/usage`
- `content/chatgpt-fetch-patch.ts` MAIN-world patch + headers
- Fallback counter mode
- Phase 3 ships a beta DMG so a few users can pressure-test the wham endpoint shape

### Phase 4 — Gemini estimated (Claude ~1.5h, Rob ~1h test)
- `content/gemini-counter.ts` 24h rolling counter
- Quota tables for Free / AI Pro / AI Ultra
- `estimated: true` plumbing through to popover row

### Phase 4.5 — Midjourney (Claude ~1.5h, Rob ~1h test)
- `background/midjourney.ts` poll `/api/app/billing/balance`
- `content/midjourney-observer.ts` baseline-capture from active session (records first response shape so the parser self-validates)
- `roadmap.md`: Midjourney status flips from **Placeholder** to **Shipped via web companion**
- Provider icon already exists in the asset catalog; no new art needed

### Phase 5 — Safari target (Claude ~1.5h, Rob ~1h test)
- wxt safari target build
- Native handler writes to App Group instead of native messaging
- Add to xcodegen project.yml
- Distribute via existing notarized .app — no new pipeline

### Phase 6 — Polish + publish (Claude ~1h, Rob ~3h: Chrome Web Store listing, screenshots, privacy doc)
- Privacy doc on trytokenomics-site
- Chrome Web Store listing copy + screenshots (use design-system'd popup shots)
- Sideload zip on GitHub Releases
- Lawyer agent review pass on ToS posture

External wait time: Chrome Web Store review (~1–3 days). No Apple review needed (Safari extension ships in the existing notarized .app).

---

## 10. Open questions for Rob

1. **Naming.** Extension product name on the store: `Tokenomics` (matches app), `Tokenomics Web Companion`, or something else?
2. **In-page widget for Claude.** Off by default, or on by default? Existing Claude trackers default to *on* but it puts a UI on someone else's product.
3. **Gemini quota table.** Confirm at build time against current Google docs — the values shift quarterly.
4. **Midjourney plan disambiguation.** Standard / Pro / Mega plans have different Fast Hour caps; we read `plan` from the response, but if MJ omits it we'd need a settings dropdown. Probably fine to defer until a beta tester surfaces it.
5. **Do we want a Firefox target too?** wxt supports it for free; only cost is one more notarization-equivalent process at Mozilla. My vote: yes, ship Phase 7. Firefox users are disproportionately privacy-conscious and overlap with the Tokenomics audience.
6. **Phase 2 (Team Observability) link.** Should the extension surface a "Tokenomics for Teams" pitch when it detects 3+ provider connections, per the conversion-event idea in `roadmap.md`? My vote: not yet — first prove the individual flow works, then layer team upsell in Phase 7+.

---

## Sources & references

- Claude endpoint pattern — `lugia19/Claude-Usage-Extension`, `sshnox/Claude-Usage-Tracker`, Chrome Web Store "Claude Usage Tracker"
- ChatGPT `/wham/usage` — [openai/codex#10869](https://github.com/openai/codex/issues/10869)
- Native Messaging — [developer.chrome.com/docs/extensions/develop/concepts/native-messaging](https://developer.chrome.com/docs/extensions/develop/concepts/native-messaging)
- Safari Web Extension messaging — [Apple developer docs: Messaging a Web Extension's Native App](https://developer.apple.com/documentation/safariservices/safari_web_extensions/messaging_a_web_extension_s_native_app)
- MV3 webRequest constraints — [Chromium MV3 webRequest docs](https://developer.chrome.com/docs/extensions/reference/api/webRequest)
- Design system — `~/projects/trytokenomics-site/design-system.md`
- Per-screen visual reference — `~/projects/Tokenomics/docs/guided-onboarding-mockup.html`
