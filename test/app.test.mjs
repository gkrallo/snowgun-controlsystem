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
