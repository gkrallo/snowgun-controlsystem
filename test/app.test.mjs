/* Prov av appen (app/index.html) utan webbläsare. Körs från repots rot:

     node --test test/app.test.mjs

   Se test/app-ram.mjs för hur appen laddas. */
import test from 'node:test';
import assert from 'node:assert/strict';
import { laddaApp, appKod, appHtml, onclick, korOnclick } from './app-ram.mjs';

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

/* ---------- K4–K12 ---------- */

const vanta = () => new Promise(r => setImmediate(r));
const FT = 3.552451 / 1.9634950;

test('K4: översikten visar FT01 rättad, som alla andra ställen', () => {
  const app = medKlocka();
  app.kor('applyLive')(liveVid(app.nu()));          // FT01 visar 20 i styrsystemet
  const html = app.visa('overview');
  assert.match(html, /FT01 36,2 m³\/h/);
  assert.doesNotMatch(html, /FT01 20,0/);
  assert.equal(+(20 * FT).toFixed(1), 36.2);
});

test('K5: en kvittering glöms när larmet gått över, och larmet visas okvitterat när det kommer tillbaka', () => {
  const larm = id => ({ id, maskin: 'SGC300', namn: '0 1', text: 'fault : hose frozen', sedan: '20/11/2026 03:10:00' });
  const app = medKlocka(undefined, { lagrat: { snokollAck: JSON.stringify(['A1', 'B2']) } });
  const med = l => { const x = liveVid(app.nu()); x.larm = l; return x; };
  app.kor('applyLive')(med([larm('A1')]));
  assert.match(app.visa('alarms'), /Kvitterad/);
  assert.deepEqual(JSON.parse(app.lager.get('snokollAck')), ['A1'], 'B2 står inte längre och glöms');
  // Larmet går över ...
  app.fram(1); app.kor('applyLive')(med([]));
  assert.deepEqual(JSON.parse(app.lager.get('snokollAck')), []);
  // ... och kommer tillbaka två veckor senare.
  app.fram(14 * 24 * 60); app.kor('applyLive')(med([larm('A1')]));
  const html = app.visa('alarms');
  assert.doesNotMatch(html, /Kvitterad/);
  assert.match(html, /ackOne\(/);
  assert.equal(app.kor('activeAlarms().length'), 1);
});

test('K5: kvitteringarna rörs inte när bryggan inte når databasen', () => {
  const app = medKlocka(undefined, { lagrat: { snokollAck: JSON.stringify(['A1']) } });
  const l = liveVid(app.nu(), { sqlOk: false }); l.larm = [];
  app.kor('applyLive')(l);
  assert.deepEqual(JSON.parse(app.lager.get('snokollAck')), ['A1']);
});

test('K6: ?demo säger EXEMPELDATA, aldrig Live, och tar inte in riktig data', () => {
  const app = laddaApp({ search: '?demo' });
  for (const vy of VYER) {
    const html = app.visa(vy);
    assert.match(html, /EXEMPELDATA/, vy);
    assert.doesNotMatch(html, /Live ·/, vy);
  }
  assert.match(app.tick(), /EXEMPELDATA/);
  app.kor('applyDamm')({ avlas: { '-Oriktig': { ts: NU, m3: 73478, typ: 'avl', uid: 'u', namn: 'Riktig' } } });
  app.kor('applyVattenTimme')({ '2026112810': 12.5 });
  app.kor('applyMembers')({ 'riktig@example,com': { role: 'admin', name: 'Riktig' } });
  app.kor('setAdmin(true,"riktig@example,com")');
  assert.equal(app.kor('avlasList().length'), 0);
  assert.equal(app.kor('Object.keys(vattenTimme).length'), 0);
  assert.equal(app.kor('members'), null);
  assert.equal(app.kor('isAdmin'), false);
  assert.doesNotMatch(app.visa('members'), /Släpp in någon/);
  assert.deepEqual(utanNat(app.fel), []);
});

test('K7: utan sparad mätning visas ingen procent för dammen utanför Damm-koll', () => {
  const app = medKlocka(), nu = app.nu();
  app.kor('applyLive')(liveVid(nu));
  app.kor('applyVattenTimme')({ '2026112810': 12.5 });
  const utan = app.visa('overview');
  assert.match(utan, /Vattenmagasin<\/h3><div class="val">–<small> %/);
  assert.match(utan, /Ingen mätning med måttband är sparad än/);
  assert.match(app.visa('water'), /– % · beräknat/);
  app.kor('applyDamm')({ kalib: { '-Okal1': { ts: nu - 3600e3, cm: 100, punkt: 'SN', uid: 'u', namn: 'Prov' } } });
  assert.match(app.visa('overview'), /Vattenmagasin<\/h3><div class="val">\d+<small> %/);
  assert.match(app.visa('water'), /\d+ % · beräknat/);
});

test('K7: påfyllningens takt står likadant överallt', () => {
  const app = medKlocka();
  app.kor('applyLive')(liveVid(app.nu()));
  const html = app.visa('dam');
  assert.match(html, /213 m³\/dygn/);
  assert.doesNotMatch(html, /214/);
  assert.equal(app.kor('dam.fillRate'), app.kor('FYLL_M3D'));
});

test('K9: pumpvarningen räknas på rättat FT01 när pumparna går, inte på kanonernas summa', () => {
  const vatten = (k125, flode) => {
    const app = medKlocka(), l = liveVid(app.nu());
    l.pump.dep12.k125 = k125;
    l.enheter['SGC400-3'].flode = flode;
    l.enheter['SGC400-4'] = Object.assign({}, l.enheter['SGC400-3'], { brunn: 9 });
    app.kor('applyLive')(l);
    return app.visa('water');
  };
  // Kanonerna räknar 70 ihop, FT01 visar 32 = 57,9 rättat: under målet, ingen varning.
  const lugnt = vatten(32, 35);
  assert.match(lugnt, /<b>70,0<\/b>/);
  assert.doesNotMatch(lugnt, /pumparnas mål|Nära målet|nära målet/);
  // FT01 38,5 = 69,7 rättat: över målet 69.
  assert.match(vatten(38.5, 35), /Uttaget 69,7 m³\/h \(FT01\) är över pumparnas mål 69 m³\/h\./);
  // FT01 39 = 70,6: över taket också.
  assert.match(vatten(39, 35), /är över pumparnas mål 69 m³\/h och över taket 70\./);
  // Pumparna står enligt FT01, men kanonerna räknar 80: då gäller kanonerna × 83 %, 66,4.
  assert.match(vatten(0.1, 40), /Uttaget 66,4 m³\/h \(kanonerna × 83 %\) är nära målet 69 m³\/h\./);
});

test('K10: appen använder inte webbläsarens egna frågerutor', () => {
  // "confirm()" i en kommentar räknas inte: bara anrop med något i parentesen.
  const kvar = appKod.split('\n').map((rad, i) => [i + 1, rad]).filter(([, rad]) => /(^|[^.\w])(confirm|alert|prompt)\((?!\))/.test(rad));
  assert.deepEqual(kvar, []);
});

// En inloggad app där skrivningarna till /damm bara antecknas.
function medDamm(rader) {
  const app = medKlocka(), skrivet = [];
  app.ctx.dammMe = () => ({ uid: 'jag', namn: 'Jag' });
  app.ctx.dammWrite = (lista, id, data) => { skrivet.push([lista, id, data]); return Promise.resolve(); };
  app.kor('applyLive')(liveVid(app.nu()));
  app.kor('applyDamm')(rader(app.nu()));
  app.visa('dam');
  return Object.assign(app, { skrivet });
}

test('K10: ta bort en avläsning kräver två tryck', async () => {
  const app = medDamm(nu => ({ avlas: { '-Oa1': { ts: nu - 3600e3, m3: 100, typ: 'avl', uid: 'jag', namn: 'Jag' } } }));
  app.kor("mtRedigera('-Oa1')");
  assert.match(app.main(), />Ta bort<\/button>/);
  await app.kor('mtTaBort()');
  assert.deepEqual(app.skrivet, [], 'första trycket tar inte bort');
  assert.match(app.main(), /Ta bort avläsningen [^<]*100 m³\? Tryck en gång till/);
  assert.match(app.main(), /Tryck igen för att ta bort/);
  await app.kor('mtTaBort()');
  assert.deepEqual(app.skrivet, [['avlas', '-Oa1', null]]);
  assert.match(app.main(), /Borttagen\./);
  assert.deepEqual(utanNat(app.fel), []);
});

test('K10: ta bort en mätning med måttband kräver två tryck', async () => {
  const app = medDamm(nu => ({ kalib: { '-Ok1': { ts: nu - 3600e3, cm: 120, punkt: 'SN', uid: 'jag', namn: 'Jag' } } }));
  app.kor("mbRedigera('-Ok1')");
  await app.kor('kalibTaBort()');
  assert.deepEqual(app.skrivet, []);
  assert.match(app.main(), /Ta bort mätningen [^<]*120 cm\? Tryck en gång till/);
  await app.kor('kalibTaBort()');
  assert.deepEqual(app.skrivet, [['kalib', '-Ok1', null]]);
});

test('K10: en orimlig takt frågar först, och sparar på andra trycket med samma siffror', async () => {
  const app = medDamm(nu => ({ avlas: { '-Oa1': { ts: nu - 3600e3, m3: 100, typ: 'start', uid: 'jag', namn: 'Jag' } } }));
  app.kor("mtForm.m3='200'");                      // 100 m³ på en timme
  await app.kor("mtSpara('avl')");
  assert.deepEqual(app.skrivet, []);
  assert.match(app.main(), /Det blir 100,0 m³\/h [^<]*tryck en gång till på samma knapp/);
  // Ändras siffran frågas det igen.
  app.kor("mtForm.m3='190'");
  await app.kor("mtSpara('avl')");
  assert.deepEqual(app.skrivet, []);
  await app.kor("mtSpara('avl')");
  assert.equal(app.skrivet.length, 1);
  assert.equal(app.skrivet[0][2].m3, 190);
  // En rimlig takt sparas direkt.
  app.skrivet.length = 0;
  app.kor("mtForm.m3='109'");
  await app.kor("mtSpara('avl')");
  assert.equal(app.skrivet.length, 1);
});

test('K12: en vald vecka fylls på med det som kommit sedan den hämtades', async () => {
  const app = medKlocka(), hamtat = [];
  app.ctx.loadHist = h => { hamtat.push(h); return Promise.resolve({}); };
  app.kor('applyLive')(liveVid(app.nu()));
  app.visa('overview');
  app.kor('setHistRange(168)'); await vanta();
  assert.deepEqual(hamtat, [168]);
  app.fram(60); app.tick(); await vanta();
  assert.deepEqual(hamtat, [168], 'inget hämtas om i onödan');
  app.fram(6 * 60); app.tick(); await vanta();
  assert.deepEqual(hamtat, [168, 8], 'bara timmarna sedan hämtningen, inte hela veckan');
  app.fram(5); app.tick(); await vanta();
  assert.deepEqual(hamtat, [168, 8]);
  // Med 24 h vald hämtas aldrig något extra.
  app.kor('setHistRange(24)'); app.fram(48 * 60); app.tick(); await vanta();
  assert.deepEqual(hamtat, [168, 8]);
});

/* ---------- S7 och städlistan ---------- */

test('S7: ett namn som börjar med = blir text i Excel-filen, inte en formel', () => {
  const app = medKlocka(), nu = app.nu(), filer = [];
  app.ctx.Blob = class { constructor(delar) { filer.push(delar.join('')); } };
  app.ctx.URL = { createObjectURL: () => 'blob:prov', revokeObjectURL() { } };
  app.kor('applyLive')(liveVid(nu));
  app.kor('applyDamm')({
    avlas: { '-Oa1': { ts: nu - 7200e3, m3: 100, typ: 'start', uid: 'u', namn: '=HYPERLINK("http://exempel.se";"klicka")' },
             '-Oa2': { ts: nu - 3600e3, m3: 109, typ: 'stopp', uid: 'u', namn: 'Anna Andersson' } },
    kalib: { '-Ok1': { ts: nu - 3600e3, cm: 100, punkt: 'SN', uid: 'u', namn: '+46701234567' } }
  });
  app.kor("loggFlik='avl'"); app.kor('loggExcel()');
  app.kor("loggFlik='mb'"); app.kor('loggExcel()');
  assert.equal(filer.length, 2);
  const celler = filer.join('\r\n').split('\r\n').flatMap(rad => rad.split(';'));
  assert.ok(!celler.some(c => /^"?[=+@]/.test(c)), 'ingen cell börjar med = + eller @');
  assert.match(filer[0], /"'=HYPERLINK\(""http:\/\/exempel\.se"";""klicka""\)"/);
  assert.match(filer[0], /Anna Andersson/);
  assert.match(filer[1], /'\+46701234567/);
  // Tal ska fortfarande vara tal: inget citattecken framför en mätarställning.
  assert.match(filer[0], /;109,000;/);
});

test('städning: inga texter i appen pekar på gamla bryggversioner', () => {
  const app = medKlocka(), nu = app.nu();
  // Det äldsta bryggan kunde skicka: en enhet utan flöde, brunn, lampor och vatten.
  const l = liveVid(nu);
  l.enheter = { 'SGC400-3': { typ: 'S ACCESS 300', senastHord: sv(nu - 30000), t: -5, rh: 80, tw: -6 } };
  app.kor('applyLive')(l);
  const allt = VYER.map(v => app.visa(v)).join('\n') + (app.kor("openUnit('K5')"), app.main());
  assert.doesNotMatch(allt, /version \d+|bryggans version|bryggan \d+/i);
  assert.match(allt, /saknas i datan från bryggan/);
  assert.deepEqual(utanNat(app.fel), []);
});

test('städning: de råa bitarna visas bara för administratörer', () => {
  const app = medKlocka();
  app.kor('applyLive')(liveVid(app.nu()));
  app.visa('overview'); app.kor("openUnit('K5')");
  assert.doesNotMatch(app.main(), /Tända bitar just nu/);
  assert.match(app.main(), /Ringar och lampor/);
  app.kor('setAdmin(true,"admin@example,com")'); app.kor("openUnit('K5')");
  assert.match(app.main(), /Tända bitar just nu[^<]*<\/p>\s*<div[^>]*>453:0,1,11</);
});

test('städning: vattenrådets kolumn Nu visar enhetens flöde', () => {
  const app = medKlocka();
  app.kor('applyLive')(liveVid(app.nu()));
  const html = app.visa('advisor');
  assert.match(html, /class="adv-cur">8,3<small> m³\/h/);
  assert.doesNotMatch(html, /är tom/);
});

test('städning: kartans knapp går till Körfönster, och larmlistan står före inställningarna', () => {
  const app = medKlocka();
  app.kor('applyLive')(liveVid(app.nu(), {}, {}));
  assert.match(app.visa('map'), /onclick="go\('forecast'\)">Körfönster</);
  app.ctx.notisNyckel = 'x';
  const larm = app.visa('alarms');
  assert.ok(larm.indexOf('Inga aktiva larm') > 0 && larm.indexOf('Inga aktiva larm') < larm.indexOf('Larm till den här telefonen'));
});

test('filen har inga riktiga mätvärden i kommentarerna som granskningen pekade ut', () => {
  for (const bit of ['190 ± 15', '133 m³ räknat', '679 mot 683', '462–464', '0,44–0,48', '119–123', '5,1 m³/h', '35.21', '0,3–1,7'])
    assert.ok(!appHtml.includes(bit), 'står kvar: ' + bit);
  assert.doesNotMatch(appKod, /\bdamTape\b|\bUCOL_REAL\b/);
});

/* ---------- Kristians beslut 28 november ---------- */

test('K8: Vattenråd är märkt som skiss överallt där den nås', () => {
  const app = medKlocka();
  app.kor('applyLive')(liveVid(app.nu()));
  const rad = app.visa('advisor');
  assert.match(rad, /Vattenrådgivare — skiss/);
  assert.match(rad, /SKISS — ställ inte in anläggningen efter de här siffrorna än/);
  assert.match(app.visa('water'), /Vattenråd \(skiss\)<\/button>/);
  assert.match(app.visa('water'), /Öppna vattenrådgivaren \(skiss\)/);
  assert.match(app.kor("document.getElementById('nav').innerHTML"), /Vattenråd \(skiss\)/);
});

test('K7: läckage och reservtakt är fasta värden, inte fält i telefonen', () => {
  const app = medKlocka();
  app.kor('applyLive')(liveVid(app.nu()));
  const dam = app.visa('dam');
  assert.doesNotMatch(dam, /id="dam_rate"|id="dam_leak"|damNum/);
  assert.match(dam, /Räknat med 2 m³\/dygn i läckage och avdunstning, och med 213 m³\/dygn i påfyllning/);
  assert.match(dam, /Värdena är lika för alla/);
  assert.equal(app.kor('dam.leak'), 2);
  assert.equal(app.kor('dam.floorH'), 0.5);
  assert.equal(app.kor('typeof damNum'), 'undefined');
});

test('pushlarmet "Styrsystemet står" ersätter appens egen rad', () => {
  const app = medKlocka(), nu = app.nu();
  app.kor('applyLive')(liveVid(nu, { gssAlder: 900 }));
  assert.match(app.visa('alarms'), /Styrsystemet skriver inga nya värden/);
  app.kor('applyLarmlage')({ gss: { typ: 'gss', titel: 'Styrsystemet står', text: 'Bryggan går, men styrsystemet har inte skrivit nya värden sedan 11:45.', sedan: nu - 60000 } });
  const larm = app.visa('alarms');
  assert.match(larm, /Styrsystemet står/);
  assert.doesNotMatch(larm, /Styrsystemet skriver inga nya värden/);
  assert.match(larm, /Jag tar det/);
  // Nästa hjärtslag lägger inte tillbaka appens egen rad.
  app.kor('applyLive')(liveVid(nu, { gssAlder: 960 }));
  assert.doesNotMatch(app.visa('alarms'), /Styrsystemet skriver inga nya värden/);
  assert.match(app.visa('alarms'), /styrsystemet som slutar skriva nya värden/);
});
