# Användare och åtkomst

Vem som får se driftdatan, hur man släpper in och tar bort någon, och vilka
regler som skyddar den. Hör ihop med
[`plan-brygga-firebase.md`](plan-brygga-firebase.md).

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
| Medlem (`viewer`) | Google | läsa `/live` och `/hist` |
| Administratör (`admin`) | Google | som medlem, plus läsa och ändra medlemslistan |
| Bryggan | eget konto, e-post och lösenord | skriva `/live` och `/hist`. Ingenting annat, och inte läsa medlemslistan |

Ingen människa får skriva mätvärden och ingen får styra något — appen har
ingen väg tillbaka till anläggningen.

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
5. **Stäng av självregistrering:** Authentication → Settings → User actions →
   bocka ur "Enable create (sign-up)". Annars kan vem som helst skapa
   e-postkonton i projektet. De kommer inte åt något, men de skräpar ner.

Misstänker du att lösenordet läckt: byt det i konsolen. Bryggan tystnar tills
det nya lagts in på styrdatorn, och appen visar "Gammal data".

## Samma projekt som prognosappen

Driftdatan ligger i samma Firebase-projekt (`snoprognos`) som snödjupsdatan.
Det betyder:

- **Två medlemslistor.** Prognosappen har sin i Firestore (`members/{e-post}`),
  driftappen sin i Realtime Database. De är oberoende med flit: den som får
  mäta snödjup ska inte automatiskt se driftdata.
- **API-nyckeln är densamma** och är begränsad till vissa webbadresser i Google
  Cloud. Den nya adressen (`https://snow.pettersson.app/*`) måste läggas till
  där, annars fungerar varken inloggning eller databas. Lägg också till den
  under Authentication → Settings → Authorized domains.
- Nyckeln är offentlig av design och får stå i koden. Skyddet är reglerna.
