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
