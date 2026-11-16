# Dammen — mätningar på plats

Det här är facit som Damm-kollens modell ska stämma mot. Skriv in nya
avläsningar längst ner i tabellen; räkna inte om gamla.

## Vattenmätaren på påfyllningen

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
