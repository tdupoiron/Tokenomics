import browser from 'webextension-polyfill';
import { AuthError, fetchClaudeUsage, RateLimitError } from './claude';
import type { ExtensionMessage, ExtensionResponse } from './messages';
import {
  getBackoff,
  setBackoff,
  setClaudeAuth,
  setClaudeSnapshot,
} from './storage';

const ALARM_NAME = 'claude-poll';
const POLL_PERIOD_MIN = 5;

// Exponential backoff: 5m → 10m → 20m → 40m → 60m (cap)
const BACKOFF_INITIAL_MS = 5 * 60_000;
const BACKOFF_MAX_MS = 60 * 60_000;

console.log('[tokenomics] service worker booted');

browser.runtime.onInstalled.addListener(async () => {
  await scheduleAlarm();
  void pollClaude('install');
});

browser.runtime.onStartup.addListener(async () => {
  await scheduleAlarm();
});

browser.alarms.onAlarm.addListener((alarm) => {
  if (alarm.name === ALARM_NAME) {
    void pollClaude('alarm');
  }
});

browser.runtime.onMessage.addListener(async (message: unknown): Promise<ExtensionResponse | undefined> => {
  const msg = message as ExtensionMessage | undefined;
  if (msg?.kind !== 'REFRESH_REQUESTED') return undefined;

  const backoff = await getBackoff();
  if (backoff && Date.now() < backoff.until) {
    return { kind: 'REFRESH_BACKOFF', until: backoff.until };
  }

  try {
    await pollClaude('manual');
    return { kind: 'REFRESH_COMPLETE' };
  } catch (err) {
    return { kind: 'REFRESH_FAILED', error: String(err) };
  }
});

async function scheduleAlarm(): Promise<void> {
  await browser.alarms.create(ALARM_NAME, { periodInMinutes: POLL_PERIOD_MIN });
}

async function pollClaude(trigger: 'install' | 'alarm' | 'manual'): Promise<void> {
  const existing = await getBackoff();
  if (existing && Date.now() < existing.until && trigger !== 'manual') {
    console.log(`[tokenomics] skipping ${trigger} poll, in backoff until`, new Date(existing.until));
    return;
  }

  try {
    const snapshot = await fetchClaudeUsage();
    await setClaudeSnapshot(snapshot);
    await setClaudeAuth('authenticated');
    await setBackoff(null);
    console.log(`[tokenomics] poll ok (${trigger})`, snapshot);
  } catch (err) {
    if (err instanceof AuthError) {
      await setClaudeAuth('unauthenticated');
      console.log('[tokenomics] claude.ai not signed in');
    } else if (err instanceof RateLimitError) {
      const next = nextBackoff(existing);
      await setBackoff(next);
      console.warn('[tokenomics] rate limited until', new Date(next.until));
      throw err;
    } else {
      console.error('[tokenomics] poll failed', err);
      throw err;
    }
  }
}

function nextBackoff(prev: { nextDelayMs: number } | null) {
  const delay = prev?.nextDelayMs ?? BACKOFF_INITIAL_MS;
  return {
    until: Date.now() + delay,
    nextDelayMs: Math.min(delay * 2, BACKOFF_MAX_MS),
  };
}
