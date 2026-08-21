# =============================================================================
# Calendar catalog
# =============================================================================
# The curated set of named calendar designs, ported from the predecessor
# `timeslices` package (inst/extdata/templates.yml there). The catalog is a
# plain R list — the source of truth; a language-agnostic YAML export can be
# generated from it when the cross-language `specs/` phase needs one.
#
# Most entries are plain Cartesian token products that `calendar_build()`
# assembles; the six `m12_md*` designs are non-Cartesian (February is short)
# and route to `.calendar_m12_mday()`. Unlike timeslices — which gave every
# timeslice a uniform share — all catalog calendars carry duration-proportional
# shares by construction.
#
# Entry fields:
#   tokens        character vector of registered token names (coarse first)
#   coverage      "complete" | "truncated" | "representative"
#   regularity    "regular" | "irregular"   (renamed from timeslices'
#                 symmetric/asymmetric)
#   month_lengths integer(12), only on the m12_md* entries
#   year_start    optional list(month =, day =) -- fiscal anchor (fy* family);
#                 forwarded to calendar_build() unless the caller overrides
#   utc_offset_minutes  optional integer -- same forwarding rule
# =============================================================================

# Month-length constants (also used by the m12/m12a token expanders in
# R/tokens.R; defined here because this file collates first and the catalog
# list below needs them at load time)
.MONTH_LENGTHS_365 <- c(31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31)
.MONTH_LENGTHS_366 <- c(31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31)
.MONTH_LENGTHS_360 <- rep(30L, 12)

.CALENDAR_CATALOG <- list(
  # day-of-year
  d360     = list(tokens = "d360", coverage = "truncated",
                  regularity = "regular"),
  d364     = list(tokens = "d364", coverage = "truncated",
                  regularity = "regular"),
  d365     = list(tokens = "d365", coverage = "truncated",
                  regularity = "regular"),
  d366     = list(tokens = "d366", coverage = "complete",
                  regularity = "regular"),
  d360_h24 = list(tokens = c("d360", "h24"), coverage = "truncated",
                  regularity = "regular"),
  d364_h24 = list(tokens = c("d364", "h24"), coverage = "truncated",
                  regularity = "regular"),
  d365_h24 = list(tokens = c("d365", "h24"), coverage = "truncated",
                  regularity = "regular"),
  d366_h24 = list(tokens = c("d366", "h24"), coverage = "complete",
                  regularity = "regular"),

  # months
  m12      = list(tokens = "m12", coverage = "complete",
                  regularity = "regular"),
  m12a     = list(tokens = "m12a", coverage = "complete",
                  regularity = "regular"),
  m12_h24  = list(tokens = c("m12", "h24"), coverage = "complete",
                  regularity = "regular"),
  m12a_h24 = list(tokens = c("m12a", "h24"), coverage = "complete",
                  regularity = "regular"),

  # month x day-of-month (non-Cartesian: month lengths vary)
  m12_md360     = list(tokens = c("m12", "md360"), coverage = "truncated",
                       regularity = "regular",
                       month_lengths = .MONTH_LENGTHS_360),
  m12_md360_h24 = list(tokens = c("m12", "md360", "h24"),
                       coverage = "truncated", regularity = "regular",
                       month_lengths = .MONTH_LENGTHS_360),
  m12_md365     = list(tokens = c("m12", "md365"), coverage = "truncated",
                       regularity = "irregular",
                       month_lengths = .MONTH_LENGTHS_365),
  m12_md365_h24 = list(tokens = c("m12", "md365", "h24"),
                       coverage = "truncated", regularity = "irregular",
                       month_lengths = .MONTH_LENGTHS_365),
  m12_md366     = list(tokens = c("m12", "md366"), coverage = "complete",
                       regularity = "irregular",
                       month_lengths = .MONTH_LENGTHS_366),
  m12_md366_h24 = list(tokens = c("m12", "md366", "h24"),
                       coverage = "complete", regularity = "irregular",
                       month_lengths = .MONTH_LENGTHS_366),

  # quarters and seasons
  q4     = list(tokens = "q4", coverage = "complete",
                regularity = "regular"),
  s4     = list(tokens = "s4", coverage = "complete",
                regularity = "regular"),
  q4_h24 = list(tokens = c("q4", "h24"), coverage = "representative",
                regularity = "regular"),
  s4_h24 = list(tokens = c("s4", "h24"), coverage = "representative",
                regularity = "regular"),

  # weeks
  w52      = list(tokens = "w52", coverage = "truncated",
                  regularity = "regular"),
  w53      = list(tokens = "w53", coverage = "complete",
                  regularity = "regular"),
  w52_h24  = list(tokens = c("w52", "h24"), coverage = "representative",
                  regularity = "regular"),
  w53_h24  = list(tokens = c("w53", "h24"), coverage = "representative",
                  regularity = "regular"),
  w52_h168 = list(tokens = c("w52", "h168"), coverage = "truncated",
                  regularity = "regular"),
  w53_h168 = list(tokens = c("w53", "h168"), coverage = "complete",
                  regularity = "irregular"),

  # weekdays and day types
  wd7     = list(tokens = "wd7", coverage = "representative",
                 regularity = "regular"),
  wd7_h24 = list(tokens = c("wd7", "h24"), coverage = "representative",
                 regularity = "regular"),
  wk2     = list(tokens = "wk2", coverage = "representative",
                 regularity = "regular"),
  wk2_h24 = list(tokens = c("wk2", "h24"), coverage = "representative",
                 regularity = "regular"),

  # fiscal years, April-start (India, Japan, ...). The model year spans
  # [Apr 1 y, Apr 1 y+1); YEAR anchors to the STARTING Gregorian year
  # (Indian "FY 2021-22" -> 2021). MONTH/QUARTER labels stay Gregorian
  # (m04 = April, Q2 = Apr-Jun); the member ORDER starts at the anchor.
  fy04_m12      = list(tokens = "m12", coverage = "complete",
                       regularity = "regular",
                       year_start = list(month = 4L, day = 1L)),
  fy04_m12_h24  = list(tokens = c("m12", "h24"), coverage = "complete",
                       regularity = "regular",
                       year_start = list(month = 4L, day = 1L)),
  fy04_q4       = list(tokens = "q4", coverage = "complete",
                       regularity = "regular",
                       year_start = list(month = 4L, day = 1L)),
  fy04_q4_h24   = list(tokens = c("q4", "h24"),
                       coverage = "representative", regularity = "regular",
                       year_start = list(month = 4L, day = 1L)),
  fy04_d365     = list(tokens = "d365", coverage = "truncated",
                       regularity = "regular",
                       year_start = list(month = 4L, day = 1L)),
  fy04_d365_h24 = list(tokens = c("d365", "h24"), coverage = "truncated",
                       regularity = "regular",
                       year_start = list(month = 4L, day = 1L)),

  # hour types
  hp3      = list(tokens = "hp3", coverage = "representative",
                  regularity = "regular"),
  d365_hp3 = list(tokens = c("d365", "hp3"), coverage = "representative",
                  regularity = "regular"),
  m12a_hp3 = list(tokens = c("m12a", "hp3"), coverage = "representative",
                  regularity = "regular"),
  s4_hp3   = list(tokens = c("s4", "hp3"), coverage = "representative",
                  regularity = "regular"),
  q4_hp3   = list(tokens = c("q4", "hp3"), coverage = "representative",
                  regularity = "regular")
)

#' The calendar catalog
#'
#' Enumerates the named calendar designs [`calendar()`] knows about — the
#' curated set ported from the predecessor `timeslices` package, all with
#' duration-proportional shares. Every id here can be built with
#' `calendar(id)`; the same objects are shipped pre-built in the
#' [`calendars`] dataset.
#'
#' @return A `data.frame` with one row per catalog entry: `id`, `tokens`
#'   (`+`-joined), `timeframes` (`/`-joined), `n_timeslices`, `coverage`
#'   (`complete`/`truncated`/`representative`), `regularity`
#'   (`regular`/`irregular`), and a generated `desc`.
#'
#' @examples
#' cat_df <- calendar_catalog()
#' head(cat_df)
#' subset(cat_df, coverage == "complete")
#' @export
calendar_catalog <- function() {
  ids <- names(.CALENDAR_CATALOG)
  rows <- lapply(ids, function(id) {
    e <- .CALENDAR_CATALOG[[id]]
    tfs <- .catalog_timeframes(e)
    n <- .catalog_n_timeslices(e)
    data.frame(
      id         = id,
      tokens     = paste(e$tokens, collapse = "+"),
      timeframes = paste(tfs, collapse = "/"),
      n_timeslices   = n,
      coverage   = e$coverage,
      regularity = e$regularity,
      desc       = sprintf("%s calendar (%d timeslices; %s, %s%s)",
                           paste(tfs, collapse = "/"), n,
                           e$coverage, e$regularity,
                           if (is.null(e$year_start)) "" else
                             sprintf("; fiscal year from m%02d",
                                     e$year_start$month)),
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

#' Timeframes of a catalog entry, coarse first
#' @noRd
.catalog_timeframes <- function(entry) {
  if (!is.null(entry$month_lengths)) {
    tfs <- c("MONTH", "MDAY")
    if ("h24" %in% entry$tokens) tfs <- c(tfs, "HOUR")
    return(tfs)
  }
  vapply(entry$tokens, function(tok) get_token(tok)$timeframe, character(1),
         USE.NAMES = FALSE)
}

#' Leaf count of a catalog entry
#' @noRd
.catalog_n_timeslices <- function(entry) {
  if (!is.null(entry$month_lengths)) {
    n <- sum(entry$month_lengths)
    if ("h24" %in% entry$tokens) n <- n * 24L
    return(as.integer(n))
  }
  as.integer(prod(vapply(entry$tokens, function(tok) {
    nrow(get_token(tok)$expand())
  }, numeric(1))))
}

#' Build a Calendar from a catalog entry
#' @noRd
.calendar_from_catalog <- function(id, entry, name, ...) {
  # Optional entry-level construction fields (fiscal anchor, UTC offset);
  # an explicit caller argument always wins over the catalog entry
  extra <- list(...)
  for (field in c("year_start", "utc_offset_minutes")) {
    if (!is.null(entry[[field]]) && is.null(extra[[field]])) {
      extra[[field]] <- entry[[field]]
    }
  }
  cal <- if (!is.null(entry$month_lengths)) {
    do.call(.calendar_m12_mday,
            c(list(entry$month_lengths,
                   hour24 = "h24" %in% entry$tokens,
                   tokens = entry$tokens,
                   name = name), extra))
  } else {
    do.call(calendar_build,
            c(as.list(entry$tokens), list(name = name), extra))
  }
  meta <- S7::prop(cal, "meta")
  meta$coverage <- entry$coverage
  meta$regularity <- entry$regularity
  S7::prop(cal, "meta") <- meta
  cal
}

#' Month x day-of-month calendar builder (non-Cartesian)
#'
#' The `m12_md*` family: months of varying length, so the leaf table is a
#' ragged month/day grid rather than a token product. Shares are
#' duration-proportional (each day is 1/sum(month_lengths) of the year).
#' Real instants the design does not cover (Feb 29 under `md365`, day 31
#' under `md360`) produce tuples absent from the leaves and map to `NA`.
#'
#' @noRd
.calendar_m12_mday <- function(month_lengths, hour24, tokens,
                               name = "",
                               desc = "",
                               year_start = list(month = 1L, day = 1L),
                               utc_offset_minutes = 0L,
                               year_fraction = 1) {
  month_lengths <- as.integer(month_lengths)
  stopifnot(length(month_lengths) == 12L, all(month_lengths >= 28L),
            all(month_lengths <= 31L))
  months <- sprintf("m%02d", 1:12)
  total_days <- sum(month_lengths)

  df <- data.frame(
    MONTH = rep(months, month_lengths),
    MDAY  = unlist(lapply(month_lengths, function(n) sprintf("d%02d", 1:n))),
    stringsAsFactors = FALSE
  )
  tfs <- c("MONTH", "MDAY")
  share <- rep(year_fraction / total_days, nrow(df))

  if (hour24) {
    hours <- sprintf("h%02d", 0:23)
    df <- df[rep(seq_len(nrow(df)), each = 24L), , drop = FALSE]
    df$HOUR <- rep(hours, times = total_days)
    tfs <- c(tfs, "HOUR")
    share <- rep(year_fraction / (total_days * 24), nrow(df))
  }
  df$share <- share
  rownames(df) <- NULL

  levels <- list(MONTH = months,
                 MDAY  = sprintf("d%02d", 1:max(month_lengths)))
  if (hour24) levels$HOUR <- sprintf("h%02d", 0:23)

  calendar_from_leaftable(
    leaftable          = df,
    timeframes         = tfs,
    members            = levels,
    name               = name,
    desc               = desc,
    year_start         = year_start,
    utc_offset_minutes = utc_offset_minutes,
    year_fraction      = year_fraction,
    tokens             = stats::setNames(tokens, tfs)
  )
}
