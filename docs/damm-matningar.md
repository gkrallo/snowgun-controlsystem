# Dammen — mätningar på plats

Det här är facit som Damm-kollens modell ska stämma mot. Skriv in nya
avläsningar längst ner i tabellen; räkna inte om gamla.

## Vattenmätaren på påfyllningen

*Sedan 25 november förs avläsningarna i appen (Damm-koll → Vattenmätaren),
inte i Excel. Tabellen nedan är de fyra första. De läggs in i appen en gång,
och därifrån går de att ladda ner som en fil för Excel.*

| Datum      | Tid   | Mätarställning (m³) | Påfyllt sedan 25/10 (m³) | Takt sedan förra (m³/h) | m³/dygn |
|------------|-------|---------------------|--------------------------|-------------------------|---------|
| 2026-10-25 | 17:00 | 69 418,963          | 0                        | –                       | –       |
| 2026-11-01 | 13:23 | 70 884,112          | 1 465,149                | 8,91                    | 213,9   |
| 2026-11-08 | 14:56 | 72 400,0            | 2 981,057                | 8,94                    | 214,6   |
| 2026-11-13 | 15:29 | 73 478,4            | 4 059,437                | 8,95                    | 214,7   |

Hela perioden: 4 059 m³ på 454,5 timmar = 8,93 m³/h = **214 m³/dygn**.
Takten är jämn inom en halv procent mellan avläsningarna, så pumpen har gått
utan avbrott och appens förval (213 m³/dygn) stämmer.

(8 november: 72 400,0 − 69 418,963 blir 2 981,037, inte 2 981,057. Mätaren
visade troligen 72 400,02. Det spelar ingen roll för takten.)

## Vattenytan mot det blå röret

- **12 november ca 21:00** — röret hänger fritt, ytan uppskattningsvis en
  decimeter under mynningen (foto).
- **13 november 15:30** — ytan precis vid röret (foto).

Mellan de två tillfällena gick pumpen 18,5 timmar = 165 m³. Vattenytan är
ungefär 1 550 m² vid den nivån, så det ska ha höjt ytan **10–11 cm**. Det
stämmer med bilderna, och betyder att modellens yta är rimlig där uppe och
att läckaget är litet jämfört med påfyllningen.

## Det som inte går ihop än

Det blå röret är snorkeln (bekräftat av Kristian 13 november). Dammen stod
alltså på 100 % den 13 november 15:30 — en säker kalibreringspunkt. Då ska
den hålla 3 850 m³ enligt modellen. Men mätaren säger att 4 059 m³ har fyllts på sedan
25 oktober — 209 m³ mer än så, och då är regnet inte ens räknat.

Var dammen tom 25 oktober måste alltså minst 209 m³ ha tagit vägen någon
annanstans på 19 dygn (drygt 11 m³/dygn). Möjliga förklaringar, att reda ut:

1. Vatten har tagits ut under perioden (provkörning, spolning av ledningar).
2. Dammen rymmer mer än ritningen säger (botten djupare eller större).
3. Läckage eller bräddning i låga hörnet — men då skulle ytan inte ha stigit
   så jämnt som bilderna visar.
4. Mätaren sitter så att allt den räknar inte hamnar i dammen.

Dammen var tom 25 oktober (Kristian, 13 november). Skillnaden är alltså
minst 209 m³, mer om det regnat eller stod en skvätt kvar på botten.

Uttag under perioden: bara provkörning, en kanon i taget från en brunn som
funktionskontroll (Kristian, 13 november). Det rör sig om tiotals
kubikmeter, inte 209 — exakt mängd bör gå att läsa ur styrsystemets
statistik (`Live_stat_SQL`) när sondrapporten finns.

**Prov som skiljer läckage från större damm:** när påfyllningen är avstängd
och inget tas ut, mät med måttbandet längs duken från krönet till ytan, och
igen efter en vecka. Läcker den 11 m³/dygn sjunker ytan 0,7 cm per dygn —
5 cm på en vecka, 9 cm längs duken. Står ytan still rymmer dammen i stället
drygt 5 % mer än ritningen, och då är det volymformeln som ska justeras.

Tills det är utrett är `leak` (2 m³/dygn) och startnivån i appen exempel.

## Uttaget enligt styrsystemet (16 november)

Läst ur `Rapport_Depart_eau_24h` med `brygga.ps1 -Uttag -Fran 2026-10-25`.
Utskriften ligger i `bridge/uttag_20261116-193940.txt` (följer inte med till
git).

| Dygn som slutar  | Pump | Drifttid (h) | Volym (m³) |
|------------------|------|--------------|------------|
| 2026-10-31 07:30 | P1   | 2,63         | 9,63       |
| 2026-10-31 07:30 | P2   | 2,00         | 4,03       |
| alla dygn därefter t.o.m. 16/11 | båda | 0 | 0     |

**Sammanlagt 13,7 m³** — provkörningen 30 oktober, och ingenting annat. Första
raden i tabellen är dygnet som slutar 31 oktober; för 25–30 oktober finns
inga rader alls, vilket troligen betyder att rapporten började föras när
systemet startades för säsongen. Enheten antas vara m³ (rimligt mot 2–3
timmars provkörning, inte bekräftat).

Det gör kalkylen skarpare, inte lösare:

    påfyllt 4 059  −  dammen full 3 850  −  uttaget 14  =  195 m³ som saknas

Uttaget förklarar alltså 14 av de 209. Kvar är **195 m³ på 19 dygn, drygt
10 m³/dygn** — läckage, eller en damm som rymmer ungefär 5 % mer än
ritningen. Måttbandsprovet ovan är fortfarande det som skiljer dem åt.

Säsongssummorna (`bilan_param_depart_eau`, räknat från 2025-11-04):
P1 7 262 m³ på 421 h, P2 7 223 m³ på 413 h — **14 485 m³ tillsammans**, alltså
nästan fyra fulla dammar förra vintern, och i snitt 17 m³/h per pump när den
går. Summan är inte nollställd inför den här säsongen.

### Rättelse 17 november: pumparna sitter i serie

Skärmbilden av pumphuset (Kristian, 16 november) visar att P1 och P2 inte är
två pumpar bredvid varandra. **P1 (LPP01) är matarpumpen** som lyfter vattnet
ur intagsbrunnen, **P2 (HPP01) är högtryckspumpen** efter filtret. Samma
vatten går genom båda. Volymerna ovan får alltså inte läggas ihop:

- Uttaget 30 oktober var **mellan 4 och 10 m³**, inte 13,7. (Varför P1
  räknat 9,6 och P2 4,0 är inte utrett — P1 gick 0,6 h längre.)
- Det som saknas i kalkylen blir då **cirka 200 m³**, inte 195. Slutsatsen
  är densamma.
- Förra vintern gick **drygt 7 200 m³** genom pumphuset, inte 14 485 —
  knappt två fulla dammar.

Skärmen visar också en flödesmätare, **FT01, i m³/h**, efter högtryckspumpen.
Det är det uppmätta flöde appen saknar; se `kolumnmappning.md`.

## Krönet inmätt (22 november)

En band-ATV körde längs krönet med pucken (u-blox). Mätningen efterberäknades
mot Swepos-stationen LIDK och fick 100 % fix runt dammen. Krönet räknas
0,7 m innanför körlinjen (uppskattat ur foto, stämmer med ritningen).
Underlaget ligger i `snowgun-forecast`, `matdata/ppk-2026-11-22-hog-damm/`
(`dammen.json` och `dammen.png`).

|                      | Ritningen M16.1-0000 | Inmätt        |
|----------------------|----------------------|---------------|
| Krönets bredd        | 36,5 m               | 36,65 m       |
| Krönets längd        | 44,5 m               | 44,67 m       |
| Yta innanför krönet  | 1 624 m²             | 1 637 m²      |
| Slänt                | 1:1,5                | inte mätt     |
| Djup                 | 3,5 m                | inte mätt     |

Sidorna är 44,95 m (väster), 36,70 m (norr), 44,38 m (öster) och
36,59 m (söder). Långsidorna går 6,5° öster om norr.

Höjden i hörnen jämfört med krönets mittvärde:

| Hörn | cm    |
|------|-------|
| SV   | +4,5  |
| NV   | +2,1  |
| SO   | −3,1  |
| NO   | −5,6  |

NO är lägst, 8 cm under NV och 10 cm under SV. Det stämmer med fältuppgiften
om ett hörn som ligger 10 cm lägre. Krönet varierar 22 cm runt om. Lägsta
punkten ligger 11 cm under mittvärdet, på norra sidan några meter väster om
NO, och där bräddar dammen först.

Höjderna är ellipsoidhöjder (samma system som barmarken i prognosappen),
inte RH2000. Bara skillnaderna används. Södra sidan kördes bara på östra
13 m, och resten är linjen förlängd. SV-hörnets höjd bygger på 9 punkter.
**Vattenytan mättes inte.**

### Vad det betyder för volymen

- **Måtten i plan förklarar inte de ~200 m³.** Med samma slänt och djup ger
  det inmätta krönet 3 884 m³ till snorkeln, alltså bara 35 m³ (0,9 %) mer än
  ritningens 3 850. Rymmer dammen mer än ritningen ligger skillnaden i botten
  eller slänten. Båda är omätta. Formeln i appen står därför kvar.
- **Höjden i hörnen betyder mer.** 10 cm i höjd är ungefär 155 m³ vid
  snorkeln, och längs duken blir 10 cm i höjd 18 cm. Den som mäter vid NO
  läser alltså 18 cm kortare än den som mäter vid SV, fast vattnet står lika.

### Så här används mätningen i appen (Kristian, 23 november)

- Krönets mittvärde räknas som ritningens 3,50 m. Hörnen ligger då på
  SV 3,545, NV 3,521, SO 3,469 och NO 3,444 m.
- Vid kalibreringen väljer man vilket hörn man mätt vid (SV, NV, NO, SO), i
  stället för ”normalt krön” och ”låga hörnet”. Valet sparas i telefonen.
- Bräddnivån i tvärsnittet är krönets lägsta punkt, 3,39 m (förut 3,40), och
  varningen ligger 15 cm under den, på 3,24 m (förut 3,25).
- Kartan visar krönet som en ruta. Damm-koll visar krönet uppifrån och
  jämför det med ritningen.

Vid snorkeln (3,20 m) ska måttbandet visa ungefär SV 62, NV 58, SO 48 och
NO 44 cm längs duken. Tidigare räknade appen med 54 cm vid ”normalt krön”
och 36 cm vid ”låga hörnet”.

**Nästa gång:** lägg pucken vid vattenlinjen en minut. Då hamnar ytan i samma
höjdsystem som krönet, och det går att se var snorkeln ligger mot krönet
och om 3,50 m är rätt utgångspunkt.

*(Gjort 24 november, se nästa avsnitt. Hörnhöjderna och snorkeln ovan
gäller inte längre i appen.)*

## Snorkeln och vattenytan inmätta (24 november)

Kristian mätte med GPS:en (SparkFun RTK Facet) i en låda som flyter. Lådan
är 235×180 mm i botten och sjunker 30 mm. Antennens fascentrum sitter 74 mm
över lådans botten. Stående på kanten sitter antennen alltså 74 mm över
marken, och flytande 44 mm över ytan. På varje ställe stod lådan först på
krönets kant och flöt sedan vid vattenlinjen, några minuter senare. Passet
gick 19:19–20:04 och efterberäknades mot LIDK (dygn 328): 100 % fix på alla
punkter, utom kanten vid snorkeln, där bara bakåträkningen hade fix.
Underlaget ligger i `snowgun-forecast`, `matdata/ppk-2026-11-24-damm/`
(`stilla.json`, `pass.pos`).

Fältanteckningar:

- Vid snorkeln var det 40 cm längs duken från kanten ner till ytan.
- Ytan låg 3–4 cm under snorkelns kant. Kristian bedömde nivån som
  praktiskt max, eftersom vattnet låg nära kanten på norra sidan.
- Duken är ojämn i hörnen, så där mättes inget med måttband.

| Ställe   | Krönet över ytan | Krönet över snorkelns kant |
|----------|------------------|----------------------------|
| Snorkeln | 18,1 cm          | 14,6 cm                    |
| SV       | 22,6 cm          | 19,1 cm                    |
| NO       | 18,6 cm          | 15,1 cm                    |
| NV       | 13,1 cm          | 9,6 cm                     |
| SO       | 12,9 cm          | 9,4 cm                     |

Felmarginalen är ±2 cm. Snorkelns kant räknas som ytan + 3,5 cm.

- **Krön minus yta på samma ställe.** Vattenytan är plan, men de åtta
  flytpunkterna skilde 4,4 cm (antennhöjd 128,130–128,174). De låg högt där
  kanten låg högt, så skillnaden på samma ställe, mätt med några minuters
  mellanrum, är säkrare än höjderna var för sig. Mot medianen av alla
  flytpunkter blir det samma sak inom 2,5 cm.
- **De lägsta hörnen är NV och SO**, inte NO som ATV:ns hörn 22 november
  visade. ATV:ns hörnhöjder var uppskattade i svängarna. Lådan står direkt
  på kanten. ATV:ns nivå låg i snitt ca 10 cm högre än lådans, möjligen på
  grund av antennhöjden på ATV:n. Bara skillnaderna används.
- **Måttbandet vid snorkeln** ger 40 cm längs duken, som motsvarar 22 cm i
  höjd vid slänten 1:1,5. GPS:en säger 18 cm. Troligen är slänten flackare
  upptill.

### Vad det betyder för volymen

- **Snorkeln sitter 13 cm under krönets medel** (de fyra hörnen), inte 30 cm.
  Med ritningens djup sitter den på **3,37 m**, och 100 % blir **4 111 m³** i
  stället för 3 849.
- **Det stämmer med vattenmätaren.** Fram till 13 november, när ytan nådde
  snorkeln, fylldes 4 059 m³ på. Provkörningen tog 4–10 m³, så ca 4 050 m³
  fanns kvar i dammen. Skillnaden mot 4 111 är ca 60 m³, ungefär 35 mm regn
  på dammen. De ca 200 m³ som saknades i kalkylen ovan var alltså troligen
  inget läckage, utan en snorkel som sitter högre än appen trodde.
- **Snorkeln sitter ca 37 cm över ritningens bräddrör** (3,00 m), inte 20.
  Antingen höjdes den mer än 20 cm, eller så satt det gamla röret högre än
  ritningen säger.
- **Botten är fortfarande inte mätt.** Volymen bygger på ritningens djup.
  Vattenmätaren är kontrollen, och den stämmer inom 1,5 %.

### Så här används mätningen i appen (Kristian, 25 november)

- De fyra hörnens medel räknas som ritningens 3,50 m. Ytan 24 november låg
  då på 3,33 m.
- **100 % är snorkelns kant, 3,37 m ≈ 4 110 m³.**
- **Lägsta inmätta krönet** är SO och NV, 3,46 m, och **varningen** ligger
  5 cm över snorkeln, på 3,42 m. Den slår till om vattnet stiger förbi
  snorkeln, till exempel om den fryser. Mellan hörnen kan det finnas lägre
  ställen som inte är mätta.
- **Måttbandet läses bara vid snorkeln** (ändrat 25 november: först gick
  hörnen att välja, men duken är ojämn där och Kristian mäter bara vid
  snorkeln). Där räknas måttbandet direkt från mätningen: 40 cm betyder att
  ytan står 3,5 cm under snorkelns kant. Full damm är ungefär 34 cm.
- Kartan och skissen visar krönet med ATV:ns plan, och snorkeln som en punkt.

### Måttbandet, vattenmätaren och loggen i appen (25 november)

Kristian provade första versionen samma dag och tyckte att den var
förvirrande. Nu ser Damm-koll ut så här:

- **Måttbandet vid snorkeln** är en ruta. Man drar i reglaget eller skriver
  måttet och ser vad det motsvarar, och det sparas först när man trycker
  **Spara mätningen**. Ordet "kalibrering" syns inte längre. Rutan säger i
  stället vad som händer: mätningen blir dammens nya utgångsläge för alla,
  och sedan räknar appen vidare med vattenmätaren och läckaget. Tiden går att
  sätta när man sparar och att ändra efteråt.
- **Vattenmätaren** är bara till för att läsa in: ställning, tid och Start,
  Stopp eller Avläsning.
- **Loggen** visar allt som sparats, i tre flikar: **Avläsningar** (som
  kolumnerna i Excel), **Pumppass** (start till stopp, med tid, m³ och
  takt) och **Måttband**. Den visar säsongen, och "Visa alla" visar resten.
  Tryck på en rad för att rätta eller ta bort. **Ladda ner för Excel** ger
  fliken som är vald, alla säsonger.
- Mellan de två senaste mätningarna med måttband räknar loggen ut hur mycket
  som försvunnit (läckage, avdunstning och bräddning, minus regn).

Förut låg avläsningarna under knapparna i inmatningsrutan, och Kristian
hittade dem inte efteråt.

Vid 100 % ska måttbandet visa ungefär 34 cm vid snorkeln.

### Läckaget 13–24 november

Påfyllningen har stått still sedan avläsningen 13 november 15:29
(Kristian, 27 november). Inget togs ut förrän pumparna startade 25
november. Ytan stod vid snorkelns kant 13 november (foto) och 3–4 cm under
den 24 november (ögonmått). Det är 3,5 cm på 11,2 dygn, med ytan cirka
1 590 m² vid den nivån. Alltså **cirka 55 m³, 5 m³ per dygn**: läckage och
avdunstning, minus regn. Båda nivåerna är uppskattade med ögat, så
felmarginalen är ungefär ±2 m³ per dygn.

Appen räknar med 2 m³ per dygn, som var ett exempel. Kristian bestämde
27 november att vänta med att ändra det tills mätningarna nedan är gjorda.

**Ett säkrare mått** fås med två mätningar med måttband medan allt står
still: ingen påfyllning och inga kanoner. Mät nu medan anläggningen väntar
på kyla, och igen efter några dygn. Loggen under Måttband räknar ut det
själv. 5 m³ per dygn är 0,3 cm per dygn i höjd, 0,6 cm längs duken, så
fyra–fem dygn behövs för att det ska synas över mätfelet.

### 24–27 november: måttbandet mot uttaget

- Måttbandet: 40 cm (24/11 19:35) och 120 cm (27/11 12:56). Påfyllningen
  stod still.
- Med slänten 1:1,5 sjönk ytan 44,4 cm, och dammen minskade 679 m³. Med
  1:2 sjönk den 35,8 cm och minskade 551 m³.
- FT01 visade 377 m³ under samma tid.
- Kanonernas räknade flöde visade cirka 823 m³. Av det är 616 m³ ur
  `flodeSum`. Resten är tiden före bryggan 7 och är uppskattad ur FT01 med
  kvoten 0,46.
- Läckaget, cirka 14 m³ på 2,7 dygn, är litet här.

Med slänten 1:1,5 visar FT01 alltså 55 % av det som togs ur dammen, och
kanonernas summa 121 %. Flytpunkten nedan visar att ytan sjönk mer än så.

### Flytpunkten 27 november: ytan sjönk 48–50 cm

Kristian lät lådan flyta vid snorkeln 27/11 12:55–12:58
(`SFE_Facet_261127_115138.ubx`), samtidigt som måttbandet lästes till
120 cm. Mätningen efterberäknades 28/11 mot LIDK dygn 331. Under de tre
minuterna lådan låg still hade alla 693 punkter fix. Spridningen var 1,1 cm,
och framåt- och bakåträkningen skilde 0,2 cm. Antennen låg på 127,672.

- **Ytan sjönk 48–50 cm** sedan 24/11. Det är 50,2 cm mot flytpunkten vid
  snorkeln (128,174) och 47,7 cm mot medianen av alla åtta flytpunkter
  (128,149). Lådan flöt på samma ställe båda gångerna, 0,7 m längre ut.
- **Krönet vid snorkeln ligger 67–68 cm över ytan** 27/11. Den siffran beror
  inte på flytpunkterna 24/11, men krönpunkten hade fix bara i
  bakåträkningen (128,385, framåt 128,376).
- **Slänten är brantare än 1:1,5 mellan 40 och 120 cm.** De 80 cm längs duken
  motsvarar 48–50 cm i höjd, alltså 1,6–1,7 cm längs duken per cm i höjd
  (1:1,2–1:1,35). Med ritningens 1:1,5 blir det 1,80 och 44,4 cm. Överst är
  duken i stället flackare: 40 cm mot 18–21 cm. Från krönet ner till ytan
  27/11 blir det 120 cm mot 67–68 cm, nära 1:1,5 (66,6 cm). Duken är alltså
  inte en rak slänt, eller så ligger flytpunkterna 24/11 några cm fel.
- **Dammen minskade 729–765 m³** (679 enligt appen med 1:1,5). Efter
  läckaget, 5–14 m³, var **uttaget 715–760 m³**.
- **FT01 visade 377 m³, alltså 50–53 % av uttaget.** Mätaren visar ungefär
  hälften, som misstänkt.
- **Kanonernas räknade flöde var 108–115 % av uttaget.** Bara 616 m³ av de
  823 räknade bryggan själv; resten är uppskattat ur FT01. Under tiden med
  `flodeSum` (26/11 08:10 till 27/11 01:05 UTC) visade FT01 282 m³, alltså
  togs 535–570 m³ ur dammen, och kanonerna räknade 616.
- Förutsättningen är att lådan bar samma sak båda gångerna: 1 kg mer i lådan
  sänker den 2,4 cm.

**I appen från 28 november (Kristian):** under 40 cm räknas måttbandet med
80 cm längs duken per 49 cm i höjd, ungefär 1:1,3 (`SF_NED`). Över 40 cm
räknas fortfarande ritningens 1:1,5, så full damm är fortfarande ungefär
34 cm. Under 120 cm är slänten inte mätt. Volymen räknas fortfarande ur
ritningen. 120 cm motsvarar nu 2,84 m och 3 308 m³ (förut 2,89 m och
3 376 m³). FT01 visas fortfarande orättad.

### Uttaget räknas ur kanonerna, inte FT01 (28 november)

Kristian vill att dammen räknas ur påfyllningen och kanonernas och lansarnas
vatten, utan FT01, tills han felsökt mätaren. Mätningar med måttband och
låda är bökiga och ska inte behövas för att se ungefär hur mycket som finns.

- **Uttaget är 90 % av kanonernas räknade vatten** (`UTTAG_FAKTOR`),
  eftersom summan var 108–115 % av dammens minskning 24–27 november.
  Påfyllningen är vattenmätaren och läckaget 2 m³ per dygn, som förut.
- Vattnet kommer timme för timme från bryggan 11 (`/vattenTimme`). **Den är
  inte installerad på styrdatorn**, så appen drog inget uttag alls efter
  mätningen 27/11 och visade 80 % fast kanonerna gått natten till 28/11.
  Nu visas dammen som gammal, "Uttaget saknas sedan mätningen", tills
  timvattnet finns. Bryggan 11 räknar hela säsongen bakåt vid första
  starten, så uttaget sedan mätningen kommer med direkt.
- **Bryggan 11 installerades 28 november på förmiddagen.** Från mätningen
  27/11 12:56 till 28/11 kl. 10 räknade kanonerna 558 m³. 90 % är 502 m³,
  så dammen har ungefär 2 800 m³, 68 %.
- Med bryggans timvatten blev kanonernas vatten 24/11 19:35 till 27/11
  12:56 **814 m³**. Det uppskattade jag förut till 823 m³ ur FT01. Mot
  dammens minskning, 715–760 m³, är det 107–114 %, så faktorn 0,9 står
  sig.
- Loggen drar kanonernas uttag mellan två mätningar med måttband och visar
  det som blir kvar per dygn. Blir det mycket mer eller mindre än några m³
  per dygn stämmer inte 90 %.

### Kontroll vid nästa påfyllning (plan, 28 november)

Vattenmätaren på påfyllningen är det säkraste mått vi har, eftersom kommunen
debiterar efter den. 13 november 15:29 stod ytan vid snorkelns kant, och
mätaren visade 73 478,4. Fylls dammen till snorkelns kant igen, är det som
fylldes lika med allt som gått ur dammen sedan dess: kanonerna, läckaget och
avdunstningen, minus regnet. Det beror inte på dammens form, slänten eller
måttbandet.

Så här görs det:

1. **Måttband medan allt står still**, gärna två gånger med några dygns
   mellanrum innan påfyllningen. Det ger läckaget.
2. **Start** i appen när pumpen startar. Från den stunden räknar appen upp
   nivån med senaste uppmätta takten, 8,95 m³/h (215 m³/dygn, passet
   25/10–13/11). En **Avläsning** under påfyllningen rättar nivån och ger
   en ny takt, om det gått minst en timme sedan förra avläsningen.
3. **Stopp** när ytan når snorkelns kant, som 13 november. Skriv
   klockslaget, och ta gärna ett foto.
4. **Bryggan 11 på styrdatorn före dess.** Den räknar kanonernas vatten
   timme för timme för hela säsongen, också tiden före bryggan 7, då bara
   FT01 fanns.

Sedan jämförs det påfyllda med kanonernas räknade vatten sedan 13/11 plus
läckaget. Kvoten ersätter `UTTAG_FAKTOR` (0,9), som bygger på slänten och
flytpunkten. Regnet på dammen (cirka 1 600 m²) är det osäkra: 10 mm regn
är 16 m³.
