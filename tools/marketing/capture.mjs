// Renders of the web app's pages at 3x, Arabic and English, on the sample home, for the marketing cards.
// Needs the site served locally: (cd docs && python3 -m http.server 8765). Writes /tmp/mkt/shots/<lang>-<page>.png.
import { chromium } from '/home/claude/.npm-global/lib/node_modules/playwright/index.mjs';
import { mkdirSync } from 'node:fs';
mkdirSync('/tmp/mkt/shots', { recursive: true });
const b = await chromium.launch();
for (const lang of ['ar', 'en']) {
  const ctx = await b.newContext({ viewport: { width: 412, height: 892 }, deviceScaleFactor: 3, locale: lang === 'ar' ? 'ar-KW' : 'en-GB' });
  const page = await ctx.newPage();
  await page.goto('http://localhost:8765/app/', { waitUntil: 'networkidle' });
  await page.waitForTimeout(400);
  if (lang === 'en') { const seg = page.locator('[data-act="set"][data-name="lang"][data-v="en"]'); if (await seg.count()) { await seg.first().click(); await page.waitForTimeout(300); } }
  const demo = page.locator('[data-act="demo"]'); if (await demo.count()) { await demo.first().click(); await page.waitForTimeout(700); }
  for (const p of ['today', 'home', 'car', 'subs', 'docs', 'settings', 'spend', 'warranties']) {
    await page.goto('http://localhost:8765/app/#/' + p); await page.reload({ waitUntil: 'networkidle' }); await page.waitForTimeout(600);
    await page.screenshot({ path: `/tmp/mkt/shots/${lang}-${p}.png` });
  }
  await ctx.close();
}
await b.close();
console.log('renders captured');
