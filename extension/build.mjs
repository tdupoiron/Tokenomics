import * as esbuild from 'esbuild';
import { cp, mkdir, rm } from 'node:fs/promises';
import { existsSync } from 'node:fs';

const watch = process.argv.includes('--watch');
const outdir = 'dist';

await rm(outdir, { recursive: true, force: true });
await mkdir(outdir, { recursive: true });

const ctx = await esbuild.context({
  entryPoints: {
    background: 'src/background.ts',
    'popup/popup': 'src/popup/popup.tsx',
  },
  bundle: true,
  outdir,
  format: 'esm',
  target: 'chrome120',
  jsx: 'automatic',
  jsxImportSource: 'preact',
  logLevel: 'info',
  sourcemap: watch ? 'inline' : false,
  minify: !watch,
});

await ctx.rebuild();

await cp('src/manifest.json', `${outdir}/manifest.json`);
await cp('src/popup/index.html', `${outdir}/popup/index.html`);
await cp('src/popup/popup.css', `${outdir}/popup/popup.css`);
await cp('src/popup/tokens.css', `${outdir}/popup/tokens.css`);
if (existsSync('src/icons')) {
  await cp('src/icons', `${outdir}/icons`, { recursive: true });
}

if (watch) {
  console.log('Watching for changes…');
  await ctx.watch();
} else {
  await ctx.dispose();
  console.log(`Build complete → ${outdir}/`);
}
