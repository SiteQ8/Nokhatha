// Everything stays on the device: state in localStorage, receipt photos in IndexedDB.

import { addDays, addMonths } from '../engine/nokhatha.js';

const KEY = 'nokhatha.v1';

export function uid() {
  const a = new Uint8Array(6);
  crypto.getRandomValues(a);
  return Array.from(a, (b) => b.toString(16).padStart(2, '0')).join('');
}

export function blank(lang) {
  return {
    v: 1,
    settings: { lang, country: 'KW', theme: 'auto', currency: 'KWD', lead: 7, onboarded: false },
    homes: [],
    cars: [],
    items: [],
    subs: [],
    warranties: [],
    techs: [],
    travel: { done: [] },
  };
}

export function normalize(s) {
  const b = blank((s && s.settings && s.settings.lang) || 'ar');
  const out = { ...b, ...(s || {}), settings: { ...b.settings, ...((s && s.settings) || {}) }, travel: { ...b.travel, ...((s && s.travel) || {}) } };
  for (const k of ['homes', 'cars', 'items', 'subs', 'warranties', 'techs']) if (!Array.isArray(out[k])) out[k] = [];
  if (!Array.isArray(out.travel.done)) out.travel.done = [];
  return out;
}

export function load() {
  try {
    const raw = localStorage.getItem(KEY);
    return raw ? normalize(JSON.parse(raw)) : null;
  } catch {
    return null;
  }
}

export function save(state) {
  try {
    localStorage.setItem(KEY, JSON.stringify(state));
    return true;
  } catch {
    return false;
  }
}

export function wipe() {
  try {
    localStorage.removeItem(KEY);
  } catch {
    /* nothing stored */
  }
}

/* --------------------------------------------------------------- assets */

export const HOME_TYPES = ['house', 'flat', 'chalet', 'farm', 'jakhoor'];

const newItem = (asset, tpl) => ({ id: uid(), asset, tpl, enabled: true, lastDone: null, lastKm: null, due: null, snoozeUntil: null, log: [] });

function wants(t, features) {
  return t.default && (!t.needs || (features && features[t.needs]));
}

export function addHome(state, { type, name, features }, templates) {
  const home = { id: uid(), kind: 'home', type, name, features: { central_ac: false, tank: false, filter: false, ...features } };
  state.homes.push(home);
  for (const t of templates) if (t.kind === 'home' && wants(t, home.features)) state.items.push(newItem(home.id, t.id));
  return home;
}

// Keeps a home's reminders in step with what it has (central AC, tank, filter).
export function syncFeatures(state, home, templates) {
  for (const t of templates) {
    if (t.kind !== 'home' || !t.needs) continue;
    const has = !!home.features[t.needs];
    const it = state.items.find((i) => i.asset === home.id && i.tpl === t.id);
    if (has && !it && t.default) state.items.push(newItem(home.id, t.id));
    if (it) it.enabled = has ? it.enabled !== false || t.default : false;
  }
}

export function addCar(state, { name, km, date, dailyKm }, templates) {
  const car = { id: uid(), kind: 'car', name, dailyKm: dailyKm || 40, readings: km != null && km !== '' ? [{ date, km: Number(km) }] : [] };
  state.cars.push(car);
  for (const t of templates) if (t.kind === 'car' && t.default) state.items.push(newItem(car.id, t.id));
  return car;
}

export function addItem(state, asset, tplId) {
  const existing = state.items.find((i) => i.asset === asset && i.tpl === tplId);
  if (existing) {
    existing.enabled = true;
    return existing;
  }
  const it = newItem(asset, tplId);
  state.items.push(it);
  return it;
}

export function addCustom(state, asset, title, every) {
  const it = { ...newItem(asset, null), title, every };
  state.items.push(it);
  return it;
}

// New homes and cars start with many never-logged tasks. Instead of all of them
// being due on day one, plan their first dates about two a week, shortest interval first.
export function spreadNew(state, assetIds, today, templates) {
  const tpl = Object.fromEntries(templates.map((t) => [t.id, t]));
  const pending = state.items
    .filter((i) => assetIds.includes(i.asset) && i.enabled !== false && !i.lastDone && !i.firstDue)
    .map((i) => ({ i, e: i.every || (tpl[i.tpl] || {}).every || { months: 6 } }))
    .filter(({ e }) => !e.fixed && !e.season)
    .map(({ i, e }) => ({ i, span: e.days || (e.months || 6) * 30 }))
    .sort((a, b) => a.span - b.span);
  pending.forEach(({ i, span }, k) => {
    i.firstDue = addDays(today, Math.min(Math.round(k * 3.5), span));
  });
}

export function removeAsset(state, id) {
  state.homes = state.homes.filter((h) => h.id !== id);
  state.cars = state.cars.filter((c) => c.id !== id);
  state.items = state.items.filter((i) => i.asset !== id);
}

/* ------------------------------------------------------------- receipts */

const DB = 'nokhatha';
const STORE = 'receipts';

function db() {
  return new Promise((resolve, reject) => {
    const r = indexedDB.open(DB, 1);
    r.onupgradeneeded = () => r.result.createObjectStore(STORE);
    r.onsuccess = () => resolve(r.result);
    r.onerror = () => reject(r.error);
  });
}

async function tx(mode, fn) {
  const d = await db();
  return new Promise((resolve, reject) => {
    const t = d.transaction(STORE, mode);
    const out = fn(t.objectStore(STORE));
    t.oncomplete = () => resolve(out && 'result' in out ? out.result : undefined);
    t.onerror = () => reject(t.error);
  });
}

export const putReceipt = (id, blob) => tx('readwrite', (s) => s.put(blob, id));
export const getReceipt = (id) => tx('readonly', (s) => s.get(id));
export const delReceipt = (id) => tx('readwrite', (s) => s.delete(id));
export const clearReceipts = () => tx('readwrite', (s) => s.clear());

export async function allReceipts() {
  const d = await db();
  return new Promise((resolve, reject) => {
    const out = [];
    const t = d.transaction(STORE, 'readonly');
    const req = t.objectStore(STORE).openCursor();
    req.onsuccess = () => {
      const c = req.result;
      if (c) {
        out.push({ id: c.key, blob: c.value });
        c.continue();
      }
    };
    t.oncomplete = () => resolve(out);
    t.onerror = () => reject(t.error);
  });
}

/* ---------------------------------------------------------- sample data */

// A believable household for trying the app, dated relative to today.
export function sample(lang, today, templates) {
  const s = blank(lang);
  s.settings.onboarded = true;
  s.sample = true;
  const T = (ar, en) => (lang === 'ar' ? ar : en);
  const home = addHome(s, { type: 'house', name: T('البيت', 'Home'), features: { tank: true, filter: true } }, templates);
  const chalet = addHome(s, { type: 'chalet', name: T('الشاليه', 'Chalet'), features: { tank: true } }, templates);
  const car = addCar(s, { name: T('سيارتي', 'My car'), km: 66050, date: addDays(today, -10), dailyKm: 40 }, templates);
  car.readings.unshift({ date: addDays(today, -130), km: 61200 });

  const set = (asset, tpl, patch) => {
    const it = s.items.find((i) => i.asset === asset && i.tpl === tpl);
    if (it) Object.assign(it, patch);
  };
  const ago = (n) => addDays(today, -n);
  const cost = (n, amount) => ({ date: ago(n), cost: amount, cur: 'KWD' });

  set(home.id, 'ac_filters', { lastDone: ago(33) });
  set(home.id, 'ac_service', { lastDone: ago(178), log: [cost(178, 25000)] });
  set(home.id, 'water_tank', { lastDone: ago(170), log: [cost(170, 15000)] });
  set(home.id, 'water_filter', { lastDone: ago(84) });
  set(home.id, 'water_heater', { lastDone: ago(305) });
  set(home.id, 'leaks', { lastDone: ago(100) });
  set(home.id, 'seals', { lastDone: ago(122) });
  set(home.id, 'smoke', { lastDone: ago(150) });
  set(home.id, 'extinguisher', { lastDone: ago(200) });
  set(home.id, 'gas_hose', { lastDone: ago(176) });
  set(home.id, 'hood', { lastDone: ago(45) });
  set(home.id, 'pests', { lastDone: ago(96), log: [cost(96, 12000)] });

  for (const i of s.items) if (i.asset === chalet.id && !['ac_filters', 'water_tank', 'pests', 'roof_drains', 'smoke'].includes(i.tpl)) i.enabled = false;
  set(chalet.id, 'ac_filters', { lastDone: ago(20) });
  set(chalet.id, 'water_tank', { lastDone: ago(60) });
  set(chalet.id, 'pests', { lastDone: ago(40), log: [cost(40, 10000)] });
  set(chalet.id, 'smoke', { lastDone: ago(90) });

  set(car.id, 'oil', { lastDone: ago(100), lastKm: 61900, log: [{ ...cost(100, 18500), km: 61900 }] });
  set(car.id, 'air_filter', { lastDone: ago(200), lastKm: 57500 });
  set(car.id, 'cabin_filter', { lastDone: ago(190), lastKm: 58000 });
  set(car.id, 'car_ac', { lastDone: ago(172) });
  set(car.id, 'coolant', { lastDone: ago(165) });
  set(car.id, 'tires', { lastDone: ago(160), log: [cost(160, 120000)] });
  set(car.id, 'battery', { lastDone: ago(158) });
  set(car.id, 'tire_pressure', { lastDone: ago(27) });
  set(car.id, 'brake_fluid', { lastDone: ago(400), lastKm: 50000 });
  set(car.id, 'registration', { due: addDays(today, 21) });
  set(car.id, 'insurance', { due: addDays(today, 21) });

  const sub = (ar, en, amount, cycle, next, back, extra = {}) => ({
    id: uid(), name: T(ar, en), amount, currency: 'KWD', cycle,
    anchor: back ? addMonths(next, -back) : next, category: extra.category || 'other', usage: {}, ...extra,
  });
  s.subs = [
    sub('منصة الأفلام', 'Movie streaming', 3500, 'monthly', addDays(today, 1), 9, { category: 'stream' }),
    sub('الموسيقى', 'Music', 1990, 'monthly', addDays(today, 12), 9, { category: 'music' }),
    sub('التخزين السحابي', 'Cloud storage', 990, 'monthly', addDays(today, 3), 0, { category: 'cloud', trial: true }),
    sub('النادي الرياضي', 'Gym', 45000, 'quarterly', addDays(today, 40), 9, { category: 'gym' }),
    sub('إنترنت البيت', 'Home internet', 15000, 'monthly', addDays(today, 6), 9, { category: 'internet' }),
    sub('برنامج التصميم', 'Design app', 35000, 'yearly', addDays(today, 64), 12, { category: 'apps' }),
  ];
  s.warranties = [
    { id: uid(), name: T('الثلاجة', 'Fridge'), store: T('معرض الأجهزة', 'Appliance store'), bought: ago(300), months: 24 },
    { id: uid(), name: T('مكيف الصالة', 'Living room AC'), store: T('وكيل المكيفات', 'AC dealer'), bought: addMonths(addDays(today, 26), -24), months: 24 },
  ];
  spreadNew(s, [home.id, chalet.id, car.id], today, templates);
  s.techs = [
    { id: uid(), name: T('أبو محمد', 'Abu Mohammed'), trade: 'ac', phone: '12345678' },
    { id: uid(), name: T('أبو علي', 'Abu Ali'), trade: 'plumber', phone: '12345679' },
    { id: uid(), name: T('كراج الشويخ', 'Shuwaikh garage'), trade: 'mechanic', phone: '12345680' },
  ];
  return s;
}
