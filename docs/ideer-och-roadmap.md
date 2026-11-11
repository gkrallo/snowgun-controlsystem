# Idéer och roadmap

Löpande idélista för övervakningsappen. Inget här är byggt — det är riktningar
att bena ut. Hårda regler gäller fortfarande (se
[`arkitektur-och-risker.md`](arkitektur-och-risker.md)).

---

## 1. Halvautomatisk vattenfördelning (rådgivare)

**Idén:** utifrån varje kanon/lans våttemperatur och driftförutsättningar
föreslå hur de ska ställas in så att vi tajmar vattenförbrukningen mot
pumpkapaciteten — och mot hur länge vattnet ska räcka.

**Form:** en *rådgivare*, inte en autopilot. Appen räknar fram ett förslag;
människan ställer in det i styrsystemet.

> ⚠️ **Varför bara förslag:** appen är läs-only mot anläggningen (hård regel).
> Den får aldrig själv ändra inställningar. Rådgivaren visar "så här skulle du
> kunna fördela", operatören verkställer. Det passar läs-only perfekt och är
> dessutom säkrare — en människa i loopen.

**Tänkt logik (grovt):**
- *Hård gräns:* summa vattenuttag ≤ pumpkapacitet.
- *Prioritet:* enheter där våttemperaturen är lägst/förhållandena bäst kan
  bära mer flöde (bättre snökvalitet per liter).
- *Mål man väljer:* "täck mer sträcka" (sprid tunt på fler) vs "producera fort"
  (full effekt på färre) vs "få vattnet att räcka X dygn".
- Knyter ihop med prognosmaskinen i snowgun-forecast — samma våttemperatur per
  plats längs spåret.

**Beroende / öppen fråga:** vilka parametrar går faktiskt att *läsa* och vilka
går att *ställa* i styrsystemet? Kristian tar reda på det om/när vi får
uppkopplingen att fungera. Utan den listan är rådgivaren bara en skiss. Troliga
rattar: flöde/strypning, dyssteg, luft — men bekräftas mot verkligheten.

---

## 2. Larm — två sorter

### a) Egna larm (räknar vi fram själva)
Appen tittar på livedatan och *varnar* när ett villkor slår till. Exempel:
- Summa vattenuttag överstiger pumpkapaciteten (eller en marginal under).
- Vattenmagasinet räcker mindre än X dygn.
- En enhet står still fast förhållandena är goda.
- Våttemperaturen passerar startgränsen (fönster öppnas/stängs).

Egna larm **notifierar** — på skärmen, push-notis, ev. SMS. 

> ⚠️ **Om att "stanna eller pulsa" vid överskriden förbrukning:** att *stoppa*
> eller *pulsa* anläggningen är en **åtgärd på anläggningen**, inte en notis.
> Det ligger utanför läs-only-appen och ska inte byggas in här. Två vägar om det
> önskas: (1) styrsystemet gör det redan självt — vi såg att det **automatiskt
> stryper** när uttaget närmar sig taket, så "pulsning"/strypning kan redan
> finnas; vår app surfar upp att det händer. (2) Vill man ha ny automatisk
> styrning är det ett eget, större och säkerhetskritiskt beslut (skrivaccess),
> helt skilt från övervakningen. Låt det aldrig smyga in via appen.

### b) Systemets egna larm (läser vi av)
Styrsystemet sätter själv larm av olika typer (vi såg tabellen `alarms_techno`
med larmkoder + texter, kopplad till en `alarms_techno.txt`). Dem **visar** vi.

### c) Statusrader och loggvolym — öppen fråga
Kristian tror att systemet också producerar mängder av statusrader (fläkt
startar → förvärmer → drift → …). Funderingar:
- **Tynger det loggningen?** I *styrsystemets* egen databas loggar det vad det
  loggar oavsett oss — vår avläsning lägger inget till det. I *vår* Firebase
  blir det bara tungt om vi designar fel.
- **Rätt grepp:** behandla fläktens faser som ett *tillstånd* (visa "nuvarande
  fas" per enhet), inte som en ström vi sparar varje rad av. Vill vi ha
  historik: skriv bara **vid förändring** (start→förvärmer→drift är några få
  övergångar per pass och enhet — billigt). Aldrig "skriv varje rad var 20:e
  sekund".
- Måste bekräftas när vi ser hur statusraderna faktiskt ser ut i databasen.

---

## 3. Fler vyer / idéer (ej påbörjade)

- **Kartvy** — enheterna på spåret vid sina brunnar (spår + brunnar finns redan
  i prognosappen).
- **Historik/säsong** — ackumulerad snövolym och vattenförbrukning över passet,
  mot "vattnet räcker en vecka".
- **Push-notiser** till den som övervakar hemifrån.
- **Beräkna m³ snö** ur vattenvolym, förluster och densitet (idé från
  driftdata-planen; kalibreras mot snödjupsmätningen).

---

## Beroenden att reda ut innan "på riktigt"

1. Vilka tabeller/kolumner finns och vad betyder de numrerade kolumnerna
   (read-only-probe mot skarpa databasen).
2. Vilka parametrar går att läsa, och — för rådgivaren — vilka går att ställa
   (i styrsystemet, av människa).
3. Hur statusrader och larm ser ut i databasen, så loggningen mot Firebase blir
   lätt.
