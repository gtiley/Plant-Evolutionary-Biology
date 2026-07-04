# Setup — RevBayes macroevolution practicals

For the two practicals in this folder:

- [`revbayes-diversification.qmd`](revbayes-diversification.qmd) — BiSSE/HiSSE. Needs
  **RevBayes + RevGadgets** only.
- [`revbayes-biogeography.qmd`](revbayes-biogeography.qmd) — GeoSSE. **Also needs TensorPhylo.**

## 1. RevBayes + RevGadgets

Same as the [phylogenetics practical setup](../../phylo/exercises/SETUP.md):

- RevBayes binary `rb`: <https://revbayes.github.io/download> (or `conda install -c bioconda revbayes`).
- RevGadgets (R): `remotes::install_github("revbayes/RevGadgets")`.

## 2. TensorPhylo (GeoSSE only — the hard part)

`dnGLHBDSP` is provided by the **TensorPhylo** plugin, which must be **built from source**:

- Repo: <https://bitbucket.org/mrmay/tensorphylo/> (see its README for CMake build steps;
  needs a C++ compiler, CMake, and BLAS/LAPACK).
- After building, note the installer `lib` path and pass it to RevBayes at the top of the
  script: `loadPlugin("TensorPhylo", "/path/to/tensorphylo/build/installer/lib")`.
- **Budget real time for this** and test a 100-generation run early.

**If TensorPhylo won't build:** teach ancestral ranges with the pure-RevBayes **DEC** model
instead (no plugin required) — see the
[biogeography DEC tutorial](https://revbayes.github.io/tutorials/biogeo/biogeo_intro.html).

## 3. Data

- **Diversification:** use Rosana Zenil-Ferguson's BiSSE/HiSSE tutorial data
  (<https://roszenil.github.io/mytutorials/contenido.html>), or substitute your own
  tree + binary trait table. The `.qmd` uses a generic `data/plant_tree.tre` +
  `data/plant_trait.tsv` placeholder.
- **Biogeography:** the *Kadua* files (`kadua.tre`, `kadua_range_n2.nex`) from the RevBayes
  [GeoSSE tutorial](https://revbayes.github.io/tutorials/geosse/) data archive.
- Create an `output/` folder before running.

> ⚠️ These materials are **drafts** — the Rev code mirrors the official/Zenil tutorials but
> has not been executed in the course repo. Validate against those tutorials and check MCMC
> convergence before using results. The two items most likely to need fixing: exact
> `dnCDBDP`/`dnGLHBDSP` argument names for your RevBayes version, and the TensorPhylo path.
