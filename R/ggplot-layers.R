# =============================================================================
# ggplot2 extension layers
# =============================================================================
# The composable layer over the same data helpers that back calendar_plot():
#
#   join_calendar()        timeslice-keyed data.frame + timeframe columns (no
#                          ggplot2 — the tidy-workflow attachment helper)
#   geom_calendar()        datetime-keyed data -> timeslices -> aggregated tiles
#   geom_calendar_tile()   timeslice-keyed data -> aggregated tiles
#   theme_calendar()       the compact heatmap theme
#
# Why layer factories and not ggproto Stats: ggplot2 trains and maps
# positional scales BEFORE statistics run, so a Stat cannot emit discrete
# (factor) axes — the reason timeslices needed its 340-line
# scale_x/y_calendar machinery (integer positions + custom scales), which
# we deliberately do not port. Instead each geom_calendar*() returns ONE
# standard ggplot2::layer() whose `data` is a function of the plot data
# (ggplot2 applies it lazily), with a plain aes(x, y, fill) mapping — so
# discrete scales, facets, and themes all work through the normal path.
# The calendar-specific inputs are therefore column-NAME arguments
# (`datetime=`, `timeslice=`, `z=`), not aes() mappings, and columns needed for
# faceting must be listed in `by=` so aggregation preserves them.
#
# ggplot2 stays in Suggests; nothing here builds ggproto objects.
# =============================================================================

#' Attach a calendar's timeframe columns to timeslice-keyed data
#'
#' Joins the calendar's timeframe columns, `share`, and `weight` onto a
#' `data.frame` keyed by timeslice ID — the attachment step for manual ggplot2
#' work, faceting, or grouped summaries. Timeframe columns are added as
#' factors in vocabulary order so axes and facets sort correctly.
#'
#' @param x A `data.frame` with a column of timeslice IDs.
#' @param calendar A [`Calendar`].
#' @param key Name of the timeslice key column in `x`. Default `"timeslice"`.
#' @param timeframes Which timeframe columns to attach. Default: all of the
#'   calendar's timeframes.
#' @param as_factor Attach timeframe columns as vocabulary-ordered factors
#'   (default `TRUE`) or plain character.
#'
#' @return `x` with the requested timeframe columns plus `share` and
#'   `weight` appended. Rows whose key is not a timeslice of the calendar get
#'   `NA`s (with a warning).
#'
#' @examples
#' cal <- calendar("m12_h24")
#' x <- data.frame(timeslice = S7::prop(cal, "leaves")$timeslice, load = 1)
#' head(join_calendar(x, cal))
#' @export
join_calendar <- function(x, calendar, key = "timeslice", timeframes = NULL,
                          as_factor = TRUE) {
  if (!is.data.frame(x)) {
    .stop("`x` must be a data.frame")
  }
  .check_calendar(calendar)
  if (!key %in% names(x)) {
    .stop("`x` has no column named `%s`; pass `key=`", key)
  }
  leaves <- S7::prop(calendar, "leaves")
  tfs    <- S7::prop(calendar, "timeframes")
  levels <- S7::prop(calendar, "levels")

  if (is.null(timeframes)) {
    timeframes <- tfs
  } else {
    bad <- setdiff(timeframes, tfs)
    if (length(bad) > 0L) {
      .stop("not timeframes of this calendar: %s", .preview(bad))
    }
  }

  mi <- match(as.character(x[[key]]), leaves$timeslice)
  if (all(is.na(mi))) {
    .stop("no rows of `x` matched the calendar's timeslices; check `key=`")
  }
  unknown <- unique(as.character(x[[key]])[is.na(mi)])
  if (length(unknown) > 0L) {
    .warn("%d code(s) in `x$%s` are not timeslices of the calendar: %s",
          length(unknown), key, .preview(unknown))
  }

  for (tf in timeframes) {
    col <- leaves[[tf]][mi]
    x[[tf]] <- if (as_factor) factor(col, levels = levels[[tf]]) else col
  }
  x$share  <- leaves$share[mi]
  x$weight <- leaves$weight[mi]
  x
}

# -----------------------------------------------------------------------------
# Shared aggregation helper
# -----------------------------------------------------------------------------

#' Aggregate a value on timeslices into an x/y tile frame
#'
#' `by_df` columns (facet/grouping carriers) are preserved: aggregation
#' happens within each distinct combination.
#' @noRd
.heat_aggregate <- function(timeslices, z, calendar, x_tf, y_tf, fun,
                            by_df = NULL) {
  leaves <- S7::prop(calendar, "leaves")
  tfs    <- S7::prop(calendar, "timeframes")
  levels <- S7::prop(calendar, "levels")

  # Default layout: finest timeframe on y, next-finest on x
  if (is.null(y_tf) && is.null(x_tf)) {
    if (length(tfs) == 1L) {
      x_tf <- tfs
    } else {
      y_tf <- tfs[length(tfs)]
      x_tf <- tfs[length(tfs) - 1L]
    }
  } else if (is.null(x_tf)) {
    x_tf <- setdiff(rev(tfs), y_tf)[1]
  } else if (is.null(y_tf) && length(setdiff(tfs, x_tf)) > 0L) {
    y_tf <- setdiff(rev(tfs), x_tf)[1]
  }
  .check_timeframe(calendar, c(x_tf, y_tf), "x_tf/y_tf")

  mi <- match(timeslices, leaves$timeslice)
  xl <- as.character(leaves[[x_tf]])[mi]
  yl <- if (!is.null(y_tf)) as.character(leaves[[y_tf]])[mi] else ""
  bl <- if (!is.null(by_df) && ncol(by_df) > 0L) {
    do.call(paste, c(lapply(by_df, as.character), sep = "\r"))
  } else {
    ""
  }

  ok <- !is.na(xl)
  gkey <- paste(xl, yl, bl, sep = "\r")
  first_i <- which(!duplicated(gkey) & ok)
  agg <- tapply(z[ok], gkey[ok], fun)

  out <- data.frame(
    x = factor(xl[first_i], levels = levels[[x_tf]]),
    y = if (!is.null(y_tf)) factor(yl[first_i], levels = levels[[y_tf]])
        else factor(rep("", length(first_i))),
    value = as.numeric(agg[gkey[first_i]]),
    stringsAsFactors = FALSE
  )
  if (!is.null(by_df) && ncol(by_df) > 0L) {
    out <- cbind(out, by_df[first_i, , drop = FALSE])
    rownames(out) <- NULL
  }
  out
}

# -----------------------------------------------------------------------------
# Layer constructors
# -----------------------------------------------------------------------------

#' Calendar layers for ggplot2
#'
#' Composable single layers that put time-series data on a calendar inside
#' a normal `ggplot()` pipeline (the assembled-figure counterparts are
#' [`calendar_autoplot()`] and [`calendar_plot()`]):
#'
#' * `geom_calendar()` — **datetime mode**: name a POSIXct/Date column
#'   (`datetime=`) and a measured column (`z=`); instants are cut to timeslices
#'   via [`instant_to_timeslice()`] and aggregated with `fun`.
#' * `geom_calendar_tile()` — **timeslice mode**: name a timeslice-ID column
#'   (`timeslice=`) and the measured column (`z=`).
#' * `theme_calendar()` — the compact heatmap theme the assembled plots
#'   use.
#'
#' The calendar inputs are column **names**, not `aes()` mappings: ggplot2
#' trains positional scales before statistics run, so a ggproto Stat cannot
#' emit the discrete axes a calendar heatmap needs. Each function instead
#' returns one standard tile layer whose data is derived from the plot (or
#' layer) data — discrete scales, facets, and themes then work through the
#' normal ggplot2 path. The tile fill is the aggregated `value`; axes are
#' vocabulary-ordered factors, so `scale_x_discrete()` etc. apply as usual.
#'
#' **Faceting**: list the columns your facets need in `by=` — aggregation
#' then happens within each combination and the columns survive into the
#' layer data (see the example).
#'
#' @param calendar A [`Calendar`].
#' @param z Name of the numeric column to aggregate and fill by.
#' @param datetime Name of the POSIXct/Date column (`geom_calendar()`).
#'   Default `"datetime"`.
#' @param timeslice Name of the timeslice-ID column (`geom_calendar_tile()`).
#'   Default `"timeslice"`.
#' @param by Character vector of columns to preserve through aggregation
#'   (facet/group carriers). Default none.
#' @param x_tf,y_tf Timeframes for the x and y axes. Default: finest on y,
#'   next-finest on x.
#' @param fun Aggregator over instants/timeslices falling in one tile. Default
#'   `mean`.
#' @param data A `data.frame`; `NULL` (default) uses the plot data.
#' @param ... Passed to the tile geom (e.g. `colour`, `linewidth`), or for
#'   `theme_calendar()` to [`ggplot2::theme()`].
#'
#' @return A single ggplot2 layer (`theme_calendar()` returns a theme).
#'
#' @examples
#' if (requireNamespace("ggplot2", quietly = TRUE)) {
#'   library(ggplot2)
#'   cal <- calendar("m12_h24")
#'
#'   # datetime mode with a facet carrier
#'   x <- data.frame(
#'     t = as.POSIXct("2021-01-01", tz = "UTC") + 3600 * (0:999),
#'     v = rnorm(1000),
#'     site = rep(c("A", "B"), 500)
#'   )
#'   ggplot(x) +
#'     geom_calendar(calendar = cal, datetime = "t", z = "v", by = "site") +
#'     facet_wrap(~site) +
#'     theme_calendar()
#'
#'   # timeslice mode
#'   y <- data.frame(timeslice = S7::prop(cal, "leaves")$timeslice, v = 1:288)
#'   ggplot(y) +
#'     geom_calendar_tile(calendar = cal, z = "v") +
#'     theme_calendar()
#' }
#' @export
geom_calendar <- function(calendar, z,
                          datetime = "datetime",
                          by = NULL,
                          x_tf = NULL, y_tf = NULL,
                          fun = mean,
                          data = NULL,
                          ...) {
  .need_ggplot("geom_calendar()")
  .check_calendar(calendar)
  build <- function(d) {
    .check_layer_cols(d, c(datetime, z, by))
    dtm <- d[[datetime]]
    if (inherits(dtm, "Date")) dtm <- as.POSIXct(dtm, tz = "UTC")
    if (!inherits(dtm, "POSIXt")) {
      .stop("column `%s` must be POSIXct/Date for geom_calendar()", datetime)
    }
    timeslices <- instant_to_timeslice(dtm, calendar)
    .heat_aggregate(timeslices, d[[z]], calendar, x_tf, y_tf, fun,
                    by_df = if (length(by)) d[by] else NULL)
  }
  .calendar_tile_layer(build, data, z, ...)
}

#' @rdname geom_calendar
#' @export
geom_calendar_tile <- function(calendar, z,
                               timeslice = "timeslice",
                               by = NULL,
                               x_tf = NULL, y_tf = NULL,
                               fun = mean,
                               data = NULL,
                               ...) {
  .need_ggplot("geom_calendar_tile()")
  .check_calendar(calendar)
  build <- function(d) {
    .check_layer_cols(d, c(timeslice, z, by))
    .heat_aggregate(as.character(d[[timeslice]]), d[[z]], calendar,
                    x_tf, y_tf, fun,
                    by_df = if (length(by)) d[by] else NULL)
  }
  .calendar_tile_layer(build, data, z, ...)
}

#' Assemble the single tile layer shared by both geoms
#' @noRd
.calendar_tile_layer <- function(build, data, z, ...) {
  ggplot2::layer(
    geom = ggplot2::GeomTile,
    stat = "identity",
    position = "identity",
    # ggplot2 applies a function `data` to the plot data lazily; an
    # explicit data.frame is transformed eagerly
    data = if (is.null(data)) build else build(data),
    mapping = ggplot2::aes(x = x, y = y, fill = value),
    inherit.aes = FALSE,
    params = list(...)
  )
}

utils::globalVariables(c("x", "y", "value"))

#' @noRd
.check_layer_cols <- function(d, cols) {
  missing <- setdiff(cols, names(d))
  if (length(missing) > 0L) {
    .stop("column(s) not found in the layer data: %s", .preview(missing))
  }
  invisible(d)
}

#' @rdname geom_calendar
#' @export
theme_calendar <- function(...) {
  .need_ggplot("theme_calendar()")
  ggplot2::theme_minimal() +
    ggplot2::theme(panel.grid = ggplot2::element_blank(),
                   axis.text = ggplot2::element_text(size = 8),
                   ...)
}
