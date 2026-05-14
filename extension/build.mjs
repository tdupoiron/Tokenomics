import * as esbuild from 'esbuild';
import { cp, mkdir, rm } from 'node:fs/promises';
import { existsSync } from 'node:fs';

const watch = process.argv.includes('--watch');
const outdir = 'dist';

await rm(outdir, { recursive: true, force: true });
await mkdir(outdir, { recursive: true });

const shared = {
  bundle: true,
  outdir,
  target: 'chrome120',
  jsx: 'automatic',
  jsxImportSource: 'preact',
  logLevel: 'info',
  sourcemap: watch ? 'inline' : false,
  minify: !watch,
};

// SW + popup ship as ES modules (the SW manifest declares `type: module`).
const moduleCtx = await esbuild.context({
  ...shared,
  entryPoints: {
    background: 'src/background.ts',
    'popup/popup': 'src/popup/popup.tsx',
  },
  format: 'esm',
});

// Content scripts must be classic scripts — Chrome rejects ESM in this slot.
const contentCtx = await esbuild.context({
  ...shared,
  entryPoints: {
    'content/chatgpt-watch': 'src/content/chatgpt-watch.ts',
  },
  format: 'iife',
});

await Promise.all([moduleCtx.rebuild(), contentCtx.rebuild()]);

await cp('src/manifest.json', `${outdir}/manifest.json`);
await cp('src/popup/index.html', `${outdir}/popup/index.html`);
await cp('src/popup/popup.css', `${outdir}/popup/popup.css`);
await cp('src/popup/tokens.css', `${outdir}/popup/tokens.css`);
if (existsSync('src/icons')) {
  await cp('src/icons', `${outdir}/icons`, { recursive: true });
}

if (watch) {
  console.log('Watching for changes…');
  await Promise.all([moduleCtx.watch(), contentCtx.watch()]);
} else {
  await Promise.all([moduleCtx.dispose(), contentCtx.dispose()]);
  console.log(`Build complete → ${outdir}/`);
}
