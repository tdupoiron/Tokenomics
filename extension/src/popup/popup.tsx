import { render } from 'preact';
import { useEffect, useState } from 'preact/hooks';
import { PROVIDERS, type ProviderId } from '../types';
import { getSelectedTab, setSelectedTab } from '../storage';
import { Header } from './components/Header';
import { ProviderTabBar } from './components/ProviderTabBar';

const DEFAULT_TAB: ProviderId = PROVIDERS[0];

function applyTheme() {
  const isDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
  document.documentElement.dataset.theme = isDark ? 'dark' : 'light';
}

function App() {
  const [selected, setSelected] = useState<ProviderId>(DEFAULT_TAB);

  useEffect(() => {
    void getSelectedTab().then((stored) => {
      if (stored) setSelected(stored);
    });
  }, []);

  const handleSelect = (provider: ProviderId) => {
    setSelected(provider);
    void setSelectedTab(provider);
  };

  return (
    <div class="popup">
      <Header />
      <ProviderTabBar selected={selected} onSelect={handleSelect} />
      <main class="popup__body" />
      <footer class="popup__footer" />
    </div>
  );
}

applyTheme();
window
  .matchMedia('(prefers-color-scheme: dark)')
  .addEventListener('change', applyTheme);

const root = document.getElementById('app');
if (root) render(<App />, root);
