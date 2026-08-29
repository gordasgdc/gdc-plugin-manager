/* =============================================================================
   DataMover — service worker DEZACTIVAT (kill switch)
   -----------------------------------------------------------------------------
   PWA-ul separat pentru DataMover a fost retras: aplicatia companion acopera
   tot domeniul gordas.dev si e servita din repo-ul gdc-plugin-manager.

   Acest fisier NU mai face cache. Rolul lui e sa curete instalarile ramase la
   utilizatorii care au vizitat pagina cat timp PWA-ul a fost publicat: se
   dezinregistreaza singur si sterge cache-urile vechi.

   NU sterge fisierul inca. Daca dispare, browserele care au deja SW-ul
   inregistrat il pastreaza pana la urmatoarea verificare esuata. Poate fi sters
   dupa ~30 de zile de la publicare (adica dupa 2026-09-22).
============================================================================= */
self.addEventListener('install', () => self.skipWaiting());

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    const names = await caches.keys();
    await Promise.all(names.filter((n) => n.startsWith('datamover-')).map((n) => caches.delete(n)));
    await self.registration.unregister();
    // Reincarcam taburile deschise ca sa iasa de sub controlul acestui SW.
    const clients = await self.clients.matchAll({ type: 'window' });
    for (const client of clients) client.navigate(client.url);
  })());
});
