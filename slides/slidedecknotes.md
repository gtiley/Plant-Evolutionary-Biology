# Slide Deck Notes — Quarto / revealjs cheat sheet

A working reference for the slide decks in this folder. Everything below reflects the
config that is **actually in play** here (`_quarto.yml`, `custom.scss`, `_template.qmd`),
not generic Quarto defaults. Keep this open while editing decks.

---

## 1. Folder layout

```
slides/
├── _quarto.yml        # project-wide config (applies to every deck)
├── custom.scss        # theme: colors, headings, custom slide elements
├── references.bib     # shared bibliography (BibTeX)
├── _template.qmd      # copy this to start a new deck
├── slidedecknotes.md  # this file
└── popgen/
    ├── 01-genetic-diversity.qmd   # fleshed-out
    ├── 02-…  …  06-….qmd          # stubs
    └── _site/ , .quarto/          # build output (git-ignored)
```

**Underscore rule:** files/folders starting with `_` are **not** rendered as outputs.
That is why `_template.qmd` never shows up in `_site/` — it is a source you copy, not a
deck. (`_quarto.yml` and `custom.scss` are config, also exempt.)

---

## 2. Render & preview

Run these from inside the `slides/` folder.

| Command | What it does |
|---|---|
| `quarto preview popgen/01-genetic-diversity.qmd` | Live preview in browser; auto-reloads on save. **Use this while writing.** |
| `quarto render popgen/01-genetic-diversity.qmd` | Build one deck to `_site/`. |
| `quarto render` | Build the whole project (every `*.qmd` + `popgen/*.qmd`). |

Output HTML lands in `_site/` (set by `output-dir` in `_quarto.yml`). That folder and
`.quarto/` are git-ignored — only the `.qmd`/`.scss`/`.bib`/`.yml` sources are tracked.

**Presenting:** open the rendered `.html`, then press `f` (fullscreen), `s` (speaker view
with notes + timer), `b` (chalkboard — draw on the slide), `o` (slide overview grid),
`?` (keyboard help), arrow keys to navigate.

---

## 3. `_quarto.yml` — the knobs in play

Project-level settings inherited by every deck. A deck can override any of these in its
own YAML front matter.

```yaml
project:
  type: default
  output-dir: _site          # where rendered HTML goes
  render:
    - "*.qmd"                 # top-level decks…
    - "popgen/*.qmd"          # …and the popgen module

author: "George P. Tiley"
bibliography: references.bib  # all decks share one .bib

format:
  revealjs:
    theme: [default, custom.scss]  # base theme + our overrides
    slide-number: c/t              # "current/total" bottom-right
    chalkboard: true               # press 'b' to draw in class
    incremental: false             # global default; opt in per slide
    html-math-method: mathjax      # full LaTeX rendering for derivations
    width: 1280                    # logical slide canvas (16:9)
    height: 720
    fig-align: center
    footer: "PB 495/595 · Plant Evolutionary Biology · Population Genomics"
    link-external-newwindow: true  # outbound links open in a new tab
    code-line-numbers: true
    smaller: false                 # set true on a dense slide if needed
```

Notes on a few:

- **`theme: [default, custom.scss]`** — list = layered. `default` first, our `custom.scss`
  applied on top. Other built-ins you could swap for `default`: `simple`, `serif`,
  `white`, `moon`, `night`, `league`, `sky`, `solarized`, `dracula`.
- **`incremental: false`** — bullets all appear at once by default. Reveal one-at-a-time
  per slide with `{.incremental}` (see §4) — that is the convention used in these decks.
- **`html-math-method: mathjax`** — required for the aligned derivations. Don't change to
  `katex` without spot-checking `\begin{aligned}`, `\binom`, `\mathbb`, `underbrace`.
- **`slide-number: c/t`** — other formats: `c` (current only), `h.v` (horizontal.vertical).

### Per-deck overrides

Each deck's front matter sets title/date and may override format. Example:

```yaml
---
title: "Genetic Diversity"
subtitle: "Population Genomics · PB 495/595 Plant Evolutionary Biology"
author: "George P. Tiley"
date: "2026-08-25"
date-format: "D MMMM YYYY"     # e.g. "25 August 2026"
# To override a project default just for this deck:
# format:
#   revealjs:
#     incremental: true
---
```

---

## 4. revealjs slide syntax used in these decks

### Slide breaks & section dividers

```markdown
# Section Title {.center}     ← level-1 header = section-divider slide
## Slide Title                ← level-2 header = a new content slide
```

`{.center}` vertically centers the divider content. Our `custom.scss` styles level-1
dividers with white text (intended for a colored band — see §5).

### Incremental bullets

```markdown
## Slide {.incremental}       ← whole slide reveals bullets one at a time
- first
- then this
```

Or force a pause anywhere with a standalone `. . .`:

```markdown
Point one is visible.

. . .                          ← click to continue

Point two appears on click.
```

### Fragment reveals (fine-grained)

```markdown
$$ p = \frac{2N_{11}+N_{12}}{2N} $$ {.fragment}   ← this equation waits for a click
```

### Two-column layout (equation/text beside a figure)

```markdown
:::: {.columns}

::: {.column width="55%"}
Left content (bullets, equation).
:::

::: {.column width="45%"}
Right content (figure / figure-prompt).
:::

::::
```

⚠️ **Fence-nesting gotcha:** the outer wrapper uses **four** colons `::::`, inner columns
use **three** `:::`. Mismatched colon counts are the #1 cause of a column "leaking" into
the next slide. If a slide renders scrambled, check these first.

### Callout boxes

```markdown
::: {.callout-note}
## Optional heading
Body text.
:::
```

Types: `note` (blue), `tip` (green), `important` (red), `warning` (orange), `caution`.
Used in the decks to flag key results and worked examples.

### Speaker notes (presenter view only, not on the slide)

```markdown
::: {.notes}
Reminder to say X; this assumes neutrality and equilibrium.
:::
```

### Math

- Inline: `$H = 2pq$`.
- Display: `$$ … $$`.
- Multi-line derivation:

```markdown
$$
\begin{aligned}
H_t &= H_{t-1}\left(1 - \tfrac{1}{2N}\right) \\
    &= H_0\left(1 - \tfrac{1}{2N}\right)^{t}.
\end{aligned}
$$
```

### Citations & references

- Cite inline with `@key` (e.g. `@leffler2012`) or `[@key]` for a parenthetical.
- Keys live in `references.bib` (current keys: `coop_notes`, `leffler2012`, `hardy1908`,
  `weinberg1908`, `watterson1975`, `kimura1968`, `tajima1989`, `wright1943`,
  `wahlund1928`).
- End the deck with a references slide:

```markdown
# References {.center}

::: {#refs}
:::
```

---

## 5. `custom.scss` — what we changed and how to use it

SCSS theme files have two labeled regions. **Order matters:** `defaults` (variables) must
come before `rules` (CSS), and variable definitions feed the base theme.

```scss
/*-- scss:defaults --*/   ← Sass variables; override theme defaults here
/*-- scss:rules --*/      ← literal CSS rules applied after the theme
```

### Color palette (defaults)

```scss
$ncsu-red:   #CC0000;   // accent: headings, links, figure-prompt border
$ncsu-black: #000000;
$ink:        #1a1a1a;   // body text
$muted:      #6b6b6b;   // captions, cross-refs, de-emphasized text
```

Change the deck's whole accent color by editing `$ncsu-red` in one place.

### Typography / heading variables (defaults)

| Variable | Value | Effect |
|---|---|---|
| `$presentation-font-size-root` | `30px` | base text size; raise/lower to fit content globally |
| `$presentation-heading-color` | `$ncsu-red` | all headings |
| `$presentation-h1-font-size` | `1.9em` | section dividers |
| `$presentation-h2-font-size` | `1.4em` | slide titles |
| `$body-color` | `$ink` | body text |
| `$link-color` | `$ncsu-red` | hyperlinks |

These are **revealjs theme variables** — Quarto exposes a whole set (`$presentation-*`,
`$body-bg`, `$code-block-*`, etc.). Override any of them in the `defaults` block.

### Custom rules (the classes you can use in slides)

| Class / selector | What it does | How to invoke in a `.qmd` |
|---|---|---|
| `.figure-prompt` | Dashed red box marking a figure to source later (with red **FIGURE** label) | `::: {.figure-prompt}` … `:::` |
| `.source` / `figcaption` / `.caption` | Small muted italic credit line under a figure | `<span class="source">Source: … </span>` |
| `.xref` | Muted small italic forward/back reference to another lecture | `<span class="xref">→ Sep 8</span>` |
| `.smaller-list` | Shrinks a bullet list on a dense slide | `## Slide {.smaller-list}` |
| `.callout` (sizing) | Slightly smaller text inside callout boxes | automatic in callouts |
| level-1 `h1` | White heading text for section dividers | automatic on `# Section` |

**Figure-prompt + alt-text workflow** (the convention in these decks):

```markdown
::: {.figure-prompt}
**FIGURE** — what to show / source. (license note if known)
:::

<!-- ALT TEXT (required when the image is added) — pick & refine one,
     then set as fig-alt="…" on the ![](…) you insert:
  A) "literal description of what the figure shows"
  B) "description emphasizing the take-home pattern"
-->
```

When the real figure is ready, replace the prompt box with:

```markdown
![](images/your-figure.png){fig-alt="…the alt text you chose…"}
```

- Put images in an `images/` folder next to the deck.
- **`fig-alt` is required** for accessibility — every `![]()` needs one. The prompt is
  *visible* on the slide (a reminder); the alt text stays in a comment until a real image
  exists, because `fig-alt` only attaches to an actual image.
- Add a credit line under reused figures with `<span class="source">…</span>`.

---

## 6. Quick gotchas

- **Colon counts:** `::::` (outer) vs `:::` (inner). Mismatches scramble slides. (§4)
- **Underscore = not rendered:** `_template.qmd` won't appear in `_site/`; that's intended.
- **SCSS order:** `scss:defaults` (variables) before `scss:rules` (CSS).
- **Blank lines around fences:** leave a blank line before/after `:::` blocks and `$$`
  math, or Markdown may not parse them.
- **MathJax vs KaTeX:** these decks rely on MathJax for `\begin{aligned}` etc. Don't switch
  math engines without re-checking the derivation slides.
- **New deck:** copy `_template.qmd` → `popgen/NN-topic.qmd`, edit front matter, render.
- **New citation:** add the BibTeX entry to `references.bib`, then cite with `@key`.

---

## 7. Handy links

- Quarto revealjs reference: <https://quarto.org/docs/presentations/revealjs/>
- revealjs advanced (fragments, layout, themes): <https://quarto.org/docs/presentations/revealjs/advanced.html>
- Theming / SCSS variables: <https://quarto.org/docs/presentations/revealjs/themes.html>
- Callout blocks: <https://quarto.org/docs/authoring/callouts.html>
- Citations: <https://quarto.org/docs/authoring/citations.html>
