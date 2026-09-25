// Regenerates the logo, favicon and app icons from one drawing.
// Usage: npm i sharp --no-save && node tools/make-icons.mjs
import { writeFileSync, mkdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..', 'docs', 'assets');
const sharp = (await import(process.env.SHARP || 'sharp')).default;

// The mark on a 64 grid: the year ring, a boom under a lateen sail,
// Sadu teeth for the sea, and the pearl of today riding the ring.
const RING = '<circle cx="32" cy="32" r="26.5" fill="none" stroke-width="3.4" class="r"/>';
const SAIL = '<path class="s" d="M47.2 30.2C40.6 22.4 31.8 15.2 20.4 10.6c1.9 7.1 3.4 14.3 3.9 21.6Z"/>';
const HULL = '<path class="h" d="M11.8 35.4 52.6 32.2c-1.7 4.6-4.5 8.3-8.6 10.6-7.9 2.5-17.6 2.7-25.4.7-3.3-1.9-5.6-4.8-6.8-8.1Z"/>';
const SEA = '<path class="w" fill="none" stroke-width="2.6" stroke-linejoin="round" stroke-linecap="round" d="m15.5 50.2 3.4-3.4 3.4 3.4 3.4-3.4 3.4 3.4 3.4-3.4 3.4 3.4 3.4-3.4 3.4 3.4 3.4-3.4 3.4 3.4"/>';
const PEARL = '<circle class="p" cx="45.3" cy="9.1" r="4.4"/>';

function markGroup(c) {
  return [
    RING.replace('class="r"', `stroke="${c.ring}"`),
    SAIL.replace('class="s"', `fill="${c.sail}"`),
    HULL.replace('class="h"', `fill="${c.hull}"`),
    SEA.replace('class="w"', `stroke="${c.sea}"`),
    PEARL.replace('class="p"', `fill="${c.pearl}"`),
  ].join('');
}

const LIGHT = { ring: '#1C2340', sail: '#A4262C', hull: '#1C2340', sea: '#127A74', pearl: '#C98A1B' };
const DARK = { ring: '#EEF1F4', sail: '#D8474D', hull: '#EEF1F4', sea: '#41B8AC', pearl: '#E7AF4B' };

const logo = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" role="img" aria-label="Nokhatha">${markGroup(LIGHT)}</svg>\n`;

const favicon = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
<style>.r{stroke:#1C2340}.h{fill:#1C2340}.s{fill:#A4262C}.w{stroke:#127A74}.p{fill:#C98A1B}
@media (prefers-color-scheme:dark){.r{stroke:#EEF1F4}.h{fill:#EEF1F4}.s{fill:#D8474D}.w{stroke:#41B8AC}.p{fill:#E7AF4B}}</style>
${RING}${SAIL}${HULL}${SEA}${PEARL}
</svg>\n`;

// App icon: night sea, the mark in pearl, a faint Sadu rim.
function appIcon(size, scale, rounded = false) {
  const off = (size - 64 * scale) / 2;
  const r = rounded ? size * 0.2237 : 0;
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${size} ${size}" width="${size}" height="${size}">
<defs><radialGradient id="g" cx="50%" cy="38%" r="75%"><stop offset="0" stop-color="#27305A"/><stop offset="1" stop-color="#161C35"/></radialGradient>
<radialGradient id="pg" cx="35%" cy="30%" r="80%"><stop offset="0" stop-color="#FFF4DA"/><stop offset=".45" stop-color="#E7AF4B"/><stop offset="1" stop-color="#B07A1A"/></radialGradient></defs>
<rect width="${size}" height="${size}" rx="${r}" fill="url(#g)"/>
<g transform="translate(${off} ${off}) scale(${scale})">${markGroup({ ...DARK, pearl: 'url(#pg)' })}</g>
</svg>`;
}

mkdirSync(join(root, 'icons'), { recursive: true });
writeFileSync(join(root, 'logo.svg'), logo);
writeFileSync(join(root, 'favicon.svg'), favicon);
writeFileSync(join(root, 'mark.svg'), favicon);
writeFileSync(join(root, 'logo-dark.svg'), `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" role="img" aria-label="Nokhatha">${markGroup(DARK)}</svg>\n`);
writeFileSync(join(root, 'icons', 'icon.svg'), appIcon(1024, 13.2) + '\n');

const png = (svg, file) => sharp(Buffer.from(svg)).png({ compressionLevel: 9 }).toFile(join(root, 'icons', file));
await png(appIcon(1024, 13.2), 'icon-1024.png');
await png(appIcon(512, 6.6), 'icon-512.png');
await png(appIcon(192, 2.47), 'icon-192.png');
await png(appIcon(180, 2.32), 'apple-touch-icon.png');
await png(appIcon(512, 6.2), 'maskable-512.png');
await png(appIcon(64, 0.84), 'favicon-64.png');
console.log('icons written');
