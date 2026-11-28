/* Prov av appen (app/index.html) utan webbläsare. Körs från repots rot:

     node --test test/app.test.mjs

   Se test/app-ram.mjs för hur appen laddas. */
import test from 'node:test';
import assert from 'node:assert/strict';
import { laddaApp, appKod, onclick, korOnclick } from './app-ram.mjs';

const NU = Date.now();
// Styrsystemets klocka: lokal tid utan zon, som bryggan skickar den.
const lok = ms => { const d = new Date(ms), p = n => String(n).padStart(2, '0'); return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}T${p(d.getHours())}:${p(d.getMinutes())}:${p(d.getSeconds())}`; };
// Ett nuläge som bryggan skriver det, med en kanon som kör vid brunn 7.
export function live(nu = NU, extra = {}) {
  return Object.assign({
    meta: { ts: nu - 20000, gssTid: lok(nu - 20000), sqlOk: true },
    enheter: {
      'SGC400-3': { typ: 'SUFAG PEAK', senastHord: lok(nu - 30000), t: -5.1, rh: 80, tw: -6.2, flode: 8.3, flodeTeori: 9, tryck: 21, tryckBor: 22, brunn: 7, k415: 6, bitar: '453:0,1,11' }
    },
    pump: { dep11: { tryckUt: 1.2 }, dep12: { tryckIn: 1.1, tryckUt: 24.5, k125: 20, vattenTemp: 1.4 } },
    vader: { t: -4, rh: 85, tw: -5 },
    larm: []
  }, extra);
}

/* ---------- S2: data i onclick ---------- */

const ELAKA = ["x');alert(1);('", "a'b", 'a"b', 'a\\', "\\');alert(1);//", '</script><script>alert(1)</script>', "o'brien@example,com", '&#39;);alert(1);(&#39;', 'rad\u2028bryt'];

test('S2: jsArg ger alltid tillbaka exakt samma värde och kör ingenting', () => {
  const app = laddaApp();
  for (const s of ELAKA) {
    const html = `<a onclick="f(${app.kor('jsArg')(s)})">`;
    const [kod] = onclick(html);
    assert.ok(kod, 'attributet gick sönder för ' + s);
    const r = korOnclick(kod, ['f']);
    assert.deepEqual(r.intrang, [], 'kod kördes för ' + s);
    assert.deepEqual(r.anrop, [['f', s]], 'fel värde kom fram för ' + s);
  }
});

test('S2: det gamla sättet, esc() inom citattecken, går att bryta sig ur', () => {
  // Visar att provet ovan faktiskt hittar felet: så här såg raden ut förut.
  const app = laddaApp();
  const [kod] = onclick(`<tr onclick="mtRedigera('${app.kor('esc')(ELAKA[0])}')">`);
  const r = korOnclick(kod, ['mtRedigera']);
  assert.deepEqual(r.intrang, [['alert', 1]]);
});

test('S2: ingen onclick i appen sätter in data med esc() inom citattecken', () => {
  const kvar = appKod.split('\n').map((rad, i) => [i + 1, rad]).filter(([, rad]) => /on\w+="[^"]*'\$\{esc\(/.test(rad));
  assert.deepEqual(kvar.map(([n]) => n), [], 'använd jsArg på de här raderna i skriptet');
});

test('S2: dammloggen visar inte rader med otillåten nyckel, och de räknas inte', () => {
  const app = laddaApp();
  app.ctx.dammMe = () => ({ uid: 'uid-admin', namn: 'Admin' });
  app.kor('setAdmin(true,"admin@example,com")');
  const rad = (m3, ts) => ({ ts, m3, typ: 'avl', uid: 'uid-annan', namn: 'Annan' });
  app.kor('applyDamm')({
    avlas: { '-Obra_1': rad(100, NU - 7200e3), [ELAKA[0]]: rad(999999, NU - 3600e3), '-Obra_2': rad(110, NU - 1800e3) },
    kalib: { [ELAKA[0]]: { ts: NU - 3600e3, cm: 5, punkt: 'SN', uid: 'uid-annan', namn: 'Annan' } }
  });
  assert.deepEqual(app.varde('avlasList().map(a=>a.id)'), ['-Obra_1', '-Obra_2']);
  assert.equal(app.kor('kalibList().length'), 0);
  for (const flik of ['avl', 'pass', 'mb']) {
    app.kor(`loggFlik=${JSON.stringify(flik)}`);
    const html = app.visa('dam');
    assert.doesNotMatch(html, /alert/, 'fliken ' + flik);
    for (const kod of onclick(html)) assert.deepEqual(korOnclick(kod, ['mtRedigera', 'mbRedigera', 'go', 'render', 'damCalib', 'mtSpara', 'mtTaBort', 'mtAvbryt', 'loggExcel', 'kalibTaBort', 'mbAvbryt', 'fragaSvar']).intrang.filter(x => x[0] !== 'fel'), []);
  }
  app.kor("loggFlik='avl'");
  const koder = onclick(app.visa('dam')).filter(k => k.startsWith('mtRedigera'));
  assert.deepEqual(koder.map(k => korOnclick(k, ['mtRedigera']).anrop[0]), [['mtRedigera', '-Obra_2'], ['mtRedigera', '-Obra_1']]);
  assert.deepEqual(app.fel, []);
});

test('S2: ett id-fält inne i raden kan inte ta nyckelns plats', () => {
  const app = laddaApp();
  app.kor('applyDamm')({ avlas: { '-Obra_1': { ts: NU - 1000, m3: 5, typ: 'avl', uid: 'u', namn: 'n', id: ELAKA[0] } } });
  assert.deepEqual(app.varde('avlasList().map(a=>a.id)'), ['-Obra_1']);
});

test('S2: medlemslistan tål en adress med apostrof', () => {
  const app = laddaApp();
  app.kor('setAdmin(true,"admin@example,com")');
  app.kor('applyMembers')({ 'admin@example,com': { role: 'admin', name: 'Admin' }, "o'brien@example,com": { role: 'viewer', name: "O'Brien" } });
  const koder = onclick(app.visa('members')).filter(k => k.startsWith('memAsk'));
  assert.equal(koder.length, 2);
  for (const k of koder) {
    const r = korOnclick(k, ['memAsk']);
    assert.deepEqual(r.intrang, []);
    assert.equal(r.anrop[0][2], "o'brien@example,com");
  }
  assert.deepEqual(app.fel, []);
});

test('S2: enhetskort, larm och historik går att trycka på och kör inget annat', () => {
  const app = laddaApp();
  app.kor('applyLive')(live(NU, { larm: [{ id: "SGC400_1_3');alert(1);('", maskin: 'SGC400', namn: '3', text: 'Fault', sedan: '2026-11-28 10:00' }] }));
  for (const vy of ['overview', 'cannons', 'water', 'alarms']) {
    const html = app.visa(vy);
    for (const kod of onclick(html)) {
      const r = korOnclick(kod, ['openUnit', 'openHist', 'ackOne', 'ackAll', 'go', 'setHistRange', 'notisKlick']);
      assert.deepEqual(r.intrang, [], vy + ': ' + kod);
    }
  }
  const ack = onclick(app.visa('alarms')).filter(k => k.startsWith('ackOne'));
  assert.deepEqual(korOnclick(ack[0], ['ackOne']).anrop, [['ackOne', "SGC400_1_3');alert(1);('"]]);
  assert.deepEqual(app.fel, []);
});

/* ---------- K3: gamla värden får aldrig se live ut ---------- */

// En app med ställbar klocka. fram(min) flyttar klockan framåt.
function medKlocka(start = Date.UTC(2026, 10, 28, 11, 0, 0), val = {}) {
  let t = start;
  const app = laddaApp(Object.assign({ nu: () => t }, val));
  return Object.assign(app, { nu: () => t, fram: min => { t += min * 60000; } });
}
// Svensk tid utan zon, som styrsystemet stämplar.
const sv = ms => new Date(ms).toLocaleString('sv-SE', { timeZone: 'Europe/Stockholm' }).replace(' ', 'T');
function liveVid(nu, meta = {}, enhet = {}) {
  const l = live(nu);
  l.meta = Object.assign({ ts: nu - 20000, gssTid: sv(nu - 25000), sqlOk: true }, meta);
  Object.assign(l.enheter['SGC400-3'], { senastHord: sv(nu - 30000) }, enhet);
  return l;
}
const korChip = /class="chip s-run"[^>]*><span class="d"><\/span>Kör</;
const gammaltKort = /class="card unit old"/;
const utanNat = fel => fel.filter(f => !/inget nät i provet/.test(f));

test('K3: färska värden visas som live', () => {
  const app = medKlocka();
  app.kor('applyLive')(liveVid(app.nu()));
  const html = app.visa('overview');
  assert.equal(app.kor('dataLage()'), 'ok');
  assert.match(html, /class="live" id="liveChip"/);
  assert.match(html, korChip);
  assert.doesNotMatch(html, gammaltKort);
  assert.match(html, /1 kör just nu/);
  assert.deepEqual(utanNat(app.fel), []);
});

test('K3: bryggan tystnar — vyn ritas om av timern och "Kör" försvinner', () => {
  const app = medKlocka();
  app.kor('applyLive')(liveVid(app.nu()));
  app.visa('overview');
  app.fram(5);
  // Ingen ny data har kommit. Utan timern står den gamla vyn kvar.
  assert.match(app.main(), korChip, 'vyn är inte omritad än');
  assert.ok(app.intervall.some(i => i.ms === 30000), 'appen har en timer på 30 s');
  const html = app.tick();
  assert.equal(app.kor('dataLage()'), 'brygga');
  assert.doesNotMatch(html, korChip);
  assert.match(html, gammaltKort);
  assert.match(html, /class="live stale" id="liveChip"[^>]*>⚠ Gammal data/);
  assert.match(html, /för 5 min sedan/);
  assert.doesNotMatch(html, /kör just nu/);
  assert.deepEqual(utanNat(app.fel), []);
});

test('K3: åldern på ett gammalt kort räknas upp av timern', () => {
  const app = medKlocka();
  app.kor('applyLive')(liveVid(app.nu()));
  app.visa('overview');
  app.fram(10); assert.match(app.tick(), /för 10 min sedan/);
  app.fram(25); assert.match(app.tick(), /för 35 min sedan/);
});

test('K3: styrsystemet står (bryggan går) — korten blir gamla och larmlistan säger det', () => {
  for (const medAlder of [true, false]) {
    const app = medKlocka(), nu = app.nu();
    // Bryggan hördes nyss, men styrsystemets senaste värde är 400 s gammalt
    // enligt bryggan (version 13), eller 20 minuter enligt klockorna (version 12).
    const l = medAlder ? liveVid(nu, { gssAlder: 400 })
      : liveVid(nu, { gssTid: sv(nu - 20 * 60000) }, { senastHord: sv(nu - 20 * 60000 - 5000) });
    app.kor('applyLive')(l);
    const html = app.visa('overview');
    assert.equal(app.kor('dataLage()'), 'gss', 'gssAlder ' + medAlder);
    assert.doesNotMatch(html, korChip);
    assert.match(html, gammaltKort);
    assert.match(html, /⚠ Styrsystemet står/);
    assert.doesNotMatch(html, /class="live" id="liveChip"/);
    assert.match(app.visa('alarms'), /Styrsystemet skriver inga nya värden/);
    assert.deepEqual(utanNat(app.fel), []);
  }
});

test('K3: gränsen för styrsystemets ålder', () => {
  const lage = meta => { const app = medKlocka(); app.kor('applyLive')(liveVid(app.nu(), typeof meta === 'function' ? meta(app.nu()) : meta)); return app.kor('dataLage()'); };
  // Med bryggans egen ålder (version 13): fem minuter.
  assert.equal(lage({ gssAlder: 20 }), 'ok');
  assert.equal(lage({ gssAlder: 290 }), 'ok');
  assert.equal(lage({ gssAlder: 310 }), 'gss');
  // Bryggans ålder går före klockorna: en styrdator vars klocka går en timme fel ger inget falskt besked.
  assert.equal(lage(nu => ({ gssAlder: 20, gssTid: sv(nu - 3600e3) })), 'ok');
  // Utan den (version 12): klockorna jämförs, och gränsen är tio minuter.
  assert.equal(lage(nu => ({ gssTid: sv(nu - 7 * 60000) })), 'ok');
  assert.equal(lage(nu => ({ gssTid: sv(nu - 11 * 60000) })), 'gss');
  // Ingen tid alls från styrsystemet: går inte att avgöra, och räknas inte som gammalt.
  assert.equal(lage({ gssTid: '' }), 'ok');
});

test('K3: styrsystemets tid jämförs som svensk tid, sommar och vinter', () => {
  const app = laddaApp();
  const naiv = app.kor('sthlmNaiv'), las = app.kor('naivMs');
  assert.equal(naiv(Date.UTC(2026, 10, 28, 11, 0, 0)), las('2026-11-28T12:00:00'));   // vintertid, +1
  assert.equal(naiv(Date.UTC(2026, 6, 1, 10, 0, 0)), las('2026-07-01T12:00:00'));     // sommartid, +2
  assert.equal(las('2026-11-28 12:00'), las('2026-11-28T12:00:00'));
  assert.equal(las('skräp'), null);
});

test('K3: bryggan når inte databasen — korten blir gamla, med tiden för de sista värdena', () => {
  const app = medKlocka(), nu = app.nu();
  app.kor('applyLive')(liveVid(nu, { sqlOk: false, gssTid: sv(nu - 40 * 60000), gssAlder: 20 }));
  const html = app.visa('overview');
  assert.equal(app.kor('dataLage()'), 'sql');
  assert.doesNotMatch(html, korChip);
  assert.match(html, gammaltKort);
  assert.match(html, /⚠ Databasen svarar inte/);
  // gssAlder står kvar från senaste lyckade läsningen och får inte användas.
  assert.ok(Math.abs(app.kor('dataTid()') - (nu - 40 * 60000)) < 2000);
  assert.match(html, /för 40 min sedan/);
});

test('K3: dammens uttag är okänt när värdena är gamla, inte "det senaste"', () => {
  const app = medKlocka(), nu = app.nu();
  app.kor('applyLive')(liveVid(nu));
  app.kor('applyVattenTimme')({ '2026112810': 12.5 });
  app.kor('applyDamm')({ kalib: { '-Okal1': { ts: nu - 5 * 3600e3, cm: 100, punkt: 'SN', uid: 'u', namn: 'Prov' } } });
  assert.equal(app.kor('damUttakM3h()'), +(20 * 3.552451 / 1.9634950).toFixed(1), 'färskt: rättat FT01');
  assert.match(app.visa('dam'), /Drifttid vid nuvarande uttag<\/h3><div class="val">≈ /);
  app.fram(6);
  const dam = app.tick();
  assert.equal(app.kor('damUttakM3h()'), null);
  assert.match(dam, /Drifttid vid nuvarande uttag<\/h3><div class="val">–</);
  assert.match(dam, /Uttaget just nu är inte känt/);
  assert.doesNotMatch(dam, /Sjunker ≈/);
  assert.match(app.visa('overview'), /Bryggan är tyst sedan [^<]*Uttaget efter det är inte med/);
  assert.match(app.visa('advisor'), /Inget förslag räknas på gamla värden/);
  assert.deepEqual(utanNat(app.fel), []);
});

const VYER = ['overview', 'water', 'dam', 'advisor', 'cannons', 'lances', 'alarms', 'forecast', 'map'];
test('K3: alla vyer går att rita i alla lägen utan fel', () => {
  for (const meta of [{}, { sqlOk: false }, { gssAlder: 900 }, null]) {
    const app = medKlocka(), nu = app.nu();
    if (meta) app.kor('applyLive')(liveVid(nu, meta));
    app.kor('applyDamm')({ kalib: { '-Okal1': { ts: nu - 3600e3, cm: 100, punkt: 'SN', uid: 'u', namn: 'Prov' } } });
    for (const vy of VYER) assert.doesNotMatch(app.visa(vy), /Kunde inte visa vyn|undefined|NaN/, vy + ' ' + JSON.stringify(meta));
    app.kor("openUnit('K5')");
    assert.doesNotMatch(app.main(), /Kunde inte visa vyn|undefined|NaN/, 'enhetsvyn ' + JSON.stringify(meta));
    app.fram(20); app.tick();
    assert.deepEqual(utanNat(app.fel), [], JSON.stringify(meta));
  }
});
