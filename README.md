# snowgun-controlsystem

Vad vi lär oss om **styrsystemet** (Sufag/MND GSSystem) i Lidköpings
Vintersportklubbs snöanläggning, och arbetet med att få ut **livedata** därifrån
till Firebase så att den kan visas i [snöprognos-appen](../snowgun-forecast).

Det här repot är **privat** och hålls privat — det innehåller uppgifter om
anläggningens interna styrsystem. Riktiga lösenord ligger **inte** i git (se
`SECRETS.md`, som är `.gitignore`-ad).

Hålls skilt från `snowgun-forecast` eftersom det repot är publikt via GitHub
Pages — känsliga systemuppgifter får aldrig hamna där.

## Innehåll

- [`docs/granskning-gssystem.md`](docs/granskning-gssystem.md) — granskning av
  GSSystems programfiler: arkitektur, var livedata finns (en lokal Microsoft
  SQL Server-databas), vilka tabeller som är läsbara, och förslag på väg framåt.
- `SECRETS.md` — anslutningsuppgifter (ej i git, fyll i lokalt).

## Kort sammanfattning

Styrsystemet lagrar allt — kanoner, lans, pumptryck, temperatur/vind, larm — i
en vanlig lokal SQL Server-databas (`Live_Snowstar`) på kontrollrums-PC:n i
pistmaskingaraget. Ingen reverse engineering av protokoll behövs; planen är en
liten bryggtjänst på den PC:n som läser databasen och skriver till Firestore,
som appen sedan läser av i realtid.

## Status

Granskning klar. Inget byggt eller uppkopplat mot skarpa systemet ännu.
Nästa steg: se slutet av `docs/granskning-gssystem.md`.
