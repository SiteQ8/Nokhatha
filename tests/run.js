// Runs the shared vectors, then property checks over wide date ranges.
// node tests/run.js
import { readFileSync } from 'node:fs';
import * as E from '../docs/engine/nokhatha.js';

const root = new URL('..', import.meta.url);
const read = (p) => JSON.parse(readFileSync(new URL(p, root), 'utf8'));
const SEA = read('docs/data/seasons.json');
const V = read('tests/vectors.json');

let pass = 0;
let fail = 0;
const ok = (cond, msg) => {
  if (cond) pass++;
  else {
    fail++;
    console.log('FAIL', msg);
  }
};

function resolve(x) {
  if (x === '$seasons') return SEA.seasons;
  if (x === '$bawarih') return SEA.bawarih;
  if (Array.isArray(x)) return x.map(resolve);
  if (x && typeof x === 'object') return Object.fromEntries(Object.entries(x).map(([k, v]) => [k, resolve(v)]));
  return x;
}

function same(a, b) {
  if (a === b) return true;
  if (typeof a === 'number' && typeof b === 'number') return Math.abs(a - b) < 1e-9;
  if (!a || !b || typeof a !== 'object' || typeof b !== 'object') return false;
  if (Array.isArray(a) !== Array.isArray(b)) return false;
  const ka = Object.keys(a).filter((k) => a[k] !== undefined).sort();
  const kb = Object.keys(b).filter((k) => b[k] !== undefined).sort();
  return ka.length === kb.length && ka.every((k, i) => k === kb[i] && same(a[k], b[k]));
}

/* ---------------------------------------------------------------- vectors */

if (V.engine !== E.VERSION) ok(false, `vectors are for ${V.engine}, engine is ${E.VERSION}`);
for (const c of V.cases) {
  const fn = E[c.fn];
  if (typeof fn !== 'function') {
    ok(false, `missing function ${c.fn}`);
    continue;
  }
  let got;
  try {
    got = fn(...resolve(c.args));
  } catch (e) {
    got = { error: e.message };
  }
  ok(same(got, c.out), `${c.fn}(${JSON.stringify(c.args).slice(1, -1)}) expected ${JSON.stringify(c.out)} got ${JSON.stringify(got)}`);
}
const vectorCount = pass + fail;

/* ------------------------------------------------------------- properties */

// Day numbers round trip for two centuries.
for (let z = E.dayNumber('1900-01-01'); z <= E.dayNumber('2100-12-31'); z++) {
  const iso = E.fromDayNumber(z);
  if (E.dayNumber(iso) !== z) {
    ok(false, `day number round trip at ${z}`);
    break;
  }
}
pass++;

// Every day from 2024 to 2032: the season it is in, and one full ring of the year.
let prev = null;
for (let d = '2024-01-01'; d <= '2032-12-31'; d = E.addDays(d, 1)) {
  const s = E.seasonAt(d, SEA.seasons);
  const r = E.seasonRing(d, SEA.seasons);
  const good = s.start <= d && d < s.next && s.dayIn - 1 + s.daysLeft === s.length
    && (r.total === 365 || r.total === 366)
    && r.segs.length === 14
    && r.segs[0].id === s.id && r.segs[0].offset <= 0 && r.segs[0].offset + r.segs[0].length > 0
    && r.segs.every((g, i) => i === 0 || g.offset === r.segs[i - 1].offset + r.segs[i - 1].length)
    && new Set(r.segs.map((g) => g.id)).size === 14;
  if (!good) {
    ok(false, `season structure on ${d}`);
    break;
  }
  if (prev && prev.id !== s.id) {
    const iPrev = SEA.seasons.findIndex((x) => x.id === prev.id);
    if (SEA.seasons[(iPrev + 1) % 14].id !== s.id || s.start !== d) {
      ok(false, `season order on ${d}`);
      break;
    }
  }
  prev = s;
}
pass++;

// A season task never done is never more than the grace behind, nor more than a year ahead.
for (let d = '2026-01-01'; d <= '2027-12-31'; d = E.addDays(d, 3)) {
  for (const [sid, off] of [['wasm', -21], ['kinna', -28], ['murabbaniya', -14], ['thurayya', -14]]) {
    const due = E.seasonalDue(null, sid, off, d, SEA.seasons);
    const gap = E.diffDays(d, due);
    if (gap < -E.SEASONAL_GRACE || gap > 366) ok(false, `seasonalDue ${sid} on ${d} gave ${due}`);
  }
}
pass++;

// Adding months never overflows the target month and lands on the right month.
for (const start of ['2024-01-31', '2025-02-28', '2026-03-30', '2026-08-31', '2028-02-29']) {
  const { y, m, d } = E.parseISO(start);
  for (let n = -30; n <= 30; n++) {
    const r = E.parseISO(E.addMonths(start, n));
    const t = y * 12 + (m - 1) + n;
    if (r.y * 12 + (r.m - 1) !== t || r.d !== Math.min(d, E.daysInMonth(r.y, r.m))) ok(false, `addMonths ${start} ${n}`);
  }
}
pass++;

// The next renewal is a real renewal, on or after today, and the one before it is in the past.
for (const cycle of Object.keys(E.CYCLES)) {
  for (const anchor of ['2024-01-31', '2025-02-28', '2025-12-31', '2026-05-15']) {
    for (let today = '2026-01-01'; today <= '2026-12-31'; today = E.addDays(today, 5)) {
      const sub = { anchor, cycle };
      const next = E.nextRenewal(sub, today);
      if (next < today) ok(false, `nextRenewal before today ${cycle} ${anchor} ${today}`);
      if (anchor < today) {
        let n = 0;
        while (E.nthRenewal(anchor, cycle, n) < next) n++;
        if (E.nthRenewal(anchor, cycle, n) !== next || (n > 0 && E.nthRenewal(anchor, cycle, n - 1) >= today)) ok(false, `nextRenewal not minimal ${cycle} ${anchor} ${today}`);
      }
    }
  }
}
pass++;

// Charges add up across a split of the range.
for (const cycle of Object.keys(E.CYCLES)) {
  const sub = { anchor: '2025-10-31', cycle };
  for (const mid of ['2026-02-27', '2026-06-30', '2026-11-01']) {
    const all = E.chargesBetween(sub, '2026-01-01', '2026-12-31');
    const a = E.chargesBetween(sub, '2026-01-01', mid);
    const b = E.chargesBetween(sub, E.addDays(mid, 1), '2026-12-31');
    if (all !== a + b) ok(false, `chargesBetween split ${cycle} at ${mid}`);
  }
}
pass++;

// Money survives formatting and reading back, in every currency and both languages.
for (const code of Object.keys(E.CURRENCIES)) {
  for (const minor of [0, 5, 990, 3500, 45000, 123456, 1234567]) {
    for (const lang of ['ar', 'en']) {
      const text = E.formatMoney(minor, code, lang);
      const back = E.parseMoney(lang === 'en' ? text.slice(code.length + 1) : text, code);
      if (back !== minor) ok(false, `money round trip ${minor} ${code} ${lang}: ${text} -> ${back}`);
    }
  }
}
pass++;

// Calendar lines never pass 75 octets, whatever the title.
const long = E.toICS([{ uid: 'x', date: '2026-10-01', title: 'تنظيف المزاريب وفحص عزل السطح قبل الوسم في البيت والشاليه والمزرعة'.repeat(2), note: 'a, b; c\nd', lead: 7 }], { stamp: '20260925T090000Z', calName: 'نُوخذة' });
ok(long.split('\r\n').every((l) => new TextEncoder().encode(l).length <= 75), 'ics line length');
ok(long.endsWith('END:VCALENDAR\r\n'), 'ics ends with CRLF');

console.log(`${vectorCount} vectors and ${pass + fail - vectorCount} property checks: ${pass} passed, ${fail} failed`);
process.exit(fail ? 1 : 0);
