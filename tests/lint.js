// Project rules, checked on every push.
// node tests/lint.js
import { readFileSync, readdirSync, statSync, existsSync } from 'node:fs';
import { join, relative, extname, dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const rel = (p) => relative(ROOT, p).split('\\').join('/');
const read = (p) => readFileSync(join(ROOT, p), 'utf8');
const json = (p) => JSON.parse(read(p));
const problems = [];
const bad = (msg) => problems.push(msg);

const BINARY = new Set(['.png', '.webp', '.jpg', '.jpeg', '.gif', '.ico', '.woff', '.woff2', '.ttf', '.otf', '.pdf', '.zip']);
function walk(dir, out = []) {
  for (const name of readdirSync(dir)) {
    if (name === '.git' || name === 'node_modules') continue;
    const p = join(dir, name);
    if (statSync(p).isDirectory()) walk(p, out);
    else out.push(p);
  }
  return out;
}
const files = walk(ROOT);
const textFiles = files.filter((f) => !BINARY.has(extname(f).toLowerCase()));

/* ------------------------------------------------------- writing rules */

const THIRD_PARTY = /^docs\/assets\/fonts\/OFL-/;
const FORBIDDEN = new RegExp(['cla' + 'ude', 'anth' + 'ropic'].join('|'), 'i');
for (const f of textFiles) {
  const r = rel(f);
  const text = readFileSync(f, 'utf8');
  if (!THIRD_PARTY.test(r) && /[\u2012-\u2015]/.test(text)) bad(`${r}: contains an en or em dash`);
  if (FORBIDDEN.test(text)) bad(`${r}: mentions a name that must not appear in this project`);
}

// Arabic: a period ends a sentence and never sits in the middle of one.
const AR = /[\u0600-\u06FF]/;
function arabicPeriods(where, s) {
  if (typeof s !== 'string' || !AR.test(s)) return;
  if (/\.\s+\S/.test(s)) bad(`${where}: period in the middle of an Arabic sentence: ${s}`);
}
function walkStrings(where, v) {
  if (typeof v === 'string') arabicPeriods(where, v);
  else if (Array.isArray(v)) v.forEach((x, i) => walkStrings(`${where}[${i}]`, x));
  else if (v && typeof v === 'object') for (const [k, x] of Object.entries(v)) walkStrings(`${where}.${k}`, x);
}

/* --------------------------------------------------------- app strings */

const strings = json('docs/data/strings.json');
const arKeys = Object.keys(strings.ar).sort();
const enKeys = Object.keys(strings.en).sort();
for (const k of arKeys) if (!(k in strings.en)) bad(`strings.json: "${k}" has no English`);
for (const k of enKeys) if (!(k in strings.ar)) bad(`strings.json: "${k}" has no Arabic`);
walkStrings('strings.json ar', strings.ar);
for (const [k, v] of Object.entries(strings.ar)) {
  const a = (v.match(/\{\w+\}/g) || []).sort().join();
  const e = (String(strings.en[k] || '').match(/\{\w+\}/g) || []).sort().join();
  if (k in strings.en && a !== e) bad(`strings.json: "${k}" placeholders differ between languages`);
}
const app = read('docs/app/app.js');
for (const m of app.matchAll(/\bt\('([a-z_]+\.[a-zA-Z0-9_]+)'(?!\s*\+)/g)) if (!(m[1] in strings.ar)) bad(`app.js uses missing string "${m[1]}"`);
const families = {
  'tab.': ['today', 'home', 'car', 'subs', 'more'],
  'cycle.': ['weekly', 'monthly', 'quarterly', 'semiannual', 'yearly'],
  'cyclename.': ['weekly', 'monthly', 'quarterly', 'semiannual', 'yearly'],
  'type.': ['house', 'flat', 'chalet', 'farm', 'jakhoor'],
  'feat.': ['central_ac', 'tank', 'filter'],
  'last.': ['unknown', 'month', 'm3', 'm6', 'year'],
  'spend.': ['home', 'car', 'things', 'subs'],
  'setup.every_': ['1', '3', '6', '12'],
  'notify.state_': ['on', 'ready', 'install', 'blocked', 'ios', 'unsupported'],
  'empty.': ['home', 'car', 'thing'],
  'act.add_': ['home', 'car', 'thing'],
  'country.': ['KW', 'SA', 'AE', 'QA', 'BH', 'OM'],
  'title.': ['home', 'car', 'subs', 'more', 'things', 'warranties', 'techs', 'travel', 'spend', 'settings', 'about'],
};
for (const [p, list] of Object.entries(families)) for (const s of list) if (!(p + s in strings.ar)) bad(`strings.json: missing "${p + s}"`);
const engineSrc = read('docs/engine/nokhatha.js');
const currencies = [...engineSrc.matchAll(/^\s+([A-Z]{3}): \{ d: \d/gm)].map((m) => m[1]);
for (const c of currencies) if (!(`cur.${c}` in strings.ar)) bad(`strings.json: missing "cur.${c}"`);
const catBlock = /const CATS = \[([\s\S]*?)\];/.exec(app)[1];
const catIds = [...catBlock.matchAll(/\['(\w+)', '\w+'\]/g)].map((m) => m[1]);
if (catIds.length < 5) bad('app.js: could not read the subscription categories');
for (const c of catIds) if (!(`cat.${c}` in strings.ar)) bad(`strings.json: missing "cat.${c}"`);

/* ---------------------------------------------------------- site strings */

const site = json('docs/data/site.json');
const html = read('docs/index.html');
for (const m of html.matchAll(/data-i18n(?:-alt|-label)?="([\w]+)"/g)) if (!(m[1] in site.en)) bad(`site.json: no English for "${m[1]}"`);
for (const k of Object.keys(site.dyn.ar)) if (!(k in site.dyn.en)) bad(`site.json dyn: "${k}" has no English`);
for (const k of Object.keys(site.dyn.en)) if (!(k in site.dyn.ar)) bad(`site.json dyn: "${k}" has no Arabic`);
walkStrings('site.json dyn.ar', site.dyn.ar);
for (const m of html.matchAll(/data-i18n="\w+">([^<]+)</g)) arabicPeriods('index.html', m[1]);
for (const m of html.matchAll(/content="([^"]+)"/g)) arabicPeriods('index.html meta', m[1]);
for (const m of read('docs/app/index.html').matchAll(/content="([^"]+)"/g)) arabicPeriods('app/index.html meta', m[1]);

// The app serves the whole Gulf: copy must not describe the seasons or the year as Kuwait's alone.
for (const f of textFiles.filter((x) => /\.(json|html|md|webmanifest)$/.test(rel(x)) && !rel(x).startsWith('tests/'))) {
  if (/مواسم الكويت|سنة الكويت|Kuwait's (?:seasons|year)/.test(readFileSync(f, 'utf8'))) bad(`${rel(f)}: describes the seasons as Kuwait's only, the app is for the Gulf`);
}

/* ------------------------------------------------------------------ data */

const seasons = json('docs/data/seasons.json');
walkStrings('seasons.json', seasons);
if (seasons.seasons.length !== 14) bad('seasons.json: there must be 14 seasons');
if (new Set(seasons.seasons.map((s) => s.id)).size !== 14) bad('seasons.json: season ids repeat');
if (seasons.seasons[0].id !== 'suhail' || seasons.seasons[0].start !== '08-24') bad('seasons.json: the year starts with Suhail on 08-24');
const md = (s) => (Number(s.slice(0, 2)) * 100 + Number(s.slice(3)) - 824 + 1300) % 1300;
for (let i = 1; i < 14; i++) if (md(seasons.seasons[i].start) <= md(seasons.seasons[i - 1].start)) bad(`seasons.json: ${seasons.seasons[i].id} is out of order`);
for (const s of seasons.seasons) {
  if (!(s.group in seasons.groups)) bad(`seasons.json: ${s.id} has an unknown group`);
  for (const k of ['ar', 'en', 'note_ar', 'note_en', 'hint_ar', 'hint_en']) if (!s[k]) bad(`seasons.json: ${s.id} is missing ${k}`);
}

const tasks = json('docs/data/tasks.json');
walkStrings('tasks.json', tasks);
const icons = read('docs/app/icons.js');
const iconNames = new Set([...icons.matchAll(/^\s{2}(\w+): '/gm)].map((m) => m[1]));
const areaIds = new Set([...tasks.areas.home, ...tasks.areas.car, ...tasks.areas.thing].map((a) => a.id));
const thingTypes = new Set(tasks.thingTypes.map((x) => x.id));
for (const x of tasks.thingTypes) {
  if (!x.ar || !x.en) bad(`tasks.json: thing type ${x.id} needs Arabic and English`);
}
const tradeIds = new Set(tasks.trades.map((t) => t.id));
const seasonIds = new Set(seasons.seasons.map((s) => s.id));
const seenTpl = new Set();
for (const t of tasks.templates) {
  if (seenTpl.has(t.id)) bad(`tasks.json: template ${t.id} repeats`);
  seenTpl.add(t.id);
  for (const k of ['ar', 'en', 'why_ar', 'why_en']) if (!t[k]) bad(`tasks.json: ${t.id} is missing ${k}`);
  if (!['home', 'car', 'thing'].includes(t.kind)) bad(`tasks.json: ${t.id} has kind ${t.kind}`);
  if (t.kind === 'thing' && !thingTypes.has(t.for)) bad(`tasks.json: ${t.id} is for unknown thing ${t.for}`);
  if (!areaIds.has(t.area)) bad(`tasks.json: ${t.id} has unknown area ${t.area}`);
  if (t.trade && !tradeIds.has(t.trade)) bad(`tasks.json: ${t.id} has unknown trade ${t.trade}`);
  if (!iconNames.has(t.icon)) bad(`tasks.json: ${t.id} uses missing icon ${t.icon}`);
  const e = t.every || {};
  const kinds = [e.fixed ? 'fixed' : null, e.season ? 'season' : null, e.days || e.months || e.km ? 'time' : null].filter(Boolean);
  if (kinds.length !== 1) bad(`tasks.json: ${t.id} needs exactly one kind of schedule`);
  if (e.season && !seasonIds.has(e.season)) bad(`tasks.json: ${t.id} uses unknown season ${e.season}`);
  if (e.km && !e.months) bad(`tasks.json: ${t.id} counts km without a time limit`);
}
for (const x of tasks.travel) if (!x.ar || !x.en || !x.id) bad(`tasks.json: travel item ${x.id} is incomplete`);
for (const m of app.matchAll(/icon\('(\w+)'/g)) if (!iconNames.has(m[1])) bad(`app.js uses missing icon ${m[1]}`);
for (const x of tasks.thingTypes) if (!iconNames.has(x.icon)) bad(`tasks.json: thing type ${x.id} uses missing icon ${x.icon}`);
for (const m of html.matchAll(/data-icon="(\w+)"/g)) if (!iconNames.has(m[1])) bad(`index.html uses missing icon ${m[1]}`);

/* ---------------------------------------------------- pages and security */

if (read('docs/CNAME').trim() !== 'nokhatha.3li.info') bad('docs/CNAME must be nokhatha.3li.info');
for (const page of ['docs/index.html', 'docs/app/index.html']) {
  const h = read(page);
  if (!/http-equiv="Content-Security-Policy"/.test(h)) bad(`${page}: no content security policy`);
  if (/script-src[^;"]*'unsafe-inline'|style-src[^;"]*'unsafe-inline'/.test(h)) bad(`${page}: the policy allows inline code`);
  if (/<script(?![^>]*\bsrc=)[^>]*>/.test(h)) bad(`${page}: inline script`);
  if (/<style[\s>]/.test(h)) bad(`${page}: inline style block`);
  for (const m of h.matchAll(/\s(?:src|href)="(https?:[^"]+)"/g)) {
    if (!/^https:\/\/(github\.com\/SiteQ8|3li\.info|nokhatha\.3li\.info)/.test(m[1])) bad(`${page}: external resource ${m[1]}`);
    if (/\ssrc="https?:/.test(m[0])) bad(`${page}: loads ${m[1]} from outside`);
  }
}
for (const f of textFiles.filter((x) => /^docs\/.*\.(js|html)$/.test(rel(x)))) {
  const s = readFileSync(f, 'utf8');
  if (/\sstyle="/.test(s)) bad(`${rel(f)}: inline style attribute, blocked by the policy`);
  if (/\son[a-z]+="/.test(s)) bad(`${rel(f)}: inline event handler`);
  if (/fetch\(\s*['"`]https?:/.test(s)) bad(`${rel(f)}: talks to another site`);
}

/* ------------------------------------------------------ versions and cache */

const VERSION = /export const VERSION = '([\d.]+)'/.exec(engineSrc)[1];
const sw = read('docs/app/sw.js');
if (/const VERSION = '([\d.]+)'/.exec(sw)[1] !== VERSION) bad('sw.js version differs from the engine');
if (json('package.json').version !== VERSION) bad('package.json version differs from the engine');
if (json('tests/vectors.json').engine !== VERSION) bad('tests/vectors.json is for another engine version');
const list = /const FILES = \[([\s\S]*?)\];/.exec(sw)[1];
for (const m of list.matchAll(/'([^']+)'/g)) {
  const p = join(ROOT, 'docs/app', m[1]);
  if (m[1] !== './' && !existsSync(p)) bad(`sw.js caches a missing file ${m[1]}`);
}
const appFiles = ['docs/app/app.js', 'docs/app/app.css', 'docs/app/dial.js', 'docs/app/icons.js', 'docs/app/store.js', 'docs/app/backup.js', 'docs/engine/nokhatha.js', 'docs/data/strings.json', 'docs/data/tasks.json', 'docs/data/seasons.json', 'docs/assets/base.css'];
for (const f of appFiles) {
  const fromApp = relative(join(ROOT, 'docs/app'), join(ROOT, f)).split('\\').join('/');
  if (!list.includes(`'${fromApp}'`)) bad(`sw.js does not cache ${fromApp}`);
}
const manifest = json('docs/app/manifest.webmanifest');
for (const i of manifest.icons) if (!existsSync(join(ROOT, 'docs/app', i.src))) bad(`manifest icon missing: ${i.src}`);
for (const lang of ['ar', 'en']) for (const s of ['today', 'home', 'subs']) if (!existsSync(join(ROOT, `docs/assets/shots/${lang}-${s}.webp`))) bad(`missing screenshot ${lang}-${s}.webp`);
for (const f of ['docs/assets/og.png', 'docs/assets/mark.svg', 'docs/assets/favicon.svg', 'LICENSE', 'README.md']) if (!existsSync(join(ROOT, f))) bad(`missing ${f}`);

if (problems.length) {
  for (const p of problems) console.log('LINT', p);
  console.log(`${problems.length} problem${problems.length === 1 ? '' : 's'}`);
  process.exit(1);
}
console.log(`lint clean: ${textFiles.length} text files, ${arKeys.length} strings in each language, ${tasks.templates.length} templates, 14 seasons`);
