// Prov av vaktens ordning (K2): node --test vakt.test.js
// Databasen och Google är atrapper. Det som provas är att en notis som inte
// gått fram provas igen, och att ingen får samma larm två gånger i onödan.
'use strict';
const test = require('node:test');
const assert = require('node:assert');
const { korning, KO_TID } = require('./vakt.js');

const MIN = 60000;
const T0 = Date.UTC(2026, 10, 26, 22, 0, 0);
const lok = ms => new Date(ms + 3600e3).toISOString().slice(0, 19);
const live = (nu, k415) => ({
  meta: { ts: nu - 20000, gssTid: lok(nu), sqlOk: true },
  enheter: { 'SGC400-3': { k415, brunn: 7, senastHord: lok(nu - 10000), flode: k415 === 6 ? 8 : 0 } },
  larm: []
});

// Tomma listor och objekt sparas inte i Realtime Database.
function somDatabasen(v) {
  if (v === null || v === undefined) return null;
  if (typeof v !== 'object') return v;
  if (Array.isArray(v)) { const a = v.map(somDatabasen).filter(x => x !== null); return a.length ? a : null; }
  const o = {};
  for (const [k, x] of Object.entries(v)) { const y = somDatabasen(x); if (y !== null) o[k] = y; }
  return Object.keys(o).length ? o : null;
}

/* En låtsasdatabas och ett låtsas-Google. fel(minut) säger vad som går snett
   den minuten: 'google' (alla telefoner får ett tillfälligt fel), 'kastar'
   (anropet till Google kastar fel), 'medlemmar' (medlemslistan går inte att
   läsa), eller inget. */
function varld(fel) {
  const db = { larmlage: null }, framme = [], skrivningar = [];
  let minut = 0, nu = T0, lage = 6;
  const satt = (path, v) => {
    const delar = path.split('/'); let o = db;
    for (const d of delar.slice(0, -1)) o = o[d] = (o[d] && typeof o[d] === 'object') ? o[d] : {};
    o[delar[delar.length - 1]] = v;
  };
  const io = {
    las: async () => ({ live: live(nu, lage), lage: JSON.parse(JSON.stringify(db.larmlage)), notis: { u1: { tel: { token: 'x'.repeat(30) } } } }),
    skriv: async upd => {
      skrivningar.push({ minut, upd: JSON.parse(JSON.stringify(upd)) });
      for (const [p, v] of Object.entries(upd)) satt(p, JSON.parse(JSON.stringify(v)));
      db.larmlage = somDatabasen(db.larmlage);
    },
    mottagare: async () => { if (fel(minut) === 'medlemmar') throw new Error('medlemslistan svarar inte'); return [{ uid: 'u1', enhet: 'tel', token: 'x' }]; },
    skicka: async (till, notiser) => {
      if (fel(minut) === 'kastar') throw new Error('Google svarar inte');
      if (fel(minut) === 'google') return { framme: false, svar: [] };
      framme.push(...notiser.map(s => ({ minut, titel: s.titel, tyst: s.tyst })));
      return { framme: true, svar: [] };
    }
  };
  return {
    db, framme, skrivningar,
    // Kör minut för minut. lageVid(minut) är kanonens läge (6 kör, 1 fel).
    async ga(minuter, lageVid) {
      for (let i = 0; i < minuter; i++, minut++) {
        nu = T0 + minut * MIN; lage = lageVid(minut);
        try { await korning(io, nu); } catch (e) { /* körningen avbröts, som i molnet */ }
      }
    }
  };
}
// Kanonen kör tre minuter och står sedan i fel: larmet kommer minut 6.
const stannar = m => m < 3 ? 6 : 1;

test('K2: allt går bra — larmet skickas en gång och kön är tom efteråt', async () => {
  const v = varld(() => null);
  await v.ga(20, stannar);
  assert.deepStrictEqual(v.framme, [{ minut: 6, titel: 'Kanon 5 står i fel', tyst: false }]);
  assert.strictEqual(v.db.larmlage.ko, undefined);
});

for (const [vad, namn] of [['google', 'Google svarar med fel'], ['kastar', 'anropet till Google kastar fel'], ['medlemmar', 'medlemslistan går inte att läsa']]) {
  test('K2: ' + namn + ' just när larmet ska ut — det går ut nästa minut i stället', async () => {
    const v = varld(m => m === 6 ? vad : null);
    await v.ga(20, stannar);
    assert.deepStrictEqual(v.framme, [{ minut: 7, titel: 'Kanon 5 står i fel', tyst: false }]);
    assert.strictEqual(v.db.larmlage.ko, undefined, 'kön ska vara tom när notisen gått fram');
    assert.ok(v.db.larmlage.aktiva['enhet-SGC400-3'], 'larmet står kvar som aktivt');
  });
}

test('K2: läget sparas tillsammans med kön, före första försöket att skicka', async () => {
  const v = varld(m => m === 6 ? 'kastar' : null);
  await v.ga(7, stannar);
  const s = v.skrivningar.filter(x => x.minut === 6);
  assert.strictEqual(s.length, 1, 'bara en skrivning när utskicket avbryts');
  assert.strictEqual(s[0].upd['larmlage/aktiva/enhet-SGC400-3/titel'], 'Kanon 5 står i fel');
  assert.strictEqual(s[0].upd['larmlage/ko'].length, 1);
  assert.deepStrictEqual(v.db.larmlage.ko.map(x => x.titel), ['Kanon 5 står i fel']);
});

test('K2: fel i flera minuter — notisen går ut en gång när det fungerar igen', async () => {
  const v = varld(m => m >= 6 && m < 15 ? 'google' : null);
  await v.ga(30, stannar);
  assert.deepStrictEqual(v.framme, [{ minut: 15, titel: 'Kanon 5 står i fel', tyst: false }]);
});

test('K2: en notis som inte gått fram på en timme släpps, och påminnelsen tar över', async () => {
  const slut = 6 + KO_TID / MIN + 10;
  const v = varld(m => m >= 6 && m < slut ? 'google' : null);
  await v.ga(slut + 5, stannar);
  // Det ursprungliga larmet är för gammalt. Påminnelsen (efter 60 min) ligger
  // däremot kvar i kön och går ut när Google svarar igen.
  assert.deepStrictEqual(v.framme.map(x => x.titel), ['Fortfarande: Kanon 5 står i fel']);
  assert.strictEqual(v.framme[0].minut, slut);
});

test('K2: larm och "kör igen" som båda fastnat går ut i rätt ordning', async () => {
  const v = varld(m => m >= 6 && m < 12 ? 'google' : null);
  await v.ga(20, m => (m < 3 || m >= 9) ? 6 : 1);
  assert.deepStrictEqual(v.framme.map(x => [x.minut, x.titel, x.tyst]), [[12, 'Kanon 5 står i fel', false], [12, 'Kanon 5 kör igen', true]]);
});

test('K2: en kvittering som görs under tiden skrivs inte över', async () => {
  const v = varld(() => null);
  await v.ga(8, stannar);
  v.db.larmlage.aktiva['enhet-SGC400-3'].kvitt = { uid: 'x', namn: 'Kristian', ts: T0 + 8 * MIN };
  await v.ga(5, stannar);
  assert.strictEqual(v.db.larmlage.aktiva['enhet-SGC400-3'].kvitt.namn, 'Kristian');
  assert.deepStrictEqual(v.framme.map(x => x.titel), ['Kanon 5 står i fel', 'Kanon 5 står i fel']);
  assert.strictEqual(v.framme[1].tyst, true);   // "Kristian tar det"
  for (const s of v.skrivningar) assert.ok(!Object.keys(s.upd).some(p => /\/kvitt$/.test(p)));
});
