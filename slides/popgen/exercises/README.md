# Population Genomics — msprime simulation exercises

`msprime`-based computer activities for the Population Genomics module. Each is
self-contained (its own setup, helper, and plotting functions) and runnable on a laptop —
no HPC required.

Each exercise comes in two forms:

- **`.md`** — plain-Markdown handout (read on GitHub, copy code into your own script/REPL).
- **`.qmd`** — executable Quarto notebook (code runs, figures render inline).

| Exercise | Handout | Notebook | Reinforces | Key idea |
|---|---|---|---|---|
| 1 — Population size, drift, diversity | [.md](exercise1-population-size.md) | [.qmd](exercise1-population-size.qmd) | decks 01, 04 | $\pi \approx 4N_e\mu$; demography shapes the SFS |
| 2 — Gene flow & population structure | [.md](exercise2-gene-flow.md) | [.qmd](exercise2-gene-flow.qmd) | decks 02, 06 | island vs. split $F_{ST}$; same $F_{ST}$, different histories |
| 3 — Life history over time (selfing) | [.md](exercise3-mating-system.md) | [.qmd](exercise3-mating-system.qmd) | decks 03, 01 | selfing shrinks $N_e$; diversity slowly forgets a shift |
| 4 — Selection & the sliding window | — | [.qmd](exercise4-selection-sliding-window.qmd) | decks 04, 05 | a hard sweep carves a diversity valley; window choice matters |
| 5 — Experimental design & precision | — | [.qmd](exercise5-experimental-design.qmd) | deck 01 | sample size / length / missing data → bias vs. variance |

Together they cover the themes the module keeps returning to: **population size**,
**gene flow**, **life history (mating system)**, **selection**, and **study design**.

## Requirements

One conda environment covers the whole module (decks + exercises):

```bash
conda env create -f ../environment.yml   # file lives in slides/
conda activate plantevo-popgen
```

## Running the notebooks

```bash
quarto preview exercise4-selection-sliding-window.qmd   # live, in the conda env
quarto render  exercise4-selection-sliding-window.qmd   # -> one self-contained .html
quarto convert exercise4-selection-sliding-window.qmd   # -> .ipynb (if you prefer Jupyter)
```

The `exercises/` folder is excluded from the deck project render (`_quarto.yml`), so these
never interfere with `quarto render` of the slides.

## Notes for the instructor

- ✅ **Validated:** all five `.qmd` notebooks render/execute cleanly in the `plantevo-popgen`
  env (msprime 1.4.2). The `.md` handouts share the same code but aren't auto-executed —
  spot-check if you edit them.
- `msprime` is a **coalescent** simulator. Exercise 3 models selfing via its $N_e$ and
  recombination scalings ($\hat F = s/(2-s)$); Exercise 4 uses `SweepGenicSelection` for a
  hard sweep. For explicit selfing or richer selection, use a forward simulator (SLiM).
- Exercise 4 averages ~20 replicate sweeps (~5 s) to reveal the expected valley; a single
  replicate is deliberately noisy (that's part of the lesson).
- Suggested mapping to the graded computer activities: **Exercise 3** → Computer Activity 1
  (Sep 1, mating systems); **Exercises 4 + 2** → Computer Activity 2 (Sep 10, genome scans).
  Exercises 1 and 5 make good warm-ups or homework.
