# =============================================================================
# Calendar constructors
# =============================================================================
# `calendar_from_leaftable()` is the layer-3 escape hatch: full flexibility,
# no token catalog, no name-based shortcut. Anything expressible as a
# weighted leaf table with a hierarchy is a valid calendar.
#
# Higher-level constructors (`calendar()` by name, `calendar_build()` by
# tokens) will be layered on top of this in Phase 1.2.
# =============================================================================

#' Build a Calendar from a flat table of leaf timeslices
#'
#' This is the most general way to construct a [`Calendar`]: provide the leaf
#' timeslices directly as a `data.frame`, name the timeframe columns, and
#' optionally pin down the per-timeframe vocabulary and model-level metadata.
#'
#' @param leaftable A `data.frame` with one row per leaf timeslice. Must contain:
#'   * one column per timeframe named in `timeframes`
#'   * `share` — numeric > 0; sums to `year_fraction`
#'   * `weight` — numeric >= 0; user-defined importance weight
#'   * (optional) `timeslice` — unique character ID; auto-generated if missing
#' @param timeframes Ordered character vector of timeframe names (coarsest
#'   first). Each must appear as a column in `leaftable`.
#' @param members Optional named list giving the full ordered member set per
#'   timeframe. If `NULL`, derived from `unique(leaftable[[tf]])` in
#'   first-appearance order.
#' @param name,desc Calendar name and free-text description.
#' @param year_start `list(month = , day = )`; defaults to January 1.
#' @param utc_offset_minutes Integer minutes; model-local time = UTC + offset.
#' @param year_fraction Fraction of a year covered by `sum(leaftable$share)`.
#'   Defaults to `1`.
#' @param ... Additional named entries appended to `meta` (free-form).
#'
#' @return A [`Calendar`] object.
#'
#' @examples
#' # A trivial monthly calendar with weights = days in month (non-leap year)
#' df <- data.frame(
#'   MONTH  = sprintf("m%02d", 1:12),
#'   share  = c(31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31) / 365,
#'   weight = c(31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31)
#' )
#' cal <- calendar_from_leaftable(df, timeframes = "MONTH", name = "m12")
#' cal
#' @export
calendar_from_leaftable <- function(leaftable,
                                 timeframes,
                                 members = NULL,
                                 name = "",
                                 desc = "",
                                 year_start = list(month = 1L, day = 1L),
                                 utc_offset_minutes = 0L,
                                 year_fraction = 1,
                                 ...) {
  if (!is.data.frame(leaftable)) {
    stop("`leaftable` must be a data.frame", call. = FALSE)
  }
  if (!is.character(timeframes) || length(timeframes) == 0L) {
    stop("`timeframes` must be a non-empty character vector", call. = FALSE)
  }
  missing_cols <- setdiff(timeframes, names(leaftable))
  if (length(missing_cols) > 0L) {
    stop("`leaftable` is missing timeframe columns: ",
         paste(missing_cols, collapse = ", "), call. = FALSE)
  }

  # Coerce timeframe columns to character (tokens are character by convention)
  for (tf in timeframes) {
    leaftable[[tf]] <- as.character(leaftable[[tf]])
  }

  # Auto-generate `timeslice` if absent
  if (!"timeslice" %in% names(leaftable)) {
    leaftable$timeslice <- .make_timeslice_ids(leaftable, timeframes)
  } else {
    leaftable$timeslice <- as.character(leaftable$timeslice)
  }

  if (!"share" %in% names(leaftable)) {
    stop("`leaftable` is missing required column `share`", call. = FALSE)
  }
  if (!"weight" %in% names(leaftable)) {
    leaftable$weight <- as.numeric(leaftable$share) * 8760  # default: hours-per-year
  }

  # Build members in first-appearance order if not supplied
  if (is.null(members)) {
    members <- lapply(stats::setNames(timeframes, timeframes),
                     function(tf) unique(leaftable[[tf]]))
  } else {
    if (!is.list(members) || is.null(names(members))) {
      stop("`members` must be a named list (one entry per timeframe)",
           call. = FALSE)
    }
    # Fill in any missing timeframes from the data
    for (tf in setdiff(timeframes, names(members))) {
      members[[tf]] <- unique(leaftable[[tf]])
    }
  }

  extra_names <- names(list(...))
  if (any(c("leaves", "levels") %in% extra_names)) {
    stop("arguments `leaves`/`levels` were renamed `leaftable`/`members` ",
         "(2026-08 lattice); update the call or use the deprecated ",
         "calendar_from_leaves()", call. = FALSE)
  }
  meta <- list(
    name               = as.character(name),
    desc               = as.character(desc),
    year_start         = year_start,
    utc_offset_minutes = as.integer(utc_offset_minutes),
    year_fraction      = as.numeric(year_fraction)
  )
  extra <- list(...)
  if (length(extra) > 0L) meta <- utils::modifyList(meta, extra)

  Calendar(
    leaftable     = leaftable,
    timeframes = timeframes,
    members     = members,
    meta       = meta
  )
}

# Internal: build composite timeslice IDs from a row's timeframe columns -----------
#' @noRd
.make_timeslice_ids <- function(df, timeframes) {
  parts <- lapply(timeframes, function(tf) as.character(df[[tf]]))
  if (length(parts) == 1L) return(parts[[1]])
  do.call(paste, c(parts, sep = "_"))
}
