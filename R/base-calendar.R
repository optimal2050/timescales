# =============================================================================
# Base calendar — the atom layer
# =============================================================================
# The analogue of geoscales' atom rows in `@leaftable`: real POSIXct instants,
# multi-year (so leap years are representable), generated on demand and
# cached rather than stored on any object. Every `recast_calendar()` routes through
# this grid; `base_calendar()` exposes it directly for converting data
# from/to date-time form.
# =============================================================================

#' @noRd
.BASE_CACHE <- new.env(parent = emptyenv())

#' Enumerate the base instant grid for one or more years
#'
#' Returns the multi-year grid of real date-time instants that conversions
#' route through — the 1:1 correspondence between the package's calendars and
#' `POSIXct`. Each instant represents the interval `[t, t + step)`; a leap
#' year at `by = "hour"` has 8784 rows. Results are cached per
#' `(years, by, tz)`.
#'
#' @param years Integer vector of Gregorian years.
#' @param by Grid step, passed to `seq.POSIXt` (`"hour"`, `"day"`,
#'   `"15 min"`, ...). Default `"hour"`.
#' @param tz Time zone of the grid. Default `"UTC"`.
#'
#' @return A `data.frame` with columns `datetime` (POSIXct) and `year`
#'   (integer, the Gregorian year the instant belongs to).
#'
#' @examples
#' nrow(base_calendar(2020))            # 8784 (leap year)
#' nrow(base_calendar(2021))            # 8760
#' nrow(base_calendar(2019:2020, by = "day"))  # 365 + 366
#' @export
base_calendar <- function(years, by = "hour", tz = "UTC") {
  years <- as.integer(years)
  if (length(years) == 0L || anyNA(years)) {
    stop("`years` must be one or more integers", call. = FALSE)
  }
  key <- paste(paste(years, collapse = ","), by, tz, sep = "|")
  if (exists(key, envir = .BASE_CACHE, inherits = FALSE)) {
    return(get(key, envir = .BASE_CACHE, inherits = FALSE))
  }

  chunks <- lapply(years, function(y) {
    start <- as.POSIXct(sprintf("%04d-01-01 00:00:00", y), tz = tz)
    end   <- as.POSIXct(sprintf("%04d-01-01 00:00:00", y + 1L), tz = tz)
    dtm   <- seq(start, end, by = by)
    dtm   <- dtm[dtm < end]
    data.frame(datetime = dtm, year = y)
  })
  out <- do.call(rbind, chunks)
  rownames(out) <- NULL

  assign(key, out, envir = .BASE_CACHE)
  out
}

# =============================================================================
# Within-calendar aggregation and the ANNUAL root
# =============================================================================

#' Derive a coarser calendar by truncating the hierarchy at a timeframe
#'
#' Aggregates a calendar to one of its own timeframe levels: leaves are
#' grouped by the timeframes down to (and including) `timeframe`, and their
#' `share`/`weight` are summed. `timeframe = "ANNUAL"` returns the implicit
#' whole-year root — a one-timeslice calendar (the root is named `ANNUAL`, never
#' `YEAR`, which is reserved for the Gregorian-year axis).
#'
#' Together with [`recast_calendar()`]'s acceptance of a timeframe name for `to=`,
#' this covers within-calendar aggregation (e.g. `q4_h24 -> q4`) without
#' constructing a second calendar by hand.
#'
#' @param calendar A [`Calendar`].
#' @param timeframe One of `calendar`'s timeframes, or `"ANNUAL"` for the
#'   whole-year root.
#'
#' @return A [`Calendar`] whose hierarchy stops at `timeframe`.
#'
#' @examples
#' cal <- calendar_build("q4", "h24")
#' prune_calendar(cal, "QUARTER")   # 4 timeslices, shares summed over hours
#' prune_calendar(cal, "ANNUAL")    # 1 timeslice covering the year
#' @export
prune_calendar <- function(calendar, timeframe) {
  if (!S7::S7_inherits(calendar, Calendar)) {
    stop("`calendar` must be a Calendar object", call. = FALSE)
  }
  if (!is.character(timeframe) || length(timeframe) != 1L) {
    stop("`timeframe` must be a single character string", call. = FALSE)
  }

  leaves <- S7::prop(calendar, "leaftable")
  tfs    <- S7::prop(calendar, "timeframes")
  levels <- S7::prop(calendar, "members")
  meta   <- S7::prop(calendar, "meta")

  base_name <- meta$name %||% ""

  if (timeframe == "ANNUAL") {
    root <- data.frame(
      ANNUAL = "ANNUAL",
      timeslice  = "ANNUAL",
      share  = sum(leaves$share),
      weight = sum(leaves$weight),
      stringsAsFactors = FALSE
    )
    meta_out <- meta
    meta_out$name <- if (nzchar(base_name)) paste0(base_name, "@ANNUAL")
                     else "ANNUAL"
    meta_out$tokens <- NULL
    meta_out$alignment <- NULL
    return(Calendar(
      leaftable  = root,
      timeframes = "ANNUAL",
      members    = list(ANNUAL = "ANNUAL"),
      meta       = meta_out
    ))
  }

  pos <- match(timeframe, tfs)
  if (is.na(pos)) {
    stop("`timeframe` must be \"ANNUAL\" or one of the calendar's ",
         "timeframes: ", paste(tfs, collapse = ", "), call. = FALSE)
  }
  keep <- tfs[seq_len(pos)]

  # Group leaves by the kept timeframe columns; sum share and weight
  grp_key <- do.call(paste, c(lapply(keep, function(tf) leaves[[tf]]),
                              sep = "\u0001"))
  first_i <- !duplicated(grp_key)
  agg <- leaves[first_i, keep, drop = FALSE]
  agg$share  <- as.numeric(tapply(leaves$share, grp_key, sum)[grp_key[first_i]])
  agg$weight <- as.numeric(tapply(leaves$weight, grp_key,
                                  sum)[grp_key[first_i]])
  agg$timeslice  <- .make_timeslice_ids(agg, keep)

  # Order rows by the vocabulary order of the kept timeframes
  ord_rank <- Reduce(`+`, lapply(seq_along(keep), function(i) {
    later <- keep[-seq_len(i)]
    span <- prod(vapply(later, function(tf) length(levels[[tf]]), numeric(1)),
                 1)
    (match(agg[[keep[i]]], levels[[keep[i]]]) - 1) * span
  }))
  agg <- agg[order(ord_rank), , drop = FALSE]
  rownames(agg) <- NULL

  meta_out <- meta
  meta_out$name <- if (nzchar(base_name)) paste0(base_name, "@", timeframe)
                   else timeframe
  if (!is.null(meta$tokens)) {
    meta_out$tokens <- meta$tokens[intersect(names(meta$tokens), keep)]
  }
  if (!is.null(meta$alignment)) {
    meta_out$alignment <- meta$alignment[intersect(names(meta$alignment),
                                                   keep)]
    if (length(meta_out$alignment) == 0L) meta_out$alignment <- NULL
  }

  Calendar(
    leaftable  = agg,
    timeframes = keep,
    members    = levels[keep],
    meta       = meta_out
  )
}
