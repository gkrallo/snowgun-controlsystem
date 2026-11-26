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
| 121 | tryck in, bar (PT01 = 0,1) | säker |
| 122 | vattentemperatur, °C (TT01 = 11,8) | säker |
| 123 | tryck ut, bar (PT02 = 7,2; 0,1 för avgång 11) | säker |
| 124 | temperatur ut, °C | säker (statistikens `temperature_refoulement`) |
| 125 | uppmätt flöde ut, m³/h (FT01) — steg till 6–12 när pumparna startade 25 november och följde skärmen (8,6). **Mätaren misstänks visa ungefär hälften.** | säker att det är FT01; storleken okontrollerad |
| 126 | stod på 0,1 även när pumpen gick — inte flödet; kanske trycket efter filtret (PITS01) | **osäker** |
| 128 | maxflöde, 70 m³/h | säker |
| 158 | senaste kontakt | säker |

Statistikens `niveau_lac` är konstant 1 och `MapLevel` är tom: det finns
ingen nivågivare i dammen. "Lake lvl. 95,5 m" på skärmen är en fast text.

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

### Snömängden är vattnet × 2,2

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

För att para resten behövs skärmbilder av Visualisation i andra lägen, med
klockslag: en stoppad kanon, en med fel, en lans som går, och när ring 3
eller 4 öppnas. Med bryggan 7 på styrdatorn behövs ingen `-Ra` — bitarna och
tiden finns i historiken.

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
| **10** | **"Theoretic water flow", m³/h** | trolig — 5,8 som 5; n° 2, tyst sedan 2022, har 15,5 där och 0 i 5 utan tryck, som 411/406 på SGC400 |
| **5** | **"Real water flow", m³/h** | trolig (samma skäl). Skärmen visade 4,7 teoretiskt och 5,4 real tidigare samma morgon, så de är inte alltid lika |
| 9 | startgräns, °C (−2 som skärmen) | trolig |
| 14 | "Flow max limit", m³/h (24,1; skärmen 24) | trolig |
| 21 | 3,7–3,8 både stående och gående — inte flödet | **osäker** |
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
