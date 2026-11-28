/* Laddar appens kod (det första skriptet i app/index.html) i Node, med en
   låtsaswebbläsare som är precis så stor att koden går att köra. Då går
   vyerna att prova utan inloggning och utan webbläsare: mata in data med
   applyLive(...) och läs HTML:en som vyn ger.

   Det här provar logiken och texten vyerna skriver ut, inte hur det ser ut
   och inte Firebase-delen (det andra skriptet, type="module"). */
import fs from 'node:fs';
import vm from 'node:vm';

const KALLA = fs.readFileSync(new URL('../app/index.html', import.meta.url), 'utf8');
export const appHtml = KALLA;
const m = /<script>\r?\n([\s\S]*?)<\/script>/.exec(KALLA);
if (!m) throw new Error('Hittar inte appens skript i app/index.html');
export const appKod = m[1];

function element() {
  const cls = new Set();
  return {
    innerHTML: '', textContent: '', value: '', style: {}, offsetHeight: 0, offsetWidth: 0,
    classList: {
      add: c => cls.add(c), remove: c => cls.delete(c), contains: c => cls.has(c),
      toggle: (c, f) => { const on = f === undefined ? !cls.has(c) : !!f; if (on) cls.add(c); else cls.delete(c); return on; }
    },
    set outerHTML(v) { this.innerHTML = v; },
    scrollIntoView() { }, remove() { }, appendChild() { }, addEventListener() { }, click() { },
    getContext: () => null, querySelector: () => null, getBoundingClientRect: () => ({ top: 0 })
  };
}

/* search: adressens frågedel, till exempel '?demo'.
   lagrat: det som ligger i telefonens localStorage när appen startar.
   nu:     en funktion som ger klockan (ms). Utan den går den riktiga. */
export function laddaApp({ search = '', lagrat = {}, nu = null } = {}) {
  const els = { app: element(), login: element(), main: element(), nav: element(), botnav: element(), flakes: element() };
  els.app.classList.add('hidden');
  const lager = new Map(Object.entries(lagrat));
  const fel = [], intervall = [];
  // Klockan går att ställa: Date.now() och new Date() utan argument följer nu().
  const Klocka = nu ? class extends Date {
    constructor(...a) { if (a.length) super(...a); else super(nu()); }
    static now() { return nu(); }
  } : Date;
  const ctx = {
    console: { log() { }, warn() { }, info() { }, error: (...a) => fel.push(a.map(x => x && x.stack || String(x)).join(' ')) },
    Date: Klocka,
    location: { search, hash: '', protocol: 'http:', hostname: 'localhost', reload() { } },
    navigator: { userAgent: 'prov' },
    localStorage: {
      getItem: k => lager.has(k) ? lager.get(k) : null,
      setItem: (k, v) => { lager.set(k, String(v)); },
      removeItem: k => { lager.delete(k); }
    },
    document: {
      hidden: false, activeElement: null, body: element(),
      // Bara de fasta delarna av sidan finns. Det vyerna själva ritar (grafer,
      // kartan, enskilda fält) finns inte, precis som innan vyn ritats.
      getElementById: id => els[id] || null,
      createElement: () => element(), addEventListener() { }, removeEventListener() { }
    },
    setInterval: (f, ms) => { intervall.push({ f, ms }); return intervall.length; },
    clearInterval() { },
    setTimeout: () => 0, clearTimeout() { },
    fetch: () => Promise.reject(new Error('inget nät i provet')),
    URL, URLSearchParams, Blob, innerWidth: 400, innerHeight: 800, scrollTo() { },
    __fel: fel
  };
  ctx.window = ctx;
  vm.createContext(ctx);
  vm.runInContext(appKod, ctx, { filename: 'app/index.html (skriptet)' });
  const kor = kod => vm.runInContext(kod, ctx);
  return {
    ctx, kor, fel, intervall, lager,
    // Ett värde ur appen som vanliga listor och objekt, så att det går att jämföra här.
    varde: kod => JSON.parse(JSON.stringify(kor(kod))),
    // Vyn som den står i sidan just nu.
    main: () => els.main.innerHTML,
    // Öppnar appen som inloggningen gör, och går till en vy.
    visa(vy) { kor('showApp()'); if (vy) kor(`go(${JSON.stringify(vy)})`); return els.main.innerHTML; },
    // Kör timrarna som appen satt upp med setInterval, som om tiden gått.
    tick() { for (const t of intervall) t.f(); return els.main.innerHTML; }
  };
}

// Det webbläsaren gör med ett attributvärde innan koden i det tolkas.
export const avkoda = s => s.replace(/&(amp|lt|gt|quot|#39);/g, (_, n) => ({ amp: '&', lt: '<', gt: '>', quot: '"', '#39': "'" }[n]));
// Alla onclick i en bit HTML, avkodade som webbläsaren ser dem.
export const onclick = html => [...html.matchAll(/onclick="([^"]*)"/g)].map(x => avkoda(x[1]));

/* Kör koden i en onclick som webbläsaren skulle göra, med de namngivna
   funktionerna utbytta mot sådana som bara antecknar anropet. Allt annat som
   koden försöker nå kastar fel — och antecknas som "intrang". */
export function korOnclick(kod, namn) {
  const anrop = [], intrang = [];
  const sand = { event: { stopPropagation() { } } };
  for (const n of namn) sand[n] = (...a) => { anrop.push([n, ...a]); };
  for (const n of ['alert', 'eval', 'fetch', 'Function', 'setTimeout', 'atob']) sand[n] = (...a) => { intrang.push([n, ...a]); };
  try { vm.runInNewContext(kod, sand); } catch (e) { intrang.push(['fel', String(e)]); }
  return { anrop, intrang };
}
