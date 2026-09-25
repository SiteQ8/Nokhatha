// The year dial. Today sits at the top as a pearl, time runs clockwise,
// every Kuwaiti season is a segment sized by its days, and due tasks are dots.
// Pure string output so the app and the site share one drawing.

import { seasonRing, parseISO, diffDays, toISO } from '../engine/nokhatha.js';

const GEO = {
  compact: { w: 400, h: 400, cx: 200, cy: 200, rOut: 184, rIn: 154, tooth: 9, teeth: 9, dotR: 136, dotStep: 14, dot: 6, bead: 12, labels: false, title: 44, sub: 16, gapT: 30 },
  labeled: { w: 640, h: 480, cx: 320, cy: 240, rOut: 168, rIn: 140, tooth: 8, teeth: 9, dotR: 122, dotStep: 13, dot: 5.5, bead: 11, labels: true, labelR: 200, title: 40, sub: 15, gapT: 28 },
};

const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const rad = (deg) => (deg * Math.PI) / 180;
const f = (n) => Math.round(n * 100) / 100;

function pt(g, r, deg) {
  return [g.cx + r * Math.cos(rad(deg)), g.cy + r * Math.sin(rad(deg))];
}

function sector(g, a1, a2, r1, r2) {
  const [x1, y1] = pt(g, r2, a1);
  const [x2, y2] = pt(g, r2, a2);
  const [x3, y3] = pt(g, r1, a2);
  const [x4, y4] = pt(g, r1, a1);
  const large = a2 - a1 > 180 ? 1 : 0;
  return `M${f(x1)} ${f(y1)}A${r2} ${r2} 0 ${large} 1 ${f(x2)} ${f(y2)}L${f(x3)} ${f(y3)}A${r1} ${r1} 0 ${large} 0 ${f(x4)} ${f(y4)}Z`;
}

// Sadu teeth along the outside of the current season.
function teeth(g, a1, a2) {
  const r0 = g.rOut + 3;
  const r1 = r0 + g.teeth;
  const step = (g.tooth / r0) * (180 / Math.PI);
  const n = Math.max(1, Math.floor((a2 - a1) / step));
  const start = a1 + (a2 - a1 - n * step) / 2;
  let d = '';
  for (let i = 0; i < n; i++) {
    const b1 = start + i * step;
    const [x1, y1] = pt(g, r0, b1);
    const [x2, y2] = pt(g, r1, b1 + step / 2);
    const [x3, y3] = pt(g, r0, b1 + step);
    d += `M${f(x1)} ${f(y1)}L${f(x2)} ${f(y2)}L${f(x3)} ${f(y3)}Z`;
  }
  return d;
}

/**
 * opts.today    ISO date
 * opts.seasons  seasons from data/seasons.json
 * opts.groups   group names from data/seasons.json
 * opts.lang     'ar' | 'en'
 * opts.dots     [{ days, status, label }] days from today
 * opts.mode     'compact' | 'labeled'
 * opts.center   { title, line1, line2, aria }
 * opts.id       unique prefix for gradient ids
 */
export function dialSVG(opts) {
  const { today, seasons, groups, lang = 'ar', dots = [], mode = 'compact', center = {}, id = 'dial' } = opts;
  const g = GEO[mode];
  const ring = seasonRing(today, seasons);
  const k = 360 / ring.total;
  const ang = (off) => -90 + off * k;
  const byId = Object.fromEntries(seasons.map((s) => [s.id, s]));
  const name = (sid) => byId[sid][lang === 'ar' ? 'ar' : 'en'];
  const gap = 0.8;
  const first = ring.segs[0];

  let segs = '';
  ring.segs.forEach((s, i) => {
    const a1 = ang(s.offset) + gap / 2;
    const a2 = ang(s.offset + s.length) - gap / 2;
    const title = `<title>${esc(name(s.id))}</title>`;
    if (i === 0) {
      // the season we are in: its elapsed part is quieter than what is left of it
      const mid = ang(0);
      segs += `<path class="sg now-past" d="${sector(g, a1, mid, g.rIn, g.rOut)}">${title}</path>`;
      segs += `<path class="sg now" d="${sector(g, mid, a2, g.rIn, g.rOut)}">${title}</path>`;
    } else {
      segs += `<path class="sg g-${byId[s.id].group}" d="${sector(g, a1, a2, g.rIn, g.rOut)}">${title}</path>`;
    }
  });

  // First day of every Gregorian month, as a quiet tick inside the ring.
  let ticks = '';
  const { y, m } = parseISO(today);
  for (let i = 0; i < 13; i++) {
    const mm = ((m - 1 + i) % 12) + 1;
    const yy = y + Math.floor((m - 1 + i) / 12);
    const off = diffDays(today, toISO(yy, mm, 1));
    if (off < first.offset || off >= first.offset + ring.total) continue;
    const a = ang(off);
    const [x1, y1] = pt(g, g.rIn - 3, a);
    const [x2, y2] = pt(g, g.rIn - 9, a);
    ticks += `M${f(x1)} ${f(y1)}L${f(x2)} ${f(y2)}`;
  }

  // Dots: upcoming things sit on their date, stacked inward when they crowd.
  // Overdue things are not scattered behind today, they become one count beside the pearl.
  let dotSvg = '';
  const placed = [];
  const gapPx = g.dot * 2 + 1.5;
  const upcoming = dots
    .filter((d) => d.days != null && d.days >= 0 && d.days < first.offset + ring.total)
    .sort((a, b) => a.days - b.days);
  for (const d of upcoming) {
    const a = ang(Math.max(d.days, 1.5));
    for (let n = 0; n < 3; n++) {
      const [cx, cy] = pt(g, g.dotR - n * g.dotStep, a);
      if (placed.some(([x, y]) => Math.hypot(x - cx, y - cy) < gapPx)) continue;
      placed.push([cx, cy]);
      dotSvg += `<circle class="dot s-${esc(d.status)}" cx="${f(cx)}" cy="${f(cy)}" r="${g.dot}"><title>${esc(d.label || '')}</title></circle>`;
      break;
    }
  }
  const late = dots.filter((d) => d.days != null && d.days < 0).length;
  if (late) {
    const [lx, ly] = pt(g, g.dotR - 4, ang(-Math.min(14, Math.max(8, -first.offset * 0.5))));
    dotSvg += `<g class="late"><circle cx="${f(lx)}" cy="${f(ly)}" r="${g.dot * 2.3}"/><text x="${f(lx)}" y="${f(ly + 5)}" text-anchor="middle">${late}</text><title>${esc(opts.lateLabel || '')}</title></g>`;
  }

  // Labels on the wide dial: every long season, and the summer run as one word.
  let labels = '';
  if (g.labels) {
    const place = (text, a, cls) => {
      const [x, yy] = pt(g, g.labelR, a);
      const c = Math.cos(rad(a));
      const s = Math.sin(rad(a));
      const anchor = c > 0.3 ? 'start' : c < -0.3 ? 'end' : 'middle';
      const dy = s < -0.8 ? -2 : s > 0.8 ? 12 : 5;
      labels += `<text class="${cls}" x="${f(x)}" y="${f(yy + dy)}" text-anchor="${anchor}" direction="ltr">${esc(text)}</text>`;
    };
    let run = null;
    ring.segs.forEach((s, i) => {
      const grp = byId[s.id].group;
      if (i > 0 && s.length < 26 && grp === 'qaith') {
        run = run ? { ...run, end: s.offset + s.length } : { start: s.offset, end: s.offset + s.length };
        return;
      }
      if (run) {
        place(groups.qaith[lang === 'ar' ? 'ar' : 'en'], ang((run.start + run.end) / 2), 'lbl');
        run = null;
      }
      const mid = i === 0 ? Math.max(ang(0) + 8, ang(s.offset + s.length / 2)) : ang(s.offset + s.length / 2);
      place(name(s.id), mid, i === 0 ? 'lbl now' : 'lbl');
    });
    if (run) place(groups.qaith[lang === 'ar' ? 'ar' : 'en'], ang((run.start + run.end) / 2), 'lbl');
  }

  const [bx, by] = pt(g, (g.rIn + g.rOut) / 2, -90);
  const dir = lang === 'ar' ? 'rtl' : 'ltr';
  const cy = g.cy;
  return `<svg class="dial dial-${mode}" viewBox="0 0 ${g.w} ${g.h}" role="img" aria-label="${esc(center.aria || center.title || '')}">
<defs><radialGradient id="${id}-pearl" cx="36%" cy="30%" r="78%"><stop offset="0" stop-color="#FFFFFF"/><stop offset=".55" stop-color="#EEF1F4"/><stop offset="1" stop-color="#BFC7D5"/></radialGradient></defs>
<g class="segs">${segs}</g>
<path class="teeth" d="${teeth(g, ang(first.offset) + gap, ang(first.offset + first.length) - gap)}"/>
<path class="ticks" d="${ticks}"/>
<g class="dots">${dotSvg}</g>
<circle class="bead" cx="${f(bx)}" cy="${f(by)}" r="${g.bead}" fill="url(#${id}-pearl)"/>
${labels}
<text class="dial-title" x="${g.cx}" y="${cy + 2}" text-anchor="middle" direction="${dir}">${esc(center.title || '')}</text>
<text class="dial-sub" x="${g.cx}" y="${cy + g.gapT + 2}" text-anchor="middle" direction="${dir}">${esc(center.line1 || '')}</text>
<text class="dial-sub dial-sub2" x="${g.cx}" y="${cy + g.gapT * 2 - 2}" text-anchor="middle" direction="${dir}">${esc(center.line2 || '')}</text>
</svg>`;
}
