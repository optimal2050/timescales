# =============================================================================
# Token registry
# =============================================================================
# A *token* is a named recipe for the labels (and per-label shares/weights)
# of one timeframe in a calendar hierarchy. Examples:
#
#   d365 -> YDAY,  labels = c("d001", ..., "d365"),    shares = rep(1/365, 365)
#   m12  -> MONTH, labels = c("m01", ..., "m12"),      shares = days/365
#   m12a -> MONTH, labels = c("JAN", ..., "DEC"),      shares = days/365
#   h24  -> HOUR,  labels = c("h00", ..., "h23"),      shares = rep(1/24, 24)
#   q4   -> QUARTER, labels = c("Q1", "Q2", "Q3", "Q4"), shares ~ days_in_q/365
#   wd7  -> WDAY,  labels = c("MON", ..., "SUN"),      shares = rep(1/7, 7)
#
# A token *expands* to a small data.frame with columns `label` and `share`
# (share = fraction of a year, summing to 1). Share is informational here;
# the final `Calendar` shares are computed from the Cartesian product so
# they sum to year_fraction.
#
# Tokens compose into a hierarchy: e.g. (m12, h24) -> a 12*24 = 288-leaf
# calendar. The order of tokens fixes the timeframe order.
# =============================================================================

# Internal: the live registry (mutable through register_calendar_token)
.TOKEN_REGISTRY <- new.env(parent = emptyenv())

# A token expands to a data.frame(label, share). `share` MUST sum to 1
# (it's the within-year share of each label at this timeframe, in isolation).

# helper: numeric_padded style ------------------------------------------------
.numeric_padded <- function(prefix, width, start, count) {
  fmt <- sprintf("%%s%%0%dd", width)
  data.frame(
    label = sprintf(fmt, prefix, seq.int(start, length.out = count)),
    share = rep(1 / count, count),
    stringsAsFactors = FALSE
  )
}

# helper: enum style ----------------------------------------------------------
.enum <- function(labels, shares = NULL) {
  if (is.null(shares)) shares <- rep(1 / length(labels), length(labels))
  data.frame(label = labels, share = shares, stringsAsFactors = FALSE)
}

# Built-in token definitions --------------------------------------------------
# Each entry is list(timeframe = , expand = function() data.frame(label, share))

# (.MONTH_LENGTHS_365 / _366 / _360 live in R/catalog.R, which collates
# earlier and needs them at load time)
.QUARTER_DAYS_365  <- c(90, 91, 92, 92)  # JFM, AMJ, JAS, OND
.MONTH_ABBR        <- c("JAN", "FEB", "MAR", "APR", "MAY", "JUN",
                        "JUL", "AUG", "SEP", "OCT", "NOV", "DEC")
.WDAY_ABBR_MONFIRST <- c("MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN")

.BUILTIN_TOKENS <- list(
  # day-of-year. Stylised short years declare how real Gregorian days beyond
  # their vocabulary map: d365 drops Feb 29 (later ydays shift down), d360 and
  # d364 drop the trailing days of the year.
  d360 = list(timeframe = "YDAY", alignment = "drop_last",
              expand = function() .numeric_padded("d", 3, 1, 360)),
  d364 = list(timeframe = "YDAY", alignment = "drop_last",
              expand = function() .numeric_padded("d", 3, 1, 364)),
  d365 = list(timeframe = "YDAY", alignment = "drop_feb29",
              expand = function() .numeric_padded("d", 3, 1, 365)),
  d366 = list(timeframe = "YDAY",
              expand = function() .numeric_padded("d", 3, 1, 366)),

  # months — numeric and abbreviated, with day-weighted shares
  m12  = list(timeframe = "MONTH", expand = function() {
    data.frame(label = sprintf("m%02d", 1:12),
               share = .MONTH_LENGTHS_365 / 365,
               stringsAsFactors = FALSE)
  }),
  m12a = list(timeframe = "MONTH", expand = function() {
    data.frame(label = .MONTH_ABBR,
               share = .MONTH_LENGTHS_365 / 365,
               stringsAsFactors = FALSE)
  }),

  # quarters and seasons
  q4   = list(timeframe = "QUARTER", expand = function() {
    data.frame(label = sprintf("Q%d", 1:4),
               share = .QUARTER_DAYS_365 / 365,
               stringsAsFactors = FALSE)
  }),
  # meteorological seasons, day-weighted (WIN = Dec+Jan+Feb = 90 days)
  s4   = list(timeframe = "SEASON", expand = function() {
    .enum(.SEASON_LABELS, c(90, 92, 92, 91) / 365)
  }),

  # weeks. Week 53 (the trailing Dec 29-31 stub) folds into w52 rather than
  # dropping those days.
  w52  = list(timeframe = "WEEK", alignment = "repeat_last",
              expand = function() .numeric_padded("w", 2, 1, 52)),
  w53  = list(timeframe = "WEEK",
              expand = function() .numeric_padded("w", 2, 1, 53)),

  # weekdays (Monday-first, ISO order)
  wd7  = list(timeframe = "WDAY",
              expand = function() .enum(.WDAY_ABBR_MONFIRST)),

  # day types (workday vs weekend) and hour types (day/night/peak)
  wk2  = list(timeframe = "DAYTYPE",
              expand = function() .enum(.DAYTYPE_LABELS, c(5, 2) / 7)),
  hp3  = list(timeframe = "HOURTYPE",
              expand = function() .enum(.HOURTYPE_LABELS, c(12, 8, 4) / 24)),

  # hours. h168 is hour-of-week (Mon 00:00 = h000), a distinct axis from
  # hour-of-day — it lives on WHOUR, not HOUR.
  h24  = list(timeframe = "HOUR",
              expand = function() .numeric_padded("h", 2, 0, 24)),
  h168 = list(timeframe = "WHOUR",
              expand = function() .numeric_padded("h", 3, 0, 168)),

  # minutes
  min60 = list(timeframe = "MINUTE",
               expand = function() .numeric_padded("min", 2, 0, 60))
)

# Initialise the registry -----------------------------------------------------
local({
  for (nm in names(.BUILTIN_TOKENS)) {
    assign(nm, .BUILTIN_TOKENS[[nm]], envir = .TOKEN_REGISTRY)
  }
})

# Public API ------------------------------------------------------------------

#' Register or look up a calendar token
#'
#' Tokens are named recipes for the labels (and within-year shares) of one
#' timeframe in a calendar hierarchy. A handful of built-in tokens covers the
#' common cases (`d365`, `m12`, `m12a`, `q4`, `w52`, `w53`, `wd7`, `h24`,
#' `h168`, `min60`, `d360`, `d364`, `d366`). Custom tokens may be added with
#' [`register_calendar_token()`].
#'
#' @param name Character scalar — the token name (e.g. `"m12"`).
#' @param timeframe One of [`CORE_TIMEFRAMES`].
#' @param expand A zero-argument function returning a `data.frame` with
#'   columns `label` (character, unique) and `share` (numeric > 0, summing
#'   to 1).
#' @param alignment Optional default alignment rule (one of
#'   [`ALIGNMENT_RULES`]) declaring how real instants beyond this token's
#'   vocabulary map onto it (e.g. `"drop_feb29"` for `d365`). Calendars built
#'   from the token inherit it in `meta$alignment`.
#'
#' @return `register_calendar_token()` invisibly returns the token name.
#'   `get_calendar_token()` returns the token definition (a list with `timeframe`,
#'   `expand`, and optionally `alignment`). `list_calendar_tokens()` returns a
#'   character vector of all registered token names.
#'
#' @examples
#' # Register a custom 4-period day-of-year partition
#' register_calendar_token("d4q", "YDAY", function() {
#'   data.frame(label = c("Q1d", "Q2d", "Q3d", "Q4d"),
#'              share = c(90, 91, 92, 92) / 365)
#' })
#' "d4q" %in% list_calendar_tokens()
#' @export
register_calendar_token <- function(name, timeframe, expand, alignment = NULL) {
  if (!is.character(name) || length(name) != 1L || !nzchar(name)) {
    stop("`name` must be a single non-empty character string", call. = FALSE)
  }
  if (!timeframe %in% CORE_TIMEFRAMES) {
    stop("`timeframe` must be one of CORE_TIMEFRAMES", call. = FALSE)
  }
  if (!is.function(expand)) {
    stop("`expand` must be a function", call. = FALSE)
  }
  if (!is.null(alignment)) {
    alignment <- match.arg(alignment, ALIGNMENT_RULES)
  }
  # Sanity-check on first call
  test <- expand()
  if (!is.data.frame(test) ||
      !all(c("label", "share") %in% names(test)) ||
      anyNA(test$label) || anyDuplicated(test$label) ||
      !is.numeric(test$share) || any(test$share <= 0) ||
      abs(sum(test$share) - 1) > 1e-9) {
    stop("`expand()` must return a data.frame(label, share) with unique ",
         "labels and share summing to 1", call. = FALSE)
  }
  entry <- list(timeframe = timeframe, expand = expand)
  if (!is.null(alignment)) entry$alignment <- alignment
  assign(name, entry, envir = .TOKEN_REGISTRY)
  invisible(name)
}

#' @rdname register_calendar_token
#' @export
get_calendar_token <- function(name) {
  if (!exists(name, envir = .TOKEN_REGISTRY, inherits = FALSE)) {
    stop("Unknown token: '", name,
         "'. Use list_calendar_tokens() to see available tokens.", call. = FALSE)
  }
  get(name, envir = .TOKEN_REGISTRY, inherits = FALSE)
}

#' @rdname register_calendar_token
#' @export
list_calendar_tokens <- function() {
  sort(ls(envir = .TOKEN_REGISTRY))
}

# Valuation vocabularies -------------------------------------------------------
# A label's NUMBER is its position in the timeframe's FULL vocabulary, not in
# whatever subset a calendar happens to hold. A sampled calendar whose YDAY
# members are d015, d105, d196, d288 must still read d015 as day 15, so the
# position is taken in the token's vocabulary (d365) rather than the calendar's.

.VOCAB_CACHE <- new.env(parent = emptyenv())

#' The full label vocabulary a calendar's timeframe labels are drawn from
#'
#' Finds the registered token for `timeframe` whose vocabulary CONTAINS the
#' calendar's labels -- preferring an exact match, then the smallest superset.
#' Falls back to the calendar's own labels when no token covers them, which is
#' the complete-vocabulary case.
#' @noRd
.valuation_vocab <- function(calendar, timeframe, labels) {
  labels <- unique(labels[!is.na(labels)])
  if (length(labels) == 0L) return(labels)
  # A calendar built by calendar()/calendar_build() records which token each
  # timeframe came from, which is exact. Filtering preserves it.
  tok <- S7::prop(calendar, "meta")$tokens[[timeframe]]
  if (is.null(tok) || !tok %in% list_calendar_tokens()) {
    tok <- .infer_token(labels, timeframe)
  }
  if (is.na(tok)) return(labels)
  get_calendar_token(tok)$expand()$label
}

#' The registered token whose vocabulary these labels are drawn from
#'
#' Prefers an exact match, then the smallest superset. `NA` when no token
#' covers them, which is a hand-built vocabulary of its own.
#' @noRd
.infer_token <- function(labels, timeframe) {
  labels <- unique(labels[!is.na(labels)])
  if (length(labels) == 0L) return(NA_character_)
  key <- paste(c(timeframe, length(labels), labels[1L],
                 labels[length(labels)]), collapse = intToUtf8(13L))
  if (exists(key, envir = .VOCAB_CACHE, inherits = FALSE)) {
    return(get(key, envir = .VOCAB_CACHE, inherits = FALSE))
  }
  best <- NA_character_
  best_n <- Inf
  for (nm in list_calendar_tokens()) {
    entry <- get_calendar_token(nm)
    if (!identical(entry$timeframe, timeframe)) next
    vocab <- entry$expand()$label
    if (!all(labels %in% vocab)) next
    if (setequal(vocab, labels)) { best <- nm; break }
    if (length(vocab) < best_n) { best <- nm; best_n <- length(vocab) }
  }
  assign(key, best, envir = .VOCAB_CACHE)
  best
}

#' The complete calendar a subset calendar's labels are drawn from
#'
#' A calendar holding only some of its timeslices cannot place them on a
#' timeline -- its own expansion carries no labels. Rebuilding the complete
#' calendar from each timeframe's inferred token gives something that can.
#' Returns `NULL` when any timeframe's vocabulary is not a registered token.
#' @noRd
.complete_calendar <- function(cal) {
  tfs <- calendar_timeframes(cal)
  toks <- vapply(tfs, function(tf)
    .infer_token(calendar_timeslices(cal, tf), tf), character(1))
  if (anyNA(toks)) return(NULL)
  out <- tryCatch(calendar(paste(toks, collapse = "_")), error = function(e) NULL)
  if (is.null(out)) return(NULL)
  if (identical(.calendar_name(out, require = FALSE),
                .calendar_name(cal, require = FALSE))) return(NULL)
  out
}
