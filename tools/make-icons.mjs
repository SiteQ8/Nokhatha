// Renders the app icons and favicons from the SVGs written by tools/make-brand.py.
// Usage: npm i sharp --no-save && node tools/make-icons.mjs
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const assets = join(dirname(fileURLToPath(import.meta.url)), '..', 'docs', 'assets');
const sharp = (await import(process.env.SHARP || 'sharp')).default;
const brand = (f) => readFileSync(join(assets, 'brand', f));

const out = [
  ['app-icon.svg', 1024, 'icon-1024.png'],
  ['app-icon.svg', 512, 'icon-512.png'],
  ['app-icon.svg', 192, 'icon-192.png'],
  ['app-icon.svg', 180, 'apple-touch-icon.png'],
  ['app-icon-maskable.svg', 512, 'maskable-512.png'],
  ['app-icon.svg', 64, 'favicon-64.png'],
];
for (const [src, size, file] of out) {
  await sharp(brand(src), { density: Math.max(72, (72 * size) / 1024 * 4) })
    .resize(size, size)
    .png({ compressionLevel: 9 })
    .toFile(join(assets, 'icons', file));
}
console.log('icons written');
