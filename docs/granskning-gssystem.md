# Granskning av GSSystem.zip — väg till livedata i Snöprognos-appen

> **Lösenord finns inte i den här filen med flit.** De SQL-inloggningar som
> hittades i programmet hålls utanför git (se `SECRETS.md`, som är
> `.gitignore`-ad). Så slipper de ligga i git-historiken även om repot
> någon gång delas.

## Vad mappen är

`GSSystem` är styrsystemets egen klientapplikation (tillverkad av Sufag/MND,
heter **GSSystem**, version 7.2.14 enligt loggarna, site-namn `LIDKOPING2`).
Det är ett Visual Basic 6-program från tidigt 2000-tal, senare utökat med
några .NET-verktyg. `ConnectSufag.exe` är bara ett installationsarkiv
(NSIS), inte en egen fjärranslutningstjänst. `SnowSetupTools.exe` (167 MB) är
troligen hela installationspaketet (SQL Server-komponenter m.m.) — inte
uppackat, det behövs inte för det här.

`arf_stand_alone_configuration_manager_v-2-2-7.msi` i roten av den
nedladdade zip-filen hör sannolikt inte till GSSystem alls (namnet matchar
inget i GSSystem-mappen) — troligen ett verktyg för kopieringsskyddet
(HASP-dongeln, se nedan) eller något annat program som råkade ligga i samma
temp-mapp. Inte undersökt närmare.

## Arkitekturen, i korthet

```
Kanon/lans (fläktstyrning)  --Modbus RTU, seriellt (COM-port)-->  GSSystem (Server1.exe .. Server8.exe)
                                                                        |
                                                                        v
                                                        Microsoft SQL Server (SQLEXPRESS, lokalt på kontrollrums-PC:n)
                                                        databas: Live_Snowstar  (även Live_Event_SQL, Live_stat_SQL, Live_Language)
                                                                        ^
                                                                        |
                                                        GSSystem.exe (skärmbilden du ser i kontrollrummet)
```

- **Server1.exe–Server8.exe** (en process per site/anläggning, "_std"-varianter
  är troligen en äldre/enklare variant) pratar Modbus mot kanonerna
  ("Start Gun SUFAG MODBUS2", "MODBUS1_RD/WR", "MODBUS5") över seriell
  COM-port, och skriver resultatet till SQL-databasen.
- **GSSystem.exe** är själva skärmbilden i kontrollrummet. Den läser och
  skriver mot samma databas.
- Allt ligger i en **vanlig Microsoft SQL Server**-instans, inte något
  proprietärt protokoll som är svårt att komma åt. Det är den enklaste
  sortens system att läsa av utifrån.
- Programmet är kopieringsskyddat med en **HASP/Sentinel-dongel**
  (`haspdinst.exe`, `hasp_com_windows.dll`). Det skyddet gäller själva
  GSSystem-programmet, inte databasen — att läsa SQL-databasen direkt
  påverkas inte av dongeln.

## Databasen — det viktiga fyndet

I `GSSystem.exe` (och flera av Server-exe:arna) ligger anslutningssträngarna
till SQL Server hårdkodade i klartext. Formen ser ut så här (lösenord
ersatta med platshållare — riktiga värden i `SECRETS.md`):

```
Provider=SQLOLEDB;Data source=127.0.0.1\SQLEXPRESS,1433;
UID=GSS_Login;PWD=<GSS_LOGIN_LÖSEN>;Initial Catalog=Live_Snowstar;
```

Det finns även en mer priviligierad inloggning (`sa` = systemadministratör
på hela SQL Server-instansen, `PWD=<SA_LÖSEN>`). Den ska inte användas av
vår egen kod.

**Det här är exakt den öppning som behövs.** Databasen heter `Live_Snowstar`
och ligger på kontrollrums-PC:n (`127.0.0.1\SQLEXPRESS` — dvs. bara nåbar
från den datorn själv, eller från nätverket om SQL Server är konfigurerad
att lyssna på nätverket också, vilket är vanligt för SQLEXPRESS med namngiven
instans).

Praktiskt: ett litet program som körs **på kontrollrums-PC:n** (eller en
annan dator i samma nätverk) kan koppla upp sig mot den databasen, läsa av
de senaste raderna var 10–30:e sekund, och skicka dem vidare till Firebase
(Firestore eller Realtime Database) över internet. Det kräver ingen ändring
i GSSystem och ingen inloggning hos tillverkaren.

**Rekommendation innan ni börjar:** skapa ett eget, nytt SQL-konto med
enbart läsrättighet (`db_datareader` på `Live_Snowstar`), i stället för att
återanvända `GSS_Login` i vår kod — och använd aldrig `sa`. Det inbyggda
kontot är känt av vem som helst som packar upp programmet, så det bör på
sikt bytas av den som sköter kontrollrums-PC:n. Men det är inget som måste
göras innan man kommer igång.

## Tabellerna — vad som faktiskt går att läsa

Databasen är gammal och migrerad från Access, så många tabeller har
**numrerade kolumner** (`[0]`, `[1]`, `[88]` osv.) i stället för namn — det
går inte att gissa sig till vad varje nummer betyder utan att jämföra mot
skärmen i kontrollrummet. Några tabeller har dock **meningsfulla
kolumnnamn** och är en mycket bättre startpunkt:

| Tabell | Innehåll (utläst av kolumnnamnen) |
|---|---|
| `stat_piste_canon_y` | En rad per kanon: `num_canon`, `etat` (status/läge), `debit_eau` (vattenflöde), `debit_air` (luftflöde), `temperature_humide` (våttemperatur ×10) |
| `alarms_techno` | Larmkoder och larmtexter (kopplad till en textfil `alarms_techno.txt` som inte fanns med i zip-filen) |
| `campagne` | Säsonger, med pris/timtaxor |
| `bilan_exploitation` / `bilan_financier` (+ `_SDM`) | Säsongssammanställningar (drifttimmar, vattenförbrukning, kostnad) |

Tabeller med numrerade kolumner, en per apparattyp (namnen avslöjar vilken
utrustning det gäller):

- `SGC300_Main` / `SGC300_Com` — troligen fläktkanonerna (Sufag Super
  Access/MND Snow)
- `SGC400_Main` / `SGC400_Com` — dyker upp i felloggen som `SGC400_Log`,
  troligen lansarna (MND Taurus)
- `SGC600_Main`, `SGC850_Main`, `TestSGC850_Main` — andra apparattyper/test
- `Lenko_Main`, `Line_Main` — okänt ännu, troligen ledningar/sektioner
- `TH_Main` — temperatur/fukt, troligen **väderstationen på brunn 7** som
  snowgun-forecast-repots CLAUDE.md redan varnar för (vindmätaren där är
  opålitlig — stämmer med att vindvärdet i appen redan hämtas från prognosen)
- `Wind_Main` — vindsensor
- `Water departure_Main`, `Air departure_Main`, `Air pressure_Main`,
  `Cooling tower_Main` — vatten-/lufttryck, pumpstatus
- `Com port_Main` — vilken COM-port/adress varje apparat sitter på
- `Shelter` — abri/manöverskåp, troligen även larm för dessa
- `Active windows`, `Set up installation` — appens egna UI-inställningar,
  inte driftdata

Det finns alltså redan **exakt de datakällor som efterfrågades**: kanoner,
lans, pumpsystem (vatten-/lufttryck) och väder/larm, i samma databas.

## Omgranskning 12 november 2026 — rättelser och nya fynd

Zip-filen gicks igenom en gång till, den här gången med SQL-frågorna
utplockade ur alla programfilerna. Det ändrar bilden på flera punkter. Där det
här avsnittet säger emot texten ovan gäller det här.

**Databaserna är fyra, inte en.** Alla ligger i samma SQL Server-instans och
nås med samma inloggning:

| Databas | Innehåll | Vem skriver |
|---|---|---|
| `Live_Snowstar` | Nuläget: en `*_Main`-tabell per apparattyp, apparatlistan (`Gun`, `Com port_Main`), anläggningens summor (`Set up installation`), pumphus (`Water departure_Main`) | `Server1.exe`–`Server8.exe` |
| `Live_stat_SQL` | Statistik med **riktiga kolumnnamn**: `stat_piste_canon_sgc300/sgc400/y`, `stat_piste_sonde_th`, `stat_SDM_depart_eau` m.fl. | `GSS_stat_record.exe` |
| `Live_event_SQL` | Händelser och larm, och `*_actuel`-tabellerna som larmlogiken jämför mot | `GSS_stat_record.exe` |
| `Live_Language` | Texter på olika språk — troligen också namnen på de numrerade kolumnerna | — |

Sondens första version tittade bara i `Live_Snowstar`. Den går nu igenom alla.

**Statistiktabellerna är facit för kolumnerna.** `stat_piste_canon_sgc400`
har kolumnerna `temperature`, `humidite`, `temperature_humide`, `pression_eau`,
`debit_eau_reel`, `debit_eau_theorique`, `debit_air_theorique`, `etat`, och
`stat_SDM_depart_eau` har bland annat `debit_eau_mesure`, `niveau_lac`
(magasinsnivå), `debit_disponible` och `debit_autorise`. De fylls ur de
numrerade kolumnerna i `Live_Snowstar`, så genom att jämföra värden går
numren att översätta utan att gissa. (`stat_piste_canon_y`, som den första
granskningen pekade ut, är bara en av flera — och troligen inte vår apparattyp.)

**Det finns en färdig tabell för aktiva larm:** `defaut_actif`, som programmet
läser med `WHERE def_actif = 1 ORDER BY date`. Och en händelselogg, `Journal`.
Larmen behöver alltså inte räknas fram ur statusbitar.

**`*_Main`-tabellerna har en kolumn `DateUpd`.** GSSystem läser dem själv med
`WHERE DateUpd > förra gången`. Bryggan kan göra likadant och hämtar då bara
det som ändrats.

**Nuläget skrivs var 20:e sekund** (syns på tidsstämplarna i `journal.log`).
Tätare än så finns inget att hämta.

**Apparaterna.** Loggarna visar sju `SGC400` (nr 1–7, Modbus-adress 3–9) som
startas och stoppas genom alla säsonger 2021–2026, och fyra `SGC300` (nr 1–4,
adress 1–4) med enstaka rader. Gissningen ovan, "SGC300 = fläktkanoner,
SGC400 = lansar", håller alltså inte — anläggningen har sex kanoner och två
lansar. Vilken apparat som är vilken avgörs av apparatlistan i sondrapporten.

**Minnesbristen var en kväll, inte ett tillstånd.** Alla minnesfel och nästan
alla timeouts i loggarna är från **24 december 2022 mellan 19:16 och 21:16**:
`GSS_Stat_report.log` (4 minnesfel), `SMSController.log` (868 timeouts) och
GSSystems egen logg (17 timeouts) — samma två timmar. SQL Server Express har
ett tak på sitt buffertminne, och den kvällen slog något i det. Efter det
finns inga minnesfel. Bryggan ska ändå väga lätt, men "gammal, minnesansträngd
dator" var en för stark slutsats av en enda kväll.

**Ett annat fel värt att känna till:** 12 februari 2025 loggades 284 rader
`La sous-requête a retourné plusieurs valeurs` för SGC300 nr 5 — en apparat
fanns dubbelt i en tabell, och statistiken för den gick inte att spara på en
och en halv timme. Tillverkarens fel, inte vårt, men det visar att tabellerna
kan innehålla dubbletter. Bryggan får inte anta en rad per apparat.

**Övrigt.** `GSS_STAT_REPORT.exe` har en adress till en tjänst hos
tillverkaren inlagd (`http://213.190.79.2/WSDamage/…`) — styrdatorn kan alltså
redan prata utåt i någon mån. `SMScontroller.exe` skickar SMS och e-post vid
larm; dess tabeller (`Config_SMS_*`, `smtp`, `SmsPort`) innehåller
telefonnummer och lösenord, och sonden visar därför inga rader ur dem.
Loggfilen heter `erreurs.log` och ligger i `C:\GSSystem\BdD\`.

## Vad loggarna avslöjar (två filer, två olika saker)

Kristian plockade fram raderna ur styrdatorns loggar 12 november 2026. De två
felloggarna säger helt olika saker, och det är värt att hålla isär:

**`GSS_Stat_report.log` — minnesbristen (relevant för bryggan).** Här står de
riktiga minnesfelen, från statistik-rapporteringen mot SQL Server:

> `GSS_STAT_REPORT -> Timer1_Tick_1 (5  There is insufficient system memory in resource pool 'internal' to run this query.)`

Samma fel loggas också **på franska** (`Mémoire système insuffisante dans le
pool de ressources 'internal'`, `Mémoire disponible insuffisante dans le pool
de mémoires tampons`) plus `Execution Timeout Expired`. SQL Server-instansen är
alltså fransk-lokaliserad. De exempel vi har är från julen 2022, under drift.
**Detta är skälet till att bryggan måste vara snål** — läs bara små
nulägestabeller, `WITH (NOLOCK)`, inga tunga frågor. Att GSSystems egen
statistik-rapport knäcker SQL Server på minne betyder att en till läsare på
samma instans måste väga lätt.

**`erreurs.log` — programkrascher, INTE minne.** Här står två andra sorters fel,
som vi varken kan eller ska röra (det är tillverkarens VB6-kod):

- `Dépassement de capacité` (franska för *overflow*, VB6-fel 6) i dialog-
  rutinerna (`DialogSGC400`, `DialogModbus`, `Dialog`, `DialogYA`). Elva gånger
  mellan november 2024 och april 2026. En bugg i GSSystem, inte vårt problem.
- `Watchdog général GSSystem, GSSystem0 ne fonctionne plus` följt av
  `Exit GSSystem crashed`. Noterbart: de två vi ser inträffar **30/03/2025
  03:00:00** och **29/03/2026 03:00:00** — exakt sista söndagen i mars, när
  klockan ställs fram till 03. De äldre loggarna (`concept\GSSystem*.tmp`)
  visar samma sak 2020, 2021, 2022 och 2023: varje år, samma natt, samma
  sekund. Watchdog-"kraschen" är alltså en sommartids-artefakt (klockan hoppar
  förbi timmen), inte en minneskrasch. Den enda watchdog-raden som inte faller
  den natten är 30/09/2022 10:50.
- Raderna `(0 : Exit from GSSystem)` är **normala avstängningar**, inte fel.

Sonden (`probe/db-sond.ps1`, avsnitt 0b) söker numera efter alla dessa mönster,
inklusive de franska, och skriver ut fil, rad och datum — så vi ser om något av
det fortfarande pågår när vi väl är vid datorn.

## Hur jag föreslår att ni går vidare

1. **Bekräfta var SQL Server faktiskt sitter.** Logga in på kontrollrums-PC:n
   och kolla om `127.0.0.1\SQLEXPRESS` bara är lokal, eller om SQL Server är
   satt att lyssna på nätverket (TCP/IP aktiverat i SQL Server Configuration
   Manager, brandväggsregel för port 1433 eller SQL Browser på UDP 1434).
   Enklast och säkrast är att köra bryggprogrammet **på samma dator**, så
   slipper man öppna upp SQL Server mot nätverket alls.
2. **Skapa ett läs-bart SQL-konto** för bryggan (se ovan).
3. **Bygg en liten bryggtjänst** (Python eller Node, körs som ett schemalagt
   jobb eller en liten Windows-tjänst på kontrollrums-PC:n):
   - Läser `stat_piste_canon_y` (senaste raden per kanon), `TH_Main`,
     `Wind_Main`, larmrader, var 10–30:e sekund.
   - Skriver resultatet till ett `livedata`-collection i Firestore
     (`snoprognos`-projektet) — t.ex. ett dokument per kanon under
     `livedata/canons/{num_canon}`, ett för väder, ett för larm.
   - Appen (`index.html` i snowgun-forecast-repot) läser av Firestore i
     realtid (`onSnapshot`), precis som redan planeras för barmarksmätningen.
4. **Mappa de numrerade kolumnerna i andra hand.** Börja med de namngivna
   tabellerna — de räcker långt för "kanon igång/stoppad, vattenflöde, larm".
   Vill man senare ha fler fält (t.ex. exakt vattentryck per kanon från
   `SGC300_Main`) är enda praktiska vägen att återställa en kopia av
   databasen på en annan dator (`BdD\Live_Snowstar.dat` är faktiskt en
   **komplett SQL Server-backup**, inte en livefil — går att återställa
   lokalt för att studera schemat utan att röra skarpa systemet) och jämföra
   kolumnvärden mot vad skärmen i kontrollrummet visar för samma apparat.

## Vad som inte är gjort

- Ingen uppkoppling mot någon databas eller något nätverk — allt ovan kommer
  från att läsa textsträngar och filformat i de nedladdade filerna, offline.
- Ingen detaljerad disassemblering/dekompilering (VB6-binärer är besvärliga
  att dekompilera fullt ut); det behövdes inte eftersom anslutningssträngar
  och tabellnamn låg i klartext.
- `SnowSetupTools.exe` och `arf_stand_alone_configuration_manager...msi` är
  inte undersökta närmare.

---
*Granskad 2026-11-11 ur `GSSystem.zip`, nedladdad från temp-mappen på
kontrollrums-PC:n.*
