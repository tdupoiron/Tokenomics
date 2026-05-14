import * as esbuild from 'esbuild';
import { glob, rm, mkdir } from 'node:fs/promises';

const outdir = 'dist-test';

await rm(outdir, { recursive: true, force: true });
await mkdir(outdir, { recursive: true });

const entryPoints = [];
for await (const file of glob('src/**/*.test.ts')) {
  entryPoints.push(file);
}

if (entryPoints.length === 0) {
  console.log('No test files found.');
  process.exit(0);
}

await esbuild.build({
  entryPoints,
  outdir,
  bundle: true,
  platform: 'node',
  format: 'esm',
  target: 'node22',
  logLevel: 'info',
  // Tests pull `import { test } from 'node:test'` etc.; keep node built-ins external.
  external: ['node:*'],
  // Each test file becomes a self-contained .mjs sibling layout matching src/.
  outbase: 'src',
  outExtension: { '.js': '.mjs' },
});

console.log(`Test bundles → ${outdir}/`);
