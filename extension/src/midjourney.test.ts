/**
 * Regression tests for the Midjourney user-account parser.
 *
 * The trial-case fixture is the actual /api/user-account response captured
 * 2026-05-14 from a real signed-in account with no subscription. Other
 * fixtures are derived from the static plan catalog and the verified
 * 60,000-credits-per-Fast-minute conversion.
 */

import { test } from 'node:test';
import { strict as assert } from 'node:assert';

import { mapToSnapshot } from './midjourney';

const NOW = 1_778_792_886_639; // matches the trial-fixture `userData.updated`
const DAY = 24 * 60 * 60 * 1000;
const CREDITS_PER_MIN = 60_000;

// The static plan catalog as returned by /api/user-account. Lifted from the
// real response; only the fields the parser depends on are kept.
const PLANS = [
  { type: 'plan', key: 'basic',    copy: { name: 'Basic Plan' },    credit_period: 'month', credit_allocation: 12_000_000 },
  { type: 'plan', key: 'standard', copy: { name: 'Standard Plan' }, credit_period: 'month', credit_allocation: 54_000_000 },
  { type: 'plan', key: 'pro',      copy: { name: 'Pro Plan' },      credit_period: 'month', credit_allocation: 108_000_000 },
  { type: 'plan', key: 'mega',     copy: { name: 'Mega Plan' },     credit_period: 'month', credit_allocation: 216_000_000 },
];

// ── Trial / no-sub case (real captured response) ─────────────

test('trial account → "No plan" label, 0% utilization', () => {
  const snap = mapToSnapshot({
    user: { abilities: { billing: false, subscription: { type: 'none' } } },
    plans: PLANS,
    userData: {
      status: 'trial',
      created: NOW,
      updated: NOW,
      period_credits: 0,
      credit_period_usage: 0,
      period_credits_used: 0,
      credits_total: 0,
    },
  }, NOW);
  assert.equal(snap.planLabel, 'No plan');
  assert.equal(snap.shortWindow.utilization, 0);
  assert.equal(snap.shortWindow.sublabelOverride, 'No active subscription');
});

test('trial account → snapshot is marked NOT estimated', () => {
  const snap = mapToSnapshot(
    { user: { abilities: { subscription: { type: 'none' } } } },
    NOW,
  );
  assert.equal(snap.estimated, false);
  assert.equal(snap.provider, 'midjourney');
});

// ── Active subscriptions ─────────────────────────────────────

test('Standard plan, half used → 50% utilization, plan name from catalog', () => {
  const snap = mapToSnapshot({
    user: { abilities: { billing: true, subscription: { type: 'plan', key: 'standard' } } },
    plans: PLANS,
    userData: {
      status: 'active',
      created: NOW - 5 * DAY,
      updated: NOW,
      period_credits: 54_000_000,
      credit_period_usage: 27_000_000,
    },
  }, NOW);
  assert.equal(snap.planLabel, 'Standard Plan');
  assert.equal(snap.shortWindow.utilization, 50);
  // 27M credits / 60K = 450 min = 7h 30m used; 900 min total = 15h.
  assert.match(snap.shortWindow.sublabelOverride ?? '', /^7h 30m of 15h/);
});

test('Pro plan, fully used → 100% utilization, hh:mm out of 30h', () => {
  const snap = mapToSnapshot({
    user: { abilities: { subscription: { type: 'plan', key: 'pro' } } },
    plans: PLANS,
    userData: {
      created: NOW,
      updated: NOW,
      period_credits: 108_000_000,
      credit_period_usage: 108_000_000,
    },
  }, NOW);
  assert.equal(snap.planLabel, 'Pro Plan');
  assert.equal(snap.shortWindow.utilization, 100);
  assert.match(snap.shortWindow.sublabelOverride ?? '', /^30h of 30h/);
});

test('Mega plan, 1 minute used → 0% util but minute count shown', () => {
  const snap = mapToSnapshot({
    user: { abilities: { subscription: { type: 'plan', key: 'mega' } } },
    plans: PLANS,
    userData: {
      created: NOW,
      updated: NOW,
      period_credits: 216_000_000,
      credit_period_usage: CREDITS_PER_MIN, // 1 minute
    },
  }, NOW);
  assert.equal(snap.planLabel, 'Mega Plan');
  assert.equal(snap.shortWindow.utilization, 0);
  assert.match(snap.shortWindow.sublabelOverride ?? '', /^1m of 60h/);
});

test('Basic plan resolves via catalog when subscribed', () => {
  const snap = mapToSnapshot({
    user: { abilities: { subscription: { type: 'plan', key: 'basic' } } },
    plans: PLANS,
    userData: {
      created: NOW,
      updated: NOW,
      period_credits: 12_000_000,
      credit_period_usage: 0,
    },
  }, NOW);
  assert.equal(snap.planLabel, 'Basic Plan');
});

test('utilization clamps to 100 when usage exceeds allocation', () => {
  const snap = mapToSnapshot({
    user: { abilities: { subscription: { type: 'plan', key: 'standard' } } },
    plans: PLANS,
    userData: {
      created: NOW,
      updated: NOW,
      period_credits: 54_000_000,
      credit_period_usage: 99_999_999_999,
    },
  }, NOW);
  assert.equal(snap.shortWindow.utilization, 100);
});

// ── Plan label fallbacks ─────────────────────────────────────

test('subscribed but plan catalog missing → toDisplayPlan fallback', () => {
  const snap = mapToSnapshot({
    user: { abilities: { subscription: { type: 'plan', key: 'pro' } } },
    // No plans array provided.
    userData: { created: NOW, updated: NOW, period_credits: 108_000_000, credit_period_usage: 0 },
  }, NOW);
  assert.equal(snap.planLabel, 'Pro');
});

test('subscribed with unknown key → "Midjourney" generic label', () => {
  const snap = mapToSnapshot({
    user: { abilities: { subscription: { type: 'plan', key: 'enterprise_super_secret' } } },
    plans: PLANS,
    userData: { created: NOW, updated: NOW, period_credits: 0, credit_period_usage: 0 },
  }, NOW);
  assert.equal(snap.planLabel, 'Midjourney');
});

test('missing subscription object → "No plan"', () => {
  const snap = mapToSnapshot({
    user: { abilities: {} },
    userData: { period_credits: 0, credit_period_usage: 0 },
  }, NOW);
  assert.equal(snap.planLabel, 'No plan');
});

// ── Reset time resolution ────────────────────────────────────

test('explicit next_period_at wins over fallback', () => {
  const target = NOW + 10 * DAY;
  const snap = mapToSnapshot({
    user: { abilities: { subscription: { type: 'plan', key: 'standard' } } },
    plans: PLANS,
    userData: {
      updated: NOW,
      next_period_at: target,
      period_credits: 54_000_000,
      credit_period_usage: 0,
    },
  }, NOW);
  assert.equal(new Date(snap.shortWindow.resetsAt).getTime(), target);
});

test('fallback reset = updated + 30 days when no explicit field', () => {
  const snap = mapToSnapshot({
    user: { abilities: { subscription: { type: 'plan', key: 'standard' } } },
    plans: PLANS,
    userData: {
      updated: NOW,
      period_credits: 54_000_000,
      credit_period_usage: 0,
    },
  }, NOW);
  assert.equal(new Date(snap.shortWindow.resetsAt).getTime(), NOW + 30 * DAY);
});

test('stale candidate (in the past) is ignored', () => {
  const snap = mapToSnapshot({
    user: { abilities: { subscription: { type: 'plan', key: 'standard' } } },
    plans: PLANS,
    userData: {
      updated: NOW,
      // A past timestamp shouldn't be used as the reset.
      next_period_at: NOW - DAY,
      period_credits: 54_000_000,
      credit_period_usage: 0,
    },
  }, NOW);
  assert.equal(new Date(snap.shortWindow.resetsAt).getTime(), NOW + 30 * DAY);
});

// ── Safety / shape drift ─────────────────────────────────────

test('completely empty body → safe defaults, no throw', () => {
  const snap = mapToSnapshot({}, NOW);
  assert.equal(snap.planLabel, 'No plan');
  assert.equal(snap.shortWindow.utilization, 0);
  assert.equal(snap.longWindow, null);
  assert.equal(snap.estimated, false);
});

test('credit_period_usage as a string is coerced to number', () => {
  const snap = mapToSnapshot({
    user: { abilities: { subscription: { type: 'plan', key: 'standard' } } },
    plans: PLANS,
    userData: {
      updated: NOW,
      period_credits: 54_000_000,
      // Pretend the server returned a string. We should still parse it.
      credit_period_usage: '13500000' as unknown as number,
    },
  }, NOW);
  // 13.5M / 54M = 25%
  assert.equal(snap.shortWindow.utilization, 25);
});
