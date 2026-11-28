# Förarvyn för pistmaskinerna

26 november 2026. **Klickbar prototyp, inte utlagd.** Sidan är
`app/pist.html` och nås på `/pist.html`, skild från resten av Snökoll så att
plattan i hytten kan starta rakt dit. All data i den är påhittad utom spåret,
brunnarna och flygbilden. Den skriver ingenting till Firebase och loggar inte
in.

## Bakgrund

Snögruppen får en egen RTK-bas vid Sparbanksspåret, som skickar till onocoy.
Med Loop Back får upp till tre egna mottagare korrektioner gratis. En
mottagare på pistmaskinens hyttak mäter snöytan varje gång maskinen kör, och
snödjupet är snöytan minus den inmätta barmarken. Föraren ser det på en
Android-platta i hytten (iPhone saknar Web Bluetooth).

Beslutat i snöprognossessionen: förarvyn byggs i Snökoll, som redan har
inloggning, medlemslistan och driften från styrsystemet. Snöprognos förblir
publik och en fil utan inloggning; barmarken och spåret läses därifrån.

## Vad prototypen visar

1. **Vyn framåt.** Flygbilden från Esri, vriden efter kursen och lutad som en
   bilnavigator. Spåret är färgat efter snödjupet: rött–gult under 20 cm,
   turkos–blått 20–50 cm, lila över 50 cm (överskott). Ett kort överst säger
   vad som väntar de närmaste 100 m ("Tunt om 35 m, ner till 14 cm"), med en
   liten profil och en varning för slang över spåret. Under maskinen står
   djupet där den står.
2. **Varvet som ett band.** Hela varvet, 2,3 km, utrullat rakt i
   körriktningen (motsols från brunn 14). Djupet som en yta, brunnarna (de
   flesta två gånger, gatan söderut körs åt båda hållen), kanonerna och
   lansarna med sitt läge, fanorna där slangen går över, markeringarna, när
   varje sträcka preparerades, och båda maskinerna.
3. **Driften.** Våttemperatur, luft, fukt och kanonernas givare, vinden ur
   prognosen (stationens vindmätare är inte att lita på), och enheterna i den
   ordning maskinen kommer till dem. Samma tolkning som Snökoll gör av `/live`.
4. **Preparerat.** Det maskinen kört över får klockslaget ("Preparerat
   05:40") och bleknar under ett halvt dygn. Efter ett dygn räknas det som
   opreparerat. Ingen knapp.
5. **Ett tryck på platsen.** Klassiskt spår draget, skejt, tunt, sten/is och
   hinder. Markeringen hamnar där maskinen står, kan ångras i sex sekunder
   och tas bort genom att trycka på den. Den syns för den andra maskinen; i
   prototypen bara mellan flikar i samma webbläsare (`?maskin=2`).

Dessutom: hela varvet uppifrån, nattläge, helskärm, skärmen hålls tänd, och
en egen `pist-manifest.json` så att förarvyn kan installeras som en egen app
("Snökoll Pist") som startar i helskärm.

## Förslag 2, för mobilen (27 november)

`app/pist-mobil.html`, efter Kristians synpunkter på förslag 1. Förslag 1
(`pist.html`) ligger kvar som det var, så att förarna kan jämföra.

- **En maskin**, den röda PistenBully 100 (ritad, utan märkets logga).
- **Överst, kompakt:** djupet under maskinen ihop med de närmaste 100
  metrarna. När djupet under maskinen är fel fylls rutan med färgen och en
  ram lyser runt hela skärmen — tunt pulserar, överskott står stilla. När
  det är bra är rutan mörk: det är förändringen som ska synas i ögonvrån.
- **Inget om kanonerna.** Brunnarna med nummer är kvar, för att hitta i
  mörkret.
- **Tre zoomlägen:** hela spåret (norr uppåt), 3 brunnar och 1 brunn.
  Provat i telefonstorlek längs hela varvet åt båda hållen: i "1 brunn"
  finns alltid minst en brunn i bild (i snitt två), i "3 brunnar" i snitt
  tre. Det krävde att kartan lutar 40 grader; brantare, som en bilnavigator,
  försvann brunnarna i vändslingorna.
- **Kartans riktning.** Mottagaren vet åt vilket håll maskinen rör sig, inte
  vart den pekar, så en backning ser ut som en vändning. Kartan vrids därför
  efter spåret, åt det håll maskinen kört, och byter håll först efter 25 m
  åt andra hållet. Ett tryck på kompassen vänder den direkt. Utanför spåret
  ska den visa norr uppåt (inte byggt, maskinen är alltid på spåret i provet).
- **En markeringsknapp.** Markeringen läggs direkt där maskinen står. Sedan
  öppnas ett ark för en kommentar, som stängs av sig självt efter 20 sekunder
  om ingen rör det. Kommentaren kan talas in (Chromes taligenkänning, som
  skickar ljudet till Google precis som tangentbordets mikrofon), skrivas
  eller väljas bland några snabbord. Listan över markeringar i menyn går att
  kommentera i efterhand.
- **Vädret** som en rad överst: luft, fukt och våttemperatur.
- **Uppdrag** (Kristians idé): Schakta, Pista, Spåra eller Transport, valt
  med ett tryck och kvar tills det byts (efter tolv timmar frågar sidan
  igen). Det maskinen kör över stämplas med uppdraget och klockslaget, så att
  bandet och kartan visar vad som gjordes senast: grönt spårat (med två
  spårfåror på kartan), ljusblått pistat, gult schaktat. Transport stämplar
  ingenting. När uppdraget byts sparas passet och sidan frågar "Hur blev
  det?" (bra, blött, isigt, klumpigt). Passen finns i menyn.

## Förslag 3, planering (27 november)

`app/planering.html`: när ska vi schakta, pista och spåra? Byggd på SLF:s
handbok *Slope Preparation and Grooming* (Davos 2019); sidnumren står vid
varje tumregel i sidan. Allt väder och all snötillverkning är påhittat.

- **Nästa natt överst:** ett råd med skäl, till exempel "Kör i kväll 21–23 —
  klarnar i natt 03, vila 9 h till 08". Reglerna vägs i ordning: mildväder
  som inte fryser (vänta), snöfall (kör när det slutat, var 20:e cm), blöt
  snö som börjar frysa (kör då), annars direkt efter stängning och före det
  klarnar. Minst 8 timmars vila före öppning.
- **Tidslinje för 48 timmar:** moln, råden, luft och våttemperatur,
  nederbörd och när spåret är stängt.
- **Klar att schakta? per brunn:** köldgradtimmar sedan kanonen stannade mot
  ett krav som växer med hur blöt snön blev (våttemperaturen) och hur stor
  högen är. Första gissning: 60 °C·h för en vanlig hög, dubbelt för blöt snö,
  1,6 gånger för en stor hög. En sticktermometer går före modellen (under
  −1 °C är klart). Har högen schaktats ut visas förarens svar bredvid
  modellens, och det är sådana svar som ska rätta gränserna.
- **Tio dygn:** ett kort råd per dag (mildväder, regn, snöfall, stabilt) och
  hur många timmar kanonerna kan gå.
- **Senast gjort:** ur förarvyns pass, i samma webbläsare.

Riktigt ska prognosen hämtas från Open-Meteo som i Snöprognos, men med
`cloud_cover`, `shortwave_radiation`, `precipitation` och `snowfall`, som
prognosappen inte hämtar i dag. Snötillverkningen per brunn kommer från
bryggan (`/vattenTimme`, våttemperaturen i `/hist`), passen och svaren från
förarvyn. Tiderna då spåret är öppet (08–21) är påhittade.

## I efterhand och meddelandet, i förslag 2 (28 november)

- **Skriv in i efterhand** (i menyn och i listan över passen), för när
  GPS:en inte var igång: vad (spåra med klassiskt och/eller skejt, pista,
  schakta), ungefär när (i dag eller i går och ett klockslag) och var
  (hela spåret eller från brunn till brunn). Sträckan visas som en
  tunnelbanekarta i arket och streckad på kartan innan den sparas. Reglerna,
  efter Kristians förslag:
  - brunn 1 ligger i vändslingan i söder: väljs den tas slingan med
  - brunn 17, 18 och 19 ligger i öglan i norr: väljs någon av dem tas hela
    öglan med
  - raksträckan mellan brunn 1 och 16 körs åt båda hållen; båda körfälten
    tas med om man inte väljer "bara söderut" eller "bara norrut"
  - ett klockslag som inte varit än går inte att spara, och mer än ett dygn
    bakåt ger en fråga om dagen stämmer
  - det senaste gäller alltid: där något loggats senare skriver
    inmatningen inte över det, och arket säger hur mycket det gäller
  - det som skrivits in går att ta bort i listan över passen
- **Passen sparar nu sina sträckor** (från, till, när), både de körda och
  de inskrivna. Det är dem gästsidan visar.
- **Meddelande till gästerna:** en fri text (högst 240 tecken, kan talas in)
  som står överst på gästsidan "från snögruppen", med hur länge den ska
  synas: i dag, till i morgon, en vecka eller tills den tas bort. Kristians
  exempel: stängt för snötillverkning, fika på lördag.

## Förslag 4, gästsidan (28 november)

`app/spar.html`: när spåret spårades senast, hur långt som är öppet,
snödjupet, vädret och ett meddelande från snögruppen. Till för klubbens
hemsida och för att länkas från Facebooksidan, där inläggen är svåra att
hitta.

- **Vinterbilden i 3D** (three.js 0.170 från cdnjs): spåret på riktigt,
  marken och granarna tecknade. Spåret lyser starkare ju nyare spårningen är
  (turkos senaste tolv timmarna, blått i går, grått äldre, rött stängt).
  Himlen och ljuset följer solen i Lidköping just nu; `?klocka=21:30` i
  adressen visar kvällsbilden mitt på dagen. Dra åt sidan för att vrida,
  tryck på spåret för att se när den delen spårades.
- **"Se senaste spårningen"** spelar upp den: pistmaskinen kör sträckan,
  spåret blir nytt bakom den och de klassiska spåren syns.
- **Korten:** spårat när (med "ca" om det skrivits in i efterhand), klassiskt
  och skejt, km spårat senaste dygnet, snödjupet med mätdatum, vädret, det
  som är stängt, delarna med namn (förslag: Norra öglan, Långa
  raksträckan, Södra slingan), veckan dag för dag och sponsorerna.
- **Ärligt om åldern:** inget registrerat på två dygn ger "Inget registrerat
  sedan dess. Det kan ha spårats utan att det skrivits in", aldrig "ej
  spårat". Ett meddelande som gått ut visas aldrig.
- **Sponsorer:** "Dagens spår presenteras av", en rad med loggor och skyltar
  vid starten i bilden. Sidan har inga kakor och följer inte besökarna.

Allt är påhittat utom spåret. Det som skrivits in eller körts i förslag 2 i
samma webbläsare kommer med, så att kedjan går att prova.

**Beslut (Kristian, 28 november):** gästsidans uppgifter ligger i en egen,
publik del av Realtime Database, `/publikt`, som alla får läsa men bara
snögruppen skriva. Då beror sidan inte av klubbens hemsida eller någon
annan för att hålla sig uppdaterad. Den innehåller bara det som står på
sidan: spårat när och var, stängda partier, snödjupet, vädret och
meddelandet. Inget från styrsystemet, inga namn och ingen maskin i realtid.
Inte byggt; reglerna skrivs när sidan kopplas in.

Att bestämma: var sidan ska ligga (en egen adress, till exempel under
klubbens domän, eller snow.pettersson.app/spar.html), delarnas namn, och om
föraren ska välja klassiskt/skejt när uppdraget Spåra väljs (nu antas
båda).

## Dela förslagen med förarna

`app/forslag.html` är startsidan, med en knapp per förslag. Den delas med en
**förhandslänk i Firebase Hosting**: en egen adress som inte rör
snow.pettersson.app och slutar gälla av sig själv. Från repots rot, i den
gren där förslagen finns:

    firebase hosting:channel:deploy forslag --expires 30d

Adressen blir ungefär `https://snoprognos--forslag-xxxxxxxx.web.app`, och
länken till förarna är den med `/forslag.html` på slutet. Samma kommando
igen lägger ut ändringar på samma adress. Förslagen loggar inte in, så att
inloggningen inte fungerar på web.app-adresser spelar ingen roll för dem
(Snökoll själv fungerar däremot inte på förhandslänken).

Inte som en artifact på claude.ai: där får sidan troligen inte hämta
flygbilden från Esri, förarna skulle behöva konto för att kommentera, och
hemskärm, tänd skärm och Bluetooth till mottagaren går inte inuti claude.ai.
Synpunkterna tas i gruppen där förarna redan pratar; varje förslag har ett
nummer och ett datum att hänvisa till.

## Val som återstår

- **MapLibre GL** i stället för Leaflet, eftersom bara den kan luta och vrida
  kartan. Den hämtas från cdnjs som Chart.js och Leaflet och sparas av
  service workern efter första gången.
- **Färgskalan och gränserna 20 och 50 cm** för tunt och överskott. Kristian
  återkommer; i sidorna står de på ett ställe (`SKALA`, `TUNT`, `OVERSKOTT`).
- **Markeringarna:** vilka typer, och hur länge de ska synas (nu ett och ett
  halvt dygn).
- **Slangen över spåret** finns inte i styrsystemet. Antingen markerar
  snögruppen den i Snökoll när slangen dras, eller så räknas den som en
  vanlig markering.
- Om förarvyn ska ha en egen medlemslista (förarna) eller använda Snökolls.

## Inkopplingen (inte gjord)

1. **Positionen.** Mottagaren skickar NMEA över Bluetooth LE med Nordic UART,
   som pucken i Snöprognos (tjänst `6e400001-b5a3-f393-e0a9-e50e24dcca9e`).
   Korrektionerna går från basen via onocoy direkt till mottagaren; nyckeln
   hör hemma i mottagaren, aldrig i koden.
2. **Snödjupet.** Snöytan = antennens höjd minus antennhöjden, rättad för
   lutningen. Antennen sitter ungefär 3 m upp: en grads lutning flyttar den
   5 cm i sidled, och i en backe blir det ett höjdfel. Barmarken slås upp i
   `barmark.json` (en meters rutor, origo vid brunn 7, samma formler som i
   Snöprognos). Basen måste först knytas till Swepos-stationen LIDK, som
   barmarken bygger på — det görs i snöprognossessionen.
3. **Delningen.** `/pist/maskiner/{maskin}` (läge, kurs, fix, tid, högst en
   gång i sekunden), djupet per ruta när det ändrats, och
   `/pist/markeringar/{id}`. Kräver nya regler i
   `firebase/database.rules.json`: bara medlemmar, var och en skriver sitt.
4. **Driften.** `/live`, som Snökoll redan lyssnar på, med samma inloggning.

## Prova senare, på riktigt

- Maskinens lutning och antennhöjden, mot bar mark intill snön.
- Plattan i mörker: ljusstyrka, nattläget, och om knapparna går att träffa
  med handskar när maskinen skakar.
