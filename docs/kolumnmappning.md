# Kolumnmappning — vad som står var i GSSystems databaser

Underlag: sondrapporten 15 november 2026 kl 18:38–18:44 och skärmbilden av
pumphuset 18:42 samma kväll. Anläggningen stod still, så allt som bara syns
under drift (flöde, driftläge, dyssteg) är ännu inte hittat.

**Säker** = stämde mot skärmbilden eller mot statistiktabellernas kolumnnamn.
**Osäker** = gissning. Kontrollera med `bridge\brygga.ps1 -EnGang -Ra` och ett
foto av skärmen när något går.

## Databaserna (29 stycken)

| Databas | Innehåll |
|---|---|
| `Live_Snowstar` | Nuläget. Numrerade kolumner. `*_Com` skrivs var 20:e sekund, `*_Main` är inställningar. |
| `Live_event_SQL` | Larm (`defaut_actif`), händelser (`Journal`), senaste läge per apparat (`*_actuel`). Klartext på engelska. |
| `Live_stat_<månad>1SQL` / `…2SQL` | Statistiken, 24 databaser. `1` = dag 1–15 (bekräftat: 15 november låg i `novembre1`), `2` = resten (antaget). Franska månadsnamn utan accenter: janvier, fevrier, mars, avril, mai, juin, juillet, aout, septembre, octobre, novembre, decembre. Riktiga kolumnnamn, värden × 10. |
| `Live_stat_SQL` | Summeringar per säsong (`bilan_*`), underhållsräknare, taxor. |
| `Live_stat_SQL_rapport` | Dygnsrapporter: `Rapport_Depart_eau_24h` (volym per avgång), `Rapport_regard_24h` (per brunn). |
| `Live_Language` | Texter på alla språk. |

Statistiken skrivs varannan minut för pumphuset (`stat_SDM_*`) och var tionde
för kanoner och givare (`stat_piste_*`). Tabellerna har 100 000–300 000 rader
per halvmånad — läs dem aldrig utan `WHERE date >`.

## Pumphuset — `Live_Snowstar.[Water departure_Com]`

En rad per avgång: `11` = P1 (lågtryck, LPP01), `12` = P2 (högtryck, HPP01).

| Kolumn | Betydelse | Säkerhet |
|---|---|---|
| 0 | avgångens nummer | säker |
| 121 | tryck in, bar (PT01 = 0,1). Sufag: "Mot mesure pression aspiration" | säker |
| 122 | vattentemperatur, °C (TT01 = 11,8). Sufag: "Mot mesure température aspiration". Mäter strömmande vatten: när pumparna står visar den vattnet i röret (bryggan 12 skickar därför också senaste värdet vid drift) | säker |
| 123 | tryck ut, bar (PT02 = 7,2; 0,1 för avgång 11). Sufag: "… pression refoulement" | säker |
| 124 | temperatur ut, °C | säker (statistikens `temperature_refoulement`) |
| 125 | uppmätt flöde ut, m³/h (FT01). Sufag: "Mot mesure débit". Steg till 6–12 när pumparna startade 25 november och följde skärmen (8,6). **Visade 50–53 % av dammens minskning 24–27 november; mätaren har felet F61, se nedan.** | säker att det är FT01; storleken fel |
| 126 | Sufag: "Mot mesure niveau lac/bac", alltså **dammens nivå**. Står på 0,1: ingen givare inkopplad | säker (sonden 28 november) |
| 128 | Sufag: "Mot de débit disponible" | säker |
| 158 | senaste kontakt | säker |

Statistikens `niveau_lac` är konstant 1 och `MapLevel` är tom: det finns
ingen nivågivare i dammen. "Lake lvl. 95,5 m" på skärmen är en fast text.

Styrsystemet har alltså en ingång för dammens nivå (126), och i
`Water departure_Main` ett ersättningsvärde för den ("Remplacement niveau
lac/bac"). En nivågivare i dammen, kopplad dit, skulle ge riktig nivå i
stället för appens räkning. Det är en fråga för leverantören.

### FT01: felet F61 och "Measuring approx. 50 %" (28 november)

Kristian fotade flödesmätaren 28 november. Den består av en Siemens SITRANS
F M MAG 5000-omvandlare och en MAG 3100-givare:

- **Omvandlaren:** MAG 5000, 7ME6910-1AA10-1AA0, märkt 08/2023.
- **Givaren:** MAG 3100, DN 65, 7ME6310-3FG11-1AA1, serienummer 161140H249,
  från 2019, kalibreringsfaktor 3,552451.

Omvandlaren är alltså fyra år yngre än givaren. Displayen visade 0 m³/h och
"Pending 029d16h08m", med växlande "Replace" och "F61 SENSORPROM err.".

Ur Siemens manual (MAG 5000/6000, A5E02338368, 06/2023, kapitel 9):

- **F61, "SENSORPROM® error", åtgärd "Replace"**: "It is not possible to
  rely on the data in SENSORPROM® unit anymore". I felsökningstabellen står
  den under symptomet *Measuring error* ("Defective SENSORPROM® unit →
  Replace SENSORPROM® unit").
- **SENSORPROM** är minnet i givarens kopplingslåda. Där ligger
  givarstorleken, kalibreringsfaktorn och alla inställningar, och
  omvandlaren hämtar dem därifrån. Det måste ha samma serienummer som
  givaren.
- **Samma tabell har symptomet "Measuring approx. 50 %"**, med orsaken
  "Missing one electrode connection" och åtgärden "Check cables".
- **Felloggen nollställs när strömmen bryts.** "Pending 029d16h08m" är
  alltså räknat sedan omvandlaren senast fick ström, troligen när
  säsongen startade kring 29–30 oktober.

FT01 visade 50–53 % av dammens minskning och 45–46 % av kanonernas räknade
flöde. Båda förklaringarna passar: data som inte går att lita på, eller en
elektrod som inte är ansluten. Att kontrollera i omvandlarens meny:

- *Sensor characteristics*: Sensor size ska vara DN 65, Calibration factor
  3,552451 och Correction factor 100 %.
- *Basic settings*: Qmax, och att strömutgången (4–20 mA) motsvarar det
  styrsystemet räknar med.
- Elektrodkablarna i kopplingslådan.

Ett nytt SENSORPROM beställs från Siemens med givarens serienummer. Det är
leverantörens eller en elektrikers sak. Kopplingslådan står under 230 V.

#### Omvandlarens inställningar, avlästa 28 november

Kristian läste av omvandlaren i läsläget 28 november 12:07–12:14. Bilderna
ligger i `FT01waterflowsensor/`, där dubbletterna är borttagna.

| Meny | Värde i omvandlaren | Givarens skylt |
|---|---|---|
| SENSORPROM | **Not installed** | – |
| Suppress P40 | No | – |
| Sensor size | **0,0400 m (DN 40)** | **DN 65** |
| Calibration factor | **1,9634950** | **3,552451** |
| Correction factor | 1,0000 | – |
| Excitation | 3,125 Hz (50 Hz) | – |
| Sensor type, code no, serial no, size (Product identity) | **tomma (-----)** | MAG 3100, 7ME6310-3FG11-1AA1, 161140H249 |
| Converter | MAG 5000, 7ME691…, N1R8220065, SW 04.08 X 03 | – |
| Qmax | 70 m³/h | (styrsystemets kolumn 128: 70) |
| Flow direction / Empty pipe / Low flow cut-off | Positive / On / 1,5 % | – |
| Error level / Mains frequency | Warning / 50 Hz | – |

**Slutsatsen:** omvandlaren har inget SENSORPROM och är inställd för en annan
givare, DN 40 med faktorn 1,9634950 (troligen ett grundvärde), medan givaren
i röret är DN 65 med 3,552451. Omvandlaren är från 2023 och givaren från
2019, så den byttes troligen utan att givarens data fördes över. Siemens
manual säger just detta: "If a SENSORPROM is not installed, check the sensor
characteristics to see if they match the product label".

**Hur mycket fel det ger.** Skillnaden i kalibreringsfaktor ensam ger att
FT01 visar 1,9634950 / 3,552451 = **55 %** av det verkliga flödet. Rättat
med 1,809 blir det:

| Tid | FT01 | Rättat | Kanonernas timvatten | Kanonerna mot rättat |
|---|---|---|---|---|
| 24/11 19:35 – 27/11 12:56 | 377 m³ | **683 m³** | 814 m³ | 119 % |
| 26/11 08:10 – 27/11 01:05 | 281 m³ | 509 m³ | 625 m³ | 123 % |
| 27/11 12:56 – 28/11 12:00 | 254 m³ | 460 m³ | 558 m³ | 121 % |

Mot dammen 24–27 november: måttbandet med ritningens slänt 1:1,5 gav 679 m³,
alltså **inom 1 % av rättat FT01**. Flytpunkten med lådan gav 729–765 m³,
7–12 % mer. Två oberoende mått pekar alltså på cirka 680 m³, och på att
slänten är ungefär 1:1,5 även mellan 40 och 120 cm. Lådans höjder kan ha
några cm fel nära kanten. Kanonernas räknade vatten blir då **cirka 120 %**
av det verkliga, och uttaget borde räknas som cirka 0,83 av det, inte 0,9.

Det här förutsätter att omvandlaren räknar flödet ur kalibreringsfaktorn och
inte också ur storleken. Hade storleken räknats in hade FT01 visat 21 % eller
69 %, och det stämmer inte med något vi sett. Påfyllningen till snorkeln
avgör: den ska vara lika med rättat FT01 sedan 13 november, plus läckaget.

**Felet är linjärt.** En magnetisk flödesmätare ger en spänning som är
proportionell mot hastigheten, och omvandlaren multiplicerar med konstanter.
En fel konstant ger samma procent fel vid alla flöden. Historiken 24–28
november bekräftar det: FT01 delat med kanonernas summa låg på 0,44–0,48 i
alla flödesband från 3 till 56 m³/h. Det svaga fallet vid högt flöde beror
troligen på kanonernas egen räkning. Två förbehåll:

- Low flow cut-off 1,5 % av Qmax gör att verkliga flöden under cirka
  1,9 m³/h visas som 0.
- Excitationen 3,125 Hz är kanske inte den frekvens givaren kalibrerades
  med. Siemens anger att det kostar under 1 % efter nollställning.

**SENSORPROM** är ett litet minne som hör till givaren. Det sitter i övre
kanten av givarens kopplingslåda, den grå lådan under displayen (märkt MAG
3100, 07/2019), under omvandlarens kopplingsplatta. Kontakten sluts av sig
själv när plattan monteras. Manualen (4.3, s. 24–25) säger: "Check that your
connection board lines up with SENSORPROM® unit, if not, move SENSORPROM®
unit to the other side of terminal box." Stödsidan med bilder, var minnet
sitter och hur värdena ställs in är en privat artefakt:
https://claude.ai/artifact/XayFgmnJaZzmyh8v7jMHdW. Kristian:
överdelen byttes för några år sedan, och det var då mätaren slutade stämma.
Troligen kom plattan inte över minnet, eller så försvann minnet vid bytet.

**Att göra (leverantör eller elektriker):** ställ in Sensor size 65 mm och
Calibration factor 3,552451 under Sensor characteristics. Det kräver
lösenordet, och fabrikens är 1000. Leta också efter givarens SENSORPROM (serie
161140H249), som kan sitta kvar i den gamla omvandlarens kopplingslåda. Fråga
först leverantören om styrsystemet använder FT01 när det fördelar flödet:
`Water departure_Main` kolumn 16 "Empilement sur débit réel (=0) ou sur
débit demandé (=1)" står på 0. Efter rättningen visar FT01 cirka 1,8 gånger
mer än i dag.

## Ledningarna — `[Line_Com]`

| Kolumn | Betydelse | Säkerhet |
|---|---|---|
| 0 | ledning: 111, 121, 122, 001, 002 | säker |
| 60 | tryck, bar (121 = 7,7 = PT03; 122 = 7,3 = PT04) | säker |

Ledning 001 och 002 är dräneringsventilerna vid brunn 7 och 18
(`Line_Main` kolumn 66).

## Kanoner och lansar — `[SGC400_Com]`

Sju rader. n° 1, 2, 3, 6, 7 är fläktkanoner (S ACCESS 300), n° 4 och 5 är
lansar (TAURUS_2.0, T2N65). **Adress = n° + 2** — bekräftat 25 november mot
skärmen Gun searching: lansarna har adress 6 och 7. Snögruppen talar om
adressen, inte n°.

| Kolumn | Betydelse | Säkerhet |
|---|---|---|
| 3 | n° | säker |
| 400 | lufttemperatur, °C | säker |
| 401 | luftfuktighet, % | säker |
| 402 | våttemperatur, °C | säker |
| 411 | "Theoretic water flow", m³/h: flödet för de öppna ringarna vid börtrycket (statistikens `debit_eau_theorique` ÷ 10). Står kvar när kanonen står (cirka 4) | säker |
| **406** | **"Real water flow", m³/h** — räknat, inte mätt: 411 × √(403 ÷ 417). 0 när kanonen står | **säker** (26 november, fem kanoner) |
| **403** | **"Water pressure", bar**, vid kanonen (10–19,9 när de gick) | **säker** (26 november) |
| **417** | **"Water pressure set point", bar** (10–21; 21 hos lansarna, som stod) | **säker** (26 november) |
| **707** | **brunnen enheten står vid** ("Shelter" på skärmen Gun searching) | **säker** — alla sju stämde 25 november: n° 1–7 = 7, 10, 9, 7, 8, 5, 8. 26 november hade n° 2 och 3 bytt (9 och 10) |
| 408 (= 706) | vattentemperatur vid enheten, °C — 2,5–2,7 hos kanonerna när vattnet ut var 2,8–3,6 | trolig |
| 415 | läge: **6 kör** (alla fem som gick 26 november), 11 för de som var OK men inte gick, 1 för den som fått fel (adress 4, "fault" 21:09), 2 för den som stoppats (adress 8, "stopped" 21:08) | trolig, flera tillfällen |
| 416 | 50 för OK, 42 för felet, 1 för den stoppade, 20 för alla som gick — felkod eller steg? | **osäker** |
| 413 | 19 för alla som gick 26 november, annars 0 | **osäker** |
| 702, 703 | start- och stoppgräns i våttemperatur per enhet: n° 1, 6, 7 −2/−1,5 som skärmens Starting/Stopping temperature, n° 2, 3 −2,4/−1,9, lansarna −3/−2,5 | trolig (skärmen visade −2/−1,5 för en kanon) |
| 450–455, 500–503, 709 | lamporna på skärmen som bitmönster, se *Lamporna* nedan | delvis |
| 852 | 9–20 för kanonerna, 50 för lansarna | **osäker** |
| 801, 802 | typ och modell | säker |
| 850 | senaste kontakt med kanonen | säker |

Händelsernas namn är "server adress brunn": `2 4 10 fault` är adress 4 vid
brunn 10, och `Disappeared S ACCESS 300 (adr = 4) from 10` säger samma sak.
Kvällen 25 november försvann adress 4, 8, 9 och 5 en i taget 21:12–21:17.
En enhet som försvinner behåller sina sista värden i tabellen, också läget i
415.

### Flödet i kanonerna (26 november 2026)

Kanonerna har ingen flödesgivare. Båda flödena på skärmen är räknade:
teoretiskt för de öppna ringarna vid börtrycket, och "real" rättat med
trycket kanonen mäter. Läsningen 08:40 mot formeln
406 = 411 × √(403 ÷ 417):

| Kanon (adress) | Brunn | 411 | 406 | 403 | 417 | Formeln |
|---|---|---|---|---|---|---|
| 3 | 7 | 7,3 | 7,3 | 10 | 10 | 7,30 |
| 4 | 9 | 6,6 | 6,5 | 16,8 | 17 | 6,56 |
| 5 | 10 | 7,6 | 7,7 | 11,1 | 11 | 7,63 |
| 8 | 5 | 7,3 | 7,1 | 19,9 | 21 | 7,11 |
| 9 | 8 | 7,6 | 9,5 | 16,8 | 10,8 | 9,48 |

### Styrsystemet räknar snön som vattnet × 2,2

Ingen kanon mäter eller rapporterar snö. Styrsystemets skärm ("Flows m³/h:
Water 41, Snow 90,2" 26 november) och statistiken (`bilan_exploitation2`,
provberäkningen för Råda 27 december 2023: 33,97 → 74,73, 224,58 → 494,08,
283,22 → 623,08 m³) ger alla exakt 2,20. Det motsvarar snö på ungefär
455 kg/m³ utan svinn, oavsett väder och snökvalitet; i verkligheten kanske
1,7–2,6. "Medium thickness of the snow" är samma volym delad med spårets
yta. "Water" på skärmen är kanonernas summerade flöde (41 mot bryggans
40,7), inte FT01 (18,6).

Styrsystemets statistik per kanon (`stat_piste_canon_SGC400`/`_SGC300` i
`Live_stat_<månad><1|2>SQL`) har `date`, `num_canon` (n°), temperatur,
fukt, våttemperatur, `pression_eau`, `debit_eau_reel`,
`debit_eau_theorique` (alla × 10) och `etat`. Raderna kommer inte med jämna
mellanrum: ungefär varje minut på det äldre kortet, var 2–3 minut på
SGC400 (räknat ur radantalen 1–15 november). Bryggan 9 `-Bakat` räknar
vattnet före bryggan 8 ur dem.

Bryggan 8 summerar vattnet per enhet sedan den kom till brunnen
(`vattenBrunn`, nollas när brunnen byts) och för säsongen från 1 augusti
(`vattenSasong`). Appen multiplicerar med `SNO_FAKTOR`. Den egna faktorn
kan tas fram när snöytan mätts med pucken: snödjup × yta mot vattnet för
samma körningar.

#### Första mätningen: högen vid brunn 5 (27 november)

- Kanon 8 (`SGC400-6`) har stått vid brunn 5 sedan 30 oktober. När högen
  mättes, 27/11 13:04–13:24, var vattnet vid brunnen 133 m³. Kanonen hade
  stått sedan strax efter midnatt.
- Av vattnet är ungefär 40 m³ efterräknat från tiden före bryggan 8,
  troligen natten 25–26 november när pumparna startade. Resten kom 26/11
  10:00 till 27/11 01:00, i −2 till −5 grader våttemperatur. Högen var
  alltså 1–2 dygn gammal, och det var minusgrader hela tiden.
- Kristian drog pucken över högen. Snöprognos-sessionen räknade ut
  **190 ± 15 m³ snö** på 444 m², med största djupet 126 cm. Till det kommer
  troligen 10–20 m³ i skogskanten, som inte mättes. Underlaget ligger i
  `snowgun-forecast`, i `matdata/ppk-2026-11-27-hog5/`.
- **Snö per m³ räknat vatten blev 1,4–1,6**: 1,43 med det som mättes, och
  1,5–1,6 med skogskanten. Styrsystemet räknar med 2,2, så appen visar
  ungefär 30 % för mycket snö.
- Mot det vatten som faktiskt gick åt blir faktorn 1,55–1,8, alltså snö på
  550–650 kg/m³. Kanonernas räknade flöde var 108–115 % av dammens minskning
  (`docs/damm-matningar.md`), så vattnet var 116–123 m³.
- Detta är en hög, en kanon och en mätning. Kanon 8 har gjort 89 m³ till
  sedan dess (222,6 m³ på morgonen 28/11). En ny mätning av samma hög ger
  alltså en andra punkt.

Kristian valde 28 november att byta `SNO_FAKTOR` från 2,2 till 1,5.

#### Snökvaliteten i styrsystemet (28 november)

Kanonerna har inställningen "Snow Quality", från Dry till Wet på en skala
1–10. Kristian tror att ni brukar köra 5. Sufags beskrivningar i
`Live_Snowstar.dat` (i `GSSystem.zip`) har bland annat:

- "Température de démarrage couronne 1–3": startgränsen för varje ring.
- "Offset qualité de neige 10 … 90".
- "Snow Quality", "Snow Quality MAIN" och "Snow quality COM".
- Modbus-ord 36 "Base snow quality" för den nyare styrningen.

Troligen öppnar automatiken varje ring vid en egen våttemperatur, och
kvaliteten flyttar de gränserna. Torrare snö betyder då att ringarna öppnar
först när det är kallare, alltså mindre vatten vid samma våttemperatur.
Kvaliteten avgör alltså både hur mycket vatten kanonen tar och hur tät snön
blir.

Styrsystemets snö (× 2,2) tar ingen hänsyn till kvaliteten. Faktorn 1,5 är
mätt vid kvalitet 5 (bekräftat av sonden 28 november: 5 på alla kanoner)
och −2 till −5 grader våttemperatur, på snö som legat 1–2 dygn.

#### Varför 1,5 och inte 2,2

Kristian valde 28 november att behålla 1,5. Skälen till att det blev så långt
från 2,2:

- **Svinn.** Pucken mätte bara på spåret. Snön som slänt ut i skogen, cirka
  10–20 m³ eller 5–10 %, kom inte med. Ett skidspår är smalt, så mer hamnar
  utanför än i en slalombacke.
- **Snön har satt sig.** Högen hade legat 1–2 dygn.
- **Nära startgränsen.** Det var −2 till −5 grader våttemperatur, med
  troligen kvalitet 5. Det ger blötare och tätare snö.
- **Vattnet är räknat.** Kanonernas räknade vatten var 108–115 % av det
  dammen minskade, och faktorn räknas mot det räknade.
- **Avdunstning och avdrift** under själva sprutningen.

### Lamporna (ringar, hydrant, kompressor …)

Skärmen visar för varje kanon Ring 1–4, Hydrant OK, Water valve open/closed,
Pressostat, Compressor ON, Automatic, General fault, Gun started, Power ON,
Fan ON, Rotation och Ready to start (temp OK). Ringarna styr hur mycket
vatten, och därmed snö, kanonen gör.

I SGC400 ligger de som bitmönster i teckenkolumnerna 450–455, 500–503 och
709. Bryggan 7 skickar de tända bitarna som `bitar`, till exempel
`453:0,1,5;454:0,4` — bit 0 är tecknet längst till höger. Historiken sparar
dem (`b`) bara när de ändras, så att varje gång en ring öppnas eller en lampa
tänds får en tid som kan jämföras med skärmen.

Tända bitar, stående kväll 25 november och gående morgon 26 november
(skärmen: ring 1 och 2, automatik, gun started, power, fläkt, kompressor,
hydrant OK och ready to start tända på alla som gick):

| Läge | 453 | 454 | 455 |
|---|---|---|---|
| OK, står (415 = 11) | 5, 6, 10 | 0, 6 | 2 |
| fel (1) / stoppad (2) | 5, 6, 8, 10 | 0, 6, 7 | 2 |
| kör (6), alla fem | 0, 1, 5, 10, 12 (+ 8, 9 eller 11 olika) | 0, 4, 6, 7, 8 | 2 |
| lans, tyst sedan oktober | – | 0, 6 | – |

Tänds bara vid körning: 453 bit 0, 1, 12 och 454 bit 4, 8. **Ring 1 och 2
är troligen 453 bit 0 och 1**, och ring 3 och 4 då bit 2 och 3 — det senare
bara en gissning ur mönstret, ingen har sett dem. Resten är inte parat.
Appen visar ringarna som tolkade och övriga som råa bitar.

Det äldre kortet har en kolumn per lampa (25–81). Bryggan skickar dem som
`flaggor`, till exempel `25,37,42,43,44,65=3`. Gående 26 november, med
skärmens Ring 0, Ring 2, Automatic, Fan ON och Compressor ON tända, var
25, 37, 42, 43 och 44 = 1, 65 = 3 och 107 = 2 — fem ettor för fem lampor,
men inte vilken som är vilken.

**Sufags egna beskrivningar (27 november, ur zip-filen).** Säkerhetskopian
`GSSystem/BdD/Live_Snowstar.dat` i `GSSystem.zip` bär Sufags beskrivning av
många kolumner (SQL Servers `MS_Description`), men inte vilken kolumn varje
text hör till. Texterna i `Live_Language.neige` 171–186 är samma lampor i
samma ordning, och de är skärmens etiketter (GSSystem hämtar `neige` 165–299
till kanonbilden). För det äldre kortet, en kolumn per bit och åtta per
byte:

| Byte | Bit 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 |
|---|---|---|---|---|---|---|---|---|
| 1 | Man – Auto | General fault | Pressostat | Hydrant OK | Gun started | Power ON | ? | fri |
| 2 | Hydrant open | Hydrant closed | 0 rings open | 1 ring open | 2 rings open | 3 rings open | 4 rings open | fri |
| 3 | fri | Compressor ON | Fan ON | Ready to start (temp OK) | General fault (strob) | … | … | … |

Lägger man byte 1 på kolumn 25 blir 25 = Auto, 37 = 2 rings open, 42 =
Compressor ON, 43 = Fan ON och 44 = Ready to start — fyra av de fem lamporna
26 november, och den femte var en kanon i kall luft. **Trolig, inte
bekräftad**: att byte 1 börjar på 25 är räknat, inte läst. Längre fram i
samma tabell: fellamporna (Hydrant fault, Fan overload, Compressor
overload, Overload protection, Fault 380V, Flex frozen, Flex disconnected,
Low water pressure m.fl.) som egna bitar.

För den nyare styrningen står Modbus-kartan i samma kopia: ord 0–2
"binaire -> Inputs", 3–6 "binaire -> Errors", 7–9 använd lufttemperatur,
fukt och våttemperatur, 10 vattentryck, 15 vattenflöde, 20 brunnsventilens
läge, **22 "Wanted rings" och 23 "Open rings"** (ett tal, inga bitar), och
50–52 "binaire" (start/stopp). Om det här är SGC400 kan ringarna läsas som
ett tal och bitkolumnerna 450–455 och 500–503 vara ingångs- och felorden.
Vilken kolumn som är vilket ord står inte i kopian.

**Facit, sonden version 3 (28 november).** Kristian körde sonden på
styrdatorn. Del 7 gav Sufags beskrivning av 2 833 kolumner med exakt tabell
och nummer. Rapporten ligger i `probe/db-sond-rapport_20261128-105703.txt`,
utanför git.

- **Det äldre kortet (SGC300) är klart, kolumn för kolumn:**
  - 25 Man – Auto, 26 General fault, 27 Pressostat, 28 Hydrant OK, 29 Gun
    started, 30 Power ON, 31 fri/värme.
  - 33 Hydrant open, 34 Hydrant closed.
  - 35–39 "0–4 rings open".
  - 42 Compressor ON, 43 Fan ON, 44 Ready to start, 45 General fault (strob).
  - 46–48 är för Sufag swivel, inte ringar. 49–50 "5–6 rings open".
  - 57 Local start, 60 PC Automatic, 61 PC Command, 65 "demande de marche".
  - 66–81 felen (67 Over regulation … 81 Filter dirty).

  Byte 1 börjar alltså på 25, som räknat. Appen visar dem med Sufags namn.
- **SGC400 har namn på orden, inte på bitarna:**
  - 450–451 "Défaut 1–2", 452 "Alarme", 453–454 "Mot Etat 1–2", 455 "Option".
  - 500–501 "Etat ETOR" (ingångar), 502–503 "Etat STOR" (utgångar), 709
    "Options".
  - "Word 22 Wanted rings / 23 Open rings" hör till tabellen `Lenko_Com`, en
    annan kanontillverkare. Den har 0 rader här.
- **Vattenstegen i SGC400, tolkade ur flödet** (kanon 8, 26–28 november):
  - Bit 11 och 12 i 453 växlar med flödet. Bara bit 11 ger cirka 5,1 m³/h,
    bara bit 12 cirka 6,5 och båda cirka 8,3.
  - Det är två steg ovanpå ett grundsteg, kopplade binärt som
    `Combinaison Ev` i `Gun` (00001, 00010, 00011).
  - Bit 0 och 1 är tända hela tiden kanonen går, och visades förut som
    ring 1 och 2. Bit 2 och 3 tänds kort vid stopp, 13 och 14 vid start.
  - Appen visar stegen som "Litet steg ?" och "Stort steg ?". Vilken av
    skärmens Ring 1–4 de motsvarar avgörs med en skärmbild med klockslag
    medan en kanon går.
- **Inställningarna:**
  - SGC400: 704 "Qualité de neige", 702 "T° de démarrage", 703 "T° arrêt",
    705 "Débit max", 706 "Température d'eau", 707 "Num regard".
  - Det äldre kortet: 16 "Snow quality COM" och 9 "Start temperature COM".
  - 28 november var kvaliteten **5 på alla** och start/stopp −2,5/−2 °C. De
    två Taurus-lansarna har −3/−2,5 och kvalitet 4–5.
  - Bryggan 12 skickar dem, och appen visar dem i enhetens vy.
- **Kanonmodellerna (`Gun`, 226 rader).** Sonden visar bara de tre första
  (Taurus):
  - "Enclenchement Ev1–4", alltså stegens startgränser i våttemperatur (−4,1,
    −5,3, −6,5, −7,2 för TAURUS_2.0).
  - "Offset qualité de neige 1–9", −20 till +20 i steg om 5 (troligen
    tiondels grader, alltså ±0,5 °C per kvalitetssteg).
  - Raden för S ACCESS 300 kom inte med. En läsning av just den raden skulle
    ge kanonernas egna stegränser.

**FT01 mot kanonerna:** de sex som gick (fem ovan och adress 1 med 5,8)
gav 43,9 m³/h ihop; FT01 visade 19,8, alltså 45 %. Klockan 06:12 var
kvoten 46 % med teoretiskt flöde. Det stämmer med att mätaren visar ungefär
hälften. Kanonernas siffra hänger på dysornas tabellvärden, men den är
oberoende av FT01 — ligger kvoten stadigt kring 45 % talar det för ett
skalningsfel. Bryggan 7 sparar summan (`flodeSum`) i historiken, så kvoten
kan följas över en hel natt. Måttbandet vid dammen avgör vilken som stämmer.

## Fläktkanoner på äldre styrkort — `[SGC300_Com]`

Två rader. n° 1 lever. n° 2 har inte hörts sedan 19 oktober 2022.

| Kolumn | Betydelse | Säkerhet |
|---|---|---|
| 2, 3, 7 | lufttemperatur, fukt, våttemperatur | säker |
| **4** | **"Water pressure", bar** (14,5; skärmen 14,6) | **säker** (26 november) |
| **10** | **"Theoric flow", m³/h** | säker (sonden 28 november) |
| **5** | **"Real flow", m³/h** | säker (sonden 28 november). Skärmen visade 4,7 teoretiskt och 5,4 real samma morgon, så de är inte alltid lika |
| 9 | "Start temperature COM", °C (−2,5 28 november) | säker (sonden 28 november) |
| 14 | "Flow max COM", m³/h (24,1; skärmen 24) | säker |
| 16 | "Snow quality COM" (5) | säker |
| 21 | "Temperature of water COM", °C (3,5–3,8) — vattentemperaturen kortet räknar med | säker |
| 88 | n° (= adress på det här kortet: n° 1 har adress 1, n° 2 adress 2) | säker |
| 104 | senaste kontakt | säker |
| **108** | **brunnen** ("Shelter"): n° 1 = 6, n° 2 = 7 | **säker** (25 november) |

n° 2 finns inte längre men ska inte tas bort ur styrsystemets databas. Appen
ska strunta i den.

## Väder — `[TH_Com]`, `[Wind_Com]`

`TH_Com` har tio rader: givare `1` (kolumn 10) är väderstationen vid brunn 7,
1001–1009 är kanonernas egna givare. Kolumn 4, 5, 6 = temperatur, fukt,
våttemperatur. `Wind_Com` kolumn 4 = fart, 5 = riktning — används inte i
appen, stationens vindmätare är inte tillförlitlig.

Det finns ingen annan givare för luften i tabellen; pumphusets ligger
troligen i `Cooling tower_Com` (se Pumphuset nedan).

### Stationens temperaturgivare visar för varmt (25 november 2026)

Snögruppen har fått höra att väderstationen mäter fel, utan att någon vet
varför, och låter därför en kanon vid brunn 7 räkna fram våttemperaturen i
stället. Jämfört med kanon 3 (SGC400 n° 1), som står vid samma brunn, var
tionde minut 20:50–22:30:

| Klockan | Stationen t / våt | Kanon 3 t / våt |
|---|---|---|
| 21:10 | 1,3 / −1,0 | −0,1 / −1,8 |
| 21:40 | 0,0 / −1,8 | −0,5 / −1,9 |
| 22:00 | 1,3 / −0,9 | −0,3 / −1,8 |
| 22:30 | 0,2 / −1,7 | −0,3 / −1,7 |

- **Temperaturen ligger 0,3–1,7 grader för högt och hoppar**, medan kanonen
  ligger still. Det är ingen fast offset, så en rättning i styrsystemet
  skulle bara stämma ibland.
- **Fukten i luften stämmer.** Ångtrycket ur temperatur och relativ fukt
  (Buck 1996) var 4,53 hPa på stationen (0,8 °C, 70 %) och 4,58–4,60 hPa på
  kanon 3 och 5 (−0,3 °C, 77 %; 0,0 °C, 75 %), daggpunkten −4,0 mot −3,8.
  Fuktgivaren mäter alltså rätt mängd vatten; den relativa fukten blir låg
  bara för att den räknas mot en för hög temperatur.
- **Tolkning (inte bekräftad):** givaren sitter i luft som är varmare än
  omgivningen — ett strålskydd som inte ventileras, värme från ett skåp, hus
  eller brunnen, eller egenuppvärmning. Det var nästan vindstilla (0,1–0,2
  m/s), då ett sådant fel blir störst och mest ojämnt. Kontrollera var och
  hur den sitter, och jämför en blåsig natt: krymper skillnaden i vind är
  det uppvärmning.
- **Följd:** stationens våttemperatur blir upp till 0,8 grader för varm,
  alltså för försiktig. Appens översikt visar stationens värden; enheterna
  vid brunn 7 är bättre så länge felet finns.

Morgonen 26 november, med alla kanoner igång, visade stationen −2,8 °C och
kanonerna −3,9 till −4,4 — fortfarande 1,1–1,6 grader för varmt. Fukten gick
då inte att jämföra: kanonernas egna fanor höjer luftfuktigheten vid deras
givare (87–92 %).

Bara en kväll och en morgon att jämföra med. Historiken har sedan bryggan 5
både stationens och de hörda enheternas t och tw, så jämförelsen kan göras
om över längre tid och i fler väder.

## Larm och händelser — `Live_event_SQL`

- `defaut_actif`: `date` (text, dd/MM/yyyy), `machine`, `nom`, `message`,
  `ID`, `def_actif` (1 = aktivt). 107 rader.
- `Journal`: `date` (datetime), `machine`, `nom`, `message`, `color`.

## Brunnarna — `[Shelter]`

24 rader, kolumn 1 = brunnens nummer, 14 = vilken givare den lyssnar på,
16/17/18 = temperatur, fukt, våttemperatur från den givaren. Vilken kanon som
står vid vilken brunn är inte utrett — CLAUDE.md i prognosrepot säger tjugo
brunnar, styrsystemet har tjugofyra.

## Ännu inte hittat

- Vilken bit som är vilken lampa, utom ring 1 och 2 (troligen), se
  *Lamporna*. Dyssteg på lansarna.
- Läget på det äldre kortet (appen räknar det som "kör" när vatten går).
- Vad `Set up installation` kolumn 11 (= 900) betyder; statistiken kallar den
  `debit_eau_total`, men den var 900 med allt avstängt.

## Vad appen visar av detta (16 november 2026)

Appen läser `/live` och `/hist` ur Firebase och visar bara det som finns där.
Med `?demo` i adressen visas i stället de gamla exempelsiffrorna.

| I appen | Källa | Anmärkning |
|---|---|---|
| Våttemperatur, luft, fukt (översikten) | `vader` (väderstationen) | riktig |
| Pumptryck in/ut, vattentemperatur | `pump/dep11`, `pump/dep12` | riktig |
| Ledningstryck | `ledningar` | riktig |
| Enheternas luft, fukt, våttemperatur | `enheter/*` | riktig, men gammal när kontakten är bruten |
| Teoretiskt flöde | `enheter/*/flodeTeori` | styrsystemets siffra för fullt flöde; enheten antas vara m³/h |
| Kontakt / Ingen kontakt | `senastHord` mot `meta/gssTid`, en kvart | appens egen tolkning |
| Larm och händelser | `larm`, `handelser` | riktiga; allvarlighetsgrad finns inte |
| Kurvor | `hist` (våttemperatur, tryck ut pump 2) | en punkt per fem minuter, ett dygn |
| Dammens nivå | appens egen beräkning | uttaget läses inte, se nedan |

**Visas som saknat, inte som siffror:** uppmätt flöde (per enhet och totalt),
driftläge (kör / står), dyssteg, strypning, luftflöde och vilken brunn en
enhet står vid. Kartan ritar därför inga enheter. **Fortfarande exempel:**
körfönstret (prognosen är inte inkopplad) — märkt som exempel i appen.

Händelsetexterna innehåller ledtrådar till brunnen (`Appeared S ACCESS 300
( adr = 9) to 1`, `Hydrant disconnected`), men vad siffrorna betyder är inte
utrett.

## Pumphuset enligt styrsystemets skärm (bild 16 november 2026)

Vattnets väg, från vänster till höger på skärmen "MR1 - Lidköping lvl.96m":

    dammen (Lake lvl. 95,5 m, fast text)
      -> avstängningsventil -> intagsbrunn med LPP01  = "Wdep11 / P1", matarpump
      -> Line111 / L1 -> PT01 (bar) -> XV02 / XV03 (förbigång) -> filter FI01
         (lampa "Filter clogged")
      -> PTS01 (bar, sugsidan) -> HPP01 = "Wdep12 / P2", högtryckspump
      -> TT01 (°C, vattnet) -> PT02 (bar) -> FT01 (m³/h, flödesmätare)
      -> delar sig:  Line 122 -> PT04 (bar) -> ventil -> Line 002
                     Line 121 -> PT03 (bar) -> ventil -> Line 001

**AC02 är kompressorn till luftningen av dammen** (bekräftat av Kristian 17
november): bubblingen kyler ner vattnet snabbare. Temperaturen bredvid (3 °C
på bilden) är en givare på containern, alltså pumphuset — torr
utetemperatur, och det den styr på. Kompressorn ska starta vid +3 °C eller
kallare. Automatiken var avstängd 16 november och skulle slås på dagen
efter. Varken givaren eller kompressorns läge är säkert hittade bland
kolumnerna.

Troligast är `Cooling tower_Com` (en rad, `0` = 11): kyltornet är i
Sufags system det som kyler vattnet, alltså här luftningen. Tabellen har
bara tre decimalkolumner, och sonden 15 november 18:43 såg 76 = 0, 77 = 0,
78 = 3. 78 kan vara temperaturen (stationen visade 2,9 samtidigt) eller
startgränsen +3 °C — samma siffra, så det går inte att skilja på en enda
läsning. Det finns ingen plats för både fukt och våttemperatur vid sidan om,
och en givare som bara styr en kompressor behöver ingen fukt: **pumphusets
givare mäter med stor sannolikhet bara torr temperatur.** Bryggan läser inte
tabellen; den behöver en läsning när temperaturen inte är 3 grader.

Vad det betyder för datan:

- **P1 och P2 sitter i serie.** `dep11` är matarpumpen, `dep12`
  högtryckspumpen. Deras volymer är samma vatten och får inte läggas ihop.
- **Värdena stämmer mot bilden:** `dep11/tryckUt` 0,1 = PT01, `dep12/tryckIn`
  0,1 = PTS01, `dep12/tryckUt` 7,2 = PT02, `dep12/vattenTemp` 11,9 = TT01,
  `ledningar/L121` 7,7 = PT03, `ledningar/L122` 7,2 = PT04. `L001` och `L002`
  är ledningarna ut mot spåret, `L111` matarledningen.
- **FT01 är `dep12/k125`, i m³/h.** Utpekad 25 november: när pumparna
  startade steg `k125` från 0,1 till 6–12 och stämde med skärmens 8,6, medan
  `k126` stod kvar på 0,1. Snögruppen upplever att mätaren visar ungefär
  hälften av verkligt flöde, kanske ett skalningsfel sedan den byttes —
  26 november visade den 45 % av kanonernas räknade flöde (se Flödet i
  kanonerna ovan). Appen
  visar värdet orättat. Rätt faktor tas fram mot dammen: mät med måttbandet
  före och efter en lång körning och jämför med FT01 summerat över körningen
  ur historiken. Uttaget i dammen räknas inte på FT01 förrän dess.
- **Dammens nivå mäts inte.** "Lake lvl.95,5m" är en fast text.
- Varje pump och ledning har ett läge (`stop` på bilden), och filtret en
  varningslampa. Inget av det är hittat bland kolumnerna än.
