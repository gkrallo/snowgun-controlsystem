# Bryggan

`brygga.ps1` läser nuläget ur styrsystemets databas och lämnar det vidare —
till en fil (torrläge) eller till Firebase. Den läser bara. Den kan inte
starta, stoppa eller ändra något i anläggningen.

**Läget 15 november 2026:** version 1. Skriptet tolkas utan fel, spärrarna är
provade och självtestet av ändringslogiken går igenom. Men det har **aldrig
körts mot den riktiga SQL-servern**, och sändningen till Firebase är oprovad
(databasen där finns inte än).

## Första körningen på styrdatorn

1. Lägg mappen `bridge` på styrdatorn.
2. Öppna PowerShell i mappen och kör en enda läsning med alla råkolumner:

       powershell -ExecutionPolicy Bypass -File .\brygga.ps1 -EnGang -Ra -SqlUser GSS_Login

   Skriv lösenordet när det frågas efter.
3. Titta i `brygga-live.json` och jämför med skärmen. Fota skärmen samtidigt.
4. Hämta uttaget per dygn sedan dammen började fyllas:

       powershell -ExecutionPolicy Bypass -File .\brygga.ps1 -Uttag -Fran 2026-10-25 -SqlUser GSS_Login

5. Ta med `brygga-live.json` och `uttag_….txt` hem.

Bäst är att göra steg 2 och 3 när minst en kanon går — det är då flöde och
driftläge går att hitta bland kolumnerna.

## Varför GSS_Login bara får köra en gång

`GSS_Login` kan skriva och radera i styrsystemets databaser. Skriptet
innehåller bara läsfrågor och vägrar allt annat, men ett konto som kan skriva
ska inte ligga i något som går dygnet runt. Därför kräver skriptet `-EnGang`
eller `-Uttag` med det kontot och skickar aldrig till molnet. För drift
behövs läs-only-kontot (`probe\skapa-lasonly-konto.sql`), som kräver `sa` —
se `docs\mejl-leverantor-2026-11-15.md`.

## Skydd i koden

- All SQL går genom en funktion som bara släpper igenom en ensam `SELECT`.
- Läsningen tar inga lås, väntar högst tre sekunder och ger alltid
  styrsystemet företräde.
- Efter tre fel i rad läser den en gång i minuten i stället för var 20:e
  sekund.
- Lösenord sparas krypterade med Windows DPAPI (`-SparaLosen sql` eller
  `moln`) och går bara att läsa av samma Windows-konto på samma dator.

## Vad som skickas, och hur ofta

Datorn står på dygnet runt, men värdena står still det mesta av året. Bryggan
läser därför var 20:e sekund men skickar bara det som ändrats:

| Vad | När |
|---|---|
| Hela nuläget | vid start och en gång i timmen |
| Ändrade fält | när ett värde gått utanför sitt dödband |
| Hjärtslag (molnets klocka, om databasen svarar, GSSystems senaste tid) | en gång i minuten |
| Historikpunkt för graferna | var femte minut; punkter äldre än 48 h tas bort |

Dödband: temperatur och tryck 0,2, luftfuktighet 2 %, vindfart 0,5 m/s,
riktning 15°. Jämförelsen görs mot det värde som senast *skickades*, så ett
värde kan inte krypa iväg en tiondel i taget utan att det märks.

Svarar inte databasen får värdena i molnet stå kvar, och bara hjärtslaget
säger ifrån. Går nätet ner försöker bryggan igen nästa varv.

`.\brygga.ps1 -Sjalvtest` provar den här logiken med påhittade värden, utan
databas och utan nät. I torrläge står i `brygga.log` vad som *skulle* ha
skickats.

## Autostart

När läs-only-kontot finns och lösenorden är sparade:

    .\brygga.ps1 -SparaLosen sql
    .\brygga.ps1 -SparaLosen moln
    .\installera-autostart.ps1

Det lägger upp en uppgift i Windows schemaläggare som startar bryggan vid
inloggning och försöker igen var femte minut. Går den redan händer inget; har
den dött, eller har datorn startats om, kommer den tillbaka av sig själv.
`-Visa` visar läget och sista raderna i loggen, `-TaBort` tar bort uppgiften.

Uppgiften körs som den Windows-användare som lade upp den, eftersom de
sparade lösenorden bara går att läsa av samma användare. Kör därför båda
stegen inloggad som den användare som GSSystem körs under.

Autostarten är oprovad på styrdatorn.

## Kvar att bygga

- Riktiga fältnamn för flöde och driftläge när kolumnerna är hittade
  (`docs\kolumnmappning.md`).
- Prova sändningen mot Firebase när databasen där är skapad.
