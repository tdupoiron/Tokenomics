# Tokenomics Web Companion

Chrome (MV3) extension that reads Claude.ai usage from your signed-in
browser session and renders it in a popup mirroring the Tokenomics
menu bar widget.

Phase 1 ships Claude only. OpenAI, Google AI, GitHub Copilot, and
Cursor tabs link to the Tokenomics Mac app; Midjourney is "Coming."

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

## Verify the Claude.ai reader

1. Sign in to <https://claude.ai> in this Chrome
2. Click the Tokenomics toolbar icon to open the popup
3. On install (or within 5 min) the popup replaces its sign-in prompt
   with your live 5-hour and 7-day utilization
4. The toolbar icon shows your 5-hour utilization as a badge (e.g. `36%`)

### Debug

<chrome://extensions> → Tokenomics → click **service worker**:

- **Console** — boot logs, poll results, error traces
- **Application** → **Local Storage** → `chrome-extension://…` — inspect
  `claudeSnapshot`, `claudeAuth`, `claudeOrgId`, `claudeBackoff`,
  `selectedTab`, `pinnedProvider`

Force a fresh poll from the SW console:

```js
chrome.runtime.sendMessage({ kind: 'REFRESH_REQUESTED' })
```

## Architecture

```
src/
├── background.ts      MV3 service worker; chrome.alarms 5-min poll;
│                      backoff (5→10→20→40→60 min cap); badge updates
├── claude.ts          /api/organizations + /api/organizations/{id}/usage
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

No telemetry, no analytics, no remote reporting. The only network
requests the extension makes are to `https://claude.ai`, authenticated
by your existing session cookie. Tokens are never extracted.

Manifest permissions:

- `storage` — persisting tab selection, pin state, snapshot, org id
- `alarms` — 5-minute periodic poll
- `host_permissions: ["https://claude.ai/*"]` — usage endpoints only

No `<all_urls>`, no `chrome.cookies`, no `chrome.tabs`.

## Phase 1 limitations

- Claude consumer (claude.ai) is the only live reader. ChatGPT,
  Gemini consumer, and Midjourney readers land in Phase 1.5.
- No native messaging bridge to the Mac app — Phase 2.
- Chrome only. Safari port lands in Phase 3.
- Plan label hardcoded to "Pro." Derived plan detection lands when
  the `/organizations` settings shape is mapped.
- Toolbar badge collapses to Claude's utilization in Phase 1 because
  it's the only live provider. Smart/pin selection still persists via
  the DisplayModeMenu and will route the badge correctly when more
  readers ship.
