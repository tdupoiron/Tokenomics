# Tokenomics 2.9.0-beta.2 — Test Checklist

A 4-layer pass to shake out the zero-Terminal onboarding flow before tagging the
beta. Run top-to-bottom; each layer is cumulative.

---

## Layer 1 — Xcode Previews (~5 min, visual-only)

### How to open the preview canvas

1. Open `Tokenomics.xcodeproj` in Xcode.
2. Open any of the files listed below (⌘⇧O → type the file name).
3. Show the canvas: **Editor → Canvas** (⌥⌘↩).
4. Press **Resume** in the canvas toolbar (or ⌥⌘P) to render.
5. Each `#Preview("…")` block becomes a tab at the top of the canvas — click
   between them to flip through states.

### Files with previews

| File | Previews available |
|---|---|
| `Views/Onboarding/Steps/DetectStep.swift` | Detect Step |
| `Views/Onboarding/Steps/ConfirmInstallStep.swift` | Install Homebrew · Install Node.js · Install Codex CLI |
| `Views/Onboarding/Steps/PreviewExternalStepsView.swift` | Window 3 (Sign-in) · Window 4 (Setup with heads-up) |
| `Views/Onboarding/Steps/AwaitExternalAuthView.swift` | Window 5 (Awaiting auth) |
| `Views/Onboarding/Steps/APIKeyPasteStep.swift` | Paste API key — empty · Paste API key — with key |
| `Views/Onboarding/Components/OnboardingStepper.swift` | Installing · Signing in · All done · Install failed |

### What to check

- [ ] Spacing and alignment match the mockup
- [ ] Serif headlines render correctly
- [ ] Stepper dots/lines look right in each phase
- [ ] Command preview surface card (ConfirmInstallStep) reads cleanly
- [ ] No clipped text at default 680×580 frame

> Containers like `WelcomeView`, `ConnectorContainer`, `AIConnectionsView`, and
> `PopoverView` don't have previews — they need real state from the view model,
> so use Layers 2–4 for those.

---

## Layer 2 — Happy path on your daily account (~10 min)

Everything is already connected on `jarvis`, so this validates the connected
state, not the install flow.

- [ ] **Build & run from Xcode** (⌘R). App appears as menu-bar icon, no Dock
  ghost.
- [ ] **Menu bar rings** render with current usage; tooltip looks right.
- [ ] **Popover** opens on click — tab through every connected provider.
- [ ] **Settings → Connections** opens the new help banner at the top
  ("Need help? Open guided setup →"). Banner uses the accent-tint background.
- [ ] **Tap the banner** → guided window opens, lands on **Welcome** (no
  pre-target).
- [ ] **Tap a connected provider's "Manage" button** → guided window opens
  pre-targeted to that provider, auto-skips install since prerequisites are
  detected.
- [ ] **Quit & relaunch** → app still launches as menu-bar agent (no Dock icon
  even briefly). Belt-and-suspenders: `setActivationPolicy(.accessory)` runs
  first thing in `applicationDidFinishLaunching`.
- [ ] **Widgets** (Notification Center) still display correctly — pivot
  shouldn't have touched them, but a quick glance confirms no regression.

---

## Layer 3 — State poking with `/Users/Shared/` scripts (~15 min)

Surgical scripts that simulate a fresh user without nuking your account.

> ⚠️ Run from Terminal. Each script prints what it'll do and asks before
> deleting. After testing, run the matching `restore-*` or re-install via the
> guided flow.

### Pattern A — Codex (system-prerequisite chain)

```bash
/Users/Shared/uninstall-codex.sh
```

- [ ] Open Tokenomics → Settings → Connections → tap **Connect** on Codex.
- [ ] Guided window opens pre-targeted, **Detect** screen appears for ~1 s.
- [ ] **ConfirmInstall** (Codex CLI) renders with command preview.
- [ ] Tap **Install** → spinner → completes.
- [ ] **Window 5** opens — AppleScript handoff to Terminal with `codex`
  pre-typed. Sign in, return to app.
- [ ] Provider flips to connected; rings update.

### Pattern B — Claude (multi-window, no install needed)

Claude is not an npm package — Pattern B previews 5 windows, no install.

- [ ] **Reconnect** an expired Claude token (or sign out via `/Users/Shared/uninstall-claude-code.sh`).
- [ ] Tap **Reconnect** in the popover error banner.
- [ ] Guided window pre-targets Claude, runs through Window 3 → 4 → 5.
- [ ] Window 5 hands off to Terminal with `claude` pre-typed (no manual typing).
- [ ] Auth flow completes, app picks up the new token.

### Pattern C — Copilot (brew → gh → auth)

```bash
/Users/Shared/uninstall-copilot.sh
```

- [ ] Tap **Connect** on Copilot.
- [ ] If `gh` is missing, ConfirmInstall renders for the gh CLI install.
- [ ] After install, `gh auth login --web` runs, flips to connected.

### Pattern D — Cursor (external bundle)

```bash
/Users/Shared/uninstall-cursor.sh
```

- [ ] Tap **Connect** on Cursor.
- [ ] Guided opens cursor.com → waits for app to come back.
- [ ] After install, returning to Tokenomics auto-detects.

### Pattern E — API key paste

```bash
/Users/Shared/uninstall-api-keys.sh
```

- [ ] Tap **Connect** on a key-based provider.
- [ ] Guided opens **APIKeyPasteStep** (3-step stepper).
- [ ] Paste a fake key → submit fails gracefully.
- [ ] Paste a real key → flips to connected.

### Homebrew-missing edge case

```bash
/Users/Shared/hide-homebrew.sh
```

- [ ] Tap **Connect** on Codex.
- [ ] Guided detects no `/opt/homebrew` → ConfirmInstall renders for
  **Homebrew** (admin sudo prompt via NSAppleScript).
- [ ] Cancel the admin prompt → user-friendly error in the failed-state stepper,
  no crash.
- [ ] Try again, allow → Homebrew installs, chain continues to Node → CLI.

```bash
/Users/Shared/restore-homebrew.sh
```

- [ ] Restored cleanly, normal happy path resumes.

### Stuck-state recovery

- [ ] Mid-OAuth wait, **close the guided window**. Re-open via Settings → guided
  doesn't get stuck on the old "awaiting auth" state.
- [ ] **Cancel an in-flight install** by closing the window. No zombie
  subprocess (verify with `ps aux | grep npm` or similar).

---

## Layer 4 — Clean-slate `tokenomics` test user (~15 min)

This is the Apple Reviewer / brand-new-user test. The `tokenomics` user has no
Homebrew, no CLIs, no creds.

1. Build a notarized DMG (or use the staging DMG at
   `/Users/Shared/Tokenomics-Screenshots-Onboarding/Tokenomics-2.9.0-beta.1.dmg`).
2. Log out, sign in as `tokenomics`.
3. Mount DMG, drag to Applications, launch.

- [ ] **Welcome** screen appears in a real Window (not popover) — serif headline,
  hero ring, Get Started CTA, privacy disclosure.
- [ ] **Get Started** → ProviderChooser with 5 providers, real Back button.
- [ ] Pick **Codex** (best canary — full chain).
- [ ] **Detect** → finds nothing → **ConfirmInstall(Homebrew)**.
- [ ] **Install** → admin prompt → runs the Homebrew installer → chain advances
  to **Node** → **Codex CLI** → **Window 5**.
- [ ] Terminal handoff fires `codex`, sign in completes.
- [ ] App is now connected — close the guided window — Window goes away,
  activation policy snaps back to `.accessory`, no Dock icon, menu-bar icon
  visible.
- [ ] Quit & relaunch — still no Dock icon. Onboarding window does **not**
  auto-restore (macOS 15+: `restorationBehavior(.disabled)`).
- [ ] Open Settings → Connections → tap **Connect** on Gemini → guided
  pre-targets, auto-skips brew/node steps, runs Gemini-only install.

---

## Sign-off

When every box above is checked:

- [ ] Tag `v2.9.0-beta.1`, run `./scripts/distribute.sh`.
- [ ] Update `Casks/tokenomics.rb` sha256 in app repo + homebrew tap.
- [ ] Push both repos.
- [ ] Sparkle appcast pushes the beta to opted-in users.

If any box fails: file under `docs/future-features.md` (low priority) or fix
in-place before tagging (high priority).
