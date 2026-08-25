# =============================================================================
# Wall-calendar layout: calendar_weekdays() / calendar_wall_layout() /
# calendar_wall_plot()
# =============================================================================
# The wall form: months as facets, day cells in a week grid -- either
# arranged by weekday (a true wall calendar; year-specific, since which
# weekday a date falls on comes from the base grid) or as a plain
# year-free sequence. Ships as a layout worker + an assembled figure,
# the same split as calendar_layout()/calendar_plot(): a single ggplot2
# layer cannot carry facets, and the month faceting is the essence of
# the form, so this is deliberately NOT a geom_*().
#
# ggplot2 stays in Suggests; only calendar_wall_plot() touches it.
# =============================================================================

#' Weekdays of a calendar's day layer in a given model year
#'
#' Maps every day of the calendar's day layer (its `YDAY` or `MDAY`
#' timeframe) onto the real dates of one model year and reports the
#' weekday structure: weekday, week-of-month row, and an anchored
#' week-of-year index. The model year honours `meta$year_start` (so for
#' the `fy04_*` fiscal calendars it runs April..March and `wyear` counts
#' fiscal weeks from April 1) and `meta$utc_offset_minutes`.
#'
#' Stylized days with no real date in that year (`m12_md360`'s day 31,
#' the `d366` label in a non-leap year) get `date = NA` with one warning.
#'
#' @param x A [`Calendar`] with a day-resolution timeframe
#'   (`YDAY` or `MDAY`). Sub-daily timeframes are collapsed to the day
#'   layer via [`prune_calendar()`].
#' @param year Integer scalar model year.
#' @param week_start Weekday the week starts on: one of
#'   `"MON"`..`"SUN"` (default `"MON"`, ISO).
#'
#' @return A `data.frame`, one row per day of the day layer, in calendar
#'   order: `timeslice` (day-level node ID), `date` (`Date`, `NA` where
#'   the stylized day has no real date), `MONTH` (facet key: the
#'   calendar's MONTH members when present, else the Gregorian
#'   `m01..m12` template; fiscal-ordered under a nontrivial
#'   `year_start`), `mday` (day-of-month number), `wday` (factor,
#'   vocabulary rotated to `week_start`), `wrow` (week-of-month row,
#'   1 = first week, breaking on `week_start`), and `wyear`
#'   (week-of-year, week 1 = the week containing the year anchor).
#'
#' @examples
#' wd <- calendar_weekdays(calendar("m12_md365"), 2021)
#' head(wd)
#' # fiscal weeks: April 1 opens week 1
#' head(calendar_weekdays(calendar("fy04_d365"), 2021))
#' @export
calendar_weekdays <- function(x, year, week_start = "MON") {
  .check_calendar(x)
  year <- as.integer(year)
  if (length(year) != 1L || is.na(year)) {
    .stop("`year` must be a single integer")
  }
  ws <- .wall_week_start(week_start)

  day <- .wall_day_layer(x)
  out <- .wall_days(day)

  # Real dates of the model year for each day timeslice, via the base
  # grid (honours year_start and utc_offset_minutes)
  grid <- expand_calendar(day$cal, year, by = "day")
  grid <- grid[!is.na(grid$timeslice), , drop = FALSE]
  out$date <- as.Date(grid$datetime[match(out$timeslice, grid$timeslice)])
  undated <- is.na(out$date)
  if (any(undated)) {
    .warn("%d day(s) have no real date in %d and get NA: %s",
          sum(undated), year, .preview(out$timeslice[undated]))
  }

  # YDAY-only calendars: with real dates in hand, month/mday come from the
  # dates themselves (the stylized month-length template only approximates
  # real month boundaries -- d360's 30-day months would misplace Jan 31);
  # facet level order = first appearance in x order (fiscal-safe)
  if (day$day_tf == "YDAY" && any(!undated)) {
    m_lab <- as.character(out$MONTH)
    m_lab[!undated] <- sprintf("m%02d",
                               as_timeframe(out$date[!undated], "MONTH"))
    out$MONTH <- factor(m_lab, levels = unique(m_lab))
    out$mday[!undated] <- as.integer(
      as_timeframe(out$date[!undated], "MDAY"))
  }

  wnum <- as_timeframe(out$date, "WDAY", week_start = ws)
  out$wday <- factor(.wall_wday_labels(ws)[wnum],
                     levels = .wall_wday_labels(ws))
  out$wrow <- as.integer(as_timeframe(out$date, "MWEEK", week_start = ws))

  # Anchored week-of-year: week 1 = the week (breaking on week_start)
  # containing the model-year anchor
  ys <- S7::prop(x, "meta")$year_start %||% list(month = 1L, day = 1L)
  anchor <- as.Date(sprintf("%04d-%02d-%02d", year,
                            as.integer(ys$month), as.integer(ys$day)))
  wfloor <- anchor -
    (as.integer(as_timeframe(anchor, "WDAY", week_start = ws)) - 1L)
  out$wyear <- as.integer(as.numeric(out$date - wfloor) %/% 7L) + 1L

  rownames(out) <- NULL
  out[, c("timeslice", "date", "MONTH", "mday", "wday", "wrow", "wyear"),
      drop = FALSE]
}

#' Wall-calendar tile layout
#'
#' The layout worker behind [`calendar_wall_plot()`]: one row per day
#' cell with facet key and grid position. Two arrangements:
#'
#' * `arrange = "weekday"` -- a true wall calendar: columns are weekdays
#'   (starting at `week_start`), rows are weeks of the month. Needs
#'   `year` (weekdays are year-specific); when `year` is `NULL` it FALLS
#'   BACK to `"sequence"` with a message.
#' * `arrange = "sequence"` -- year-free: days flow left-to-right in
#'   fixed 7-wide rows, no weekday meaning.
#'
#' @inheritParams calendar_weekdays
#' @param year Integer model year (required for the weekday
#'   arrangement; `NULL` falls back to `"sequence"` with a message).
#' @param arrange `"weekday"` or `"sequence"` (see above).
#'
#' @return A `data.frame`: `timeslice`, `MONTH` (factor in member
#'   order), `label` (day-of-month number), `col`, `row`, `wday`
#'   (factor, `NA` in sequence mode), `date` (`NA` in sequence mode).
#'
#' @examples
#' head(calendar_wall_layout(calendar("m12_md365"), year = 2021))
#' head(calendar_wall_layout(calendar("m12_md365")))  # sequence fallback
#' @export
calendar_wall_layout <- function(x, year = NULL,
                                 arrange = c("weekday", "sequence"),
                                 week_start = "MON") {
  .check_calendar(x)
  arrange <- match.arg(arrange)
  if (arrange == "weekday" && is.null(year)) {
    message("weekday arrangement needs `year=` (weekdays are ",
            "year-specific); falling back to arrange = \"sequence\"")
    arrange <- "sequence"
  }

  if (arrange == "weekday") {
    wd <- calendar_weekdays(x, year, week_start = week_start)
    dated <- !is.na(wd$date)
    if (!all(dated)) wd <- wd[dated, , drop = FALSE]
    out <- data.frame(
      timeslice = wd$timeslice,
      MONTH     = wd$MONTH,
      label     = wd$mday,
      col       = as.integer(wd$wday),
      row       = wd$wrow,
      wday      = wd$wday,
      date      = wd$date,
      stringsAsFactors = FALSE
    )
  } else {
    d <- .wall_days(.wall_day_layer(x))
    out <- data.frame(
      timeslice = d$timeslice,
      MONTH     = d$MONTH,
      label     = d$mday,
      col       = (d$mday - 1L) %% 7L + 1L,
      row       = (d$mday - 1L) %/% 7L + 1L,
      wday      = factor(rep(NA_character_, nrow(d)),
                         levels = .wall_wday_labels(.wall_week_start(
                           week_start))),
      date      = as.Date(rep(NA, nrow(d))),
      stringsAsFactors = FALSE
    )
  }
  rownames(out) <- NULL
  out
}

#' Wall-calendar figure
#'
#' Draws the calendar as a wall calendar: one facet per month (in member
#' order -- April first for the `fy04_*` fiscal calendars), day cells in
#' a week grid, weeks top-down. With `data`, day cells are filled by the
#' aggregated value; without, a plain calendar (day numbers only).
#'
#' `data` may be keyed by timeslice (day-level IDs directly; finer IDs
#' -- e.g. hours of `d365_h24` -- roll up into their day cell) or by
#' datetime (mapped through [`datetime_to_timeslice()`] on the day
#' layer). The key column is auto-detected (`timeslice`, else the first
#' POSIXct/Date column) unless `key=` names it.
#'
#' @inheritParams calendar_wall_layout
#' @param data Optional `data.frame` of values to fill the day cells.
#' @param z Name of the numeric value column of `data`.
#' @param fun Aggregator collapsing multiple observations (sub-daily
#'   timeslices, repeated dates) into one day cell. Default `mean`.
#' @param label Draw day-of-month numbers (default `TRUE`).
#' @param key Key column of `data`; `NULL` auto-detects.
#' @param ... Passed to [`ggplot2::theme()`] via [`theme_calendar()`].
#'
#' @return A ggplot object.
#'
#' @examples
#' if (requireNamespace("ggplot2", quietly = TRUE)) {
#'   # plain wall calendar for 2021
#'   calendar_wall_plot(calendar("m12_md365"), year = 2021)
#'
#'   # daily data on a fiscal wall (April..March facets)
#'   cal <- calendar("fy04_d365")
#'   x <- data.frame(
#'     timeslice = S7::prop(cal, "leaftable")$timeslice,
#'     v = cumsum(stats::rnorm(365))
#'   )
#'   calendar_wall_plot(cal, x, z = "v", year = 2021)
#' }
#' @export
calendar_wall_plot <- function(x, data = NULL, z = NULL,
                               year = NULL,
                               arrange = c("weekday", "sequence"),
                               week_start = "MON",
                               fun = mean, label = TRUE, key = NULL,
                               ...) {
  .need_ggplot("calendar_wall_plot()")
  lay <- calendar_wall_layout(x, year = year, arrange = arrange,
                              week_start = week_start)
  weekday_mode <- !all(is.na(lay$wday))

  if (!is.null(data)) {
    if (is.null(z)) {
      .stop("`z` must name the value column of `data`")
    }
    vals <- .wall_values(x, data, z, key, fun)
    lay$value <- vals[lay$timeslice]
  }

  p <- ggplot2::ggplot(lay, ggplot2::aes(x = col, y = row))
  p <- if (!is.null(data)) {
    p + ggplot2::geom_tile(ggplot2::aes(fill = value),
                           colour = "white", linewidth = 0.4)
  } else {
    p + ggplot2::geom_tile(fill = "grey93", colour = "white",
                           linewidth = 0.4)
  }
  if (isTRUE(label)) {
    p <- p + ggplot2::geom_text(ggplot2::aes(label = label), size = 2.6,
                                colour = "grey25")
  }
  p <- p +
    ggplot2::scale_y_reverse(breaks = NULL) +
    ggplot2::facet_wrap(~MONTH, labeller = .wall_month_labeller(
      years = if (weekday_mode) .wall_month_years(lay))) +
    theme_calendar(...) +
    ggplot2::labs(x = NULL, y = NULL)
  p <- if (weekday_mode) {
    # single letters (M T W T F S S, rotated to week_start): full names
    # overlay each other across twelve narrow facets
    p + ggplot2::scale_x_continuous(breaks = 1:7,
                                    labels = substr(levels(lay$wday),
                                                    1, 1),
                                    position = "top")
  } else {
    p + ggplot2::scale_x_continuous(breaks = NULL)
  }
  p
}

# -----------------------------------------------------------------------------
# Internals
# -----------------------------------------------------------------------------

#' Resolve week_start against the weekday vocabulary -> lubridate number
#' (1 = Monday .. 7 = Sunday)
#' @noRd
.wall_week_start <- function(week_start) {
  i <- match(toupper(as.character(week_start)[1]), .WDAY_ABBR_MONFIRST)
  if (is.na(i)) {
    .stop("`week_start` must be one of: %s",
          paste(.WDAY_ABBR_MONFIRST, collapse = ", "))
  }
  i
}

#' Weekday labels starting at week_start
#' @noRd
.wall_wday_labels <- function(ws) {
  n <- length(.WDAY_ABBR_MONFIRST)
  .WDAY_ABBR_MONFIRST[((ws - 1L + seq_len(n) - 1L) %% n) + 1L]
}

#' The day layer of a calendar: pruned calendar + which timeframe is the day
#' @noRd
.wall_day_layer <- function(calendar) {
  tfs <- S7::prop(calendar, "timeframes")
  day_tf <- if ("YDAY" %in% tfs) "YDAY" else if ("MDAY" %in% tfs) "MDAY"
            else {
    .stop(paste0("wall layout needs a day-resolution timeframe (YDAY or ",
                 "MDAY); this calendar has: %s"),
          paste(tfs, collapse = ", "))
  }
  list(cal = prune_calendar(calendar, day_tf), day_tf = day_tf)
}

#' One row per day cell: timeslice, MONTH (factor), mday
#' @noRd
.wall_days <- function(day) {
  leaves <- S7::prop(day$cal, "leaftable")
  tfs    <- S7::prop(day$cal, "timeframes")

  if (day$day_tf == "MDAY") {
    months <- S7::prop(day$cal, "members")$MONTH
    month  <- factor(as.character(leaves$MONTH), levels = months)
    mday   <- as.integer(sub("^d", "", as.character(leaves$MDAY)))
  } else {
    # YDAY-only: month split from the Gregorian month-length template,
    # in fiscal order under a nontrivial year_start
    ys <- S7::prop(day$cal, "meta")$year_start %||%
      list(month = 1L, day = 1L)
    tpl <- .wall_month_template(nrow(leaves), as.integer(ys$month))
    month <- factor(tpl$month, levels = unique(tpl$month))
    mday  <- tpl$mday
  }
  data.frame(timeslice = leaves$timeslice, MONTH = month, mday = mday,
             stringsAsFactors = FALSE)
}

#' Month/mday template for an n-day stylized year starting at start_month
#' @noRd
.wall_month_template <- function(n_days, start_month = 1L) {
  lengths <- switch(as.character(n_days),
    "366" = .MONTH_LENGTHS_366,
    "360" = .MONTH_LENGTHS_360,
    .MONTH_LENGTHS_365   # 365, and 364 = the same template truncated
  )
  ord <- ((start_month - 1L + 0:11) %% 12L) + 1L
  month <- rep(sprintf("m%02d", ord), lengths[ord])
  mday  <- unlist(lapply(lengths[ord], seq_len), use.names = FALSE)
  data.frame(month = month[seq_len(n_days)], mday = mday[seq_len(n_days)],
             stringsAsFactors = FALSE)
}

#' Gregorian year of each MONTH facet, from the layout's real dates
#' (weekday mode). NA where a month has no dated cells.
#' @noRd
.wall_month_years <- function(lay) {
  vapply(split(lay$date, lay$MONTH), function(d) {
    d <- d[!is.na(d)]
    if (length(d) == 0L) NA_integer_ else as.integer(format(d[1], "%Y"))
  }, integer(1))
}

#' Month facet labeller: m01 -> JAN, or "JAN 2020" when the facet's year
#' is known -- on a fiscal wall the facets then read APR 2019 .. MAR 2020,
#' making the year rollover explicit.
#' @noRd
.wall_month_labeller <- function(years = NULL) {
  ggplot2::as_labeller(function(x) {
    i <- match(x, sprintf("m%02d", 1:12))
    lab <- ifelse(is.na(i), x, .MONTH_ABBR[i])
    if (!is.null(years)) {
      y <- years[x]
      lab <- ifelse(is.na(y), lab, paste(lab, y))
    }
    lab
  })
}

#' Aggregate `data[[z]]` into one value per day timeslice
#' @noRd
.wall_values <- function(calendar, data, z, key, fun) {
  if (!is.data.frame(data)) .stop("`data` must be a data.frame")
  data <- as.data.frame(data)
  if (!z %in% names(data)) {
    .stop("`data` has no column named `%s`", z)
  }
  day <- .wall_day_layer(calendar)
  day_leaves <- S7::prop(day$cal, "leaftable")

  if (is.null(key)) {
    key <- if ("timeslice" %in% names(data)) "timeslice"
           else {
      is_dtm <- vapply(data, inherits, logical(1),
                       what = c("POSIXt", "Date"))
      if (!any(is_dtm)) {
        .stop(paste0("`data` has no `timeslice` column and no ",
                     "POSIXct/Date column; pass `key=`"))
      }
      names(data)[which(is_dtm)[1]]
    }
  }
  if (!key %in% names(data)) {
    .stop("`data` has no column named `%s`; pass `key=`", key)
  }

  if (inherits(data[[key]], c("POSIXt", "Date"))) {
    cell <- datetime_to_timeslice(data[[key]], day$cal)
  } else {
    ids <- as.character(data[[key]])
    cell <- ifelse(ids %in% day_leaves$timeslice, ids,
                   .wall_roll_up(calendar, day, ids))
    unknown <- unique(ids[is.na(cell)])
    if (length(unknown) > 0L) {
      .warn("%d code(s) in `data$%s` are not timeslices of the calendar: %s",
            length(unknown), key, .preview(unknown))
    }
  }

  ok <- !is.na(cell) & !is.na(data[[z]])
  vapply(split(data[[z]][ok], cell[ok]), fun, numeric(1))
}

#' Map fine (sub-daily) timeslice IDs to their day cell
#' @noRd
.wall_roll_up <- function(calendar, day, ids) {
  leaves <- S7::prop(calendar, "leaftable")
  keep   <- S7::prop(day$cal, "timeframes")
  full_key <- do.call(paste, c(lapply(keep, function(tf)
    as.character(leaves[[tf]])), sep = "\r"))
  day_leaves <- S7::prop(day$cal, "leaftable")
  day_key <- do.call(paste, c(lapply(keep, function(tf)
    as.character(day_leaves[[tf]])), sep = "\r"))
  cell_of <- stats::setNames(
    day_leaves$timeslice[match(full_key, day_key)], leaves$timeslice)
  unname(cell_of[ids])
}

utils::globalVariables(c("col", "row", "value"))
