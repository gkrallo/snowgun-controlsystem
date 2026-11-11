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
   Gammal, minnesansträngd maskin.
5. **Lösenord/nycklar aldrig i git.** Se `SECRETS.md` (gitignore-ad).
6. **Firebase-regler låsta:** bara bryggan skriver, bara inloggade läser.
7. **Tidsstämpel på allt** — appen varnar för gammal data, visar aldrig stale
   som live.
8. **Bryggan auto-startar** vid omboot. **Budgetlarm** i Google Cloud, skriv
   bara vid ändring.

## Vad vi vet hittills

Se [`docs/granskning-gssystem.md`](docs/granskning-gssystem.md) för helheten.
I korthet:

- GSSystem är ett VB6-program (v7.2.14, site `LIDKOPING2`) som pratar **Modbus**
  över seriell COM-port mot kanoner/lansar och lagrar allt i en lokal
  **Microsoft SQL Server (SQLEXPRESS)**-databas `Live_Snowstar` på
  kontrollrums-PC:n.
- Anslutningssträngar och tabellnamn låg i **klartext** i `GSSystem.exe` — ingen
  dekompilering behövdes.
- Namngivna, direkt läsbara tabeller: `stat_piste_canon_y` (kanonstatus, flöden,
  våttemperatur), `alarms_techno` (larm), `TH_Main`/`Wind_Main` (väder, troligen
  brunn 7-stationen). Apparattabeller som `SGC300_Main`/`SGC400_Main` har
  numrerade kolumner och måste mappas mot kontrollrumsskärmen.

## Plan framåt

1. Bekräfta om SQL Server bara lyssnar lokalt eller på nätverket.
2. Skapa ett eget läs-only SQL-konto (`db_datareader`), inte det inbyggda.
3. Bryggtjänst (Python/Node) på kontrollrums-PC:n som pollar och skriver till
   Firestore i `snoprognos`-projektet.
4. Appen läser Firestore i realtid (`onSnapshot`).

## Relation till forecast-repot

Firebase-projektet (`snoprognos`) och appen som ska visa datan ligger i
`snowgun-forecast`. Det här repot är kunskaps- och verktygssidan av samma
arbete — brygg-koden kommer troligen att bo här.
