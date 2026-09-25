// The explanation site: live dial for today, the Kuwaiti year, Arabic and English.
// Arabic lives in the HTML, English comes from data/site.json.

import * as E from './engine/nokhatha.js';
import { dialSVG } from './app/dial.js';
import { icon } from './app/icons.js';

const $ = (sel, el = document) => el.querySelector(sel);
const $$ = (sel, el = document) => [...el.querySelectorAll(sel)];
const esc = (v) => String(v ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const fill = (s, v) => s.replace(/\{(\w+)\}/g, (_, k) => (v[k] ?? ''));
const todayISO = () => {
  const d = new Date();
  return E.toISO(d.getFullYear(), d.getMonth() + 1, d.getDate());
};

const AR = { text: {}, alt: {}, label: {} };
let EN;
let DYN;
let SEA;
let TASKS;
let lang;

function capture() {
  for (const el of $$('[data-i18n]')) AR.text[el.dataset.i18n] ??= el.textContent;
  for (const el of $$('[data-i18n-alt]')) AR.alt[el.dataset.i18nAlt] ??= el.alt;
  for (const el of $$('[data-i18n-label]')) AR.label[el.dataset.i18nLabel] ??= el.getAttribute('aria-label');
}

function pickLang() {
  const q = new URLSearchParams(location.search).get('lang');
  if (q === 'ar' || q === 'en') return q;
  try {
    const saved = localStorage.getItem('nokhatha.site.lang');
    if (saved === 'ar' || saved === 'en') return saved;
  } catch {
    /* storage unavailable */
  }
  return (navigator.language || 'ar').toLowerCase().startsWith('ar') ? 'ar' : 'en';
}

const days = (n) => (lang === 'ar' ? E.countAr(n, 'day') : `${n} day${n === 1 ? '' : 's'}`);
const byId = () => Object.fromEntries(SEA.seasons.map((s) => [s.id, s]));

function applyText() {
  const html = document.documentElement;
  html.lang = lang;
  html.dir = lang === 'ar' ? 'rtl' : 'ltr';
  for (const el of $$('[data-i18n]')) {
    const v = lang === 'ar' ? AR.text[el.dataset.i18n] : EN[el.dataset.i18n];
    if (v != null) el.textContent = v;
  }
  for (const el of $$('[data-i18n-alt]')) el.alt = (lang === 'ar' ? AR.alt : EN)[el.dataset.i18nAlt] || el.alt;
  for (const el of $$('[data-i18n-label]')) el.setAttribute('aria-label', (lang === 'ar' ? AR.label : EN)[el.dataset.i18nLabel] || '');
  for (const img of $$('img[data-shot]')) img.src = `assets/shots/${lang}-${img.dataset.shot}.webp`;
  document.title = DYN[lang].title;
  const toggle = $('[data-lang-toggle]');
  toggle.textContent = DYN[lang].switch;
  toggle.setAttribute('lang', lang === 'ar' ? 'en' : 'ar');
  $('.brand').setAttribute('aria-label', lang === 'ar' ? AR.text.name : EN.name);
}

function renderDial() {
  const today = todayISO();
  const S = byId();
  const y = E.parseISO(today).y;
  const cur = E.seasonAt(today, SEA.seasons);
  const nm = (id) => S[id][lang];
  const dates = `${E.formatDate(cur.start, lang, y)} ${DYN[lang].to} ${E.formatDate(E.addDays(cur.next, -1), lang, y)}`;
  const left = fill(DYN[lang].left, { n: days(cur.daysLeft), next: nm(cur.nextId) });
  // The seasonal jobs of the year, from the same templates the app uses.
  const dots = TASKS.templates
    .filter((t) => t.every.season)
    .map((t) => {
      const due = E.nextDue({ every: t.every, lastDone: null }, { today, seasons: SEA.seasons, bawarih: SEA.bawarih }).due;
      const st = E.statusOf(due, today, 14);
      return { days: Math.max(0, st.days), status: st.status === 'ok' ? 'ok' : 'soon', label: `${t[lang]}: ${E.formatDate(due, lang, y)}` };
    });
  $('#hero-dial').innerHTML = dialSVG({
    today, seasons: SEA.seasons, groups: SEA.groups, lang, dots, mode: 'labeled', id: 'hero',
    center: { title: nm(cur.id), line1: dates, line2: left, aria: `${nm(cur.id)}، ${left}` },
  });
  const date = `${E.WEEKDAYS[lang][E.weekday(today)]} ${E.formatDate(today, lang, y)}`;
  $('#hero-caption').innerHTML = `<span>${esc(fill(DYN[lang].caption, { date, season: nm(cur.id), n: days(cur.daysLeft), next: nm(cur.nextId) }))}</span><small>${esc(DYN[lang].dots)}</small>`;
}

function renderSeasons() {
  const today = todayISO();
  const S = byId();
  const y = E.parseISO(today).y;
  const ring = E.seasonRing(today, SEA.seasons);
  $('#seasons').innerHTML = ring.segs.map((s, i) => {
    const se = S[s.id];
    const start = E.addDays(today, s.offset);
    const end = E.addDays(start, s.length - 1);
    return `<li class="season g-${se.group}${i === 0 ? ' now' : ''}">
<div class="season-top"><h3>${esc(se[lang])}</h3>${i === 0 ? `<span class="here">${esc(DYN[lang].here)}</span>` : `<span class="grp">${esc(SEA.groups[se.group][lang])}</span>`}</div>
<p class="season-dates">${esc(E.formatDate(start, lang, y))} ${esc(DYN[lang].to)} ${esc(E.formatDate(end, lang, y))}<span class="len">${esc(days(s.length))}</span></p>
<p class="season-note">${esc(se['note_' + lang])}</p>
<p class="season-hint">${icon('spark')}<span>${esc(se['hint_' + lang])}</span></p>
</li>`;
  }).join('');
}

function apply() {
  applyText();
  renderDial();
  renderSeasons();
}

async function boot() {
  capture();
  for (const el of $$('[data-icon]')) el.innerHTML = icon(el.dataset.icon);
  const get = (p) => fetch(p).then((r) => {
    if (!r.ok) throw new Error(p);
    return r.json();
  });
  try {
    const [site, seasons, tasks] = await Promise.all([get('data/site.json'), get('data/seasons.json'), get('data/tasks.json')]);
    EN = site.en;
    DYN = site.dyn;
    SEA = seasons;
    TASKS = tasks;
  } catch {
    return;
  }
  lang = pickLang();
  apply();
  $('[data-lang-toggle]').addEventListener('click', () => {
    lang = lang === 'ar' ? 'en' : 'ar';
    try {
      localStorage.setItem('nokhatha.site.lang', lang);
    } catch {
      /* storage unavailable */
    }
    apply();
  });
}

boot();
