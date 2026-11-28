# Bryggan

`brygga.ps1` läser nuläget ur styrsystemets databas och lämnar det vidare —
till en fil (torrläge) eller till Firebase. Den läser bara. Den kan inte
starta, stoppa eller ändra något i anläggningen.

**Läget 26 november 2026:** version 10 går på styrdatorn sedan 12:15 med
`GSS_Login` enligt avsteget nedan, som schemalagd uppgift. `-Bakat` är gjord
11:53 och `-BakatBrunn` 12:14: statistikraderna kommer var tionde minut (en
föll bort på kvartsgränsen), journalen går tillbaka till 30 oktober 08:45
och gav 82 inkopplingar. SGC400-3 var senast inkopplad vid en annan brunn
än 10 och räknas vid brunnen från 09:53.

- **Läget 28 november:** version 11 går på styrdatorn sedan förmiddagen
  (Kristian), installerad enligt `LAS-MIG-FORST.txt` i
  `brygga-styrdatorn-2026-11-26-v11.zip`. `/vattenTimme` fick 53 timmar med
  vatten, 1 433 m³ från 30 oktober. Det stämmer med `flodeSum` i `/hist`:
  1 130 mot 1 130 m³ under de 35 timmar båda finns. Kanonerna startade 26/11
  02:00 UTC, inte 25/11 kväll; FT01 visade bara någon m³ då.
- Version 11 räknar kanonernas vatten timme för timme ur styrsystemets
  statistik och skickar det till `/vattenTimme` (nyckel = timmens början i
  UTC, värde m³), för dammens uttag. Första starten räknar hela säsongen,
  sedan var tionde minut från den första timme som kan ha fått nya rader
  (en timme räknas klar 25 minuter efter att den slutat). Läget sparas som
  `timmeFran` i `brygga-state.json`. Ett avbrott tas igen av sig självt,
  eftersom statistiken finns kvar. Kräver att databasreglerna med
  `vattenTimme` är utlagda; annars loggar bryggan felet och går vidare.
- Version 10 rättar brunnsdelen av bakåträkningen (`-BakatBrunn`, en gång).
  Version 9 frågade journalen efter `message LIKE 'Appeared%'` och fick noll
  rader, så alla kanoner räknades som vid sin brunn sedan 1 augusti.
  Säsongen var rätt och rörs inte. Se *Räkna bakåt*.
  Version 9 tappade också stämpeln `bakat` ur `brygga-state.json` vid
  första sparningen efteråt; version 10 behåller den, och bygger upp den ur
  rapporten `bakat_<tid>.txt` när den saknas. `-Bakat` vägrar också om en
  sådan rapport finns.
  Stoppa bryggan med `-TaBort` **och** processen: `-TaBort` tar bara bort
  uppgiften, och en brygga som går hindrar bakåträkningen.
- Version 9 kan fylla på räkneverken med vattnet från före version 8, ur
  styrsystemets statistik (`-Bakat`, en gång). Se *Räkna bakåt*. En läsning tar 25–70 ms, också med alla kanoner igång.
Inte provat: en omstart av datorn.

- Version 8 räknar vattnet per enhet sedan den kom till brunnen
  (`vattenBrunn`, börjar om när brunnen byts) och för säsongen från 1
  augusti (`vattenSasong`). Appen gör snö av det (× 2,2). Räkneverken sparas
  i `brygga-state.json` var femte minut och överlever en omstart; tiden när
  bryggan inte gick räknas inte. **Ta inte bort `brygga-state.json`** — då
  börjar räkneverken om på noll.
- Version 7 skickar flöde och tryck per enhet (`flode`, `flodeTeori`,
  `tryck`, `tryckBor`; se `docs\kolumnmappning.md`), och historiken får
  varje hörd enhets flöde och summan av dem (`flodeSum`) att jämföra med FT01.
  Den skickar också lamporna (ringar, hydrant, kompressor …) som tända bitar
  (`bitar`, `flaggor`); historiken sparar dem bara när de ändras (`b`).
- Version 6 skickar brunnen varje enhet står vid (`brunn`, kolumn 707 på
  SGC400 och 108 på det äldre kortet), som "Shelter" på skärmen Gun
  searching.
- Version 5 sparar också varje enhets luft- och våttemperatur i historiken,
  men bara för enheter som styrsystemet hört de senaste 15 minuterna. En tyst
  enhet blir ett hål i kurvan i stället för sitt gamla värde om och om igen.
- Version 4 sparar historiken hela säsongen; version 3 tog bort punkter
  äldre än 48 timmar.

## Uppdatera bryggan på styrdatorn

Bara `brygga.ps1` byts. `brygga-config.json` och de två
`brygga-hemligt-*.txt` ska ligga kvar — lösenorden är krypterade för just den
datorn och det kontot, och följer inte med i zipfilen.

1. Öppna PowerShell i bryggans mapp och stoppa den gamla:

       powershell -ExecutionPolicy Bypass -File .\installera-autostart.ps1 -TaBort

2. Kopiera den nya `brygga.ps1` över den gamla.
3. Prova den (ingen databas eller lösenord behövs):

       powershell -ExecutionPolicy Bypass -File .\brygga.ps1 -Sjalvtest

4. Lägg upp autostarten igen, med avsteget:

       powershell -ExecutionPolicy Bypass -File .\installera-autostart.ps1 -AvstegSkrivkonto

5. Kontrollera efter en minut:

       powershell -ExecutionPolicy Bypass -File .\installera-autostart.ps1 -Visa

   Loggen ska ha en rad `Bryggan startar (version 10, ...)`.

## Räkna bakåt (`-Bakat`, en gång)

Bryggan 8 började räkna vattnet per kanon 26 november 09:53. `-Bakat`
lägger till det som gjordes innan, ur styrsystemets egen statistik:

- **Säsongen:** `stat_piste_canon_SGC400` och `_SGC300` i
  halvmånadsdatabaserna har varje kanons "Real water flow" (× 10). Raderna
  kommer inte med jämna mellanrum, så varje rad vägs med tiden till nästa
  (`LEAD` i databasen), högst 15 minuter. Bara rader med flöde hämtas.
- **Vid brunnen:** journalens `Appeared … ( adr = 8) to 5` säger när en
  kanon kopplades in vid en brunn. Den första i en obruten följd vid samma
  brunn är när den kom dit. Ingen inkoppling under säsongen: sedan 1 augusti.
  Senast inkopplad vid en annan brunn: okänt, och inget läggs till.

Bryggan måste vara stoppad, och det görs bara en gång (`brygga-state.json`
får en stämpel `bakat`; den gamla filen sparas som `.fore-bakat`). En
rapport hamnar i `bakat_<tid>.txt`. Historikens sågtand (`vb`) fylls inte i
bakåt — kurvan börjar när bryggan 8 startade.

Kör, i bryggans mapp, mellan steg 3 och 4 under *Uppdatera bryggan*:

    powershell -ExecutionPolicy Bypass -File .\brygga.ps1 -Bakat -SqlUser GSS_Login

**Gjort 26 november 11:53:** 249 rader, 283 m³ före 09:53 för alla kanoner
tillsammans, men 0 inkopplingar i journalen. Rättas med `-BakatBrunn`
(version 10): samma statistikrader (vägrar om antalet inte är detsamma som
vid `-Bakat`), journalen med `LIKE '%Appeared%'`, och för varje kanon som
står kvar vid samma brunn dras säsongens tillägg av och tillägget sedan
ankomsten läggs till. Rapporten (`bakatbrunn_<tid>.txt`) visar också hur
tätt statistikraderna kommer och hur många som föll bort på kvartsgränsen,
och hur långt bakåt journalen går.

    powershell -ExecutionPolicy Bypass -File .\brygga.ps1 -BakatBrunn -SqlUser GSS_Login

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
| Historikpunkt för graferna | var femte minut; sparas hela säsongen (sedan version 4, förut 48 h); hörda enheters t och tw sedan version 5, deras flöde och summan sedan version 7 |

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
