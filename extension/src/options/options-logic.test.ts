/**
 * Unit tests for visibility toggle logic in options-logic.ts.
 *
 * Run via `npm run test`.
 *
 * applyVisibilityToggle accepts injected storage setter and bridge sender,
 * making it straightforward to verify both without module-level mocking.
 */

import { test } from 'node:test';
import { strict as assert } from 'node:assert';

// Install the chrome mock before any module that touches chrome.* loads.
// bridge.ts uses raw chrome.* calls (no polyfill), so this covers it.
import { installMockChrome } from '../__mocks__/chrome';
installMockChrome();

// Import only the pure logic module — no webextension-polyfill involved.
import { applyVisibilityToggle } from './options-logic';
import type { ProviderVisibilitySetting } from '../bridge-types';
import type { BridgeSendReason } from '../bridge';

// ── Helpers ──────────────────────────────────────────────────────

function makeNoopSetter(): (map: Record<string, ProviderVisibilitySetting>) => Promise<void> {
  return async () => { /* no-op */ };
}

function makeSpy(): { fn: (reason: BridgeSendReason) => void; calls: BridgeSendReason[] } {
  const calls: BridgeSendReason[] = [];
  return {
    fn: (reason) => { calls.push(reason); },
    calls,
  };
}

// ── Test 1: lastChangedAt is set close to Date.now() ────────────

test('applyVisibilityToggle: sets lastChangedAt to a timestamp near Date.now()', async () => {
  const before = Date.now();

  const result = await applyVisibilityToggle(
    'copilot',
    false,
    {},
    makeNoopSetter(),
    makeSpy().fn,
  );

  const after = Date.now();
  const entry = result['copilot'];
  assert.ok(entry, 'copilot entry should exist in returned map');
  assert.equal(entry.enabled, false, 'enabled flag should reflect the toggle argument');

  const ts = new Date(entry.lastChangedAt).getTime();
  assert.ok(
    ts >= before && ts <= after + 5,
    `lastChangedAt (${entry.lastChangedAt}) should be between ${before} and ${after + 5}`,
  );
});

// ── Test 2: toggle calls bridge sender with reason "settings" ────

test('applyVisibilityToggle: calls sendBridge("settings") once per toggle', async () => {
  const spy = makeSpy();
  const noop = makeNoopSetter();

  await applyVisibilityToggle('cursor', true, {}, noop, spy.fn);
  await applyVisibilityToggle('copilot', false, {}, noop, spy.fn);

  assert.equal(spy.calls.length, 2, 'sendBridge should be called once per toggle');
  assert.equal(spy.calls[0], 'settings', 'first call reason should be "settings"');
  assert.equal(spy.calls[1], 'settings', 'second call reason should be "settings"');
});
