/**
 * Message protocol between the popup / content scripts and the
 * background service worker.
 */

export type ExtensionMessage =
  | { kind: 'REFRESH_REQUESTED' }
  | { kind: 'CHATGPT_MESSAGE'; model: string | null; ts: number }
  | { kind: 'CHATGPT_SET_PLAN'; plan: 'free' | 'plus' | 'pro' | 'team' | 'auto' };

export type ExtensionResponse =
  | { kind: 'REFRESH_COMPLETE' }
  | { kind: 'REFRESH_FAILED'; error: string }
  | { kind: 'REFRESH_BACKOFF'; until: number }
  | { kind: 'ACK' };
