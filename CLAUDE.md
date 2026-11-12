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
  öppna `snowgun-forecast`. Hosting ej bestämd (Firebase Hosting eller internt;
  inte GitHub Pages).

## Hårda regler — får aldrig glömmas

Fullständig motivering i [`docs/arkitektur-och-risker.md`](docs/arkitektur-och-risker.md).
I korthet:

1. **Skriv ALDRIG till SQL.** Läs-only-konto (`db_datareader`), aldrig `sa`.
2. **Läs med `WITH (NOLOCK)`** — våra läsningar får aldrig blockera
   styrprogrammet.
3. **Bara små nulägestabeller.** Tung analys sker mot en återställd kopia av
   backupen, aldrig skarpa databasen.
4. **Bryggan lätt och utåtgående.** Kör på PC:n, öppna aldrig en port in.
   SQL Server Express tog slut på minne en kväll (24 dec 2022) — läs lite.
5. **Lösenord/nycklar aldrig i git.** Se `SECRETS.md` (gitignore-ad).
6. **Firebase-regler låsta:** bara bryggan skriver, bara inloggade läser.
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
- Databaserna är **fyra**: `Live_Snowstar` (nuläge, numrerade kolumner),
  `Live_stat_SQL` (statistik med riktiga kolumnnamn — facit för numren),
  `Live_event_SQL` (larm och händelser) och `Live_Language` (texter).
- Anslutningssträngar och SQL-frågor ligger i **klartext** i programfilerna —
  ingen dekompilering behövdes.
- `*_Main`-tabellerna har `DateUpd` och skrivs var 20:e sekund. Aktiva larm
  finns färdiga i `defaut_actif`.
- Loggarna ligger i `C:\GSSystem\BdD\` (`erreurs.log`, `GSS_Stat_report.log`)
  och `C:\GSSystem\concept\` (`*.rap`), på franska.

## Plan framåt

Se [`docs/plan-brygga-firebase.md`](docs/plan-brygga-firebase.md) och
[`docs/anvandarhantering.md`](docs/anvandarhantering.md). I korthet:

1. Sonden (`probe/db-sond.ps1`) körs en gång på styrdatorn.
2. Kolumnerna mappas hemma mot rapporten och foton av skärmen.
3. Realtime Database, regler, medlemslista och bryggkonto i Firebase.
4. Läs-only SQL-konto och bryggan (PowerShell, schemalagd uppgift) på
   styrdatorn.
5. Appen byter simuleringen mot riktiga värden och läggs på Firebase Hosting.

## Filer

- `app/index.html` — appen, en fil, ingen bygg. Simulerad data tills bryggan
  finns. Skriv aldrig över den i sin helhet när en riktad ändring räcker.
- `probe/` — sonden och skriptet för läs-only-kontot. `db-sond.ps1` **måste
  sparas som UTF-8 med BOM** och får inte innehålla typografiska tankstreck
  eller citattecken — Windows PowerShell 5.1 läser annars filen fel och
  skriptet går inte att köra. Kontrollera efter varje ändring.
- `docs/` — granskningen, arkitekturen, planen, användarhanteringen, idéerna.

## Relation till forecast-repot

Firebase-projektet (`snoprognos`) delas med prognosappen i `snowgun-forecast`,
men driftappen och bryggan bor här. De två apparna har var sin medlemslista
med flit.
