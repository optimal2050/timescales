# =============================================================================
# join_calendar() -- attach a calendar to a dataset
# =============================================================================
# The attachment step: adds a timeslice-label column NAMED AFTER THE CALENDAR
# (meta$name), so several calendars can live side by side on one dataset --
# and the pair of label columns is itself a direct conversion route between
# those calendars. Works from either end of the base route:
#
#   * datetime-keyed data  -> labels computed on the base grid
#   * timeslice-keyed data -> labels validated against the calendar
#
# Optional timeframe / share / weight columns come prefixed "<name>." so a
# second calendar never collides with the first. Runs as a dplyr join
# against a small in-memory frame, so any supported backend works
# (see R/backend.R).
# =============================================================================

#' Attach a calendar to a dataset
#'
#' Adds a timeslice-label column named after the calendar (its
#' `meta$name`), plus optionally the calendar's timeframe columns and
#' share/weight, all prefixed `"<name>."`. Because every calendar attaches
#' under its own name, several calendars can be joined to the same dataset
#' -- and a dataset carrying two label columns is a direct crosswalk
#' between those calendars.
#'
#' The key is auto-detected: an existing column named like the calendar is
#' used as-is; else a `timeslice` column (labels validated against the
#' calendar, with a warning for unknown codes); else a `datetime` column
#' (labels computed on the base grid via [`datetime_to_timeslice()`] --
#' this is how a calendar is attached to raw datetime observations).
#' Existing columns are never overwritten; the join errors instead.
#'
#' @param x The dataset, in any supported backend (see
#'   [`recast_calendar()`]'s Backends section).
#' @param calendar A named [`Calendar`].
#' @param key Key column of `x`: a timeslice-label column, or a POSIXct
#'   datetime column. `NULL` (default) auto-detects as described above.
#' @param timeframes Character vector of the calendar's timeframes to
#'   attach as `"<name>.<TIMEFRAME>"` columns (default: none). `TRUE`
#'   attaches all of them.
#' @param meta Attach `"<name>.share"` and `"<name>.weight"` columns
#'   (default `FALSE`).
#' @param as_factor Attach timeframe columns as vocabulary-ordered factors
#'   (default `TRUE`) or plain character. (Lazy backends store them as
#'   dictionary/character columns.)
#' @param year Model year(s) for the base grid when attaching by datetime.
#'   Default: the span of years observed in the data, padded one year each
#'   side.
#' @param by,tz Base-grid resolution and time zone for the datetime route,
#'   as in [`expand_calendar()`].
#' @param collect For lazy inputs: materialise (`TRUE`) or return the
#'   query (default).
#'
#' @return `x` with the new column(s) appended, in the input's class
#'   (lazy in, lazy out).
#'
#' @examples
#' cal <- calendar("m12_h24")
#' x <- data.frame(timeslice = S7::prop(cal, "leaftable")$timeslice, load = 1)
#' head(join_calendar(x, cal))                    # adds `m12_h24`
#' head(join_calendar(x, cal, timeframes = TRUE)) # + m12_h24.MONTH, ...
#'
#' # two calendars on one dataset = a direct crosswalk between them
#' xt <- data.frame(datetime = seq(as.POSIXct("2021-01-01", tz = "UTC"),
#'                                 by = "hour", length.out = 48), v = 1)
#' xt <- join_calendar(xt, calendar("m12_h24"))
#' xt <- join_calendar(xt, calendar("q4_h24"))
#' head(xt)
#' @export
join_calendar <- function(x, calendar, key = NULL, timeframes = NULL,
                          meta = FALSE, as_factor = TRUE,
                          year = NULL, by = NULL, tz = "UTC",
                          collect = NULL) {
  backend <- .ts_backend(x)
  if (is.na(backend)) {
    .stop(paste0("`x` must be a data.frame, tibble, data.table, or an ",
                 "arrow table/dataset/query"))
  }
  .check_calendar(calendar)
  cal_nm <- .calendar_name(calendar)
  schema <- .ts_schema(x)

  leaves <- S7::prop(calendar, "leaftable")
  tfs    <- S7::prop(calendar, "timeframes")
  levels <- S7::prop(calendar, "members")

  # -- resolve the key and the attach mode ------------------------------------
  if (is.null(key)) {
    key <- if (cal_nm %in% names(schema)) cal_nm
           else if ("timeslice" %in% names(schema)) "timeslice"
           else if ("datetime" %in% names(schema)) "datetime"
           else .stop(paste0("`x` has no `%s`, `timeslice`, or `datetime` ",
                             "column; pass `key=`"), cal_nm)
  }
  if (!key %in% names(schema)) {
    .stop("`x` has no column named `%s`; pass `key=`", key)
  }
  dtm_route <- inherits(schema[[key]], c("POSIXct", "POSIXt", "Date"))

  # -- what gets attached -----------------------------------------------------
  if (isTRUE(timeframes)) timeframes <- tfs
  if (!is.null(timeframes) && !isFALSE(timeframes)) {
    bad <- setdiff(timeframes, tfs)
    if (length(bad) > 0L) {
      .stop("not timeframes of this calendar: %s", .preview(bad))
    }
  } else {
    timeframes <- character(0)
  }
  new_cols <- c(if (key != cal_nm) cal_nm,
                paste0(cal_nm, ".", timeframes),
                if (isTRUE(meta)) paste0(cal_nm, c(".share", ".weight")))
  clash <- intersect(new_cols, names(schema))
  if (length(clash) > 0L) {
    .stop(paste0("attaching calendar \"%s\" would overwrite existing ",
                 "column(s): %s"), cal_nm, .preview(clash))
  }
  if (length(new_cols) == 0L) {
    return(x)   # label column already there, nothing else requested
  }

  # -- the in-memory attach frame ---------------------------------------------
  attach_df <- data.frame(.ts_label = leaves$timeslice,
                          stringsAsFactors = FALSE)
  for (tf in timeframes) {
    col <- leaves[[tf]]
    attach_df[[paste0(cal_nm, ".", tf)]] <-
      if (as_factor) factor(col, levels = levels[[tf]]) else col
  }
  if (isTRUE(meta)) {
    attach_df[[paste0(cal_nm, ".share")]]  <- leaves$share
    attach_df[[paste0(cal_nm, ".weight")]] <- leaves$weight
  }

  xq <- .ts_lazy(x, backend)

  if (dtm_route) {
    # datetime -> label via the base grid
    if (is.null(year)) {
      yy <- .ts_pull(
        xq |>
          dplyr::mutate(.ts_y = lubridate::year(!!rlang::sym(key))) |>
          dplyr::summarise(mn = min(.ts_y), mx = max(.ts_y)))
      year <- (as.integer(yy$mn[1]) - 1L):(as.integer(yy$mx[1]) + 1L)
    }
    grid <- expand_calendar(calendar, as.integer(year), by = by, tz = tz)
    grid <- grid[, c("datetime", "timeslice")]
    names(grid) <- c(key, ".ts_label")
    out <- dplyr::left_join(xq, grid, by = key, na_matches = "na")
  } else {
    # label-keyed: validate and (if needed) copy under the calendar's name
    keys <- .ts_pull(
      dplyr::distinct(dplyr::select(xq, dplyr::all_of(key))))[[key]]
    keys <- unique(stats::na.omit(as.character(keys)))
    if (!any(keys %in% leaves$timeslice)) {
      .stop("no rows of `x` matched the calendar's timeslices; check `key=`")
    }
    unknown <- setdiff(keys, leaves$timeslice)
    if (length(unknown) > 0L) {
      .warn("%d code(s) in `x$%s` are not timeslices of the calendar: %s",
            length(unknown), key, .preview(unknown))
    }
    lab_map <- data.frame(k = leaves$timeslice,
                          .ts_label = leaves$timeslice,
                          stringsAsFactors = FALSE)
    names(lab_map)[1] <- key
    out <- dplyr::left_join(xq, lab_map, by = key, na_matches = "na")
  }

  if (ncol(attach_df) > 1L) {
    out <- dplyr::left_join(out, attach_df, by = ".ts_label",
                            na_matches = "na")
  }
  if (key != cal_nm) {
    out <- dplyr::rename(out, !!rlang::sym(cal_nm) := !!rlang::sym(".ts_label"))
  } else {
    out <- dplyr::select(out, -dplyr::all_of(".ts_label"))
  }
  .ts_restore(out, backend, collect = collect)
}
