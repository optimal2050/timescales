# =============================================================================
# Internal utilities
# =============================================================================
# The .stop/.warn/.preview trio and the .check_* validators mirror
# geoscales/R/utils.R so error style is uniform across the sibling packages:
# sprintf templates, lowercase first word, no trailing period, backticked
# argument names, remedy after ";".

#' Null-coalescing operator
#' @noRd
`%||%` <- function(x, y) if (is.null(x)) y else x

#' @noRd
.stop <- function(...) {
  stop(sprintf(...), call. = FALSE)
}

#' @noRd
.warn <- function(...) {
  warning(sprintf(...), call. = FALSE)
}

#' Compact preview of a vector for messages: "a, b, c, ... (12 total)"
#' @noRd
.preview <- function(x, n = 3L) {
  if (length(x) <= n) return(paste(x, collapse = ", "))
  sprintf("%s, ... (%d total)", paste(x[seq_len(n)], collapse = ", "),
          length(x))
}

#' @noRd
.check_calendar <- function(x, arg = "calendar") {
  if (!S7::S7_inherits(x, Calendar) &&
      !inherits(x, "timescales::Calendar")) {
    .stop("`%s` must be a Calendar object", arg)
  }
  invisible(x)
}

#' The calendar's name, required by conversion routes and attachment
#'
#' `meta$name` is the calendar's identity: it keys the pairwise conversion
#' registry, the crosswalk cache, and names the label column that
#' `join_calendar()` attaches. `calendar()`/`calendar_build()` name
#' calendars automatically; only hand-built `calendar_from_leaftable()`
#' objects can end up nameless.
#' @noRd
.calendar_name <- function(cal, require = TRUE, arg = "calendar") {
  nm <- S7::prop(cal, "meta")$name %||% ""
  if (require && (!is.character(nm) || length(nm) != 1L || is.na(nm) ||
                  !nzchar(nm))) {
    .stop(paste0("`%s` has no name; conversion and attach need a named ",
                 "calendar -- set meta$name, or build it with calendar()/",
                 "calendar_build(), which name automatically"), arg)
  }
  nm
}

#' @noRd
.check_timeframe <- function(cal, timeframe, arg = "timeframe") {
  tfs <- S7::prop(cal, "timeframes")
  bad <- setdiff(timeframe, c(tfs, "ANNUAL"))
  if (length(bad) > 0L) {
    .stop(paste0("`%s` must be \"ANNUAL\" or one of the calendar's ",
                 "timeframes (%s); got %s"),
          arg, paste(tfs, collapse = ", "), .preview(bad))
  }
  invisible(timeframe)
}
