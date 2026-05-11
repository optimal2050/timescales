# =============================================================================
# Datetime <-> slice conversions and calendar expansion
# =============================================================================
# Three building blocks that together cover goal #2 ("logic"):
#
#   instant_to_slice(dtm, cal)        datetime vector -> slice IDs
#   expand_calendar(cal, year, by)    enumerate every instant in a year ->
#                                     data.frame(datetime, slice, ...tokens...)
#   recast(x, from, to, ...)          value-on-slice-in-A -> value-on-slice-in-B
#
# These compose into the central `recast()` operation. Typed Instant/Interval
# wrappers are deferred to v0.2 per the design plan; here, datetime is plain
# POSIXct and a slice is a plain character vector accompanied by its Calendar.
# =============================================================================

# -----------------------------------------------------------------------------
# instant_to_slice()
# -----------------------------------------------------------------------------

#' Map datetimes to calendar slice IDs
#'
#' Extracts each calendar timeframe's token from `dtm` using [`as_timeframe()`]
#' and looks the resulting tuple up in `calendar@leaves`. Datetimes that
#' produce a tuple not present in the calendar return `NA`.
#'
#' @param dtm A `POSIXct`/`POSIXlt`/`Date` vector.
#' @param calendar A [`Calendar`].
#'
#' @return A character vector of slice IDs the same length as `dtm`.
#'
#' @examples
#' df <- data.frame(
#'   MONTH  = sprintf("m%02d", 1:12),
#'   share  = c(31,28,31,30,31,30,31,31,30,31,30,31) / 365,
#'   weight = c(31,28,31,30,31,30,31,31,30,31,30,31)
#' )
#' cal <- calendar_from_leaves(df, timeframes = "MONTH", name = "m12")
#' instant_to_slice(lubridate::ymd(c("2020-01-15", "2020-07-04")), cal)
#' @export
instant_to_slice <- function(dtm, calendar) {
  if (!inherits(calendar, "timescales::Calendar") &&
      !S7::S7_inherits(calendar, Calendar)) {
    stop("`calendar` must be a Calendar object", call. = FALSE)
  }

  tfs    <- S7::prop(calendar, "timeframes")
  leaves <- S7::prop(calendar, "leaves")

  # Build the tuple key for `dtm` (one column per timeframe, token format)
  dtm_keys <- vapply(
    tfs,
    function(tf) as_timeframe(dtm, tf, format = "token"),
    character(length(dtm))
  )
  if (length(dtm) == 1L) dtm_keys <- matrix(dtm_keys, nrow = 1L)
  if (!is.matrix(dtm_keys)) dtm_keys <- matrix(dtm_keys, ncol = length(tfs))
  dtm_key <- apply(dtm_keys, 1L, paste, collapse = "\u0001")

  # Build the same key from leaves
  leaf_key <- do.call(paste,
    c(lapply(tfs, function(tf) as.character(leaves[[tf]])), sep = "\u0001"))

  out <- leaves$slice[match(dtm_key, leaf_key)]
  out
}

# -----------------------------------------------------------------------------
# expand_calendar()
# -----------------------------------------------------------------------------

#' Enumerate every instant in a year mapped to its calendar slice
#'
#' Returns a `data.frame` with one row per instant in the requested year at
#' the requested resolution, plus a `slice` column giving the calendar slice
#' that instant belongs to (via [`instant_to_slice()`]). This is the ground
#' truth used by [`recast()`].
#'
#' @param calendar A [`Calendar`].
#' @param year Integer scalar — the Gregorian year to enumerate.
#' @param by Resolution string passed to `seq.POSIXt`'s `by` argument
#'   (`"hour"`, `"day"`, `"15 min"`, ...). Defaults to `"hour"` if `HOUR` is
#'   in the calendar's timeframes, otherwise `"day"`.
#' @param tz Time zone string. Defaults to `"UTC"`.
#'
#' @return A `data.frame` with columns `datetime` (POSIXct) and `slice`
#'   (character). Rows where `slice` is `NA` correspond to instants the
#'   calendar does not cover (e.g. Feb 29 in a 365-day calendar).
#'
#' @examples
#' df <- data.frame(
#'   MONTH  = sprintf("m%02d", 1:12),
#'   share  = c(31,28,31,30,31,30,31,31,30,31,30,31) / 365,
#'   weight = c(31,28,31,30,31,30,31,31,30,31,30,31)
#' )
#' cal <- calendar_from_leaves(df, timeframes = "MONTH", name = "m12")
#' grid <- expand_calendar(cal, year = 2021, by = "month")
#' head(grid)
#' @export
expand_calendar <- function(calendar, year, by = NULL, tz = "UTC") {
  if (!S7::S7_inherits(calendar, Calendar)) {
    stop("`calendar` must be a Calendar object", call. = FALSE)
  }
  year <- as.integer(year)
  if (length(year) != 1L || is.na(year)) {
    stop("`year` must be a single integer", call. = FALSE)
  }

  tfs <- S7::prop(calendar, "timeframes")
  if (is.null(by)) {
    by <- if ("MINUTE" %in% tfs) "min"
          else if ("HOUR" %in% tfs) "hour"
          else "day"
  }

  start <- as.POSIXct(sprintf("%04d-01-01 00:00:00", year), tz = tz)
  end   <- as.POSIXct(sprintf("%04d-12-31 23:59:59", year), tz = tz)
  dtm   <- seq(start, end, by = by)

  data.frame(
    datetime = dtm,
    slice    = instant_to_slice(dtm, calendar),
    stringsAsFactors = FALSE
  )
}

# -----------------------------------------------------------------------------
# recast()
# -----------------------------------------------------------------------------

#' Recast values from one calendar to another
#'
#' The central conversion verb. Takes a `data.frame` keyed by slice in
#' calendar `from` with one or more numeric value columns, and returns a
#' `data.frame` keyed by slice in calendar `to`. Conversion goes through a
#' shared instant grid built by [`expand_calendar()`] for the given `year`.
#'
#' @param x `data.frame` with a column named by `key` (default `"slice"`)
#'   plus one or more numeric value columns.
#' @param from Source [`Calendar`].
#' @param to Destination [`Calendar`].
#' @param year Integer scalar Gregorian year used to materialise both
#'   calendars on a shared grid.
#' @param key Name of the slice key column in `x`. Default `"slice"`.
#' @param values Character vector of value columns to transform. Default:
#'   all numeric columns other than `key`.
#' @param rule Aggregation rule for many-source-instants-per-target-slice
#'   (downsampling). One of:
#'   * `"weighted_mean"` — share-weighted mean (default; physical units like
#'     average load).
#'   * `"sum"` — sum (extensive quantities like total energy).
#'   * `"mean"` — unweighted mean.
#' @param by Grid resolution for [`expand_calendar()`]. Defaults to the
#'   finest of the two calendars.
#' @param tz Time zone for the shared grid. Default `"UTC"`.
#'
#' @return A `data.frame` keyed by slice in `to`, with one row per slice in
#'   `to` and the same value columns as in `x`.
#'
#' @details
#' Algorithm:
#' 1. Expand both calendars onto a shared instant grid for `year`.
#' 2. Join `x` onto the grid via `from$slice`, broadcasting each source
#'    slice's value to every grid instant it covers.
#' 3. Group by `to$slice` and aggregate per `rule`.
#'
#' Instants present in one calendar but not the other (e.g. Feb 29) drop out
#' silently for now (will be configurable in a later phase).
#'
#' @examples
#' month_df <- data.frame(
#'   MONTH  = sprintf("m%02d", 1:12),
#'   share  = c(31,28,31,30,31,30,31,31,30,31,30,31) / 365,
#'   weight = c(31,28,31,30,31,30,31,31,30,31,30,31)
#' )
#' cal_m <- calendar_from_leaves(month_df, timeframes = "MONTH", name = "m12")
#'
#' quarter_df <- data.frame(
#'   QUARTER = sprintf("Q%d", 1:4),
#'   share   = c(90, 91, 92, 92) / 365,
#'   weight  = c(90, 91, 92, 92)
#' )
#' cal_q <- calendar_from_leaves(quarter_df, timeframes = "QUARTER",
#'                               name = "q4")
#'
#' x <- data.frame(
#'   slice = sprintf("m%02d", 1:12),
#'   load  = seq(100, 210, length.out = 12)
#' )
#' recast(x, from = cal_m, to = cal_q, year = 2021, rule = "weighted_mean")
#' @export
recast <- function(x, from, to, year,
                   key = "slice",
                   values = NULL,
                   rule = c("weighted_mean", "sum", "mean"),
                   by = NULL,
                   tz = "UTC") {
  rule <- match.arg(rule)

  if (!is.data.frame(x)) {
    stop("`x` must be a data.frame", call. = FALSE)
  }
  if (!key %in% names(x)) {
    stop(sprintf("`x` has no column named `%s`", key), call. = FALSE)
  }
  if (!S7::S7_inherits(from, Calendar) || !S7::S7_inherits(to, Calendar)) {
    stop("`from` and `to` must be Calendar objects", call. = FALSE)
  }

  if (is.null(values)) {
    candidates <- setdiff(names(x), key)
    values <- candidates[vapply(x[candidates], is.numeric, logical(1))]
    if (length(values) == 0L) {
      stop("No numeric value columns found in `x`. Specify `values=`.",
           call. = FALSE)
    }
  } else if (!all(values %in% names(x))) {
    stop("Some `values` columns are not in `x`: ",
         paste(setdiff(values, names(x)), collapse = ", "),
         call. = FALSE)
  }

  # Default grid resolution = finer of the two calendars
  if (is.null(by)) {
    tfs <- union(S7::prop(from, "timeframes"), S7::prop(to, "timeframes"))
    by <- if ("MINUTE" %in% tfs) "min"
          else if ("HOUR" %in% tfs) "hour"
          else "day"
  }

  # Materialise the shared instant grid
  start <- as.POSIXct(sprintf("%04d-01-01 00:00:00", as.integer(year)), tz = tz)
  end   <- as.POSIXct(sprintf("%04d-12-31 23:59:59", as.integer(year)), tz = tz)
  dtm   <- seq(start, end, by = by)

  s_from <- instant_to_slice(dtm, from)
  s_to   <- instant_to_slice(dtm, to)

  # Drop instants not covered by either calendar
  ok <- !is.na(s_from) & !is.na(s_to)
  s_from <- s_from[ok]
  s_to   <- s_to[ok]

  # Look up x values for each grid instant
  xi <- match(s_from, x[[key]])
  if (anyNA(xi)) {
    missing_slices <- setdiff(unique(s_from), x[[key]])
    if (length(missing_slices) > 0L) {
      warning(sprintf(
        "%d source slice(s) present on the grid but missing from `x` (e.g. %s); produced NAs.",
        length(missing_slices),
        paste(utils::head(missing_slices, 3L), collapse = ", ")),
        call. = FALSE)
    }
  }

  # For each value column, aggregate by destination slice
  out <- data.frame(slice = S7::prop(to, "leaves")$slice,
                    stringsAsFactors = FALSE)
  names(out) <- key

  for (v in values) {
    vals <- x[[v]][xi]
    out[[v]] <- .aggregate_by(vals, key_to = s_to, rule = rule,
                              target_keys = out[[key]])
  }
  out
}

# Internal: aggregate `values` indexed by `key_to`, producing one number per
# `target_keys` (in order). Slices in `target_keys` with no contributing
# instants get NA.
#' @noRd
.aggregate_by <- function(values, key_to, rule, target_keys) {
  if (length(values) == 0L) {
    return(rep(NA_real_, length(target_keys)))
  }
  if (rule == "sum") {
    agg <- tapply(values, key_to, sum, na.rm = FALSE)
  } else if (rule == "mean" || rule == "weighted_mean") {
    # On a uniform-step grid, weighted_mean and unweighted mean coincide,
    # because each instant carries equal weight. They differ only once we
    # support non-uniform grids (deferred).
    agg <- tapply(values, key_to, mean, na.rm = FALSE)
  } else {
    stop("Unknown rule: ", rule, call. = FALSE)
  }
  out <- as.numeric(agg[target_keys])
  names(out) <- NULL
  out
}
