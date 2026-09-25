// Offline support. One cache per version, the app shell answers every navigation.
const VERSION = '0.2.0';
const CACHE = `nokhatha-${VERSION}`;
const FILES = [
  './',
  'index.html',
  'app.css',
  'app.js',
  'icons.js',
  'dial.js',
  'store.js',
  'backup.js',
  'manifest.webmanifest',
  '../engine/nokhatha.js',
  '../data/seasons.json',
  '../data/tasks.json',
  '../data/strings.json',
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
      .then((keys) => Promise.all(keys.filter((k) => k.startsWith('nokhatha-') && k !== CACHE).map((k) => caches.delete(k))))
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
