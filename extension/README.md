# Tokenomics Web Companion

Chrome (MV3) extension that surfaces AI usage in a popup mirroring the
Tokenomics menu bar widget.

Phase 1.5 + 4.5 ships three providers:

- **Claude** — real usage via `claude.ai/api/organizations/{id}/usage`,
  cookie auth, polled every 5 min.
- **ChatGPT (OpenAI tab)** — local counter. OpenAI doesn't expose a
  server-side usage endpoint to the web client (we verified — zero
  matching network requests), so a content script on `chatgpt.com`
  observes outbound `POST /backend-api/conversation` calls and counts
  locally against the published quota for the user's plan. Plan is
  auto-detected via `/backend-api/me` with a manual override. The
  popup shows an `estimated` indicator next to the plan badge to keep
  the framing honest.
- **Midjourney** — real usage via `www.midjourney.com/api/app/billing/balance`,
  cookie auth, polled every 10 min. Shows Fast Hours (primary window)
  and GPU Minutes (secondary window, when the plan meters them). Plan
  label (Standard / Pro / Mega) shown in the Header's PlanBadge.
  **Endpoint shape is unverified** — the field names were inferred from
  the plan doc; the parser logs every raw response to the SW console so
  the first real user can confirm or correct the mapping.

Google AI, GitHub Copilot, and Cursor tabs link to the Tokenomics
Mac app.

## Develop

```sh
cd extension
npm install
npm run build       # bundle to extension/dist/
npm run watch       # rebuild on save
npm run typecheck   # tsc --noEmit
```

## Load in Chrome (dev mode)

1. `npm run build`
2. Open <chrome://extensions>
3. Toggle **Developer mode** on (top right)
4. Click **Load unpacked**
5. Select `extension/dist/`

The Tokenomics icon appears in the toolbar. Click it to open the popup.

## Verify the readers

**Claude:** sign in to <https://claude.ai> in this Chrome, open the
popup. Within 5 min the Claude tab shows your 5-hour + 7-day
utilization. The toolbar badge shows the highest utilization across
signed-in providers (or your pinned provider if set).

**ChatGPT:** sign in to <https://chatgpt.com> and send any message.
The content script counts the request as you chat. Open the popup,
switch to the OpenAI tab — you should see `1 of 10 messages · resets
in 5h 0m` (Free plan), with an `estimated` indicator next to the
plan badge.

**Midjourney:** sign in to <https://www.midjourney.com/app>. Within
10 min the Midjourney tab shows your Fast Hours and GPU Minutes usage.
Check the SW console for the raw `midjourney raw billing response`
log line — it prints on every successful poll so you can confirm the
field names match the real API. If the numbers look wrong, compare
against the Billing page in the MJ web app.

### Debug

<chrome://extensions> → Tokenomics → click **service worker**:

- **Console** — boot logs, Claude poll results, ChatGPT plan detection,
  per-message log lines (`chatgpt message observed (model=...)`)
- **Application** → **Local Storage** → `chrome-extension://…` —
  inspect: `claudeSnapshot`, `claudeAuth`, `claudeOrgId`, `claudeBackoff`,
  `chatgptSnapshot`, `chatgptEvents` (the raw message log),
  `chatgptPlanAuto`, `chatgptPlanOverride`,
  `midjourneySnapshot`, `midjourneyAuth`, `midjourneyBackoff`,
  `selectedTab`, `pinnedProvider`

Force a fresh poll from the SW console:

```js
chrome.runtime.sendMessage({ kind: 'REFRESH_REQUESTED' })
```

## Architecture

```
src/
├── background.ts      MV3 service worker; Claude 5-min poll with
│                      backoff (5→10→20→40→60 min cap); Midjourney
│                      10-min poll with same backoff; ChatGPT
│                      message handler + 24h plan re-detect; badge
├── claude.ts          /api/organizations + /api/organizations/{id}/usage
├── midjourney.ts      /api/app/billing/balance — Fast Hours + GPU
│                      Minutes; plan label from response field
├── chatgpt.ts         /backend-api/me plan detect + counter math
│                      (no server-side usage endpoint exists)
├── content/
│   └── chatgpt-watch.ts   document_start content script; injects a
│                          MAIN-world fetch monkey-patch that emits a
│                          CHATGPT_MESSAGE event per /backend-api/conversation POST
├── snapshot.ts        ProviderUsageSnapshot types + pace / reset helpers
│                      (mirrors Tokenomics/Models/Provider.swift)
├── storage.ts         browser.storage.local accessors
├── messages.ts        popup ↔ SW message protocol
├── types.ts           ProviderId enum + tab metadata
└── popup/             Preact + TSX popup
    ├── popup.tsx      assembly + storage.onChanged subscription
    ├── popup.css      design-system tokens, widget palette
    ├── tokens.css     :root + [data-theme="dark"] (sourced from
    │                  ~/projects/trytokenomics-site/design-system.md)
    └── components/    Header, PlanBadge, ProviderTabBar, UsageBar,
                       SyncFooter, DisplayModeMenu, EmptyState, icons
```

## Privacy

No telemetry, no analytics, no remote reporting. All Claude and
ChatGPT data stays on your machine — the extension's only network
calls are to `claude.ai` (usage endpoint) and `chatgpt.com`
(`/backend-api/me` for plan detection, plus passive observation of
the chat tab's own requests via a content script). Cookies aren't
read; tokens aren't extracted.

Manifest permissions:

- `storage` — persisting tab selection, pin state, snapshots, event log
- `alarms` — periodic Claude poll + daily ChatGPT plan re-detect
- `host_permissions: ["https://claude.ai/*", "https://chatgpt.com/*", "https://www.midjourney.com/*"]`
  — limited to the three providers we read
- `content_scripts` on `chatgpt.com/*` — observes the page's own
  `/backend-api/conversation` calls (does not initiate them)

No `<all_urls>`, no `chrome.cookies`, no `chrome.tabs`, no `scripting`.

## Phase 1.5 + 4.5 limitations

- ChatGPT counter is local-only and `estimated`: it counts what you
  send from THIS browser. Messages sent from your phone, another
  browser, or another machine don't count. This matches every other
  shipping ChatGPT tracker — there is no server-side endpoint to
  read accurate numbers from.
- ChatGPT quota table reflects May 2026 OpenAI defaults (Free
  10/5h GPT-5.5, Plus 160/3h, Pro effectively uncapped). These
  shift quarterly.
- **Midjourney endpoint shape is unverified.** The parser maps
  hypothesised field names from the plan doc (`fast_time_remaining_min`,
  `fast_time_total_min`, `gpu_minutes_used`, `gpu_minutes_included`,
  `plan`, `cycle_resets_at`). Every successful poll logs the raw JSON
  to the SW console so Rob can confirm or correct the mapping against
  a real session. If numbers are wrong, compare the SW console output
  to the MJ Billing page and update `midjourney.ts` accordingly.
- Gemini consumer reader is deferred.
- No native messaging bridge to the Mac app — Phase 2.
- Chrome only. Safari port lands in a later phase.
- Claude plan label hardcoded to "Pro"; ChatGPT plan auto-detected
  from `/backend-api/me`, falling back to the user's manual choice;
  Midjourney plan from the `plan` field in the billing response.
