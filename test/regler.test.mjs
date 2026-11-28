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

export { HOST, NS, BRYGGA, BRYGGAN, MEDLEM, ADMIN, las, satt, andra, tabort, far, nekas };
