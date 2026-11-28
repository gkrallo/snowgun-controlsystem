/* Pushlarm för Snökoll (docs/forslag-pushlarm.md).

   En funktion, "vakt", körs i Googles moln varje minut. Den läser /live,
   bedömer läget (larm.js), sparar det i /larmlage och skickar notiser till
   telefonerna under /notis med Firebase Cloud Messaging. Ordningen, och kön
   som gör att en notis som inte gått fram provas igen, står i vakt.js. Här
   finns bara det som talar med Firebase.

   Varför en funktion på klocka och inte en som körs när bryggan skriver:
   larmet "Bryggan är tyst" måste komma just när bryggan INTE skriver, och då
   händer ingenting som kan starta en funktion. En minut är tillräckligt fort
   för allt annat också, och det blir bara en sak att förstå.

   Funktionen styr ingenting i anläggningen och har ingen väg dit. Den läser
   det bryggan redan skickat. */

'use strict';
const { onSchedule } = require('firebase-functions/v2/scheduler');
const logger = require('firebase-functions/logger');
const admin = require('firebase-admin');
const { korning } = require('./vakt.js');

admin.initializeApp({ databaseURL: 'https://snoprognos-default-rtdb.europe-west1.firebasedatabase.app' });

// Appens adress. Notisen öppnar larmsidan.
const APP = 'https://snow.pettersson.app/#larm';

// Vilka som får notiser: den som slagit på det i appen OCH fortfarande står
// under /members med bekräftad adress. Tas någon bort ur snögruppen slutar
// notiserna direkt, utan att någon behöver städa i /notis.
async function mottagare(db, notis) {
  const members = (await db.ref('members').get()).val() || {};
  const ut = [];
  for (const [uid, enheter] of Object.entries(notis || {})) {
    let ok = false;
    try {
      const u = await admin.auth().getUser(uid);
      ok = !!(u.email && u.emailVerified && members[u.email.toLowerCase().split('.').join(',')]);
    } catch (e) {
      // Kontot finns inte längre: ingen notis dit. Alla andra fel (Google
      // svarar inte just nu) kastas vidare, så att körningen avbryts och
      // notisen ligger kvar i kön. Förut räknades varje fel som "inte
      // medlem", och då kunde ett larm gå ut till ingen alls.
      if (!e || e.code !== 'auth/user-not-found') throw e;
    }
    if (!ok) continue;
    for (const [enhet, n] of Object.entries(enheter || {}))
      if (n && typeof n.token === 'string') ut.push({ uid, enhet, token: n.token, prov: n.prov });
  }
  return ut;
}

// Bara data, ingen färdig notis: service workern (app/sw.js) visar den
// själv. Då kan den byta ut en notis med samma tagg och öppna rätt sida, och
// det behövs inget Firebase-bibliotek i service workern.
function meddelande(token, s) {
  return {
    token,
    data: { titel: s.titel, text: s.text || '', tag: s.tag, tyst: s.tyst ? '1' : '0', url: APP },
    webpush: {
      // Hög prioritet väcker en telefon som sparar ström. En tyst notis om
      // att något gått över behöver inte det.
      headers: { Urgency: s.tyst ? 'normal' : 'high', TTL: '3600' },
      fcmOptions: { link: APP }
    }
  };
}

// Svarar { framme, svar }. framme = minst en telefon fick notiserna, eller
// det fanns ingen att skicka till. Är framme falskt provar vakt.js igen nästa
// minut. Fick några men inte alla dem skickas de inte om: de som fick dem
// skulle då få samma larm en gång till.
async function skicka(db, till, notiser) {
  const svar = [];
  let ok = 0, tillfalliga = 0;
  if (!till.length || !notiser.length) return { framme: true, svar };
  const msgs = [], vem = [];
  for (const s of notiser) for (const t of till) { msgs.push(meddelande(t.token, s)); vem.push(t); }
  // Högst 500 per anrop.
  for (let i = 0; i < msgs.length; i += 500) {
    const r = await admin.messaging().sendEach(msgs.slice(i, i + 500));
    // Loggas varje gång: utan det går det inte att se om en notis som inte
    // kom fram stannade hos oss, hos FCM eller i telefonen (26 november).
    console.log('FCM svarade: ' + r.successCount + ' ok, ' + r.failureCount + ' fel, ' + notiser.map(s => s.titel).join(' / '));
    const bort = {};
    r.responses.forEach((x, j) => {
      if (x.success) { ok++; return; }
      const code = x.error && x.error.code;
      const t = vem[i + j];
      // Appen avinstallerad eller notiser avslagna i telefonen: adressen
      // gäller inte längre och tas bort.
      if (code === 'messaging/registration-token-not-registered' || code === 'messaging/invalid-registration-token')
        bort['notis/' + t.uid + '/' + t.enhet] = null;
      else { tillfalliga++; logger.warn('Notisen gick inte fram', { code, uid: t.uid }); }
    });
    svar.push(...r.responses.map(x => x.success ? 'ok' : String(x.error && (x.error.code + ' ' + x.error.message)).slice(0, 300)));
    if (Object.keys(bort).length) await db.ref().update(bort);
  }
  return { framme: ok > 0 || tillfalliga === 0, svar };
}

exports.vakt = onSchedule({
  schedule: 'every 1 minutes',
  timeZone: 'Europe/Stockholm',
  region: 'europe-west1',
  // En körning åt gången, och ingen omkörning av en som misslyckats: nästa
  // minut kommer ändå, och en omkörning kan skicka samma notis två gånger.
  maxInstances: 1,
  retryCount: 0,
  memory: '256MiB',
  timeoutSeconds: 50
}, async () => {
  const db = admin.database();
  const nu = Date.now();
  const k = await korning({
    las: async () => {
      const [liveS, lageS, notisS] = await Promise.all([db.ref('live').get(), db.ref('larmlage').get(), db.ref('notis').get()]);
      return { live: liveS.val(), lage: lageS.val(), notis: notisS.val() };
    },
    skriv: upd => db.ref().update(upd),
    mottagare: notis => mottagare(db, notis),
    skicka: (till, notiser) => skicka(db, till, notiser)
  }, nu);
  const till = k.till;
  if (!k.framme) logger.warn('Notiserna gick inte fram och provas igen nästa minut', { notiser: k.ko.map(s => s.titel) });

  // Provnotis: appens knapp sätter prov på sin egen telefon. Den går bara dit.
  const prov = till.filter(t => Number.isFinite(t.prov));
  for (const t of prov) {
    const { svar } = await skicka(db, [t], [{ tag: 'prov', titel: 'Provnotis från Snökoll', text: 'Larmen kommer fram till den här telefonen.', tyst: false }]);
    await db.ref('notis/' + t.uid + '/' + t.enhet + '/prov').remove();
    // Senaste provets svar från FCM, så att man kan se om en provnotis som
    // inte kom fram stannade hos FCM eller i telefonen. Ingen adress sparas.
    await db.ref('larmlage/prov').set({ ts: nu, telefon: t.enhet, svar: svar.join(' | ') || 'inget skickat' });
  }
  if (k.ko.length && k.framme) logger.info('Skickade', { notiser: k.ko.map(s => s.titel), telefoner: till.length, omforsok: k.omforsok });
});
