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

# Internal: the live registry (mutable through register_token)
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

.MONTH_LENGTHS_365 <- c(31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31)
.MONTH_LENGTHS_366 <- c(31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31)
.QUARTER_DAYS_365  <- c(90, 91, 92, 92)  # JFM, AMJ, JAS, OND
.MONTH_ABBR        <- c("JAN", "FEB", "MAR", "APR", "MAY", "JUN",
                        "JUL", "AUG", "SEP", "OCT", "NOV", "DEC")
.WDAY_ABBR_MONFIRST <- c("MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN")

.BUILTIN_TOKENS <- list(
  # day-of-year
  d360 = list(timeframe = "YDAY",
              expand = function() .numeric_padded("d", 3, 1, 360)),
  d364 = list(timeframe = "YDAY",
              expand = function() .numeric_padded("d", 3, 1, 364)),
  d365 = list(timeframe = "YDAY",
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

  # weeks
  w52  = list(timeframe = "WEEK",
              expand = function() .numeric_padded("w", 2, 1, 52)),
  w53  = list(timeframe = "WEEK",
              expand = function() .numeric_padded("w", 2, 1, 53)),

  # weekdays (Monday-first, ISO order)
  wd7  = list(timeframe = "WDAY",
              expand = function() .enum(.WDAY_ABBR_MONFIRST)),

  # hours
  h24  = list(timeframe = "HOUR",
              expand = function() .numeric_padded("h", 2, 0, 24)),
  h168 = list(timeframe = "HOUR",
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
#' [`register_token()`].
#'
#' @param name Character scalar — the token name (e.g. `"m12"`).
#' @param timeframe One of [`CORE_TIMEFRAMES`].
#' @param expand A zero-argument function returning a `data.frame` with
#'   columns `label` (character, unique) and `share` (numeric > 0, summing
#'   to 1).
#'
#' @return `register_token()` invisibly returns the token name.
#'   `get_token()` returns the token definition (a list with `timeframe`
#'   and `expand`). `list_tokens()` returns a character vector of all
#'   registered token names.
#'
#' @examples
#' # Register a custom 4-period day-of-year partition
#' register_token("d4q", "YDAY", function() {
#'   data.frame(label = c("Q1d", "Q2d", "Q3d", "Q4d"),
#'              share = c(90, 91, 92, 92) / 365)
#' })
#' "d4q" %in% list_tokens()
#' @export
register_token <- function(name, timeframe, expand) {
  if (!is.character(name) || length(name) != 1L || !nzchar(name)) {
    stop("`name` must be a single non-empty character string", call. = FALSE)
  }
  if (!timeframe %in% CORE_TIMEFRAMES) {
    stop("`timeframe` must be one of CORE_TIMEFRAMES", call. = FALSE)
  }
  if (!is.function(expand)) {
    stop("`expand` must be a function", call. = FALSE)
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
  assign(name,
         list(timeframe = timeframe, expand = expand),
         envir = .TOKEN_REGISTRY)
  invisible(name)
}

#' @rdname register_token
#' @export
get_token <- function(name) {
  if (!exists(name, envir = .TOKEN_REGISTRY, inherits = FALSE)) {
    stop("Unknown token: '", name, "'. Use list_tokens() to see available tokens.",
         call. = FALSE)
  }
  get(name, envir = .TOKEN_REGISTRY, inherits = FALSE)
}

#' @rdname register_token
#' @export
list_tokens <- function() {
  sort(ls(envir = .TOKEN_REGISTRY))
}
