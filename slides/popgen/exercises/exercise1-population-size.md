# Exercise 1 — Population size, drift, and diversity

**Population Genomics · PB 495/595 Plant Evolutionary Biology**

> Reinforces deck 01 (Genetic Diversity) and deck 04 (Selection & Demography).
> Concepts: $\theta = 4N_e\mu$, genetic drift, the site frequency spectrum (SFS),
> and how **population-size history** (bottlenecks, expansions) is written into diversity.

⚠️ **Draft for review.** Code is idiomatic `msprime` 1.x but has not been executed in this
repo — run it once and validate the numbers before using in class.

---

## Learning goals

By the end you should be able to:

1. Show empirically that nucleotide diversity scales as $\pi \approx 4N_e\mu$.
2. Explain why **smaller populations hold less diversity** (drift).
3. Read population-size *changes* off the **SFS** and **Tajima's $D$**.

## Setup

```bash
# one-time install (conda or pip)
pip install msprime tskit numpy matplotlib
```

```python
import msprime
import numpy as np
import matplotlib.pyplot as plt

RNG = 42  # base random seed
```

### Helper + plotting functions

```python
def harmonic(n):
    """a_n = sum_{i=1}^{n-1} 1/i  (Watterson's correction)."""
    return np.sum(1.0 / np.arange(1, n))

def simulate(Ne, mu=1e-8, L=1e6, n_diploid=25, recomb=1e-8,
             demography=None, seed=RNG):
    """Simulate a sample and return (ts, summary dict).

    n_diploid individuals -> 2*n_diploid haploid sample genomes.
    """
    if demography is None:
        ts = msprime.sim_ancestry(
            samples=n_diploid, population_size=Ne, sequence_length=L,
            recombination_rate=recomb, random_seed=seed)
    else:
        ts = msprime.sim_ancestry(
            samples=n_diploid, demography=demography, sequence_length=L,
            recombination_rate=recomb, random_seed=seed)
    ts = msprime.sim_mutations(ts, rate=mu, random_seed=seed)

    n = ts.num_samples                      # 2 * n_diploid haploid genomes
    S = ts.segregating_sites(span_normalise=False)
    summary = {
        "pi": ts.diversity(),               # per-site nucleotide diversity
        "theta_w": (S / harmonic(n)) / ts.sequence_length,
        "tajimas_d": ts.Tajimas_D(),
        "seg_sites": int(S),
    }
    return ts, summary

def sfs_counts(ts):
    """Folded-allele-count SFS (derived counts 1..n-1), as integer site counts."""
    afs = ts.allele_frequency_spectrum(polarised=True, span_normalise=False)
    return afs[1:-1]                         # drop monomorphic 0 and n classes

def plot_sfs(ts, title="Site frequency spectrum", ax=None):
    counts = sfs_counts(ts)
    x = np.arange(1, len(counts) + 1)
    ax = ax or plt.gca()
    ax.bar(x, counts, color="#4477AA")
    ax.set_xlabel("derived-allele count")
    ax.set_ylabel("number of sites")
    ax.set_title(title)
    return ax

def plot_xy(x, y, xlabel, ylabel, title, ax=None, **kw):
    ax = ax or plt.gca()
    ax.plot(x, y, marker="o", **kw)
    ax.set_xlabel(xlabel); ax.set_ylabel(ylabel); ax.set_title(title)
    return ax
```

---

## Exercise 1A — Diversity scales with $N_e$

Simulate across a grid of effective sizes and compare measured $\pi$ to the theoretical
$4N_e\mu$.

```python
mu = 1e-8
Ne_grid = [500, 1000, 2000, 5000, 10000, 20000]
pis, thetas = [], []
for Ne in Ne_grid:
    _, s = simulate(Ne, mu=mu, seed=RNG)
    pis.append(s["pi"]); thetas.append(s["theta_w"])

fig, ax = plt.subplots(figsize=(5, 4))
plot_xy(Ne_grid, pis, "effective size $N_e$", r"diversity $\pi$",
        "Diversity scales with $N_e$", ax=ax, label=r"$\pi$ (measured)")
ax.plot(Ne_grid, [4 * Ne * mu for Ne in Ne_grid], "k--", label=r"$4N_e\mu$ (theory)")
ax.legend(); fig.tight_layout()
fig.savefig("ex1a_diversity_vs_Ne.png", dpi=150)
```

**Questions**

- Does $\pi$ fall on the $4N_e\mu$ line? Where does it deviate, and why (one replicate!)?
- Re-run with several seeds and add error bars. How much does a *single* genome's estimate
  bounce around?
- $\theta_W$ vs $\pi$: under this constant-size neutral model they should agree — confirm.

---

## Exercise 1B — Drift erases diversity

Smaller populations lose heterozygosity faster (deck 01: decay rate $1/2N_e$). With the
coalescent we see it as **shorter genealogies** ⟹ fewer mutations ⟹ lower $\pi$.

```python
for Ne in [500, 5000, 50000]:
    _, s = simulate(Ne, mu=mu, seed=RNG)
    print(f"Ne={Ne:>6}:  pi={s['pi']:.5f}   S={s['seg_sites']}")
```

**Question.** A selfing or recently bottlenecked plant may have a census size in the
millions but a low $\pi$. Which $N$ — census or effective — does $\pi$ report? (deck 01,
"What is $N_e$?")

---

## Exercise 1C — Population-size *change* and the SFS

A constant-size population gives the neutral SFS $\mathbb{E}[\xi_i] \propto 1/i$.
**Expansions** add rare variants (Tajima's $D<0$); **bottlenecks** remove them and leave an
excess of intermediate-frequency variants ($D>0$).

```python
Ne = 10000

# (1) Expansion: small in the past, large now
exp_dem = msprime.Demography()
exp_dem.add_population(name="A", initial_size=Ne)
exp_dem.add_population_parameters_change(time=2000, initial_size=Ne / 20, population="A")

# (2) Bottleneck: a transient crash 1000-1500 generations ago
bot_dem = msprime.Demography()
bot_dem.add_population(name="A", initial_size=Ne)
bot_dem.add_population_parameters_change(time=1000, initial_size=Ne / 50, population="A")
bot_dem.add_population_parameters_change(time=1500, initial_size=Ne, population="A")

fig, axes = plt.subplots(1, 3, figsize=(13, 4), sharey=False)
for ax, (label, dem) in zip(
        axes, [("constant", None), ("expansion", exp_dem), ("bottleneck", bot_dem)]):
    ts, s = simulate(Ne, mu=mu, demography=dem, seed=RNG)
    plot_sfs(ts, title=f"{label}\nTajima's D = {s['tajimas_d']:.2f}", ax=ax)
fig.tight_layout()
fig.savefig("ex1c_sfs_demography.png", dpi=150)
```

**Questions**

- Which scenario skews the SFS toward **rare** variants? Which toward **intermediate**?
- Read off Tajima's $D$ for each — do the signs match the rule from deck 04?
- **Why this matters:** demography shifts the SFS *genome-wide*. Keep this picture in mind
  for Exercise on selection scans, where *selection* shifts it only *locally*.

---

## Stretch

- Plot $\pi$ in sliding windows (`ts.diversity(windows=...)`) and confirm it's flat under a
  constant-size neutral model — the genome-wide background you compare outliers against.
- Replace one replicate with the mean ± SD over 20 seeds for the $N_e$ sweep.
