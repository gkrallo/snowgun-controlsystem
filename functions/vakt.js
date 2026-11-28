/* En körning av vakten: läs läget, bedöm det, spara det och skicka notiserna.

   Ordningen är poängen (K2 i granskningen 28 november). Förut sparades läget
   först och notisen skickades efteråt, utan nytt försök: ett kort fel hos
   Google just då, och larmet räknades som skickat fast ingen fått det. Nästa
   försök var påminnelsen en timme senare.

   Nu läggs varje notis i en kö (/larmlage/ko) i SAMMA skrivning som läget.
   Kön töms först när notiserna gått fram. Går något snett emellan (Google
   svarar fel, medlemslistan går inte att läsa, funktionen avbryts) ligger
   notisen kvar och provas igen nästa minut, i upp till en timme.

   Filen rör inte Firebase själv. Allt in och ut går genom io, så att
   ordningen går att prova på datorn (node --test vakt.test.js):

     io.las()                -> { live, lage, notis }
     io.skriv(upd)           -> sparar flera sökvägar i en skrivning
     io.mottagare(notis)     -> [{ uid, enhet, token, prov }]; kastar fel om
                                det inte går att avgöra vilka som ska ha larmen
     io.skicka(till, notiser)-> { framme, svar }; framme = någon fick dem,
                                eller det finns ingen att skicka till */

'use strict';
const { bedom } = require('./larm.js');

const MIN = 60000;
// Så länge provas en notis som inte gått fram. Efter en timme kommer
// påminnelsen om ett okvitterat larm ändå, och ett äldre besked är inaktuellt.
const KO_TID = 60 * MIN;
// Kön ska inte kunna växa hur som helst om Google är nere länge.
const KO_MAX = 20;
const FALT = ['typ', 'titel', 'text', 'sedan', 'skickad', 'paminnd', 'kvittSkickad'];
const lista = x => Array.isArray(x) ? x.filter(Boolean) : Object.values(x || {});

async function korning(io, nu) {
  const inne = await io.las();
  const lage = inne.lage || {};
  const r = bedom(inne.live, lage.aktiva, lage.minne, nu);

  const kvar = lista(lage.ko).filter(s => s && s.titel && Number.isFinite(s.sedan) && nu - s.sedan < KO_TID);
  const ko = kvar.concat(r.skicka.map(s => Object.assign({}, s, { sedan: nu }))).slice(-KO_MAX);

  // Skrivs fält för fält och inte hela /larmlage: en kvittering som någon
  // gör medan funktionen räknar ska inte skrivas över.
  const upd = { 'larmlage/minne': r.minne, 'larmlage/ko': ko.length ? ko : null };
  for (const id of Object.keys(lage.aktiva || {})) if (!r.aktiva[id]) upd['larmlage/aktiva/' + id] = null;
  for (const [id, a] of Object.entries(r.aktiva))
    for (const f of FALT) upd['larmlage/aktiva/' + id + '/' + f] = a[f] === undefined ? null : a[f];
  await io.skriv(upd);

  // Kastar mottagare() eller skicka() fel avbryts körningen här, och kön
  // ligger kvar till nästa minut.
  const till = await io.mottagare(inne.notis);
  let framme = true;
  if (ko.length) {
    framme = !!(await io.skicka(till, ko)).framme;
    if (framme) await io.skriv({ 'larmlage/ko': null });
  }
  return { r, ko, till, framme, omforsok: kvar.length };
}

module.exports = { korning, KO_TID, KO_MAX };
