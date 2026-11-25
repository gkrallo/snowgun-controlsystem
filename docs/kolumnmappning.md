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
| 411 | teoretiskt vattenflöde, m³/h (statistikens `debit_eau_theorique` ÷ 10) | säker |
| **707** | **brunnen enheten står vid** ("Shelter" på skärmen Gun searching) | **säker** — alla sju stämde 25 november: n° 1–7 = 7, 10, 9, 7, 8, 5, 8 |
| 408 (= 706) | vattentemperatur vid enheten, °C — 2,5–2,7 hos kanonerna när vattnet ut var 2,8–3,6 | trolig |
| 415 | läge: 11 för de som var OK, 1 för den som fått fel (adress 4, "fault" 21:09), 2 för den som stoppats (adress 8, "stopped" 21:08) | trolig, ett tillfälle |
| 416 | 50 för OK, 42 för felet, 1 för den stoppade — felkod eller steg? | **osäker** |
| 413 | 19 för n° 2, annars 0 | **osäker** |
| 702, 703 | −2,4/−1,9, −4/−3,5, −3/−2,5 (lansarna), −2/−1,5 — start- och stoppgräns i våttemperatur per enhet? Skillnaden är alltid 0,5 | **osäker** |
| 417 | 11–14 för kanonerna, 21 för lansarna | **osäker** |
| 852 | 9–20 för kanonerna, 50 för lansarna | **osäker** |
| 801, 802 | typ och modell | säker |
| 850 | senaste kontakt med kanonen | säker |

Händelsernas namn är "server adress brunn": `2 4 10 fault` är adress 4 vid
brunn 10, och `Disappeared S ACCESS 300 (adr = 4) from 10` säger samma sak.
Kvällen 25 november försvann adress 4, 8, 9 och 5 en i taget 21:12–21:17.
En enhet som försvinner behåller sina sista värden i tabellen, också läget i
415.

Uppmätt flöde (`debit_eau_reel`) och tryck (`pression_eau`) var noll och går
inte att peka ut förrän något går.

## Fläktkanoner på äldre styrkort — `[SGC300_Com]`

Två rader. n° 1 lever. n° 2 har inte hörts sedan 19 oktober 2022.

| Kolumn | Betydelse | Säkerhet |
|---|---|---|
| 2, 3, 7 | lufttemperatur, fukt, våttemperatur | säker |
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

- Uppmätt flöde per kanon och i pumphuset.
- Driftläge per kanon (stoppad, väntar, startar, går, fel).
- Dyssteg på lansarna.
- Vilken brunn varje kanon står vid.
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
efter. Varken givaren eller kompressorns läge är hittade bland kolumnerna.

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
  hälften av verkligt flöde, kanske ett skalningsfel sedan den byttes. Appen
  visar värdet orättat. Rätt faktor tas fram mot dammen: mät med måttbandet
  före och efter en lång körning och jämför med FT01 summerat över körningen
  ur historiken. Uttaget i dammen räknas inte på FT01 förrän dess.
- **Dammens nivå mäts inte.** "Lake lvl.95,5m" är en fast text.
- Varje pump och ledning har ett läge (`stop` på bilden), och filtret en
  varningslampa. Inget av det är hittat bland kolumnerna än.
