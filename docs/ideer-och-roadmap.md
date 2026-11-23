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

## 4. Nivågivare i dammen — sommarjobb inför säsongen 2027

Parkerad 23 november 2026. Hinns inte före säsongen, och en givare monteras
lättast när det inte är is.

**Idén:** en givare som ligger under vattnet och mäter trycket, och ur trycket
räknar ut djupet (en så kallad hydrostatisk nivågivare). Den fungerar under
is, vilket en givare som mäter uppifrån (ultraljud, radar) inte gör. Kristian
tittade på en billig stålgivare med 33 m kabel och mätområde 0–5 m
(Amazon B0BH1DM5BG). Manualen saknar det viktigaste, så det måste
kontrolleras före köp:

- **Utsignal:** 4–20 mA är det vanliga och tål lång kabel. Andra varianter
  har 0–5 V, 0–10 V eller RS485.
- **Matning:** oftast 12–36 V.
- **Noggrannhet:** 0,5 % av 5 m är ±2,5 cm, ungefär ±40 m³. 0,25 % eller
  0,1 % är värt pengarna.
- **Kabeltyp:** de flesta har ett tunt luftrör i kabeln, så att lufttrycket
  räknas bort. Då måste kabeländen sitta torrt, i en kopplingslåda. Saknas
  luftröret måste lufttrycket mätas separat, eftersom det varierar så mycket
  som ±30 cm vattenpelare.

**Två sätt att koppla in den:**

1. **I styrsystemet.** Det är den bästa vägen. GSSystem är redan förberett:
   statistiken har kolumnen `niveau_lac`, som står på 1, och skärmen visar
   "Lake lvl. 95,5 m" som fast text (se `kolumnmappning.md`). Med en givare
   syns nivån i pumphuset, sparas i statistiken och kan läsas av bryggan som
   allt annat. Men det är en ändring i anläggningen: leverantören måste säga
   vilken ingång, signal och vilket mätområde som gäller, och ställa in den.
   Fråga därför innan ni köper. Systemet kan också använda nivån i sin egen
   logik, till exempel för att stoppa pumparna vid låg nivå. Det är
   leverantörens beslut, och vi bygger inget som styr.
2. **Egen ESP32.** Den är helt fristående och passar reglerna, eftersom den
   bara läser och skickar ut. Den behöver 24 V till givaren och en modul som
   gör om 4–20 mA till spänning, eller ett motstånd och en separat
   AD-omvandlare (till exempel ADS1115). ESP32:ans egen omvandlare är för
   onoggrann. Den behöver också ström och nät vid dammen. Står den på samma
   nät som styrdatorn kan bryggan hämta värdet och skicka det med resten.
   Annars behövs ett eget konto i Firebase och nya regler, eftersom bara
   bryggan skriver i dag.

**Montering:**

- **Inga ankare genom duken.** Lägg ett perforerat PE-rör längs slänten med
  givaren nere i röret, en bit över botten där slammet ligger. Röret skyddar
  givaren och kabeln mot isen, och tyngden håller det på plats.
- **Inte vid pumpintaget**, där suget stör trycket.
- **Kalibrera en gång.** Givarens höjd över botten blir okänd. Den
  kalibreras mot en flottmätning med pucken, där vattenytan mäts i samma
  höjdsystem som krönet.

**Vad den skulle ge:**

- Damm-koll kan visa uppmätt nivå i stället för beräknad, och måttbandet blir
  en kontroll.
- Den kan reda ut de cirka 200 m³ som saknas (`damm-matningar.md`):
  - **När bara påfyllningen går**, med 8,93 m³/h, stiger ytan ungefär 6 mm i
    timmen. Hur fort den stiger ger vattenytans verkliga area på varje nivå,
    och därmed dammens verkliga volym.
  - **När allt står still** är det som försvinner läckage.

  Det kräver upplösning på millimetern, inte absolut noggrannhet, eftersom
  man kan räkna medelvärden över flera timmar. Ett par veckors data räcker.

---

## Beroenden att reda ut innan "på riktigt"

1. Vilka tabeller/kolumner finns och vad betyder de numrerade kolumnerna
   (read-only-probe mot skarpa databasen).
2. Vilka parametrar går att läsa, och — för rådgivaren — vilka går att ställa
   (i styrsystemet, av människa).
3. Hur statusrader och larm ser ut i databasen, så loggningen mot Firebase blir
   lätt.
