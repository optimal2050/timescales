# =============================================================================
# Calendar visualization
# =============================================================================
# Three layers, mirroring geoscales/R/plot.R:
#
#   calendar_layout(cal)      -> plain data.frame of rectangles (no ggplot2);
#                                the plotting-system-agnostic foundation
#   calendar_autoplot(cal)    -> the structure icicle (standard geom_rect)
#   calendar_plot(cal, data)  -> the single data-on-calendar heatmap renderer
#
# autoplot()/plot() dispatch to calendar_autoplot(). ggplot2 is a Suggests
# dependency, guarded by .need_ggplot(); custom stat_*/geom_* layers are a
# deliberate later stage built over the same layout/heat-data helpers (see
# dev/review-core.md and the plan) — nothing here uses ggproto.
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
#' backs [`calendar_autoplot()`].
#'
#' @param x A [`Calendar`].
#' @param annual Include the `ANNUAL` root band on top? Default `TRUE`.
#'
#' @return A `data.frame` with columns `timeframe`, `label` (the level value
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
  keys <- lapply(tfs, function(tf) match(as.character(leaves[[tf]]),
                                         levels[[tf]]))
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
# calendar_autoplot()
# -----------------------------------------------------------------------------

#' Plot a calendar's structure as an icicle
#'
#' One horizontal band per timeframe (`ANNUAL` root on top, coarsest first),
#' rectangle widths proportional to timeslice shares, x spanning the covered
#' year on `[0, 1]`. `autoplot()` and `plot()` on a Calendar dispatch here.
#'
#' @param x A [`Calendar`].
#' @param type `"icicle"` (default) or `"stack"` — the axonometric
#'   stacked-planes view (see below).
#' @param fill What drives the fill gradient: `"order"` (chronological
#'   position, default), `"share"`, or `"weight"`.
#' @param color_pattern For `fill = "order"`: `"within"` (default) restarts
#'   the gradient inside each parent timeslice (hours recycle every day);
#'   `"global"` sweeps once across the whole year.
#' @param labels Segment labels. Icicle: `"name"` (level value, e.g.
#'   `h00`; default), `"timeslice"` (full path, e.g. `Q1_h00`), or
#'   `"none"`; `TRUE`/`FALSE` are accepted as shorthands.
#'   `type = "stack"`: a character vector of timeframes whose member
#'   names are drawn on their plane's segments (e.g.
#'   `labels = "SEASON"`); unset = none.
#' @param max_labels Rows with more segments than this get no labels.
#'   Default 60.
#' @param max_segments Rows with more segments than this are binned by
#'   x-midpoint before drawing (fill = width-weighted mean), keeping
#'   hourly calendars fast. Default 2000.
#' @param border Rectangle border color. Default `NA` (none), so dense rows
#'   render as smooth gradients.
#' @param palette Viridis option letter or name (`"D"`/`"viridis"`,
#'   `"C"`/`"plasma"`, `"B"`, `"A"`, `"E"`, `"turbo"`...). Default `"D"`.
#'   `type = "stack"` also accepts `NULL`: no fill scale is added, so
#'   you can supply your own (e.g. an energypal scale).
#' @param annual Include the `ANNUAL` root band. Default `TRUE`.
#' @param view `type = "stack"` only: a predefined point of view --
#'   `"oblique"` (the shear/depth default), `"top-down"`, `"cavalier"`,
#'   `"cabinet"`, `"military"`, `"isometric"`, `"dimetric"`,
#'   `"trimetric"`, or `"perspective"` (receding planes shrink).
#' @param angle,ratio `type = "stack"` only: oblique view by angle
#'   (degrees of the receding axis) and foreshortening ratio --
#'   `e2 = ratio * (cos(angle), sin(angle))`. Overridden by `view`.
#' @param shear,depth,gap `type = "stack"` only: the raw receding-axis
#'   components (`e2 = (shear, depth)`; used when neither `view` nor
#'   `angle`/`ratio` is given) and the vertical spacing between planes.
#'   `gap = NULL` (default) spaces planes almost touching, with a slight
#'   overlap (0.85 x the plane's screen height).
#' @param rotate `type = "stack"` only: in-plane rotation of each plane
#'   (degrees, counter-clockwise) before projection.
#' @param direction `type = "stack"` only: `"up"` (default) stacks the
#'   coarsest timeframe on top; `"down"` puts it at the bottom.
#' @param colour,linewidth `type = "stack"` only: segment border colour
#'   and width, recycled across the planes (one entry per plane styles
#'   them individually). Defaults `"grey35"` and `0.2` -- ggplot2's own
#'   sf polygon border. (The icicle's rectangle border is the separate
#'   `border` argument.)
#' @param frame `type = "stack"` only: draw each plane's outline (the
#'   unit box run through the same projection) as a guide. `TRUE` uses
#'   `"grey80"`, a colour string uses that colour, `NULL` (default)
#'   draws no frames.
#' @param frame_fill `type = "stack"` only: fill for the plane sheets;
#'   best mostly transparent, e.g.
#'   `frame_fill = ggplot2::alpha("grey60", 0.12)`. Setting a fill
#'   draws the frames even without `frame`; `NA` (default) = no fill.
#' @param data,z Colour the figure by a value instead of by structure:
#'   works for BOTH types -- the icicle fills each band's rectangles,
#'   the stack fills each plane. `data` is a data.frame with a
#'   `timeslice` column at the calendar's resolution (or a
#'   calendar-named label column) plus the value column named by `z`;
#'   every timeframe gets the value recast to its resolution, so the
#'   whole figure shares one continuous fill scale (legend title via
#'   `labs(fill = )`). On the icicle, `data` overrides
#'   `fill`/`color_pattern`, and dense bands are binned with
#'   width-weighted means.
#' @param rule With `data`: aggregation rule for the per-timeframe
#'   recasts (`"sum"`, `"mean"`, `"weighted_mean"`, ... -- see
#'   [`recast_calendar()`]; explicit or registered, never guessed).
#' @param year With `data`: the model year the recast routes through
#'   (required by [`recast_calendar()`]).
#' @param by With `data`: base-grid granularity for the per-timeframe
#'   recasts. Defaults to `"hour"` -- always correct (the automatic
#'   choice can pick a daily grid for sub-daily calendars, which
#'   silently collapses hour-type slices).
#' @param connectors `type = "stack"` only: dashed lines joining the
#'   corresponding frame corners of adjacent planes. `TRUE` uses the
#'   frame colour, a colour string picks its own; default `FALSE`.
#' @param ... Ignored (future extension).
#'
#' @section The stack view:
#' `type = "stack"` draws the same structure axonometrically — one
#' sheared plane per timeframe, `ANNUAL` on top, each plane segmented by
#' the true duration shares, with segments visibly nesting into the
#' plane above. `fill`/`labels`/`max_segments` apply to the icicle only;
#' the stack colours each plane by its own segment order.
#'
#' @return A ggplot object (returned, not printed).
#'
#' @examples
#' if (requireNamespace("ggplot2", quietly = TRUE)) {
#'   calendar_autoplot(calendar("q4_h24"))
#'   ggplot2::autoplot(calendar("m12"))   # same via the generic
#'   calendar_autoplot(calendar("s4_hp3"), type = "stack")
#' }
#' @export
calendar_autoplot <- function(x,
                              type = c("icicle", "stack"),
                              fill = c("order", "share", "weight"),
                              color_pattern = c("within", "global"),
                              labels = c("name", "timeslice", "none"),
                              max_labels = 60L,
                              max_segments = 2000L,
                              border = NA,
                              palette = "D",
                              annual = TRUE,
                              view = NULL, angle = NULL, ratio = NULL,
                              shear = 0.5, depth = 0.3, gap = NULL,
                              rotate = 0, direction = c("up", "down"),
                              colour = "grey35", linewidth = 0.2,
                              frame = NULL, frame_fill = NA,
                              connectors = FALSE,
                              data = NULL, z = NULL, rule = "weighted_mean",
                              year = NULL, by = "hour",
                              ...) {
  .need_ggplot("calendar_autoplot()")
  type <- match.arg(type)
  if (type == "stack") {
    # `labels` means something else on the stack (a vector of timeframes
    # whose member names go on the planes, mirroring geoscales); the
    # icicle's c("name","timeslice","none") default must not leak in
    stack_labels <- if (missing(labels)) NULL else labels
    return(.calendar_stack_plot(x, annual = annual, palette = palette,
                                view = view, angle = angle, ratio = ratio,
                                shear = shear, depth = depth, gap = gap,
                                rotate = rotate, direction = direction,
                                colour = colour, linewidth = linewidth,
                                frame = frame, frame_fill = frame_fill,
                                connectors = connectors,
                                data = data, z = z, rule = rule,
                                year = year, by = by,
                                labels = stack_labels))
  }
  fill <- match.arg(fill)
  color_pattern <- match.arg(color_pattern)
  if (isTRUE(labels)) labels <- "name"
  if (isFALSE(labels)) labels <- "none"
  labels <- match.arg(labels)

  tfs    <- S7::prop(x, "timeframes")
  levels <- S7::prop(x, "members")
  meta   <- S7::prop(x, "meta")

  d <- calendar_layout(x, annual = annual)
  n_leaf <- nrow(S7::prop(x, "leaftable"))

  # Fill values ---------------------------------------------------------------
  if (!is.null(data)) {
    # data fill: each band's rectangles carry the value recast to that
    # band's timeframe (widths still encode duration shares). Overrides
    # `fill`/`color_pattern`. Dense bands are binned below with
    # width-weighted means, which is the right downsample for a value.
    row_tfs <- unique(d$timeframe)
    vals <- .calendar_frame_values(x, row_tfs, data, z, rule, year, by)
    d$.fill <- NA_real_
    for (tf in row_tfs) {
      i <- d$timeframe == tf
      d$.fill[i] <- vals[[tf]][[z]][match(d$timeslice[i],
                                          vals[[tf]]$timeslice)]
    }
    # legend title via labs() below so callers can retitle
    fill_scale <- ggplot2::scale_fill_viridis_c(option = palette)
  } else if (fill == "order" && color_pattern == "within") {
    # 0-1 gradient recycling inside each parent; scaled by the timeframe's
    # vocabulary size so h00..h23 always spans the full palette
    klev <- c(ANNUAL = 1L,
              vapply(tfs, function(tf) length(levels[[tf]]), integer(1)))
    d$.fill <- (d$within - 1) / pmax(1, klev[d$timeframe] - 1)
    fill_scale <- ggplot2::scale_fill_viridis_c(
      option = palette, limits = c(0, 1), breaks = c(0, 1),
      labels = c("first", "last"), name = "timeslice")
  } else if (fill == "order") {
    d$.fill <- d$order
    fill_scale <- ggplot2::scale_fill_viridis_c(
      option = palette, limits = c(1, n_leaf), breaks = c(1, n_leaf),
      labels = c("1", format(n_leaf)), name = "timeslice")
  } else {
    d$.fill <- d[[fill]]
    fill_scale <- ggplot2::scale_fill_viridis_c(option = palette,
                                                name = fill)
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
  row_order <- unique(calendar_layout(x, annual = annual)$timeframe)
  n_rows <- length(row_order)
  p <- ggplot2::ggplot(d) +
    ggplot2::geom_rect(
      ggplot2::aes(xmin = xmin, xmax = xmax, ymin = ymin, ymax = ymax,
                   fill = .fill),
      color = border, linewidth = 0.15) +
    fill_scale +
    ggplot2::scale_x_continuous("share of the year",
                                limits = c(0, 1),
                                expand = ggplot2::expansion(mult = 0.005)) +
    ggplot2::scale_y_continuous(NULL,
                                breaks = rev(seq_len(n_rows)) - 0.55,
                                labels = row_order) +
    ggplot2::theme_minimal() +
    ggplot2::theme(panel.grid = ggplot2::element_blank())

  if (!is.null(meta$name) && nzchar(meta$name)) {
    p <- p + ggplot2::labs(
      title = meta$name,
      subtitle = if (!is.null(meta$desc) && nzchar(meta$desc)) meta$desc)
  }
  if (!is.null(data)) p <- p + ggplot2::labs(fill = z)

  # Labels ---------------------------------------------------------------------
  if (labels != "none") {
    lab_rows <- names(seg_n)[seg_n <= max_labels]
    ld <- d[d$timeframe %in% lab_rows & !is.na(d$timeslice), , drop = FALSE]
    if (nrow(ld) > 0L) {
      ld$.label <- if (labels == "timeslice") ld$timeslice else ld$label
      # white on dark cells, dark on light ones (normalize fill to [0,1])
      rng <- range(d$.fill, finite = TRUE)
      f01 <- if (diff(rng) > 0) (ld$.fill - rng[1]) / diff(rng) else 0.5
      f01[!is.finite(f01)] <- 0
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
.calendar_frame_values <- function(calendar, tfs, data, z, rule, year, by) {
  if (is.null(data)) return(NULL)
  if (is.null(z) || !z %in% names(data)) {
    stop("`z` must name a value column of `data`", call. = FALSE)
  }
  if (is.null(year)) {
    stop("`data` needs `year =`: the per-timeframe recasts route ",
         "through recast_calendar(), which requires it", call. = FALSE)
  }
  vals <- lapply(tfs, function(tf) {
    as.data.frame(recast_calendar(data, from = calendar, to = tf,
                                  year = year, values = z, rule = rule,
                                  by = by))
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
    r$.fill  <- stats::weighted.mean(row_df$.fill[i], width[i])
    r$timeslice  <- NA_character_   # a bin is not a real timeslice; also mutes labels
    r
  })
  do.call(rbind, out)
}

# -----------------------------------------------------------------------------
# calendar_plot() — the data-on-calendar heatmap
# -----------------------------------------------------------------------------

#' Heatmap of data on a calendar
#'
#' The package's single data-on-calendar renderer (the analogue of
#' `geoscales::geoscale_plot()`): callers prepare a `data.frame` keyed by timeslice
#' and hand it over. With no data, the calendar's own `share` is drawn — a
#' quick structural view. Layout follows the calendar's hierarchy: finest
#' timeframe on y, next-finest on x, anything coarser as facets
#' (overridable via `x_tf`/`y_tf`/`facet_tf`).
#'
#' @param x A [`Calendar`].
#' @param data Optional `data.frame` with a `key` column of timeslice IDs plus
#'   one numeric value column (pick with `values=` if there are several).
#'   Default `NULL` plots `leaves$share`.
#' @param values Name of the value column to plot. Default: the first
#'   numeric column other than `key`.
#' @param key Name of the timeslice key column in `data`. Default `"timeslice"`.
#' @param x_tf,y_tf,facet_tf Timeframe names overriding the automatic
#'   layout.
#' @param fun Aggregator applied when the chosen layout drops timeframes
#'   (e.g. plotting an hourly calendar by MONTH x HOUR averages over days).
#'   Default `mean`.
#' @param palette `NULL` (default) keeps ggplot2's default continuous
#'   gradient; a viridis option letter/name opts in.
#' @param ... Ignored (future extension).
#'
#' @return A ggplot object.
#'
#' @examples
#' if (requireNamespace("ggplot2", quietly = TRUE)) {
#'   calendar_plot(calendar("m12_h24"))   # structure: share heatmap
#'
#'   cal <- calendar("m12")
#'   x <- data.frame(timeslice = sprintf("m%02d", 1:12), load = 1:12)
#'   calendar_plot(cal, x)
#' }
#' @export
calendar_plot <- function(x, data = NULL,
                          values = NULL,
                          key = "timeslice",
                          x_tf = NULL, y_tf = NULL, facet_tf = NULL,
                          fun = mean,
                          palette = NULL,
                          ...) {
  .need_ggplot("calendar_plot()")
  if (!S7::S7_inherits(x, Calendar)) {
    stop("`x` must be a Calendar object", call. = FALSE)
  }
  hd <- .calendar_heat_data(x, data, values, key, x_tf, y_tf, facet_tf, fun)
  meta <- S7::prop(x, "meta")

  p <- ggplot2::ggplot(hd$df, ggplot2::aes(x = .x, y = .y, fill = .fill)) +
    ggplot2::geom_tile() +
    ggplot2::scale_x_discrete(hd$x_tf, breaks = hd$x_breaks) +
    ggplot2::scale_y_discrete(hd$y_tf, breaks = hd$y_breaks) +
    ggplot2::labs(fill = hd$fill_label) +
    theme_calendar()

  if (!is.null(palette)) {
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
.calendar_heat_data <- function(cal, data, values, key,
                                x_tf, y_tf, facet_tf, fun) {
  leaves <- S7::prop(cal, "leaftable")
  tfs    <- S7::prop(cal, "timeframes")
  levels <- S7::prop(cal, "members")

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
    if (is.null(values)) {
      cand <- setdiff(names(data), key)
      values <- cand[vapply(data[cand], is.numeric, logical(1))][1]
      if (is.na(values) || length(values) == 0L) {
        stop("No numeric value column found in `data`; specify `values=`.",
             call. = FALSE)
      }
    }
    if (length(values) != 1L || !values %in% names(data)) {
      stop("`values` must name exactly one column of `data`", call. = FALSE)
    }
    mi <- match(leaves$timeslice, data[[key]])
    if (all(is.na(mi))) {
      stop("no rows of `data` matched the calendar's timeslices; check `key=`",
           call. = FALSE)
    }
    val <- data[[values]][mi]
    fill_label <- values
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
# Generics: autoplot() and plot()
# -----------------------------------------------------------------------------

#' @rdname calendar_autoplot
#' @param object A [`Calendar`] (the S3 `autoplot()` generic's argument
#'   name; `calendar_autoplot()` itself takes `x`).
#' @param ... Passed on to [`calendar_autoplot()`].
#' @exportS3Method ggplot2::autoplot
autoplot.Calendar <- function(object, ...) {
  calendar_autoplot(object, ...)
}

# Registered on ggplot2::autoplot in .onLoad (R/zzz.R) under both class
# strings, the geoscales pattern.

#' @rdname calendar_autoplot
#' @param x A [`Calendar`] (for `plot()`).
#' @export
#' @method plot Calendar
plot.Calendar <- function(x, ...) {
  calendar_autoplot(x, ...)
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
#' `view` preset > `angle`/`ratio` (oblique: `e2 = ratio * (cos, sin)`)
#' > raw `shear`/`depth` (`e2 = (shear, depth)`).
#' Duplicated verbatim in geoscales/R/plot.R -- keep in sync.
#' @noRd
.stack_view <- function(view = NULL, angle = NULL, ratio = NULL,
                        shear = 0.5, depth = 0.3) {
  deg <- pi / 180
  if (!is.null(view)) {
    view <- match.arg(view, c("oblique", "top-down", "cavalier",
                              "cabinet", "military", "isometric",
                              "dimetric", "trimetric", "perspective"))
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
                           scale = 0.82)
    ))
  }
  if (!is.null(angle) || !is.null(ratio)) {
    a <- (angle %||% 45) * deg
    return(list(e1 = c(1, 0), e2 = (ratio %||% 0.5) * c(cos(a), sin(a)),
                scale = 1))
  }
  list(e1 = c(1, 0), e2 = c(shear, depth), scale = 1)
}

#' Draw the calendar as stacked planes under a chosen point of view
#'
#' One plane per timeframe, coarsest on top; each plane's segments are
#' the timeframe's members at their true duration shares. Colours cycle
#' per plane (normalized segment order). Planes may overlap when `gap`
#' is smaller than a plane's screen height -- painter order (bottom
#' first) keeps the stack readable.
#' @noRd
.calendar_stack_plot <- function(calendar, annual = TRUE, palette = "D",
                                 view = NULL, angle = NULL, ratio = NULL,
                                 shear = 0.5, depth = 0.3, gap = NULL,
                                 rotate = 0,
                                 direction = c("up", "down"),
                                 colour = "grey35", linewidth = 0.2,
                                 frame = NULL, frame_fill = NA,
                                 connectors = FALSE,
                                 data = NULL, z = NULL, rule = "weighted_mean",
                                 year = NULL, by = "hour",
                                 labels = NULL) {
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
  vals <- .calendar_frame_values(calendar, tfs, data, z, rule, year, by)
  if (!is.null(labels)) {
    bad <- setdiff(labels, tfs)
    if (length(bad)) {
      stop("`labels` must name timeframes of the calendar (unknown: ",
           paste(bad, collapse = ", "), ")", call. = FALSE)
    }
  }

  rad <- rotate * pi / 180
  corner <- function(u, w) {
    du <- u - 0.5; dw <- w - 0.5                 # in-plane rotation first
    ur <- 0.5 + du * cos(rad) - dw * sin(rad)
    wr <- 0.5 + du * sin(rad) + dw * cos(rad)
    cbind(ur * v$e1[1] + wr * v$e2[1],
          ur * v$e1[2] + wr * v$e2[2])
  }
  ctr <- corner(0.5, 0.5)                        # plane center, pre-lift

  # vertical placement: coarsest on top ("up", default) or bottom
  zlev <- if (direction == "up") (nk - seq_len(nk)) * gap
          else (seq_len(nk) - 1) * gap
  top_rank <- if (direction == "up") seq_len(nk) - 1 else nk - seq_len(nk)

  quads <- do.call(rbind, lapply(seq_along(tfs), function(k) {
    d <- lay[lay$timeframe == tfs[k], , drop = FALSE]
    sk <- v$scale^top_rank[k]                    # top plane is largest
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
      q <- sweep(sweep(cn, 2, ctr) * v$scale^top_rank[k], 2, ctr, `+`)
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
      ggplot2::geom_polygon(data = quads[quads$tf == tfs[k], ],
                            ggplot2::aes(fill = ord),
                            colour = col_k[k], linewidth = lwd_k[k],
                            show.legend = FALSE)
    } else {
      ggplot2::geom_polygon(data = quads[quads$tf == tfs[k], ],
                            ggplot2::aes(fill = .z),
                            colour = col_k[k], linewidth = lwd_k[k])
    }
  }
  if (!is.null(labels)) {                # member names, over all planes
    labdf <- do.call(rbind, lapply(match(labels, tfs), function(k) {
      d <- lay[lay$timeframe == tfs[k], , drop = FALSE]
      pc <- corner((d$xmin + d$xmax) / 2, rep(0.5, nrow(d)))
      pc <- sweep(sweep(pc, 2, ctr) * v$scale^top_rank[k], 2, ctr, `+`)
      data.frame(x = pc[, 1], y = pc[, 2] + zlev[k], .label = d$label,
                 stringsAsFactors = FALSE)
    }))
    p <- p + ggplot2::geom_text(data = labdf,
                                ggplot2::aes(x = x, y = y, label = .label),
                                inherit.aes = FALSE,
                                size = 2.4, colour = "grey10")
  }

  # legend title via labs() so callers can retitle with `+ labs(fill = )`
  if (!is.null(vals)) p <- p + ggplot2::labs(fill = z)
  if (!is.null(palette)) {               # NULL = caller adds a scale
    p <- p + if (is.null(vals)) {
      ggplot2::scale_fill_viridis_c(option = palette, guide = "none")
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
