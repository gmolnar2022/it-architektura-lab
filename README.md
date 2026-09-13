# IT Architektúra – gyakorlati munkafüzet

## Kipróbálható értékelési prototípus

- `index.qmd` – kurzus kezdőlap
- `weeks/week01/index.qmd` – az 1. heti interaktív munkafüzet
- `config/setup.js` – központi kapcsolók

A hallgató közvetlenül a böngészőben tölti ki a heti oldalt. A prototípusban nincs hallgatói JSON-export.

## Feladatszintű ellenőrzés

Minden feladat pontosan egy ellenőrzési típust kap:

- **Szintaktikai ellenőrzés** – Q01–Q12 és Q15
- **AI-ellenőrzés** – Q13–Q14

Az AI-ellenőrzés ebben a prototípusban még helyi szabályokkal szimulált. A végleges verzióban az Azure Function `/api/check` végpontja fogja kiszolgálni.

Ha egy ellenőrzött válasz módosul, az ellenőrzés státusza automatikusan „módosítva” állapotra vált.

## Beadás előtti összesítés

A **Beadás** gomb még nem küld adatot szerverre. Először megjeleníti:

- kitöltöttség százalékát és mezőszámát;
- becsült aktív időt;
- befejezett / hátralévő feladatokat;
- a hátralévő feladatok listáját;
- opcionálisan a szintaktikai és AI-ellenőrzések összesítését;
- a „Biztosan beadja?” megerősítést.

A prototípusban a megerősített beadás csak a böngésző helyi tárhelyén kerül rögzítésre.

## Központi konfiguráció

A `config/setup.js` fő kapcsolói:

```javascript
window.ITARCH_SETUP = {
  timeTracking: true,
  eventTracking: true,
  showTrackingPanel: true,

  checksEnabled: true,
  syntaxChecks: true,
  aiChecks: true,
  showChecksInSubmissionSummary: true,
  requireChecksBeforeSubmission: false,

  allowImport: false
};
```

Az összes ellenőrzés egyszerre kikapcsolható:

```javascript
checksEnabled: false
```

Ekkor az ellenőrző gombok nem jelennek meg, és a beadási összesítő sem mutat ellenőrzési eredményeket.

A két ellenőrzési típus külön is letiltható:

```javascript
syntaxChecks: false,
aiChecks: true
```

Az ellenőrzések alapból nem kötelezőek a beadáshoz. Ha ezt később meg akarjuk változtatni:

```javascript
requireChecksBeforeSubmission: true
```

## Learning analytics

A korábbi mező-munkamenet alapú szerkesztési eseményszámlálás megmaradt. Emellett a prototípus naplózza többek között:

- `check_performed`;
- `check_invalidated`;
- `submission_summary_opened`;
- `submission_returned_to_editing`;
- `submission_confirmed_prototype`.

Az aktivitási és ellenőrzési adatok jelenleg csak a localStorage-ban vannak. A későbbi szerveres változatban ezek az Azure Functionön keresztül külön analytics tárhelyre kerülhetnek.
