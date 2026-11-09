# Egységes IT Architecture javító – v1.0 (pilot)

A `grade.mjs` egyetlen Node.js javítómotor az **1–7. heti** gyakorlatokhoz. A külön **6. heti HF nincs benne**.

## Fontos státusz

Ez **működésre előkészített pilot**, nem véglegesített értékelési kulcs. A 2–7. heti rubrikák automatikusan a csatolt `.qmd` feladatlapokból kinyert mezőket és feladatszövegeket tartalmazzák, **tanári jóváhagyásra várnak**. A `criteria[].description` kezdetben technikai mezőnév, nem részletes javítókulcs. Ezeket a pontos elvárások és részpontok szerint ki kell tölteni a teljes évfolyam előtt. A program ezt a státuszt ellenőrzi.

Az 1. heti rubrika is **pilot**, és az új, általános mezőnkénti pontozás **nem azonos** a korábbi v0.8.1 különleges rubrikájával. Az első hét hivatalos eredményeit ne írja felül ez a változat. A korábbi 1. heti javítót külön őrizzük meg.

## Előfeltételek

Windows PowerShell, Node.js 20+, Azure PowerShell bejelentkezés, `@azure/identity`, `@azure/storage-blob`, `openai`. A projekt gyökérkönyvtárában:

```powershell
npm install openai @azure/identity @azure/storage-blob
```

Másold az `unified_grader` mappát a projektbe, majd a projekt gyökeréből:

```powershell
# 2. hét – első hat beadás (előzetes, tanári rubrikaellenőrzéshez)
node .\unified_grader\grade.mjs --week 2 --limit 6 --batch-size 6 --concurrency 2

# Kiválasztott hallgatók
node .\unified_grader\grade.mjs --week 2 --ids ABC123,DEF456

# Teljes évfolyam CSAK a rubrika jóváhagyása után:
node .\unified_grader\grade.mjs --week 2 --all --confirm-all

# Kizárólag technikai próba, még nem jóváhagyott rubrikával:
node .\unified_grader\grade.mjs --week 2 --all --confirm-all --accept-draft-rubric
```

A rubrikát a `rubrics/week02.json` fájlban lehet szerkeszteni. Ellenőrizd minden feladat `description`, `fields`, `criteria`, `weight` mezőit. A `weight` értékek feladaton belül relatív súlyok; **minden feladat összesen 1 pont**, 15 feladat = 15 pont. A jóváhagyott rubrikában állítsd `status` mezőt `approved` értékre.

A 80%-os küszöb egységes: **12/15 pont**. A nem elfogadott eredmény és a kézi ellenőrzési igény külön dolog; a CSV és JSON tartalmazza mindkettőt.

## Adatkezelés és kimenet

A program a `itarchsubmissions/submissions/weekNN/<NEPTUN>/*.json` helyről csak **olvas**. Hallgatónként a `submitted_at` szerint legfrissebb beadást választja ki. A kimenet a projekt gyökeréhez viszonyítva `grading-output/unified/weekNN/`: `summary.csv`, `cache_stats.csv`, hallgatónként részletes JSON. A cache a `grading-output/cache/unified_weekNN.json` fájlban van, és a rubrika teljes tartalmának SHA-256 hashét is figyelembe veszi.

Az azonos válaszokat a program feladatonként összevonja. Üres válaszokat szabályalapon nulláz; egyszerű Igen/Nem mezőket szabályalapon kezel, **de ez csak önbevallás, nem igazolja a végrehajtást**. Az AI értékelése 0/50/100 százalékos részszempontokból számolódik, majd súlyozott átlagot képez. Az AI-hibákat három próbálkozás után kisebb csomagokra bontva kezeli; végső hiba esetén **nem ad automatikusan nulla pontot**, hanem hiányosnak jelöli az értékelést.

## Korlátok

- Az Azure/Windows/Linux műveletek tényleges végrehajtását a beadott szöveg nem bizonyítja.
- A QMD-ből automatikusan származtatott rubrikák **nem helyettesítik a tanári értékelési elvárásokat**.
- A heti `description` mezők rövidített, nyers feladatszöveget tartalmaznak; érdemes ezeket tömör, ellenőrzött kritériumokra átírni.
- Az új motort **még nem futtattuk a felhasználó Azure-környezetében**. Csak szintaktikai és helyi szerkezeti ellenőrzés történt.
