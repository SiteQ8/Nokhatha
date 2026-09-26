// Writes tests/fixtures/parity.json: the web app's sample household on a fixed day,
// with the tasks and subscriptions exactly as the web app evaluates and orders them.
// The iPhone tests read the same state and must reach the same answers.
// node tests/fixtures/make-parity.mjs
import { readFileSync, writeFileSync } from 'node:fs';
import * as E from '../../docs/engine/nokhatha.js';
import * as S from '../../docs/app/store.js';

const root = new URL('../../', import.meta.url);
const read = (p) => JSON.parse(readFileSync(new URL(p, root), 'utf8'));
const seasons = read('docs/data/seasons.json');
const tasks = read('docs/data/tasks.json');
const today = '2026-09-25';

// deterministic ids so the fixture does not change on every run
let n = 0;
globalThis.crypto.getRandomValues = (a) => { for (let i = 0; i < a.length; i++) a[i] = (n * 7 + i * 13) % 256; n++; return a; };

const state = S.sample('ar', today, tasks.templates);
const tpl = Object.fromEntries(tasks.templates.map((t) => [t.id, t]));
const asset = (id) => state.homes.find((h) => h.id === id) || state.cars.find((c) => c.id === id) || state.things.find((x) => x.id === id);
const rank = { overdue: 0, today: 1, soon: 2, unset: 3, ok: 4 };
const evals = state.items.filter((i) => i.enabled !== false && asset(i.asset)).map((it) => {
  const a = asset(it.asset);
  const every = it.every || (tpl[it.tpl] || {}).every || { months: 6 };
  const nd = E.nextDue({ ...it, every }, { today, seasons: seasons.seasons, bawarih: seasons.bawarih, heat: seasons.heat, car: a.kind === 'car' ? a : null });
  const lead = every.fixed ? every.lead || 30 : state.settings.lead;
  const st = E.statusOf(nd.due, today, lead);
  return { id: it.id, due: nd.due, by: nd.by, status: st.status, days: st.days };
}).sort((a, b) => rank[a.status] - rank[b.status] || (a.due || '9999-12-31').localeCompare(b.due || '9999-12-31'));
const subs = state.subs.map((s) => {
  const next = E.nextRenewal(s, today);
  return { id: s.id, next, days: E.diffDays(today, next) };
});
const totals = E.subTotals(state.subs);
writeFileSync(new URL('tests/fixtures/parity.json', root), JSON.stringify({ today, state, tasks: evals, subs, totals }, null, 1) + '\n');
console.log(`parity fixture: ${evals.length} tasks, ${subs.length} subscriptions`);
