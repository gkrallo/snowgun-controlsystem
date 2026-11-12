# Läs-only-sond mot styrsystemets databas

Ett litet PowerShell-skript (`db-sond.ps1`) som körs **en gång på styrdatorn**
för att kartlägga databasen `Live_Snowstar` inför bryggan. Det **bara läser** —
skriver aldrig, ändrar inga inställningar, skickar inget någonstans. All läsning
sker med `WITH (NOLOCK)` så styrprogrammet aldrig kan blockeras, och radantal
hämtas ur systemtabeller så inga stora tabeller skannas.

Resultatet blir en textfil, `db-sond-rapport_DATUM-TID.txt`, bredvid skriptet.
**Den filen tar du med hem** — där står versionen, nätverksuppgifter, tabeller,
kolumner och några smakprovsrader. Utifrån den kan vi bygga rätt bryggfrågor och
planera ett eget läs-only-konto.

## Så gör du på plats

1. **Lägg `db-sond.ps1` på Google Drive** hemifrån. På styrdatorn: öppna Drive i
   webbläsaren och ladda ner filen (eller ta ett USB-minne). Lägg den i en egen
   mapp, t.ex. `C:\Temp\sond\`.

2. **Öppna PowerShell** (Start → skriv *PowerShell* → Enter) och gå till mappen:
   ```powershell
   cd C:\Temp\sond
   ```

3. **Kör sonden.** Prova först Windows-inloggning (inget lösenord behövs om din
   Windows-användare har åtkomst):
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\db-sond.ps1
   ```
   `-ExecutionPolicy Bypass` behövs ofta för att Windows annars blockerar
   nedladdade skript. Det gäller bara den här körningen.

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

5. **Ta med rapporten hem.** Sökvägen skrivs ut sist i fönstret
   (`...\db-sond-rapport_DATUM-TID.txt`). Lägg upp den på Drive igen eller på
   USB-minnet. Skriptet lämnar inga spår i databasen.

## Passa på medan du är där

Sonden kan läsa tabellerna, men **inte** vad de numrerade kolumnerna i
`SGC300_Main` / `SGC400_Main` betyder. Det ser bara du, genom att jämföra med
skärmen:

- **Fota kontrollrumsskärmen** när något faktiskt körs — bilden som visar
  flöden, våttemperatur, status per kanon/lans. Då kan vi para ihop ett tal i
  en kolumn med rätt kanon och storhet.
- **Notera om datorn når internet utåt** (öppna en vanlig webbsida). Bryggan
  behöver bara utgående anslutning — aldrig någon port in.
- Kolla gärna om det står **Python** eller **Node** installerat (inte
  nödvändigt, men avgör vilket språk bryggan skrivs i).

## Säkerhet

- Skriptet innehåller **inga lösenord** — det frågar vid behov. Lägg aldrig det
  verkliga lösenordet i någon fil som hamnar i git; det hör hemma i `SECRETS.md`
  (gitignore-ad) om vi behöver spara det.
- Rapportfilen kan innehålla driftvärden. Den ligger lokalt / på din Drive —
  **lägg inte upp den i något publikt repo.**
- Hela övningen är läs-only och i linje med de hårda reglerna i
  [`../docs/arkitektur-och-risker.md`](../docs/arkitektur-och-risker.md).
