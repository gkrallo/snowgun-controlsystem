/* Service worker för Snökoll.
   Den finns för att appen ska gå att installera och starta fort — inte för
   att visa driftdata utan nät. Mätvärdena kommer alltid direkt från Firebase
   och sparas aldrig här: gammal data får inte kunna se ny ut. */

const VERSION = "snokoll-v3";
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
