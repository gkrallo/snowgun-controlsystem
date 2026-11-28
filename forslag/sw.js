/* Förslagssidorna låg förut i samma mapp som Snökoll och delade dess
   service worker. Den som öppnat förhandslänken då har den gamla kvar. Den
   här tar bort den och allt den sparat, och gör sedan ingenting. */
self.addEventListener("install", () => self.skipWaiting());
self.addEventListener("activate", e => e.waitUntil(
  caches.keys()
    .then(keys => Promise.all(keys.map(k => caches.delete(k))))
    .then(() => self.registration.unregister())
));
