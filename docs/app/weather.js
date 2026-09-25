// Weather alerts for the Gulf. Shared by the page (imported as a module) and by the
// service worker (importScripts), so it declares no imports or exports and sets one global.
//
// Data: Open-Meteo forecast and air quality APIs (free, no key), sent only an approximate
// location, and only when the person turns weather alerts on.
//
// Dust is judged against the place's own recent history: Kuwait and Riyadh usually carry
// ten times the dust of Muscat, so one fixed number would alert every day in one city and
// never in another. A day is dusty when it beats 90% of the last 60 days there.
(function (root) {
  const FORECAST = 'https://api.open-meteo.com/v1/forecast';
  const AIR = 'https://air-quality-api.open-meteo.com/v1/air-quality';

  const LIMITS = {
    dustFloor: 150, // never call a day dusty below this PM10 daily maximum, in micrograms per cubic metre
    rainMm: 0.5,
    rainChance: 50,
    heat: 48, // degrees C, daily maximum
    cold: 4, // degrees C, daily minimum
    gust: 60, // km/h
  };
  const ORDER = { dust_heavy: 0, rain: 1, wind: 2, dust: 3, heat: 4, cold: 5 };

  function urls(lat, lon) {
    const at = `latitude=${lat}&longitude=${lon}&timezone=auto`;
    return {
      forecast: `${FORECAST}?${at}&daily=temperature_2m_max,temperature_2m_min,precipitation_sum,precipitation_probability_max,wind_gusts_10m_max&forecast_days=3`,
      air: `${AIR}?${at}&hourly=pm10&past_days=60&forecast_days=3`,
    };
  }

  function percentile(sorted, f) {
    if (!sorted.length) return null;
    return sorted[Math.min(sorted.length - 1, Math.floor(f * (sorted.length - 1)))];
  }

  // Both responses into one small summary that is cheap to keep.
  function summarize(forecast, air) {
    const dust = {};
    const hourly = (air && air.hourly) || {};
    (hourly.time || []).forEach((t, i) => {
      const v = hourly.pm10 ? hourly.pm10[i] : null;
      if (v == null) return;
      const day = t.slice(0, 10);
      dust[day] = Math.max(dust[day] || 0, v);
    });
    const f = (forecast && forecast.daily) || {};
    const days = (f.time || []).map((date, i) => ({
      date,
      tmax: f.temperature_2m_max ? f.temperature_2m_max[i] : null,
      tmin: f.temperature_2m_min ? f.temperature_2m_min[i] : null,
      rain: f.precipitation_sum ? f.precipitation_sum[i] : null,
      chance: f.precipitation_probability_max ? f.precipitation_probability_max[i] : null,
      gust: f.wind_gusts_10m_max ? f.wind_gusts_10m_max[i] : null,
      dust: dust[date] != null ? Math.round(dust[date]) : null,
    }));
    const first = days.length ? days[0].date : '9999-12-31';
    const history = Object.keys(dust).filter((d) => d < first).map((d) => dust[d]).sort((a, b) => a - b);
    const p90 = percentile(history, 0.9);
    const p97 = percentile(history, 0.97);
    const dusty = Math.max(LIMITS.dustFloor, p90 == null ? Infinity : p90);
    const heavy = Math.max(dusty * 1.25, p97 == null ? Infinity : p97);
    return { days, dusty: Math.round(dusty), heavy: Math.round(heavy), history: history.length };
  }

  // Alerts for today (day 0) and tomorrow (day 1), most serious first.
  function alerts(summary, today) {
    const out = [];
    if (!summary || !summary.days) return out;
    for (const [dayIndex, date] of [[0, today], [1, nextDay(today)]]) {
      const d = summary.days.find((x) => x.date === date);
      if (!d) continue;
      if (d.dust != null && summary.history >= 20) {
        if (d.dust >= summary.heavy) out.push({ kind: 'dust_heavy', day: dayIndex });
        else if (d.dust >= summary.dusty) out.push({ kind: 'dust', day: dayIndex });
      }
      if ((d.rain != null && d.rain >= LIMITS.rainMm) || (d.chance != null && d.chance >= LIMITS.rainChance)) out.push({ kind: 'rain', day: dayIndex });
      if (d.gust != null && d.gust >= LIMITS.gust) out.push({ kind: 'wind', day: dayIndex });
      if (d.tmax != null && d.tmax >= LIMITS.heat) out.push({ kind: 'heat', day: dayIndex, value: Math.round(d.tmax) });
      if (d.tmin != null && d.tmin <= LIMITS.cold) out.push({ kind: 'cold', day: dayIndex, value: Math.round(d.tmin) });
    }
    return out.sort((a, b) => a.day - b.day || ORDER[a.kind] - ORDER[b.kind]);
  }

  function nextDay(iso) {
    const [y, m, d] = iso.split('-').map(Number);
    const t = new Date(Date.UTC(y, m - 1, d + 1));
    return t.toISOString().slice(0, 10);
  }

  async function fetchWeather(lat, lon, fetchImpl, timeoutMs) {
    const u = urls(lat, lon);
    const ctl = typeof AbortController !== 'undefined' ? new AbortController() : null;
    const timer = ctl ? setTimeout(() => ctl.abort(), timeoutMs || 10000) : null;
    try {
      const opts = ctl ? { signal: ctl.signal, credentials: 'omit', referrerPolicy: 'no-referrer' } : {};
      const [a, b] = await Promise.all([fetchImpl(u.forecast, opts), fetchImpl(u.air, opts)]);
      if (!a.ok || !b.ok) throw new Error('weather ' + a.status + ' ' + b.status);
      return summarize(await a.json(), await b.json());
    } finally {
      if (timer) clearTimeout(timer);
    }
  }

  root.NokhathaWeather = { LIMITS, urls, summarize, alerts, fetchWeather, nextDay };
})(typeof self !== 'undefined' ? self : globalThis);
