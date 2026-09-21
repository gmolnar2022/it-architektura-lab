# Korszerű adatbázisok – Quarto kurzus

Ez a projekt a Korszerű adatbázisok kurzus Quarto-alapú webhelyének induló változata.

## Tartalom

- `index.qmd` – kurzus kezdőlap
- `week01/theory.qmd` – 1. heti elméleti tananyag
- `week01/practical.qmd` – 1. heti gyakorlati feladatok
- `solutions/week01.sql` – oktatói megoldások (nincs a webhely navigációjában)
- `resources/source/` – az eredeti első heti forrásanyagok
- `docs/` – a Quarto renderelt kimenete (renderelés után)

## Helyi futtatás

```bash
quarto preview
```

Publikálható kimenet készítése:

```bash
quarto render
```

A webhely a `docs/` mappába renderelődik, így GitHub Pages használható
`main /docs` beállítással.
