# snowgun-controlsystem — projektanteckningar

Systersrepo till `snowgun-forecast` (snöprognos-appen). Här samlas allt vi lär
oss om **styrsystemet** (Sufag/MND GSSystem) och arbetet med att exportera
**livedata** därifrån till Firebase.

## Grundregler

- **Privat repo, hålls privat.** Innehåller uppgifter om anläggningens interna
  styrsystem. Får aldrig slås ihop med `snowgun-forecast`, som är publikt via
  GitHub Pages.
- **Riktiga lösenord ligger aldrig i git.** De hör hemma i `SECRETS.md`, som är
  `.gitignore`-ad. I spårbara filer används platshållare som `<GSS_LOGIN_LÖSEN>`.
  Skälet: git-historik är svår att städa i efterhand, och ett privat repo kan
  senare delas eller göras publikt.
- **Svenska i allt** som syns, och i anteckningar — samma som i forecast-repot.
- **Bygg inget som kan styra anläggningen.** Bara läsning. Helst ska
  kontrollrums-PC:n bara skicka ut data, inget öppnas mot internet in.
- Nedladdade programbinärer (`GSSystem/`, `*.exe`, `*.dat`, `*.msi`) checkas
  inte in — de är stora och ägs av tillverkaren. Se `.gitignore`.

## Beslut (2026-11-11)

- **Bara läsning och övervakning** — appen får aldrig styra anläggningen. För
  faktisk styrning finns Google Remote Desktop mot kontrollrums-PC:n.
- **Inloggning krävs** (Firebase Auth). Datan är inte för allmänheten.
- **Egen app, skild från den publika prognosappen.** Koden bor här, isär från
  öppna `snowgun-forecast`. Appen heter Snökoll och ligger på Firebase Hosting,
  **https://snow.pettersson.app** (sedan 17 november 2026). Inte GitHub Pages.

## Läget (17 november 2026)

Hela kedjan går: styrsystemet → bryggan → Firebase → appen, med inloggning.

- **Bryggan** (`bridge/brygga.ps1`, version 12 på styrdatorn sedan 28
  november 11:20, med TT01 vid drift och snökvaliteten per enhet) går på
  styrdatorn som en
  schemalagd uppgift, läser var 20:e sekund och skickar bara ändringar.
  **Den går med `GSS_Login` enligt ett uttalat avsteg** — leverantören har
  inte svarat om `sa`, och utan `sa` går läs-only-kontot inte att skapa. Se
  `bridge/README.md`. Avsteget ska bort så snart `snogrupp_ro` finns.
- **Firebase** (projekt `snoprognos`): Realtime Database
  `snoprognos-default-rtdb` i europe-west1, regler i
  `firebase/database.rules.json`. Bryggan skriver `/live` och `/hist`,
  medlemmar läser, administratörer sköter `/members`. Medlemmar skriver
  dammens avläsningar och kalibreringar under `/damm` (sina egna; sedan 25
  november, provat i emulatorn). `/hist` får en punkt
  var femte minut och sparas hela säsongen (bryggans version 4, 22 november;
  runt 4 MB per säsong). **Appen får aldrig hämta hela `/hist` när den
  öppnas** — det är läsningen som kostar. Den lyssnar på det senaste
  dygnet; längre perioder (3 dygn, vecka, månad, säsong) hämtas en gång när
  man väljer dem över kurvorna (`setHistRange`, `loadHist`) och visas som
  medelvärden, högst 600 punkter. Valet sparas medvetet inte till nästa
  gång appen öppnas. Från bryggans version 5 har varje punkt också `e`:
  luft och våttemperatur för de enheter styrsystemet hört de senaste 15
  minuterna; från version 7 också deras flöde, och punkten har `flodeSum`
  (runt 18 MB per säsong). Lägg inte till fler fält per enhet
  utan att räkna på vad en hämtning av säsongen då kostar.
- **Gamla värden får aldrig se live ut.** Ett kort vars enhet är tyst, eller
  allt när bryggan tystnat, får klassen `old`: streckad kant, nedtonade
  siffror och en klocka med åldern (`agoHTML`). Gult och rött är för larm,
  inte för gammal data. Chippen säger "Hörs"/"Tyst" när läget inte är känt
  — "Kontakt" i blått lästes som att enheten körde — och "Kör" bara när
  läget säger det och enheten hörs just nu. Värden med
  historik går att trycka på (`histAttr`, `openHist`). TT01
  (vattentemperaturen i pumphuset) mäter bara strömmande vatten: står
  pumparna (FT01 under 2 m³/h) blir den grå, med "senast vid drift" under
  skissen (`tt01Rad`, från bryggan 12).
- **Appen** loggar in med Google, visar riktig data och går att installera på
  hemskärmen. Det som saknas i datan visas som saknat, aldrig som påhittade
  siffror: öppna ringar, dyssteg och strypning. Körfönstret är riktig
  prognos (se nedan), och
  dammen är appens egen beräkning. Volymen kommer ur ritningen, men krönet
  och snorkeln är inmätta mot vattenytan (24 november): 100 % är snorkeln,
  3,37 m ≈ 4 110 m³, och varningen ligger 5 cm över den. Måttbandet läses
  bara vid snorkeln, se `docs/damm-matningar.md`. Under 40 cm på måttbandet
  räknas slänten 1:1,3 (`SF_NED`), inte ritningens 1:1,5. Det mättes med
  lådan som flöt 27 november: 120 cm längs duken, och ytan hade sjunkit
  48–50 cm. Avläsningarna av
  vattenmätaren (start, stopp, emellan) förs i appen i stället för i Excel,
  och påfyllningen räknas ur dem. Mätningarna med måttband sparas
  gemensamt. Loggen i Damm-koll visar avläsningar, pumppass och mätningar,
  och varje flik går att ladda ner för Excel. Säg "mätning", inte
  "kalibrering", i det som syns — ordet förvirrade.
- **Körfönstret är inte längre ett exempel** (28 november). Det hämtar
  prognosen från Open-Meteo för spårets mittpunkt, samma punkt och samma
  anrop som Snöprognos, och räknar som Snöprognos (`index.html` där,
  avsnitt 2–7): psykrometrisk våttemperatur, startgräns −2,5 °C för fläkt
  och −4 för lans skjuten nedåt av vattnet, kvalitetslinjen 0,4 °C per steg,
  kapaciteten (`capacity()`), vindgränserna 5 och 9 m/s och sidodriften.
  Ändras räkningen där ska den ändras här också. Provat 28 november:
  gränser, våttemperatur, kapacitet och körfönster blev desamma som i
  Snöprognos. Tvärvinden räknas vid brunnarna där enheterna hörs (värsta
  riktningen inom räckvidden, medianen över enheterna), annars längs hela
  spåret. Kvalitet och vattentemperatur ställs per telefon (`snokollKorf`),
  förval som i Snöprognos (5 och 1,5 °C); TT01 erbjuds bara när pumparna
  går, eftersom vattnet i pumphuset står varmt annars. Prognosen sparas
  aldrig i telefonen: den hämtas när Körfönster eller Översikt öppnas och
  var 30:e minut, och korten blir streckade när den är över två timmar
  gammal. Väderstationen visas bredvid men räknas aldrig in.
- **FT01 (flöde ut) är `dep12/k125`**, utpekad 25 november när pumparna
  startade. Den visade 50–53 % av dammens minskning 24–27 november
  (måttband och flytpunkt). Appen visar den orättad och märkt så. **Räkna
  inte dammens uttag på den** förrän en körning till är mätt med måttband
  vid start och stopp (se `docs/damm-matningar.md`).
- **Kanonernas flöde är räknat, inte mätt** (bryggan 7): "Real water flow"
  = teoretiskt × √(tryck ÷ börtryck), 0 när kanonen står. Det summeras och
  läggs bredvid FT01 (45 % av summan 26 november). Summan var 108–115 % av
  dammens minskning 24–27 november. Teoretiskt flöde står
  kvar när kanonen står och får aldrig summeras. Flödet ligger i `q`, inte
  i `eau` (som bara är ?demo).
- **Dammens uttag dödräknas ur kanonerna** (Kristians beslut 26 november,
  eftersom FT01 troligen inte går att lita på). Bryggan 11 räknar varje
  timmes vatten ur styrsystemets statistik till `/vattenTimme` (nyckel =
  timmens början i UTC); appen drar summan sedan senaste måttbandsmätningen
  (`damDrawnSince`), och nuvarande uttag är summan av `q`. Båda räknas som
  90 % av kanonernas beräknade flöde (`UTTAG_FAKTOR`, sedan 28 november),
  eftersom summan var 108–115 % av dammens minskning 24–27 november.
  Loggen jämför två måttbandsmätningar med det. FT01 används inte förrän
  Kristian felsökt den. Bryggan 11 installerades 28 november och räknade
  hela säsongen bakåt. Timvattnet stämmer med `flodeSum` i `/hist` (1 130 mot
  1 130 m³ under de 35 timmar båda finns). Saknas `/vattenTimme` står dammen
  kvar på senaste mätningen och visas som gammal ("Uttaget saknas sedan
  mätningen").
- **Pushlarm** är utlagda sedan 26 november 16:20 (`docs/forslag-pushlarm.md`,
  "Byggt 26 november"). Läggs ut med `firebase deploy --only functions`.
  Funktionen körs som projektets standardkonto
  (`726097160825-compute@…`), som i det här projektet inte fick några roller
  automatiskt. Det har fått Cloud Build Service Account (bygget), Firebase
  Realtime Database Admin, Firebase Authentication Viewer och Firebase
  Cloud Messaging **API** Admin. Utan dem bygger den inte, eller säger att
  "authentication credentials … are invalid". Rollen som bara heter
  Firebase Cloud Messaging Admin räcker inte: FCM svarade
  `mismatched-credential … cloudmessaging.messages.create denied` och ingen
  notis gick ut (26 november). Svaret på senaste provnotisen står i
  `/larmlage/prov`. En molnfunktion, `vakt` i `functions/`, körs varje minut,
  läser `/live` och skickar notiser via FCM. Logiken i `functions/larm.js`
  provas med `node --test larm.test.js` och ska gå igenom före varje
  utläggning. `functions/` är det enda i repot som kräver npm; appen är
  fortfarande en fil utan bygge. Kräver Blaze (Kristians beslut) och
  nyckeln för webbnotiser i `window.notisNyckel`. Larmen styr ingenting.
- **Snömängden är vatten × 1,5**, uppmätt med pucken på högen vid brunn 5
  (kanon 8) 27 november: 190 ± 15 m³ snö på 133 m³ räknat vatten.
  Styrsystemet räknar med 2,2. Ingen kanon mäter snö. Bryggan 8 summerar bara vattnet, per enhet sedan den kom till
  brunnen (nollas vid byte av brunn, sågtand) och per säsong från 1 augusti,
  i `brygga-state.json`. Vattnet före bryggan 8 läggs till en gång med
  `-Bakat` (version 9) ur styrsystemets statistik per kanon och journalens
  inkopplingar; filen stämplas så att det inte kan räknas dubbelt. Gjort
  26 november, med brunnsdelen rättad av `-BakatBrunn` (version 10): journalens
  text börjar inte med "Appeared" i databasen, och version 9 tappade
  stämpeln vid nästa sparning. Rapporten `bakat_*.txt` på styrdatorn är
  därför också ett spärr — `-Bakat` vägrar om den finns. **`-TaBort` stoppar
  inte en brygga som går**; processen måste avslutas för hand.
  Faktorn står på ett ställe i appen (`SNO_FAKTOR`). Den bygger på en hög
  och en mätning (Kristian valde 1,5 den 28 november), se
  `docs/kolumnmappning.md`.
- **Lamporna** (ringar 1–4, hydrant, kompressor, fläkt …) skickas från
  bryggan 7 som tända bitar och sparas i historiken bara när de ändras.
  Sonden version 3 (28 november) gav Sufags namn på varje kolumn. Det äldre
  kortets lampor är därför säkra och visas med namn. SGC400 har bara namn på
  orden ("Mot Etat 1–2" …), inte på bitarna. 453 bit 11 och 12 är två
  vattensteg, tolkade ur flödet och märkta "?". Bit 0 och 1, som förut
  visades som ring 1 och 2, är tända hela tiden kanonen går. Lägg in en
  lampa i `LAMPOR` först när den jämförts med skärmen eller Sufags
  beskrivningar, aldrig ur en gissning utan märkning. Snökvaliteten och
  start-/stoppgränsen per enhet kommer med bryggan 12 (kanonerna på 5 och
  −2,5/−2, lansarna −3/−2,5 och Lans 7 på kvalitet 4, den 28 november).
- **Väderstationen vid brunn 7 visar för varmt**, 0,3–1,7 grader och
  ojämnt, medan fukten i luften stämmer (jämfört med kanon 3 vid samma
  brunn 25 november). Troligen uppvärmd givare, inte en offset — lägg
  ingen fast rättning på den. Detaljer i `docs/kolumnmappning.md`.
- **Enheterna heter efter Modbus-adressen** ("Kanon 4", "Lans 6"), som
  styrsystemets skärm visar och snögruppen säger. Adress = n° + 2 på SGC400,
  = n° på det äldre kortet. Brunnen ("Shelter") skickas från bryggans
  version 6 och placerar enheterna på kartan. Läget (kolumn 415: 6 kör,
  1 fel, 2 stoppad, 11 OK) visas bara när enheten hörs — en urkopplad enhet
  behåller sitt sista läge. Det äldre kortet saknar läget och räknas som
  körande när vatten går. **Kanonen på adress 2
  finns inte längre** men står kvar i styrsystemets databas med flit; appen
  hoppar över den och dess gamla larm.
- **Inte gjort:** svar från leverantören och läs-only-kontot; faktorn för
  FT01; prova en omstart av styrdatorn; backup av styrdatorn.

## Adresser, och var en ny måste läggas in

- `https://snow.pettersson.app` — den adress folk ska använda. Domänen ligger
  hos Cloudflare: CNAME `snow` → `snoprognos.web.app`, **grått moln**.
- `https://snoprognos.firebaseapp.com` — fungerar fortfarande, och **bryggan
  använder den som `referer`** för att få logga in. Ta aldrig bort den ur
  API-nyckelns lista.
- `https://snoprognos.web.app` — visar sidan men inloggningen fungerar inte
  där (står inte i API-nyckelns lista). Använd den inte.
- `http://localhost:8000` — lokalt prov. Måste vara just port 8000.

En ny adress måste in på fyra ställen, annars fungerar inte inloggningen:
Firebase Hosting, Authentication → Authorized domains, API-nyckelns
webbplatslista och OAuth-klientens adresser i Google Cloud. Stegen står i
`docs/anvandarhantering.md`. Appen väljer inloggningsadress efter var den
öppnas (`AUTH_HOST` i `app/index.html`); en ny domän måste läggas till där
också.

## Hårda regler — får aldrig glömmas

Fullständig motivering i [`docs/arkitektur-och-risker.md`](docs/arkitektur-och-risker.md).
I korthet:

1. **Skriv ALDRIG till SQL.** Läs-only-konto (`db_datareader`), aldrig `sa`.
   (Avsteg sedan 16 november: bryggan går med `GSS_Login`, som kan skriva,
   tills läs-only-kontot finns. Skyddet är då att all SQL går genom
   `Read-Sql`, som bara släpper igenom en ensam `SELECT`.)
2. **Läs med `WITH (NOLOCK)`** — våra läsningar får aldrig blockera
   styrprogrammet.
3. **Bara små nulägestabeller.** Tung analys sker mot en återställd kopia av
   backupen, aldrig skarpa databasen.
4. **Bryggan lätt och utåtgående.** Kör på PC:n, öppna aldrig en port in.
   SQL Server Express tog slut på minne en kväll (24 dec 2022) — läs lite.
5. **Lösenord/nycklar aldrig i git.** Se `SECRETS.md` (gitignore-ad).
6. **Firebase-regler låsta:** bara bryggan skriver driftdata, bara inloggade
   medlemmar läser. Undantaget är `/damm`, där medlemmar skriver sina egna
   avläsningar av vattenmätaren och måttbandet (Kristian, 25 november).
   Inget i Firebase kan styra anläggningen.
7. **Tidsstämpel på allt** — appen varnar för gammal data, visar aldrig stale
   som live.
8. **Bryggan auto-startar** vid omboot. **Budgetlarm** i Google Cloud, skriv
   bara vid ändring.
9. **Sikta på 69 m³/h, aldrig 70.** 70 är pumparnas absoluta max — över det
   börjar de slå av och på. Förslag och varningar räknar mot `PUMP_TARGET`
   (69); `PUMP_MAX` (70) visas bara som gränsen. Vattenflöden anges i m³/h.

## Idéer under utredning

Se [`docs/ideer-och-roadmap.md`](docs/ideer-och-roadmap.md). Viktigast att minnas:

- **Vattenfördelnings-rådgivare:** föreslå inställningar per enhet utifrån
  våttemperatur + pumptak, så förbrukningen tajmas. Alltid bara *förslag* —
  människan ställer in i styrsystemet (läs-only-regeln).
- **"Stanna/pulsa vid överskriden förbrukning" bygger vi INTE in.** Det är en
  åtgärd på anläggningen (skrivaccess, säkerhetskritiskt), skilt från
  övervakningen. Styrsystemet stryper troligen redan själv — vi *visar* det.
  Egna larm får notifiera, aldrig styra.
- **Statusrader (fläkt startar→förvärmer→drift) hanteras som tillstånd**, inte
  en ström vi sparar rad för rad. Skriv till Firebase bara vid förändring.

## Vad vi vet hittills

Se [`docs/granskning-gssystem.md`](docs/granskning-gssystem.md) för helheten.
I korthet:

- GSSystem är ett VB6-program (v7.2.14, site `LIDKOPING2`) som pratar **Modbus**
  över seriell COM-port mot kanoner/lansar och lagrar allt i en lokal
  **Microsoft SQL Server (SQLEXPRESS)** på kontrollrums-PC:n.
- Databaserna är **29** (sonden 15 november): `Live_Snowstar` (nuläge,
  numrerade kolumner), `Live_event_SQL` (larm och händelser),
  `Live_Language` (texter), `Live_stat_SQL` och `Live_stat_SQL_rapport`
  (summor och dygnsrapporter) och 24 halvmånadsdatabaser med statistik.
  Vilken kolumn som är vad står i `docs/kolumnmappning.md`.
- **Pumparna sitter i serie:** P1 (`dep11`) är matarpumpen, P2 (`dep12`)
  högtryckspumpen. Deras volymer är samma vatten och får inte läggas ihop.
  Dammens nivå mäts inte.
- Anslutningssträngar och SQL-frågor ligger i **klartext** i programfilerna —
  ingen dekompilering behövdes.
- `*_Main`-tabellerna har `DateUpd` och skrivs var 20:e sekund. Aktiva larm
  finns färdiga i `defaut_actif`.
- Loggarna ligger i `C:\GSSystem\BdD\` (`erreurs.log`, `GSS_Stat_report.log`)
  och `C:\GSSystem\concept\` (`*.rap`), på franska.

## Planen, och hur långt den kommit

Se [`docs/plan-brygga-firebase.md`](docs/plan-brygga-firebase.md) och
[`docs/anvandarhantering.md`](docs/anvandarhantering.md). Stegen 1–3 och 5 är
gjorda; av steg 4 finns bryggan men inte läs-only-kontot:

1. Sonden (`probe/db-sond.ps1`) körs en gång på styrdatorn. *Gjort 15 nov.*
2. Kolumnerna mappas hemma mot rapporten och foton av skärmen. *Det som går
   att se när anläggningen står still är gjort.*
3. Realtime Database, regler, medlemslista och bryggkonto i Firebase. *Gjort.*
4. Läs-only SQL-konto och bryggan (PowerShell, schemalagd uppgift) på
   styrdatorn. *Bryggan går, med `GSS_Login` som avsteg.*
5. Appen byter simuleringen mot riktiga värden och läggs på Firebase Hosting.
   *Gjort.*

## Publicering

Från repots rot, med Firebase-verktyget inloggat:

    firebase deploy --only hosting      (appen, mappen app/)
    firebase deploy --only database     (reglerna)

`firebase.json` ligger i roten, eftersom verktyget inte får peka på en mapp
utanför sin egen. Ändra reglerna i filen och lägg ut dem därifrån, aldrig i
konsolen — nästa utläggning skriver annars över det.

Inget versionsnummer behöver höjas för en ny utgåva av appen: den frågar
servern om sidan ändrats när den kommer fram på skärmen. `VERSION` i
`app/sw.js` höjs bara när `sw.js` eller ikonerna ändras. **Byts en ikon måste
filen byta namn** — under samma namn kommer den gamla bilden tillbaka.

**Startsidan `/` måste ha `no-cache`** i `firebase.json`, inte bara
`**/*.html`. Den installerade appen startar på `./`, som Hosting annars
ger en timmes cache. 26 november startade appen på gammal kod efter en
utläggning (larmkortet saknades) och visade den nya först när man drog
ner sidan. Uppdateringskollen räddar inte det: dess första fråga sparar
bara serverns nuvarande etag och jämför först nästa gång.

Prova lokalt på `http://localhost:8000` (porten står i API-nyckelns lista).
Ingen kan logga in åt användaren i förhandsvisningen; vyerna provas genom
att mata in data med `applyLive(...)` i konsolen. `?demo` i adressen visar
de gamla exempelsiffrorna.

## Filer

- `app/index.html` — appen, en fil, ingen bygg. Skriv aldrig över den i sin
  helhet när en riktad ändring räcker. Riktiga mätvärden får aldrig stå i
  filen: den går att läsa utan inloggning.
- `app/sw.js`, `app/manifest.json`, `app/kanon-*.png` — det som gör appen
  installerbar. `sw.js` sparar aldrig mätvärden och rör inte sidorna under
  `/__/` (Firebases inloggning).
- `app/pist.html` (förslag 1), `app/pist-mobil.html` (förslag 2, med
  uppdrag och pass) och deras manifest — förarvyn för pistmaskinen.
  `app/planering.html` (förslag 3) — när ska vi schakta, pista och spåra,
  efter SLF:s handbok. Klickbara förslag med påhittad data
  (`docs/forslag-forarvy.md`). `app/forslag.html` är startsidan som delas
  med förarna via en förhandslänk i Firebase Hosting. Egna sidor så att
  `index.html` inte behöver röras. Skriver inget till Firebase.
- `bridge/` — bryggan och autostarten. Samma krav på UTF-8 med BOM som
  sonden. `brygga-config.json` och de krypterade lösenorden följer inte med
  till git. `-Sjalvtest` och `-ProvaMoln` ska gå igenom efter varje ändring.
- `firebase/database.rules.json` — reglerna.
- `probe/` — sonden och skriptet för läs-only-kontot. `db-sond.ps1` **måste
  sparas som UTF-8 med BOM** och får inte innehålla typografiska tankstreck
  eller citattecken — Windows PowerShell 5.1 läser annars filen fel och
  skriptet går inte att köra. Kontrollera efter varje ändring.
- `docs/` — granskningen, arkitekturen, planen, användarhanteringen, idéerna.

## Relation till forecast-repot

Firebase-projektet (`snoprognos`) delas med prognosappen i `snowgun-forecast`,
men driftappen och bryggan bor här. De två apparna har var sin medlemslista
med flit.
