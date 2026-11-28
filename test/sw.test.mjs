/* Prov av service workern (app/sw.js) och av inställningarna runt appen
   (firebase.json, bibliotekens kontrollsummor). Körs från repots rot:

     node --test test/sw.test.mjs */
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

const rot = new URL('../', import.meta.url);
const las = namn => fs.readFileSync(new URL(namn, rot), 'utf8');
const BAS = 'https://snow.pettersson.app';

// Service workern med låtsad webbläsare: sparat = det som ligger i cachen.
function laddaSw() {
  const lyssnare = {}, sparat = new Map(), oppnat = [];
  const cache = { put: (k, v) => { sparat.set(typeof k === 'string' ? k : k.url, v); return Promise.resolve(); }, add: () => Promise.resolve() };
  const ctx = {
    URL, Promise, console,
    location: { origin: BAS },
    caches: { open: () => Promise.resolve(cache), match: k => Promise.resolve(sparat.get(typeof k === 'string' ? k : k.url)), keys: () => Promise.resolve([]), delete: () => Promise.resolve() },
    fetch: req => Promise.resolve({ ok: true, url: req.url, clone() { return this; } }),
    self: {
      addEventListener: (n, f) => { lyssnare[n] = f; },
      skipWaiting() { }, registration: { showNotification: () => Promise.resolve() },
      clients: { claim() { }, matchAll: () => Promise.resolve(ctx.fonster), openWindow: u => { oppnat.push(u); return Promise.resolve(); } }
    },
    fonster: []
  };
  vm.createContext(ctx);
  vm.runInContext(las('app/sw.js'), ctx);
  return { ctx, lyssnare, sparat, oppnat };
}
// En sidladdning (navigering) till en adress. Svarar om service workern tog hand om den.
async function navigera(sw, path) {
  let svar = null;
  sw.lyssnare.fetch({ request: { method: 'GET', mode: 'navigate', url: BAS + path }, respondWith: p => { svar = p; } });
  if (svar) await svar;
  await new Promise(r => setImmediate(r));
  return !!svar;
}

test('sw: bara Snökoll själv sparas som startsida', async () => {
  const sw = laddaSw();
  assert.equal(await navigera(sw, '/'), true);
  assert.deepEqual([...sw.sparat.keys()], ['./index.html']);
  await navigera(sw, '/index.html');
  await navigera(sw, '/#larm');
  assert.deepEqual([...sw.sparat.keys()], ['./index.html']);
  assert.equal(sw.sparat.get('./index.html').url, BAS + '/#larm');
});

test('sw: en fil som öppnas direkt i webbläsaren blir inte appens startsida', async () => {
  const sw = laddaSw();
  await navigera(sw, '/');
  const start = sw.sparat.get('./index.html');
  for (const p of ['/manifest.json', '/kanon-192.png', '/sw.js', '/nagot/annat']) {
    assert.equal(await navigera(sw, p), false, p + ' ska gå rakt mot nätet');
  }
  assert.equal(sw.sparat.get('./index.html'), start, 'startsidan är orörd');
  assert.deepEqual([...sw.sparat.keys()], ['./index.html']);
});

test('sw: andra sidor sparas under sitt eget namn', async () => {
  const sw = laddaSw();
  await navigera(sw, '/'); await navigera(sw, '/forslag.html');
  assert.deepEqual([...sw.sparat.keys()].sort(), ['./forslag.html', './index.html']);
});

test('sw: ett tryck på en larmnotis går till Snökoll, inte till en annan sida på samma adress', async () => {
  const klick = async fonster => {
    const sw = laddaSw(), fokus = [], bud = [];
    sw.ctx.fonster = fonster.map(url => ({ url, focus() { fokus.push(url); return Promise.resolve(); }, postMessage: m => bud.push([url, m]) }));
    let klart; sw.lyssnare.notificationclick({ notification: { close() { }, data: { url: './#larm' } }, waitUntil: p => { klart = p; } });
    await klart;
    return { fokus, bud, oppnat: sw.oppnat };
  };
  // Bara en förslagssida är öppen: appen öppnas på larmsidan.
  let r = await klick([BAS + '/pist.html']);
  assert.deepEqual(r.fokus, []);
  assert.deepEqual(r.oppnat, ['./#larm']);
  // Förslagssidan och appen är öppna: appen får fokus och går till larmen.
  r = await klick([BAS + '/forslag.html', BAS + '/']);
  assert.deepEqual(r.fokus, [BAS + '/']);
  assert.deepEqual(JSON.parse(JSON.stringify(r.bud)), [[BAS + '/', { vy: 'alarms' }]]);
  assert.deepEqual(r.oppnat, []);
  // En sida på en annan adress räknas inte.
  r = await klick(['https://exempel.se/']);
  assert.deepEqual(r.oppnat, ['./#larm']);
});

test('S4: sidorna får säkerhetshuvuden, och startsidan sparas inte i webbläsaren', () => {
  const H = JSON.parse(las('firebase.json')).hosting.headers;
  const for_ = source => Object.fromEntries(H.filter(h => h.source === source).flatMap(h => h.headers.map(x => [x.key, x.value])));
  assert.equal(for_('**')['X-Content-Type-Options'], 'nosniff');
  assert.equal(for_('**')['Referrer-Policy'], 'strict-origin-when-cross-origin');
  for (const s of ['/', '**/*.html']) {
    // SAMEORIGIN, inte DENY: inloggningen använder en ram på samma adress.
    assert.equal(for_(s)['X-Frame-Options'], 'SAMEORIGIN', s);
    // Annars startar den installerade appen på gammal kod (CLAUDE.md, 26 november).
    assert.equal(for_(s)['Cache-Control'], 'no-cache', s);
  }
  // Firebases egna sidor för inloggningen (/__/auth/…) får inte träffas av ramspärren.
  assert.ok(!H.some(h => h.source === '**' && h.headers.some(x => x.key === 'X-Frame-Options')));
});

test('S4: bibliotek från CDN har kontrollsumma', () => {
  const html = las('app/index.html');
  const taggar = [...html.matchAll(/<(?:script|link)\b[^>]*\b(?:src|href)="https:\/\/cdnjs\.cloudflare\.com[^"]*"[^>]*>/g)].map(m => m[0]);
  assert.equal(taggar.length, 3);
  for (const t of taggar) {
    assert.match(t, /integrity="sha512-[A-Za-z0-9+/]{86}=="/, t);
    assert.match(t, /crossorigin="anonymous"/, t);
    assert.match(t, /\/\d+\.\d+\.\d+\//, 'versionen är låst: ' + t);
  }
});

test('reglerna är giltig JSON och stängda i roten', () => {
  const r = JSON.parse(las('firebase/database.rules.json')).rules;
  assert.equal(r['.read'], false);
  assert.equal(r['.write'], false);
});

/* ---------- S3: förslagen ligger inte på den skarpa adressen ---------- */

test('S3: under app/ ligger bara Snökoll', () => {
  const filer = fs.readdirSync(new URL('app/', rot)).sort();
  assert.deepEqual(filer, ['index.html', 'kanon-192.png', 'kanon-512.png', 'kanon-apple.png', 'kanon-maskable-512.png', 'manifest.json', 'sw.js']);
  assert.equal(JSON.parse(las('firebase.json')).hosting.public, 'app');
  assert.equal(JSON.parse(las('firebase.forslag.json')).hosting.public, 'forslag');
});

test('S3: förslagen går inte att förväxla med Snökoll', () => {
  for (const m of ['forslag/pist-manifest.json', 'forslag/pist-mobil-manifest.json']) {
    const j = JSON.parse(las(m));
    assert.doesNotMatch(j.name + j.short_name, /Snökoll/, m);
    assert.match(j.name, /prototyp, påhittad data/, m);
    for (const i of j.icons) assert.ok(fs.existsSync(new URL('forslag/' + i.src.replace('./', ''), rot)), i.src);
  }
  for (const sida of ['pist.html', 'pist-mobil.html', 'planering.html', 'forslag.html']) {
    const html = las('forslag/' + sida);
    assert.doesNotMatch(html, /serviceWorker\.register/, sida);
    for (const l of html.matchAll(/href="\.\/([\w-]+\.(?:html|json|png))"/g)) assert.ok(fs.existsSync(new URL('forslag/' + l[1], rot)), sida + ' länkar till ' + l[1]);
  }
});

test('S3: märket "påhittad data" göms inte på smala skärmar', () => {
  const html = las('forslag/pist.html');
  assert.match(html, /id="provband">Prototyp · påhittad data</);
  assert.doesNotMatch(html, /#provband\{display:none\}/);
});

test('S3: förslagens sw.js tar bara bort den gamla service workern', () => {
  const kod = las('forslag/sw.js');
  assert.match(kod, /registration\.unregister\(\)/);
  assert.doesNotMatch(kod, /addEventListener\("(fetch|push)"/);
});
