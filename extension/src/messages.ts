/**
 * Message protocol between the popup and the background service worker.
 * Use ExtensionMessage for requests, ExtensionResponse for replies.
 */

export type ExtensionMessage = { kind: 'REFRESH_REQUESTED' };

export type ExtensionResponse =
  | { kind: 'REFRESH_COMPLETE' }
  | { kind: 'REFRESH_FAILED'; error: string }
  | { kind: 'REFRESH_BACKOFF'; until: number };
