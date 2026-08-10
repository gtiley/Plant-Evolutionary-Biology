# =============================================================================
# example_FigTree.R
# Working example for plot_timetree() using scripts/FigTree.tre
#
# NOTE: FigTree.tre comes from a short, unconverged MCMC run and is intended
# only to demonstrate the plotting workflow, not for biological interpretation.
#
# Run from the project root:
#   Rscript scripts/example_FigTree.R
# =============================================================================

suppressPackageStartupMessages({
  library(ape)
  library(ggtree)
  library(treeio)
  library(deeptime)
  library(ggplot2)
  library(patchwork)
})

source("scripts/geo_time_tree.R")

# ---- 1. Read the tree -------------------------------------------------------
# FigTree.tre uses the non-standard UTREE keyword; patch it so treeio can parse
# the node annotations.  A temporary file is used and removed on exit.
tmp <- tempfile(fileext = ".tre")
on.exit(unlink(tmp), add = TRUE)

lines <- readLines("scripts/FigTree.tre")
lines <- sub("^[ \t]*UTREE", "        TREE", lines)
writeLines(lines, tmp)

tr <- treeio::read.beast(tmp)

# ---- 2. Scale branch lengths to Ma ------------------------------------------
# Raw branch lengths are in units of ~100 Ma; multiply to get Ma.
SCALE <- 100
tr@phylo$edge.length        <- tr@phylo$edge.length * SCALE
tr@data[["0.95HPD"]] <- lapply(tr@data[["0.95HPD"]], function(x) {
  if (is.null(x) || length(x) != 2L) x else as.numeric(x) * SCALE
})

cat(sprintf("Root age: %.1f Ma   Tips: %d\n",
            get_tree_root_age(tr), ape::Ntip(tr@phylo)))

# ---- 3. Plot ----------------------------------------------------------------
p <- plot_timetree(
  tree            = tr,
  node_age_hpd    = "0.95HPD",
  show_tip_labels = FALSE,          # 644 tips — labels would be unreadable
  timescale_dat   = list("epochs", "periods", "eras"),
  abbrv           = list(TRUE, TRUE, FALSE),  # abbreviate fine-scale strips
  strip_size      = list(2, 2.5, 3),
  hpd_color       = "steelblue",
  hpd_alpha       = 0.25,
  hpd_linewidth   = 0.6,
  hpd_bar_height  = 0.3
)

# ---- 4. Save ----------------------------------------------------------------
out_pdf <- "scripts/example_FigTree.pdf"
out_png <- "scripts/example_FigTree.png"

ggplot2::ggsave(out_pdf, p, width = 12, height = 22)
ggplot2::ggsave(out_png, p, width = 12, height = 22, dpi = 150)

message("Saved:\n  ", out_pdf, "\n  ", out_png)
