# =============================================================================
# Calendar constructors
# =============================================================================
# `calendar_from_leaves()` is the layer-3 escape hatch: full flexibility,
# no token catalog, no name-based shortcut. Anything expressible as a
# weighted leaf table with a hierarchy is a valid calendar.
#
# Higher-level constructors (`calendar()` by name, `calendar_build()` by
# tokens) will be layered on top of this in Phase 1.2.
# =============================================================================

#' Build a Calendar from a flat table of leaf slices
#'
#' This is the most general way to construct a [`Calendar`]: provide the leaf
#' slices directly as a `data.frame`, name the timeframe columns, and
#' optionally pin down the per-timeframe vocabulary and model-level metadata.
#'
#' @param leaves A `data.frame` with one row per leaf slice. Must contain:
#'   * one column per timeframe named in `timeframes`
#'   * `share` — numeric > 0; sums to `year_fraction`
#'   * `weight` — numeric >= 0; user-defined importance weight
#'   * (optional) `slice` — unique character ID; auto-generated if missing
#' @param timeframes Ordered character vector of timeframe names (coarsest
#'   first). Each must appear as a column in `leaves`.
#' @param levels Optional named list giving the full ordered token set per
#'   timeframe. If `NULL`, derived from `unique(leaves[[tf]])` in
#'   first-appearance order.
#' @param name,desc Calendar name and free-text description.
#' @param year_start `list(month = , day = )`; defaults to January 1.
#' @param utc_offset_minutes Integer minutes; model-local time = UTC + offset.
#' @param year_fraction Fraction of a year covered by `sum(leaves$share)`.
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
#' cal <- calendar_from_leaves(df, timeframes = "MONTH", name = "m12")
#' cal
#' @export
calendar_from_leaves <- function(leaves,
                                 timeframes,
                                 levels = NULL,
                                 name = "",
                                 desc = "",
                                 year_start = list(month = 1L, day = 1L),
                                 utc_offset_minutes = 0L,
                                 year_fraction = 1,
                                 ...) {
  if (!is.data.frame(leaves)) {
    stop("`leaves` must be a data.frame", call. = FALSE)
  }
  if (!is.character(timeframes) || length(timeframes) == 0L) {
    stop("`timeframes` must be a non-empty character vector", call. = FALSE)
  }
  missing_cols <- setdiff(timeframes, names(leaves))
  if (length(missing_cols) > 0L) {
    stop("`leaves` is missing timeframe columns: ",
         paste(missing_cols, collapse = ", "), call. = FALSE)
  }

  # Coerce timeframe columns to character (tokens are character by convention)
  for (tf in timeframes) {
    leaves[[tf]] <- as.character(leaves[[tf]])
  }

  # Auto-generate `slice` if absent
  if (!"slice" %in% names(leaves)) {
    leaves$slice <- .make_slice_ids(leaves, timeframes)
  } else {
    leaves$slice <- as.character(leaves$slice)
  }

  if (!"share" %in% names(leaves)) {
    stop("`leaves` is missing required column `share`", call. = FALSE)
  }
  if (!"weight" %in% names(leaves)) {
    leaves$weight <- as.numeric(leaves$share) * 8760  # default: hours-per-year
  }

  # Build levels in first-appearance order if not supplied
  if (is.null(levels)) {
    levels <- lapply(stats::setNames(timeframes, timeframes),
                     function(tf) unique(leaves[[tf]]))
  } else {
    if (!is.list(levels) || is.null(names(levels))) {
      stop("`levels` must be a named list (one entry per timeframe)",
           call. = FALSE)
    }
    # Fill in any missing timeframes from the data
    for (tf in setdiff(timeframes, names(levels))) {
      levels[[tf]] <- unique(leaves[[tf]])
    }
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
    leaves     = leaves,
    timeframes = timeframes,
    levels     = levels,
    meta       = meta
  )
}

# Internal: build composite slice IDs from a row's timeframe columns -----------
#' @noRd
.make_slice_ids <- function(df, timeframes) {
  parts <- lapply(timeframes, function(tf) as.character(df[[tf]]))
  if (length(parts) == 1L) return(parts[[1]])
  do.call(paste, c(parts, sep = "_"))
}
