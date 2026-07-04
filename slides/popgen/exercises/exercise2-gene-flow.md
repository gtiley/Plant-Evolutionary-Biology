# Exercise 2 — Gene flow and population structure

**Population Genomics · PB 495/595 Plant Evolutionary Biology**

> Reinforces deck 02 (Population Structure) and deck 06 (Gene Flow & Polyploidy).
> Concepts: $F_{ST}$, the **island model** $F_{ST}\approx\tfrac{1}{1+4N_em}$, the
> **split model** $F_{ST}\approx\tfrac{T}{T+4N_e}$, and the fact that **migration and
> divergence time can produce the same $F_{ST}$**.

⚠️ **Draft for review.** Code is idiomatic `msprime` 1.x but has not been executed in this
repo — validate before class use. Note `msprime` migration rates are defined **backwards in
time** (fraction of a population replaced by migrants per generation); for these symmetric,
low-rate models that matches the forward intuition closely enough for teaching.

---

## Learning goals

1. Measure $F_{ST}$ from simulated data and match it to the island-model prediction.
2. Show $F_{ST}$ grows with **divergence time** under the split model.
3. Demonstrate that **ongoing gene flow** and an **old split** can give the *same*
   $F_{ST}$ — and think about what else could tell them apart.

## Setup

```python
import msprime
import numpy as np
import matplotlib.pyplot as plt

RNG = 7
```

### Helper + plotting functions

```python
def two_pop_island(Ne, m, n_diploid=30, mu=1e-8, L=1e6, recomb=1e-8, seed=RNG):
    """Two demes of size Ne exchanging symmetric migration at rate m (per gen)."""
    dem = msprime.Demography()
    dem.add_population(name="A", initial_size=Ne)
    dem.add_population(name="B", initial_size=Ne)
    dem.set_migration_rate(source="A", dest="B", rate=m)
    dem.set_migration_rate(source="B", dest="A", rate=m)
    ts = msprime.sim_ancestry(samples={"A": n_diploid, "B": n_diploid},
                              demography=dem, sequence_length=L,
                              recombination_rate=recomb, random_seed=seed)
    return msprime.sim_mutations(ts, rate=mu, random_seed=seed), dem

def two_pop_split(Ne, T, n_diploid=30, mu=1e-8, L=1e6, recomb=1e-8, seed=RNG):
    """Two demes that split T generations ago with NO subsequent migration."""
    dem = msprime.Demography()
    dem.add_population(name="A", initial_size=Ne)
    dem.add_population(name="B", initial_size=Ne)
    dem.add_population(name="ANC", initial_size=Ne)
    dem.add_population_split(time=T, derived=["A", "B"], ancestral="ANC")
    ts = msprime.sim_ancestry(samples={"A": n_diploid, "B": n_diploid},
                              demography=dem, sequence_length=L,
                              recombination_rate=recomb, random_seed=seed)
    return msprime.sim_mutations(ts, rate=mu, random_seed=seed), dem

def fst(ts):
    """Hudson-style Fst between the two populations in the tree sequence."""
    A = ts.samples(population=0)
    B = ts.samples(population=1)
    return ts.Fst([A, B])

def plot_xy(x, y, xlabel, ylabel, title, ax=None, **kw):
    ax = ax or plt.gca()
    ax.plot(x, y, marker="o", **kw)
    ax.set_xlabel(xlabel); ax.set_ylabel(ylabel); ax.set_title(title)
    return ax
```

---

## Exercise 2A — The island model: migration homogenizes

Vary the number of migrants per generation $N_e m$ and compare measured $F_{ST}$ to
$\frac{1}{1+4N_e m}$.

```python
Ne = 5000
Nm_grid = [0.1, 0.25, 0.5, 1, 2, 5, 10]
fst_obs = []
for Nm in Nm_grid:
    m = Nm / Ne
    ts, _ = two_pop_island(Ne, m, seed=RNG)
    fst_obs.append(fst(ts))

fig, ax = plt.subplots(figsize=(5, 4))
plot_xy(Nm_grid, fst_obs, r"migrants per generation $N_e m$", r"$F_{ST}$",
        "Island model: gene flow erodes structure", ax=ax, label="measured")
ax.plot(Nm_grid, [1 / (1 + 4 * Nm) for Nm in Nm_grid], "k--", label=r"$1/(1+4N_em)$")
ax.set_xscale("log"); ax.legend(); fig.tight_layout()
fig.savefig("ex2a_island_fst.png", dpi=150)
```

**Questions**

- At $N_e m = 1$ (one migrant per generation), what is $F_{ST}$? Compare to the "one
  migrant rule" from deck 06.
- How few migrants does it take to keep $F_{ST}$ below 0.05?

---

## Exercise 2B — The split model: time builds structure

No migration; differentiation accumulates with divergence time $T$.

```python
Ne = 5000
T_grid = [200, 500, 1000, 2000, 5000, 10000, 20000]
fst_obs = [fst(two_pop_split(Ne, T, seed=RNG)[0]) for T in T_grid]

fig, ax = plt.subplots(figsize=(5, 4))
plot_xy(T_grid, fst_obs, "divergence time $T$ (generations)", r"$F_{ST}$",
        "Split model: drift builds structure", ax=ax, label="measured")
ax.plot(T_grid, [T / (T + 4 * Ne) for T in T_grid], "k--", label=r"$T/(T+4N_e)$")
ax.legend(); fig.tight_layout()
fig.savefig("ex2b_split_fst.png", dpi=150)
```

**Questions**

- Solve $F_{ST}=T/(T+4N_e)$ for $T$ at your measured $F_{ST}$ — does it recover the
  simulated divergence time?
- Halve $N_e$ and repeat: for a fixed $T$, do smaller populations differentiate faster?

---

## Exercise 2C — Same $F_{ST}$, different histories

A **recent split with migration** and an **older split without migration** can give the
*same* $F_{ST}$. Find a matching pair, then look past $F_{ST}$.

```python
Ne = 5000
ts_mig, _   = two_pop_island(Ne, m=1.0 / Ne, seed=RNG)        # ongoing gene flow
ts_split, _ = two_pop_split(Ne, T=1300, seed=RNG)             # old, isolated

print("Fst (migration) =", round(fst(ts_mig), 3))
print("Fst (split)     =", round(fst(ts_split), 3))

# Look deeper: between-population shared vs private variation, or the joint SFS
def joint_sfs(ts):
    A = ts.samples(population=0); B = ts.samples(population=1)
    return ts.allele_frequency_spectrum([A, B], polarised=True, span_normalise=False)

fig, axes = plt.subplots(1, 2, figsize=(10, 4))
for ax, (lab, ts) in zip(axes, [("migration", ts_mig), ("split", ts_split)]):
    ax.imshow(np.log1p(joint_sfs(ts)), origin="lower", aspect="auto")
    ax.set_title(f"{lab}: joint SFS\n$F_{{ST}}$={fst(ts):.3f}")
    ax.set_xlabel("derived count in B"); ax.set_ylabel("derived count in A")
fig.tight_layout()
fig.savefig("ex2c_joint_sfs.png", dpi=150)
```

**Questions**

- Tune `m` and `T` until the two $F_{ST}$ values match. Now compare the **joint SFS** — do
  the histories look different even though $F_{ST}$ is the same?
- Which patterns of shared vs. private polymorphism would you expect under *ongoing* gene
  flow vs. an *old isolated split*? (Connects to ILS vs. introgression, deck 06.)

---

## Stretch

- Add a third "ghost" population that sends migrants into A only, and see how asymmetric
  gene flow distorts $F_{ST}$ and the joint SFS — a toy version of detecting introgression.
- Compute $F_{ST}$ in sliding windows under pure neutral migration to see how much
  outlier-like signal appears **by chance** (your null for deck 05 scans).
