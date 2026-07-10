# Setup — RevBayes phylogenetics practical

What you need for [`revbayes-phylogenetics.qmd`](revbayes-phylogenetics.qmd) (molecular
phylogenetics & dating). **No TensorPhylo needed here** (that's only the GeoSSE practical).

## 1. RevBayes

Install the RevBayes binary (`rb`):

- Download for macOS/Linux/Windows: <https://revbayes.github.io/download>
- Or with conda: `conda install -c bioconda revbayes` (availability varies by platform).
- Verify: `rb --version`.

Run a script with `rb my_script.Rev`, or start interactively with `rb` and paste blocks.

## 2. RevGadgets (R, for plotting)

```r
install.packages("remotes")
remotes::install_github("revbayes/RevGadgets")   # or install.packages("RevGadgets")
```

RevGadgets needs a recent R (≥ 4.1) and pulls `ggplot2`, `ape`, `ggtree`.

## 3. Data

The practical uses the Hawaiian *Kadua* alignments from the RevBayes
**[`timefig_dating` tutorial](https://revbayes.github.io/tutorials/timefig_dating/)**.

- Download the tutorial's data archive from that page and place the NEXUS alignments in a
  local `data/` folder (the scripts expect e.g. `data/kadua_ITS.nex`).
- Make an `output/` folder before running (`mkdir output`).

## 4. Run

```bash
mkdir -p output
rb revbayes-phylogenetics.Rev      # after copying the code blocks into a .Rev file
Rscript plot.R                      # the RevGadgets block, saved as plot.R
```

> ⚠️ These materials are **drafts** — the Rev code mirrors the official tutorial but has not
> been executed in the course repo. Validate against the
> [tutorial](https://revbayes.github.io/tutorials/timefig_dating/) and check MCMC convergence
> (ESS > 200 in Tracer) before using results.
