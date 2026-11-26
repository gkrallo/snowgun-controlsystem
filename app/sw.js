/* Service worker för Snökoll.
   Den finns för att appen ska gå att installera och starta fort — inte för
   att visa driftdata utan nät. Mätvärdena kommer alltid direkt från Firebase
   och sparas aldrig här: gammal data får inte kunna se ny ut. */

const VERSION = "snokoll-v4";
const SHELL = [
  "./",
  "./index.html",
  "./manifest.json",
  "./kanon-192.png",
  "./kanon-512.png",
  "./kanon-apple.png"
];

// Biblioteken (Chart.js, Leaflet, Firebase) ligger på adresser med
// versionsnummer i sig och ändras aldrig, så de kan sparas första gången.
const LIBS = ["cdnjs.cloudflare.com", "www.gstatic.com"];

self.addEventListener("install", e => {
  e.waitUntil(
    caches.open(VERSION)
      .then(c => Promise.allSettled(SHELL.map(u => c.add(u))))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener("activate", e => {
  e.waitUntil(
    caches.keys()
      .then(keys => Promise.all(keys.filter(k => k !== VERSION).map(k => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener("fetch", e => {
  const req = e.request;
  if (req.method !== "GET") return;
  const url = new URL(req.url);

  if (url.origin !== location.origin) {
    // Allt annat utanför appen (Firebase, Googles inloggning, kartrutor) går
    // rakt mot nätet utan att den här filen lägger sig i.
    if (!LIBS.includes(url.hostname)) return;
    e.respondWith(
      caches.match(req).then(hit => hit || fetch(req).then(res => {
        // Bara svar som säkert gick bra sparas. Chart.js och Leaflet hämtas med
        // vanliga script-taggar, och då går det inte att se härifrån om svaret
        // var en felsida - sparades den skulle graferna vara trasiga tills
        // VERSION höjs. De hämtas därför från nätet varje gång; mätvärdena
        // kräver ändå nät.
        if (res && res.ok) { const copy = res.clone(); caches.open(VERSION).then(c => c.put(req, copy)); }
        return res;
      }))
    );
    return;
  }

  // Firebase har egna sidor under /__/ på samma adress, bland annat den som
  // tar emot svaret från Googles inloggning. Rörs de går inloggningen sönder.
  if (url.pathname.startsWith("/__/")) return;

  // Själva sidan: nätet först, så att en ny version kommer fram direkt. Den
  // sparade kopian används bara när nätet saknas.
  if (req.mode === "navigate") {
    e.respondWith(
      fetch(req, { cache: "no-cache" })
        .then(res => {
          // Bara ett giltigt svar får bli den sparade startsidan — annars kan
          // en felsida fastna som appens första sida.
          if (res && res.ok) { const copy = res.clone(); caches.open(VERSION).then(c => c.put("./index.html", copy)); }
          return res;
        })
        .catch(() => caches.match("./index.html"))
    );
    return;
  }

  // Ikoner och manifest: sparad kopia om den finns, annars nätet.
  e.respondWith(
    caches.match(req).then(hit => hit || fetch(req).then(res => {
      if (res && res.ok) { const copy = res.clone(); caches.open(VERSION).then(c => c.put(req, copy)); }
      return res;
    }))
  );
});

/* Pushlarm (functions/index.js). Molnet skickar bara data, och notisen visas
   här: då kan en notis med samma tagg bytas ut ("Kanon 5 kör igen" ersätter
   "Kanon 5 står i fel") i stället för att de blir fler. En push MÅSTE visa
   en notis — iPhone stänger av notiserna för en app som låter bli. */
self.addEventListener("push", e => {
  let d = {};
  try { const j = e.data ? e.data.json() : {}; d = j.data || j || {}; } catch (x) { d = { text: e.data ? e.data.text() : "" }; }
  const tyst = d.tyst === "1";
  e.waitUntil(self.registration.showNotification(d.titel || "Snökoll", {
    body: d.text || "",
    tag: d.tag || "snokoll",
    // Ett nytt larm med samma tagg ska höras igen; en tyst uppdatering inte.
    renotify: !tyst && !!d.tag,
    silent: tyst,
    // Ett larm ligger kvar tills någon tittat på det.
    requireInteraction: !tyst,
    icon: "./kanon-192.png",
    badge: "./kanon-192.png",
    // Alltid appens egen adress, inte den molnet skickar: appen nås både på
    // snow.pettersson.app och snoprognos.firebaseapp.com.
    data: { url: "./#larm" }
  }));
});

// Trycket på notisen: till en öppen Snökoll om det finns en, annars öppnas
// appen på larmsidan.
self.addEventListener("notificationclick", e => {
  e.notification.close();
  const url = (e.notification.data && e.notification.data.url) || "./#larm";
  e.waitUntil(self.clients.matchAll({ type: "window", includeUncontrolled: true }).then(list => {
    for (const c of list) {
      if (new URL(c.url).origin === location.origin && "focus" in c) {
        c.postMessage({ vy: "alarms" });
        return c.focus();
      }
    }
    return self.clients.openWindow(url);
  }));
});
