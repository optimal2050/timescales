# =============================================================================
# Deprecated names
# =============================================================================
# Renamed 2026-08 under the harmonized *scales convention: verb_class for
# data operations and object transforms (recast_calendar, join_calendar,
# prune_calendar), class-prefixed nouns for properties and queries.
# These aliases warn and forward; they will be removed before 1.0.

#' Deprecated timescales functions
#'
#' These functions were renamed under the harmonized naming convention
#' shared with the geoscales package: operations on data and object
#' transforms are `verb_calendar()`, properties and queries are
#' `calendar_*()`. The old names warn and forward to their replacements;
#' they will be removed before the 1.0 release.
#'
#' * `calendar_recast()` -> [recast_calendar()] (or the [recast()]
#'   generic)
#' * `calendar_join()` -> [join_calendar()]
#' * `calendar_at_level()` -> [prune_calendar()]
#' * `instant_to_timeslice()` -> [datetime_to_timeslice()] ("instant"
#'   retired from the public vocabulary: the column is `datetime`, the
#'   grid is the base calendar)
#' * `instant_to_slice()` -> [datetime_to_timeslice()]
#'
#' @param ... Arguments forwarded to the replacement function.
#' @return See the replacement function.
#' @name timescales-deprecated
#' @keywords internal
NULL

#' @rdname timescales-deprecated
#' @export
calendar_recast <- function(...) {
  .Deprecated("recast_calendar")
  recast_calendar(...)
}

#' @rdname timescales-deprecated
#' @export
calendar_join <- function(...) {
  .Deprecated("join_calendar")
  join_calendar(...)
}

#' @rdname timescales-deprecated
#' @export
calendar_at_level <- function(...) {
  .Deprecated("prune_calendar")
  prune_calendar(...)
}

#' @rdname timescales-deprecated
#' @export
instant_to_timeslice <- function(...) {
  .Deprecated("datetime_to_timeslice")
  datetime_to_timeslice(...)
}

#' @rdname timescales-deprecated
#' @export
instant_to_slice <- function(...) {
  .Deprecated("datetime_to_timeslice")
  datetime_to_timeslice(...)
}

#' @rdname timescales-deprecated
#' @export
calendar_from_leaves <- function(leaves, timeframes, levels = NULL, ...) {
  .Deprecated("calendar_from_leaftable")
  calendar_from_leaftable(leaftable = leaves, timeframes = timeframes,
                          members = levels, ...)
}
