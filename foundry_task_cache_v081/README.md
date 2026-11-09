# Hibrid javító v0.8.1 – Q08 és Q11 pontosított rubrika

A v0.8 teljes funkcionalitása megmaradt (feladatonkénti AI-batch, azonos válaszok összevonása, tartós cache, részpontok).

**Q08:** két egyenlő súlyú részszempont: előfizetések lekérdezése és kizárólag Name/State megjelenítése. A beadásban külön szereplő parancskimenet bizonyíték, nem harmadik pontozási szempont. A formátum, fejléc és mezősorrend nem pontozandó.

**Q11:** két egyenlő súlyú részszempont: állapot lekérdezése és helyes állapotmegnevezés. `running` és `VM running` egyaránt teljes értékű. A Start/Stop/Restart parancsok tényleges végrehajtása nem követelmény.

A verzió és a cache-fájl neve módosult, így a v0.8 értékelései nem kerülnek át automatikusan. A teljes évfolyam javítása előtt érdemes ismét a hat hallgatóval próbálni.

A projekt gyökérkönyvtárából:

```powershell
node .\foundry_task_cache_v081\grade_hybrid.mjs --batch-size 6 --concurrency 2
```

Eredmények: `grading-output/hybrid/week01_v081/summary.csv`, `cache_stats.csv`, egyéni JSON-ok.
Cache: `grading-output/cache/week01_grading_cache_v081.json`.

Teljes évfolyam (a teszt ellenőrzése után):

```powershell
node .\foundry_task_cache_v081\grade_hybrid.mjs --all --confirm-all --batch-size 10 --concurrency 3
```

**Figyelem:** A program szintaktikailag ellenőrzött, de itt Azure-hitelesítés és Foundry futtatás nem történt. Az eredmények előzetesek, különösen a döntési határok közelében.
