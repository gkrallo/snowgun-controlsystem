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

## Val som återstår

- **MapLibre GL** i stället för Leaflet, eftersom bara den kan luta och vrida
  kartan. Den hämtas från cdnjs som Chart.js och Leaflet och sparas av
  service workern efter första gången.
- **Gränserna 20 och 50 cm** för tunt och överskott.
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
