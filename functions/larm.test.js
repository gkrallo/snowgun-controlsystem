// Prov av larmens bedömning: node --test functions/
'use strict';
const test = require('node:test');
const assert = require('node:assert');
const { bedom, GRANS, enhetNamn } = require('./larm.js');

const MIN = 60000;
const T0 = Date.UTC(2026, 10, 26, 22, 0, 0);
// Styrsystemets lokala klocka, utan zon. Bara skillnader räknas.
const lok = ms => new Date(ms + 3600e3).toISOString().slice(0, 19);

function live(nu, enheter, extra) {
  return Object.assign({
    meta: { ts: nu - 20000, gssTid: lok(nu), sqlOk: true },
    enheter, larm: []
  }, extra || {});
}
const kanon = (nu, k415, x) => Object.assign({ k415, brunn: 7, senastHord: lok(nu - 10000), flode: k415 === 6 ? 8 : 0 }, x || {});

// Kör bedömningen minut för minut och samlar notiserna.
function korning(steg) {
  let aktiva = {}, minne = {}, alla = [];
  for (const [nu, l] of steg) {
    const r = bedom(l, aktiva, minne, nu);
    aktiva = r.aktiva; minne = r.minne;
    alla.push(...r.skicka.map(s => Object.assign({ nu }, s)));
  }
  return { aktiva, minne, alla };
}

test('namnen följer Modbus-adressen', () => {
  assert.strictEqual(enhetNamn('SGC400-3', {}), 'Kanon 5');
  assert.strictEqual(enhetNamn('SGC300-1', {}), 'Kanon 1');
  assert.strictEqual(enhetNamn('SGC300-1', { typ: 'TAURUS 2.0' }), 'Lans 1');
});

test('en kanon som stannar larmar efter tre minuter, en gång', () => {
  const steg = [];
  for (let i = 0; i < 10; i++) { const nu = T0 + i * MIN; steg.push([nu, live(nu, { 'SGC400-3': kanon(nu, 6) })]); }
  for (let i = 10; i < 20; i++) { const nu = T0 + i * MIN; steg.push([nu, live(nu, { 'SGC400-3': kanon(nu, 1) })]); }
  const r = korning(steg);
  assert.strictEqual(r.alla.length, 1);
  assert.strictEqual(r.alla[0].titel, 'Kanon 5 står i fel');
  assert.strictEqual(r.alla[0].nu, T0 + 13 * MIN);
  assert.strictEqual(r.alla[0].tyst, false);
  assert.match(r.alla[0].text, /Brunn 7/);
  assert.ok(r.aktiva['enhet-SGC400-3']);
});

test('en kort omstart larmar inte', () => {
  const steg = [];
  for (let i = 0; i < 20; i++) {
    const nu = T0 + i * MIN, lage = (i === 5 || i === 6) ? 2 : 6;
    steg.push([nu, live(nu, { 'SGC400-1': kanon(nu, lage) })]);
  }
  assert.strictEqual(korning(steg).alla.length, 0);
});

test('en kanon som stått länge larmar inte', () => {
  const steg = [];
  for (let i = 0; i < 20; i++) { const nu = T0 + i * MIN; steg.push([nu, live(nu, { 'SGC400-4': kanon(nu, 11) })]); }
  assert.strictEqual(korning(steg).alla.length, 0);
});

test('larmet går över tyst när kanonen kör igen', () => {
  const steg = [];
  for (let i = 0; i < 3; i++) { const nu = T0 + i * MIN; steg.push([nu, live(nu, { 'SGC400-3': kanon(nu, 6) })]); }
  for (let i = 3; i < 10; i++) { const nu = T0 + i * MIN; steg.push([nu, live(nu, { 'SGC400-3': kanon(nu, 2) })]); }
  for (let i = 10; i < 12; i++) { const nu = T0 + i * MIN; steg.push([nu, live(nu, { 'SGC400-3': kanon(nu, 6) })]); }
  const r = korning(steg);
  assert.deepStrictEqual(r.alla.map(s => [s.titel, s.tyst]), [['Kanon 5 har stoppats', false], ['Kanon 5 kör igen', true]]);
  assert.strictEqual(r.alla[0].tag, r.alla[1].tag);
  assert.deepStrictEqual(r.aktiva, {});
});

test('flera kanoner som stannar samtidigt blir en notis', () => {
  const steg = [];
  for (let i = 0; i < 10; i++) {
    const nu = T0 + i * MIN, l = i < 3 ? 6 : 2;
    steg.push([nu, live(nu, { 'SGC400-1': kanon(nu, l), 'SGC400-2': kanon(nu, l), 'SGC300-1': kanon(nu, undefined, { flode: i < 3 ? 6 : 0 }) })]);
  }
  const r = korning(steg);
  assert.strictEqual(r.alla.length, 1);
  assert.strictEqual(r.alla[0].titel, '3 larm');
  assert.strictEqual(Object.keys(r.aktiva).length, 3);
});

test('en kanon som tystnar larmar "hörs inte"', () => {
  const steg = [];
  for (let i = 0; i < 3; i++) { const nu = T0 + i * MIN; steg.push([nu, live(nu, { 'SGC400-2': kanon(nu, 6) })]); }
  const tyst = lok(T0 + 2 * MIN);
  for (let i = 3; i < 15; i++) { const nu = T0 + i * MIN; steg.push([nu, live(nu, { 'SGC400-2': kanon(nu, 6, { senastHord: tyst }) })]); }
  const r = korning(steg);
  assert.strictEqual(r.alla.length, 1);
  assert.strictEqual(r.alla[0].titel, 'Kanon 4 hörs inte');
});

test('bryggan tyst: larm, inga andra bedömningar, och tyst när den kommer tillbaka', () => {
  const steg = [];
  for (let i = 0; i < 3; i++) { const nu = T0 + i * MIN; steg.push([nu, live(nu, { 'SGC400-1': kanon(nu, 6) })]); }
  // Bryggan stannar: /live står kvar som den var.
  const kvar = live(T0 + 2 * MIN, { 'SGC400-1': kanon(T0 + 2 * MIN, 6) });
  for (let i = 3; i < 20; i++) steg.push([T0 + i * MIN, kvar]);
  for (let i = 20; i < 22; i++) { const nu = T0 + i * MIN; steg.push([nu, live(nu, { 'SGC400-1': kanon(nu, 6) })]); }
  const r = korning(steg);
  assert.deepStrictEqual(r.alla.map(s => [s.titel, s.tyst]), [['Bryggan är tyst', false], ['Bryggan hörs igen', true]]);
  assert.strictEqual(r.alla[0].nu, T0 + 12 * MIN);
});

test('styrsystemet utan databas: ett larm, och kanonerna bedöms inte', () => {
  const steg = [];
  for (let i = 0; i < 3; i++) { const nu = T0 + i * MIN; steg.push([nu, live(nu, { 'SGC400-1': kanon(nu, 6) })]); }
  for (let i = 3; i < 10; i++) {
    const nu = T0 + i * MIN, l = live(nu, { 'SGC400-1': kanon(nu, 2) });
    l.meta.sqlOk = false; steg.push([nu, l]);
  }
  const r = korning(steg);
  assert.deepStrictEqual(r.alla.map(s => s.titel), ['Bryggan når inte styrsystemet']);
});

test('kvittering: "tar det" en gång, ingen påminnelse', () => {
  let aktiva = {}, minne = {}, skickat = [];
  for (let i = 0; i < 120; i++) {
    const nu = T0 + i * MIN;
    const r = bedom(live(nu, { 'SGC400-3': kanon(nu, i < 3 ? 6 : 1) }), aktiva, minne, nu);
    aktiva = r.aktiva; minne = r.minne; skickat.push(...r.skicka);
    if (i === 20) aktiva['enhet-SGC400-3'].kvitt = { uid: 'x', namn: 'Kristian', ts: nu };
  }
  assert.deepStrictEqual(skickat.map(s => s.text.split('.')[0]), ['Brunn 7', 'Kristian tar det']);
  assert.strictEqual(skickat[1].tyst, true);
});

test('okvitterat larm påminner en gång efter en timme', () => {
  let aktiva = {}, minne = {}, skickat = [];
  for (let i = 0; i < 200; i++) {
    const nu = T0 + i * MIN;
    const r = bedom(live(nu, { 'SGC400-3': kanon(nu, i < 3 ? 6 : 1) }), aktiva, minne, nu);
    aktiva = r.aktiva; minne = r.minne; skickat.push(...r.skicka);
  }
  assert.deepStrictEqual(skickat.map(s => s.titel), ['Kanon 5 står i fel', 'Fortfarande: Kanon 5 står i fel']);
});

test('ett stopp som står kvar glöms efter tolv timmar och larmar inte igen', () => {
  let aktiva = {}, minne = {}, skickat = [];
  const steg = 14 * 60;
  for (let i = 0; i < steg; i += 1) {
    const nu = T0 + i * MIN;
    const r = bedom(live(nu, { 'SGC400-3': kanon(nu, i < 3 ? 6 : 2) }), aktiva, minne, nu);
    aktiva = r.aktiva; minne = r.minne; skickat.push(...r.skicka);
  }
  assert.deepStrictEqual(aktiva, {});
  assert.strictEqual(skickat.length, 2);
  assert.ok(GRANS.glom >= 12 * 60 * MIN);
});

test('nytt larm i styrsystemet blir en notis, gamla och borttagna inte', () => {
  const gammalt = { id: 'SGC850_def_voie_pres_eau_1', maskin: 'Networked Snowgun', namn: '1 901', text: 'Fault water pressure channel' };
  const bort = { id: 'SGC300_def26_2', maskin: 'SGC300', namn: '0 2', text: 'general fault' };
  const nytt = { id: 'SGC400_def_5', maskin: 'Autonomous Snowgun', namn: '2 5 10', text: 'Fan mismatch fault' };
  const steg = [];
  for (let i = 0; i < 5; i++) { const nu = T0 + i * MIN; steg.push([nu, live(nu, {}, { larm: i < 3 ? [bort, gammalt] : [bort, gammalt, nytt] })]); }
  const r = korning(steg);
  assert.strictEqual(r.alla.length, 1);
  assert.strictEqual(r.alla[0].text, 'Autonomous Snowgun 2 5 10: Fan mismatch fault');
});

test('verklig /live från 26 november ger inget larm första gången', () => {
  const nu = Date.UTC(2026, 10, 26, 14, 52, 1);
  const l = {
    meta: { gssTid: '2026-11-26T15:52:00', sqlOk: true, ts: nu - 1000 },
    enheter: {
      'SGC300-1': { brunn: 6, flode: 6.1, senastHord: '2026-11-26T15:51:43', typ: 'S ACCESS 300' },
      'SGC300-2': { brunn: 7, flode: 0, senastHord: '2022-10-19T11:40:32', typ: 'S ACCESS 300' },
      'SGC400-3': { brunn: 10, flode: 0, k415: 5, senastHord: '2026-11-26T15:51:56' },
      'SGC400-4': { brunn: 7, flode: 0, k415: 11, senastHord: '2026-10-30T15:06:19' }
    },
    larm: [{ id: 'SGC300_def26_2' }, { id: 'SGC850_def_voie_pres_eau_1' }]
  };
  const r = bedom(l, {}, {}, nu);
  assert.deepStrictEqual(r.skicka, []);
  assert.deepStrictEqual(r.aktiva, {});
  assert.strictEqual(r.minne.enheter['SGC300-1'].kor, nu);
  assert.strictEqual(r.minne.enheter['SGC400-3'].kor, undefined);
});
