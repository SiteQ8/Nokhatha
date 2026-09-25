// Offline support, and reminders from the device itself.
// One cache per version, the app shell answers every navigation.
const VERSION = '0.5.0';
const CACHE = `nokhatha-${VERSION}`;
// Written by the page: what is due in the coming weeks, already worded in the person's language.
const DIGEST = 'nokhatha-digest';
importScripts('weather.js');
const FILES = [
  './',
  'index.html',
  'app.css',
  'app.js',
  'icons.js',
  'dial.js',
  'store.js',
  'backup.js',
  'weather.js',
  'manifest.webmanifest',
  '../engine/nokhatha.js',
  '../data/seasons.json',
  '../data/tasks.json',
  '../data/strings.json',
  '../data/places.json',
  '../assets/base.css',
  '../assets/favicon.svg',
  '../assets/icons/icon-192.png',
  '../assets/icons/apple-touch-icon.png',
  '../assets/fonts/fonts.css',
  '../assets/fonts/plex-arabic-400-arabic.woff2',
  '../assets/fonts/plex-arabic-400-latin.woff2',
  '../assets/fonts/plex-arabic-500-arabic.woff2',
  '../assets/fonts/plex-arabic-500-latin.woff2',
  '../assets/fonts/plex-arabic-600-arabic.woff2',
  '../assets/fonts/plex-arabic-600-latin.woff2',
  '../assets/fonts/plex-arabic-700-arabic.woff2',
  '../assets/fonts/plex-arabic-700-latin.woff2',
  '../assets/fonts/reem-kufi-400-700-arabic.woff2',
  '../assets/fonts/reem-kufi-400-700-latin.woff2',
];

self.addEventListener('install', (event) => {
  event.waitUntil(caches.open(CACHE).then((cache) => cache.addAll(FILES)));
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((k) => k.startsWith('nokhatha-') && k !== CACHE && k !== DIGEST).map((k) => caches.delete(k))))
      .then(() => self.clients.claim()),
  );
});

self.addEventListener('message', (event) => {
  if (event.data === 'skip') self.skipWaiting();
});

self.addEventListener('fetch', (event) => {
  const req = event.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);
  if (url.origin !== self.location.origin) return;
  if (req.mode === 'navigate') {
    event.respondWith(caches.match('index.html').then((hit) => hit || fetch(req)));
    return;
  }
  event.respondWith(caches.match(req, { ignoreSearch: true }).then((hit) => hit || fetch(req)));
});

// Chrome wakes an installed app once or twice a day with periodicsync. No server is involved:
// the list of due tasks never leaves the device, and the check runs here.
self.addEventListener('periodicsync', (event) => {
  if (event.tag === 'nokhatha-daily') event.waitUntil(remind());
});

const pad = (n) => String(n).padStart(2, '0');

async function remind() {
  const cache = await caches.open(DIGEST);
  const res = await cache.match('digest.json');
  if (!res) return;
  const d = await res.json();
  const now = new Date();
  const today = `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}`;
  const seen = await cache.match('seen.json').then((r) => (r ? r.json() : {})).catch(() => ({}));
  const save = (x) => cache.put('seen.json', new Response(JSON.stringify(x), { headers: { 'Content-Type': 'application/json' } }));
  const quiet = now.getHours() < 7 || now.getHours() >= 22;
  if (!d.notify || seen.notified === today || quiet) return save({ ...seen, ran: now.toISOString() });
  const due = d.items.filter((x) => x.date <= today);
  const sky = await weatherLine(d, today);
  if (!due.length && !sky) return save({ ...seen, ran: now.toISOString() });
  const late = due.some((x) => x.date < today);
  const lines = (sky ? [sky] : []).concat(due.slice(0, 3).map((x) => x.title));
  const body = lines.join(d.sep) + (due.length > 3 ? d.sep + d.more : '');
  try {
    await self.registration.showNotification(due.length ? (late ? d.titleNow : d.titleToday) : d.weather.title, {
      body, tag: 'nokhatha-due', lang: d.lang, dir: d.dir,
      icon: '../assets/icons/icon-192.png', badge: '../assets/icons/favicon-64.png', data: { url: './#/today' },
    });
  } catch {
    // permission was withdrawn in the browser settings: record the check and stay quiet
    return save({ ...seen, ran: now.toISOString(), blocked: true });
  }
  return save({ ran: now.toISOString(), notified: today });
}

// Only when the person turned weather alerts on: the forecast for their approximate area.
async function weatherLine(d, today) {
  if (!d.weather || !self.NokhathaWeather) return null;
  try {
    const sum = await self.NokhathaWeather.fetchWeather(d.weather.lat, d.weather.lon, fetch, 8000);
    const a = self.NokhathaWeather.alerts(sum, today)[0];
    if (!a) return null;
    return d.weather.texts[a.kind].replace('{day}', a.day === 0 ? d.weather.day0 : d.weather.day1).replace('{t}', a.value == null ? '' : a.value);
  } catch {
    return null;
  }
}

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const url = new URL((event.notification.data && event.notification.data.url) || './#/today', self.registration.scope).href;
  event.waitUntil(self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((list) => {
    const open = list.find((c) => c.url.startsWith(self.registration.scope));
    if (open) return open.focus().then((c) => (c && 'navigate' in c ? c.navigate(url) : c));
    return self.clients.openWindow(url);
  }));
});
