# Användare och åtkomst

Vem som får se driftdatan, hur man släpper in och tar bort någon, och vilka
regler som skyddar den. Hör ihop med
[`plan-brygga-firebase.md`](plan-brygga-firebase.md).

**Egen adress sedan 17 november 2026: https://snow.pettersson.app.** Det är
den adress folk ska få. Inloggning är provad därifrån, både på dator och från
telefon, och appen går att lägga på hemskärmen från den. Domänen
ligger hos Cloudflare, med en CNAME `snow` -> `snoprognos.web.app` och grått
moln (DNS only; med Cloudflares proxy kan Firebase inte utfärda certifikatet).
Fyra ställen måste känna till en ny adress, annars fungerar inte
inloggningen:

1. Firebase -> Hosting -> Add custom domain (utan redirect).
2. Firebase -> Authentication -> Settings -> Authorized domains.
3. Google Cloud -> Credentials -> API-nyckeln: `https://snow.pettersson.app/*`
   under Website restrictions. Raden `https://snoprognos.firebaseapp.com/*`
   ska stå kvar — bryggan använder den som `referer`.
4. Google Cloud -> Credentials -> OAuth-klienten:
   `https://snow.pettersson.app/__/auth/handler` under Authorized redirect
   URIs, och adressen utan sökväg under Authorized JavaScript origins.

Appen väljer inloggningsadress efter var den öppnas (`AUTH_HOST`), eftersom
inloggning i samma flik på telefon kräver att den är samma som appens egen.
Den gamla adressen fungerar fortfarande. En installerad app hör till sin
adress, så den som vill ha den nya lägger till appen på hemskärmen därifrån.

**Appen låg först på https://snoprognos.firebaseapp.com**, från 16 november 2026
(Firebase Hosting, mappen `app`). Den adressen fungerar fortfarande. Lägg ut en ny version från repots rot med
`firebase deploy --only hosting`, och reglerna med
`firebase deploy --only database` — `firebase.json` ligger i roten, eftersom
verktyget inte får peka på en mapp utanför sin egen. Syskonadressen
`snoprognos.web.app` visar samma sida men står inte i API-nyckelns lista, så
inloggningen fungerar inte där — använd den inte.
Sidan går att öppna för vem som helst; utan medlemskap visas bara
inloggningsrutan. Exempelsiffrorna (som bara visas med `?demo`) står i sidans källkod och är alltså
läsbara utan inloggning — de är påhittade, men riktiga värden får aldrig
läggas i själva filen.

**Dammens avläsningar, 25 november 2026:** medlemmar får skriva under
`/damm`. Där sparas avläsningarna av vattenmätaren på påfyllningen
(`/damm/avlas`) och kalibreringarna med måttband (`/damm/kalib`), som förut
fördes i Excel och i minnet på varje telefon. Kristian bestämde det 25
november. En medlem får lägga till, och rätta eller ta bort det hen själv
lagt in. En administratör får rätta och ta bort allt, men den som läste av
står kvar. Reglerna kontrollerar fälten: tiden får inte ligga i framtiden,
typen måste vara start, stopp eller avläsning, platsen en av de fem, och
inga andra fält får finnas. Att mätaren inte går baklänges kontrollerar
appen, eftersom reglerna bara ser en avläsning i taget. Inget av det rör
anläggningen. Provat i Firebases lokala emulator med ett låtsasprojekt (26
fall: medlem, annan medlem, administratör, icke-medlem, obekräftad adress,
felaktiga fält, tömning av hela listan). Inte provat mot den riktiga
databasen.

**Inloggningen i appen, 16 november 2026:** `app/index.html` loggar in med
Google på riktigt och lyssnar på sin egen rad under `/members`; utan rad visas
"har inte åtkomst" och en utloggningsknapp, och tas raden bort medan appen är
öppen stängs den. Provat: sidan utan inloggning, och att ett stoppat
inloggningsfönster ger ett begripligt meddelande. Kristian loggade in som
administratör och kom in. Inte provat: ett konto som inte står i listan, och
att appen stängs när raden tas bort. Vyerna visar sedan samma kväll riktig data ur `/live` och
`/hist` (se `kolumnmappning.md`). Sidan måste ligga på en
adress som står i API-nyckelns lista (i dag bl.a. `http://localhost:8000`).

**Läget 16 november 2026:** bryggkontot finns och dess id står i
`firebase/database.rules.json`, utlagt. Första administratören är inlagd under
`/members`. Bryggkontot är provat med `brygga.ps1 -ProvaMoln`: det får
skriva `/live` och `/hist`, och får varken läsa eller skriva `/members` eller
skriva någon annanstans. Inte provat: medlemmarnas läsning, som väntar på att
appen får riktig Google-inloggning.

**Läget 15 november 2026:** databasen finns
(`snoprognos-default-rtdb`, europe-west1) och reglerna nedan är inlagda från
`firebase/database.rules.json` med `firebase deploy --only database`. Provat:
utan inloggning nekas läsning av `/live`, `/hist`, `/members` och roten, och
skrivning nekas. Inte provat: allt som kräver ett inloggat konto, alltså hela
checklistan längre ner. Bryggkontot finns inte än, så i reglerna står
`BRYGGANS_UID_SAKNAS` och ingen kan skriva; medlemslistan är tom, så ingen
kan läsa. Ändra reglerna i filen och lägg ut dem därifrån, inte i konsolen —
annars skriver nästa utläggning över det som gjorts för hand.

**Läget 12 november 2026:** inget av detta är byggt. Inloggningsknappen i
prototypen (`app/index.html`) är en attrapp som släpper in vem som helst, och
namnet "Kristian" står hårdkodat. Det är i sin ordning så länge datan är
simulerad — men den riktiga inloggningen och reglerna nedan ska vara på plats
och provade **innan** bryggan börjar skicka riktiga värden.

---

## Principen

**Att logga in är inte att få åtkomst.** Vem som helst med ett Google-konto
kan logga in i ett Firebase-projekt; det går inte att hindra. Det som skyddar
datan är databasens regler: bara den vars e-postadress står i medlemslistan får
läsa. Appen går att ladda för alla, men utan medlemskap är den tom.

Tre sorters konton:

| Konto | Loggar in med | Får |
|---|---|---|
| Medlem (`viewer`) | Google | läsa `/live`, `/hist` och `/damm`. Lägga till dammens avläsningar och kalibreringar, och rätta eller ta bort sina egna |
| Administratör (`admin`) | Google | som medlem, plus läsa och ändra medlemslistan, och rätta alla avläsningar |
| Bryggan | eget konto, e-post och lösenord | skriva `/live` och `/hist`. Ingenting annat, och inte läsa medlemslistan |

Ingen människa får skriva driftdata ur styrsystemet, och ingen får styra
något — appen har ingen väg tillbaka till anläggningen. Det medlemmar skriver
under `/damm` är bara det de själva läst av på mätaren och måttbandet.

Ha **minst två administratörer**. Annars står gruppen utan någon som kan
släppa in folk den dag en person slutar eller tappar sitt konto.

## Medlemslistan

Ligger i Realtime Database under `/members`. Nyckeln är e-postadressen med
gemener och **punkt utbytt mot komma** — databasnycklar får inte innehålla
punkt:

```
/members
  anna,andersson@gmail,com   { role: "viewer", name: "Anna",     added: "2026-11-20" }
  kristian@exempel,se        { role: "admin",  name: "Kristian", added: "2026-11-20" }
```

Adressen ska vara den personen loggar in på Google med. Googles inloggning
lämnar alltid en bekräftad adress, och reglerna kräver det.

### I appen (sedan 16 november 2026)

En administratör har vyn **Medlemmar** i menyn (på telefonen: knappen längst
ner på Översikt). Där går det att lägga till, byta roll och ta bort. Appen gör
själv om adressen till rätt nyckel, så `Anna.Andersson@gmail.com` blir rätt.
Den egna raden går inte att ändra därifrån — spärren mot att gruppen blir utan
administratör. Vyn är gömd för andra, men skyddet är reglerna: bara en
administratörs skrivning under `/members` går igenom.

Adressen måste höra till ett **Google-konto**. Den behöver inte sluta på
gmail.com: en jobbadress eller annan adress går bra om personen kan logga in
hos Google med den, och den som saknar Google-konto kan skapa ett på sin
vanliga adress.

Provat med en påhittad databas bakom: ogiltig adress, dubblett, tomt namn,
adress med flera punkter och stora bokstäver, byte av roll, borttagning, den
egna raden, och att vyn försvinner när man slutar vara administratör. Kristian
gjorde sedan en riktig ändring från appen, och den gick igenom.

Stegen nedan är samma sak gjord för hand i konsolen, om appen inte går att nå.

### Släppa in någon

1. Fråga vilken Google-adress personen använder.
2. Firebase-konsolen → Realtime Database → Data → `members` → **+**.
3. Nyckel: adressen med gemener och komma i stället för punkt.
   Värde: `role` = `viewer`, `name`, `added`.
4. Be personen öppna appen och logga in. Åtkomsten gäller direkt.

### Ta bort någon

Ta bort raden under `members`. Det gäller direkt — reglerna prövas vid varje
läsning, och en öppen app tappar sin koppling. Kontot finns kvar under
Authentication men kan inte läsa något; ta bort det där också om du vill städa.

### Gå igenom listan

Varje höst före säsongen: läs igenom `members` och ta bort dem som inte längre
är med. Listan innehåller namn och e-postadresser — bara administratörer kan
läsa hela, en medlem ser bara sin egen rad.

## Inloggning från telefon

På telefon går inloggningen i samma flik; på dator i ett eget fönster. Första
inloggningen från en iPhone (16 november 2026) slutade på en vit sida med
"Unable to process request due to missing initial state" — fönstret hade
tappat kopplingen till sidan. Efter bytet kom personen in.

Öppnas länken inifrån Messenger, Facebook eller Instagram hamnar man i den
appens inbyggda webbläsare, och där loggar Google inte in. Appen varnar då.
Rådet till den som fastnar: öppna Safari eller Chrome och skriv in adressen.

## Installera appen på telefonen

Appen går att lägga på hemskärmen (sedan 16 november 2026), som prognosappen:

- **iPhone:** öppna adressen i Safari → Dela → Lägg till på hemskärmen.
- **Android:** öppna adressen i Chrome → menyn → Installera app.

`app/sw.js` gör den installerbar. Den sparar sidan och ikonerna så att appen
startar fort, men aldrig mätvärden — de kommer alltid från Firebase. Sidorna
under `/__/` (Firebases inloggning) rör den inte. En installerad app frågar
servern om sidan ändrats varje gång den kommer fram på skärmen och laddar om
i så fall, så det finns inget versionsnummer att höja vid en ny utgåva.
`VERSION` i `sw.js` behöver bara höjas om själva `sw.js` eller ikonerna ändras.

**Byts ikonen måste filerna byta namn.** Servern låter webbläsaren behålla en
bild i en timme, och hemskärmar håller den längre. När iskristallen byttes mot
kanonen under samma filnamn kom iskristallen tillbaka även efter att appen
tagits bort och lagts till igen. Därför heter filerna `kanon-*.png`.

Inte provat: inloggning inifrån den installerade appen på en riktig telefon.

## Vad appen ska visa

- **Inte inloggad:** inloggningssidan.
- **Inloggad, inte medlem:** "Du är inloggad som anna@… men har inte åtkomst.
  Be en administratör i snögruppen lägga till dig." och en knapp för att logga
  ut. Inte en tom app och inte ett felmeddelande på engelska.
- **Medlem:** appen, med namn och initialer från Google-kontot i hörnet.
- **Kvittera larm** är personligt och lokalt: det döljer larmet för den som
  tryckt, sparas i telefonen och ändrar ingenting för andra eller i
  anläggningen.

## Reglerna

Klistras in under Realtime Database → Rules. `BRYGGANS_UID` byts mot
bryggkontots användar-id (Authentication → Users → kolumnen User UID).

```json
{
  "rules": {
    ".read": false,
    ".write": false,

    "live": {
      ".read":  "auth != null && auth.token.email_verified == true && root.child('members').child(auth.token.email.toLowerCase().replace('.', ',')).exists()",
      ".write": "auth != null && auth.uid === 'BRYGGANS_UID'"
    },
    "hist": {
      ".read":  "auth != null && auth.token.email_verified == true && root.child('members').child(auth.token.email.toLowerCase().replace('.', ',')).exists()",
      ".write": "auth != null && auth.uid === 'BRYGGANS_UID'"
    },

    "members": {
      ".read":  "auth != null && auth.token.email_verified == true && root.child('members').child(auth.token.email.toLowerCase().replace('.', ',')).child('role').val() === 'admin'",
      ".write": "auth != null && auth.token.email_verified == true && root.child('members').child(auth.token.email.toLowerCase().replace('.', ',')).child('role').val() === 'admin'",
      "$who": {
        ".read": "auth != null && auth.token.email_verified == true && auth.token.email.toLowerCase().replace('.', ',') === $who"
      }
    }
  }
}
```

Kopian ovan visar grunden. Sedan 25 november finns också grenen `/damm`,
där medlemmar skriver dammens avläsningar. Den gällande versionen står i
`firebase/database.rules.json`.

Reglerna är skrivna men **inte provade**. Innan riktig data: kör dem i
regelsimulatorn (Rules → Rules Playground) och bocka av:

- [ ] Inte inloggad: kan varken läsa `/live` eller `/members`.
- [ ] Inloggad med Google, inte i listan: kan inte läsa `/live`.
- [ ] Medlem: kan läsa `/live` och `/hist`, inte skriva, inte läsa hela `/members`.
- [ ] Medlem: kan läsa sin egen rad under `/members`.
- [ ] Administratör: kan läsa och ändra `/members`.
- [ ] Bryggkontot: kan skriva `/live`, kan inte läsa `/members`.
- [ ] En adress med flera punkter (`anna.b.andersson@gmail.com`) fungerar.

Den första administratören läggs in för hand i konsolen (konsolen går förbi
reglerna). Ta aldrig bort den sista.

## Bryggkontot

1. Authentication → Sign-in method → slå på **E-post/lösenord**.
2. Authentication → Users → Add user: en adress som inte är någons riktiga
   (t.ex. `brygga@pettersson.app`) och ett långt slumpat lösenord.
3. Kopiera kontots User UID in i reglerna.
4. Lösenordet läggs in på styrdatorn när bryggan installeras (krypterat, se
   planen) och i `SECRETS.md` hemma. Aldrig i git.
5. **Låt "Enable create (sign-up)" vara på** (Authentication → Settings →
   User actions). Här stod förut att den skulle stängas av, och det var fel:
   inställningen stoppar *alla* nya konton, också första inloggningen med
   Google, som då nekas med `auth/admin-restricted-operation`. Det upptäcktes
   16 november när den första riktiga inloggningen provades. Priset för att ha
   den på är att vem som helst kan skapa ett konto i projektet. Ett sådant
   konto kommer inte åt något — reglerna kräver medlemskap — men det syns i
   listan under Authentication och kan tas bort där.

Misstänker du att lösenordet läckt: byt det i konsolen. Bryggan tystnar tills
det nya lagts in på styrdatorn, och appen visar "Gammal data".

## Samma projekt som prognosappen

Driftdatan ligger i samma Firebase-projekt (`snoprognos`) som snödjupsdatan.
Det betyder:

- **Två medlemslistor.** Prognosappen har sin i Firestore (`members/{e-post}`),
  driftappen sin i Realtime Database. De är oberoende med flit: den som får
  mäta snödjup ska inte automatiskt se driftdata.
- **API-nyckeln är densamma** och är begränsad till vissa webbadresser i Google
  Cloud. I listan står nu `https://gkrallo.github.io/*` (prognosappen),
  `http://localhost:8000/*`, `https://snoprognos.firebaseapp.com/*` (som
  bryggan använder) och `https://snow.pettersson.app/*`. Slutar inloggningen
  fungera någonstans är det den listan man tittar i först.
- Nyckeln är offentlig av design och får stå i koden. Skyddet är reglerna.
