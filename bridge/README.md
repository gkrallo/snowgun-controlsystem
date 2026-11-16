# Bryggan

`brygga.ps1` läser nuläget ur styrsystemets databas och lämnar det vidare —
till en fil (torrläge) eller till Firebase. Den läser bara. Den kan inte
starta, stoppa eller ändra något i anläggningen.

**Läget 16 november 2026:** version 3, och **körd på styrdatorn** samma kväll
med `GSS_Login` enligt avsteget nedan. Självtestet gick igenom där, en läsning
tar 29 ms, `-ProvaMoln` stämde, och `-Skicka` lade hela nuläget (97 fält) och
två historikpunkter i Firebase. Autostarten lades upp, gick, och togs sedan
bort igen — bryggan står alltså stilla tills den läggs upp på nytt. Inte
provat: en omstart av datorn, och hur bryggan beter sig när kanonerna går.

Raden `Klart på … ms` efter `-EnGang` räknar med tiden det tar att skriva
lösenordet (10 656 ms första gången). Den riktiga lästiden står som `lasMs`
i hjärtslaget.

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

## Avsteget 16 november 2026: GSS_Login i drift tills vidare

Leverantören har inte svarat om `sa`, och utan `sa` går läs-only-kontot inte
att skapa. Kristian bestämde 16 november att bryggan tills vidare får gå med
`GSS_Login`, med extra försiktighet. Version 3 gör det möjligt, men bara
uttalat:

    .\brygga.ps1 -Skicka -SqlUser GSS_Login -AvstegSkrivkonto
    .\installera-autostart.ps1 -AvstegSkrivkonto

Vad som gäller under avsteget:

- **Skyddet är bara koden.** Kontot *kan* skriva; det som hindrar är att all
  SQL går genom en funktion som bara släpper igenom en ensam `SELECT`. Ändra
  inte i `Read-Snapshot` eller `Read-Sql` utan att köra `-Sjalvtest` och läsa
  ändringen två gånger.
- **Det syns.** Varje start skriver en rad som börjar med `AVSTEG` i
  `brygga.log`, och hjärtslaget i molnet har `meta/skrivkonto: true`.
- **`sa` är aldrig tillåtet i drift**, inte heller med växeln.
- **Avsteget ska bort.** När `snogrupp_ro` finns: spara det kontots lösenord
  med `-SparaLosen sql` och kör `.\installera-autostart.ps1` utan växeln.

Kör i den här ordningen på styrdatorn, och gå inte vidare om ett steg ser
konstigt ut:

1. Packa upp i en egen mapp, till exempel `C:\Snogrupp\bridge` — inte i
   GSSystems mapp.
2. En enda läsning i torrläge (steg 2–4 under Första körningen ovan). Titta
   på `brygga-live.json` och jämför med skärmen. (Raden `Klart på … ms`
   räknar med tiden för att skriva lösenordet och säger inget om läsningen.)
3. Torrläge i några minuter, med GSSystems skärm framme:

       powershell -ExecutionPolicy Bypass -File .\brygga.ps1 -SqlUser GSS_Login -AvstegSkrivkonto

   Skärmen ska bete sig som vanligt. Avsluta med Ctrl+C.
4. Spara lösenorden: `-SparaLosen sql` (GSS_Logins) och `-SparaLosen moln`.
5. `-ProvaMoln` — ska sluta med "Allt stämmer".
6. Skicka på riktigt, i ett öppet fönster, i några minuter:

       powershell -ExecutionPolicy Bypass -File .\brygga.ps1 -Skicka -SqlUser GSS_Login -AvstegSkrivkonto

   I appen ska det stå "bryggan hördes" med klockslag under namnet.
7. Avsluta med Ctrl+C och lägg upp autostarten:

       powershell -ExecutionPolicy Bypass -File .\installera-autostart.ps1 -AvstegSkrivkonto

Stoppa allt: `.\installera-autostart.ps1 -TaBort`, och stäng en brygga som
går i ett fönster med Ctrl+C.

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

## Prova molnet

    powershell -ExecutionPolicy Bypass -File .\brygga.ps1 -ProvaMoln

Loggar in som bryggkontot, skriver ett provvärde under `/live` och `/hist`,
tar bort det igen, och kontrollerar att kontot *inte* kan läsa eller skriva i
medlemslistan eller skriva någon annanstans. Behöver ingen databas och går att
köra på vilken dator som helst — gör det hemma, så att ett fel i nyckel,
lösenord eller regler inte upptäcks först vid styrdatorn. Lösenordet frågas
efter om det inte är sparat med `-SparaLosen moln`.

`brygga-config.json` (kopia av exemplet, följer inte med till git) behöver
raden `referer`. Webbnyckeln är låst till vissa webbadresser i Google Cloud,
och utan raden nekas inloggningen med "Requests from referer <empty> are
blocked". Adressen måste vara en av dem som står i nyckelns lista.

**Läget 16 november 2026:** provet är byggt och felvägarna provade (fel
lösenord, saknad `referer`), från företagsnätet. Kristian körde sedan hela provet med det
riktiga lösenordet: allt stämde.

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
