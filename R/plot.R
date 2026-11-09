# =============================================================================
# Calendar visualization
# =============================================================================
# Three layers, mirroring geoscales/R/plot.R:
#
#   calendar_layout(cal)       -> plain data.frame of rectangles (no ggplot2);
#                                 the plotting-system-agnostic foundation
#   gg_calendar(cal, type = )  -> the assembled figures: icicle, stack,
#                                 heatmap (data on a timeframe grid), wall
#   autoplot(cal) / plot(cal)  -> methods over gg_calendar(); autoplot()
#                                 returns the ggplot, plot() draws it
#
# ggplot2 is a Suggests dependency, guarded by .need_ggplot(); custom
# stat_*/geom_* layers are a deliberate later stage built over the same
# layout/heat-data helpers (see dev/review-core.md) — nothing here uses
# ggproto.
# =============================================================================

#' @noRd
.need_ggplot <- function(what) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop(what, " requires the ggplot2 package; install it with ",
         "install.packages(\"ggplot2\")", call. = FALSE)
  }
}

# -----------------------------------------------------------------------------
# calendar_layout()
# -----------------------------------------------------------------------------

#' Icicle layout of a calendar's structure
#'
#' Computes the rectangle geometry of the structure plot as a plain
#' `data.frame` — one band per timeframe (coarsest at the top, plus the
#' implicit `ANNUAL` root), one rectangle per contiguous timeslice segment,
#' x normalized to `[0, 1]` (share of the covered year). Exposed so the
#' layout can be drawn with something other than ggplot2; the same frame
#' backs [`gg_calendar()`].
#'
#' @param x A [`Calendar`].
#' @param annual Include the `ANNUAL` root band on top? Default `TRUE`.
#'
#' @return A `data.frame` with columns `timeframe`, `label` (the member value
#'   of the segment), `timeslice` (the full prefix path id), `rank` (0 for
#'   `ANNUAL`, then 1 = coarsest), `xmin`/`xmax` (in `[0, 1]`),
#'   `ymin`/`ymax` (bands, top row highest), `share` (segment share of the
#'   year), `weight` (segment weight sum), `order` (index of the segment's
#'   first leaf in chronological order), and `within` (1-based position
#'   among its siblings, restarting per parent).
#'
#' @examples
#' head(calendar_layout(calendar("q4_h24")))
#' @export
calendar_layout <- function(x, annual = TRUE) {
  if (!S7::S7_inherits(x, Calendar)) {
    stop("`x` must be a Calendar object", call. = FALSE)
  }
  leaves <- S7::prop(x, "leaftable")
  tfs    <- S7::prop(x, "timeframes")
  levels <- S7::prop(x, "members")
  meta   <- S7::prop(x, "meta")
  yf     <- meta$year_fraction %||% 1

  # Chronological order = vocabulary order of each timeframe, coarsest key
  # first, so segment grouping below reduces to run-length detection
  keys <- lapply(tfs, function(tf) {
    match(as.character(leaves[[tf]]), levels[[tf]])
  })
  leaves <- leaves[do.call(order, keys), , drop = FALSE]

  n_leaf <- nrow(leaves)
  w  <- leaves$share / yf
  x1 <- cumsum(w)
  x0 <- x1 - w

  n_rows <- length(tfs) + as.integer(annual)
  band <- function(b) c(ymin = n_rows - b, ymax = n_rows - b + 0.9)

  rows <- list()
  if (annual) {
    b <- band(1)
    rows[[1]] <- data.frame(
      timeframe = "ANNUAL", label = "ANNUAL", timeslice = "ANNUAL", rank = 0L,
      xmin = 0, xmax = x1[n_leaf], ymin = b[["ymin"]], ymax = b[["ymax"]],
      share = sum(leaves$share), weight = sum(leaves$weight),
      order = 1L, within = 1L, stringsAsFactors = FALSE
    )
  }

  prev_gid <- rep(1L, n_leaf)
  for (i in seq_along(tfs)) {
    gid <- .prefix_group_id(leaves, tfs[seq_len(i)])
    starts <- which(!duplicated(gid))
    ends   <- c(starts[-1] - 1L, n_leaf)

    prefix <- lapply(tfs[seq_len(i)], function(tf) {
      as.character(leaves[[tf]])[starts]
    })
    b <- band(i + as.integer(annual))
    rows[[length(rows) + 1L]] <- data.frame(
      timeframe = tfs[i],
      label     = as.character(leaves[[tfs[i]]])[starts],
      timeslice     = do.call(paste, c(prefix, sep = "_")),
      rank      = i,
      xmin      = x0[starts],
      xmax      = x1[ends],
      ymin      = b[["ymin"]],
      ymax      = b[["ymax"]],
      share     = as.numeric(tapply(leaves$share, gid, sum)),
      weight    = as.numeric(tapply(leaves$weight, gid, sum)),
      order     = starts,
      within    = stats::ave(seq_along(starts), prev_gid[starts],
                             FUN = seq_along),
      stringsAsFactors = FALSE
    )
    prev_gid <- gid
  }

  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

#' Group id from change-points over prefix columns (assumes sorted input)
#' @noRd
.prefix_group_id <- function(df, cols) {
  n <- nrow(df)
  if (n <= 1L) return(rep(1L, n))
  changed <- rep(FALSE, n - 1L)
  for (cl in cols) {
    v <- as.character(df[[cl]])
    ch <- v[-1L] != v[-n]
    ch[is.na(ch)] <- FALSE
    changed <- changed | ch
  }
  cumsum(c(TRUE, changed))
}

# -----------------------------------------------------------------------------
# gg_calendar(): one entry point, `type` selects the figure
# -----------------------------------------------------------------------------

# Arguments each figure type accepts, besides `object`, `type` and `...`.
# Anything listed for another type only is refused, never ignored.
.GG_CALENDAR_ARGS <- list(
  icicle  = c("data", "z", "key", "year", "palette", "labels", "rule", "by",
              "reference", "annual", "fill", "color_pattern", "max_labels",
              "max_segments", "border"),
  stack   = c("data", "z", "key", "year", "palette", "labels", "rule", "by",
              "annual", "view", "angle", "ratio", "shear", "depth", "gap",
              "rotate", "direction", "colour", "linewidth", "frame",
              "frame_fill", "connectors"),
  heatmap = c("data", "z", "key", "palette", "fun", "x_tf", "y_tf",
              "facet_tf"),
  wall    = c("data", "z", "key", "year", "palette", "labels", "fun",
              "arrange", "week_start")
)

#' Refuse arguments that belong to another figure type
#'
#' `call` is the `match.call()` of the entry point: names passed through
#' the methods' `...` are expanded there, so the check sees them too.
#' Names outside the table are the entry point's own `...` (fixed
#' aesthetics for the drawing layer) and pass.
#' @noRd
.gg_check_args <- function(call, type, table, fn) {
  given <- setdiff(names(call)[-1], c("", "object", "type"))
  known <- unique(unlist(table))
  bad <- setdiff(intersect(given, known), table[[type]])
  if (length(bad)) {
    .stop("`%s` does not apply to %s(type = \"%s\")",
          paste(bad, collapse = "`, `"), fn, type)
  }
}

#' The palette sentinels: `NULL` is the type's default scale, `NA` is none
#' @noRd
.gg_palette <- function(palette, type, default) {
  if (!is.null(palette)) return(palette)
  if (type %in% c("icicle", "stack")) default else NULL
}

#' @noRd
.has_palette <- function(palette) {
  !is.null(palette) && !(length(palette) == 1L && is.na(palette))
}

#' Add a layer with fixed aesthetics; the user's `...` override the defaults
#' @noRd
.gg_layer <- function(geom, mapping, defaults, dots, data = NULL) {
  names(dots)[names(dots) == "color"] <- "colour"
  args <- utils::modifyList(defaults, dots)
  if (!is.null(data)) args$data <- data
  do.call(geom, c(list(mapping = mapping), args))
}

#' Plot a calendar
#'
#' One function for every calendar figure, selected by `type`: the structure
#' icicle (default), the axonometric stack, a heatmap of data on a timeframe
#' grid, and a wall calendar. `autoplot()` on a [`Calendar`] returns the same
#' ggplot; `plot()` draws it and returns it invisibly.
#'
#' @param object A [`Calendar`].
#' @param type The figure: `"icicle"` (default), `"stack"`, `"heatmap"` or
#'   `"wall"`; see the sections below. An argument that belongs to another
#'   type is an error, not ignored.
#' @param data,z Colour the figure by a value instead of by structure.
#'   `data` is a data.frame keyed by timeslice (see `key`) with the value
#'   column named by `z`; `z` is required whenever `data` is given. The
#'   icicle and the stack recast the value to every timeframe shown, so the
#'   whole figure shares one continuous fill scale; the heatmap and the wall
#'   collapse the leaves into the cells shown with `fun`. Legend title via
#'   `labs(fill = )`.
#' @param key Key column of `data`. `NULL` (default) uses `timeslice` when
#'   present; the wall also accepts a POSIXct/Date column and detects the
#'   first one.
#' @param year The calendar year the figure is about: the wall arranges its
#'   days by that year's weekdays, the icicle and the stack route their
#'   recasts through it (required with `data`, see [`recast_calendar()`]).
#' @param rule,fun Aggregation. `rule` is the registry rule of the
#'   per-timeframe recasts on the icicle and the stack (`"sum"`, `"mean"`,
#'   `"weighted_mean"`, ... as in [`recast_calendar()`]; explicit or
#'   registered, never guessed). `"share"` colours every row by each
#'   timeslice's share within the row above it on a fixed linear 0..1
#'   scale; `"logshare"` is the same on a fixed log10 percent scale. `fun`
#'   is the function that collapses several observations into one cell on
#'   the heatmap and the wall (default `mean`).
#' @param by With `data` on the icicle or the stack: base-grid granularity
#'   of the recasts. Defaults to `"hour"`, which is always correct (the
#'   automatic choice can pick a daily grid for sub-daily calendars, which
#'   silently collapses hour-type slices).
#' @param palette Fill scale. `NULL` (default) is the type's own: viridis
#'   `"D"` on the icicle and the stack, ggplot2's default gradient on the
#'   heatmap and the wall. A viridis option letter or name (`"C"`,
#'   `"plasma"`, `"turbo"`, ...) opts into that palette on any type. `NA`
#'   adds no fill scale at all, so a custom one can be supplied.
#' @param labels What is labelled. `NULL` (default) is the type's own.
#'   Icicle: `"name"` (the member value, e.g. `h00`; the default),
#'   `"timeslice"` (the full path, e.g. `Q1_h00`) or `"none"`; `TRUE` and
#'   `FALSE` are shorthands. Stack: a character vector of timeframes whose
#'   member names are drawn on their plane (`TRUE` = all; default none).
#'   Wall: `TRUE` (default) draws the day numbers. The heatmap has no labels.
#' @param reference Icicle only: a complete [`Calendar`] to draw a sampled
#'   `object` against. The layout is the reference's; segments without a
#'   timeslice of `object` are left empty (grey). `TRUE` resolves the
#'   reference from `meta$parent_name`, as recorded by
#'   [`filter_calendar()`].
#' @param annual Icicle and stack: include the `ANNUAL` root. Default `TRUE`.
#' @param fill Icicle: what drives the structure fill, `"order"`
#'   (chronological position, default), `"share"` or `"weight"`. `data`
#'   overrides it.
#' @param color_pattern Icicle, for `fill = "order"`: `"within"` (default)
#'   restarts the gradient inside each parent timeslice (hours recycle every
#'   day); `"global"` sweeps once across the whole year.
#' @param max_labels Icicle: rows with more segments than this get no
#'   labels. Default 60.
#' @param max_segments Icicle: rows with more segments than this are binned
#'   by x-midpoint before drawing (fill = width-weighted mean), keeping
#'   hourly calendars fast. Default 2000.
#' @param border Icicle: rectangle border colour. Default `NA` (none), so
#'   dense rows render as smooth gradients.
#' @param view Stack: a predefined point of view -- `"oblique"` (the
#'   shear/depth default), `"top-down"`, `"cavalier"`, `"cabinet"`,
#'   `"military"`, `"isometric"`, `"dimetric"`, `"trimetric"`,
#'   `"perspective"` (receding planes shrink) or `"pyramid"` (receding
#'   planes grow: the coarsest timeframe is the small top, the finest the
#'   wide base).
#' @param angle,ratio Stack: oblique view by angle (degrees of the receding
#'   axis) and foreshortening ratio -- `e2 = ratio * (cos(angle),
#'   sin(angle))`. Overridden by `view`.
#' @param shear,depth,gap Stack: the raw receding-axis components
#'   (`e2 = (shear, depth)`; used when neither `view` nor `angle`/`ratio`
#'   is given) and the vertical spacing between planes: one value for every
#'   pair, or one per pair from the top down. `gap = NULL` (default) spaces
#'   planes almost touching, with a slight overlap (0.85 x the plane's
#'   screen height). Under `"perspective"` and `"pyramid"` each spacing is
#'   scaled with the planes it separates, so it stays uniform relative to
#'   their size.
#' @param rotate Stack: in-plane rotation of each plane (degrees,
#'   counter-clockwise) before projection.
#' @param direction Stack: `"up"` (default) stacks the coarsest timeframe
#'   on top; `"down"` puts it at the bottom.
#' @param colour,linewidth Stack: segment border colour and width, recycled
#'   across the planes (one entry per plane styles them individually).
#'   Defaults `"grey35"` and `0.2`, ggplot2's own sf polygon border. The
#'   icicle's rectangle border is the separate `border` argument.
#' @param frame Stack: draw each plane's outline (the unit box run through
#'   the same projection) as a guide. `TRUE` uses `"grey80"`, a colour
#'   string uses that colour, `NULL` (default) draws no frames.
#' @param frame_fill Stack: fill for the plane sheets; best mostly
#'   transparent, e.g. `frame_fill = ggplot2::alpha("grey60", 0.12)`.
#'   Setting a fill draws the frames even without `frame`; `NA` (default)
#'   = no fill.
#' @param connectors Stack: dashed lines joining the corresponding frame
#'   corners of adjacent planes. `TRUE` uses the frame colour, a colour
#'   string picks its own; default `FALSE`.
#' @param x_tf,y_tf,facet_tf Heatmap: timeframe names overriding the
#'   automatic layout (finest timeframe on y, next-finest on x, anything
#'   coarser as facets).
#' @param arrange Wall: `"weekday"` (default) places each day under its
#'   weekday of `year`; `"sequence"` fills the week grid in order.
#' @param week_start Wall: first day of the week. Default `"MON"`.
#' @param ... Fixed aesthetics for the figure's main layer: the icicle's
#'   `geom_rect()`, the stack's plane polygons, the heatmap's and the wall's
#'   `geom_tile()` (e.g. `alpha = 0.8`).
#' @param x A [`Calendar`] (for `plot()`).
#'
#' @section Icicle (`type = "icicle"`):
#' One horizontal band per timeframe (`ANNUAL` root on top, coarsest
#' first), rectangle widths proportional to timeslice shares, x spanning
#' the covered year on `[0, 1]`. With `data`, each band's rectangles carry
#' the value recast to that band's timeframe; dense bands are binned with
#' width-weighted means.
#'
#' @section Stack (`type = "stack"`):
#' The same structure drawn axonometrically: one sheared plane per
#' timeframe, `ANNUAL` on top, each plane segmented by the true duration
#' shares, with segments visibly nesting into the plane above. Without
#' `data`, each plane is coloured by its own segment order.
#'
#' @section Heatmap (`type = "heatmap"`):
#' Data on a timeframe grid: finest timeframe on y, next-finest on x,
#' anything coarser as facets (overridable via `x_tf`/`y_tf`/`facet_tf`).
#' Without `data`, the calendar's own `share` is drawn.
#'
#' @section Wall (`type = "wall"`):
#' A wall calendar: one facet per month (in member order, so April first
#' for the `fy04_*` fiscal calendars), day cells in a week grid, weeks
#' top-down. `data` may be keyed by timeslice (day-level ids directly;
#' finer ids, e.g. hours of `d365_h24`, roll up into their day cell) or by
#' datetime (mapped through [`datetime_to_timeslice()`] on the day layer).
#' Needs a day-resolution timeframe (`YDAY` or `MDAY`).
#'
#' @section Methods:
#' `autoplot(object, ...)` is `gg_calendar(object, ...)`. `plot(x, ...)`
#' prints that figure and returns it invisibly, like base `plot()`.
#'
#' @return A ggplot object.
#'
#' @examples
#' if (requireNamespace("ggplot2", quietly = TRUE)) {
#'   cal <- calendar("q4_h24")
#'   gg_calendar(cal)
#'   ggplot2::autoplot(cal)                            # the same figure
#'   gg_calendar(calendar("s4_hp3"), type = "stack")
#'
#'   x <- data.frame(timeslice = sprintf("m%02d", 1:12), load = 1:12)
#'   gg_calendar(calendar("m12"), data = x, z = "load", type = "heatmap")
#'
#'   gg_calendar(calendar("m12_md365"), type = "wall", year = 2021)
#' }
#' @export
gg_calendar <- function(object,
                        type = c("icicle", "stack", "heatmap", "wall"),
                        data = NULL, z = NULL, key = NULL, year = NULL,
                        rule = "weighted_mean", by = "hour",
                        fun = mean,
                        palette = NULL, labels = NULL,
                        reference = NULL,
                        annual = TRUE,
                        fill = c("order", "share", "weight"),
                        color_pattern = c("within", "global"),
                        max_labels = 60L, max_segments = 2000L, border = NA,
                        view = NULL, angle = NULL, ratio = NULL,
                        shear = 0.5, depth = 0.3, gap = NULL,
                        rotate = 0, direction = c("up", "down"),
                        colour = "grey35", linewidth = 0.2,
                        frame = NULL, frame_fill = NA, connectors = FALSE,
                        x_tf = NULL, y_tf = NULL, facet_tf = NULL,
                        arrange = c("weekday", "sequence"), week_start = "MON",
                        ...) {
  .need_ggplot("gg_calendar()")
  if (!S7::S7_inherits(object, Calendar)) {
    stop("`object` must be a Calendar object", call. = FALSE)
  }
  type <- match.arg(type)
  .gg_check_args(match.call(), type, .GG_CALENDAR_ARGS, "gg_calendar")
  if (!is.null(data) && is.null(z)) {
    stop("`z` must name the value column of `data`", call. = FALSE)
  }
  palette <- .gg_palette(palette, type, default = "D")
  switch(type,
    icicle = .gg_calendar_icicle(
      object, data = data, z = z, key = key, year = year, rule = rule,
      by = by, palette = palette, labels = labels, reference = reference,
      annual = annual, fill = fill, color_pattern = color_pattern,
      max_labels = max_labels, max_segments = max_segments,
      border = border, ...),
    stack = .gg_calendar_stack(
      object, annual = annual, palette = palette, view = view,
      angle = angle, ratio = ratio, shear = shear, depth = depth, gap = gap,
      rotate = rotate, direction = direction, colour = colour,
      linewidth = linewidth, frame = frame, frame_fill = frame_fill,
      connectors = connectors, data = data, z = z, key = key, rule = rule,
      year = year, by = by, labels = labels, ...),
    heatmap = .gg_calendar_heatmap(
      object, data = data, z = z, key = key, x_tf = x_tf, y_tf = y_tf,
      facet_tf = facet_tf, fun = fun, palette = palette, ...),
    wall = .gg_calendar_wall(
      object, data = data, z = z, year = year, arrange = arrange,
      week_start = week_start, fun = fun, labels = labels, key = key, ...)
  )
}

#' Icicle label mode from the `labels` sentinel
#' @noRd
.gg_icicle_labels <- function(labels) {
  if (is.null(labels) || isTRUE(labels)) return("name")
  if (isFALSE(labels)) return("none")
  match.arg(labels, c("name", "timeslice", "none"))
}

#' Resolve `reference` to a Calendar with the same timeframes, or NULL
#' @noRd
.gg_reference <- function(object, reference) {
  if (is.null(reference) || isFALSE(reference)) return(NULL)
  if (isTRUE(reference)) {
    reference <- .reference_calendar(object)
    if (is.null(reference)) {
      .stop(paste0("`reference = TRUE` needs a calendar whose complete form ",
                   "is known: a `meta$parent_name` or inferable tokens"))
    }
  }
  if (!S7::S7_inherits(reference, Calendar)) {
    .stop("`reference` must be a Calendar, TRUE or NULL")
  }
  if (!identical(S7::prop(reference, "timeframes"),
                 S7::prop(object, "timeframes"))) {
    .stop("`reference` must have the same timeframes as `object`")
  }
  reference
}

#' Which layout segments contain at least one timeslice of `object`
#'
#' A segment's `timeslice` is its prefix path; it is selected when some
#' leaf of `object` has that path as a prefix. `ANNUAL` is selected
#' whenever the calendar is non-empty, a day only if the whole day is in.
#' @noRd
.gg_selected <- function(object, d) {
  leaves <- S7::prop(object, "leaftable")
  tfs    <- S7::prop(object, "timeframes")
  paths <- unlist(lapply(seq_along(tfs), function(i) {
    cols <- lapply(tfs[seq_len(i)], function(tf) as.character(leaves[[tf]]))
    unique(do.call(paste, c(cols, sep = "_")))
  }))
  d$timeframe == "ANNUAL" | d$timeslice %in% paths
}

#' The structure icicle (type = "icicle")
#' @noRd
.gg_calendar_icicle <- function(object, data = NULL, z = NULL, key = NULL,
                                year = NULL, rule = "weighted_mean",
                                by = "hour", palette = "D", labels = NULL,
                                reference = NULL, annual = TRUE,
                                fill = c("order", "share", "weight"),
                                color_pattern = c("within", "global"),
                                max_labels = 60L, max_segments = 2000L,
                                border = NA, ...) {
  fill <- match.arg(fill)
  color_pattern <- match.arg(color_pattern)
  labels <- .gg_icicle_labels(labels)
  dots <- list(...)
  empty_col <- "grey90"

  # With a reference, the layout is the complete calendar's; the segments
  # that hold no timeslice of `object` are emptied below
  ref  <- .gg_reference(object, reference)
  grid <- ref %||% object
  tfs    <- S7::prop(grid, "timeframes")
  levels <- S7::prop(grid, "members")
  meta   <- S7::prop(object, "meta")

  d <- calendar_layout(grid, annual = annual)
  n_leaf <- nrow(S7::prop(grid, "leaftable"))

  # Fill values ---------------------------------------------------------------
  is_share <- any(rule %in% c("share", "logshare"))
  if (!is.null(data)) {
    # data fill: each band's rectangles carry the value recast to that
    # band's timeframe (widths still encode duration shares). Overrides
    # `fill`/`color_pattern`. Dense bands are binned below with
    # width-weighted means, which is the right downsample for a value.
    row_tfs <- unique(d$timeframe)
    vals <- if (is_share) {
      .calendar_frame_shares(object, row_tfs, data, z, year, by, key)
    } else {
      .calendar_frame_values(object, row_tfs, data, z, rule, year, by, key)
    }
    d$.fill <- NA_real_
    for (tf in row_tfs) {
      i <- d$timeframe == tf
      d$.fill[i] <- vals[[tf]][[z]][match(d$timeslice[i],
                                          vals[[tf]]$timeslice)]
    }
    mode <- if (is_share) "share" else "data"
  } else if (fill == "order" && color_pattern == "within") {
    # 0-1 gradient recycling inside each parent; scaled by the timeframe's
    # vocabulary size so h00..h23 always spans the full palette
    klev <- c(ANNUAL = 1L,
              vapply(tfs, function(tf) length(levels[[tf]]), integer(1)))
    d$.fill <- (d$within - 1) / pmax(1, klev[d$timeframe] - 1)
    mode <- "within"
  } else if (fill == "order") {
    d$.fill <- d$order
    mode <- "global"
  } else {
    d$.fill <- d[[fill]]
    mode <- "column"
  }
  if (!is.null(ref)) {
    d$.fill[!.gg_selected(object, d)] <- NA_real_
  }

  # Bin overly dense rows by x-midpoint ---------------------------------------
  seg_n <- table(d$timeframe)
  dense <- names(seg_n)[seg_n > max_segments]
  if (length(dense) > 0L) {
    keep <- d[!d$timeframe %in% dense, , drop = FALSE]
    binned <- lapply(dense, function(tf) {
      .bin_layout_row(d[d$timeframe == tf, , drop = FALSE], max_segments)
    })
    d <- rbind(keep, do.call(rbind, binned))
  }

  # Base plot ------------------------------------------------------------------
  row_order <- unique(calendar_layout(grid, annual = annual)$timeframe)
  n_rows <- length(row_order)
  p <- ggplot2::ggplot(d) +
    .gg_layer(ggplot2::geom_rect,
              ggplot2::aes(xmin = xmin, xmax = xmax, ymin = ymin,
                           ymax = ymax, fill = .fill),
              list(colour = border, linewidth = 0.15), dots) +
    ggplot2::scale_x_continuous("share of the year",
                                limits = c(0, 1),
                                expand = ggplot2::expansion(mult = 0.005)) +
    ggplot2::scale_y_continuous(NULL,
                                breaks = rev(seq_len(n_rows)) - 0.55,
                                labels = row_order) +
    ggplot2::theme_minimal() +
    ggplot2::theme(panel.grid = ggplot2::element_blank())

  if (.has_palette(palette)) {
    p <- p + switch(mode,
      share  = .calendar_share_scale(palette,
                                     log = any(rule %in% "logshare")),
      data   = ggplot2::scale_fill_viridis_c(option = palette,
                                             na.value = empty_col),
      within = ggplot2::scale_fill_viridis_c(
        option = palette, limits = c(0, 1), breaks = c(0, 1),
        labels = c("first", "last"), name = "timeslice",
        na.value = empty_col),
      global = ggplot2::scale_fill_viridis_c(
        option = palette, limits = c(1, n_leaf), breaks = c(1, n_leaf),
        labels = c("1", format(n_leaf)), name = "timeslice",
        na.value = empty_col),
      column = ggplot2::scale_fill_viridis_c(option = palette, name = fill,
                                             na.value = empty_col))
  }

  if (!is.null(meta$name) && nzchar(meta$name)) {
    p <- p + ggplot2::labs(
      title = meta$name,
      subtitle = if (!is.null(meta$desc) && nzchar(meta$desc)) meta$desc)
  }
  if (!is.null(data)) {
    p <- p + ggplot2::labs(fill = if (is_share) "Share" else z)
  }

  # Labels ---------------------------------------------------------------------
  if (labels != "none") {
    lab_rows <- names(seg_n)[seg_n <= max_labels]
    ld <- d[d$timeframe %in% lab_rows & !is.na(d$timeslice), , drop = FALSE]
    if (nrow(ld) > 0L) {
      ld$.label <- if (labels == "timeslice") ld$timeslice else ld$label
      # white on dark cells, dark on light ones (normalize fill to [0,1]);
      # empty cells are light, so their text is dark
      rng <- range(d$.fill, finite = TRUE)
      f01 <- if (diff(rng) > 0) (ld$.fill - rng[1]) / diff(rng) else 0.5
      f01[!is.finite(f01)] <- 1
      ld$.label_col <- ifelse(f01 < 0.5, "white", "grey15")
      p <- p + ggplot2::geom_text(
        data = ld,
        ggplot2::aes(x = (xmin + xmax) / 2, y = (ymin + ymax) / 2,
                     label = .label),
        color = ld$.label_col, size = 2.6, check_overlap = TRUE)
    }
  }
  p
}

#' Per-timeframe recast of a timeslice-keyed value table
#'
#' The shared engine behind the data fills of both calendar figures
#' (icicle bands and stack planes): recast `data[[z]]` to every
#' timeframe in `tfs` with [`recast_calendar()`]. `data` is keyed the
#' way recast_calendar() accepts (a `timeslice` column at the
#' calendar's resolution, or a calendar-named label column). Returns
#' NULL when `data` is NULL; a named list of data.frames (one per
#' timeframe, keyed by `timeslice`) otherwise.
#' @noRd
.calendar_frame_values <- function(calendar, tfs, data, z, rule, year, by,
                                   key = NULL) {
  if (is.null(data)) return(NULL)
  if (is.null(z) || !z %in% names(data)) {
    stop("`z` must name a value column of `data`", call. = FALSE)
  }
  if (is.null(year)) {
    stop("`data` needs `year =`: the per-timeframe recasts route ",
         "through recast_calendar(), which requires it", call. = FALSE)
  }
  vals <- lapply(tfs, function(tf) {
    as.data.frame(recast_calendar(data, source = calendar, target = tf,
                                  year = year, key = key, values = z,
                                  rule = rule, by = by))
  })
  stats::setNames(vals, tfs)
}


#' Fill scale for a share fill, mirroring geoscales' .share_fill_scale():
#' FIXED limits either way, so any two share figures map colour
#' identically. "share" is the plain 0..1 scale; "logshare" spreads the
#' decades (below-limit values squish to the darkest colour; only true
#' zeros take the na colour).
#' @noRd
.calendar_share_scale <- function(palette, log = FALSE) {
  if (!log) {
    return(ggplot2::scale_fill_viridis_c(
      option = palette, limits = c(0, 1),
      breaks = c(0, 0.25, 0.5, 0.75, 1),
      na.value = "grey85"))
  }
  ggplot2::scale_fill_viridis_c(
    option = palette, transform = "log10",
    limits = c(1e-4, 1),
    oob = scales::oob_squish,
    breaks = c(1e-4, 1e-3, 1e-2, 1e-1, 1),
    labels = c("0.01%", "0.1%", "1%", "10%", "100%"),
    na.value = "grey85")
}

#' The share fill, mirroring geoscales' .geoscale_frame_shares(): every
#' row shows each timeslice's share within the row ABOVE it, and the top
#' row (or ANNUAL) its share of the year. Timeframes of one calendar
#' always nest, so no cross-cut fallback is needed.
#' @noRd
.calendar_frame_shares <- function(calendar, tfs, data, z, year, by,
                                   key = NULL) {
  if (is.null(z) || !z %in% names(data)) {
    stop("`z` must name a value column of `data`", call. = FALSE)
  }
  if (is.null(year)) {
    stop("`data` needs `year =`: the per-timeframe recasts route ",
         "through recast_calendar(), which requires it", call. = FALSE)
  }
  vals <- lapply(seq_along(tfs), function(i) {
    tf <- tfs[[i]]
    if (tf == "ANNUAL") {
      return(data.frame(timeslice = "ANNUAL", v = 1))
    }
    s <- as.data.frame(recast_calendar(data, source = calendar, target = tf,
                                       year = year, key = key, values = z,
                                       rule = "sum", by = by))
    parent <- if (i > 1L && tfs[[i - 1L]] != "ANNUAL") tfs[[i - 1L]]
              else "ANNUAL"
    as.data.frame(recast_calendar(s, source = prune_calendar(calendar, tf),
                                  target = parent, year = year, values = z,
                                  rule = "share", by = by))
  })
  vals <- lapply(vals, function(v) {
    names(v)[names(v) == "v"] <- z
    v
  })
  stats::setNames(vals, tfs)
}

#' Bin one layout row to at most `k` segments by x-midpoint
#' @noRd
.bin_layout_row <- function(row_df, k) {
  mid <- (row_df$xmin + row_df$xmax) / 2
  brk <- seq(min(row_df$xmin), max(row_df$xmax), length.out = k + 1L)
  bin <- cut(mid, breaks = brk, labels = FALSE, include.lowest = TRUE)
  width <- row_df$xmax - row_df$xmin
  idx <- split(seq_len(nrow(row_df)), bin)
  out <- lapply(idx, function(i) {
    r <- row_df[i[1L], , drop = FALSE]
    r$xmin   <- min(row_df$xmin[i])
    r$xmax   <- max(row_df$xmax[i])
    r$share  <- sum(row_df$share[i])
    r$weight <- sum(row_df$weight[i])
    r$.fill  <- stats::weighted.mean(row_df$.fill[i], width[i], na.rm = TRUE)
    # a bin is not a real timeslice; this also mutes labels
    r$timeslice  <- NA_character_
    r
  })
  do.call(rbind, out)
}

# -----------------------------------------------------------------------------
# The heatmap (type = "heatmap"): data on a timeframe grid
# -----------------------------------------------------------------------------

#' @noRd
.gg_calendar_heatmap <- function(object, data = NULL, z = NULL, key = NULL,
                                 x_tf = NULL, y_tf = NULL, facet_tf = NULL,
                                 fun = mean, palette = NULL, ...) {
  dots <- list(...)
  hd <- .calendar_heat_data(object, data, z, key, x_tf, y_tf, facet_tf, fun)
  meta <- S7::prop(object, "meta")

  p <- ggplot2::ggplot(hd$df, ggplot2::aes(x = .x, y = .y, fill = .fill)) +
    .gg_layer(ggplot2::geom_tile, NULL, list(), dots) +
    ggplot2::scale_x_discrete(hd$x_tf, breaks = hd$x_breaks) +
    ggplot2::scale_y_discrete(hd$y_tf, breaks = hd$y_breaks) +
    ggplot2::labs(fill = hd$fill_label) +
    theme_calendar()

  if (.has_palette(palette)) {
    p <- p + ggplot2::scale_fill_viridis_c(option = palette)
  }
  if (!is.null(hd$facet_tf)) {
    p <- p + ggplot2::facet_wrap(ggplot2::vars(.facet))
  }
  if (isTRUE(hd$rotate_x)) {
    p <- p + ggplot2::theme(
      axis.text.x = ggplot2::element_text(angle = 90, vjust = 0.5,
                                          hjust = 1))
  }
  if (!is.null(meta$name) && nzchar(meta$name)) {
    p <- p + ggplot2::ggtitle(meta$name)
  }
  p
}

#' Join, lay out, and aggregate data onto a calendar for the heatmap.
#' Kept separate so a future stat_calendar() can wrap it directly.
#' @noRd
.calendar_heat_data <- function(cal, data, z, key,
                                x_tf, y_tf, facet_tf, fun) {
  leaves <- S7::prop(cal, "leaftable")
  tfs    <- S7::prop(cal, "timeframes")
  levels <- S7::prop(cal, "members")
  key <- key %||% "timeslice"

  # Value vector on leaves ----------------------------------------------------
  if (is.null(data)) {
    val <- leaves$share
    fill_label <- "share"
  } else {
    if (!is.data.frame(data)) {
      stop("`data` must be a data.frame", call. = FALSE)
    }
    if (!key %in% names(data)) {
      stop(sprintf("`data` has no column named `%s`", key), call. = FALSE)
    }
    if (is.null(z) || length(z) != 1L || !z %in% names(data)) {
      stop("`z` must name exactly one column of `data`", call. = FALSE)
    }
    mi <- match(leaves$timeslice, data[[key]])
    if (all(is.na(mi))) {
      stop("no rows of `data` matched the calendar's timeslices; check `key=`",
           call. = FALSE)
    }
    val <- data[[z]][mi]
    fill_label <- z
  }

  # Layout: finest -> y, next-finest -> x, coarser -> facets -------------------
  if (is.null(y_tf) && is.null(x_tf)) {
    if (length(tfs) == 1L) {
      x_tf <- tfs
      y_tf <- NULL
    } else {
      y_tf <- tfs[length(tfs)]
      x_tf <- tfs[length(tfs) - 1L]
    }
  } else if (is.null(x_tf)) {
    x_tf <- setdiff(rev(tfs), c(y_tf, facet_tf))[1]
  } else if (is.null(y_tf) && length(setdiff(tfs, c(x_tf, facet_tf))) > 0L) {
    y_tf <- setdiff(rev(tfs), c(x_tf, facet_tf))[1]
  }
  used <- c(x_tf, y_tf, facet_tf)
  if (is.null(facet_tf)) {
    rest <- setdiff(tfs, used)
    if (length(rest) > 0L) {
      facet_tf <- rest[1]
      used <- c(used, facet_tf)
    }
  }
  bad <- setdiff(used, tfs)
  if (length(bad) > 0L) {
    stop("not timeframes of this calendar: ", paste(bad, collapse = ", "),
         call. = FALSE)
  }

  # Aggregate the value over dropped timeframes --------------------------------
  grp_cols <- lapply(used, function(tf) as.character(leaves[[tf]]))
  gkey <- do.call(paste, c(grp_cols, sep = "\r"))
  first_i <- !duplicated(gkey)
  agg <- as.numeric(tapply(val, gkey, function(v) fun(v))[gkey[first_i]])

  df <- data.frame(.fill = agg, stringsAsFactors = FALSE)
  df$.x <- factor(grp_cols[[1L]][first_i], levels = levels[[x_tf]])
  if (!is.null(y_tf)) {
    df$.y <- factor(grp_cols[[2L]][first_i], levels = levels[[y_tf]])
  } else {
    df$.y <- factor(rep("", nrow(df)))
  }
  if (!is.null(facet_tf)) {
    fi <- match(facet_tf, used)
    df$.facet <- factor(grp_cols[[fi]][first_i], levels = levels[[facet_tf]])
  }

  thin <- function(vocab, k = 8L) {
    if (length(vocab) <= 12L) return(vocab)
    vocab[unique(round(seq(1, length(vocab), length.out = k)))]
  }
  list(df = df,
       x_tf = x_tf,
       y_tf = y_tf %||% NULL,
       facet_tf = facet_tf,
       fill_label = fill_label,
       x_breaks = thin(levels[[x_tf]]),
       y_breaks = if (!is.null(y_tf)) thin(levels[[y_tf]]) else "",
       rotate_x = length(levels[[x_tf]]) > 12L || !is.null(facet_tf))
}

# -----------------------------------------------------------------------------
# Methods: autoplot() returns the figure, plot() draws it
# -----------------------------------------------------------------------------

#' @rdname gg_calendar
#' @exportS3Method ggplot2::autoplot
autoplot.Calendar <- function(object, ...) {
  gg_calendar(object, ...)
}

#' @rdname calendar_leaftable
#' @exportS3Method ggplot2::fortify
fortify.Calendar <- function(model, data, ...) {
  calendar_leaftable(model)
}

# Registered on ggplot2::autoplot in .onLoad (R/zzz.R) under both class
# strings, the geoscales pattern.

#' @rdname gg_calendar
#' @export
#' @method plot Calendar
plot.Calendar <- function(x, ...) {
  print(gg_calendar(x, ...))
}

# Base-R S3 dispatch sees the qualified S7 class string first.
#' @export
`plot.timescales::Calendar` <- plot.Calendar

utils::globalVariables(c("xmin", "xmax", "ymin", "ymax",
                         ".fill", ".label", ".x", ".y", ".facet",
                         "id", "ord", "tf", "x", "y", "xend", "yend",
                         ".z"))

# -----------------------------------------------------------------------------
# The axonometric stack view (type = "stack")
# -----------------------------------------------------------------------------

#' Resolve a stack point of view to screen axes
#'
#' A view places the two in-plane unit axes on screen: `e1` (the layer's
#' x axis) and `e2` (its depth axis), plus a per-layer `scale` (< 1 =
#' receding planes shrink -- the perspective approximation). Precedence:
#' the `view` preset wins, then `angle`/`ratio` (oblique:
#' `e2 = ratio * (cos, sin)`), then raw `shear`/`depth`
#' (`e2 = (shear, depth)`). (Worded without ">" chains: a wrapped line
#' starting with ">" is a markdown blockquote, which roxygen rejects.)
#' Duplicated verbatim in geoscales/R/plot.R -- keep in sync.
#' @noRd
.stack_view <- function(view = NULL, angle = NULL, ratio = NULL,
                        shear = 0.5, depth = 0.3) {
  deg <- pi / 180
  if (!is.null(view)) {
    view <- match.arg(view, c("oblique", "top-down", "cavalier",
                              "cabinet", "military", "isometric",
                              "dimetric", "trimetric", "perspective",
                              "pyramid"))
    return(switch(view,
      "oblique"     = list(e1 = c(1, 0), e2 = c(shear, depth), scale = 1),
      "top-down"    = list(e1 = c(1, 0), e2 = c(0, 1), scale = 1),
      "cavalier"    = list(e1 = c(1, 0),
                           e2 = c(cos(45 * deg), sin(45 * deg)),
                           scale = 1),
      "cabinet"     = list(e1 = c(1, 0),
                           e2 = 0.5 * c(cos(45 * deg), sin(45 * deg)),
                           scale = 1),
      "military"    = list(e1 = c(cos(45 * deg), sin(45 * deg)),
                           e2 = c(-sin(45 * deg), cos(45 * deg)),
                           scale = 1),
      "isometric"   = list(e1 = c(cos(30 * deg), sin(30 * deg)),
                           e2 = c(-cos(30 * deg), sin(30 * deg)),
                           scale = 1),
      "dimetric"    = list(e1 = c(cos(26.565 * deg), sin(26.565 * deg)),
                           e2 = c(-cos(26.565 * deg), sin(26.565 * deg)),
                           scale = 1),
      "trimetric"   = list(e1 = c(cos(10 * deg), sin(10 * deg)),
                           e2 = 0.9 * c(-cos(40 * deg), sin(40 * deg)),
                           scale = 1),
      "perspective" = list(e1 = c(1, 0),
                           e2 = 0.5 * c(cos(45 * deg), sin(45 * deg)),
                           scale = 0.82),
      # the inverse of perspective: each plane below the top is larger
      "pyramid"     = list(e1 = c(1, 0),
                           e2 = 0.5 * c(cos(45 * deg), sin(45 * deg)),
                           scale = 1 / 0.82)
    ))
  }
  if (!is.null(angle) || !is.null(ratio)) {
    a <- (angle %||% 45) * deg
    return(list(e1 = c(1, 0), e2 = (ratio %||% 0.5) * c(cos(a), sin(a)),
                scale = 1))
  }
  list(e1 = c(1, 0), e2 = c(shear, depth), scale = 1)
}

#' The axonometric stack (type = "stack" of gg_calendar())
#'
#' One plane per timeframe, coarsest on top; each plane's segments are
#' the timeframe's members at their true duration shares. Colours cycle
#' per plane (normalized segment order). Planes may overlap when `gap`
#' is smaller than a plane's screen height -- painter order (bottom
#' first) keeps the stack readable.
#' @noRd
.gg_calendar_stack <- function(calendar, annual = TRUE, palette = "D",
                               view = NULL, angle = NULL, ratio = NULL,
                               shear = 0.5, depth = 0.3, gap = NULL,
                               rotate = 0,
                               direction = c("up", "down"),
                               colour = "grey35", linewidth = 0.2,
                               frame = NULL, frame_fill = NA,
                               connectors = FALSE,
                               data = NULL, z = NULL, key = NULL,
                               rule = "weighted_mean",
                               year = NULL, by = "hour",
                               labels = NULL, ...) {
  dots <- list(...)
  v <- .stack_view(view, angle, ratio, shear, depth)
  direction <- match.arg(direction)
  # default spacing: planes almost touching, slight overlap (the plane's
  # screen height is |e1_y| + |e2_y| for a unit footprint)
  gap <- gap %||% (0.85 * (abs(v$e1[2]) + abs(v$e2[2])))
  lay <- calendar_layout(calendar, annual = annual)
  tfs <- unique(lay$timeframe)
  nk <- length(tfs)

  # value fill: every plane gets the value recast to its timeframe so
  # one continuous scale spans the stack
  is_share <- any(rule %in% c("share", "logshare"))
  vals <- if (is_share) {
    .calendar_frame_shares(calendar, tfs, data, z, year, by, key)
  } else {
    .calendar_frame_values(calendar, tfs, data, z, rule, year, by, key)
  }
  # `labels`: TRUE = every plane, FALSE/NULL = none, else timeframes
  if (isTRUE(labels)) labels <- tfs
  if (isFALSE(labels)) labels <- NULL
  if (!is.null(labels)) {
    bad <- setdiff(labels, tfs)
    if (length(bad)) {
      stop("`labels` must name timeframes of the calendar (unknown: ",
           paste(bad, collapse = ", "), ")", call. = FALSE)
    }
  }

  rad <- rotate * pi / 180
  corner <- function(u, w) {
    du <- u - 0.5                                # in-plane rotation first
    dw <- w - 0.5
    ur <- 0.5 + du * cos(rad) - dw * sin(rad)
    wr <- 0.5 + du * sin(rad) + dw * cos(rad)
    cbind(ur * v$e1[1] + wr * v$e2[1],
          ur * v$e1[2] + wr * v$e2[2])
  }
  ctr <- corner(0.5, 0.5)                        # plane center, pre-lift

  top_rank <- if (direction == "up") seq_len(nk) - 1 else nk - seq_len(nk)
  # per-plane size factor. A factor below 1 shrinks the planes below the
  # top (perspective); a factor above 1 is applied from the bottom up, so
  # the largest plane is always full size and pyramid mirrors perspective.
  fac <- if (v$scale < 1) v$scale^top_rank
         else (1 / v$scale)^(nk - 1 - top_rank)
  # vertical placement: coarsest on top ("up", default) or bottom. `gap` is
  # the spacing between consecutive planes, top to bottom, one value for all
  # or one per pair. Each step scales with the larger of the two planes it
  # separates, so spacing stays uniform relative to plane size and pyramid
  # mirrors perspective exactly.
  if (!length(gap) %in% c(1L, nk - 1L)) {
    .stop("`gap` must be a single value or one per pair of planes (%d)",
          nk - 1L)
  }
  pos <- if (direction == "up") seq_len(nk) else rev(seq_len(nk))  # 1 = top
  fac_tb <- fac[order(pos)]  # top to bottom
  steps <- rep_len(gap, nk - 1L) * pmax(fac_tb[-nk], fac_tb[-1L])
  zlev <- vapply(pos, function(p) sum(steps[seq_len(nk - 1L) >= p]),
                 numeric(1))

  quads <- do.call(rbind, lapply(seq_along(tfs), function(k) {
    d <- lay[lay$timeframe == tfs[k], , drop = FALSE]
    sk <- fac[k]
    n <- nrow(d)
    do.call(rbind, lapply(seq_len(n), function(i) {
      p <- corner(c(d$xmin[i], d$xmax[i], d$xmax[i], d$xmin[i]),
                  c(0, 0, 1, 1))
      p <- sweep(sweep(p, 2, ctr) * sk, 2, ctr, `+`)
      data.frame(
        id  = paste(tfs[k], i),
        tf  = tfs[k],
        timeslice = d$timeslice[i],
        z   = zlev[k],
        ord = if (n > 1) (i - 1) / (n - 1) else 0.5,
        x   = p[, 1],
        y   = p[, 2] + zlev[k],
        stringsAsFactors = FALSE
      )
    }))
  }))
  if (!is.null(vals)) {                  # recast output ids == layout ids
    quads$.z <- NA_real_
    for (tf in tfs) {
      i <- quads$tf == tf
      quads$.z[i] <- vals[[tf]][[z]][
        match(quads$timeslice[i], vals[[tf]]$timeslice)]
    }
  }
  # painter order: lower planes first, so upper planes overpaint at
  # overlaps (matters now that the default gap lets planes touch)
  quads <- quads[order(quads$z), , drop = FALSE]
  quads$id <- factor(quads$id, levels = unique(quads$id))
  quads$tf <- factor(quads$tf, levels = rev(tfs))

  # plane frames ("sheets"): the padded unit box through the same
  # projection -- guide lines for the stack; connectors join the
  # corresponding corners of adjacent planes
  frame_col <- if (isTRUE(frame)) "grey80"
               else if (is.character(frame)) frame else NULL
  conn_col  <- if (isTRUE(connectors)) frame_col %||% "grey80"
               else if (is.character(connectors)) connectors else NULL
  draw_frame <- !is.null(frame_col) || !is.na(frame_fill)
  frames <- NULL
  if (draw_frame || !is.null(conn_col)) {
    fp <- 0.03
    cn <- corner(c(-fp, 1 + fp, 1 + fp, -fp),
                 c(-fp, -fp, 1 + fp, 1 + fp))
    frames <- lapply(seq_len(nk), function(k) {
      q <- sweep(sweep(cn, 2, ctr) * fac[k], 2, ctr, `+`)
      data.frame(x = q[, 1], y = q[, 2] + zlev[k])
    })
  }

  xr <- range(quads$x, unlist(lapply(frames, `[[`, "x")))
  yr <- range(quads$y, unlist(lapply(frames, `[[`, "y")))
  span <- xr[2] - xr[1]

  lab <- do.call(rbind, lapply(seq_along(tfs), function(k) {
    if (draw_frame) {                    # anchor to the plane's frame
      data.frame(tf = tfs[k], x = min(frames[[k]]$x) - 0.02 * span,
                 y = mean(range(frames[[k]]$y)), stringsAsFactors = FALSE)
    } else {
      q <- quads[quads$tf == tfs[k], ]
      data.frame(tf = tfs[k], x = min(q$x) - 0.02 * span,
                 y = mean(range(q$y)), stringsAsFactors = FALSE)
    }
  }))

  col_k <- rep_len(colour, nk)
  lwd_k <- rep_len(linewidth, nk)
  p <- ggplot2::ggplot(quads, ggplot2::aes(x = x, y = y, group = id))
  if (!is.null(conn_col)) {              # under everything
    ord <- order(zlev)
    seg <- do.call(rbind, lapply(seq_len(nk - 1), function(i) {
      data.frame(x = frames[[ord[i]]]$x, y = frames[[ord[i]]]$y,
                 xend = frames[[ord[i + 1]]]$x,
                 yend = frames[[ord[i + 1]]]$y)
    }))
    p <- p + ggplot2::geom_segment(
      data = seg,
      ggplot2::aes(x = x, y = y, xend = xend, yend = yend),
      inherit.aes = FALSE,
      colour = conn_col, linewidth = 0.25, linetype = "22"
    )
  }
  for (k in order(zlev)) {               # lower planes first
    if (draw_frame) {                    # the plane's sheet
      p <- p + ggplot2::geom_polygon(data = frames[[k]],
                                     ggplot2::aes(x = x, y = y),
                                     inherit.aes = FALSE,
                                     fill = frame_fill,
                                     colour = frame_col %||% NA,
                                     linewidth = 0.3)
    }
    p <- p + if (is.null(vals)) {
      .gg_layer(ggplot2::geom_polygon, ggplot2::aes(fill = ord),
                list(colour = col_k[k], linewidth = lwd_k[k],
                     show.legend = FALSE),
                dots, data = quads[quads$tf == tfs[k], ])
    } else {
      .gg_layer(ggplot2::geom_polygon, ggplot2::aes(fill = .z),
                list(colour = col_k[k], linewidth = lwd_k[k]),
                dots, data = quads[quads$tf == tfs[k], ])
    }
  }
  if (!is.null(labels)) {                # member names, over all planes
    labdf <- do.call(rbind, lapply(match(labels, tfs), function(k) {
      d <- lay[lay$timeframe == tfs[k], , drop = FALSE]
      pc <- corner((d$xmin + d$xmax) / 2, rep(0.5, nrow(d)))
      pc <- sweep(sweep(pc, 2, ctr) * fac[k], 2, ctr, `+`)
      data.frame(x = pc[, 1], y = pc[, 2] + zlev[k], .label = d$label,
                 stringsAsFactors = FALSE)
    }))
    p <- p + ggplot2::geom_text(data = labdf,
                                ggplot2::aes(x = x, y = y, label = .label),
                                inherit.aes = FALSE,
                                size = 2.4, colour = "grey10")
  }

  # legend title via labs() so callers can retitle with `+ labs(fill = )`
  if (!is.null(vals)) {
    p <- p + ggplot2::labs(fill = if (is_share) "Share" else z)
  }
  if (.has_palette(palette)) {           # NA = caller adds a scale
    p <- p + if (is.null(vals)) {
      ggplot2::scale_fill_viridis_c(option = palette, guide = "none")
    } else if (is_share) {
      .calendar_share_scale(palette, log = any(rule %in% "logshare"))
    } else {
      ggplot2::scale_fill_viridis_c(option = palette)
    }
  }

  # fit the canvas to the content: left room sized by the longest
  # timeframe name (clip = "off" catches what still overflows)
  pad_l <- (0.02 + 0.016 * max(nchar(tfs))) * span
  pad_y <- 0.02 * (yr[2] - yr[1])
  p +
    ggplot2::geom_text(data = lab,
                       ggplot2::aes(x = x, y = y, label = tf),
                       inherit.aes = FALSE, hjust = 1, size = 3.2,
                       colour = "grey25") +
    ggplot2::coord_equal(xlim = c(xr[1] - pad_l, xr[2] + 0.01 * span),
                         ylim = c(yr[1] - pad_y, yr[2] + pad_y),
                         expand = FALSE, clip = "off") +
    ggplot2::theme_void() +
    ggplot2::theme(
      plot.background = ggplot2::element_rect(fill = "white", colour = NA),
      plot.margin = ggplot2::margin(4, 8, 4, 4),
      legend.box.spacing = ggplot2::unit(6, "pt")
    )
}
