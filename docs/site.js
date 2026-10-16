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

function applyShots() {
  for (const img of $$('[data-shot]')) img.src = `assets/shots/${lang}-${img.dataset.shot}.webp`;
}

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
  $('#hero-caption').innerHTML = `<small>${esc(DYN[lang].dots)}</small>`;
}

const HIJRI_AR = ['المحرم', 'صفر', 'ربيع الأول', 'ربيع الآخر', 'جمادى الأولى', 'جمادى الآخرة', 'رجب', 'شعبان', 'رمضان', 'شوال', 'ذو القعدة', 'ذو الحجة'];
const HIJRI_EN = ['Muharram', 'Safar', 'Rabi al-Awwal', 'Rabi al-Thani', 'Jumada al-Ula', 'Jumada al-Akhira', 'Rajab', 'Shaban', 'Ramadan', 'Shawwal', 'Dhu al-Qadah', 'Dhu al-Hijjah'];

function hijriText(iso) {
  const h = E.toHijri(iso);
  return lang === 'ar' ? `${h.d} ${HIJRI_AR[h.m - 1]} ${h.y} هـ` : `${h.d} ${HIJRI_EN[h.m - 1]} ${h.y} AH`;
}

/** The almanac's head: today in both calendars, the season, and the days to the next one. */
function renderDateline() {
  const today = todayISO();
  const S = byId();
  const y = E.parseISO(today).y;
  const cur = E.seasonAt(today, SEA.seasons);
  const date = `${E.WEEKDAYS[lang][E.weekday(today)]} ${E.formatDate(today, lang, y)}`;
  $('#dateline').innerHTML = esc(fill(DYN[lang].dateline, { date, hijri: hijriText(today), season: S[cur.id][lang], n: days(cur.daysLeft), next: S[cur.nextId][lang] }));
}

/** The year as a table: each season a row, its length drawn to scale, the current one inked. */
function renderSeasons() {
  const today = todayISO();
  const S = byId();
  const y = E.parseISO(today).y;
  const ring = E.seasonRing(today, SEA.seasons);
  const longest = Math.max(...ring.segs.map((s) => s.length));
  $('#seasons').innerHTML = ring.segs.map((s, i) => {
    const se = S[s.id];
    const start = E.addDays(today, s.offset);
    const end = E.addDays(start, s.length - 1);
    const pct = Math.round((s.length / longest) * 100);
    return `<li class="row g-${se.group}${i === 0 ? ' now' : ''}">
<h3>${esc(se[lang])}${i === 0 ? `<span class="here">${esc(DYN[lang].here)}</span>` : ''}<span class="grp">${esc(SEA.groups[se.group][lang])}</span></h3>
<p class="dates">${esc(E.formatDate(start, lang, y))} ${esc(DYN[lang].to)} ${esc(E.formatDate(end, lang, y))}</p>
<p class="len"><span class="bar"><i data-pct="${pct}"></i></span><span class="n">${esc(days(s.length))}</span></p>
<p class="do">${icon('spark')}<span>${esc(se['hint_' + lang])}</span></p>
</li>`;
  }).join('');
  for (const bar of $$('#seasons .len i')) bar.style.width = `${bar.dataset.pct}%`;
}

function apply() {
  applyText();
  applyShots();
  renderDateline();
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
