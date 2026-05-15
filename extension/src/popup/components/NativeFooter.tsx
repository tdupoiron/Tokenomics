/**
 * Small footer shown inside a provider card when the data source is the
 * Mac app bridge (not the extension's own web fetch). Sets the right
 * expectation that this card can't be refreshed from within the extension.
 */
export function NativeFooter() {
  return (
    <div class="native-footer" aria-label="Data source: Tokenomics on macOS">
      <span class="native-footer__dot" aria-hidden="true" />
      <span class="native-footer__text">Tracked by Tokenomics on macOS</span>
    </div>
  );
}
