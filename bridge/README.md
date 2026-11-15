# Bryggan

`brygga.ps1` läser nuläget ur styrsystemets databas och lämnar det vidare —
till en fil (torrläge) eller till Firebase. Den läser bara. Den kan inte
starta, stoppa eller ändra något i anläggningen.

**Läget 15 november 2026:** version 0. Skriptet tolkas utan fel och spärrarna
är provade, men det har **aldrig körts mot den riktiga SQL-servern**, och
delen som skickar till Firebase är oprovad (databasen där finns inte än).

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

## Kvar att bygga

- Skriv bara ändringar (dödband), i stället för hela nuläget varje gång.
- Historikpunkter var femte minut för graferna.
- Schemalagd uppgift som startar bryggan vid uppstart.
- Riktiga fältnamn för flöde och driftläge när kolumnerna är hittade
  (`docs\kolumnmappning.md`).
