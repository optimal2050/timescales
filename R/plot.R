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
#' @param calendar A [`Calendar`].
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
calendar_layout <- function(calendar, annual = TRUE) {
  if (!S7::S7_inherits(calendar, Calendar)) {
    stop("`calendar` must be a Calendar object", call. = FALSE)
  }
  leaves <- S7::prop(calendar, "leaftable")
  tfs    <- S7::prop(calendar, "timeframes")
  levels <- S7::prop(calendar, "members")
  meta   <- S7::prop(calendar, "meta")
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
#' @param object A [`Calendar`].
#' @param fill What drives the fill gradient: `"order"` (chronological
#'   position, default), `"share"`, or `"weight"`.
#' @param color_pattern For `fill = "order"`: `"within"` (default) restarts
#'   the gradient inside each parent timeslice (hours recycle every day);
#'   `"global"` sweeps once across the whole year.
#' @param labels Segment labels: `"name"` (level value, e.g. `h00`;
#'   default), `"timeslice"` (full path, e.g. `Q1_h00`), or `"none"`.
#'   `TRUE`/`FALSE` are accepted as shorthands.
#' @param max_labels Rows with more segments than this get no labels.
#'   Default 60.
#' @param max_segments Rows with more segments than this are binned by
#'   x-midpoint before drawing (fill = width-weighted mean), keeping
#'   hourly calendars fast. Default 2000.
#' @param border Rectangle border color. Default `NA` (none), so dense rows
#'   render as smooth gradients.
#' @param palette Viridis option letter or name (`"D"`/`"viridis"`,
#'   `"C"`/`"plasma"`, `"B"`, `"A"`, `"E"`, `"turbo"`...). Default `"D"`.
#' @param annual Include the `ANNUAL` root band. Default `TRUE`.
#' @param ... Ignored (future extension).
#'
#' @return A ggplot object (returned, not printed).
#'
#' @examples
#' if (requireNamespace("ggplot2", quietly = TRUE)) {
#'   calendar_autoplot(calendar("q4_h24"))
#'   ggplot2::autoplot(calendar("m12"))   # same via the generic
#' }
#' @export
calendar_autoplot <- function(object,
                              fill = c("order", "share", "weight"),
                              color_pattern = c("within", "global"),
                              labels = c("name", "timeslice", "none"),
                              max_labels = 60L,
                              max_segments = 2000L,
                              border = NA,
                              palette = "D",
                              annual = TRUE,
                              ...) {
  .need_ggplot("calendar_autoplot()")
  fill <- match.arg(fill)
  color_pattern <- match.arg(color_pattern)
  if (isTRUE(labels)) labels <- "name"
  if (isFALSE(labels)) labels <- "none"
  labels <- match.arg(labels)

  tfs    <- S7::prop(object, "timeframes")
  levels <- S7::prop(object, "members")
  meta   <- S7::prop(object, "meta")

  d <- calendar_layout(object, annual = annual)
  n_leaf <- nrow(S7::prop(object, "leaftable"))

  # Fill values ---------------------------------------------------------------
  if (fill == "order" && color_pattern == "within") {
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
  row_order <- unique(calendar_layout(object, annual = annual)$timeframe)
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
#' `geoscales::geo_plot()`): callers prepare a `data.frame` keyed by timeslice
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
#' @param ... Passed on to [`calendar_autoplot()`].
#' @export
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
                         ".fill", ".label", ".x", ".y", ".facet"))
