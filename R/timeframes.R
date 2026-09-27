# =============================================================================
# TIMEFRAME EXTRACTION FROM DATETIME VECTORS
# =============================================================================
# Extract individual timeframe components (YEAR, MONTH, HOUR, ...) from
# datetime vectors using standard `lubridate` conventions. When a `Calendar`
# is involved (later layers), calendar-specific conventions can override
# these defaults.
# =============================================================================

#' Core timeframe identifiers
#'
#' Standard timeframe names used for datetime component extraction.
#' These correspond to hierarchical time divisions from years down to seconds,
#' plus week-related axes.
#'
#' @format Character vector of timeframe names.
#' @export
CORE_TIMEFRAMES <- c(
  "YEAR",    # Calendar year (e.g. 2020, 2021)
  "QUARTER", # Quarter of year (1-4)
  "MONTH",   # Month of year (1-12)
  "MDAY",    # Day of month (1-31)
  "YDAY",    # Day of year (1-366)
  "HOUR",    # Hour of day (0-23)
  "MINUTE",  # Minute of hour (0-59)
  "SECOND",  # Second of minute (0-59)
  "WDAY",    # Day of week (1-7; numbering depends on `week_start`)
  "WHOUR",   # Hour of week (0-167, Monday-first ISO)
  "MWEEK",   # Week of month (1-5, calendar-grid aligned to WDAY)
  "WEEK",    # Week of year (1-53)
  "SEASON",  # Meteorological season (1-4: WIN=Dec-Feb, SPR, SUM, FAL)
  "DAYTYPE", # Day type (1-2: WORKDAY=Mon-Fri, WEEKEND)
  "HOURTYPE" # Hour type (1-3: DAY, NIGHT=h22-h05, PEAK=h17-h20)
)

# Enum label sets for the derived type axes. The numeric codes returned by
# the extractors index these vectors, so token vocabularies in this order
# work with the positional fallback in datetime_to_timeslice().
.SEASON_LABELS   <- c("WIN", "SPR", "SUM", "FAL")
.DAYTYPE_LABELS  <- c("WORKDAY", "WEEKEND")
.HOURTYPE_LABELS <- c("DAY", "NIGHT", "PEAK")

# Internal: lubridate-based extractors -----------------------------------------
.TIMEFRAME_EXTRACTORS <- list(
  YEAR    = lubridate::year,
  QUARTER = lubridate::quarter,
  MONTH   = lubridate::month,
  MDAY    = lubridate::mday,
  YDAY    = lubridate::yday,
  HOUR    = lubridate::hour,
  MINUTE  = lubridate::minute,
  SECOND  = lubridate::second,
  WDAY    = function(x, week_start = NULL, ...) {
    if (is.null(week_start)) lubridate::wday(x)
    else lubridate::wday(x, week_start = week_start)
  },
  WEEK    = lubridate::week,
  WHOUR   = function(x, ...) {
    # Hour of week, Monday-first ISO: Mon 00:00 -> 0, Sun 23:00 -> 167.
    (lubridate::wday(x, week_start = 1) - 1L) * 24L + lubridate::hour(x)
  },
  SEASON  = function(x, ...) {
    # Meteorological seasons: WIN = Dec-Feb, SPR = Mar-May, ...
    c(1L, 1L, 2L, 2L, 2L, 3L, 3L, 3L, 4L, 4L, 4L, 1L)[lubridate::month(x)]
  },
  DAYTYPE = function(x, ...) {
    ifelse(lubridate::wday(x, week_start = 1) <= 5L, 1L, 2L)
  },
  HOURTYPE = function(x, ...) {
    # DAY = 1 (default), NIGHT = 2 (h22-h05), PEAK = 3 (h17-h20)
    h <- lubridate::hour(x)
    ifelse(h >= 17L & h <= 20L, 3L, ifelse(h >= 22L | h <= 5L, 2L, 1L))
  },
  MWEEK   = function(x, week_start = NULL, ...) {
    # Calendar-grid week-of-month, aligned to WDAY:
    #   MWEEK = floor((MDAY + WDAY(first_of_month) - 2) / 7) + 1
    d <- lubridate::mday(x)
    first <- lubridate::floor_date(x, unit = "month")
    w1 <- if (is.null(week_start)) lubridate::wday(first)
          else lubridate::wday(first, week_start = week_start)
    ((d + w1 - 2) %/% 7) + 1
  }
)

# Internal: token formatters (aligned with timeslices/templates.yml) -----------
.TIMEFRAME_FORMATTERS <- list(
  YEAR    = function(x) sprintf("y%04d", x),
  QUARTER = function(x) sprintf("Q%01d", x),
  MONTH   = function(x) sprintf("m%02d", x),
  MDAY    = function(x) sprintf("d%02d", x),
  YDAY    = function(x) sprintf("d%03d", x),
  HOUR    = function(x) sprintf("h%02d", x),
  MINUTE  = function(x) sprintf("min%02d", x),
  SECOND  = function(x) sprintf("sec%02d", as.integer(x)),
  WDAY    = function(x) c("SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT")[x],
  WHOUR   = function(x) sprintf("h%03d", x),
  SEASON  = function(x) .SEASON_LABELS[x],
  DAYTYPE = function(x) .DAYTYPE_LABELS[x],
  HOURTYPE = function(x) .HOURTYPE_LABELS[x],
  MWEEK   = function(x) sprintf("mw%02d", x),
  WEEK    = function(x) sprintf("w%02d", x)
)

# Internal: first integer of each timeframe's vocabulary ----------------------
# A calendar stores each timeframe's labels in vocabulary order (`members`), so
# a label's ordinal position plus this origin is its numeric value. `NA` marks
# a timeframe whose values are absolute, not ordinal: there is no such mapping.
#
# WDAY's vocabulary is ISO (Monday first) -- `week_start = 1` on the datetime
# path, NOT lubridate's Sunday-first default that .TIMEFRAME_FORMATTERS
# follows. The two conventions differ by one.
.TIMEFRAME_ORIGIN <- c(
  YEAR     = NA_integer_,
  QUARTER  = 1L,
  MONTH    = 1L,
  MDAY     = 1L,
  YDAY     = 1L,
  HOUR     = 0L,
  MINUTE   = 0L,
  SECOND   = 0L,
  WDAY     = 1L,
  WHOUR    = 0L,
  MWEEK    = 1L,
  WEEK     = 1L,
  SEASON   = 1L,
  DAYTYPE  = 1L,
  HOURTYPE = 1L
)

#' Extract timeframe values from datetime vectors
#'
#' Extracts a single timeframe component (`YEAR`, `MONTH`, `HOUR`, ...) from a
#' `Date`, `POSIXct`, or `POSIXlt` vector, optionally formatted as a token
#' string.
#'
#' @param x A datetime vector (`Date`, `POSIXct`, or `POSIXlt`).
#' @param timeframe Character scalar naming the timeframe to extract;
#'   one of [`CORE_TIMEFRAMES`].
#' @param format `"numeric"` (default) for raw integer values, or `"token"`
#'   for formatted strings (`"m01"`, `"h00"`, `"d365"`, `"MON"`, ...).
#' @param ... Currently `week_start` is forwarded to `lubridate::wday()` for
#'   `WDAY` and `MWEEK`. Token vocabularies such as `wd7` are ISO (Monday
#'   first), so pair them with `week_start = 1`; the default is lubridate's
#'   (Sunday first) and differs from those vocabularies by one.
#'
#' @return Integer/numeric vector for `format = "numeric"`, character vector
#'   for `format = "token"`. Preserves `NA` positions.
#'
#' @details
#' For datetime input (no calendar), `lubridate` defaults apply:
#' * `WDAY` uses `getOption("lubridate.week.start", 7)` (1 = Sunday).
#' * `MONTH`: 1 = January, 12 = December.
#' * `HOUR`: 0-23.
#' * `MWEEK`: calendar-grid week-of-month aligned to `WDAY`.
#'
#' @examples
#' library(lubridate)
#' dtm <- ymd_h("2020-03-15 14", tz = "UTC")
#' as_timeframe(dtm, "MONTH")                   # 3
#' as_timeframe(dtm, "YDAY", format = "token")  # "d075"
#' @export
as_timeframe <- function(x, timeframe,
                         format = c("numeric", "token"), ...) {
  UseMethod("as_timeframe")
}

#' @rdname as_timeframe
#' @export
as_timeframe.POSIXt <- function(x, timeframe,
                                format = c("numeric", "token"), ...) {
  format <- match.arg(format)
  timeframe <- toupper(timeframe)

  if (!timeframe %in% CORE_TIMEFRAMES) {
    stop("Unsupported timeframe: '", timeframe, "'. Must be one of: ",
         paste(CORE_TIMEFRAMES, collapse = ", "), call. = FALSE)
  }

  dots <- list(...)
  week_start <- dots$week_start

  na_mask <- is.na(x)

  extractor <- .TIMEFRAME_EXTRACTORS[[timeframe]]
  numeric_value <- tryCatch(
    if (!is.null(week_start) && timeframe %in% c("WDAY", "MWEEK")) {
      extractor(x, week_start = week_start)
    } else {
      extractor(x)
    },
    error = function(e) extractor(x)
  )

  if (any(na_mask)) numeric_value[na_mask] <- NA_integer_

  if (format == "numeric") return(numeric_value)

  # token format
  if (timeframe == "WDAY") {
    lbl <- if (is.null(week_start)) {
      lubridate::wday(x, label = TRUE, abbr = TRUE)
    } else {
      lubridate::wday(x, label = TRUE, abbr = TRUE, week_start = week_start)
    }
    tok <- toupper(as.character(lbl))
    if (any(na_mask)) tok[na_mask] <- NA_character_
    return(tok)
  }

  formatter <- .TIMEFRAME_FORMATTERS[[timeframe]]
  tok <- formatter(numeric_value)
  if (any(na_mask)) tok[na_mask] <- NA_character_
  tok
}

#' @rdname as_timeframe
#' @export
as_timeframe.Date <- function(x, timeframe,
                              format = c("numeric", "token"), ...) {
  as_timeframe.POSIXt(as.POSIXct(x, tz = "UTC"), timeframe, format, ...)
}

#' @rdname as_timeframe
#' @export
as_timeframe.numeric <- function(x, timeframe,
                                 format = c("numeric", "token"),
                                 calendar = NULL, ...) {
  format <- match.arg(format)
  timeframe <- .match_timeframe(timeframe)
  if (format == "numeric") return(x)
  na_mask <- is.na(x)
  # A calendar's own vocabulary wins over the canonical formatter: `m12a`
  # spells March "MAR", `wd7` is Monday-first, and the formatters are not.
  tok <- if (!is.null(calendar)) {
    .value_vocab(x, .timeframe_vocab(calendar, timeframe), timeframe)
  } else {
    .TIMEFRAME_FORMATTERS[[timeframe]](x)
  }
  if (any(na_mask)) tok[na_mask] <- NA_character_
  tok
}

#' @rdname as_timeframe
#' @export
as_timeframe.default <- function(x, timeframe,
                                 format = c("numeric", "token"), ...) {
  stop("as_timeframe() is not implemented for class '",
       class(x)[1], "'. Supported classes: Date, POSIXct, POSIXlt.",
       call. = FALSE)
}

# -----------------------------------------------------------------------------
# Internal helpers
# -----------------------------------------------------------------------------

#' @noRd
.is_valid_timeframe <- function(timeframe) {
  toupper(timeframe) %in% CORE_TIMEFRAMES
}

#' Normalise and validate a timeframe name
#' @noRd
.match_timeframe <- function(timeframe, arg = "timeframe") {
  if (!is.character(timeframe) || length(timeframe) != 1L) {
    .stop("`%s` must be a single character string", arg)
  }
  tf <- toupper(timeframe)
  if (!tf %in% CORE_TIMEFRAMES) {
    .stop("unsupported %s: \"%s\". Must be one of: %s",
          arg, timeframe, paste(CORE_TIMEFRAMES, collapse = ", "))
  }
  tf
}

#' Ordinal position of labels within a vocabulary, as timeframe values
#'
#' `vocab` is the timeframe's labels in order, as a calendar's `members` holds
#' them. Unmatched labels give `NA`. Errors for a timeframe whose values are
#' absolute rather than ordinal (see `.TIMEFRAME_ORIGIN`).
#' @noRd
.vocab_value <- function(labels, vocab, timeframe) {
  origin <- .TIMEFRAME_ORIGIN[[timeframe]]
  if (is.na(origin)) {
    .stop(paste0("%s values are absolute rather than ordinal, so a label ",
                 "carries no position in a vocabulary"), timeframe)
  }
  match(labels, vocab) - 1L + origin
}

#' A timeframe's label vocabulary, in order, from a calendar
#'
#' `members` holds the labels in vocabulary order, which is what makes an
#' ordinal position meaningful. Errors when the calendar has no such timeframe.
#' @noRd
.timeframe_vocab <- function(calendar, timeframe) {
  .check_calendar(calendar, "calendar")
  members <- S7::prop(calendar, "members")
  if (!timeframe %in% names(members)) {
    .stop(paste0("calendar \"%s\" has no %s timeframe; it holds: %s"),
          .calendar_name(calendar, require = FALSE), timeframe,
          paste(names(members), collapse = ", "))
  }
  members[[timeframe]]
}

#' Labels for timeframe values, the inverse of `.vocab_value()`
#' @noRd
.value_vocab <- function(values, vocab, timeframe) {
  origin <- .TIMEFRAME_ORIGIN[[timeframe]]
  if (is.na(origin)) {
    .stop(paste0("%s values are absolute rather than ordinal, so they carry ",
                 "no position in a vocabulary"), timeframe)
  }
  idx <- as.integer(values) - origin + 1L
  idx[idx < 1L | idx > length(vocab)] <- NA_integer_
  vocab[idx]
}
