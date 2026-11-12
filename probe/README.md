# Läs-only-sond mot styrdatorn

Ett PowerShell-skript (`db-sond.ps1`) som körs **en gång på styrdatorn** för
att kartlägga allt bryggan behöver veta. Det **bara läser** — skriver aldrig
till databasen, ändrar inga inställningar och skickar ingen data någonstans
(det provar bara, med en tom förfrågan, om datorn når molnet). All läsning
sker med `WITH (NOLOCK)` så styrprogrammet aldrig kan blockeras, radantal
hämtas ur systemtabeller, och stora tabeller sorteras bara om de har ett index
på datum — ingen stor tabell skannas.

Körningen tar ungefär en minut.

> **Version 2 (12 november 2026).** Den första versionen tittade bara i
> databasen `Live_Snowstar`. Omgranskningen av programfilerna visade att
> GSSystem har **fyra** databaser, och att larmen och de tabeller som har
> riktiga kolumnnamn ligger i de andra. Sonden går nu igenom alla. Den är
> provkörd hemma mot loggarna ur zip-filen, men **databasdelen har inte kunnat
> provas** — det finns ingen SQL Server att prova mot hemma. Går något snett
> där står felet i rapporten, och dator- och loggdelen sparas ändå.

Resultatet blir en textfil, `db-sond-rapport_DATUM-TID.txt`, bredvid skriptet.
**Den filen tar du med hem.** Den fångar allt vi behöver i ett svep:

- **Miljön på datorn** (körs först, även om databasen inte svarar):
  Windows- och PowerShell-version, arbetsminne, vilka av styrsystemets program
  som går och hur mycket minne de tar, klocka och tidszon, och om datorn når
  molnet med TLS 1.2. Det avgör hur bryggan byggs — så vi slipper en andra
  resa bara för att kolla förutsättningarna.
- **Loggarna** (körs också före databasen): GSSystems loggar i `BdD` och
  `concept`, och SQL Servers `ERRORLOG`. För varje fil räknas minnesfel,
  timeouts, watchdog-rader, overflow och lagringsfel, och de sista raderna
  skrivs ut. Så ser vi vad som hänt sedan zip-filen togs. Hittas inte
  GSSystems mapp automatiskt, kör om med sökvägen:
  `.\db-sond.ps1 -GsLog "C:\GSSystem"` (hitta mappen genom att högerklicka
  GSSystem-ikonen → Öppna filplats).
- **Databaserna:** version, språk och minnestak; inloggningar och roller; och
  för **var och en av de fyra databaserna** alla tabeller med radantal och
  kolumner. Små tabeller (högst 100 rader — det är där nuläget och
  apparatlistan finns) skrivs ut hela, stora med de tre senaste raderna.
  Språkdatabasen skrivs ut mer fullständigt, eftersom texterna där troligen
  förklarar de numrerade kolumnerna.

**Vad som inte följer med:** rader ur tabeller som kan innehålla lösenord
eller telefonnummer (`smtp`, `Config_SMS_*`, `SmsPort`, användartabeller) —
bara deras kolumner visas. Lösenordet du skriver in sparas inte och skrivs
aldrig ut.

Utifrån den kan vi bygga rätt bryggfrågor och färdigställa läs-only-kontot.

## Filer i den här mappen

| Fil | Vad | När |
|-----|-----|-----|
| `db-sond.ps1` | Läs-only-sonden (kartlägger datorn + databasen) | Kör på plats, först |
| `skapa-lasonly-konto.sql` | Skapar bryggans egna läs-only-konto (`db_datareader`) | Senare, när vi sett rapporten |
| `README.md` | Den här instruktionen | — |

## Så gör du på plats

1. **Lägg `db-sond.ps1` på Google Drive** hemifrån. På styrdatorn: öppna Drive i
   webbläsaren och ladda ner filen (eller ta ett USB-minne). Lägg den i en egen
   mapp, t.ex. `C:\Temp\sond\`.

2. **Öppna PowerShell i den mappen.** Enklast:
   - Öppna mappen i Utforskaren.
   - Håll inne **Shift** och **högerklicka** på tom yta i mappen.
   - Välj **"Öppna PowerShell-fönster här"** (på Windows 11 kan det stå
     **"Öppna i Terminal"**).

   Ett fönster öppnas, redan i rätt mapp. (Alternativt: Start → skriv
   *PowerShell* → Enter, och gå dit med `cd C:\Temp\sond`.)

3. **Kör sonden.** Klistra in raden och tryck Enter. Prova först
   Windows-inloggning (inget lösenord behövs om din Windows-användare har
   åtkomst):
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\db-sond.ps1
   ```
   `-ExecutionPolicy Bypass` behövs ofta för att Windows annars blockerar
   nedladdade skript. Det gäller bara den här körningen — inget ställs om
   permanent.

   > **Om Windows säger att filen är blockerad eller "inte betrodd":**
   > högerklicka på `db-sond.ps1` → **Egenskaper** → bocka i
   > **"Fjärrblockering upphävd"** (Unblock) längst ned → **OK**. Kör sedan igen.

4. **Om anslutningen misslyckas** står det i fönstret — och det gör den
   troligen första gången, eftersom GSSystem själv loggar in med ett
   SQL-konto och Windows-användaren sällan har åtkomst. Kör då med
   styrsystemets inloggning. Skriptet frågar efter lösenordet; **ta med det
   från `SECRETS.md` hemma** (på en lapp eller i telefonen — inte i en fil på
   styrdatorn):
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\db-sond.ps1 -User GSS_Login
   ```
   Skriptet provar själv de adresser GSSystem använder
   (`127.0.0.1\SQLEXPRESS,1433`, `localhost\SQLEXPRESS` m.fl.). Skulle ingen
   fungera kan du ange en egen:
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\db-sond.ps1 -User GSS_Login -Server "DATORNAMN\SQLEXPRESS"
   ```
   Skriver loggkollen *"Hittade ingen loggmapp automatiskt"*, peka på GSSystems
   mapp så den hittar loggarna (flaggorna går att kombinera):
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\db-sond.ps1 -GsLog "C:\GSSystem"
   ```

5. **Ta med rapporten hem.** Sökvägen skrivs ut sist i fönstret
   (`...\db-sond-rapport_DATUM-TID.txt`). Lägg upp den på Drive igen eller på
   USB-minnet. Skriptet lämnar inga spår i databasen.

> **Vill du prova hemma först?** Kör den på din egen dator — du får då bara
> "anslutning misslyckades" (databasen finns inte där), men miljökollen högst
> upp körs ändå, så du ser hur det ser ut. Sonden bara läser och kan inte råka
> ändra eller stoppa något i anläggningen.

## Passa på medan du är där

Datorn, nätet och databaserna tar sonden reda på själv. Det enda **du**
behöver göra för hand är det sonden inte kan se: vad skärmen visar i samma
ögonblick.

- **Fota kontrollrumsskärmen strax före eller efter att du kör sonden** —
  bilden som visar flöden, våttemperatur och status per kanon/lans, och gärna
  bilden för pumphuset. Då kan vi para ihop ett tal i en kolumn med rätt
  apparat och storhet. Bäst är om något går, men även en stillastående
  anläggning visar temperaturer och lägen.
- **Fota apparatlistan** om det finns en sådan bild (vilken kanon som har
  vilket nummer och vilken adress). Loggarna visar sju apparater av en typ och
  fyra av en annan, och vi vet inte vilken som är vilken.
- **Titta efter en nivågivare i dammen** i pumphusbilden. Databasen har ett
  fält för magasinsnivå; finns givaren kan appen läsa nivån i stället för att
  räkna fram den.

## Nästa steg: läs-only-kontot (`skapa-lasonly-konto.sql`)

Det här kör vi **inte** blint på första besöket — vi tittar först på
sondrapporten så vi vet hur inloggningarna ser ut. Sedan:

1. Öppna `skapa-lasonly-konto.sql` och **byt ut lösenordet** mot ett riktigt,
   starkt. Spara det riktiga lösenordet bara i `SECRETS.md` (gitignore-ad).
2. Kör som sysadmin, t.ex.:
   ```powershell
   sqlcmd -S 127.0.0.1\SQLEXPRESS -E -i skapa-lasonly-konto.sql
   ```
3. Det skapar kontot `snogrupp_ro` med **enbart läsrätt** (`db_datareader`) i
   var och en av de fyra databaserna — det kan inte ändra något. Bryggan
   använder sedan det kontot i stället för det hårdkodade `GSS_Login`.

Skriptet går att köra om, och har en bortkommenterad del som tar bort kontot
igen. Det är det enda vi någonsin kör som ändrar något i SQL Server, och det
är inte provkört än — vi går igenom det mot sondrapporten innan det körs.

## Säkerhet

- Skriptet innehåller **inga lösenord** — det frågar vid behov. Lägg aldrig det
  verkliga lösenordet i någon fil som hamnar i git; det hör hemma i `SECRETS.md`
  (gitignore-ad) om vi behöver spara det.
- Rapportfilen kan innehålla driftvärden. Den ligger lokalt / på din Drive —
  **lägg inte upp den i något publikt repo.**
- Hela övningen är läs-only och i linje med de hårda reglerna i
  [`../docs/arkitektur-och-risker.md`](../docs/arkitektur-och-risker.md).
