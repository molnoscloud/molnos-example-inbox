import { build } from 'esbuild';
import { readdir } from 'node:fs/promises';
import path from 'node:path';

const SRC_DIR = path.resolve('functions');
const OUT_DIR = path.resolve('dist');

async function collectMjsFiles(dir) {
  const entries = await readdir(dir, { withFileTypes: true });
  const files = [];

  for (const entry of entries) {
    const fullPath = path.join(dir, entry.name);

    if (entry.isDirectory()) {
      files.push(...(await collectMjsFiles(fullPath)));
    } else if (
      entry.isFile() &&
      entry.name.endsWith('.mjs') &&
      entry.name !== 'config.mjs'
    ) {
      files.push(fullPath);
    }
  }

  return files;
}

const entryPoints = await collectMjsFiles(SRC_DIR);

if (entryPoints.length === 0) {
  console.log('No MJS files found.');
  process.exit(0);
}

await build({
  entryPoints,
  bundle: true,
  minify: true,
  target: 'es2024',
  outbase: SRC_DIR,
  outdir: OUT_DIR,
  platform: 'node',
  format: 'esm',
  logLevel: 'info'
});
