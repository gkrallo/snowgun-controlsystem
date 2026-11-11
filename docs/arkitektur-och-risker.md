# Arkitektur, risker och beslut — livedata från styrsystemet

Levande beslutsdokument. Här står *hur* vi tänker bygga övervakningen, *vilka
risker* som måste respekteras, och *vilka val* vi redan gjort. Läs
[`granskning-gssystem.md`](granskning-gssystem.md) för de tekniska fynden om
själva styrsystemet.

---

## Beslut (2026-11-11)

1. **Bara läsning och övervakning.** Appen ska aldrig kunna styra anläggningen
   — inte starta/stoppa kanoner, inte ändra något. För de få gånger man
   verkligen måste styra finns **Google Remote Desktop** mot kontrollrums-PC:n
   (bökigt på mobil, men fungerar). Övervakning på håll är det vi bygger.
2. **Inloggning krävs.** Datan är **inte** för allmänheten. Bara snögruppen ska
   komma åt den.
3. **Egen app, skild från den publika prognosappen.** Koden bor i det här
   privata repot, helt isär från det öppna `snowgun-forecast`. Motivering
   nedan.

---

## Arkitektur

```
  Kontrollrums-PC (pistmaskingaraget)
  ┌───────────────────────────────────────────┐
  │  GSSystem + SQL Server (Live_Snowstar)     │
  │              ▲                             │
  │              │  SELECT, read-only, var ~20s │
  │         ┌────┴─────┐                         │
  │         │  Bryggan │  (litet eget program)   │
  │         └────┬─────┘                         │
  └──────────────┼────────────────────────────┘
                 │  HTTPS, bara UTÅT
                 ▼
            Firebase (snoprognos)
              ├─ Realtime Database  → live mätvärden (kanon, väder, larm)
              └─ Firestore          → sällan ändrad data (säsongsstatistik)
                 │  kräver inloggning (Firebase Auth)
                 ▼
        Övervakningsappen (PWA, telefon/dator — hemma eller i spåret)
```

- **Bryggan** är ett litet eget program som kör på kontrollrums-PC:n. Den
  läser några få tabeller ur SQL-databasen, jämför med förra värdet och
  skickar bara ändringar vidare till Firebase.
- **Trafiken går bara utåt.** PC:n ringer upp molnet; inget öppnas in mot PC:n.
- **Appen** läser Firebase i realtid (`onSnapshot`) bakom inloggning.

---

## HÅRDA REGLER — får aldrig glömmas

Det här är de risker vi måste vara extra försiktiga med. Bryt dem inte utan att
medvetet tänka om hela säkerhetsbilden.

### Mot det skarpa styrsystemet (viktigast — det rör anläggningen)
1. **Skriv ALDRIG till SQL-databasen.** Använd ett konto med *enbart*
   läsrättighet (`db_datareader`). Inte det inbyggda `GSS_Login`, och framför
   allt aldrig `sa`.
2. **Läs med `WITH (NOLOCK)`** (eller läs-ögonblicksbild) så våra läsningar
   aldrig kan låsa eller blockera styrprogrammet — och tvärtom. För övervakning
   gör det inget om en läsning är en bråkdels sekund "smutsig".
3. **Läs bara de små nulägestabellerna.** Aldrig tunga JOIN:ar eller full
   genomsökning av de stora statistiktabellerna (de växer hela säsongen).
4. **Tung analys bara mot en återställd kopia** av backupen
   (`BdD\Live_Snowstar.dat`), aldrig mot den skarpa databasen.
5. **Bryggan ska vara lätt.** Kontrollrums-PC:n är gammal och ansträngd —
   loggarna visar riktiga minnesfel ("insufficient system memory") och
   watchdog-krascher. Liten minnesanvändning, inga tunga beräkningar.

### Mot nätet och säkerheten
6. **Bara utåtgående trafik.** Öppna aldrig en port *in* mot kontrollrums-PC:n.
   Kör bryggan på PC:n själv.
7. **Lösenord och nycklar aldrig i git.** Platshållare i spårbara filer, riktiga
   värden i `SECRETS.md` (gitignore-ad). Gäller både SQL-inloggningen och
   Firebase-nyckeln.
8. **Firebase-regler måste låsas och testas:** bara bryggan får *skriva*, bara
   inloggade användare får *läsa*. Utan det kan vem som helst läsa eller mata in
   falska värden.

### Mot vilseledande data
9. **Varje mätvärde ska bära en tidsstämpel, och appen ska varna för gammal
   data.** Om bryggan dör eller nätet faller får en gammal siffra ALDRIG se
   live ut. Den som övervakar hemifrån måste kunna lita på att "kanon igång"
   betyder igång *nu*.
10. **Bryggan ska auto-starta** om PC:n bootar om (Windows-tjänst eller
    schemalagd uppgift vid inloggning), annars tystnar flödet tyst.

### Mot kostnader
11. **Sätt ett budgetlarm i Google Cloud** så en skenande bugg aldrig
    överraskar.
12. **Skriv bara vid ändring** (dödband — hoppa över småskvalp), och håll
    pollintervallet rimligt (15–30 s, aldrig 1 s). Realtime Database för
    strömmen (billig per datamängd), Firestore bara för sällan ändrad data.

---

## Varför en separat app (min bedömning)

Din instinkt är rätt — håll det isär. Skälen:

- **Källkoden hålls privat.** Den här appen kommer innehålla tabellmappningar,
  bryggans logik och detaljer om styrsystemet. Det hör inte hemma i det öppna
  prognos-repot, som vem som helst kan läsa.
- **Prognosappen hålls ren.** `snowgun-forecast` har en tydlig själ: öppen, utan
  bygg, "ska gå att öppna och felsöka av en icke-programmerare". Att bulta på
  inloggning och live-telemetri på den grumlar det.
- **Olika publik, olika syfte.** Prognosen är öppen för alla; driftövervakningen
  är intern och bakom lås.

Så den riktiga säkerhetsvinsten med ett eget privat repo är att *koden* stannar
privat. Själva skyddet av *datan* sköts av Firebase Auth oavsett var appen körs
— att en app-sida går att ladda är inte säkerhetsgränsen; den inloggningsgrän‑
sade datan är det.

**Not om hosting:** Firebase-projektet har ingen Hosting påslagen i dag. Vill vi
lägga appen på Firebase Hosting (naturligt, eftersom Auth och databas redan
finns där) är det ett nytt steg att aktivera. Alternativt kör vi den internt
till att börja med. GitHub Pages passar inte — det kräver betald plan för
privata repon, och vi vill inte servera den här appen publikt ändå.

---

## Öppna frågor och nästa steg

1. **Bekräfta SQL-schemat** med en försiktig, read-only-probe på kontrollrums-
   PC:n innan något byggs — särskilt de numrerade kolumnerna i `SGC300_Main`
   m.fl., som i dag är kvalificerade gissningar.
2. **Bestäm hosting** för övervakningsappen (Firebase Hosting eller internt).
3. **Skapa läs-only SQL-kontot** på PC:n.
4. **Välj språk för bryggan** (Python eller Node — båda fungerar; Python med
   `pyodbc` är enkelt mot SQL Server).
5. **Bygg bryggan**, sedan appen.

Inget av detta är gjort ännu — allt bygger på offline-granskning av
programfilerna.
