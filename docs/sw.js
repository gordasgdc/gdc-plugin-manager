/* =============================================================================
   GDC (gordas.dev) — Service Worker
   -----------------------------------------------------------------------------
   Rol: face site-ul instalabil (PWA) si utilizabil offline, si sta la baza
   APK-ului Android din folderul twa/. Acelasi cod ruleaza si in browser, si in
   aplicatia de pe telefon.

   CUM SE ACTUALIZEAZA:
   La FIECARE modificare de index.html / catalog.json / iconite, INCREMENTEAZA
   CACHE_VERSION de mai jos. Altfel utilizatorii raman cu versiunea veche din
   cache. E singurul pas obligatoriu la fiecare release al paginii.

   Strategii, alese pe tip de continut:
   - navigari HTML ...... network-first  (pagina se schimba des)
   - catalog/update.json  network-first  (produse noi, preturi, evenimente)
   - imagini, coperti ... cache-first    (nu se schimba la acelasi URL)
   - fonturi Google ..... cache-first    (imutabile, versionate in URL)

   IMPORTANT pentru catalog.json: e network-first, deci un produs nou apare in
   aplicatie imediat ce publici catalogul — FARA APK nou si fara reinstalare.
============================================================================= */

const CACHE_VERSION = 'v1';                  // <-- INCREMENTEAZA la fiecare update de pagina
const SHELL_CACHE   = `gdc-shell-${CACHE_VERSION}`;
const RUNTIME_CACHE = `gdc-runtime-${CACHE_VERSION}`;

// "App shell": minimul care trebuie sa existe offline imediat dupa instalare.
const SHELL_ASSETS = [
  '/',
  '/index.html',
  '/offline.html',
  '/catalog.json',
  '/manifest.webmanifest',
  '/favicon.ico',
  '/favicon-32.png',
  '/apple-touch-icon.png',
  '/icons/icon-192.png',
  '/icons/icon-512.png',
  '/icons/icon-maskable-512.png',
];

// ── Install ─────────────────────────────────────────────────────────────────
self.addEventListener('install', (event) => {
  event.waitUntil((async () => {
    const cache = await caches.open(SHELL_CACHE);
    // addAll e "all or nothing": un singur fisier lipsa ar rupe tot install-ul,
    // asa ca adaugam individual si doar avertizam pentru ce lipseste.
    await Promise.all(SHELL_ASSETS.map(async (url) => {
      try { await cache.add(new Request(url, { cache: 'reload' })); }
      catch (err) { console.warn('[SW] Nu am putut pre-cacha:', url, err); }
    }));
    await self.skipWaiting();
  })());
});

// ── Activate: curata versiunile vechi de cache ──────────────────────────────
self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    const names = await caches.keys();
    await Promise.all(
      names.filter((n) => n.startsWith('gdc-') && !n.endsWith(CACHE_VERSION))
           .map((n) => caches.delete(n))
    );
    await self.clients.claim();
  })());
});

// ── Helpers ─────────────────────────────────────────────────────────────────

/** Network-first: incearca reteaua, cade pe cache cand nu e conexiune. */
async function networkFirst(request, cacheName, fallbackUrl) {
  const cache = await caches.open(cacheName);
  try {
    const fresh = await fetch(request);
    if (fresh && fresh.ok) cache.put(request, fresh.clone());
    return fresh;
  } catch (err) {
    const cached = await cache.match(request);
    if (cached) return cached;
    if (fallbackUrl) {
      const fallback = await caches.match(fallbackUrl);
      if (fallback) return fallback;
    }
    throw err;
  }
}

/** Cache-first: raspunde din cache, altfel descarca si retine. */
async function cacheFirst(request, cacheName) {
  const cached = await caches.match(request);
  if (cached) return cached;
  const cache = await caches.open(cacheName);
  const fresh = await fetch(request);
  // Raspunsurile "opaque" (cross-origin, no-cors) au status 0 dar sunt valide.
  if (fresh && (fresh.ok || fresh.type === 'opaque')) cache.put(request, fresh.clone());
  return fresh;
}

// ── Fetch ───────────────────────────────────────────────────────────────────
self.addEventListener('fetch', (event) => {
  const { request } = event;

  // Doar GET. POST-urile (activari, formulare) trec direct la retea.
  if (request.method !== 'GET') return;

  const url = new URL(request.url);

  // Fonturi Google: imutabile, cache-first pentru randare instant offline.
  if (url.hostname === 'fonts.googleapis.com' || url.hostname === 'fonts.gstatic.com') {
    event.respondWith(cacheFirst(request, RUNTIME_CACHE));
    return;
  }

  // Restul cross-origin (GitHub Releases, YouTube) ramane in seama retelei.
  if (url.origin !== self.location.origin) return;

  // Navigari: network-first, cu pagina offline ca ultima solutie.
  if (request.mode === 'navigate') {
    event.respondWith(networkFirst(request, RUNTIME_CACHE, '/offline.html'));
    return;
  }

  // Date "vii": catalogul de produse/cursuri/evenimente si versiunile.
  if (/\/(catalog|update)\.json$/.test(url.pathname)) {
    event.respondWith(networkFirst(request, RUNTIME_CACHE));
    return;
  }

  // Restul (imagini, coperti, PDF, iconite, CSS/JS): cache-first.
  event.respondWith(
    cacheFirst(request, RUNTIME_CACHE).catch(() => caches.match('/offline.html'))
  );
});

// ── Notificari push (produs nou, LUT/DCTL, curs, workshop) ──────────────────
// Handler-ele sunt gata, dar push-ul NU functioneaza pana nu configurezi un
// backend (Firebase Cloud Messaging sau server web-push cu chei VAPID) si pana
// pagina nu apeleaza pushManager.subscribe(). Vezi docs/ANDROID.md.
self.addEventListener('push', (event) => {
  let data = { title: 'GDC', body: 'Ai o noutate in catalog.', url: '/' };
  try { if (event.data) data = { ...data, ...event.data.json() }; }
  catch (err) { if (event.data) data.body = event.data.text(); }

  event.waitUntil(self.registration.showNotification(data.title, {
    body: data.body,
    icon: '/icons/icon-192.png',
    badge: '/icons/icon-192.png',
    data: { url: data.url || '/' },
    tag: data.tag || 'gdc-news',   // notificarile cu acelasi tag se inlocuiesc
  }));
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const target = (event.notification.data && event.notification.data.url) || '/';
  event.waitUntil((async () => {
    const all = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
    // Daca aplicatia e deja deschisa, o focusam in loc sa deschidem alt tab.
    for (const client of all) {
      if (new URL(client.url).origin === self.location.origin && 'focus' in client) {
        return client.focus();
      }
    }
    return self.clients.openWindow(target);
  })());
});
