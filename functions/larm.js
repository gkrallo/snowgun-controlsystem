/* Larmens bedömning: vad som larmar, när ett larm börjar och när det går över.

   Ren logik utan Firebase, så att den går att prova på datorn
   (node --test functions/). index.js läser databasen, kör bedom() och
   skickar det den säger.

   Larmen styr ingenting i anläggningen. De talar bara om för telefonerna att
   något hänt. Styrsystemets egna larm och skydd gäller som förut.

   Tiderna i /live (senastHord, gssTid) är styrsystemets lokala klocka utan
   zon. De jämförs bara med varandra, aldrig med molnets klocka, så zonen
   spelar ingen roll. meta.ts är molnets klocka och jämförs med nu. */

'use strict';

const MIN = 60000;
const GRANS = {
  // Bryggan skickar varje minut. Tio minuter utan något betyder att
  // styrdatorn, bryggan eller nätet står, inte ett enstaka tappat paket.
  tyst: 10 * MIN,
  // En enhet larmar bara om den har kört nyss. En kanon som stått sedan i
  // oktober ska inte larma för att den inte kör.
  korFonster: 30 * MIN,
  // En kanon som stannar och går igen inom några minuter (styrsystemet
  // startar om den) ska inte väcka någon.
  stoppVanta: 3 * MIN,
  // Samma som "hörd" i appen är en kvart, men ett larm ska komma fortare.
  kontakt: 5 * MIN,
  sqlVanta: 3 * MIN,
  // Styrsystemet skriver var 20:e sekund. Tio minuter utan nytt värde, fast
  // bryggan går och kan läsa, betyder att programmet är stängt eller hängt.
  gssStar: 10 * MIN,
  // Ett okvitterat larm påminner en gång.
  paminn: 60 * MIN,
  // En kanon som står kvar efter ett pass (flyttad, avstängd) ska inte ligga
  // som larm i all evighet.
  glom: 12 * 60 * MIN
};

// Kanonen på adress 2 (det äldre kortet) finns inte längre men står kvar i
// styrsystemets databas, med ett larm sedan 2024. Samma undantag som i appen.
const BORTTAGEN = /^SGC300-2$/;
const BORTTAGET_LARM = /^SGC300_.*_2$/;

const naiv = s => { const t = s ? Date.parse(String(s).slice(0, 19) + 'Z') : NaN; return Number.isFinite(t) ? t : null; };
const klocka = ms => new Date(ms).toLocaleTimeString('sv-SE', { hour: '2-digit', minute: '2-digit', timeZone: 'Europe/Stockholm' });
const klockaNaiv = s => (s && String(s).length >= 16) ? String(s).slice(11, 16) : 'okänt';

// Namnet snögruppen använder: Modbus-adressen. På SGC400 är den n° + 2,
// på det äldre kortet n° (samma som appen).
function enhetNamn(key, e) {
  const m = /^(SGC\d+)-(\d+)$/.exec(key) || [];
  const gammal = m[1] === 'SGC300', nr = +(m[2] || 0);
  const adr = gammal ? nr : nr + 2;
  return (/TAURUS/i.test((e && e.typ) || '') ? 'Lans ' : 'Kanon ') + adr;
}

// Kör = läget är 6 på SGC400. Det äldre kortet har inget läge, där räknas
// den som körande när vatten går (flödet räknas ur trycket och är 0 när den
// står).
function kor(e) {
  return Number.isFinite(e.k415) ? e.k415 === 6 : (Number.isFinite(e.flode) && e.flode > 0);
}

function stoppTitel(namn, e, harKontakt) {
  if (!harKontakt) return namn + ' hörs inte';
  if (e.k415 === 1) return namn + ' står i fel';
  if (e.k415 === 2) return namn + ' har stoppats';
  return namn + ' har stannat';
}

/* live    = /live som bryggan skrev den
   aktiva  = /larmlage/aktiva (larm som pågår, med kvittering)
   minne   = /larmlage/minne (det funktionen behöver komma ihåg mellan körningar)
   nu      = molnets klocka i ms
   Svarar { aktiva, minne, skicka }, där skicka är notiserna att skicka. */
function bedom(live, aktivaIn, minneIn, nu) {
  const aktiva = JSON.parse(JSON.stringify(aktivaIn || {}));
  const minne = JSON.parse(JSON.stringify(minneIn || {}));
  minne.enheter = minne.enheter || {};
  const nya = [], skicka = [];
  live = live || {};
  const meta = live.meta || {};

  const starta = (id, typ, titel, text) => {
    if (aktiva[id]) { aktiva[id].titel = titel; aktiva[id].text = text; return; }
    aktiva[id] = { typ, titel, text, sedan: nu, skickad: nu };
    nya.push(id);
  };
  const avsluta = (id, titel, text) => {
    if (!aktiva[id]) return;
    delete aktiva[id];
    // Samma tagg som larmet: notisen på telefonen byts ut i stället för att
    // en till läggs till. Tyst, ingen ska väckas av att något blev bra.
    skicka.push({ tag: id, titel, text, tyst: true });
  };

  // --- Bryggan ---
  const farsk = Number.isFinite(meta.ts) && nu - meta.ts < GRANS.tyst;
  if (!farsk) {
    starta('brygga', 'brygga', 'Bryggan är tyst',
      (Number.isFinite(meta.ts) ? 'Inget från styrdatorn sedan ' + klocka(meta.ts) + '.' : 'Inget från styrdatorn.') +
      ' Inga andra larm kommer fram förrän den hörs igen.');
  } else {
    avsluta('brygga', 'Bryggan hörs igen', 'Styrdatorn skickar igen.');
  }

  // Står bryggan är /live gammal. Då bedöms inget annat, varken nya larm
  // eller att larm gått över: gamla värden får inte se ut som nya.
  if (farsk) {
    // --- Styrsystemets databas ---
    if (meta.sqlOk === false) {
      if (!minne.sqlBorta) minne.sqlBorta = nu;
      if (nu - minne.sqlBorta >= GRANS.sqlVanta)
        starta('sql', 'sql', 'Bryggan når inte styrsystemet',
          'Bryggan går men kan inte läsa styrsystemets databas sedan ' + klocka(minne.sqlBorta) + '. Värdena i appen står still.');
    } else {
      delete minne.sqlBorta;
      avsluta('sql', 'Bryggan läser styrsystemet igen', 'Värdena i appen är aktuella igen.');
    }

    // --- Styrsystemet självt (28 november 2026) ---
    // Bryggan går och kan läsa, men styrsystemet skriver inga nya värden.
    // Då är allt i /live gammalt fast hjärtslaget är färskt, och förut kom
    // inget larm alls: kanonerna såg ut att köra i all evighet.
    // Bara med bryggans eget mått (meta.gssAlder, sekunder, från version 13).
    // Det är räknat på styrdatorns egen klocka. Att jämföra gssTid med
    // molnets klocka skulle larma alla om styrdatorns klocka går fel.
    const gssStar = meta.sqlOk !== false && Number.isFinite(meta.gssAlder) && meta.gssAlder * 1000 >= GRANS.gssStar;
    if (gssStar) {
      starta('gss', 'gss', 'Styrsystemet står',
        'Bryggan går, men styrsystemet har inte skrivit nya värden sedan ' + klocka(meta.ts - meta.gssAlder * 1000) +
        '. Värdena i appen står still, och inga kanonlarm kommer fram förrän det skriver igen.');
    } else if (meta.sqlOk !== false) {
      avsluta('gss', 'Styrsystemet skriver igen', 'Värdena i appen är aktuella igen.');
    }

    // --- Kanoner och lansar ---
    // Går inte att läsa databasen, eller står styrsystemet, är också
    // enheternas värden gamla.
    if (meta.sqlOk !== false && !gssStar) {
      const gss = naiv(meta.gssTid);
      for (const [key, e] of Object.entries(live.enheter || {})) {
        if (!e || BORTTAGEN.test(key)) continue;
        const m = minne.enheter[key] = minne.enheter[key] || {};
        const hord = naiv(e.senastHord);
        const harKontakt = gss !== null && hord !== null && Math.abs(gss - hord) < GRANS.kontakt;
        const id = 'enhet-' + key, namn = enhetNamn(key, e);
        if (harKontakt && kor(e)) {
          m.kor = nu;
          delete m.borta;
          avsluta(id, namn + ' kör igen', Number.isFinite(e.brunn) ? 'Brunn ' + e.brunn + '.' : '');
          continue;
        }
        // Slutade köra nyss: börja räkna. En enhet som inte kört på länge
        // får inget borta och larmar aldrig.
        if (!m.borta && m.kor && nu - m.kor <= GRANS.korFonster) m.borta = nu;
        if (!m.borta || nu - m.borta < GRANS.stoppVanta) continue;
        if (aktiva[id] && nu - aktiva[id].sedan >= GRANS.glom) { delete aktiva[id]; continue; }
        if (!aktiva[id] && nu - m.borta >= GRANS.glom) continue;
        const text = [Number.isFinite(e.brunn) ? 'Brunn ' + e.brunn + '.' : '',
          'Körde senast ' + klocka(m.kor || m.borta) + '.',
          harKontakt ? '' : 'Styrsystemet hörde den senast ' + klockaNaiv(e.senastHord) + '.'].filter(Boolean).join(' ');
        starta(id, 'enhet', stoppTitel(namn, e, harKontakt), text);
      }
    }

    // --- Nya larm i styrsystemet ---
    // De syns redan under Larm i appen. Här blir de bara en notis när de
    // dyker upp, inga egna larm att kvittera.
    const larm = (Array.isArray(live.larm) ? live.larm : Object.values(live.larm || {}))
      .filter(a => a && a.id && !BORTTAGET_LARM.test(String(a.id)));
    const ids = larm.map(a => String(a.id));
    // larmSedd säger att listan har lästs förut. Det går inte att se på
    // larmKanda: är den tom sparar databasen den inte alls, och då såg "inga
    // larm förra gången" ut som "första körningen" — det första larmet efter
    // en larmfri stund gav ingen notis. (Ett minne från före larmSedd har
    // bara larmKanda, och räknas också som läst.)
    if (minne.larmSedd || minne.larmKanda) {
      const kanda = new Set(minne.larmKanda || []);
      const nyaLarm = larm.filter(a => !kanda.has(String(a.id)));
      if (nyaLarm.length) skicka.push({
        tag: 'styrsystemet',
        titel: nyaLarm.length === 1 ? 'Larm i styrsystemet' : nyaLarm.length + ' larm i styrsystemet',
        text: nyaLarm.map(a => [a.maskin, a.namn].filter(Boolean).join(' ') + ': ' + (a.text || '')).join('\n'),
        tyst: false
      });
    }
    // Ett larm som går över och kommer tillbaka ska höras igen.
    minne.larmKanda = ids;
    minne.larmSedd = true;
  }

  // --- Påminnelse och kvittering ---
  for (const [id, a] of Object.entries(aktiva)) {
    if (nya.includes(id)) continue;
    if (a.kvitt && !a.kvittSkickad) {
      a.kvittSkickad = nu;
      skicka.push({ tag: id, titel: a.titel, text: (a.kvitt.namn || 'Någon') + ' tar det.', tyst: true });
    } else if (!a.kvitt && !a.paminnd && nu - a.sedan >= GRANS.paminn) {
      a.paminnd = nu;
      skicka.push({ tag: id, titel: 'Fortfarande: ' + a.titel, text: a.text + ' Ingen har kvitterat.', tyst: false });
    }
  }

  // --- Nya larm ---
  // Stannar flera kanoner samtidigt (våttemperaturen steg, pumpen stannade)
  // blir det en notis, inte en per kanon.
  if (nya.length === 1) {
    const a = aktiva[nya[0]];
    skicka.push({ tag: nya[0], titel: a.titel, text: a.text, tyst: false });
  } else if (nya.length > 1) {
    skicka.push({ tag: 'flera-' + nu, titel: nya.length + ' larm',
      text: nya.map(id => aktiva[id].titel).join('\n'), tyst: false });
  }

  return { aktiva, minne, skicka };
}

module.exports = { bedom, GRANS, enhetNamn };
