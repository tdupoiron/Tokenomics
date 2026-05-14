/**
 * Round-trip tests for the BridgeRequest / BridgeResponse wire shapes.
 * Confirms that JSON.stringify → JSON.parse preserves all required fields.
 *
 * Run via `npm run test`.
 */

import { test } from 'node:test';
import { strict as assert } from 'node:assert';

import {
  BRIDGE_HOST_NAME,
  BRIDGE_SCHEMA_VERSION,
  type BridgeRequest,
  type BridgeResponse,
  type BridgeSnapshot,
  type BridgeWindow,
  type ProviderVisibilitySetting,
} from './bridge-types';

// ── helpers ────────────────────────────────────────────────────

function makeWindow(overrides: Partial<BridgeWindow> = {}): BridgeWindow {
  return {
    label: '5h',
    utilization: 0.42,
    resetsAt: '2026-05-14T20:00:00.000Z',
    windowDurationSec: 18000,
    ...overrides,
  };
}

function makeSnapshot(provider: string, overrides: Partial<BridgeSnapshot> = {}): BridgeSnapshot {
  return {
    provider,
    capturedAt: '2026-05-14T18:30:00.000Z',
    shortWindow: makeWindow(),
    longWindow: null,
    planLabel: 'Pro',
    ...overrides,
  };
}

function roundTrip<T>(value: T): T {
  return JSON.parse(JSON.stringify(value)) as T;
}

// ── constants ──────────────────────────────────────────────────

test('BRIDGE_HOST_NAME is com.tokenomics.bridge', () => {
  assert.equal(BRIDGE_HOST_NAME, 'com.tokenomics.bridge');
});

test('BRIDGE_SCHEMA_VERSION is 1', () => {
  assert.equal(BRIDGE_SCHEMA_VERSION, 1);
});

// ── BridgeRequest round-trip ────────────────────────────────────

test('BridgeRequest: all fields survive JSON round-trip', () => {
  const visibility: Record<string, ProviderVisibilitySetting> = {
    claude: { enabled: true, lastChangedAt: '2026-05-14T17:00:00.000Z' },
    chatgpt: { enabled: true, lastChangedAt: '2026-05-14T17:00:00.000Z' },
    midjourney: { enabled: false, lastChangedAt: '2026-05-14T18:28:00.000Z' },
  };

  const original: BridgeRequest = {
    schemaVersion: 1,
    envelopeSentAt: '2026-05-14T18:30:00.000Z',
    extensionId: 'test-extension-id',
    snapshots: [makeSnapshot('midjourney', { estimated: false })],
    settings: { providerVisibility: visibility },
    requestedActions: { refreshNativeProviders: false },
  };

  const decoded = roundTrip(original);

  assert.equal(decoded.schemaVersion, 1);
  assert.equal(decoded.extensionId, 'test-extension-id');
  assert.equal(decoded.snapshots.length, 1);
  assert.equal(decoded.snapshots[0].provider, 'midjourney');
  assert.equal(decoded.snapshots[0].estimated, false);
  assert.equal(decoded.snapshots[0].shortWindow.utilization, 0.42);
  assert.equal(decoded.snapshots[0].longWindow, null);
  assert.equal(decoded.settings?.providerVisibility['claude']?.enabled, true);
  assert.equal(decoded.settings?.providerVisibility['chatgpt']?.enabled, true);
  assert.equal(decoded.settings?.providerVisibility['midjourney']?.enabled, false);
  assert.equal(decoded.requestedActions?.refreshNativeProviders, false);
});

test('BridgeRequest: optional fields absent when undefined', () => {
  const original: BridgeRequest = {
    schemaVersion: 1,
    envelopeSentAt: '2026-05-14T18:30:00.000Z',
    extensionId: 'test-id',
    snapshots: [],
  };

  const decoded = roundTrip(original);

  assert.equal(decoded.settings, undefined);
  assert.equal(decoded.requestedActions, undefined);
  assert.equal(decoded.snapshots.length, 0);
});

// ── BridgeResponse round-trip ───────────────────────────────────

test('BridgeResponse: commands array preserves kind string', () => {
  const original: BridgeResponse = {
    ok: true,
    bridgeSchemaVersion: 1,
    macAppVersion: '2.9.0',
    ackedAt: '2026-05-14T18:30:01.000Z',
    nativeSnapshots: [
      makeSnapshot('codex', {
        shortWindow: makeWindow({ sublabelOverride: 'Resets tomorrow' }),
      }),
    ],
    commands: [{ kind: 'refreshWebProviders' }],
  };

  const decoded = roundTrip(original);

  assert.equal(decoded.ok, true);
  assert.equal(decoded.bridgeSchemaVersion, 1);
  assert.equal(decoded.macAppVersion, '2.9.0');
  assert.equal(decoded.nativeSnapshots.length, 1);
  assert.equal(decoded.nativeSnapshots[0].provider, 'codex');
  assert.equal(
    decoded.nativeSnapshots[0].shortWindow.sublabelOverride,
    'Resets tomorrow',
  );
  assert.equal(decoded.commands.length, 1);
  assert.equal(decoded.commands[0].kind, 'refreshWebProviders');
  assert.equal(decoded.error, undefined);
});

test('BridgeResponse: error path', () => {
  const original: BridgeResponse = {
    ok: false,
    bridgeSchemaVersion: 1,
    macAppVersion: '2.9.0',
    ackedAt: '2026-05-14T18:30:01.000Z',
    nativeSnapshots: [],
    commands: [],
    error: 'unsupported schema version',
  };

  const decoded = roundTrip(original);

  assert.equal(decoded.ok, false);
  assert.equal(decoded.error, 'unsupported schema version');
  assert.equal(decoded.commands.length, 0);
});

// ── BridgeWindow sublabelOverride ──────────────────────────────

test('BridgeWindow: sublabelOverride survives round-trip', () => {
  const window = makeWindow({ sublabelOverride: 'Resets in 2h 15m' });
  const decoded = roundTrip(window);
  assert.equal(decoded.sublabelOverride, 'Resets in 2h 15m');
});

test('BridgeWindow: absent sublabelOverride stays absent', () => {
  const window = makeWindow();
  const decoded = roundTrip(window);
  assert.equal(decoded.sublabelOverride, undefined);
});

// ── BridgeSnapshot with longWindow ─────────────────────────────

test('BridgeSnapshot: longWindow present round-trips correctly', () => {
  const snapshot = makeSnapshot('claude', {
    longWindow: makeWindow({ label: '7d', utilization: 0.2, windowDurationSec: 604800 }),
  });
  const decoded = roundTrip(snapshot);
  assert.ok(decoded.longWindow);
  assert.equal(decoded.longWindow.label, '7d');
  assert.equal(decoded.longWindow.utilization, 0.2);
  assert.equal(decoded.longWindow.windowDurationSec, 604800);
});

// ── ProviderVisibilitySetting ──────────────────────────────────

test('ProviderVisibilitySetting: enabled=false round-trips', () => {
  const setting: ProviderVisibilitySetting = {
    enabled: false,
    lastChangedAt: '2026-05-14T17:00:00.000Z',
  };
  const decoded = roundTrip(setting);
  assert.equal(decoded.enabled, false);
  assert.equal(decoded.lastChangedAt, '2026-05-14T17:00:00.000Z');
});
