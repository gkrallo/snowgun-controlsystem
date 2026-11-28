# snowgun-controlsystem

Driftövervakning av snöanläggningen vid Lidköpings Vintersportklubb: en brygga
som läser nuläget ur **styrsystemet** (Sufag/MND GSSystem), och appen
**Snökoll** som visar det för snögruppen.

**Appen: https://snow.pettersson.app** — kräver inloggning med Google och att
adressen står i medlemslistan.

Det här repot är **privat** och hålls privat — det innehåller uppgifter om
anläggningens interna styrsystem. Riktiga lösenord ligger **inte** i git (se
`SECRETS.md`, som är `.gitignore`-ad). Det hålls skilt från
[`snowgun-forecast`](../snowgun-forecast), prognosappen, som är publik.

Allt här **läser bara**. Varken bryggan eller appen kan starta, stoppa eller
ändra något i anläggningen.

## Hur det hänger ihop

    styrsystemets databas  ->  bryggan  ->  Firebase  ->  appen Snökoll
    (SQL Server på             (PowerShell     (Realtime     (snow.pettersson.app,
     styrdatorn)                på styrdatorn)  Database)     går att installera)

Bryggan läser var 20:e sekund och skickar bara det som ändrats. Den öppnar
ingen port in till styrdatorn.

## Innehåll

- `app/` — appen Snökoll: en fil (`index.html`), plus det som gör den
  installerbar.
- `bridge/` — bryggan och autostarten. Börja i [`bridge/README.md`](bridge/README.md).
- `firebase/` och `firebase.json` — databasens regler och utläggningen.
- `probe/` — sonden som kartlade databasen, och skriptet för läs-only-kontot.
- `docs/` —
  [`anvandarhantering.md`](docs/anvandarhantering.md) (vem som får se vad,
  adresser, installation),
  [`kolumnmappning.md`](docs/kolumnmappning.md) (vilket värde som är vad, och
  pumphuset),
  [`damm-matningar.md`](docs/damm-matningar.md) (dammen),
  [`plan-brygga-firebase.md`](docs/plan-brygga-firebase.md),
  [`arkitektur-och-risker.md`](docs/arkitektur-och-risker.md),
  [`granskning-gssystem.md`](docs/granskning-gssystem.md),
  [`ideer-och-roadmap.md`](docs/ideer-och-roadmap.md).
- `CLAUDE.md` — projektanteckningarna: regler, läget och fallgropar.
- `SECRETS.md` — lösenord (inte i git, fylls i lokalt).

## Prov

Från repots rot, före varje incheckning:

    node --test test/app.test.mjs test/sw.test.mjs
    firebase emulators:exec --only database --project demo-snokoll "node --test test/regler.test.mjs"
    cd functions; npm test
    powershell -ExecutionPolicy Bypass -File bridge\brygga.ps1 -Sjalvtest

Regelproven går mot Firebases lokala emulator (kräver Java) och rör aldrig
den riktiga databasen.

## Status (28 november 2026)

Hela kedjan går sedan 16 november: appen på egen adress sedan 17 november,
pushlarm sedan 26 november, körfönster ur riktig prognos sedan 28 november.
Kodgranskningen 28 november är åtgärdad i koden; vad som är utlagt och
installerat står i `CLAUDE.md`.

Kvar att göra:

- **Läs-only-konto i SQL.** Bryggan går tills vidare med styrsystemets eget
  konto, som ett uttalat avsteg. Väntar på leverantören.
- **Flödesmätaren FT01** ska ställas in av elektrikern; appen rättar värdet
  tills dess.
- **Backup av styrdatorn** finns inte.
- En omstart av styrdatorn är inte provad.
