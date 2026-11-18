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

## Status (17 november 2026)

Hela kedjan går sedan 16 november, och appen ligger på egen adress sedan 17
november.

Kvar att göra:

- **Läs-only-konto i SQL.** Bryggan går tills vidare med styrsystemets eget
  konto, som ett uttalat avsteg. Väntar på leverantören.
- **Uppmätt flöde, driftläge och brunn per enhet** saknas i datan. Går att
  hitta först när anläggningen kör.
- **Backup av styrdatorn** finns inte.
- En omstart av styrdatorn är inte provad.
