# Exercise 3 — Life history over time: the shift to selfing

**Population Genomics · PB 495/595 Plant Evolutionary Biology**

> Reinforces deck 03 (Outcrossing, Selfers, Apomicts) and ties back to deck 01 ($N_e$).
> Concepts: selfing's effect on $N_e$ and recombination, the inbreeding coefficient
> $\hat F = \tfrac{s}{2-s}$, and how a **change in mating system over time** is recorded in
> (and slowly erased from) genetic diversity.

⚠️ **Draft for review.** Code is idiomatic `msprime` 1.x but unexecuted here — validate
before class.

### A modeling note (read this first)

`msprime` is a **coalescent** simulator and does **not** model selfing directly. We encode
selfing through its two population-genetic consequences (deck 03):

$$
\hat F = \frac{s}{2-s}, \qquad
N_e^{\text{self}} = \frac{N_e}{1+\hat F}, \qquad
r^{\text{eff}} = r\,(1-\hat F).
$$

So selfing **shrinks $N_e$** (toward half) and **crushes effective recombination** (toward
zero). We pass the *rescaled* size and recombination rate to `msprime`. This is an
approximation — good enough to build intuition, not a substitute for a forward simulator
(e.g. SLiM) if you need explicit selfing.

---

## Learning goals

1. Quantify how selfing rate $s$ depresses diversity via $N_e^{\text{self}}$.
2. Simulate a **transition** from outcrossing to selfing at a time $T_{\text{shift}}$ in the
   past, and watch diversity decay toward the new equilibrium.
3. See that the **timescale of equilibration is ~$N_e$ generations** — recent shifts are
   only partway there.

## Setup

```python
import msprime
import numpy as np
import matplotlib.pyplot as plt

RNG = 11

def selfing_scaling(s):
    """Return (F, Ne factor, recombination factor) for selfing rate s."""
    F = s / (2 - s)
    return F, 1.0 / (1.0 + F), (1.0 - F)
```

### Helper + plotting functions

```python
def simulate_constant(s, Ne=10000, mu=1e-8, L=1e6, recomb=1e-8,
                      n_diploid=25, seed=RNG):
    """A population selfing at constant rate s for all time."""
    F, ne_fac, rec_fac = selfing_scaling(s)
    ts = msprime.sim_ancestry(
        samples=n_diploid, population_size=Ne * ne_fac, sequence_length=L,
        recombination_rate=recomb * rec_fac, random_seed=seed)
    ts = msprime.sim_mutations(ts, rate=mu, random_seed=seed)
    return ts

def simulate_shift(s, T_shift, Ne=10000, mu=1e-8, L=1e6,
                   recomb=1e-8, n_diploid=25, seed=RNG):
    """Outcrossing until T_shift generations ago, then selfing to the present.

    Diversity (pi) depends on coalescence times, so we vary N_e by epoch and keep
    recombination fixed (pi is ~recombination-independent; see the LD stretch for
    the recombination side of the story).
    """
    F, ne_fac, _ = selfing_scaling(s)
    dem = msprime.Demography()
    dem.add_population(name="A", initial_size=Ne * ne_fac)            # recent: selfing
    dem.add_population_parameters_change(time=T_shift, initial_size=Ne, population="A")  # older: outcrossing
    ts = msprime.sim_ancestry(samples=n_diploid, demography=dem,
                              sequence_length=L, recombination_rate=recomb,
                              random_seed=seed)
    return msprime.sim_mutations(ts, rate=mu, random_seed=seed)

def pi(ts):
    return ts.diversity()

def plot_xy(x, y, xlabel, ylabel, title, ax=None, **kw):
    ax = ax or plt.gca()
    ax.plot(x, y, marker="o", **kw)
    ax.set_xlabel(xlabel); ax.set_ylabel(ylabel); ax.set_title(title)
    return ax
```

---

## Exercise 3A — How much diversity does selfing cost?

```python
mu, Ne = 1e-8, 10000
s_grid = [0.0, 0.5, 0.9, 0.95, 0.99]
pis = [pi(simulate_constant(s, Ne=Ne, mu=mu, seed=RNG)) for s in s_grid]

for s, p in zip(s_grid, pis):
    F = s / (2 - s)
    print(f"s={s:<4}  F={F:.3f}  pi={p:.5f}")

fig, ax = plt.subplots(figsize=(5, 4))
plot_xy(s_grid, pis, "selfing rate $s$", r"diversity $\pi$",
        "Selfing depresses diversity", ax=ax, label="measured")
ax.plot(s_grid, [4 * Ne / (1 + s / (2 - s)) * mu for s in s_grid], "k--",
        label=r"$4N_e\mu/(1+\hat F)$")
ax.legend(); fig.tight_layout()
fig.savefig("ex3a_pi_vs_selfing.png", dpi=150)
```

**Questions**

- A highly selfing plant ($s=0.99$) — by what factor is $\pi$ reduced vs. an outcrosser?
  Compare to the $1/(1+\hat F)$ prediction.
- Connect to **deck 03**: a selfing rate of $s=0.9$ gives what equilibrium $\hat F$? Does
  the diversity reduction match?

---

## Exercise 3B — A mating-system shift, and the memory of the past

A lineage that **recently** switched to selfing still carries the diversity of its
outcrossing past; one that switched **long ago** has drifted down to the selfer equilibrium.
Vary $T_{\text{shift}}$ and watch.

```python
mu, Ne, s = 1e-8, 10000, 0.95
T_grid = [0, 500, 1000, 2000, 5000, 10000, 20000, 50000]
pis = [pi(simulate_shift(s, T, Ne=Ne, mu=mu, seed=RNG)) for T in T_grid]

pi_out  = 4 * Ne * mu                          # outcrosser equilibrium
pi_self = 4 * Ne / (1 + s / (2 - s)) * mu      # selfer equilibrium

fig, ax = plt.subplots(figsize=(5.5, 4))
plot_xy(T_grid, pis, r"time since shift to selfing $T_{\rm shift}$ (gen)",
        r"diversity $\pi$", "Diversity remembers a recent shift", ax=ax, label="measured")
ax.axhline(pi_out,  ls=":", color="green", label="outcrosser equilibrium")
ax.axhline(pi_self, ls=":", color="red",   label="selfer equilibrium")
ax.legend(); fig.tight_layout()
fig.savefig("ex3b_pi_vs_shift_time.png", dpi=150)
```

**Questions**

- For small $T_{\text{shift}}$, is $\pi$ closer to the outcrosser or selfer equilibrium? Why?
- Roughly how many generations until $\pi$ settles near the selfer equilibrium? Relate this
  to the equilibration timescale $\sim N_e$ generations (diversity is slow to respond).
- **Interpretation:** a recently-derived selfer (e.g. *Capsella rubella*, deck 03) can still
  show relatively high diversity — the genome hasn't caught up to its new life history.

---

## Exercise 3C (stretch) — Selfing and linkage disequilibrium

Selfing crushes *effective recombination*, so LD extends much further. Compare an outcrosser
to a selfer at matched $N_e$.

```python
def r2_decay(ts, n_sites=300, seed=RNG):
    """Crude LD decay: r^2 between pairs of sampled segregating sites vs. distance."""
    rng = np.random.default_rng(seed)
    G = ts.genotype_matrix()                       # (sites x samples), 0/1
    pos = ts.tables.sites.position
    keep = rng.choice(G.shape[0], size=min(n_sites, G.shape[0]), replace=False)
    keep.sort()
    G, pos = G[keep], pos[keep]
    d, r2 = [], []
    for i in range(len(keep)):
        for j in range(i + 1, len(keep)):
            r = np.corrcoef(G[i], G[j])[0, 1]
            if np.isfinite(r):
                d.append(abs(pos[j] - pos[i])); r2.append(r ** 2)
    return np.array(d), np.array(r2)

# Selfer: rescale BOTH Ne and recombination
F, ne_fac, rec_fac = selfing_scaling(0.95)
ts_out  = msprime.sim_mutations(msprime.sim_ancestry(
    25, population_size=10000, sequence_length=1e6,
    recombination_rate=1e-8, random_seed=RNG), rate=1e-8, random_seed=RNG)
ts_self = msprime.sim_mutations(msprime.sim_ancestry(
    25, population_size=10000 * ne_fac, sequence_length=1e6,
    recombination_rate=1e-8 * rec_fac, random_seed=RNG), rate=1e-8, random_seed=RNG)

fig, ax = plt.subplots(figsize=(5.5, 4))
for lab, ts, c in [("outcrosser", ts_out, "green"), ("selfer s=0.95", ts_self, "red")]:
    d, r2 = r2_decay(ts)
    order = np.argsort(d)
    # binned mean for readability
    bins = np.linspace(0, d.max(), 25)
    idx = np.digitize(d, bins)
    mean_r2 = [r2[idx == b].mean() if np.any(idx == b) else np.nan for b in range(1, len(bins))]
    ax.plot(bins[1:], mean_r2, label=lab, color=c)
ax.set_xlabel("distance (bp)"); ax.set_ylabel(r"mean $r^2$")
ax.set_title("Selfing extends LD"); ax.legend(); fig.tight_layout()
fig.savefig("ex3c_ld_decay.png", dpi=150)
```

**Questions**

- Which curve decays more slowly? By how much? Tie it back to $r^{\text{eff}} = r(1-\hat F)$.
- Why does extended LD make selfers harder to use for fine-mapping (GWAS) — and what does it
  do to the reach of linked selection (deck 04)?

---

## Where this connects

- **Population size** governs the *level* of diversity (Exercise 1).
- **Gene flow** governs differentiation *among* populations (Exercise 2).
- **Life history** (here, mating system) changes the *effective* size and recombination —
  and, when it shifts over time, leaves a transient signature that diversity only slowly
  forgets (this exercise).
