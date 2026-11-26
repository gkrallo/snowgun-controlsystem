# Pushlarm till telefonen

26 november 2026. Förslaget nedan, och sedan samma dag **byggt men inte
utlagt** — se "Byggt 26 november" längst ner. Bygger på det vi har: appen
Snökoll som installerad webbapp på Firebase Hosting, Firebase Realtime
Database och bryggan som bara läser styrsystemet.

## Grundtanke

Bryggan fortsätter som nu: läser, skickar till `/live` och `/hist`, inget
mer. Larmen räknas fram **i Firebase**, av två små funktioner (Cloud
Functions), och skickas med Firebase Cloud Messaging (FCM) som vanliga
notiser till telefonerna. Appen och funktionerna styr ingenting i
anläggningen, och styrsystemets egna larm och skydd gäller som förut. Det
här är ett komplement, inte ett skydd.

Varför inte låta bryggan skicka larmen:

- Bryggan skulle behöva en servicenyckel med makt över hela projektet. Den
  håller vi borta från styrdatorn.
- Stannar styrdatorn eller bryggan kommer inga larm alls, och ingen märker
  det. En funktion i molnet kan larma just när bryggan tystnar.

## Delarna

```
styrsystemet --SQL--> bryggan --> /live, /hist      (som nu)
                                     |
                       Cloud Function "bedom" (vid varje ändring i /live)
                       Cloud Function "vakt"  (varannan minut)
                                     |
                         /larmlage   (vad som larmar, sedan när, kvitterat av)
                                     |
                         FCM --> telefonerna som prenumererar
```

1. **Appen** frågar en gång om lov att visa notiser och sparar telefonens
   FCM-adress under `/notis/{uid}/{enhet}`. Alla larm går till alla
   telefoner som slagit på dem. Service workern (`sw.js`) visar notisen och öppnar rätt vy
   när man trycker på den.
2. **"bedom"** körs när bryggan skrivit i `/live`. Den jämför med
   `/larmlage` och skickar bara när ett larm *börjar* eller *går över*.
3. **"vakt"** körs varannan minut. Den larmar om `meta/ts` är äldre än tio
   minuter (bryggan eller styrdatorn tyst) och om ett kvitterat larm
   fortfarande står kvar efter en timme.
4. **Kvittera** i appen skriver vem och när i `/larmlage`, och övriga får en
   tyst uppdatering: "Kristian tar det".

## Larm att börja med

| Larm | Villkor (förslag) | Varför |
|---|---|---|
| Kanon stannad eller fel | `k415` går från 6 (kör) till 1 (fel) eller 2 (stoppad) under ett körpass, eller flödet faller till 0 | Frysrisk i slang och kanon |
| Kanon tappar kontakten | `senastHord` äldre än 5 min för en enhet som körde | Samma |
| Bryggan tyst | `meta/ts` äldre än 10 min | Annars kan alla andra larm vara tysta utan att någon vet det |
| Nära stoppgränsen | våttemperaturen mindre än 0,5 °C från kanonens stoppgräns (`703`) och stigande senaste halvtimmen | Hinna förbereda innan kanonerna stannar |
| Nytt larm i styrsystemet | ny rad i `live/larm` | Det som redan syns under Larm i appen |
| Pumptrycket faller | `PT02` sjunker mer än 2 bar på några minuter medan kanoner kör | Läcka, brusten slang, pumpstopp |
| Dammen | under lägsta driftnivå inom 6 h, eller över varningsnivån | **Vänta** tills uttaget ur kanonerna (timvattnet, version 11) har stämt mot måttbandet ett par gånger |

Gränserna är förslag och ska sättas av snögruppen. De står på ett ställe i
funktionen, så att de går att ändra utan att röra resten.

Varje larm har en **spärr**: samma larm skickas en gång och inte igen förrän
det gått över (eller efter en timme okvitterat). Ett **körpass** är när
minst en kanon har kört de senaste 30 minuterna, så att en avstängd
anläggning på sommaren inte larmar.

## Vad som behövs

- **Betalplanen Blaze** i Firebase-projektet `snoprognos`, med ett kort.
  Cloud Functions kräver det. Med vår mängd (en funktion några gånger i
  minuten, notiser några gånger i veckan) ligger det långt inom
  gratiskvoten. Sätt en budgetvarning på till exempel 50 kr i månaden.
  Det är Kristians beslut.
- **Nya regler** i `firebase/database.rules.json`: `/notis/{uid}` får bara
  ägaren läsa och skriva, `/larmlage` får medlemmar läsa och bara
  kvitteringsfältet skriva.
- **En ny mapp** `functions/` i repot (Node.js, Firebase-verktygen). Det är
  första koden som kräver npm i det här repot, men den körs i molnet och
  rör inte appen, som fortfarande är en enda fil utan bygge.
- **Appen**: reglage för att slå på larm på telefonen,
  kvittering. Service workern behöver Firebase Messaging.

## Telefonerna

- **Android**: fungerar i Chrome, installerad eller inte.
- **iPhone**: bara om appen är tillagd på hemskärmen och telefonen har iOS
  16.4 eller senare. Notiserna kommer då som från en vanlig app.
- En notis kan bli fördröjd när telefonen sparar ström. Det är inte ett
  larm som väcker någon garanterat — för det behövs SMS eller samtal, som
  kan läggas till senare (till exempel via en SMS-tjänst från funktionen).

## Ordning

1. Kristian slår på Blaze och sätter budgetvarningen.
2. Appen: slå på notiser, spara adressen, en provnotis till sig själv.
3. "vakt" med larmet Bryggan tyst — det enklaste och det viktigaste.
4. "bedom" med kanon stannad, fel och kontakt.
5. Kvittering.
6. Nära stoppgränsen, styrsystemets larm, pumptrycket.
7. Dammen, när uttaget visat sig stämma.

## Bestämt 26 november (Kristian)

- **Alla medlemmar får alla larm.** Den som inte vill stänger av i appen
  eller i telefonens inställningar för just Snökoll. Det gäller bara den här
  appen, inte hela Chrome.
- **Inga tysta timmar i appen.** Det körs ofta på natten, så larmen går fram
  dygnet runt. Vill man ha tyst använder man telefonens Stör ej.
- **Ingen "i tjänst"** än. Kan bli en senare funktion.

Det gör appen enklare: ett reglage "Larm på den här telefonen" och
kvittering, inga val per larm och inga tider.

## Byggt 26 november

Steg 2–6 i ordningen ovan, utom nära stoppgränsen och pumptrycket. Inget
är utlagt.

**En funktion i stället för två.** `functions/index.js` har bara "vakt",
som körs varje minut. Larmet "Bryggan är tyst" måste komma just när
bryggan inte skriver, och då händer inget som kan starta en funktion. En
minut räcker för de andra larmen också, och det blir bara en sak att
förstå.

**Logiken** ligger för sig i `functions/larm.js`, utan Firebase, och provas
med `node --test larm.test.js` i `functions/` (14 prov). Gränserna står i
`GRANS` överst:

| Larm | Gräns |
|---|---|
| Bryggan är tyst | `meta/ts` äldre än 10 min |
| Bryggan når inte styrsystemet | `sqlOk` falskt i 3 min |
| Kanon har stannat / står i fel / har stoppats | körde (läge 6, eller flöde på SGC300) inom 30 min och har inte kört på 3 min |
| Kanon hörs inte | samma, men styrsystemet har inte hört den på 5 min |
| Larm i styrsystemet | ett nytt id i `live/larm` (bara notis, inget att kvittera) |

- Stannar flera samtidigt blir det **en** notis ("3 larm").
- När ett larm går över kommer en **tyst** notis som byter ut larmet på
  telefonen ("Kanon 5 kör igen").
- Ett okvitterat larm **påminner en gång** efter en timme.
- **Jag tar det** i appen kvitterar för alla och ger en tyst notis "Kristian
  tar det". Bara den första kvitteringen gäller (reglerna).
- Ett kanonlarm som står kvar i **12 timmar** tas bort (kanonen flyttad
  eller avstängd efter passet), och larmar inte igen förrän den kört.
- Medan bryggan är tyst bedöms inget annat: gamla värden får inte se nya ut.

**Mottagare** är den som slagit på larmen i appen (`/notis/<uid>/<telefon>`)
och fortfarande står under `/members` med bekräftad adress. En död adress
(appen borttagen, notiser avslagna) tas bort när FCM säger det.

**Appen**: överst under Larm finns "Larm till den här telefonen" med Slå på,
Stäng av och Skicka en provnotis. Pushlarmen står överst i larmlistan med
knappen Jag tar det. Service workern (`sw.js`, nu `snokoll-v4`) visar
notisen och öppnar appen på `#larm`.

**Provat**: logiken i `larm.test.js`, och hela funktionen mot Firebases
emulator med FCM utbytt mot en atrapp. Appens larmsida i
förhandsvisningen. En riktig notis till en telefon är inte provad, den
kräver att allt är utlagt.

**Utlagt 26 november.** Blaze och budgeten fanns redan, nyckeln är
inlagd, och funktionen kör sedan 16:20. Standardkontot behövde fyra roller
(se CLAUDE.md). Hostingen kom inte med första gången och lades ut för sig.
Första provnotisen stannade hos FCM (`cloudmessaging.messages.create
denied`) tills kontot fick Firebase Cloud Messaging API Admin. Efter det
kom provnotisen fram till Kristians Android samma kväll. Svaret på senaste
provet står i `/larmlage/prov`. Kvar: prova på iPhone.

### Kvar innan det kan läggas ut (gjort)

1. **Blaze** i projektet `snoprognos` och en budgetvarning (Kristian).
2. **Nyckeln för webbnotiser**: Firebase-konsolen → Projektinställningar →
   Cloud Messaging → Web Push certificates → Generate key pair. Den
   offentliga nyckeln (lång rad som börjar med B) skrivs in som
   `window.notisNyckel` i `app/index.html`. Den är offentlig och får stå i
   koden. Utan den säger appen att larmen inte är påslagna.
3. Lägg ut: `firebase deploy --only database,hosting,functions`. Första
   gången slår Firebase på Cloud Functions, Cloud Build, Artifact Registry
   och Cloud Scheduler i projektet. Svara ja på frågan om att rensa gamla
   byggen (annars växer lagringen sakta).
4. Slå på larmen i appen och skicka en provnotis, på Android och iPhone.
