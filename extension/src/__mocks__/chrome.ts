/**
 * Minimal Chrome extension API mock for use in bridge.test.ts and related
 * unit tests. Exposes a controllable `sendNativeMessage` so tests can
 * simulate both successful bridge responses and lastError failures.
 */

type Listener<T> = (msg: T) => void;

export interface MockChrome {
  runtime: {
    lastError?: { message: string };
    sendNativeMessage: (hostName: string, message: unknown, callback: (response: unknown) => void) => void;
    onMessage: { addListener: (cb: Listener<unknown>) => void };
    id: string;
  };
  alarms: {
    create: (name: string, alarmInfo: chrome.alarms.AlarmCreateInfo) => void;
    onAlarm: { addListener: (cb: (alarm: chrome.alarms.Alarm) => void) => void };
    clear: (name: string, callback?: (wasCleared: boolean) => void) => void;
  };
  storage: {
    local: {
      get: (keys: string | string[] | null, callback: (items: Record<string, unknown>) => void) => void;
      set: (items: Record<string, unknown>, callback?: () => void) => void;
    };
  };
}

interface MockOptions {
  nativeMessageResponse?: unknown;
  nativeMessageError?: string;
}

export function makeMockChrome(options: MockOptions = {}): MockChrome {
  const storageBacking: Record<string, unknown> = {};
  return {
    runtime: {
      id: 'test-extension-id',
      lastError: undefined,
      sendNativeMessage: (_host, _message, callback) => {
        if (options.nativeMessageError) {
          (globalThis as any).chrome.runtime.lastError = { message: options.nativeMessageError };
          callback(undefined);
          (globalThis as any).chrome.runtime.lastError = undefined;
        } else {
          callback(options.nativeMessageResponse ?? { ok: true });
        }
      },
      onMessage: { addListener: () => undefined },
    },
    alarms: {
      create: () => undefined,
      onAlarm: { addListener: () => undefined },
      clear: (_name, callback) => callback?.(true),
    },
    storage: {
      local: {
        get: (keys, callback) => {
          if (keys === null) {
            callback({ ...storageBacking });
            return;
          }
          const out: Record<string, unknown> = {};
          const list = Array.isArray(keys) ? keys : [keys];
          for (const k of list) {
            if (k in storageBacking) out[k] = storageBacking[k];
          }
          callback(out);
        },
        set: (items, callback) => {
          Object.assign(storageBacking, items);
          callback?.();
        },
      },
    },
  };
}

/** Install a mock Chrome API on `globalThis.chrome` and return the mock for inspection. */
export function installMockChrome(options: MockOptions = {}): MockChrome {
  const mock = makeMockChrome(options);
  (globalThis as any).chrome = mock;
  return mock;
}
