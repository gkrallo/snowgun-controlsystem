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
| 125, 126 | båda 0,1 — den ena uppmätt flöde (FT01), den andra trycket efter filtret (PITS01) eller nivån | **osäker** |
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
lansar (TAURUS_2.0, T2N65). Adress = n° + 2.

| Kolumn | Betydelse | Säkerhet |
|---|---|---|
| 3 | n° | säker |
| 400 | lufttemperatur, °C | säker |
| 401 | luftfuktighet, % | säker |
| 402 | våttemperatur, °C | säker |
| 411 | teoretiskt vattenflöde, m³/h (statistikens `debit_eau_theorique` ÷ 10) | säker |
| 408 | 8–15 — vattentemperatur eller tryck? | **osäker** |
| 413 | 19 för n° 2, annars 0 | **osäker** |
| 415, 416 | 2/1 eller 11/50 — läge? | **osäker** |
| 702, 703 | −2 … −4 — startgränser? | **osäker** |
| 801, 802 | typ och modell | säker |
| 850 | senaste kontakt med kanonen | säker |

Uppmätt flöde (`debit_eau_reel`) och tryck (`pression_eau`) var noll och går
inte att peka ut förrän något går.

## Fläktkanoner på äldre styrkort — `[SGC300_Com]`

Två rader. n° 1 lever. n° 2 har inte hörts sedan 19 oktober 2022.

| Kolumn | Betydelse | Säkerhet |
|---|---|---|
| 2, 3, 7 | lufttemperatur, fukt, våttemperatur | säker |
| 88 | n° | säker |
| 104 | senaste kontakt | säker |

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
