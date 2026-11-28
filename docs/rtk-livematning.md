# Livemätning av snödjup från pistmaskinen (RTK)

Påbörjat 28 november 2026. Snödjupet är snöytan minus barmarken. Snöytan
mäts av en RTK-mottagare på pistmaskinens hyttak varje gång maskinen kör,
och visas i Snökoll för inloggade.

## Beslutat (Kristian, 28 november)

- **All RTK-hantering hör hemma i Snökoll.** Snöprognos förblir en öppen
  prognosapp och ska inte hänvisa till RTK. Fliken Snödjup där (barmarken,
  mätpassguiden, Bluetooth, uppdragen) rörs inte förrän Snökoll har ersatt
  den, och tas sedan bort. Inga nya pass läggs in där under tiden.
- **Barmarken flyttas till Snökoll** och får en källa. Den kan trimmas
  efter säsongen om mätningen blir bättre.
- **En pistmaskin i vinter**, och mottagaren är **pucken** (SparkFun RTK
  Facet, samma som mätte barmarken). Den flyttas till maskinen.
- **Egen basstation vid spåret, ansluten till onocoy.** Inte på plats än.
- **Första byggsteget är sidan Mätprov** (nedan).

## Inte bestämt än

- **Skärmen i hytten.** Förarna har både Android och iPhone, och en iPhone
  kan inte nå pucken från en webbsida (Safari saknar Web Bluetooth).
  Förslaget är en Android som sitter fast i maskinen och sköter mätningen,
  medan förarens egen telefon, också iPhone, tittar i Snökoll. Alternativet
  är att bara förare med Android kan mäta.
- **Var barmarken ska ligga.** Som fil under `app/` (går att läsa utan
  inloggning, som i dag på GitHub Pages) eller i databasen (bara medlemmar).
  Tills det är bestämt läser Mätprov barmarken från Snöprognos, så att den
  finns på ett ställe.
- Grenen `claude/lucid-wu-02ffe1` (förslag 4, gästsidan) är inte ihopslagen.

## Så hänger det ihop

    basen vid spåret → onocoy → pucken hämtar korrektionerna över wifi
    pucken → Bluetooth → skärmen i hytten → Snökoll → Firebase

- **Pucken hämtar korrektionerna själv** (NTRIP-klient över wifi från en
  telefon eller platta som delar nät i hytten). onocoy-uppgifterna finns då
  bara i pucken. De får aldrig stå i appen, i repot eller under `app/`.
- **Loop Back hos onocoy** (kontrollerat mot docs.onocoy.com 28 november):
  stationens egna NTRIP-uppgifter (console.onocoy.com → Reference Stations →
  NTRIP Credentials) används också i pucken, mot `clients.onocoy.com`, port
  2101 (2121 med TLS) och **stationens egen mountpoint**, inte NRBY_ADV.
  Tre samtidiga anslutningar är gratis, och datan får bara användas internt.
  Strömmen kommer först när onocoy godkänt stationens data; hur lång tid
  det tar står inte.
- **Pucken** (SparkFuns äldre RTK Firmware): wifi och Bluetooth går
  samtidigt, upp till fyra sparade nät, BLE väljs under System → Bluetooth
  Protocol. Appen läser NMEA över Nordics UART-tjänst, som Snöprognos gör.
- **Ingen nyckel finns sparad** (28 november): inte i `SECRETS.md`, inte i
  minnet, inte i anteckningarna.

## Referenssystemet — därför Mätprov

Barmarken är efterberäknad mot Swepos fasta koordinater för LIDK
(SWEREF 99, `docs/ppk-lidk.conf` i Snöprognos). Loop Back ger som förval
ITRF2020 vid dagens datum, som ligger decimetrar från SWEREF 99 i sidled
och glider 2–3 cm om året här.

**Kristian valde ETRS89 den 28 november**, under Advanced Settings →
"Reference Frame (Self-streaming)" på stationens NTRIP-uppgifter i onocoys
konsol (beskrivningen där är "LVSK"). SWEREF 99 är Sveriges variant av
ETRS89, så skillnaden mot barmarken bör bli liten, och ramen följer med
marken. Valet påverkar bara de egna mottagarna, inte det andra får från
stationen. I konsolen heter valet **"Europe ETRS89 - ETRF2000 (2010.0
epoch)"**, med rutan Epoch på 2010.0, som är onocoys förval för ramen.
Epoken är inte ändrad för hand och ska inte ändras.

Skillnaden är ändå inte säkert noll. SWEREF 99 är låst vid 1999,5 och
onocoys ram vid 2010,0, och däremellan har marken här höjt sig några
centimeter (landhöjningen; en uppskattning, inte uppmätt). Olika varianter
av ETRS89 skiljer dessutom någon centimeter, och hur pucken räknar sin
antennhöjd i realtid ingår också. Den ska **mätas**, inte antas: pucken med
RTK-fix läggs på punkter som finns i barmarken, och skillnaden blir en fast
förskjutning för säsongen.

**Ändra inte ramen, puckens antenninställningar eller basens koordinater
efter att kontrollpunkterna är mätta.** Görs det ändå måste de mätas om.

## Mätprov (byggt och utlagt 28 november, inte provat med riktig puck)

Vyn `rtk` i `app/index.html`, nås från sidomenyn och från Översikt.
Reglerna och appen lades ut 28 november kväll, reglerna först. Kontrollerat
utifrån: sidan är samma fil som i repot, `/pist` svarar nej utan
inloggning, och barmarken går att hämta från Snöprognos. Ingen har provat
vyn inloggad än.

- **Pucken:** ansluts med Bluetooth (Chrome på Android eller dator). Visar
  läget (RTK-fix, float, ingen korrektion), satelliter, höjdosäkerhet och
  korrektionernas ålder. Tystnar pucken i fem sekunder visas värdena som
  gamla. Skärmen hålls tänd medan pucken är ansluten.
- **Mät en punkt:** 30 sekunder med pucken stilla. Bara värden med RTK-fix
  och höjdosäkerhet under 5 cm räknas (samma regel som i Snöprognos).
  Resultatet jämförs med barmarken i samma ruta och, om en brunn valts, med
  brunnens inmätta läge.
- **Kontrollpunkter:** sparas gemensamt under `/pist/kontroll`. Appen
  sparar det uppmätta (läge, höjd, spridning), inte skillnaden: den räknas
  mot barmarken varje gång, så att en trimmad barmark ger rätt svar.
  Sammanfattningen visar medianen i höjd, norr och öst.
- **Två sorters punkter behövs.** Brunnarnas hörn ligger 0,7–1,7 m utanför
  den mätta marken (fyrhjulingen körde gatans kanter; brunn 1 har ingen
  mätt ruta inom två meter). En punkt vid en brunn ger därför läget i
  sidled, och höjden mäts där fyrhjulingen körde. Bara punkter som ligger i
  en mätt ruta räknas i höjdens median, och rutan Pucken säger "på mätt
  mark" när pucken ligger rätt. Brunn 3, 5, 6, 8, 10, 11 och 12 är osäkert
  inmätta och räknas inte in i sidled. En punkt mer än fem meter från sin
  brunn räknas inte alls (fel brunn vald).
- **Ingen förskjutning läggs på av sig själv.** Den förs in i koden när
  Kristian har bestämt den.
- `?demo` har en låtsaspuck och en påhittad barmark, och sparar bara i
  minnet.

Reglerna: medlemmar läser; var och en lägger till och ändrar sitt eget,
administratörer allt; nyckeln kontrolleras (`firebase/database.rules.json`,
`pist/kontroll`). Prov i `test/app.test.mjs` och `test/regler.test.mjs`.

## Ordningen framåt

1. **Basen till onocoy** (Kristian). Skapa NTRIP-uppgifterna, se att
   stationen syns i konsolen.
2. **Pucken får RTK-fix via Loop Back.** NTRIP-klienten ställs in på
   puckens inställningssida. Kontrollera att fältet för användarnamn finns
   (står inte i SparkFuns manual).
3. **Kontrollpunkter med Mätprov:** minst tre, helst fem, av varje sort.
   För höjden på mätt mark, flackt och med fri himmel. För sidled i hörnet
   mot spåret vid brunn 1, 2, 4, 9 och 13–19, som är bra inmätta.
4. **Datamodell, regler och maskinkonto**, provat med en låtsasmaskin i
   emulatorn. Räkna ut vad en säsong kostar innan något sparas.
5. **Minsta riktiga förarvy**, med förslag 2 (`forslag/pist-mobil.html`)
   som utseende.
6. **Livekarta för medlemmar** i Snökoll.
7. **Sammanfattning till den offentliga sidan** (molnfunktionen skriver,
   aldrig rådata eller positioner).
8. **Barmarken flyttas**, och fliken Snödjup tas bort ur Snöprognos.

## Principer för det som byggs sedan

- **Spara snöytans höjd, räkna djupet vid visning.** Då rättar en trimmad
  barmark också gamla djup.
- **Ett konto per maskin**, som bara får skriva sin egen gren och bara nya
  rader (samma mönster som bryggan mot `/hist`).
- **Aldrig råa positioner flera gånger i sekunden till databasen.** De
  läggs ihop till rutor i enheten och skickas glest. Ingen telefon ska
  lyssna på hela rutnätet; översikten läser en sammanfattning per sträcka.
- **Mätningen sparas i enheten först** och skickas när nätet finns.
- **Gammalt ser gammalt ut:** en sträcka utan fix behåller sitt förra värde
  med åldern utskriven.
- **Föraren ska inte behöva göra något:** en skärm, en knapp, tre lampor
  (pucken, RTK-fix, nät). Mätningen börjar när fixen finns och pausar utan.

## Måste provas ute

- Pucken på hyttaket: den är stänkskyddad (IP53), inte vattentät, och har
  inbyggt batteri. SparkFun anger varken temperaturområde eller om den
  laddar i kyla. Antennen går inte att skilja från mottagaren.
- Lutningen: pucken har ingen lutningsgivare. Med antennen tre meter upp
  flyttar fem graders lutning mätpunkten cirka 25 cm i sidled.
- Träden vid brunn 3–4 och 7, som gav dålig eller falsk fix i
  barmarkspassen.
- Bluetooth och wifi genom hyttaket.
- Antennhöjden på maskinen. I barmarkspassen var pucken på marken
  kalibreringens svaga punkt (±3 cm).
- Trycket "Anslut pucken" krävs varje gång sidan öppnas (Web Bluetooth).
  Om sidan ansluter själv igen efter ett avbrott är inte provat.
