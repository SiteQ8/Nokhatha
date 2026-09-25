// Nokhatha web app. Plain modules, no framework, no network after the first load.

import * as E from '../engine/nokhatha.js';
import { icon, mark } from './icons.js';
import { dialSVG } from './dial.js';
import * as S from './store.js';
import { encryptBackup, decryptBackup, blobToB64, b64ToBlob } from './backup.js';

const $ = (sel, el = document) => el.querySelector(sel);
const $$ = (sel, el = document) => [...el.querySelectorAll(sel)];
const esc = (v) => String(v ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const pad = (n) => String(n).padStart(2, '0');
const nowISO = () => {
  const d = new Date();
  return E.toISO(d.getFullYear(), d.getMonth() + 1, d.getDate());
};
const calm = () => matchMedia('(prefers-reduced-motion: reduce)').matches;

let D;
let state;
let TODAY;
let draft = null;
let introDone = false;
let undoFn = null;
let sheet = null;
let swWaiting = null;

/* ------------------------------------------------------------- language */

const L = () => state.settings.lang;
function t(key, vars) {
  const tab = D.strings[L()] || D.strings.ar;
  const s = tab[key] ?? D.strings.ar[key] ?? key;
  return vars ? s.replace(/\{(\w+)\}/g, (_, k) => (vars[k] ?? '')) : s;
}
const nm = (o) => (o ? o[L()] ?? o.ar : '');
const comma = () => (L() === 'ar' ? '، ' : ', ');
const money = (minor, cur) => E.formatMoney(minor, cur, L());
const dateText = (iso) => E.formatDate(iso, L(), E.parseISO(TODAY).y);
const rel = (days) => E.relative(days, L());
const fmtInt = (n) => String(n).replace(/\B(?=(\d{3})+(?!\d))/g, ',');
const kmText = (n) => (L() === 'ar' ? `${fmtInt(n)} كم` : `${fmtInt(n)} km`);
const dayCount = (n) => (L() === 'ar' ? E.countAr(n, 'day') : `${n} day${n === 1 ? '' : 's'}`);
const monthCount = (n) => (L() === 'ar' ? E.countAr(n, 'month') : `${n} month${n === 1 ? '' : 's'}`);

/* ----------------------------------------------------------------- data */

async function loadData() {
  const get = (n) => fetch(`../data/${n}.json`).then((r) => {
    if (!r.ok) throw new Error(n);
    return r.json();
  });
  const [seasons, tasks, strings] = await Promise.all([get('seasons'), get('tasks'), get('strings')]);
  D = {
    seasons: seasons.seasons, groups: seasons.groups, bawarih: seasons.bawarih,
    templates: tasks.templates, areas: tasks.areas, trades: tasks.trades, travel: tasks.travel, strings,
  };
  D.tpl = Object.fromEntries(D.templates.map((x) => [x.id, x]));
  D.season = Object.fromEntries(D.seasons.map((x) => [x.id, x]));
  D.trade = Object.fromEntries(D.trades.map((x) => [x.id, x]));
}

const CATS = [
  ['stream', 'play'], ['music', 'music'], ['cloud', 'cloud'], ['games', 'game'], ['gym', 'gym'],
  ['internet', 'wifi'], ['phone', 'phone'], ['apps', 'apps'], ['other', 'repeat'],
];
const catIcon = (c) => (CATS.find((x) => x[0] === c) || CATS[CATS.length - 1])[1];
const CYCLES = ['weekly', 'monthly', 'quarterly', 'semiannual', 'yearly'];

/* ------------------------------------------------------------ evaluation */

const findAsset = (id) => state.homes.find((h) => h.id === id) || state.cars.find((c) => c.id === id);
const tplOf = (it) => (it.tpl ? D.tpl[it.tpl] : null);
const everyOf = (it) => it.every || (tplOf(it) || {}).every || { months: 6 };

function evalItem(it) {
  const asset = findAsset(it.asset);
  const every = everyOf(it);
  const car = asset && asset.kind === 'car' ? asset : null;
  const nd = E.nextDue({ ...it, every }, { today: TODAY, seasons: D.seasons, bawarih: D.bawarih, car });
  const lead = every.fixed ? every.lead || 30 : state.settings.lead;
  const st = E.statusOf(nd.due, TODAY, lead);
  return { it, asset, every, tpl: tplOf(it), due: nd.due, by: nd.by, status: st.status, days: st.days };
}

const RANK = { overdue: 0, today: 1, soon: 2, unset: 3, ok: 4 };
function byUrgency(a, b) {
  return RANK[a.status] - RANK[b.status] || (a.due || '9999-12-31').localeCompare(b.due || '9999-12-31');
}

function items(filter) {
  return state.items
    .filter((i) => i.enabled !== false && findAsset(i.asset) && (!filter || filter(i)))
    .map(evalItem)
    .sort(byUrgency);
}

function evalSub(s) {
  const next = E.nextRenewal(s, TODAY);
  const days = E.diffDays(TODAY, next);
  const answer = s.usage ? s.usage[next] : null;
  return {
    s, next, days, answer,
    trial: !!s.trial && s.anchor >= TODAY,
    status: s.cancelled ? 'off' : E.statusOf(next, TODAY, 3).status,
    ask: !s.cancelled && days <= 7 && !answer,
    planned: !s.cancelled && days <= 7 && answer === 'no',
  };
}

function evalWarranty(w) {
  const end = E.addMonths(w.bought, w.months);
  return { w, end, ...E.statusOf(end, TODAY, 30) };
}

const itemTitle = (ev) => (ev.tpl ? nm(ev.tpl) : ev.it.title);
const why = (tpl) => (tpl ? tpl['why_' + L()] || tpl.why_ar : '');

/* --------------------------------------------------------------- pieces */

function dueMeta(ev) {
  if (ev.status === 'unset') return `<span class="rel">${t('due.unset')}</span>`;
  let r;
  if (ev.every.fixed) {
    r = ev.days < 0 ? t('due.expired', { rel: rel(ev.days) }) : t('due.expires', { rel: rel(ev.days) });
  } else if (ev.status === 'overdue') {
    r = ev.days === -1 ? t('due.overdue_yesterday') : t('due.overdue', { rel: rel(ev.days) });
  } else {
    r = ev.status === 'today' ? t('due.today') : t('due.in', { rel: rel(ev.days) });
  }
  const extra = ev.by === 'km' && ev.it.lastKm != null
    ? `<span class="date">${t('due.km', { km: kmText(ev.it.lastKm + ev.every.km) })}</span>`
    : `<span class="date">${dateText(ev.due)}</span>`;
  return `<span class="rel">${r}</span>${extra}`;
}

function doneBtn(ev) {
  const id = esc(ev.it.id);
  if (ev.every.fixed) {
    if (!ev.due) return `<button class="done txt" data-act="item" data-id="${id}">${t('act.setdate')}</button>`;
    return `<button class="done txt" data-act="renew" data-id="${id}">${t('act.renewed')}</button>`;
  }
  return `<button class="done" data-act="done" data-id="${id}" aria-label="${esc(t('act.done_label', { title: itemTitle(ev) }))}">${icon('done')}</button>`;
}

function row(ev, showAsset = false) {
  const title = itemTitle(ev);
  const p = ev.every.fixed || !ev.it.lastDone || !ev.due ? null : E.cycleProgress(ev.it.lastDone, ev.due, TODAY);
  return `<li class="row s-${ev.status}" data-row="${esc(ev.it.id)}">
<button class="row-body" data-act="item" data-id="${esc(ev.it.id)}">
<span class="row-ic">${icon(ev.tpl ? ev.tpl.icon : 'spark')}</span>
<span class="row-main"><span class="row-title">${esc(title)}</span>
<span class="row-meta">${dueMeta(ev)}${showAsset && ev.asset ? `<span class="asset">${esc(ev.asset.name)}</span>` : ''}</span>
${p == null ? '' : `<span class="weave" data-p="${p.toFixed(3)}"><i></i></span>`}</span>
</button>${doneBtn(ev)}</li>`;
}

function pageHead(title, band, extra = '', back = false) {
  return `${back ? `<a class="back" href="#/more">${icon('back', 'flip')}<span>${t('tab.more')}</span></a>` : ''}
<div class="ph"><h1 class="h1">${esc(title)}</h1></div>${extra}<div class="band band-${band}" aria-hidden="true"></div>`;
}

function assetChips(list, cur, kind) {
  return `<div class="chips">${list.map((a) => `<a class="chip${a.id === cur.id ? ' on' : ''}" href="#/${kind}/${esc(a.id)}"${a.id === cur.id ? ' aria-current="page"' : ''}>${esc(a.name)}</a>`).join('')}
<button class="chip chip-add" data-act="add-${kind}">${icon('plus')}<span>${t('act.add_' + kind)}</span></button></div>`;
}

function everyText(e) {
  if (e.fixed) return t('every.fixed', { n: e.repeat === 12 ? t('every.year') : monthCount(e.repeat || 12) });
  if (e.season) {
    const s = nm(D.season[e.season]);
    return e.offset ? t('every.before', { season: s, n: dayCount(-e.offset) }) : t('every.with', { season: s });
  }
  const parts = [];
  if (e.km) parts.push(kmText(e.km));
  if (e.months) parts.push(monthCount(e.months));
  if (e.days) parts.push(dayCount(e.days));
  let s = e.km ? t('every.km', { km: parts[0], time: parts[1] }) : t('every.plain', { n: parts[0] });
  if (e.bawarih) s += t('every.bawarih', { n: dayCount(e.bawarih) });
  return s;
}

function greeting() {
  const h = new Date().getHours();
  return h >= 4 && h < 12 ? t('greet.morning') : t('greet.evening');
}

function longDate(iso) {
  return `${E.WEEKDAYS[L()][E.weekday(iso)]} ${dateText(iso)}`;
}

function seasonCenter(season) {
  const sN = D.season[season.id];
  const next = D.season[season.nextId];
  return {
    title: nm(sN),
    line1: `${dateText(season.start)} ${t('dial.to')} ${dateText(E.addDays(season.next, -1))}`,
    line2: t('dial.left', { n: dayCount(season.daysLeft), next: nm(next) }),
    aria: t('dial.aria', { season: nm(sN), left: t('dial.left', { n: dayCount(season.daysLeft), next: nm(next) }) }),
  };
}

function techFor(trade) {
  return trade ? state.techs.find((x) => x.trade === trade) : null;
}

function phoneDigits(p) {
  let d = String(p || '').replace(/[^\d+]/g, '');
  d = E.normalizeDigits(d);
  if (d.startsWith('+')) d = d.slice(1);
  if (d.startsWith('00')) d = d.slice(2);
  if (d.length === 8) d = '965' + d;
  return d;
}

function techLinks(tech) {
  const d = phoneDigits(tech.phone);
  return `<a class="btn" href="tel:+${esc(d)}">${icon('phone')}<span>${t('tech.call')}</span></a>
<a class="btn" href="https://wa.me/${esc(d)}" target="_blank" rel="noopener noreferrer">${icon('chat')}<span>${t('tech.whatsapp')}</span></a>`;
}

/* ---------------------------------------------------------------- views */

function viewToday() {
  if (!state.homes.length && !state.cars.length && !state.subs.length) {
    return `<div class="empty big">${mark('mark-lg')}<p>${t('today.empty')}</p><a class="btn btn-primary" href="#/welcome/2">${t('act.setup')}</a></div>`;
  }
  const evs = items();
  const now = evs.filter((e) => ['overdue', 'today', 'soon'].includes(e.status));
  const later = evs.filter((e) => e.status === 'ok' && e.days <= 30).slice(0, 6);
  const subs = state.subs.map(evalSub);
  const talk = subs.filter((x) => x.ask || x.planned);
  const warr = state.warranties.map(evalWarranty).filter((x) => ['soon', 'today'].includes(x.status));
  const season = E.seasonAt(TODAY, D.seasons);
  const dots = [
    ...evs.filter((e) => e.due).map((e) => ({ days: e.days, status: e.status, label: itemTitle(e) })),
    ...subs.filter((x) => !x.s.cancelled).map((x) => ({ days: x.days, status: 'sub', label: x.s.name })),
  ];
  const late = evs.filter((e) => e.status === 'overdue').length;
  const dial = dialSVG({ today: TODAY, seasons: D.seasons, groups: D.groups, lang: L(), dots, mode: 'compact', id: 'today', center: seasonCenter(season), lateLabel: t('dial.late', { n: late }) });
  const intro = !introDone && !calm();
  introDone = true;
  const totals = E.subTotals(state.subs);
  const cur = totals[state.settings.currency] ? state.settings.currency : Object.keys(totals)[0];
  return `<div class="today">
<section class="today-dial">
<p class="greet"><span>${greeting()}</span><span class="greet-d">${longDate(TODAY)}</span></p>
<div class="dial-wrap${intro ? ' intro' : ''}">${dial}</div>
<p class="tip">${icon('spark')}<span>${esc(D.season[season.id]['hint_' + L()])}</span></p>
</section>
<section class="today-list">
${installTip()}
<div class="sec"><h2>${t('today.now')}</h2>${now.length ? `<span class="count">${now.length}</span>` : ''}</div>
${now.length ? `<ul class="list">${now.map((e) => row(e, true)).join('')}</ul>` : `<div class="empty">${icon('done')}<p>${t('today.clear')}</p></div>`}
${talk.length ? askCard(talk[0]) : ''}
${talk.length > 1 ? `<a class="more-asks" href="#/subs">${t('today.more_asks')}</a>` : ''}
${cur ? `<a class="strip" href="#/subs">${icon('repeat')}<span>${t('today.subs', { amount: money(totals[cur].month, cur) })}</span>${icon('next', 'flip chev')}</a>` : ''}
${warr.length ? `<div class="sec"><h2>${t('today.warranties')}</h2></div><ul class="list">${warr.map(warrantyRow).join('')}</ul>` : ''}
${later.length ? `<div class="sec"><h2>${t('today.later')}</h2></div><ul class="list">${later.map((e) => row(e, true)).join('')}</ul>` : ''}
</section></div>`;
}

function askCard(x) {
  const id = esc(x.s.id);
  const name = esc(x.s.name);
  if (x.planned) {
    return `<div class="ask no"><p class="ask-q">${t('ask.cancel_title', { name })}</p><p class="ask-d">${t('ask.cancel_body')}</p>
${x.s.note ? `<p class="ask-note">${esc(x.s.note)}</p>` : ''}
<div class="ask-b"><button class="btn btn-primary" data-act="sub-cancelled" data-id="${id}">${t('ask.cancelled')}</button><button class="btn btn-quiet" data-act="sub-keep" data-id="${id}">${t('ask.keep')}</button></div></div>`;
  }
  const when = x.trial
    ? (x.days === 0 ? t('sub.trial_today') : t('sub.trial', { rel: rel(x.days) }))
    : (x.days === 0 ? t('sub.renews_today') : t('sub.renews', { rel: rel(x.days) }));
  return `<div class="ask${x.trial ? ' trial' : ''}"><p class="ask-q">${t(x.trial ? 'ask.q_trial' : 'ask.q', { name })}</p><p class="ask-d">${when}${comma()}${esc(money(x.s.amount, x.s.currency))}</p>
<div class="ask-b"><button class="btn" data-act="sub-yes" data-id="${id}">${t('ask.yes')}</button><button class="btn btn-quiet" data-act="sub-no" data-id="${id}">${t('ask.no')}</button></div></div>`;
}

// Safari on iPhone clears storage of sites left unopened for a while; installed web apps are exempt.
function installTip() {
  const ios = /iPad|iPhone|iPod/.test(navigator.userAgent) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
  const installed = navigator.standalone === true || matchMedia('(display-mode: standalone)').matches;
  if (!ios || installed || state.settings.installTipOff) return '';
  return `<div class="install">${icon('upload')}<div><p class="install-t">${t('tip.install_title')}</p><p class="install-b">${t('tip.install_body')}</p>
<button class="btn btn-quiet" data-act="install-ok">${t('act.got_it')}</button></div></div>`;
}

function emptyAsset(kind) {
  return `<div class="empty big">${icon(kind === 'home' ? 'home' : 'car', 'ic-xl')}<p>${t('empty.' + kind)}</p><button class="btn btn-primary" data-act="add-${kind}">${icon('plus')}<span>${t('act.add_' + kind)}</span></button></div>`;
}

function groupedRows(evs, areas) {
  return areas
    .map((a) => ({ a, evs: evs.filter((e) => (e.tpl ? e.tpl.area : 'custom') === a.id) }))
    .filter((g) => g.evs.length)
    .map((g) => `<div class="sec sec-sm"><h3>${esc(nm(g.a))}</h3></div><ul class="list">${g.evs.map((e) => row(e)).join('')}</ul>`)
    .join('');
}

function viewHome(r) {
  if (!state.homes.length) return pageHead(t('tab.home'), 'home') + emptyAsset('home');
  const cur = state.homes.find((h) => h.id === r.id) || state.homes[0];
  const evs = items((i) => i.asset === cur.id);
  return `${pageHead(t('tab.home'), 'home', assetChips(state.homes, cur, 'home'))}
${groupedRows(evs, D.areas.home)}
<div class="actions"><button class="btn" data-act="add-task" data-id="${esc(cur.id)}">${icon('plus')}<span>${t('act.add_task')}</span></button>
<button class="btn btn-quiet" data-act="edit-home" data-id="${esc(cur.id)}">${icon('edit')}<span>${t('act.edit_home')}</span></button></div>`;
}

function viewCar(r) {
  if (!state.cars.length) return pageHead(t('tab.car'), 'car') + emptyAsset('car');
  const cur = state.cars.find((c) => c.id === r.id) || state.cars[0];
  const km = E.kmOn(cur, TODAY);
  const last = E.lastReading(cur);
  const evs = items((i) => i.asset === cur.id);
  return `${pageHead(t('tab.car'), 'car', assetChips(state.cars, cur, 'car'))}
<div class="odo"><div class="odo-t"><span class="odo-l">${t('car.odo')}</span>
<span class="odo-v">${km != null ? kmText(km) : t('car.odo_unknown')}</span>
<span class="odo-s">${last ? t('car.odo_last', { km: kmText(last.km), date: dateText(last.date) }) : t('car.odo_none')}</span></div>
<button class="btn" data-act="odo" data-id="${esc(cur.id)}">${icon('gauge')}<span>${t('act.update_odo')}</span></button></div>
${groupedRows(evs, D.areas.car)}
<div class="actions"><button class="btn" data-act="add-task" data-id="${esc(cur.id)}">${icon('plus')}<span>${t('act.add_task')}</span></button>
<button class="btn btn-quiet" data-act="edit-car" data-id="${esc(cur.id)}">${icon('edit')}<span>${t('act.edit_car')}</span></button></div>`;
}

function subRow(x) {
  let meta;
  if (x.s.cancelled) meta = `<span class="rel">${t('sub.cancelled')}</span>`;
  else if (x.trial) meta = `<span class="rel">${x.days === 0 ? t('sub.trial_today') : t('sub.trial', { rel: rel(x.days) })}</span>`;
  else meta = `<span class="rel">${x.days === 0 ? t('sub.renews_today') : t('sub.renews', { rel: rel(x.days) })}</span><span class="date">${dateText(x.next)}</span>`;
  return `<li class="row s-${x.s.cancelled ? 'off' : x.status}${x.trial ? ' trial' : ''}"><button class="row-body" data-act="sub" data-id="${esc(x.s.id)}">
<span class="row-ic">${icon(catIcon(x.s.category))}</span>
<span class="row-main"><span class="row-title">${esc(x.s.name)}</span><span class="row-meta">${meta}</span></span>
<span class="row-amt"><b>${esc(money(x.s.amount, x.s.currency))}</b><small>${t('cycle.' + x.s.cycle)}</small></span></button></li>`;
}

function viewSubs() {
  const subs = state.subs.map(evalSub).sort((a, b) => Number(!!a.s.cancelled) - Number(!!b.s.cancelled) || a.next.localeCompare(b.next));
  const totals = E.subTotals(state.subs);
  const curs = Object.keys(totals);
  const main = totals[state.settings.currency] ? state.settings.currency : curs[0];
  const talk = subs.filter((x) => x.ask || x.planned);
  const head = pageHead(t('tab.subs'), 'subs');
  if (!state.subs.length) {
    return `${head}<div class="empty big">${icon('repeat', 'ic-xl')}<p>${t('empty.subs')}</p><button class="btn btn-primary" data-act="add-sub">${icon('plus')}<span>${t('act.add_sub')}</span></button></div>`;
  }
  const others = curs.filter((c) => c !== main).map((c) => `<span class="total-o">${esc(money(totals[c].month, c))} ${t('cycle.monthly')}</span>`).join('');
  return `${head}
${main ? `<div class="total"><span class="total-l">${t('subs.month')}</span><span class="big">${esc(money(totals[main].month, main))}</span>
<span class="total-s">${t('subs.year', { amount: money(totals[main].year, main) })}</span>${others}</div>` : ''}
${talk.map(askCard).join('')}
<div class="sec"><h2>${t('subs.all')}</h2><span class="count">${state.subs.filter((s) => !s.cancelled).length}</span></div>
<ul class="list">${subs.map(subRow).join('')}</ul>
<div class="actions"><button class="btn" data-act="add-sub">${icon('plus')}<span>${t('act.add_sub')}</span></button></div>`;
}

function viewMore() {
  const entries = [
    ['warranties', 'seal', 'more.warranties', state.warranties.length || null],
    ['techs', 'wrench', 'more.techs', state.techs.length || null],
    ['travel', 'plane', 'more.travel', state.travel.done.length ? `${state.travel.done.length}/${D.travel.length}` : null],
    ['spend', 'wallet', 'more.spend', null],
    ['settings', 'sliders', 'more.settings', null],
    ['about', 'info', 'more.about', null],
  ];
  return `${pageHead(t('tab.more'), 'more')}<ul class="list nav-list">${entries.map(([r, ic, k, n]) => `<li><a class="nav-row" href="#/${r}">
<span class="row-ic">${icon(ic)}</span><span class="nav-l">${t(k)}</span>${n != null ? `<span class="nav-n">${esc(String(n))}</span>` : ''}${icon('next', 'flip chev')}</a></li>`).join('')}</ul>`;
}

function warrantyRow(x) {
  const r = x.status === 'overdue' ? t('w.ended', { rel: rel(x.days) }) : x.status === 'today' ? t('w.today') : t('w.ends', { rel: rel(x.days) });
  return `<li class="row s-${x.status}"><button class="row-body" data-act="warranty" data-id="${esc(x.w.id)}">
<span class="row-ic">${icon('seal')}</span><span class="row-main"><span class="row-title">${esc(x.w.name)}</span>
<span class="row-meta"><span class="rel">${r}</span><span class="date">${dateText(x.end)}</span>${x.w.store ? `<span class="asset">${esc(x.w.store)}</span>` : ''}</span></span>
${x.w.receipt ? `<span class="row-tag">${icon('receipt')}</span>` : ''}</button></li>`;
}

function viewWarranties() {
  const ws = state.warranties.map(evalWarranty).sort((a, b) => a.end.localeCompare(b.end));
  const active = ws.filter((x) => x.status !== 'overdue');
  const ended = ws.filter((x) => x.status === 'overdue');
  return `${pageHead(t('more.warranties'), 'more', '', true)}
<p class="lede">${t('w.lede')}</p>
${ws.length ? '' : `<div class="empty">${icon('seal', 'ic-xl')}<p>${t('empty.warranties')}</p></div>`}
${active.length ? `<ul class="list">${active.map(warrantyRow).join('')}</ul>` : ''}
${ended.length ? `<div class="sec sec-sm"><h3>${t('w.ended_h')}</h3></div><ul class="list">${ended.map(warrantyRow).join('')}</ul>` : ''}
<div class="actions"><button class="btn" data-act="add-warranty">${icon('plus')}<span>${t('act.add_warranty')}</span></button></div>`;
}

function viewTechs() {
  const byTrade = D.trades.map((tr) => ({ tr, list: state.techs.filter((x) => x.trade === tr.id) })).filter((g) => g.list.length);
  return `${pageHead(t('more.techs'), 'more', '', true)}
<p class="lede">${t('tech.lede')}</p>
${state.techs.length ? '' : `<div class="empty">${icon('wrench', 'ic-xl')}<p>${t('empty.techs')}</p></div>`}
${byTrade.map((g) => `<div class="sec sec-sm"><h3>${esc(nm(g.tr))}</h3></div><ul class="list">${g.list.map((x) => `<li class="row tech">
<button class="row-body" data-act="tech" data-id="${esc(x.id)}"><span class="row-ic">${icon('wrench')}</span>
<span class="row-main"><span class="row-title">${esc(x.name)}</span><span class="row-meta"><span class="date ltr">${esc(x.phone)}</span>${x.note ? `<span class="asset">${esc(x.note)}</span>` : ''}</span></span></button>
<span class="tech-b">${techLinks(x)}</span></li>`).join('')}</ul>`).join('')}
<div class="actions"><button class="btn" data-act="add-tech">${icon('plus')}<span>${t('act.add_tech')}</span></button></div>`;
}

function viewTravel() {
  const done = new Set(state.travel.done);
  return `${pageHead(t('more.travel'), 'more', '', true)}
<p class="lede">${t('travel.lede')}</p>
<p class="progress-l">${t('travel.progress', { n: done.size, of: D.travel.length })}</p>
<ul class="list checks">${D.travel.map((x) => `<li><label class="check-row"><input type="checkbox" data-act="travel" value="${esc(x.id)}"${done.has(x.id) ? ' checked' : ''}>
<span class="box">${icon('done')}</span><span>${esc(nm(x))}</span></label></li>`).join('')}</ul>
<div class="actions"><button class="btn btn-quiet" data-act="travel-reset">${icon('repeat')}<span>${t('travel.reset')}</span></button></div>`;
}

function viewSpend(r) {
  const year = Number(r.id) || E.parseISO(TODAY).y;
  const from = `${year}-01-01`;
  const to = `${year}-12-31`;
  const upto = E.minISO(to, TODAY);
  const sums = {};
  const add = (cur, cat, v) => {
    const s = (sums[cur] ||= { home: 0, car: 0, subs: 0, projected: 0 });
    s[cat] += v;
  };
  const logs = [];
  for (const it of state.items) {
    for (const l of it.log || []) {
      if (l.cost == null || l.date < from || l.date > to) continue;
      const asset = findAsset(it.asset);
      add(l.cur || state.settings.currency, asset && asset.kind === 'car' ? 'car' : 'home', l.cost);
      logs.push({ l, ev: { it, tpl: tplOf(it) }, asset });
    }
  }
  for (const s of state.subs) {
    const stop = s.cancelled && s.cancelledOn ? s.cancelledOn : null;
    const n = E.chargesBetween(s, from, stop ? E.minISO(upto, stop) : upto);
    const all = E.chargesBetween(s, from, stop ? E.minISO(to, stop) : to);
    add(s.currency, 'subs', n * s.amount);
    sums[s.currency].projected += all * s.amount;
  }
  logs.sort((a, b) => b.l.date.localeCompare(a.l.date));
  const blocks = Object.entries(sums).map(([cur, s]) => {
    const total = s.home + s.car + s.subs;
    const max = Math.max(s.home, s.car, s.subs, 1);
    const bar = (k, ic) => `<div class="bar"><span class="bar-l">${icon(ic)}${t('spend.' + k)}</span><span class="bar-v">${esc(money(s[k], cur))}</span>
<span class="bar-t"><i data-p="${(s[k] / max).toFixed(3)}"></i></span></div>`;
    return `<div class="total"><span class="total-l">${t('spend.total', { year })}</span><span class="big">${esc(money(total, cur))}</span>
${year === E.parseISO(TODAY).y ? `<span class="total-s">${t('spend.projected', { amount: money(s.projected + s.home + s.car, cur) })}</span>` : ''}
<div class="bars">${bar('home', 'home')}${bar('car', 'car')}${bar('subs', 'repeat')}</div></div>`;
  }).join('');
  return `${pageHead(t('more.spend'), 'more', '', true)}
<div class="year-nav"><a class="btn btn-quiet" href="#/spend/${year - 1}">${icon('back', 'flip')}<span>${year - 1}</span></a><strong>${year}</strong>
${year < E.parseISO(TODAY).y ? `<a class="btn btn-quiet" href="#/spend/${year + 1}"><span>${year + 1}</span>${icon('next', 'flip')}</a>` : '<span></span>'}</div>
${blocks || `<div class="empty">${icon('wallet', 'ic-xl')}<p>${t('empty.spend')}</p></div>`}
<p class="lede small">${t('spend.note')}</p>
${logs.length ? `<div class="sec sec-sm"><h3>${t('spend.logged')}</h3></div><ul class="list">${logs.map(({ l, ev, asset }) => `<li class="row plain"><span class="row-main">
<span class="row-title">${esc(ev.tpl ? nm(ev.tpl) : ev.it.title)}</span><span class="row-meta"><span class="date">${dateText(l.date)}</span>${asset ? `<span class="asset">${esc(asset.name)}</span>` : ''}</span></span>
<span class="row-amt"><b>${esc(money(l.cost, l.cur || state.settings.currency))}</b></span></li>`).join('')}</ul>` : ''}`;
}

function seg(name, value, options) {
  return `<div class="segc" role="group" data-seg="${name}">${options.map(([v, label]) => `<button type="button" data-act="set" data-name="${name}" data-v="${v}" class="${String(value) === String(v) ? 'on' : ''}" aria-pressed="${String(value) === String(v)}">${label}</button>`).join('')}</div>`;
}

function viewSettings() {
  const st = state.settings;
  return `${pageHead(t('more.settings'), 'more', '', true)}
<div class="setting"><span class="setting-l">${icon('globe')}${t('settings.lang')}</span>${seg('lang', st.lang, [['ar', 'عربي'], ['en', 'English']])}</div>
<div class="setting"><span class="setting-l">${icon('sun')}${t('settings.theme')}</span>${seg('theme', st.theme, [['auto', t('settings.auto')], ['light', t('settings.light')], ['dark', t('settings.dark')]])}</div>
<div class="setting"><span class="setting-l">${icon('wallet')}${t('settings.currency')}</span>
<select class="input" data-act="currency" aria-label="${esc(t('settings.currency'))}">${Object.keys(E.CURRENCIES).map((c) => `<option value="${c}"${c === st.currency ? ' selected' : ''}>${c} ${esc(t('cur.' + c))}</option>`).join('')}</select></div>
<div class="setting"><span class="setting-l">${icon('snooze')}${t('settings.lead')}</span>${seg('lead', st.lead, [[3, dayCount(3)], [7, dayCount(7)], [14, dayCount(14)]])}</div>
<div class="sec sec-sm"><h3>${t('settings.calendar')}</h3></div>
<p class="lede small">${t('settings.calendar_body')}</p>
<button class="btn btn-block" data-act="ics">${icon('calendar')}<span>${t('act.ics')}</span></button>
<div class="sec sec-sm"><h3>${t('settings.backup')}</h3></div>
<p class="lede small">${t('settings.backup_body')}</p>
<p class="backup-when">${icon(st.lastBackup ? 'done' : 'info')}<span>${st.lastBackup ? t('settings.last_backup', { date: dateText(st.lastBackup) }) : t('settings.no_backup')}</span></p>
<div class="actions two"><button class="btn" data-act="backup">${icon('lock')}<span>${t('act.backup')}</span></button><button class="btn" data-act="restore">${icon('upload')}<span>${t('act.restore')}</span></button></div>
<div class="sec sec-sm"><h3>${t('settings.data')}</h3></div>
<div class="actions two"><button class="btn" data-act="demo">${icon('spark')}<span>${t('welcome.demo')}</span></button><button class="btn btn-danger" data-act="wipe">${icon('trash')}<span>${t('act.wipe')}</span></button></div>`;
}

function viewAbout() {
  return `${pageHead(t('more.about'), 'more', '', true)}
<div class="about">${mark('mark-lg')}<h2 class="about-name">${t('app.name')}</h2><p class="about-v">${t('about.version', { v: E.VERSION })}</p></div>
<p class="lede">${t('about.name')}</p>
<div class="sec sec-sm"><h3>${t('about.privacy_h')}</h3></div>
<p class="lede">${t('about.privacy')}</p>
<p class="lede">${t('about.remind')}</p>
<p class="lede">${t('about.keep')}</p>
<div class="sec sec-sm"><h3>${t('about.open_h')}</h3></div>
<p class="lede">${t('about.open')}</p>
<div class="actions two"><a class="btn" href="https://github.com/SiteQ8/Nokhatha" target="_blank" rel="noopener noreferrer">${icon('code')}<span>${t('about.source')}</span></a>
<a class="btn" href="https://nokhatha.3li.info" target="_blank" rel="noopener noreferrer">${icon('globe')}<span>nokhatha.3li.info</span></a></div>
<p class="fine">${t('about.copyright')}</p>`;
}

/* ----------------------------------------------------------- onboarding */

const LAST_KEYS = ['ac_filters', 'pests', 'water_tank', 'water_filter', 'hood', 'smoke', 'oil', 'tire_pressure'];
const LAST_OPTS = [['unknown', null], ['month', 15], ['m3', 90], ['m6', 180], ['year', 365]];

function viewWelcome() {
  return `<div class="welcome">
${mark('mark-xl')}
<h1 class="w-name">${t('app.name')}</h1>
<p class="w-tag">${t('welcome.tag')}</p>
<p class="w-body">${t('welcome.body')}</p>
${seg('lang', L(), [['ar', 'عربي'], ['en', 'English']])}
<a class="btn btn-primary btn-block" href="#/welcome/2">${t('welcome.start')}</a>
<button class="btn btn-quiet btn-block" data-act="demo">${t('welcome.demo')}</button>
<p class="w-foot">${icon('lock')}<span>${t('welcome.private')}</span></p>
</div>`;
}

function newDraft() {
  return { type: 'house', name: '', features: { central_ac: false, tank: true, filter: false }, car: true, carName: '', km: '' };
}

function viewSetup() {
  draft ||= newDraft();
  const f = draft.features;
  const sw = (key, label) => `<label class="switch-row"><span>${label}</span><input type="checkbox" class="switch" data-draft-f="${key}"${f[key] ? ' checked' : ''}></label>`;
  return `<div class="welcome setup">
<p class="step">${t('setup.step', { n: 1, of: 2 })}</p>
<h1 class="h1">${t('setup.title')}</h1>
<div class="field"><span>${t('setup.type')}</span><div class="chips wrap">${S.HOME_TYPES.map((ty) => `<button class="chip${draft.type === ty ? ' on' : ''}" data-act="draft-type" data-v="${ty}">${t('type.' + ty)}</button>`).join('')}</div></div>
<label class="field"><span>${t('setup.name')}</span><input class="input" data-draft="name" value="${esc(draft.name)}" placeholder="${esc(t('type.' + draft.type))}" autocomplete="off"></label>
<div class="field"><span>${t('setup.has')}</span><div class="switches">${sw('central_ac', t('feat.central_ac'))}${sw('tank', t('feat.tank'))}${sw('filter', t('feat.filter'))}</div></div>
<div class="field"><span>${t('setup.car')}</span><div class="switches"><label class="switch-row"><span>${t('setup.has_car')}</span><input type="checkbox" class="switch" data-draft-car${draft.car ? ' checked' : ''}></label></div></div>
${draft.car ? `<div class="grid2"><label class="field"><span>${t('car.name')}</span><input class="input" data-draft="carName" value="${esc(draft.carName)}" placeholder="${esc(t('car.default'))}" autocomplete="off"></label>
<label class="field"><span>${t('car.km_now')}</span><input class="input ltr" data-draft="km" value="${esc(draft.km)}" inputmode="numeric" placeholder="84000"></label></div>` : ''}
<button class="btn btn-primary btn-block" data-act="setup-next">${t('act.next')}</button>
<a class="btn btn-quiet btn-block" href="#/welcome">${t('act.back')}</a>
</div>`;
}

function viewLast() {
  if (!draft || !draft.created) return viewSetup();
  const list = state.items
    .filter((i) => LAST_KEYS.includes(i.tpl) && i.enabled !== false && draft.created.includes(i.asset))
    .sort((a, b) => LAST_KEYS.indexOf(a.tpl) - LAST_KEYS.indexOf(b.tpl));
  return `<div class="welcome setup">
<p class="step">${t('setup.step', { n: 2, of: 2 })}</p>
<h1 class="h1">${t('last.title')}</h1>
<p class="w-body">${t('last.body')}</p>
${list.map((i) => `<div class="last-q"><p>${esc(nm(D.tpl[i.tpl]))}</p><div class="chips wrap">${LAST_OPTS.map(([k]) => `<button class="chip${(draft.last[i.id] || 'unknown') === k ? ' on' : ''}" data-act="last" data-id="${esc(i.id)}" data-v="${k}">${t('last.' + k)}</button>`).join('')}</div></div>`).join('')}
<button class="btn btn-primary btn-block" data-act="finish">${t('act.finish')}</button>
</div>`;
}

/* --------------------------------------------------------------- shell */

const TABS = [['today', 'today'], ['home', 'home'], ['car', 'car'], ['subs', 'repeat'], ['more', 'more']];

function route() {
  const parts = (location.hash || '#/today').replace(/^#\/?/, '').split('/');
  return { name: parts[0] || 'today', id: parts[1] ? decodeURIComponent(parts[1]) : null };
}

function shell(r, body) {
  const active = ['today', 'home', 'car', 'subs'].includes(r.name) ? r.name : 'more';
  const season = E.seasonAt(TODAY, D.seasons);
  return `<a class="skip" href="#main">${t('nav.skip')}</a><div class="app">
<nav class="tabbar" aria-label="${esc(t('nav.label'))}">${TABS.map(([name, ic]) => `<a class="tab${active === name ? ' on' : ''}" href="#/${name}"${active === name ? ' aria-current="page"' : ''}>${icon(ic)}<span>${t('tab.' + name)}</span></a>`).join('')}</nav>
<div class="col"><header class="top"><a class="brand" href="#/today">${mark()}<span>${t('app.name')}</span></a>
${r.name === 'today' ? '' : `<span class="top-season">${esc(nm(D.season[season.id]))}</span>`}</header>
<main class="page page-${esc(r.name)}" id="main" tabindex="-1">${body}</main></div></div>
${swWaiting ? `<div class="update" role="status"><span>${t('update.ready')}</span><button class="btn btn-primary" data-act="update">${t('update.now')}</button></div>` : ''}`;
}

let lastRoute = '';
function render() {
  const html = document.documentElement;
  html.lang = L();
  html.dir = L() === 'ar' ? 'rtl' : 'ltr';
  if (state.settings.theme === 'auto') delete html.dataset.theme;
  else html.dataset.theme = state.settings.theme;
  const r = route();
  let out;
  if (r.name === 'welcome') {
    const v = r.id === '2' ? viewSetup() : r.id === '3' ? viewLast() : viewWelcome();
    out = `<main class="onb" id="main">${v}</main>`;
  } else {
    const V = { today: viewToday, home: viewHome, car: viewCar, subs: viewSubs, more: viewMore, warranties: viewWarranties, techs: viewTechs, travel: viewTravel, spend: viewSpend, settings: viewSettings, about: viewAbout }[r.name] || viewToday;
    out = shell(r, V(r));
  }
  $('#app').innerHTML = out;
  $$('[data-p]').forEach((el) => el.style.setProperty('--p', el.dataset.p));
  document.title = r.name === 'today' || r.name === 'welcome' ? t('app.name') : `${t('app.name')}: ${t(`title.${r.name}`)}`;
  const key = location.hash;
  if (key !== lastRoute) {
    window.scrollTo(0, 0);
    lastRoute = key;
  }
}

let persistAsked = false;
function keepStorage() {
  if (persistAsked || !navigator.storage || !navigator.storage.persist) return;
  persistAsked = true;
  navigator.storage.persisted().then((yes) => yes || navigator.storage.persist()).catch(() => {});
}

function commit(silent) {
  if (!S.save(state)) toast(t('err.storage'));
  if (state.homes.length || state.cars.length || state.subs.length) keepStorage();
  if (!silent) render();
}

/* ---------------------------------------------------------- sheets etc */

function openSheet(html, label) {
  closeSheet(true);
  const root = document.createElement('div');
  root.id = 'sheet-root';
  root.innerHTML = `<div class="backdrop" data-act="close"></div><div class="sheet" role="dialog" aria-modal="true" aria-label="${esc(label || '')}" tabindex="-1">
<div class="grip" aria-hidden="true"></div><button class="sheet-x" data-act="close" aria-label="${esc(t('act.close'))}">${icon('close')}</button>${html}</div>`;
  document.body.appendChild(root);
  document.body.classList.add('locked');
  sheet = { back: document.activeElement };
  $$('[data-p]', root).forEach((el) => el.style.setProperty('--p', el.dataset.p));
  requestAnimationFrame(() => $('.sheet', root).focus());
}

function closeSheet(silent) {
  const root = $('#sheet-root');
  if (root) root.remove();
  document.body.classList.remove('locked');
  if (!silent && sheet && sheet.back && document.contains(sheet.back)) sheet.back.focus();
  sheet = null;
}

const val = (name) => {
  const el = $(`#sheet-root [name="${name}"]`);
  return el ? el.value.trim() : '';
};

function toast(msg, undo) {
  const old = $('#toast');
  if (old) old.remove();
  clearTimeout(toast.timer);
  const el = document.createElement('div');
  el.id = 'toast';
  el.className = 'toast';
  el.setAttribute('role', 'status');
  el.innerHTML = `<span>${esc(msg)}</span>${undo ? `<button data-act="undo">${t('act.undo')}</button>` : ''}`;
  document.body.appendChild(el);
  undoFn = undo || null;
  toast.timer = setTimeout(() => {
    el.remove();
    undoFn = null;
  }, 5200);
}

function download(content, name, type) {
  const blob = content instanceof Blob ? content : new Blob([content], { type });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = name;
  document.body.appendChild(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 4000);
}

function snapshot(id) {
  const i = state.items.findIndex((x) => x.id === id);
  const copy = JSON.parse(JSON.stringify(state.items[i]));
  const car = findAsset(state.items[i].asset);
  const readings = car && car.kind === 'car' ? JSON.parse(JSON.stringify(car.readings)) : null;
  return () => {
    const j = state.items.findIndex((x) => x.id === id);
    if (j >= 0) state.items[j] = copy;
    if (readings) car.readings = readings;
    commit();
  };
}

function addReading(car, date, km) {
  car.readings = car.readings.filter((r) => r.date !== date);
  car.readings.push({ date, km });
  car.readings.sort((a, b) => a.date.localeCompare(b.date));
}

function markDone(id, opts = {}) {
  const it = state.items.find((x) => x.id === id);
  if (!it) return;
  const undo = snapshot(id);
  const every = everyOf(it);
  const asset = findAsset(it.asset);
  const date = opts.date || TODAY;
  const entry = { date };
  if (asset && asset.kind === 'car' && every.km) {
    const km = opts.km != null ? opts.km : E.kmOn(asset, date);
    if (opts.km != null) addReading(asset, date, opts.km);
    it.lastKm = km;
    if (km != null) entry.km = km;
  }
  if (opts.cost != null) {
    entry.cost = opts.cost;
    entry.cur = state.settings.currency;
  }
  it.lastDone = date;
  it.snoozeUntil = null;
  (it.log ||= []).push(entry);
  const rowEl = $(`[data-row="${CSS.escape(id)}"]`);
  const finish = () => {
    commit();
    toast(t('toast.done', { title: itemTitle(evalItem(it)) }), undo);
  };
  if (rowEl && !calm()) {
    rowEl.classList.add('leaving');
    setTimeout(finish, 420);
  } else finish();
}

function renew(id) {
  const it = state.items.find((x) => x.id === id);
  if (!it || !it.due) return;
  const undo = snapshot(id);
  const every = everyOf(it);
  it.due = E.addMonths(it.due, every.repeat || 12);
  it.lastDone = TODAY;
  (it.log ||= []).push({ date: TODAY });
  commit();
  toast(t('toast.renewed', { date: dateText(it.due) }), undo);
}

/* ---------------------------------------------------------------- sheets */

function itemSheet(id) {
  const it = state.items.find((x) => x.id === id);
  if (!it) return;
  const ev = evalItem(it);
  const title = itemTitle(ev);
  const car = ev.asset && ev.asset.kind === 'car' ? ev.asset : null;
  const cur = state.settings.currency;
  const tech = techFor(ev.tpl && ev.tpl.trade);
  const logs = (it.log || []).slice(-6).reverse();
  let h = `<div class="sh-head s-${ev.status}"><span class="row-ic">${icon(ev.tpl ? ev.tpl.icon : 'spark')}</span>
<div><h2 class="sh-title">${esc(title)}</h2><p class="row-meta">${dueMeta(ev)}</p></div></div>`;
  if (ev.tpl) h += `<p class="why">${esc(why(ev.tpl))}</p>`;
  h += `<dl class="facts"><div><dt>${t('item.every')}</dt><dd>${esc(everyText(ev.every))}</dd></div>
<div><dt>${t('item.last')}</dt><dd>${it.lastDone ? esc(dateText(it.lastDone)) : t('item.never')}</dd></div>
${ev.due ? `<div><dt>${t('item.next')}</dt><dd>${esc(dateText(ev.due))}</dd></div>` : ''}
${it.lastKm != null && ev.every.km ? `<div><dt>${t('item.at_km')}</dt><dd>${esc(kmText(it.lastKm))}</dd></div>` : ''}</dl>`;
  if (ev.every.fixed) {
    h += `<label class="field"><span>${t('item.expiry')}</span><input class="input" type="date" name="due" value="${esc(it.due || '')}"></label>
<button class="btn btn-primary btn-block" data-act="save-due" data-id="${esc(id)}">${t('act.save')}</button>
${it.due ? `<button class="btn btn-block" data-act="renew" data-id="${esc(id)}">${icon('done')}<span>${t('act.renewed_long', { date: dateText(E.addMonths(it.due, ev.every.repeat || 12)) })}</span></button>` : ''}`;
  } else {
    h += `<div class="done-form"><div class="grid2"><label class="field"><span>${t('item.when')}</span><input class="input" type="date" name="date" value="${TODAY}" max="${TODAY}"></label>
${car && ev.every.km ? `<label class="field"><span>${t('item.km')}</span><input class="input ltr" name="km" inputmode="numeric" value="${E.kmOn(car, TODAY) ?? ''}"></label>` : ''}</div>
<label class="field"><span>${t('item.cost')}</span><input class="input ltr" name="cost" inputmode="decimal" placeholder="${esc(money(0, cur))}"></label>
<button class="btn btn-primary btn-block" data-act="save-done" data-id="${esc(id)}">${icon('done')}<span>${t('act.done')}</span></button></div>
<div class="actions two"><button class="btn" data-act="snooze" data-id="${esc(id)}">${icon('snooze')}<span>${t('act.snooze')}</span></button>
${ev.every.season ? '' : `<button class="btn" data-act="interval" data-id="${esc(id)}">${icon('edit')}<span>${t('act.interval')}</span></button>`}</div>`;
  }
  if (tech) h += `<div class="tech-line"><p>${t('tech.for', { trade: nm(D.trade[tech.trade]), name: esc(tech.name) })}</p><div class="actions two">${techLinks(tech)}</div></div>`;
  else if (ev.tpl && ev.tpl.trade) h += `<p class="fine">${t('tech.none', { trade: nm(D.trade[ev.tpl.trade]) })} <a href="#/techs" data-act="close-nav">${t('tech.add_link')}</a></p>`;
  if (logs.length) {
    h += `<h3 class="sh-h">${t('item.history')}</h3><ul class="hist">${logs.map((l) => `<li><span>${esc(dateText(l.date))}</span>${l.km != null ? `<span>${esc(kmText(l.km))}</span>` : ''}${l.cost != null ? `<span>${esc(money(l.cost, l.cur || cur))}</span>` : ''}</li>`).join('')}</ul>`;
  }
  h += `<button class="btn btn-quiet btn-danger btn-block" data-act="${it.tpl ? 'stop-item' : 'delete-item'}" data-id="${esc(id)}">${icon('trash')}<span>${it.tpl ? t('act.stop') : t('act.delete')}</span></button>`;
  openSheet(h, title);
}

function intervalSheet(id) {
  const it = state.items.find((x) => x.id === id);
  const e = everyOf(it);
  const unit = e.days ? 'days' : 'months';
  const n = e.days || e.months || 6;
  openSheet(`<h2 class="sh-title">${t('act.interval')}</h2>
<div class="grid2"><label class="field"><span>${t('int.every')}</span><input class="input ltr" name="n" inputmode="numeric" value="${n}"></label>
<div class="field"><span>${t('int.unit')}</span>${seg('unit', unit, [['days', t('int.days')], ['months', t('int.months')]])}<input type="hidden" name="unit" value="${unit}"></div></div>
${e.km ? `<label class="field"><span>${t('int.km')}</span><input class="input ltr" name="km" inputmode="numeric" value="${e.km}"></label>` : ''}
<button class="btn btn-primary btn-block" data-act="save-interval" data-id="${esc(id)}">${t('act.save')}</button>
${it.every && it.tpl ? `<button class="btn btn-quiet btn-block" data-act="reset-interval" data-id="${esc(id)}">${t('int.reset')}</button>` : ''}`, t('act.interval'));
}

function addTaskSheet(assetId) {
  const asset = findAsset(assetId);
  const kind = asset.kind;
  const have = new Set(state.items.filter((i) => i.asset === assetId && i.enabled !== false).map((i) => i.tpl));
  const avail = D.templates.filter((x) => x.kind === kind && !have.has(x.id));
  openSheet(`<h2 class="sh-title">${t('act.add_task')}</h2>
${avail.length ? `<p class="lede small">${t('add.from_list')}</p><div class="chips wrap">${avail.map((x) => `<button class="chip" data-act="add-tpl" data-id="${esc(assetId)}" data-v="${esc(x.id)}">${icon(x.icon)}<span>${esc(nm(x))}</span></button>`).join('')}</div>` : ''}
<h3 class="sh-h">${t('add.custom')}</h3>
<label class="field"><span>${t('add.title')}</span><input class="input" name="title" autocomplete="off" placeholder="${esc(t('add.title_ph'))}"></label>
<div class="grid2"><label class="field"><span>${t('int.every')}</span><input class="input ltr" name="n" inputmode="numeric" value="3"></label>
<div class="field"><span>${t('int.unit')}</span>${seg('unit', 'months', [['days', t('int.days')], ['months', t('int.months')]])}<input type="hidden" name="unit" value="months"></div></div>
<button class="btn btn-primary btn-block" data-act="save-custom" data-id="${esc(assetId)}">${t('act.save')}</button>`, t('act.add_task'));
}

function homeSheet(id) {
  const h = id ? state.homes.find((x) => x.id === id) : null;
  const type = h ? h.type : 'house';
  const f = h ? h.features : { central_ac: false, tank: true, filter: false };
  const sw = (key) => `<label class="switch-row"><span>${t('feat.' + key)}</span><input type="checkbox" class="switch" name="f-${key}"${f[key] ? ' checked' : ''}></label>`;
  openSheet(`<h2 class="sh-title">${h ? t('act.edit_home') : t('act.add_home')}</h2>
<div class="field"><span>${t('setup.type')}</span>${seg('type', type, S.HOME_TYPES.map((ty) => [ty, t('type.' + ty)]))}<input type="hidden" name="type" value="${type}"></div>
<label class="field"><span>${t('setup.name')}</span><input class="input" name="name" value="${esc(h ? h.name : '')}" placeholder="${esc(t('type.' + type))}" autocomplete="off"></label>
<div class="field"><span>${t('setup.has')}</span><div class="switches">${sw('central_ac')}${sw('tank')}${sw('filter')}</div></div>
<button class="btn btn-primary btn-block" data-act="save-home" data-id="${esc(id || '')}">${t('act.save')}</button>
${h ? `<button class="btn btn-quiet btn-danger btn-block" data-act="delete-asset" data-id="${esc(id)}">${icon('trash')}<span>${t('act.delete_home')}</span></button>` : ''}`, t('act.add_home'));
}

function carSheet(id) {
  const c = id ? state.cars.find((x) => x.id === id) : null;
  openSheet(`<h2 class="sh-title">${c ? t('act.edit_car') : t('act.add_car')}</h2>
<label class="field"><span>${t('car.name')}</span><input class="input" name="name" value="${esc(c ? c.name : '')}" placeholder="${esc(t('car.default'))}" autocomplete="off"></label>
${c ? '' : `<label class="field"><span>${t('car.km_now')}</span><input class="input ltr" name="km" inputmode="numeric" placeholder="84000"></label>`}
<label class="field"><span>${t('car.daily')}</span><input class="input ltr" name="daily" inputmode="numeric" value="${c ? c.dailyKm : 40}"></label>
<p class="fine">${t('car.daily_note')}</p>
<button class="btn btn-primary btn-block" data-act="save-car" data-id="${esc(id || '')}">${t('act.save')}</button>
${c ? `<button class="btn btn-quiet btn-danger btn-block" data-act="delete-asset" data-id="${esc(id)}">${icon('trash')}<span>${t('act.delete_car')}</span></button>` : ''}`, t('act.add_car'));
}

function odoSheet(id) {
  const c = state.cars.find((x) => x.id === id);
  openSheet(`<h2 class="sh-title">${t('act.update_odo')}</h2>
<p class="lede small">${t('odo.body')}</p>
<div class="grid2"><label class="field"><span>${t('item.km')}</span><input class="input ltr" name="km" inputmode="numeric" value="${E.kmOn(c, TODAY) ?? ''}"></label>
<label class="field"><span>${t('item.when')}</span><input class="input" type="date" name="date" value="${TODAY}" max="${TODAY}"></label></div>
<button class="btn btn-primary btn-block" data-act="save-odo" data-id="${esc(id)}">${t('act.save')}</button>`, t('act.update_odo'));
}

function subSheet(id) {
  const s = id ? state.subs.find((x) => x.id === id) : null;
  const cur = s ? s.currency : state.settings.currency;
  const cycle = s ? s.cycle : 'monthly';
  const next = s ? E.nextRenewal(s, TODAY) : E.addMonths(TODAY, 1);
  const cat = s ? s.category : 'stream';
  openSheet(`<h2 class="sh-title">${s ? esc(s.name) : t('act.add_sub')}</h2>
<label class="field"><span>${t('sub.name')}</span><input class="input" name="name" value="${esc(s ? s.name : '')}" autocomplete="off" placeholder="${esc(t('sub.name_ph'))}"></label>
<div class="grid2"><label class="field"><span>${t('sub.amount')}</span><input class="input ltr" name="amount" inputmode="decimal" value="${s ? esc(E.formatMoney(s.amount, s.currency, 'en').split(' ')[1]) : ''}" placeholder="3.500"></label>
<label class="field"><span>${t('settings.currency')}</span><select class="input" name="currency">${Object.keys(E.CURRENCIES).map((c) => `<option value="${c}"${c === cur ? ' selected' : ''}>${c}</option>`).join('')}</select></label></div>
<div class="field"><span>${t('sub.cycle')}</span>${seg('cycle', cycle, CYCLES.map((c) => [c, t('cyclename.' + c)]))}<input type="hidden" name="cycle" value="${cycle}"></div>
<label class="field"><span>${t('sub.next')}</span><input class="input" type="date" name="next" value="${esc(next)}"></label>
<label class="switch-row"><span>${t('sub.trial_q')}</span><input type="checkbox" class="switch" name="trial"${s && s.trial && s.anchor >= TODAY ? ' checked' : ''}></label>
<div class="field"><span>${t('sub.category')}</span><div class="chips wrap">${CATS.map(([c, ic]) => `<button class="chip${c === cat ? ' on' : ''}" data-act="set" data-name="category" data-v="${c}">${icon(ic)}<span>${t('cat.' + c)}</span></button>`).join('')}</div><input type="hidden" name="category" value="${cat}"></div>
<label class="field"><span>${t('sub.note')}</span><input class="input" name="note" value="${esc(s ? s.note || '' : '')}" placeholder="${esc(t('sub.note_ph'))}" autocomplete="off"></label>
<button class="btn btn-primary btn-block" data-act="save-sub" data-id="${esc(id || '')}">${t('act.save')}</button>
${s && s.cancelled ? `<button class="btn btn-block" data-act="sub-restore" data-id="${esc(id)}">${t('sub.restore')}</button>` : ''}
${s && !s.cancelled ? `<button class="btn btn-block" data-act="sub-cancelled" data-id="${esc(id)}">${t('ask.cancelled')}</button>` : ''}
${s ? `<button class="btn btn-quiet btn-danger btn-block" data-act="delete-sub" data-id="${esc(id)}">${icon('trash')}<span>${t('act.delete')}</span></button>` : ''}`, t('act.add_sub'));
}

async function warrantySheet(id) {
  const w = id ? state.warranties.find((x) => x.id === id) : null;
  let img = '';
  if (w && w.receipt) {
    try {
      const blob = await S.getReceipt(w.receipt);
      if (blob) img = `<img class="receipt" src="${URL.createObjectURL(blob)}" alt="${esc(t('w.receipt'))}">`;
    } catch {
      img = '';
    }
  }
  const months = w ? w.months : 24;
  openSheet(`<h2 class="sh-title">${w ? esc(w.name) : t('act.add_warranty')}</h2>
<label class="field"><span>${t('w.name')}</span><input class="input" name="name" value="${esc(w ? w.name : '')}" placeholder="${esc(t('w.name_ph'))}" autocomplete="off"></label>
<label class="field"><span>${t('w.store')}</span><input class="input" name="store" value="${esc(w ? w.store || '' : '')}" autocomplete="off"></label>
<label class="field"><span>${t('w.bought')}</span><input class="input" type="date" name="bought" value="${esc(w ? w.bought : TODAY)}" max="${TODAY}"></label>
<div class="field"><span>${t('w.months')}</span>${seg('months', months, [[12, monthCount(12)], [24, monthCount(24)], [36, monthCount(36)], [60, monthCount(60)]])}<input type="hidden" name="months" value="${months}"></div>
<div class="field"><span>${t('w.receipt')}</span>${img}<label class="btn btn-block file">${icon('camera')}<span>${w && w.receipt ? t('w.receipt_change') : t('w.receipt_add')}</span><input type="file" name="receipt" accept="image/*"></label></div>
<button class="btn btn-primary btn-block" data-act="save-warranty" data-id="${esc(id || '')}">${t('act.save')}</button>
${w ? `<button class="btn btn-quiet btn-danger btn-block" data-act="delete-warranty" data-id="${esc(id)}">${icon('trash')}<span>${t('act.delete')}</span></button>` : ''}`, t('act.add_warranty'));
}

function techSheet(id) {
  const x = id ? state.techs.find((y) => y.id === id) : null;
  const trade = x ? x.trade : 'ac';
  openSheet(`<h2 class="sh-title">${x ? esc(x.name) : t('act.add_tech')}</h2>
<label class="field"><span>${t('tech.name')}</span><input class="input" name="name" value="${esc(x ? x.name : '')}" autocomplete="off"></label>
<div class="field"><span>${t('tech.trade')}</span><div class="chips wrap">${D.trades.map((tr) => `<button class="chip${tr.id === trade ? ' on' : ''}" data-act="set" data-name="trade" data-v="${tr.id}">${esc(nm(tr))}</button>`).join('')}</div><input type="hidden" name="trade" value="${trade}"></div>
<label class="field"><span>${t('tech.phone')}</span><input class="input ltr" name="phone" type="tel" inputmode="tel" value="${esc(x ? x.phone : '')}" placeholder="+965"></label>
<label class="field"><span>${t('tech.note')}</span><input class="input" name="note" value="${esc(x ? x.note || '' : '')}" autocomplete="off"></label>
<button class="btn btn-primary btn-block" data-act="save-tech" data-id="${esc(id || '')}">${t('act.save')}</button>
${x ? `<button class="btn btn-quiet btn-danger btn-block" data-act="delete-tech" data-id="${esc(id)}">${icon('trash')}<span>${t('act.delete')}</span></button>` : ''}`, t('act.add_tech'));
}

function backupSheet() {
  openSheet(`<h2 class="sh-title">${t('act.backup')}</h2><p class="lede small">${t('backup.body')}</p>
<label class="field"><span>${t('backup.pass')}</span><input class="input ltr" type="password" name="pass" autocomplete="new-password"></label>
<label class="field"><span>${t('backup.pass2')}</span><input class="input ltr" type="password" name="pass2" autocomplete="new-password"></label>
<button class="btn btn-primary btn-block" data-act="do-backup">${icon('lock')}<span>${t('backup.go')}</span></button>`, t('act.backup'));
}

function restoreSheet() {
  openSheet(`<h2 class="sh-title">${t('act.restore')}</h2><p class="lede small">${t('restore.body')}</p>
<label class="btn btn-block file">${icon('upload')}<span data-file-label>${t('restore.pick')}</span><input type="file" name="file" accept=".json,application/json"></label>
<label class="field"><span>${t('backup.pass')}</span><input class="input ltr" type="password" name="pass" autocomplete="current-password"></label>
<button class="btn btn-primary btn-block" data-act="do-restore">${icon('upload')}<span>${t('restore.go')}</span></button>`, t('act.restore'));
}

function confirmSheet(msg, act, id, label) {
  openSheet(`<h2 class="sh-title">${esc(msg)}</h2><div class="actions two">
<button class="btn btn-danger" data-act="${act}" data-id="${esc(id || '')}" data-confirmed="1">${esc(label)}</button>
<button class="btn" data-act="close">${t('act.cancel')}</button></div>`, msg);
}

/* ------------------------------------------------------------- actions */

async function compress(file) {
  const bmp = await createImageBitmap(file);
  const scale = Math.min(1, 1600 / Math.max(bmp.width, bmp.height));
  const c = document.createElement('canvas');
  c.width = Math.round(bmp.width * scale);
  c.height = Math.round(bmp.height * scale);
  c.getContext('2d').drawImage(bmp, 0, 0, c.width, c.height);
  return new Promise((res) => c.toBlob(res, 'image/jpeg', 0.82));
}

function exportICS() {
  const events = [];
  for (const ev of items()) {
    if (!ev.due) continue;
    const date = ev.due < TODAY ? TODAY : ev.due;
    events.push({ uid: `${ev.it.id}-${ev.due}`, date, title: `${itemTitle(ev)}${ev.asset ? `${comma()}${ev.asset.name}` : ''}`, note: why(ev.tpl), lead: ev.every.fixed ? 7 : ev.status === 'ok' ? 3 : 0 });
  }
  for (const x of state.subs.map(evalSub)) {
    if (!x.s.cancelled) events.push({ uid: `sub-${x.s.id}-${x.next}`, date: x.next, title: t('ics.sub', { name: x.s.name, amount: money(x.s.amount, x.s.currency) }), lead: x.days > 3 ? 3 : 0 });
  }
  for (const w of state.warranties.map(evalWarranty)) {
    if (w.end >= TODAY) events.push({ uid: `w-${w.w.id}`, date: w.end, title: t('ics.warranty', { name: w.w.name }), lead: w.days > 14 ? 14 : 0 });
  }
  const d = new Date();
  const stamp = `${d.getUTCFullYear()}${pad(d.getUTCMonth() + 1)}${pad(d.getUTCDate())}T${pad(d.getUTCHours())}${pad(d.getUTCMinutes())}${pad(d.getUTCSeconds())}Z`;
  download(E.toICS(events, { stamp, calName: t('app.name') }), 'nokhatha.ics', 'text/calendar');
  toast(t('toast.ics', { n: events.length }));
}

async function doBackup() {
  const pass = val('pass');
  if (pass.length < 8) return toast(t('backup.short'));
  if (pass !== val('pass2')) return toast(t('backup.mismatch'));
  const btn = $('#sheet-root [data-act="do-backup"]');
  btn.disabled = true;
  try {
    const receipts = {};
    for (const r of await S.allReceipts().catch(() => [])) receipts[r.id] = { type: r.blob.type, data: await blobToB64(r.blob) };
    const file = await encryptBackup({ state, receipts }, pass);
    download(JSON.stringify(file), `nokhatha-backup-${TODAY}.json`, 'application/json');
    state.settings.lastBackup = TODAY;
    S.save(state);
    closeSheet(true);
    render();
    toast(t('backup.done'));
  } catch {
    btn.disabled = false;
    toast(t('backup.failed'));
  }
}

async function doRestore() {
  const input = $('#sheet-root [name="file"]');
  const file = input && input.files[0];
  if (!file) return toast(t('restore.nofile'));
  try {
    const payload = await decryptBackup(JSON.parse(await file.text()), val('pass'));
    state = S.normalize(payload.state);
    state.settings.onboarded = true;
    await S.clearReceipts().catch(() => {});
    for (const [id, r] of Object.entries(payload.receipts || {})) await S.putReceipt(id, b64ToBlob(r.data, r.type));
    closeSheet(true);
    location.hash = '#/today';
    commit();
    toast(t('restore.done'));
  } catch (e) {
    toast(e.message === 'pass' ? t('restore.badpass') : t('restore.badfile'));
  }
}

function num(s) {
  const n = Number(E.normalizeDigits(s).replace(/[^\d]/g, ''));
  return Number.isFinite(n) && String(s).trim() !== '' ? n : null;
}

async function onClick(e) {
  const el = e.target.closest('[data-act]');
  if (!el) return;
  const act = el.dataset.act;
  const id = el.dataset.id;
  if (el.tagName === 'INPUT') return;
  switch (act) {
    case 'close': closeSheet(); break;
    case 'install-ok': state.settings.installTipOff = true; commit(); break;
    case 'close-nav': closeSheet(true); break;
    case 'undo': if (undoFn) { const f = undoFn; undoFn = null; $('#toast')?.remove(); f(); } break;
    case 'update': if (swWaiting) swWaiting.postMessage('skip'); break;
    case 'done': markDone(id); break;
    case 'renew': closeSheet(true); renew(id); break;
    case 'item': itemSheet(id); break;
    case 'save-done': {
      const date = val('date') || TODAY;
      const cost = val('cost') ? E.parseMoney(val('cost'), state.settings.currency) : null;
      const km = val('km') ? num(val('km')) : null;
      closeSheet(true);
      markDone(id, { date: date > TODAY ? TODAY : date, cost, km });
      break;
    }
    case 'save-due': {
      const it = state.items.find((x) => x.id === id);
      const v = val('due');
      if (!E.isISO(v)) return toast(t('err.date'));
      it.due = v;
      closeSheet(true);
      commit();
      toast(t('toast.saved'));
      break;
    }
    case 'snooze': {
      const undo = snapshot(id);
      const it = state.items.find((x) => x.id === id);
      it.snoozeUntil = E.addDays(TODAY, 7);
      closeSheet(true);
      commit();
      toast(t('toast.snoozed', { date: dateText(it.snoozeUntil) }), undo);
      break;
    }
    case 'interval': intervalSheet(id); break;
    case 'save-interval': {
      const it = state.items.find((x) => x.id === id);
      const n = num(val('n'));
      if (!n || n < 1 || n > 3650) return toast(t('err.number'));
      const next = val('unit') === 'days' ? { days: n } : { months: Math.min(n, 120) };
      const base = everyOf(it);
      if (base.km) next.km = num(val('km')) || base.km;
      it.every = next;
      closeSheet(true);
      commit();
      toast(t('toast.saved'));
      break;
    }
    case 'reset-interval': {
      const it = state.items.find((x) => x.id === id);
      delete it.every;
      closeSheet(true);
      commit();
      break;
    }
    case 'stop-item':
    case 'delete-item': {
      const it = state.items.find((x) => x.id === id);
      const undo = snapshot(id);
      if (act === 'stop-item') it.enabled = false;
      else state.items = state.items.filter((x) => x.id !== id);
      closeSheet(true);
      commit();
      toast(act === 'stop-item' ? t('toast.stopped') : t('toast.deleted'), act === 'stop-item' ? undo : () => { state.items.push(it); commit(); });
      break;
    }
    case 'add-task': addTaskSheet(id); break;
    case 'add-tpl': {
      S.addItem(state, id, el.dataset.v);
      closeSheet(true);
      commit();
      toast(t('toast.added'));
      break;
    }
    case 'save-custom': {
      const title = val('title');
      const n = num(val('n'));
      if (!title) return toast(t('err.title'));
      if (!n || n < 1) return toast(t('err.number'));
      S.addCustom(state, id, title, val('unit') === 'days' ? { days: n } : { months: Math.min(n, 120) });
      closeSheet(true);
      commit();
      toast(t('toast.added'));
      break;
    }
    case 'add-home': homeSheet(null); break;
    case 'edit-home': homeSheet(id); break;
    case 'save-home': {
      const type = val('type') || 'house';
      const name = val('name') || t('type.' + type);
      const features = { central_ac: $('#sheet-root [name="f-central_ac"]').checked, tank: $('#sheet-root [name="f-tank"]').checked, filter: $('#sheet-root [name="f-filter"]').checked };
      let home;
      if (id) {
        home = state.homes.find((x) => x.id === id);
        Object.assign(home, { type, name, features });
        S.syncFeatures(state, home, D.templates);
        S.spreadNew(state, [home.id], TODAY, D.templates);
      } else {
        home = S.addHome(state, { type, name, features }, D.templates);
        S.spreadNew(state, [home.id], TODAY, D.templates);
      }
      closeSheet(true);
      location.hash = `#/home/${home.id}`;
      commit();
      break;
    }
    case 'add-car': carSheet(null); break;
    case 'edit-car': carSheet(id); break;
    case 'save-car': {
      const name = val('name') || t('car.default');
      const daily = num(val('daily')) || 40;
      let car;
      if (id) {
        car = state.cars.find((x) => x.id === id);
        Object.assign(car, { name, dailyKm: daily });
      } else {
        car = S.addCar(state, { name, km: num(val('km')), date: TODAY, dailyKm: daily }, D.templates);
        S.spreadNew(state, [car.id], TODAY, D.templates);
      }
      closeSheet(true);
      location.hash = `#/car/${car.id}`;
      commit();
      break;
    }
    case 'delete-asset':
      if (!el.dataset.confirmed) return confirmSheet(t('confirm.asset'), 'delete-asset', id, t('act.delete'));
      S.removeAsset(state, id);
      closeSheet(true);
      commit();
      break;
    case 'odo': odoSheet(id); break;
    case 'save-odo': {
      const car = state.cars.find((x) => x.id === id);
      const km = num(val('km'));
      const date = val('date') || TODAY;
      if (km == null) return toast(t('err.number'));
      addReading(car, date > TODAY ? TODAY : date, km);
      closeSheet(true);
      commit();
      toast(t('toast.saved'));
      break;
    }
    case 'set': {
      const group = el.closest('[data-seg], .chips');
      const name = el.dataset.name;
      if (name && ['lang', 'theme', 'lead'].includes(name) && !el.closest('#sheet-root')) {
        state.settings[name] = name === 'lead' ? Number(el.dataset.v) : el.dataset.v;
        if (name === 'lang' && draft) draft.name = draft.name || '';
        commit();
        break;
      }
      if (group) group.querySelectorAll('[data-act="set"]').forEach((b) => {
        b.classList.toggle('on', b === el);
        b.setAttribute('aria-pressed', String(b === el));
      });
      const hidden = $(`#sheet-root input[type="hidden"][name="${name}"]`);
      if (hidden) hidden.value = el.dataset.v;
      if (name === 'type') {
        const nameInput = $('#sheet-root [name="name"]');
        if (nameInput) nameInput.placeholder = t('type.' + el.dataset.v);
      }
      break;
    }
    case 'add-sub': subSheet(null); break;
    case 'sub': subSheet(id); break;
    case 'save-sub': {
      const name = val('name');
      const currency = val('currency') || state.settings.currency;
      const amount = E.parseMoney(val('amount'), currency);
      const next = val('next');
      if (!name) return toast(t('err.title'));
      if (amount == null) return toast(t('err.amount'));
      if (!E.isISO(next)) return toast(t('err.date'));
      const patch = { name, amount, currency, cycle: val('cycle') || 'monthly', anchor: next, trial: $('#sheet-root [name="trial"]').checked, category: val('category') || 'other', note: val('note') };
      if (id) Object.assign(state.subs.find((x) => x.id === id), patch);
      else state.subs.push({ id: S.uid(), usage: {}, ...patch });
      closeSheet(true);
      commit();
      toast(t('toast.saved'));
      break;
    }
    case 'sub-yes':
    case 'sub-no':
    case 'sub-keep': {
      const s = state.subs.find((x) => x.id === id);
      const next = E.nextRenewal(s, TODAY);
      s.usage = { ...(s.usage || {}), [next]: act === 'sub-no' ? 'no' : 'yes' };
      commit();
      if (act === 'sub-yes' || act === 'sub-keep') toast(t('toast.kept', { name: s.name }));
      break;
    }
    case 'sub-cancelled': {
      const s = state.subs.find((x) => x.id === id);
      const before = { ...s };
      s.cancelled = true;
      s.cancelledOn = TODAY;
      closeSheet(true);
      commit();
      toast(t('toast.cancelled', { name: s.name }), () => { Object.assign(s, before); delete s.cancelledOn; if (!before.cancelled) delete s.cancelled; commit(); });
      break;
    }
    case 'sub-restore': {
      const s = state.subs.find((x) => x.id === id);
      s.cancelled = false;
      delete s.cancelledOn;
      closeSheet(true);
      commit();
      break;
    }
    case 'delete-sub': {
      if (!el.dataset.confirmed) return confirmSheet(t('confirm.sub'), 'delete-sub', id, t('act.delete'));
      state.subs = state.subs.filter((x) => x.id !== id);
      closeSheet(true);
      commit();
      break;
    }
    case 'add-warranty': warrantySheet(null); break;
    case 'warranty': warrantySheet(id); break;
    case 'save-warranty': {
      const name = val('name');
      const bought = val('bought');
      if (!name) return toast(t('err.title'));
      if (!E.isISO(bought)) return toast(t('err.date'));
      const patch = { name, store: val('store'), bought, months: Number(val('months')) || 24 };
      let w = id ? state.warranties.find((x) => x.id === id) : null;
      if (w) Object.assign(w, patch);
      else state.warranties.push((w = { id: S.uid(), ...patch }));
      const file = $('#sheet-root [name="receipt"]').files[0];
      if (file) {
        try {
          const blob = await compress(file);
          const rid = w.receipt || S.uid();
          await S.putReceipt(rid, blob);
          w.receipt = rid;
        } catch {
          toast(t('err.photo'));
        }
      }
      closeSheet(true);
      commit();
      toast(t('toast.saved'));
      break;
    }
    case 'delete-warranty': {
      if (!el.dataset.confirmed) return confirmSheet(t('confirm.warranty'), 'delete-warranty', id, t('act.delete'));
      const w = state.warranties.find((x) => x.id === id);
      if (w && w.receipt) await S.delReceipt(w.receipt).catch(() => {});
      state.warranties = state.warranties.filter((x) => x.id !== id);
      closeSheet(true);
      commit();
      break;
    }
    case 'add-tech': techSheet(null); break;
    case 'tech': techSheet(id); break;
    case 'save-tech': {
      const name = val('name');
      if (!name) return toast(t('err.title'));
      const patch = { name, trade: val('trade') || 'general', phone: val('phone'), note: val('note') };
      if (id) Object.assign(state.techs.find((x) => x.id === id), patch);
      else state.techs.push({ id: S.uid(), ...patch });
      closeSheet(true);
      commit();
      toast(t('toast.saved'));
      break;
    }
    case 'delete-tech': {
      if (!el.dataset.confirmed) return confirmSheet(t('confirm.tech'), 'delete-tech', id, t('act.delete'));
      state.techs = state.techs.filter((x) => x.id !== id);
      closeSheet(true);
      commit();
      break;
    }
    case 'travel-reset': state.travel.done = []; commit(); break;
    case 'ics': exportICS(); break;
    case 'backup': backupSheet(); break;
    case 'do-backup': await doBackup(); break;
    case 'restore': restoreSheet(); break;
    case 'do-restore': await doRestore(); break;
    case 'demo': {
      const has = state.homes.length || state.cars.length || state.subs.length;
      if (has && !el.dataset.confirmed) return confirmSheet(t('confirm.sample'), 'demo', '', t('act.replace'));
      state = S.sample(L(), TODAY, D.templates);
      closeSheet(true);
      location.hash = '#/today';
      commit();
      break;
    }
    case 'wipe': {
      if (!el.dataset.confirmed) return confirmSheet(t('confirm.wipe'), 'wipe', '', t('act.wipe'));
      const lang = L();
      S.wipe();
      await S.clearReceipts().catch(() => {});
      state = S.blank(lang);
      draft = null;
      closeSheet(true);
      location.hash = '#/welcome';
      commit();
      break;
    }
    case 'draft-type': draft.type = el.dataset.v; draft.features.tank = el.dataset.v !== 'flat'; render(); break;
    case 'setup-next': {
      for (const a of draft.created || []) S.removeAsset(state, a);
      const home = S.addHome(state, { type: draft.type, name: draft.name.trim() || t('type.' + draft.type), features: draft.features }, D.templates);
      draft.created = [home.id];
      if (draft.car) {
        const km = num(draft.km);
        const car = S.addCar(state, { name: draft.carName.trim() || t('car.default'), km, date: TODAY, dailyKm: 40 }, D.templates);
        draft.created.push(car.id);
      }
      draft.last = {};
      S.save(state);
      location.hash = '#/welcome/3';
      break;
    }
    case 'last': draft.last[id] = el.dataset.v; render(); break;
    case 'finish': {
      for (const [itemId, v] of Object.entries(draft.last || {})) {
        const days = (LAST_OPTS.find((o) => o[0] === v) || [])[1];
        if (days == null) continue;
        const it = state.items.find((x) => x.id === itemId);
        const asset = findAsset(it.asset);
        it.lastDone = E.addDays(TODAY, -days);
        if (asset.kind === 'car' && everyOf(it).km) {
          const now = E.kmOn(asset, TODAY);
          if (now != null) it.lastKm = Math.max(0, now - days * (asset.dailyKm || 40));
        }
      }
      S.spreadNew(state, draft.created || [], TODAY, D.templates);
      state.settings.onboarded = true;
      draft = null;
      location.hash = '#/today';
      commit();
      break;
    }
    default: break;
  }
}

function onChange(e) {
  const el = e.target;
  if (el.matches('[data-act="travel"]')) {
    const set = new Set(state.travel.done);
    if (el.checked) set.add(el.value);
    else set.delete(el.value);
    state.travel.done = D.travel.map((x) => x.id).filter((x) => set.has(x));
    commit(true);
    const p = $('.progress-l');
    if (p) p.textContent = t('travel.progress', { n: state.travel.done.length, of: D.travel.length });
    return;
  }
  if (el.matches('[data-act="currency"]')) {
    state.settings.currency = el.value;
    commit();
    return;
  }
  if (el.matches('[data-draft-f]')) {
    draft.features[el.dataset.draftF] = el.checked;
    return;
  }
  if (el.matches('[data-draft-car]')) {
    draft.car = el.checked;
    render();
    return;
  }
  if (el.matches('#sheet-root [name="file"]')) {
    const lbl = $('#sheet-root [data-file-label]');
    if (lbl && el.files[0]) lbl.textContent = el.files[0].name;
  }
}

function onInput(e) {
  const el = e.target;
  if (el.matches('[data-draft]') && draft) draft[el.dataset.draft] = el.value;
}

function onKey(e) {
  const root = $('#sheet-root');
  if (!root) return;
  if (e.key === 'Escape') {
    closeSheet();
    return;
  }
  if (e.key === 'Tab') {
    const f = $$('button, [href], input:not([type="hidden"]), select, textarea', root).filter((x) => !x.disabled && x.offsetParent !== null);
    if (!f.length) return;
    const first = f[0];
    const lastEl = f[f.length - 1];
    if (e.shiftKey && document.activeElement === first) {
      e.preventDefault();
      lastEl.focus();
    } else if (!e.shiftKey && document.activeElement === lastEl) {
      e.preventDefault();
      first.focus();
    }
  }
}

/* ------------------------------------------------------------------ boot */

function registerSW() {
  if (!('serviceWorker' in navigator)) return;
  const hadController = !!navigator.serviceWorker.controller;
  navigator.serviceWorker.register('sw.js').then((reg) => {
    const watch = (w) => w && w.addEventListener('statechange', () => {
      if (w.state === 'installed' && navigator.serviceWorker.controller) {
        swWaiting = w;
        if (!$('#sheet-root')) render();
      }
    });
    if (reg.waiting && navigator.serviceWorker.controller) {
      swWaiting = reg.waiting;
      render();
    }
    reg.addEventListener('updatefound', () => watch(reg.installing));
  }).catch(() => {});
  let reloaded = false;
  navigator.serviceWorker.addEventListener('controllerchange', () => {
    if (!hadController || reloaded) return;
    reloaded = true;
    location.reload();
  });
}

async function boot() {
  try {
    await loadData();
  } catch {
    document.getElementById('app').innerHTML = '<p class="boot-error">تعذّر التحميل، جرّب مرة ثانية.<br>Could not load, please try again.</p>';
    return;
  }
  TODAY = nowISO();
  const lang = (navigator.language || 'ar').toLowerCase().startsWith('ar') ? 'ar' : 'en';
  state = S.load() || S.blank(lang);
  const params = new URLSearchParams(location.search);
  if (params.get('lang') === 'ar' || params.get('lang') === 'en') state.settings.lang = params.get('lang');
  if (params.has('sample') && !state.homes.length && !state.cars.length) state = S.sample(state.settings.lang, TODAY, D.templates);
  window.addEventListener('hashchange', () => {
    closeSheet(true);
    render();
  });
  document.addEventListener('click', onClick);
  document.addEventListener('change', onChange);
  document.addEventListener('input', onInput);
  document.addEventListener('keydown', onKey);
  setInterval(() => {
    const now = nowISO();
    if (now !== TODAY) {
      TODAY = now;
      if (!$('#sheet-root')) render();
    }
  }, 60000);
  if (!state.settings.onboarded && !location.hash.startsWith('#/welcome')) location.replace('#/welcome');
  render();
  registerSW();
}

boot();
