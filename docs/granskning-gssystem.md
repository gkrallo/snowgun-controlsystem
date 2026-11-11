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
