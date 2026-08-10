# =============================================================================
# geo_time_tree.R
# =============================================================================
# Builds a figure of a time-calibrated phylogenetic tree (branch lengths in
# millions of years) with geological timescale strips, and optionally stacked
# paleo-atmospheric CO2 and/or surface temperature panels sharing the same
# time axis.
#
# Entry point:  plot_timetree()
#   Returns a patchwork object (ggplot-like).  Print to display, or pass to
#   ggplot2::ggsave().
#
# Required packages:
#   install.packages(c("ape", "ggplot2", "patchwork"))
#   if (!requireNamespace("BiocManager", quietly = TRUE))
#     install.packages("BiocManager")
#   BiocManager::install("ggtree")
#   install.packages("deeptime")          # CRAN
#   # or: remotes::install_github("willgearty/deeptime")
#
# =============================================================================
# PALEO-CLIMATE DATA  (optional)
# =============================================================================
# Supply a data.frame (typically read from CSV) via the `paleo_data` argument.
# Recognised column names:
#
#   age_Ma      – age in millions of years before present  [required]
#   co2_ppm     – atmospheric CO2 in ppm                   [CO2 panel]
#   co2_lower   – lower 95% CI for CO2                     [ribbon, optional]
#   co2_upper   – upper 95% CI for CO2                     [ribbon, optional]
#   temp_C      – surface temperature in degrees C         [temp panel]
#   temp_lower  – lower 95% CI for temperature             [ribbon, optional]
#   temp_upper  – upper 95% CI for temperature             [ribbon, optional]
#
# CO2 and temperature panels are generated automatically for whichever
# columns are present; CI ribbons appear when both lower and upper columns
# exist for a given variable.
#
# Recommended data sources
# ------------------------
# CO2 · Cenozoic proxy compilation (~0-65 Ma):
#       Foster et al. 2017, Science Advances
#       doi:10.1126/sciadv.1501894  →  Supplement Table S1
#
#     · Phanerozoic (~0-540 Ma), model + proxy compilation:
#       GEOCARB III  —  Berner & Kothavala (2001) Am. J. Sci. 301:182-204
#       Royer (2014) Geochim. Cosmochim. Acta 142:405-412
#       doi:10.1016/j.gca.2014.09.014
#
# Temp· Cenozoic benthic d18O stack (~0-65 Ma):
#       Westerhold et al. 2020, Science 369:1383-1387
#       doi:10.1126/science.aba6853
#
#     · Phanerozoic (~0-540 Ma):
#       Scotese et al. 2021, Earth-Science Reviews 215:103503
#       doi:10.1016/j.earscirev.2021.103503  (PALEOMAP project)
# =============================================================================

# ---- Packages ---------------------------------------------------------------
library(ape)
library(ggtree)
library(deeptime)
library(ggplot2)
library(patchwork)

# =============================================================================
# HELPERS
# =============================================================================

# Returns the root age of a time-calibrated tree (phylo or treedata) in Ma.
get_tree_root_age <- function(tree) {
  tr <- if (inherits(tree, "treedata")) tree@phylo else tree
  max(ape::node.depth.edgelength(tr))
}

# Returns a vector of sensible round-number axis break positions (positive Ma)
# for a given root age.  The interval is chosen automatically by depth.
make_time_breaks <- function(root_age) {
  interval <- if      (root_age <=  20)   5
              else if (root_age <=  60)  10
              else if (root_age <= 150)  25
              else if (root_age <= 400)  50
              else                      100
  seq(0, ceiling(root_age / interval) * interval, by = interval)
}

# .extract_hpd_df -------------------------------------------------------
# Extract node-age HPD intervals from a treeio treedata object and return a
# data.frame ready for geom_errorbarh() in the revts() coordinate system.
#
# tree       treedata object (e.g. from treeio::read.beast())
# plot_data  p$data from revts(ggtree(tree)); supplies node y-positions
# hpd_col    column name in tree@data storing the HPD intervals.
#            Expected format: a list-column where each element is a 2-element
#            numeric vector c(lower_Ma, upper_Ma), ages as positive values
#            from the present (the convention used by BEAST, MrBayes,
#            MCMCtree, RevBayes via treeio).
#            Common names:  "height_95%_HPD"  (BEAST 1/2, MrBayes)
#                           "height_0.95_HPD" (BEAST 2 alternative)
#                           "age_95%HPD"      (RevBayes / MCMCtree)
#
# After revts(): present = 0, past = negative.
# HPD stored as positive ages, so:
#   xmin = -hpd_upper  (older bound, more negative)
#   xmax = -hpd_lower  (younger bound, less negative)
#
.extract_hpd_df <- function(tree, plot_data, hpd_col) {
  ann <- as.data.frame(tree@data)

  if (!hpd_col %in% names(ann)) {
    warning(sprintf(
      "HPD column '%s' not found in tree annotations.\n  Available: %s",
      hpd_col, paste(names(ann), collapse = ", ")
    ))
    return(NULL)
  }

  raw <- ann[[hpd_col]]

  if (is.list(raw)) {
    # Most common treeio format: list-column, each element c(lower, upper)
    valid    <- lengths(raw) == 2L
    if (!any(valid, na.rm = TRUE)) {
      warning("HPD column does not contain 2-element intervals.")
      return(NULL)
    }
    hpd_low  <- vapply(raw[valid], function(x) as.numeric(x[[1L]]), numeric(1L))
    hpd_high <- vapply(raw[valid], function(x) as.numeric(x[[2L]]), numeric(1L))
    node_ids <- ann$node[valid]
  } else if (is.matrix(raw) && ncol(raw) == 2L) {
    hpd_low  <- raw[, 1L]
    hpd_high <- raw[, 2L]
    node_ids <- ann$node
  } else {
    warning(
      "Unrecognised HPD column format. ",
      "Expected a list-column of 2-element vectors or a 2-column matrix."
    )
    return(NULL)
  }

  df <- data.frame(node = node_ids, hpd_low = hpd_low, hpd_high = hpd_high)
  df <- merge(df, plot_data[, c("node", "y")], by = "node")
  df <- df[!is.na(df$y) & !is.na(df$hpd_low) & !is.na(df$hpd_high), ]

  if (nrow(df) == 0L) {
    warning("No valid HPD values found after merging with tree node positions.")
    return(NULL)
  }

  df$xmin <- -df$hpd_high
  df$xmax <- -df$hpd_low
  df
}

# =============================================================================
# INTERNAL PANEL BUILDERS  (called by plot_timetree; prefix . marks internal)
# =============================================================================

# .build_tree_plot ------------------------------------------------------------
# Build the phylogenetic tree panel with geological timescale strips.
#
# tree           phylo or treedata object
# timescale_dat  list of deeptime dataset names, listed INNERMOST first
#                (fine → coarse, e.g. list("epochs", "periods", "eras")).
#                Built-in options: "eons", "eras", "periods", "epochs", "stages"
#                Strips are stacked outward in list order.
# abbrv          logical or list<logical>: abbreviate interval names?
#                Pass a list (one entry per timescale_dat entry) for per-strip
#                control.  For Phanerozoic-depth trees consider
#                list(TRUE, TRUE, FALSE) so narrow epoch/period strips are
#                abbreviated while era labels remain readable.
# strip_size     numeric or list<numeric>: strip label font size (pts).
# show_x_axis    logical: show numeric Ma tick labels on the time axis?
#                Set TRUE only on the bottom-most panel of the final figure.
# node_age_hpd   character: column name in treedata@data holding HPD intervals.
#                Ignored for plain phylo objects.
#
.build_tree_plot <- function(
  tree,
  root_age,
  timescale_dat    = list("epochs", "periods", "eras"),
  show_tip_labels  = TRUE,
  xlim_extra       = NULL,
  tip_label_size   = 3,
  show_x_axis      = FALSE,
  x_breaks         = NULL,
  abbrv            = FALSE,
  strip_size       = 3,
  node_age_hpd     = NULL,
  hpd_color        = "grey30",
  hpd_alpha        = 0.50,
  hpd_linewidth    = 1.5,
  hpd_bar_height   = 0.4
) {
  if (is.null(xlim_extra)) xlim_extra <- root_age * 0.05
  if (is.null(x_breaks))   x_breaks   <- make_time_breaks(root_age)

  n_dat     <- length(timescale_dat)
  xlim_left <- -(root_age + xlim_extra)
  tr_phylo  <- if (inherits(tree, "treedata")) tree@phylo else tree
  n_tips    <- ape::Ntip(tr_phylo)

  # coord_geo stacks strips: first entry is closest to the plot (innermost),
  # subsequent entries are progressively further out (outermost).
  pos_list   <- rep(list("bottom"), n_dat)
  abbrv_list <- if (is.list(abbrv))      abbrv      else rep(list(abbrv),      n_dat)
  size_list  <- if (is.list(strip_size)) strip_size else rep(list(strip_size), n_dat)

  # revts() negates x-coordinates so tips sit at 0 and root at -root_age.
  # coord_geo(neg = TRUE) interprets this as time running left (past) to
  # right (present).
  p <- revts(ggtree(tree))

  # --- Node-age HPD bars (optional; rendered before branches) --------------
  # HPD values from treeio are positive ages-from-present; after revts() the
  # axis is negative, so .extract_hpd_df() negates them automatically.
  if (!is.null(node_age_hpd)) {
    if (!inherits(tree, "treedata")) {
      warning(
        "node_age_hpd is set but tree is not a treedata object. ",
        "Read the tree with a treeio reader (e.g. treeio::read.beast()) ",
        "to access HPD annotations."
      )
    } else {
      hpd_df <- .extract_hpd_df(tree, p$data, node_age_hpd)
      if (!is.null(hpd_df)) {
        p <- p + geom_errorbar(
          data        = hpd_df,
          aes(y = y, xmin = xmin, xmax = xmax),
          orientation = "y",
          width       = hpd_bar_height,
          linewidth   = hpd_linewidth,
          color       = hpd_color,
          alpha       = hpd_alpha,
          inherit.aes = FALSE
        )
      }
    }
  }

  if (show_tip_labels) {
    p <- p + geom_tiplab(size = tip_label_size)
  }

  p <- p +
    coord_geo(
      dat               = timescale_dat,
      xlim              = c(xlim_left, 0),
      ylim              = c(-2, n_tips + 0.5),
      pos               = pos_list,
      neg               = TRUE,
      abbrv             = abbrv_list,
      size              = size_list,
      center_end_labels = TRUE
    ) +
    scale_x_continuous(
      breaks = -x_breaks,   # axis positions are negative after revts()
      labels =  x_breaks,   # labels display as positive Ma
      expand = expansion(mult = 0)
    ) +
    theme_tree2() +
    theme(plot.margin = margin(5, 5, 0, 5, unit = "pt"))

  if (!show_x_axis) {
    p <- p + theme(
      axis.text.x  = element_blank(),
      axis.ticks.x = element_blank(),
      axis.title.x = element_blank()
    )
  } else {
    p <- p + xlab("Age (Ma)")
  }

  p
}


# .build_co2_panel ------------------------------------------------------------
# Build the atmospheric CO2 panel.
#
# x-axis uses the same negative-coordinate convention as the tree panel
# (x = -age_Ma, limits = c(xlim_left, 0)) so the axes register correctly
# when stacked with patchwork.
#
.build_co2_panel <- function(paleo_data, xlim_left, x_breaks,
                             show_x_axis = FALSE) {
  has_ci <- all(c("co2_lower", "co2_upper") %in% names(paleo_data))

  p <- ggplot(paleo_data, aes(x = -age_Ma, y = co2_ppm))

  if (has_ci) {
    p <- p + geom_ribbon(
      aes(ymin = co2_lower, ymax = co2_upper),
      alpha = 0.20, fill = "#2166ac"
    )
  }

  p <- p +
    geom_line(color = "#2166ac", linewidth = 0.7) +
    scale_x_continuous(
      limits = c(xlim_left, 0),
      breaks = -x_breaks,
      labels = if (show_x_axis) x_breaks else NULL,
      expand = expansion(mult = 0)
    ) +
    labs(
      x = if (show_x_axis) "Age (Ma)" else NULL,
      y = expression("Atm. CO"[2] * " (ppm)")
    ) +
    theme_classic(base_size = 10) +
    theme(
      axis.title.x = if (show_x_axis) element_text() else element_blank(),
      axis.text.x  = if (show_x_axis) element_text() else element_blank(),
      axis.ticks.x = if (show_x_axis) element_line() else element_blank(),
      plot.margin  = margin(0, 5, 0, 5, unit = "pt")
    )

  p
}


# .build_temp_panel -----------------------------------------------------------
# Build the surface temperature panel.
#
.build_temp_panel <- function(paleo_data, xlim_left, x_breaks,
                              show_x_axis = TRUE) {
  has_ci <- all(c("temp_lower", "temp_upper") %in% names(paleo_data))

  p <- ggplot(paleo_data, aes(x = -age_Ma, y = temp_C))

  if (has_ci) {
    p <- p + geom_ribbon(
      aes(ymin = temp_lower, ymax = temp_upper),
      alpha = 0.20, fill = "#d6604d"
    )
  }

  p <- p +
    geom_line(color = "#d6604d", linewidth = 0.7) +
    scale_x_continuous(
      limits = c(xlim_left, 0),
      breaks = -x_breaks,
      labels = if (show_x_axis) x_breaks else NULL,
      expand = expansion(mult = 0)
    ) +
    labs(
      x = if (show_x_axis) "Age (Ma)" else NULL,
      y = "Surface temp. (\u00b0C)"
    ) +
    theme_classic(base_size = 10) +
    theme(
      axis.title.x = if (show_x_axis) element_text() else element_blank(),
      axis.text.x  = if (show_x_axis) element_text() else element_blank(),
      axis.ticks.x = if (show_x_axis) element_line() else element_blank(),
      plot.margin  = margin(0, 5, 5, 5, unit = "pt")
    )

  p
}


# =============================================================================
# MAIN FUNCTION
# =============================================================================

#' Plot a time-calibrated phylogenetic tree with geological timescale
#'
#' @param tree            An \code{ape::phylo} object with branch lengths in
#'                        millions of years (Ma).
#' @param paleo_data      Optional \code{data.frame} with paleo-climate data.
#'                        Must contain \code{age_Ma}; optionally any of
#'                        \code{co2_ppm}, \code{co2_lower}, \code{co2_upper},
#'                        \code{temp_C}, \code{temp_lower}, \code{temp_upper}.
#'                        CO2 and temperature panels are added automatically
#'                        based on which columns are present.
#' @param timescale_dat   List of deeptime interval dataset names, ordered
#'                        innermost to outermost (finest to coarsest).
#'                        Default: \code{list("epochs", "periods", "eras")}.
#'                        Available names: \code{"eons"}, \code{"eras"},
#'                        \code{"periods"}, \code{"epochs"}, \code{"stages"}.
#' @param show_tip_labels Logical; show tip labels on the tree.  Default TRUE.
#' @param xlim_extra      Extra horizontal space (Ma) added beyond the root.
#'                        Defaults to 5% of root age; increase to prevent
#'                        tip-label clipping on wide labels.
#' @param tip_label_size  Font size (pts) for tip labels.  Default 3.
#' @param panel_heights   Numeric vector of relative panel heights, one entry
#'                        per panel (tree + any paleo panels in order).
#'                        Default: tree = 4, each paleo panel = 1.2.
#' @param abbrv           Logical or list<logical>: abbreviate geological
#'                        interval names in strips?  Default FALSE.  For
#'                        Phanerozoic-depth trees, consider
#'                        \code{list(TRUE, TRUE, FALSE)} so narrow epoch and
#'                        period strips abbreviate while era labels are full.
#'                        Pass a list with one entry per \code{timescale_dat}
#'                        element for per-strip control.
#' @param strip_size      Numeric or list<numeric>: strip label font size (pts).
#'                        Default 3.  Pass a list (one entry per
#'                        \code{timescale_dat} element) for per-strip sizing.
#' @param node_age_hpd    Character; column name in a \code{treedata} object
#'                        (from \code{treeio}) containing node-age 95\% HPD
#'                        intervals.  The column must be a list-column where
#'                        each element is \code{c(lower_Ma, upper_Ma)} with
#'                        ages as positive values from the present.
#'                        Common names by tool:
#'                        \itemize{
#'                          \item BEAST 1/2, MrBayes: \code{"height_95\%_HPD"}
#'                          \item BEAST 2 (alt.): \code{"height_0.95_HPD"}
#'                          \item RevBayes / MCMCtree: \code{"age_95\%HPD"}
#'                        }
#'                        Ignored with a warning when \code{tree} is a plain
#'                        \code{phylo} object.  Default NULL (no HPD bars).
#' @param hpd_color       Colour of HPD bars.  Default \code{"grey30"}.
#' @param hpd_alpha       Opacity of HPD bars (0–1).  Default 0.5.
#' @param hpd_linewidth   Line width of HPD bars.  Default 1.5.
#' @param hpd_bar_height  Vertical height of HPD bar end-caps.  Default 0.4.
#'
#' @return A \code{patchwork} object.  Use \code{print()} to display or
#'   \code{ggplot2::ggsave()} to save.
#'
#' @note
#'   \strong{Axis alignment:}  patchwork aligns panels by matching coordinate
#'   ranges.  Slight left-margin drift can occur between the tree panel (which
#'   has no y-axis text) and paleo panels (which do).  For pixel-perfect
#'   alignment, replace the final \code{wrap_plots()} call with
#'   \code{deeptime::ggarrange2(plotlist = panels, nrow = n_panels,
#'   heights = panel_heights)}, which uses gtable decomposition designed
#'   specifically for \code{coord_geo()} plots.
#'
#' @examples
#' \dontrun{
#' library(ape)
#'
#' # --- Tree only (ape::phylo) ----------------------------------------------
#' tree <- read.tree("my_calibrated.nwk")    # Newick with Ma branch lengths
#' # tree <- read.nexus("my_calibrated.nex") # NEXUS alternative
#'
#' p <- plot_timetree(tree)
#' print(p)
#'
#' # --- BEAST / node-age HPD bars -------------------------------------------
#' # Read annotated tree (treedata object); branch lengths must be in Ma
#' beast_tree <- treeio::read.beast("my_beast_output.tre")
#' # Other readers: treeio::read.mrbayes(), treeio::read.mcmctree(),
#' #                treeio::read.raxml(), treeio::read.phyml()
#'
#' # Inspect available annotation columns:
#' # head(as.data.frame(beast_tree@data))
#'
#' p <- plot_timetree(
#'   tree         = beast_tree,
#'   node_age_hpd = "height_95%_HPD",  # column from treeio; adjust name as needed
#'   hpd_color    = "steelblue",
#'   hpd_alpha    = 0.35
#' )
#' print(p)
#'
#' # --- With paleo data -----------------------------------------------------
#' # CSV columns: age_Ma, co2_ppm, co2_lower, co2_upper, temp_C,
#' #              temp_lower, temp_upper  (lower/upper are optional)
#' paleo <- read.csv("paleo_climate.csv")
#'
#' p <- plot_timetree(
#'   tree            = tree,
#'   paleo_data      = paleo,
#'   timescale_dat   = list("epochs", "periods", "eras"),
#'   show_tip_labels = TRUE,
#'   panel_heights   = c(4, 1.2, 1.2)   # tree : CO2 : temp
#' )
#' print(p)
#'
#' # --- Fine-tuning ---------------------------------------------------------
#' # More space for long tip labels:
#' p <- plot_timetree(tree, xlim_extra = 20)
#'
#' # Abbreviated epoch/period names (recommended for deep-time trees):
#' p <- plot_timetree(tree, abbrv = list(TRUE, TRUE, FALSE))
#'
#' # Four-row timescale (stages added):
#' p <- plot_timetree(tree, timescale_dat = list("stages", "epochs",
#'                                               "periods", "eras"))
#'
#' # --- Save ----------------------------------------------------------------
#' ggplot2::ggsave("timetree.pdf", p, width = 10, height = 8)
#' ggplot2::ggsave("timetree.png", p, width = 10, height = 8, dpi = 300)
#' }
plot_timetree <- function(
  tree,
  paleo_data       = NULL,
  timescale_dat    = list("epochs", "periods", "eras"),
  show_tip_labels  = TRUE,
  xlim_extra       = NULL,
  tip_label_size   = 3,
  panel_heights    = NULL,
  abbrv            = FALSE,
  strip_size       = 3,
  node_age_hpd     = NULL,
  hpd_color        = "grey30",
  hpd_alpha        = 0.50,
  hpd_linewidth    = 1.5,
  hpd_bar_height   = 0.4
) {
  stopifnot(
    "tree must be an ape::phylo or treeio::treedata object" =
      inherits(tree, "phylo") || inherits(tree, "treedata")
  )
  if (!is.null(paleo_data)) {
    stopifnot(
      "paleo_data must be a data.frame"       = is.data.frame(paleo_data),
      "paleo_data must contain column age_Ma" = "age_Ma" %in% names(paleo_data)
    )
  }

  # --- Detect which paleo panels to build ----------------------------------
  has_co2  <- !is.null(paleo_data) && "co2_ppm" %in% names(paleo_data)
  has_temp <- !is.null(paleo_data) && "temp_C"  %in% names(paleo_data)
  n_paleo  <- has_co2 + has_temp

  # --- Axis geometry -------------------------------------------------------
  root_age <- get_tree_root_age(tree)
  if (root_age < 0.001)
    stop(
      "Root age is effectively 0 Ma. ",
      "Ensure tree branch lengths are in millions of years."
    )

  if (is.null(xlim_extra)) xlim_extra <- root_age * 0.05
  x_breaks  <- make_time_breaks(root_age)
  xlim_left <- -(root_age + xlim_extra)

  # --- Tree panel ----------------------------------------------------------
  # Ma tick labels appear on the tree only when there are no paleo panels
  # below it (i.e. the tree IS the bottom-most panel).
  tree_plot <- .build_tree_plot(
    tree            = tree,
    root_age        = root_age,
    timescale_dat   = timescale_dat,
    show_tip_labels = show_tip_labels,
    xlim_extra      = xlim_extra,
    tip_label_size  = tip_label_size,
    show_x_axis     = (n_paleo == 0),
    x_breaks        = x_breaks,
    abbrv           = abbrv,
    strip_size      = strip_size,
    node_age_hpd    = node_age_hpd,
    hpd_color       = hpd_color,
    hpd_alpha       = hpd_alpha,
    hpd_linewidth   = hpd_linewidth,
    hpd_bar_height  = hpd_bar_height
  )

  if (n_paleo == 0) return(tree_plot)

  # --- Paleo panels --------------------------------------------------------
  # Only the bottom-most panel receives "Age (Ma)" axis text.
  panels <- list(tree_plot)

  if (has_co2) {
    panels <- c(panels, list(
      .build_co2_panel(
        paleo_data  = paleo_data,
        xlim_left   = xlim_left,
        x_breaks    = x_breaks,
        show_x_axis = !has_temp    # CO2 is bottom only when there is no temp panel
      )
    ))
  }

  if (has_temp) {
    panels <- c(panels, list(
      .build_temp_panel(
        paleo_data  = paleo_data,
        xlim_left   = xlim_left,
        x_breaks    = x_breaks,
        show_x_axis = TRUE         # temp is always the bottom-most panel
      )
    ))
  }

  n_panels <- length(panels)

  # --- Validate / default panel heights ------------------------------------
  if (is.null(panel_heights)) {
    panel_heights <- c(4, rep(1.2, n_panels - 1))
  }
  if (length(panel_heights) != n_panels) {
    warning(sprintf(
      "panel_heights length (%d) does not match the number of panels (%d). ",
      "Using default heights.",
      length(panel_heights), n_panels
    ))
    panel_heights <- c(4, rep(1.2, n_panels - 1))
  }

  # --- Combine panels with patchwork ---------------------------------------
  # wrap_plots() returns a patchwork object: composable, printable, ggsave-able.
  #
  # Alternative with more precise axis alignment for coord_geo() layouts:
  #   deeptime::ggarrange2(
  #     plotlist = panels,
  #     nrow     = n_panels,
  #     heights  = panel_heights,
  #     draw     = FALSE
  #   )
  patchwork::wrap_plots(panels, ncol = 1, heights = panel_heights)
}
