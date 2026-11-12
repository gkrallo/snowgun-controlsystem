# Läs-only-sond mot styrsystemets databas

Ett litet PowerShell-skript (`db-sond.ps1`) som körs **en gång på styrdatorn**
för att kartlägga databasen `Live_Snowstar` inför bryggan. Det **bara läser** —
skriver aldrig, ändrar inga inställningar, skickar inget någonstans. All läsning
sker med `WITH (NOLOCK)` så styrprogrammet aldrig kan blockeras, och radantal
hämtas ur systemtabeller så inga stora tabeller skannas.

Resultatet blir en textfil, `db-sond-rapport_DATUM-TID.txt`, bredvid skriptet.
**Den filen tar du med hem.** Den fångar allt vi behöver i ett svep:

- **Miljön på datorn** (körs först, även om databasen inte svarar): om Python
  eller Node finns, vilka ODBC-drivrutiner som är installerade, och om datorn
  når molnet utåt på port 443. Det avgör hur bryggan byggs — så vi slipper en
  andra resa bara för att kolla förutsättningarna.
- **Loggkollen** (körs också före databasen): söker igenom GSSystems loggmapp
  och SQL Servers `ERRORLOG` efter minnesfel ("insufficient system memory") och
  watchdog-krascher — samma sak som dök upp i zip-granskningen. Så ser vi om
  felen fortfarande pågår, vilken fil och rad de står på, och hur snålt bryggan
  måste köra. Hittas inte GSSystems mapp automatiskt, kör om med sökvägen:
  `.\db-sond.ps1 -GsLog "C:\...\GSSystem"` (hitta mappen genom att högerklicka
  GSSystem-ikonen → Öppna filplats).
- **Databasen:** version, om TCP/IP är på och vilken port, inloggningar och
  roller, alla tabeller med radantal, kolumnerna i nyckeltabellerna och några
  smakprovsrader.

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

4. **Om anslutningen misslyckas** står det i fönstret. Kör då med
   styrsystemets SQL-inloggning i stället — skriptet frågar efter lösenordet
   (det hämtas ur GSSystems inställningar / den som installerade systemet):
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\db-sond.ps1 -User GSS_Login
   ```
   Heter instansen något annat än `127.0.0.1\SQLEXPRESS` kan du ange den:
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\db-sond.ps1 -Server "DATORNAMN\SQLEXPRESS"
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

Internet, Python/Node och ODBC-drivrutiner tar sonden reda på själv. Det enda
**du** behöver göra för hand är det sonden inte kan se: vad de numrerade
kolumnerna i `SGC300_Main` / `SGC400_Main` betyder.

- **Fota kontrollrumsskärmen** när något faktiskt körs — bilden som visar
  flöden, våttemperatur, status per kanon/lans. Då kan vi para ihop ett tal i
  en kolumn med rätt kanon och storhet.

## Nästa steg: läs-only-kontot (`skapa-lasonly-konto.sql`)

Det här kör vi **inte** blint på första besöket — vi tittar först på
sondrapporten så vi vet hur inloggningarna ser ut. Sedan:

1. Öppna `skapa-lasonly-konto.sql` och **byt ut lösenordet** mot ett riktigt,
   starkt. Spara det riktiga lösenordet bara i `SECRETS.md` (gitignore-ad).
2. Kör som sysadmin, t.ex.:
   ```powershell
   sqlcmd -S 127.0.0.1\SQLEXPRESS -E -i skapa-lasonly-konto.sql
   ```
3. Det skapar kontot `snogrupp_ro` med **enbart läsrätt** (`db_datareader`) —
   det kan inte ändra något i databasen. Bryggan använder sedan det kontot i
   stället för det hårdkodade `GSS_Login`.

Scriptet har `IF NOT EXISTS`-skydd (går att köra om) och en bortkommenterad
del som tar bort kontot igen om ni vill.

## Säkerhet

- Skriptet innehåller **inga lösenord** — det frågar vid behov. Lägg aldrig det
  verkliga lösenordet i någon fil som hamnar i git; det hör hemma i `SECRETS.md`
  (gitignore-ad) om vi behöver spara det.
- Rapportfilen kan innehålla driftvärden. Den ligger lokalt / på din Drive —
  **lägg inte upp den i något publikt repo.**
- Hela övningen är läs-only och i linje med de hårda reglerna i
  [`../docs/arkitektur-och-risker.md`](../docs/arkitektur-och-risker.md).
