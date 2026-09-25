// Nokhatha engine
// Dependency-free scheduling for the home, the car and recurring subscriptions,
// driven by the Kuwaiti seasonal calendar.
//
// Rules that keep the three platforms identical (web, iOS, Android):
//   * Dates are ISO strings "YYYY-MM-DD" on the local civil calendar.
//   * All date arithmetic is integer day numbers. No time zones, no floats.
//   * Money is integer minor units (fils for KWD). Never floats.
//   * Every function here is pure. "today" is always passed in.
// tests/vectors.json is the contract every port must satisfy.

export const VERSION = '0.3.0';

// A seasonal task done within this many days of its anchor is not due again
// until the anchor of the following year.
export const SEASONAL_MIN_GAP = 60;
// A seasonal task never done stays due for this many days after its anchor,
// then moves to next year's anchor.
export const SEASONAL_GRACE = 60;
// Fallback daily distance when a car has fewer than two usable odometer readings.
export const DEFAULT_DAILY_KM = 40;

const pad = (n, w = 2) => String(n).padStart(w, '0');

// Integer division helpers. Operands stay far below 2^53, so the quotient
// of two doubles never crosses an integer boundary by rounding.
export function floorDiv(a, b) {
  const q = Math.trunc(a / b);
  return a % b !== 0 && (a < 0) !== (b < 0) ? q - 1 : q;
}
export const ceilDiv = (a, b) => -floorDiv(-a, b);
// Round half up for non negative numerators.
export const roundDiv = (a, b) => floorDiv(2 * a + b, 2 * b);

/* ---------------------------------------------------------------- dates */

export function isLeap(y) {
  return (y % 4 === 0 && y % 100 !== 0) || y % 400 === 0;
}

export function daysInMonth(y, m) {
  return [31, isLeap(y) ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][m - 1];
}

export function parseISO(s) {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(String(s || ''));
  if (!m) throw new Error('bad date: ' + s);
  const y = +m[1], mo = +m[2], d = +m[3];
  if (mo < 1 || mo > 12 || d < 1 || d > daysInMonth(y, mo)) throw new Error('bad date: ' + s);
  return { y, m: mo, d };
}

export function isISO(s) {
  try { parseISO(s); return true; } catch { return false; }
}

export const toISO = (y, m, d) => `${pad(y, 4)}-${pad(m)}-${pad(d)}`;

// Days since 1970-01-01 (civil calendar, proleptic Gregorian).
export function dayNumber(iso) {
  let { y, m, d } = parseISO(iso);
  y -= m <= 2 ? 1 : 0;
  const era = floorDiv(y, 400);
  const yoe = y - era * 400;
  const mp = (m + 9) % 12;
  const doy = floorDiv(153 * mp + 2, 5) + d - 1;
  const doe = yoe * 365 + floorDiv(yoe, 4) - floorDiv(yoe, 100) + doy;
  return era * 146097 + doe - 719468;
}

export function fromDayNumber(z) {
  z += 719468;
  const era = floorDiv(z, 146097);
  const doe = z - era * 146097;
  const yoe = floorDiv(doe - floorDiv(doe, 1460) + floorDiv(doe, 36524) - floorDiv(doe, 146096), 365);
  const doy = doe - (365 * yoe + floorDiv(yoe, 4) - floorDiv(yoe, 100));
  const mp = floorDiv(5 * doy + 2, 153);
  const d = doy - floorDiv(153 * mp + 2, 5) + 1;
  const m = mp < 10 ? mp + 3 : mp - 9;
  return toISO(yoe + era * 400 + (m <= 2 ? 1 : 0), m, d);
}

export const addDays = (iso, n) => fromDayNumber(dayNumber(iso) + n);
export const diffDays = (a, b) => dayNumber(b) - dayNumber(a);
export const minISO = (a, b) => (a <= b ? a : b);
export const maxISO = (a, b) => (a >= b ? a : b);

// Adds calendar months and clamps to the last day of the target month.
export function addMonths(iso, n) {
  const { y, m, d } = parseISO(iso);
  const t = y * 12 + (m - 1) + n;
  const ny = floorDiv(t, 12);
  const nm = t - ny * 12 + 1;
  return toISO(ny, nm, Math.min(d, daysInMonth(ny, nm)));
}

// 0 = Sunday ... 6 = Saturday
export const weekday = (iso) => ((dayNumber(iso) % 7) + 7 + 4) % 7;

/* -------------------------------------------------------------- seasons */

const startIn = (season, year) => {
  const [m, d] = season.start.split('-').map(Number);
  return toISO(year, m, d);
};

function startsAround(iso, seasons) {
  const { y } = parseISO(iso);
  const out = [];
  for (let yy = y - 1; yy <= y + 2; yy++) {
    for (let i = 0; i < seasons.length; i++) out.push({ i, date: startIn(seasons[i], yy) });
  }
  out.sort((a, b) => (a.date < b.date ? -1 : a.date > b.date ? 1 : 0));
  return out;
}

function currentIndex(list, iso) {
  let k = -1;
  for (let j = 0; j < list.length; j++) if (list[j].date <= iso) k = j;
  return k;
}

// The Kuwaiti season a date falls in.
export function seasonAt(iso, seasons) {
  const list = startsAround(iso, seasons);
  const k = currentIndex(list, iso);
  const cur = list[k], nxt = list[k + 1];
  return {
    id: seasons[cur.i].id,
    index: cur.i,
    start: cur.date,
    next: nxt.date,
    nextId: seasons[nxt.i].id,
    length: diffDays(cur.date, nxt.date),
    dayIn: diffDays(cur.date, iso) + 1,
    daysLeft: diffDays(iso, nxt.date),
  };
}

// One full turn of the calendar starting with the season that contains iso.
// offset is the start of each segment relative to iso, in days.
export function seasonRing(iso, seasons) {
  const list = startsAround(iso, seasons);
  const k = currentIndex(list, iso);
  const segs = [];
  for (let j = 0; j < seasons.length; j++) {
    const a = list[k + j], b = list[k + j + 1];
    segs.push({ id: seasons[a.i].id, start: a.date, offset: diffDays(iso, a.date), length: diffDays(a.date, b.date) });
  }
  return { total: segs.reduce((t, s) => t + s.length, 0), segs };
}

// First start of a given season on or after iso.
export function seasonStartOnOrAfter(iso, seasonId, seasons) {
  const s = seasons.find((x) => x.id === seasonId);
  if (!s) throw new Error('unknown season: ' + seasonId);
  const { y } = parseISO(iso);
  for (let yy = y - 1; yy <= y + 2; yy++) {
    const d = startIn(s, yy);
    if (d >= iso) return d;
  }
  return null;
}

// A window is a month-day range such as the Bawarih winds, {start:"06-07", end:"07-28"}.
export function inWindow(iso, w) {
  const md = iso.slice(5);
  return w.start <= w.end ? md >= w.start && md <= w.end : md >= w.start || md <= w.end;
}

/* ------------------------------------------------------------- schedule */

function anchorsFor(seasonId, offset, y0, y1, seasons) {
  const s = seasons.find((x) => x.id === seasonId);
  if (!s) throw new Error('unknown season: ' + seasonId);
  const out = [];
  for (let y = y0; y <= y1; y++) out.push(addDays(startIn(s, y), offset));
  return out;
}

// Next due date of a yearly task pinned to a season (for example 21 days before Al-Wasm).
export function seasonalDue(lastDone, seasonId, offset, today, seasons) {
  if (lastDone) {
    const th = addDays(lastDone, SEASONAL_MIN_GAP);
    const y = parseISO(th).y;
    return anchorsFor(seasonId, offset, y - 1, y + 2, seasons).find((a) => a >= th);
  }
  const y = parseISO(today).y;
  const as = anchorsFor(seasonId, offset, y - 1, y + 2, seasons);
  const prev = as.filter((a) => a <= today).pop();
  if (prev && diffDays(prev, today) <= SEASONAL_GRACE) return prev;
  return as.find((a) => a > today);
}

function sortedReadings(car) {
  return (car && car.readings ? car.readings.slice() : []).sort((a, b) => (a.date < b.date ? -1 : a.date > b.date ? 1 : 0));
}

export function lastReading(car) {
  const r = sortedReadings(car);
  return r.length ? r[r.length - 1] : null;
}

// Kilometres per day as an exact fraction {num, den}.
// Uses the earliest reading within 180 days of the latest one, spanning at least 14 days.
export function kmRate(car) {
  const r = sortedReadings(car);
  if (r.length >= 2) {
    const L = r[r.length - 1];
    const from = addDays(L.date, -180);
    const E = r.find((x) => x.date >= from && x.date < L.date) || r[0];
    const span = diffDays(E.date, L.date);
    const dist = L.km - E.km;
    if (span >= 14 && dist > 0) return { num: dist, den: span };
  }
  const daily = car && car.dailyKm > 0 ? car.dailyKm : DEFAULT_DAILY_KM;
  return { num: daily, den: 1 };
}

// The date the odometer is expected to reach target km (may be in the past).
export function dateAtKm(car, target) {
  const L = lastReading(car);
  if (!L) return null;
  const { num, den } = kmRate(car);
  return addDays(L.date, ceilDiv((target - L.km) * den, num));
}

// Estimated odometer on a date.
export function kmOn(car, iso) {
  const L = lastReading(car);
  if (!L) return null;
  const d = diffDays(L.date, iso);
  if (d <= 0) return L.km;
  const { num, den } = kmRate(car);
  return L.km + floorDiv(d * num, den);
}

// item: { every, lastDone, lastKm, due, snoozeUntil }
// every: {days, bawarih} | {months} | {km, months} | {season, offset} | {fixed}
// ctx: { today, seasons, bawarih, car }
// returns { due, by } where by is time | km | season | fixed | new | unset | snooze
export function nextDue(item, ctx) {
  const s = item.every || {};
  const today = ctx.today;
  let res;
  if (s.fixed) {
    res = item.due ? { due: item.due, by: 'fixed' } : { due: null, by: 'unset' };
  } else if (s.season) {
    res = { due: seasonalDue(item.lastDone, s.season, s.offset || 0, today, ctx.seasons), by: 'season' };
  } else {
    let due = null;
    let by = 'time';
    if (item.lastDone) {
      if (s.months) due = addMonths(item.lastDone, s.months);
      if (s.days) {
        let n = s.days;
        if (s.bawarih && ctx.bawarih && inWindow(item.lastDone, ctx.bawarih)) n = s.bawarih;
        const t = addDays(item.lastDone, n);
        due = due ? minISO(due, t) : t;
      }
    } else {
      // never logged: due on its planned first date, or today when there is none
      due = item.firstDue || today;
      by = 'new';
    }
    if (s.km && ctx.car && item.lastKm != null) {
      const kd = dateAtKm(ctx.car, item.lastKm + s.km);
      if (kd && (!due || kd < due)) {
        due = kd;
        by = 'km';
      }
    }
    res = { due, by };
  }
  if (item.snoozeUntil && res.due && item.snoozeUntil > res.due) res = { due: item.snoozeUntil, by: 'snooze' };
  return res;
}

// overdue | today | soon | ok | unset
export function statusOf(due, today, lead) {
  if (!due) return { status: 'unset', days: null };
  const days = diffDays(today, due);
  const status = days < 0 ? 'overdue' : days === 0 ? 'today' : days <= lead ? 'soon' : 'ok';
  return { status, days };
}

// Share of the current cycle already used, 0..1. For display only.
export function cycleProgress(lastDone, due, today) {
  if (!lastDone || !due) return 0;
  const total = diffDays(lastDone, due);
  if (total <= 0) return 1;
  return Math.max(0, Math.min(1, diffDays(lastDone, today) / total));
}

/* -------------------------------------------------------- subscriptions */

export const CYCLES = {
  weekly: { days: 7 },
  monthly: { months: 1 },
  quarterly: { months: 3 },
  semiannual: { months: 6 },
  yearly: { months: 12 },
};

// Renewals are always computed from the anchor, never chained,
// so a subscription on the 31st returns to the 31st after February.
export function nthRenewal(anchor, cycle, n) {
  const c = CYCLES[cycle];
  if (!c) throw new Error('bad cycle: ' + cycle);
  return c.days ? addDays(anchor, c.days * n) : addMonths(anchor, c.months * n);
}

export function nextRenewal(sub, today) {
  if (sub.anchor >= today) return sub.anchor;
  const c = CYCLES[sub.cycle];
  const gap = diffDays(sub.anchor, today);
  let n = Math.max(0, (c.days ? floorDiv(gap, c.days) : floorDiv(gap, c.months * 31)) - 1);
  while (nthRenewal(sub.anchor, sub.cycle, n) < today) n++;
  return nthRenewal(sub.anchor, sub.cycle, n);
}

// Number of charges falling in [from, to], counting from the anchor.
export function chargesBetween(sub, from, to) {
  let n = 0;
  let count = 0;
  for (;;) {
    const d = nthRenewal(sub.anchor, sub.cycle, n);
    if (d > to) break;
    if (d >= from) count++;
    n++;
    if (n > 2000) break;
  }
  return count;
}

export function perMonth(minor, cycle) {
  switch (cycle) {
    case 'weekly': return roundDiv(minor * 52, 12);
    case 'monthly': return minor;
    case 'quarterly': return roundDiv(minor, 3);
    case 'semiannual': return roundDiv(minor, 6);
    case 'yearly': return roundDiv(minor, 12);
    default: throw new Error('bad cycle: ' + cycle);
  }
}

export function perYear(minor, cycle) {
  const k = { weekly: 52, monthly: 12, quarterly: 4, semiannual: 2, yearly: 1 }[cycle];
  if (!k) throw new Error('bad cycle: ' + cycle);
  return minor * k;
}

// Totals per currency for subscriptions that are not cancelled.
export function subTotals(subs) {
  const out = {};
  for (const s of subs) {
    if (s.cancelled) continue;
    const t = out[s.currency] || (out[s.currency] = { month: 0, year: 0, count: 0 });
    t.month += perMonth(s.amount, s.cycle);
    t.year += perYear(s.amount, s.cycle);
    t.count += 1;
  }
  return out;
}

/* ---------------------------------------------------------------- money */

export const CURRENCIES = {
  KWD: { d: 3, ar: 'د.ك' },
  SAR: { d: 2, ar: 'ر.س' },
  AED: { d: 2, ar: 'د.إ' },
  QAR: { d: 2, ar: 'ر.ق' },
  BHD: { d: 3, ar: 'د.ب' },
  OMR: { d: 3, ar: 'ر.ع' },
  USD: { d: 2, ar: 'دولار' },
};

export function formatMoney(minor, code, lang) {
  const c = CURRENCIES[code];
  if (!c) throw new Error('bad currency: ' + code);
  const neg = minor < 0;
  const a = Math.abs(minor);
  const p = 10 ** c.d;
  const major = String(floorDiv(a, p)).replace(/\B(?=(\d{3})+(?!\d))/g, ',');
  const num = (neg ? '-' : '') + major + '.' + String(a % p).padStart(c.d, '0');
  return lang === 'ar' ? `${num} ${c.ar}` : `${code} ${num}`;
}

// Arabic Indic and Persian digits, Arabic decimal and thousands marks, to ASCII.
export function normalizeDigits(s) {
  return String(s)
    .replace(/[\u0660-\u0669]/g, (ch) => String(ch.charCodeAt(0) - 0x0660))
    .replace(/[\u06F0-\u06F9]/g, (ch) => String(ch.charCodeAt(0) - 0x06f0))
    .replace(/\u066B/g, '.')
    .replace(/\u066C/g, ',');
}

// Reads what a person types ("4.5", "٤٫٥٠٠", "2,5", "1,500 SAR") into minor units.
// A single comma is a decimal mark when the digits after it fit the currency,
// otherwise commas are thousands marks. Extra decimals are rounded half up.
export function parseMoney(text, code) {
  const c = CURRENCIES[code];
  if (!c) return null;
  const m = normalizeDigits(text).match(/[\d.,]*\d/);
  if (!m) return null;
  let s = m[0];
  if (/^[.,]/.test(s)) s = '0' + s;
  if (s.includes('.') && s.includes(',')) {
    s = s.replace(/,/g, '');
  } else if (s.includes(',')) {
    const parts = s.split(',');
    s = parts.length === 2 && parts[1].length <= c.d ? parts[0] + '.' + parts[1] : parts.join('');
  }
  if (!/^\d+(\.\d+)?$/.test(s)) return null;
  const [ip, fp = ''] = s.split('.');
  const digits = fp.padEnd(c.d + 1, '0');
  let minor = Number(ip) * 10 ** c.d + Number(digits.slice(0, c.d) || '0');
  if (Number(digits[c.d]) >= 5) minor += 1;
  return minor;
}

/* -------------------------------------------------------------- wording */

function spanOf(days) {
  if (days < 14) return [days, 'day'];
  if (days < 30) return [floorDiv(days, 7), 'week'];
  if (days < 335) return [floorDiv(days, 30), 'month'];
  return [Math.max(1, roundDiv(days, 365)), 'year'];
}

// Kuwaiti dialect counting: 1, 2 (dual), 3 to 10 plural, 11 and up singular.
const AR_UNITS = {
  day: ['يوم', 'يومين', 'أيام', 'يوم'],
  week: ['أسبوع', 'أسبوعين', 'أسابيع', 'أسبوع'],
  month: ['شهر', 'شهرين', 'شهور', 'شهر'],
  year: ['سنة', 'سنتين', 'سنوات', 'سنة'],
};

export function countAr(n, unit) {
  const f = AR_UNITS[unit];
  if (n === 1) return f[0];
  if (n === 2) return f[1];
  if (n <= 10) return `${n} ${f[2]}`;
  return `${n} ${f[3]}`;
}

// Relative wording for a number of days from today.
export function relative(days, lang) {
  if (lang === 'ar') {
    if (days === 0) return 'اليوم';
    if (days === 1) return 'باچر';
    if (days === -1) return 'أمس';
    const [n, u] = spanOf(Math.abs(days));
    return (days > 0 ? 'بعد ' : 'من ') + countAr(n, u);
  }
  if (days === 0) return 'today';
  if (days === 1) return 'tomorrow';
  if (days === -1) return 'yesterday';
  const [n, u] = spanOf(Math.abs(days));
  const w = `${n} ${u}${n === 1 ? '' : 's'}`;
  return days > 0 ? `in ${w}` : `${w} ago`;
}

export const MONTHS = {
  ar: ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'],
  en: ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'],
};
export const WEEKDAYS = {
  ar: ['الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'],
  en: ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'],
};

// "25 سبتمبر" or "25 September", with the year when it differs from refYear.
export function formatDate(iso, lang, refYear) {
  const { y, m, d } = parseISO(iso);
  const base = `${d} ${MONTHS[lang === 'ar' ? 'ar' : 'en'][m - 1]}`;
  return refYear && y !== refYear ? `${base} ${y}` : base;
}

/* ------------------------------------------------------------ calendar */

function icsEscape(s) {
  return String(s).replace(/\\/g, '\\\\').replace(/;/g, '\\;').replace(/,/g, '\\,').replace(/\r?\n/g, '\\n');
}

const utf8Len = (ch) => {
  const c = ch.codePointAt(0);
  return c < 0x80 ? 1 : c < 0x800 ? 2 : c < 0x10000 ? 3 : 4;
};

// Folds a content line at 75 octets without splitting a character (RFC 5545 3.1).
export function foldLine(line) {
  const out = [];
  let cur = '';
  let bytes = 0;
  for (const ch of line) {
    const b = utf8Len(ch);
    if (bytes + b > 75) {
      out.push(cur);
      cur = ' ' + ch;
      bytes = 1 + b;
    } else {
      cur += ch;
      bytes += b;
    }
  }
  out.push(cur);
  return out.join('\r\n');
}

// events: [{ uid, date, title, note, lead }]; stamp: "YYYYMMDDTHHMMSSZ"
// Each event is an all-day entry with an alert at 9:00 on the day,
// and another at 9:00 lead days before when lead > 0.
export function toICS(events, { stamp, calName }) {
  const L = [
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//Nokhatha//Nokhatha//AR',
    'CALSCALE:GREGORIAN',
    'METHOD:PUBLISH',
    `X-WR-CALNAME:${icsEscape(calName)}`,
  ];
  for (const e of events) {
    const title = icsEscape(e.title);
    L.push(
      'BEGIN:VEVENT',
      `UID:${e.uid}@nokhatha.3li.info`,
      `DTSTAMP:${stamp}`,
      `DTSTART;VALUE=DATE:${e.date.replace(/-/g, '')}`,
      `DTEND;VALUE=DATE:${addDays(e.date, 1).replace(/-/g, '')}`,
      `SUMMARY:${title}`,
    );
    if (e.note) L.push(`DESCRIPTION:${icsEscape(e.note)}`);
    L.push('BEGIN:VALARM', 'ACTION:DISPLAY', `DESCRIPTION:${title}`, 'TRIGGER:PT9H', 'END:VALARM');
    if (e.lead > 0) {
      const t = e.lead - 1 > 0 ? `-P${e.lead - 1}DT15H` : '-PT15H';
      L.push('BEGIN:VALARM', 'ACTION:DISPLAY', `DESCRIPTION:${title}`, `TRIGGER:${t}`, 'END:VALARM');
    }
    L.push('END:VEVENT');
  }
  L.push('END:VCALENDAR');
  return L.map(foldLine).join('\r\n') + '\r\n';
}
