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
- **Kalibreringen** mäts helst vid snorkeln, som är förvald. Där räknas
  måttbandet direkt från mätningen: 40 cm betyder att ytan står 3,5 cm under
  snorkelns kant. Full damm är ungefär 34 cm. Hörnen går att välja, men
  duken är ojämn där. Valet sparas i telefonen under en ny nyckel, så att ett
  hörn som valts med ATV:ns höjder inte ligger kvar.
- Kartan och skissen visar krönet med ATV:ns plan, och snorkeln som en punkt.

Vid 100 % ska måttbandet visa ungefär 34 cm vid snorkeln. I hörnen blir det
ungefär SV 34, NO 27, NV 17 och SO 17 cm, om slänten är 1:1,5.

**Öppet:** gick påfyllningen mellan 13 och 24 november? Om den stängdes när
ytan nådde snorkeln har ytan sjunkit 3,5 cm på elva dygn, ungefär 55 m³
eller drygt 5 m³ per dygn. Det vore första riktiga måttet på läckaget.
