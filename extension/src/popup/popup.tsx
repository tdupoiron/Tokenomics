import { render } from 'preact';

function App() {
  return (
    <div class="popup">
      <p class="popup__placeholder">Tokenomics — scaffolding</p>
    </div>
  );
}

const root = document.getElementById('app');
if (root) render(<App />, root);
