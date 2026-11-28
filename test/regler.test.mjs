/* Prov av databasens regler (firebase/database.rules.json) mot Firebases
   lokala emulator. Ingenting här rör den riktiga databasen: projektet heter
   demo-snokoll och finns bara på den här datorn.

   Körs från repots rot:

     firebase emulators:exec --only database --project demo-snokoll "node --test test/regler.test.mjs"

   Emulatorn kräver Java. Inga npm-paket behövs: provet talar med emulatorn
   över REST. Inloggade användare härmas med osignerade tokens, som bara
   emulatorn godtar. */
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const HOST = process.env.FIREBASE_DATABASE_EMULATOR_HOST;
if (!HOST) {
  console.error('Emulatorn går inte. Kör:\n  firebase emulators:exec --only database --project demo-snokoll "node --test test/regler.test.mjs"');
  process.exit(1);
}
const NS = 'demo-snokoll-default-rtdb';
const BRYGGA = 'GKqPM6LQz2PRML5ayk4jAqfiaF42';   // bryggans uid, samma som i reglerna

const b64 = o => Buffer.from(JSON.stringify(o)).toString('base64url');
function token(uid, email, extra = {}) {
  const nu = Math.floor(Date.now() / 1000);
  return b64({ alg: 'none', typ: 'JWT' }) + '.' + b64(Object.assign({
    iss: 'https://securetoken.google.com/demo-snokoll', aud: 'demo-snokoll',
    iat: nu, exp: nu + 3600, auth_time: nu, sub: uid, user_id: uid,
    email, email_verified: true,
    firebase: { sign_in_provider: 'google.com', identities: {} }
  }, extra)) + '.';
}
const MEDLEM = token('uid-medlem', 'Medlem.Ett@example.com');
const ANNAN = token('uid-annan', 'annan@example.com');
const ADMIN = token('uid-admin', 'admin@example.com');
const UTANFOR = token('uid-utanfor', 'utanfor@example.com');
const OBEKRAFTAD = token('uid-medlem', 'medlem.ett@example.com', { email_verified: false });
const BRYGGAN = token(BRYGGA, 'brygga@example.com');

const url = (path, tok) => `http://${HOST}/${path.split('/').map(encodeURIComponent).join('/')}.json?ns=${NS}` + (tok && tok !== 'owner' ? '&auth=' + tok : '');
async function anrop(metod, path, tok, data) {
  const r = await fetch(url(path, tok), {
    method: metod,
    headers: Object.assign({ 'Content-Type': 'application/json' }, tok === 'owner' ? { Authorization: 'Bearer owner' } : {}),
    body: data === undefined ? undefined : JSON.stringify(data)
  });
  return { ok: r.ok, status: r.status, val: await r.json().catch(() => null) };
}
const las = (p, t) => anrop('GET', p, t);
const satt = (p, t, d) => anrop('PUT', p, t, d);
const andra = (p, t, d) => anrop('PATCH', p, t, d);
const tabort = (p, t) => anrop('DELETE', p, t);
const far = async (lofte, vad) => { const r = await lofte; assert.ok(r.ok, `${vad}: borde gå, men svaret var ${r.status} ${JSON.stringify(r.val)}`); return r; };
const nekas = async (lofte, vad) => { const r = await lofte; assert.ok(!r.ok && (r.status === 401 || r.status === 403), `${vad}: borde nekas, men svaret var ${r.status}`); };

const NU = Date.now();
const avlas = (uid, x = {}) => Object.assign({ ts: NU - 60000, m3: 73478.4, typ: 'avl', uid, namn: 'Prov' }, x);
const kalib = (uid, x = {}) => Object.assign({ ts: NU - 60000, cm: 120, punkt: 'SN', uid, namn: 'Prov' }, x);
// Nyckeln som S2 handlar om: bryter sig ur onclick="mtRedigera('…')".
const ELAK = "x');alert(1);('";

test.before(async () => {
  const regler = fs.readFileSync(new URL('../firebase/database.rules.json', import.meta.url), 'utf8');
  const r = await fetch(`http://${HOST}/.settings/rules.json?ns=${NS}`, { method: 'PUT', headers: { Authorization: 'Bearer owner' }, body: regler });
  assert.ok(r.ok, 'Emulatorn tog inte emot reglerna: ' + await r.text());
});
test.beforeEach(async () => {
  await far(satt('', 'owner', {
    members: {
      'medlem,ett@example,com': { role: 'viewer', name: 'Medlem Ett' },
      'annan@example,com': { role: 'viewer', name: 'Annan' },
      'admin@example,com': { role: 'admin', name: 'Admin' }
    }
  }), 'nollställning');
});

test('utan inloggning går ingenting att läsa', async () => {
  for (const p of ['', 'live', 'hist', 'damm', 'members', 'larmlage', 'vattenTimme', 'notis'])
    await nekas(las(p, null), 'läsa /' + p + ' utan inloggning');
});

test('inloggad utan rad i medlemslistan, eller med obekräftad adress, läser ingenting', async () => {
  for (const p of ['live', 'hist', 'damm', 'vattenTimme', 'larmlage']) {
    await nekas(las(p, UTANFOR), 'läsa /' + p + ' som utomstående');
    await nekas(las(p, OBEKRAFTAD), 'läsa /' + p + ' med obekräftad adress');
  }
  await far(las('damm', MEDLEM), 'läsa /damm som medlem');
});

test('medlem kan inte lägga till sig själv eller göra sig till administratör', async () => {
  await nekas(satt('members/utanfor@example,com', UTANFOR, { role: 'viewer', name: 'x' }), 'lägga till sig själv');
  await nekas(satt('members/medlem,ett@example,com/role', MEDLEM, 'admin'), 'göra sig till administratör');
  await far(satt('members/ny@example,com', ADMIN, { role: 'viewer', name: 'Ny' }), 'administratör lägger till');
});

test('S2: dammens rader måste ha en nyckel av bokstäver, siffror, - och _', async () => {
  await far(satt('damm/avlas/-OabcDEF_123456789ab', MEDLEM, avlas('uid-medlem')), 'avläsning med vanlig nyckel');
  await far(satt('damm/kalib/-OabcDEF_123456789ab', MEDLEM, kalib('uid-medlem')), 'mätning med vanlig nyckel');
  for (const k of [ELAK, 'a b', 'a"b', 'a<b>', 'a=b', 'x'.repeat(41)]) {
    await nekas(satt('damm/avlas/' + k, MEDLEM, avlas('uid-medlem')), 'avläsning med nyckeln ' + k);
    await nekas(satt('damm/kalib/' + k, MEDLEM, kalib('uid-medlem')), 'mätning med nyckeln ' + k);
    await nekas(satt('damm/avlas/' + k, ADMIN, avlas('uid-admin')), 'avläsning med nyckeln ' + k + ' som administratör');
  }
  // Samma sak när flera rader skrivs i ett anrop.
  await nekas(andra('damm/avlas', MEDLEM, { [ELAK]: avlas('uid-medlem') }), 'elak nyckel i ett samlat anrop');
  assert.deepEqual(Object.keys((await las('damm/avlas', 'owner')).val), ['-OabcDEF_123456789ab']);
});

test('S2: en rad med otillåten nyckel som redan finns går att ta bort för en administratör', async () => {
  await far(satt('damm/avlas/' + ELAK, 'owner', avlas('uid-annan')), 'så in en gammal elak rad');
  await nekas(tabort('damm/avlas/' + ELAK, MEDLEM), 'ta bort någon annans rad som medlem');
  await far(tabort('damm/avlas/' + ELAK, ADMIN), 'ta bort som administratör');
  assert.equal((await las('damm/avlas', 'owner')).val, null);
});

test('dammen: man ändrar sitt eget, administratören allt, och ingen skriver i någon annans namn', async () => {
  await far(satt('damm/avlas/rad1', MEDLEM, avlas('uid-medlem')), 'lägga till');
  await far(satt('damm/avlas/rad1', MEDLEM, avlas('uid-medlem', { m3: 73500 })), 'rätta sin egen');
  await nekas(satt('damm/avlas/rad1', ANNAN, avlas('uid-medlem', { m3: 1 })), 'rätta någon annans');
  await nekas(tabort('damm/avlas/rad1', ANNAN), 'ta bort någon annans');
  await far(satt('damm/avlas/rad1', ADMIN, avlas('uid-medlem', { m3: 73501 })), 'administratören rättar, mätaren står kvar');
  await nekas(satt('damm/avlas/rad2', MEDLEM, avlas('uid-annan')), 'ny rad i någon annans namn');
  await nekas(satt('damm/avlas/rad3', MEDLEM, avlas('uid-medlem', { extra: 1 })), 'okänt fält');
  await nekas(satt('damm/avlas/rad4', MEDLEM, avlas('uid-medlem', { typ: 'annat' })), 'okänd typ');
  await nekas(satt('damm/avlas/rad5', UTANFOR, avlas('uid-utanfor')), 'utomstående skriver');
  await far(tabort('damm/avlas/rad1', MEDLEM), 'ta bort sin egen');
});

test('medlemmar kan inte skriva driftdata', async () => {
  for (const p of ['live/meta/ts', 'hist/202611281200', 'vattenTimme/2026112812', 'larmlage/aktiva/brygga/titel', 'larmlage/minne/x'])
    await nekas(satt(p, MEDLEM, 1), 'skriva /' + p + ' som medlem');
  await nekas(satt('live/meta/ts', ADMIN, 1), 'skriva /live som administratör');
});

/* ---------- S6: bryggans konto får fylla på, inte ta bort ---------- */

const SV = { '.sv': 'timestamp' };
// Historikens nyckel: UTC på jämna fem minuter, som bryggan räknar den.
const slot = ms => { const d = new Date(ms - ms % 300000); return d.toISOString().replace(/\D/g, '').slice(0, 12); };
const punkt = (x = {}) => Object.assign({ ts: SV, t: -4.1, tw: -5.2, tryckUt: 24.5, k125: 20.1, k126: 0.1, e: { 'SGC400-3': { t: -5, tw: -6, flode: 8.3, vb: 12.5 } }, flodeSum: 8.3 }, x);

test('S6: bryggan skriver nuläget som förut, hela och bitvis', async () => {
  await far(satt('live', BRYGGAN, {
    meta: { ts: SV, sqlOk: true, version: '13', lasMs: 40, gssTid: '2026-11-28T12:00:00', gssAlder: 20, skrivkonto: true },
    enheter: { 'SGC400-3': { typ: 'S ACCESS 300', tw: -6.2, flode: 8.3, brunn: 7, k415: 6 } },
    pump: { dep12: { tryckUt: 24.5, k125: 20 } }, larm: [{ id: 'x1', text: 'fault' }]
  }), 'hela nuläget (PUT /live)');
  await far(andra('live', BRYGGAN, { 'meta/ts': SV, 'meta/sqlOk': true, 'meta/version': '13', 'meta/lasMs': 35, 'enheter/SGC400-3/tw': -6.4, 'enheter/SGC400-4/tw': null }), 'ändrade fält (PATCH /live)');
  const v = (await las('live', MEDLEM)).val;
  assert.equal(v.enheter['SGC400-3'].tw, -6.4);
  assert.ok(Math.abs(v.meta.ts - Date.now()) < 60000, 'hjärtslaget har molnets klocka');
});

test('S6: hjärtslaget kan inte stämplas in i framtiden', async () => {
  await nekas(andra('live', BRYGGAN, { 'meta/ts': Date.now() + 86400000 }), 'ts ett dygn fram');
  await nekas(satt('live', BRYGGAN, { meta: { ts: Date.now() + 86400000, sqlOk: true } }), 'hela nuläget med ts i framtiden');
  await nekas(andra('live', BRYGGAN, { 'meta/ts': 'nu' }), 'ts som text');
});

test('S6: historiken får nya punkter, och den senaste får skrivas om', async () => {
  const k = slot(Date.now());
  await far(andra('hist', BRYGGAN, { [k]: punkt() }), 'ny punkt (PATCH /hist, som bryggan gör)');
  // Bryggan startas om innan den hunnit spara vilken punkt som var den sista.
  await far(andra('hist', BRYGGAN, { [k]: punkt({ t: -4.3 }) }), 'samma punkt en gång till inom en kvart');
  assert.equal((await las('hist/' + k, MEDLEM)).val.t, -4.3);
});

test('S6: bryggans konto kan inte ta bort eller skriva över historiken', async () => {
  const gammal = slot(Date.now() - 3 * 3600e3), g2 = slot(Date.now() - 2 * 3600e3);
  await far(satt('hist', 'owner', { [gammal]: punkt({ ts: Date.now() - 3 * 3600e3 }), [g2]: punkt({ ts: Date.now() - 2 * 3600e3 }) }), 'så in två gamla punkter');
  await nekas(tabort('hist', BRYGGAN), 'ta bort hela historiken');
  await nekas(satt('hist', BRYGGAN, {}), 'ersätta hela historiken med ingenting');
  await nekas(satt('hist', BRYGGAN, { [slot(Date.now())]: punkt() }), 'ersätta hela historiken med en punkt');
  await nekas(tabort('hist/' + gammal, BRYGGAN), 'ta bort en gammal punkt');
  await nekas(andra('hist', BRYGGAN, { [gammal]: null }), 'ta bort en gammal punkt i ett samlat anrop');
  await nekas(andra('hist', BRYGGAN, { [gammal]: punkt({ t: 99 }) }), 'skriva över en gammal punkt');
  await nekas(satt('hist/' + gammal + '/t', BRYGGAN, 99), 'ändra ett fält i en gammal punkt');
  // Bryggans eget prov (-ProvaMoln): punkten finns inte, och svaret ska vara nej.
  await nekas(tabort('hist/200001010000', BRYGGAN), 'ta bort en punkt som inte finns');
  const kvar = (await las('hist', 'owner')).val;
  assert.deepEqual(Object.keys(kvar).sort(), [gammal, g2].sort());
  assert.equal(kvar[gammal].t, -4.1);
});

test('S6: en historikpunkt måste ha rätt nyckel och en tid som inte ligger i framtiden', async () => {
  await nekas(andra('hist', BRYGGAN, { skrap: punkt() }), 'nyckel som inte är en tid');
  await nekas(andra('hist', BRYGGAN, { '2026112812': punkt() }), 'för kort nyckel');
  await nekas(andra('hist', BRYGGAN, { [slot(Date.now())]: { t: -4 } }), 'punkt utan ts');
  await nekas(andra('hist', BRYGGAN, { [slot(Date.now())]: punkt({ ts: Date.now() + 86400000 }) }), 'ts i framtiden');
});

test('S6: -ProvaMoln fungerar som förut', async () => {
  const prov = { prov: true, tid: SV };
  for (const g of ['live', 'hist']) {
    await far(satt(g + '/_prov', BRYGGAN, prov), 'provvärde under /' + g);
    await far(tabort(g + '/_prov', BRYGGAN), 'ta bort provvärdet under /' + g);
  }
  await nekas(las('members', BRYGGAN), 'läsa medlemslistan');
  await nekas(satt('members/_prov', BRYGGAN, prov), 'skriva i medlemslistan');
  await nekas(satt('annat/_prov', BRYGGAN, prov), 'skriva någon annanstans');
  await nekas(satt('damm/avlas/x1', BRYGGAN, avlas(BRYGGA)), 'skriva i dammloggen');
  await nekas(satt('larmlage/aktiva/brygga/titel', BRYGGAN, 'x'), 'skriva i larmläget');
});

test('S6: timvattnet får skrivas och skrivas om, men inte tas bort', async () => {
  await far(andra('vattenTimme', BRYGGAN, { '2026112810': 12.5, '2026112811': 3.25 }), 'två timmar');
  await far(andra('vattenTimme', BRYGGAN, { '2026112811': 30.1 }), 'den pågående timmen växer');
  await nekas(tabort('vattenTimme', BRYGGAN), 'ta bort allt timvatten');
  await nekas(satt('vattenTimme', BRYGGAN, { '2026112811': 1 }), 'ersätta allt timvatten');
  await nekas(tabort('vattenTimme/2026112810', BRYGGAN), 'ta bort en timme');
  await nekas(andra('vattenTimme', BRYGGAN, { '2026112810': null }), 'ta bort en timme i ett samlat anrop');
  await nekas(andra('vattenTimme', BRYGGAN, { skrap: 1 }), 'nyckel som inte är en timme');
  await nekas(andra('vattenTimme', BRYGGAN, { '2026112812': 5000 }), 'orimligt värde');
  assert.deepEqual((await las('vattenTimme', MEDLEM)).val, { '2026112810': 12.5, '2026112811': 30.1 });
});

/* ---------- S7: medlemmar loggar in med Google ---------- */

test('S7: ett konto med lösenord släpps inte in som medlem, fast adressen står i listan', async () => {
  const LOSEN = token('uid-losen', 'medlem.ett@example.com', { firebase: { sign_in_provider: 'password', identities: {} } });
  const ADMINLOSEN = token('uid-losen2', 'admin@example.com', { firebase: { sign_in_provider: 'password', identities: {} } });
  for (const p of ['live', 'hist', 'damm', 'vattenTimme', 'larmlage']) await nekas(las(p, LOSEN), 'läsa /' + p + ' med lösenordskonto');
  await nekas(satt('damm/avlas/rad1', LOSEN, avlas('uid-losen')), 'skriva i dammloggen med lösenordskonto');
  await nekas(las('members', ADMINLOSEN), 'läsa medlemslistan med lösenordskonto');
  await nekas(satt('members/ny@example,com', ADMINLOSEN, { role: 'admin', name: 'x' }), 'ändra medlemslistan med lösenordskonto');
  await nekas(las('members/medlem,ett@example,com', LOSEN), 'läsa sin egen rad med lösenordskonto');
  await far(las('members/medlem,ett@example,com', MEDLEM), 'läsa sin egen rad med Google');
  await far(las('members', ADMIN), 'administratören läser listan med Google');
});

test('notiser och kvittering: bara ens egna, och bara medlemmar', async () => {
  const anm = { token: 'x'.repeat(40), ts: Date.now(), namn: 'Medlem', ua: 'prov' };
  await far(satt('notis/uid-medlem/abcdefgh12345678', MEDLEM, anm), 'anmäla sin telefon');
  await nekas(satt('notis/uid-annan/abcdefgh12345678', MEDLEM, anm), 'anmäla någon annans');
  await nekas(las('notis/uid-medlem', ANNAN), 'läsa någon annans anmälan');
  await nekas(satt('notis/uid-utanfor/abcdefgh12345678', UTANFOR, anm), 'anmäla sig utan att vara medlem');
  await far(tabort('notis/uid-medlem/abcdefgh12345678', MEDLEM), 'ta bort sin anmälan (Logga ut gör det)');
  await far(satt('larmlage/aktiva/enhet-SGC400-3', 'owner', { typ: 'enhet', titel: 'Kanon 5 står i fel', text: '', sedan: Date.now() }), 'så in ett larm');
  const kv = { uid: 'uid-medlem', namn: 'Medlem', ts: Date.now() };
  await far(satt('larmlage/aktiva/enhet-SGC400-3/kvitt', MEDLEM, kv), 'kvittera');
  await nekas(satt('larmlage/aktiva/enhet-SGC400-3/kvitt', ANNAN, { uid: 'uid-annan', namn: 'Annan', ts: Date.now() }), 'kvittera en gång till');
  await nekas(satt('larmlage/aktiva/finns-inte/kvitt', MEDLEM, kv), 'kvittera ett larm som inte finns');
  await nekas(satt('larmlage/ko', MEDLEM, [{ titel: 'x' }]), 'skriva i notiskön');
});
