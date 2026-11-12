# Plan: från styrdatorn till Firebase

Hur livedata ska ta sig från GSSystems databaser till appen, i vilken ordning
vi bygger, och vad som måste vara sant innan varje steg. Hårda regler står i
[`arkitektur-och-risker.md`](arkitektur-och-risker.md); fynden om styrsystemet
i [`granskning-gssystem.md`](granskning-gssystem.md).

Skriven 12 november 2026, efter omgranskningen av `GSSystem.zip`. Allt som
beror på sondrapporten är märkt **(sonden)** — det är antaganden tills
rapporten finns.

---

## Bilden

```
  Styrdatorn                                   Molnet (Firebase, projekt snoprognos)
  ┌────────────────────────────────┐
  │ GSSystem ──► SQL Server Express│
  │   Live_Snowstar   (nuläge)     │
  │   Live_event_SQL  (larm)       │           Realtime Database
  │   Live_stat_SQL   (statistik)  │            /live   nuläge (skrivs över)
  │            ▲ SELECT, NOLOCK    │            /hist   5-minuterspunkter, 48 h
  │       ┌────┴────┐  var 20 s    │            /members  vilka som får läsa
  │       │ Bryggan │──────────────┼─ HTTPS ──►
  │       └─────────┘  bara utåt   │           Auth (Google för människor,
  └────────────────────────────────┘                 eget konto för bryggan)
                                                        │
                                                        ▼
                                               Appen (snow.pettersson.app)
```

## Bryggan

**Ett PowerShell-skript, inget att installera.** Styrdatorn har redan det som
behövs: PowerShell, .NET:s `SqlClient` (samma som sonden använder) och HTTPS.
Varje installation på den datorn är en risk mot styrsystemet, så vi lägger
inte dit Python eller Node om vi slipper. **(sonden)** bekräftar
PowerShell-version och att TLS 1.2 fungerar; gör det inte det blir bryggan en
liten .NET-konsolapp i stället.

**Vad den läser.** GSSystem skriver själv nuläget var 20:e sekund, så tätare
än så finns inget att hämta.

| Vad | Var (enligt programfilerna) | Hur |
|---|---|---|
| Nuläge per kanon/lans | `Live_Snowstar`: `SGC300_Main`, `SGC400_Main` m.fl. | `WHERE DateUpd > förra läsningen` — GSSystem läser själv så, och då hämtas bara rader som ändrats |
| Summa vattenflöde, antal i drift/i fel | `Live_Snowstar`: `Set up installation` (kolumn 11, 8, 9) | en rad |
| Pumphus, tryck, uppmätt flöde, magasinsnivå | `Live_Snowstar`: `Water departure_Main` | en rad per avgång |
| Väderstationen | `TH_Main`, `Wind_Main` | en rad per givare |
| Aktiva larm | `defaut_actif WHERE def_actif = 1` (troligen i `Live_event_SQL`) | liten tabell |
| Händelser | `Journal`, de tio senaste (troligen samma databas) | `TOP 10 … ORDER BY date DESC` |
| Apparatlista och namn | `Gun`, `Com port_Main` | läses vid start, sedan en gång i timmen |

Exakt vilka kolumner som är vad avgörs av **(sonden)**. Statistikdatabasens
tabeller har riktiga kolumnnamn (`debit_eau_reel`, `temperature_humide`,
`niveau_lac` …) och fylls ur samma numrerade kolumner, så de fungerar som
facit när kolumnerna ska mappas.

**Vad den aldrig gör:** skriver till SQL, läser de stora statistiktabellerna
utan datumindex, öppnar en port, tar emot något utifrån.

**Vad den skriver.** Bara ändringar, med dödband (flöde ±0,2 m³/h, temperatur
±0,1 °C), plus ett hjärtslag en gång i minuten. Var femte minut en punkt till
`/hist` för graferna; punkter äldre än 48 h tas bort.

```
/live/meta      { ts: <molnets klocka>, sqlOk: true, version: "1" }
/live/total     { flow: 61.9, running: 6, fault: 0 }
/live/units/K1  { state: "run", flow: 12.0, tw: -6.4, ts: … }
/live/pump      { flowMeasured: …, pressure: …, level: … }
/live/weather   { t: …, rh: …, tw: … }
/live/alarms/<id> { text: "…", since: … }
/hist/flow/<yyyyMMddHHmm>  61.9
/hist/tw/<yyyyMMddHHmm>    -6.4
```

Hjärtslaget stämplas med **molnets** klocka (`{".sv":"timestamp"}`), inte
styrdatorns. Då kan appen avgöra om datan är gammal även om styrdatorns klocka
går fel eller hoppar vid sommartid — och GSSystems egen watchdog visar att just
den natten är känslig.

**Inloggningen.** Bryggan loggar in som ett eget Firebase-konto
(e-post och lösenord) och får skriva till `/live` och `/hist`, inget annat. Vi
använder *inte* en servicekonto-nyckel: en sådan ger full makt över hela
Firebase-projektet, och den skulle ligga på en dator som står i ett garage.
Läcker bryggans lösenord kan någon som mest skriva falska mätvärden — illa
nog, men det går att stänga av med ett klick och rör varken snödjupsdatan
eller medlemslistan.

Lösenorden (SQL-kontot `snogrupp_ro` och bryggkontot) sparas på styrdatorn
krypterade med Windows egen DPAPI, så de bara går att läsa av det Windows-konto
som bryggan körs under. Aldrig i klartext, aldrig i git.

**Drift.** Schemalagd uppgift som startar vid uppstart och startas om om den
dör. Loggar till en liten fil som roterar. Ett "torrläge" skriver till en fil
i stället för till molnet — det kör vi först.

## När något går fel

| Händelse | Vad som syns i appen |
|---|---|
| Bryggan har dött eller nätet är nere | Hjärtslaget åldras; efter 90 s byter stämpeln till "Gammal data · senast 20:41" |
| SQL Server svarar inte | `sqlOk: false` i hjärtslaget; appen visar "Styrdatorn nås, men databasen svarar inte" |
| GSSystem är avstängt | Värdena står still men hjärtslaget går; appen visar när värdena senast ändrades |
| Styrdatorn startas om | Bryggan startar själv; lucka i grafen |
| Styrdatorns klocka fel / sommartid | Påverkar inte gammal-data-varningen (molnets klocka) |
| Minnesbrist i SQL Server (som 24 dec 2022) | Bryggans frågor får timeout; den backar till en läsning i minuten tills det gått över |

## Stegen

**0. Sonden (ett besök).** Kör `probe/db-sond.ps1`, fota skärmen när något
går. Ger: PowerShell-version, TLS, minne, alla tabeller och kolumner i de
fyra databaserna, smakprov, loggarna. *Klart när:* rapporten ligger hemma.

**1. Mappning (hemma).** Para ihop kolumnerna med foton och med
statistiktabellernas namn. Skriv in det i `docs/`. Vill vi prova bryggan utan
att åka dit går `BdD\Live_Snowstar.dat` (en vanlig SQL-backup) att återställa
i SQL Server Express hemma — men bara den databasen finns i zip-filen.
*Klart när:* vi kan säga vilken kolumn som är flöde, våttemperatur och läge
för kanon 1.

**2. Firebase (hemma, i konsolen).**
- Skapa Realtime Database. Den finns inte i europe-north1; närmast är
  europe-west1 (Belgien).
- Lägg in reglerna ur [`anvandarhantering.md`](anvandarhantering.md) och prova
  dem i regelsimulatorn.
- Skapa bryggkontot, lägg in första medlemmen.
- Budgetlarm i Google Cloud.

*Klart när:* en inloggad medlem kan läsa `/live`, en inloggad icke-medlem
inte, och ingen utom bryggkontot kan skriva.

**3. Bryggan (ett besök).** Skapa läs-only-kontot
(`probe/skapa-lasonly-konto.sql`), lägg dit bryggan, kör i torrläge en stund,
jämför med skärmen, slå på. *Klart när:* `/live` uppdateras och stämmer med
kontrollrumsskärmen, och bryggan överlever en omstart av datorn.

**4. Appen.** Byt simuleringen mot riktiga läsningar (`onValue`), riktig
inloggning, lägg ut på Firebase Hosting med `snow.pettersson.app`. API-nyckelns
webbplatslista i Google Cloud måste få den nya adressen — annars fungerar
varken inloggning eller databas. *Klart när:* appen visar samma siffror som
kontrollrummet, på telefonen, hemifrån.

**5. Senare.** Egna larm med pushnotis, historik per säsong, rådgivaren på
riktiga värden.

## Kostnad

Realtime Database tar betalt för lagring och nedladdad mängd, inte per läsning.
Nuläget är några kilobyte och historiken ett par hundra kilobyte. Med
skriv-vid-ändring och en handfull användare ligger det långt under
gratisgränserna (1 GB lagrat, 10 GB nedladdat i månaden). Budgetlarmet finns
för att en bugg som skriver i en slinga ska märkas.

## Öppna frågor

1. Vilka kolumner är vad — **(sonden)**.
2. Visar `Water departure_Main` verkligen magasinsnivån (`niveau_lac`) på vår
   anläggning, eller saknas givaren? Finns den kan Damm-koll kalibrera sig
   själv i stället för med måttband.
3. Vilka apparater är `SGC300` och vilka `SGC400`? Loggarna visar sju
   SGC400 (adress 3–9) som startas och stoppas 2021–2026 och fyra SGC300
   (adress 1–4) med enstaka rader. Det stämmer inte självklart med sex kanoner
   och två lansar — **(sonden)** visar apparatlistan.
4. Samma Firebase-projekt som prognosappen, eller ett eget? Samma är enklast
   (inloggning och nyckel finns), och reglerna håller isär datan. Ett eget
   projekt ger vattentäta skott men dubbel administration. Förslag: samma.
