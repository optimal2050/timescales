# =============================================================================
# TIMESLICE LABEL CONVERSIONS
# =============================================================================
# Reading a timeframe off a timeslice, and the datetime round trip.
#
# Every conversion here is a JOIN against a table the package already builds --
# `calendar_leaftable()` when the calendar holds the timeframe,
# `calendar_map_between()` when it does not -- never a parse of the label text. Labels
# are an output format, not a data structure: `h168` labels hours of the WEEK
# as "h000".."h167", so reading "h" + digits as an hour of the day is wrong.
# =============================================================================

# Target token for a timeframe a calendar does not hold. Several tokens can
# claim one timeframe (m12/m12a, w52/w53, d360/d364/d365/d366); these are the
# numeric-label choices. Timeframes absent here have no token at all, so no
# crosswalk target exists for them.
.DEFAULT_TIMEFRAME_TOKEN <- c(
  YDAY     = "d365",
  MONTH    = "m12",
  QUARTER  = "q4",
  SEASON   = "s4",
  WEEK     = "w53",
  WDAY     = "wd7",
  DAYTYPE  = "wk2",
  HOURTYPE = "hp3",
  HOUR     = "h24",
  WHOUR    = "h168",
  MINUTE   = "min60"
)

# Timeframes whose value depends on WHICH year the timeslice falls in, because
# they are weekday-derived. The rest are fixed by the day of year, so any year
# gives the same answer and `year` may default.
.YEAR_DEPENDENT_TIMEFRAMES <- c("YEAR", "WDAY", "MWEEK", "DAYTYPE", "WHOUR")

# Used when the timeframe is year-invariant and the caller gave no year. A
# non-leap year, matching d365's own vocabulary.
.DEFAULT_MAP_YEAR <- 2021L

#' Accept a Calendar or the name of one
#' @noRd
.as_calendar <- function(x, arg = "calendar") {
  if (is.null(x)) {
    .stop(paste0("`%s` is required: the timeframe is read from the calendar, ",
                 "not guessed from the label text"), arg)
  }
  if (is.character(x) && length(x) == 1L && nzchar(x)) return(calendar(x))
  .check_calendar(x, arg)
  x
}

#' Resolve a year for a crosswalk, requiring one where it changes the answer
#' @noRd
.resolve_map_year <- function(year, timeframe) {
  if (!is.null(year)) {
    year <- as.integer(year)
    if (length(year) != 1L || is.na(year)) {
      .stop("`year` must be a single integer")
    }
    return(year)
  }
  if (timeframe %in% .YEAR_DEPENDENT_TIMEFRAMES) {
    .stop(paste0("%s depends on which year the timeslices fall in, so `year` ",
                 "must be given; it is weekday-derived, unlike MONTH or YDAY"),
          timeframe)
  }
  .DEFAULT_MAP_YEAR
}

#' Read a timeframe's label off timeslices
#'
#' Returns the label at `timeframe` for each element of `x`, plus the
#' vocabulary those labels come from (needed to turn them into numbers).
#' Two routes, both joins:
#' * the calendar holds the timeframe -- its leaftable already has the column;
#' * it does not -- `calendar_map_between()` builds the crosswalk to the timeframe's
#'   own calendar, which must be a FUNCTION of the source timeslices. A month
#'   does not determine an hour, and that is an error rather than a guess.
#' @noRd
.resolve_timeframe <- function(x, cal, timeframe, year = NULL) {
  x <- as.character(x)
  own <- calendar_timeframes(cal)

  if (timeframe %in% own) {
    lt <- calendar_leaftable(cal)
    vocab <- .timeframe_vocab(cal, timeframe)
    i <- match(x, lt$timeslice)
    lab <- lt[[timeframe]][i]
    # Labels already at this timeframe ("h20" asked for HOUR) are not leaf
    # keys, so they do not match above; they are their own answer.
    unres <- is.na(i) & !is.na(x)
    if (any(unres)) {
      direct <- x[unres] %in% vocab
      lab[unres][direct] <- x[unres][direct]
    }
    return(list(label = lab, vocab = .valuation_vocab(cal, timeframe, vocab),
                value = NULL))
  }

  tok <- if (timeframe %in% names(.DEFAULT_TIMEFRAME_TOKEN)) {
    .DEFAULT_TIMEFRAME_TOKEN[[timeframe]]
  } else {
    NA_character_
  }
  if (is.na(tok)) {
    # No token claims this timeframe, so there is no crosswalk target. The
    # timeslice still names an instant, and every timeframe is readable from
    # one -- so go through the datetime rather than refuse.
    return(.derive_via_instant(x, cal, timeframe,
                               .resolve_map_year(year, timeframe)))
  }
  target <- calendar(tok)
  from_nm <- .calendar_name(cal, arg = "calendar")
  to_nm   <- .calendar_name(target)
  yr <- .resolve_map_year(year, timeframe)
  m <- tryCatch(calendar_map_between(cal, target, year = yr),
                error = function(e) NULL)
  if (is.null(m)) return(.derive_via_instant(x, cal, timeframe, yr))
  if (anyDuplicated(m[[from_nm]])) {
    .stop(paste0("%s is not available for calendar \"%s\": its timeslices ",
                 "each span several %s values, so there is no single answer. ",
                 "\"%s\" holds %s"),
          timeframe, from_nm, timeframe, from_nm, paste(own, collapse = ", "))
  }
  i <- match(x, m[[from_nm]])
  list(label = m[[to_nm]][i],
       vocab = .valuation_vocab(target, timeframe,
                                .timeframe_vocab(target, timeframe)),
       value = NULL)
}

#' @param calendar A [`Calendar`], or the name of one (`"d365_h24"`). Required
#'   for character input: the timeframe is read from the calendar rather than
#'   parsed out of the label. For numeric input it is optional, and selects the
#'   calendar's own label vocabulary over the canonical one.
#' @param year The year the timeslices fall in. Needed only when `timeframe`
#'   is weekday-derived (`WDAY`, `MWEEK`, `DAYTYPE`, `WHOUR`); `MONTH`, `YDAY`,
#'   `QUARTER`, `SEASON`, `WEEK` and `MDAY` are the same in every year.
#' @rdname as_timeframe
#' @export
as_timeframe.character <- function(x, timeframe,
                                   format = c("numeric", "token"),
                                   calendar = NULL, year = NULL, ...) {
  format <- match.arg(format)
  tf <- .match_timeframe(timeframe)
  cal <- .as_calendar(calendar)
  res <- .resolve_timeframe(x, cal, tf, year)
  if (!is.null(res$value)) {
    # Derived through the instant: there is no vocabulary to index, so the
    # canonical formatter spells the value out.
    return(as_timeframe(res$value, tf, format = format))
  }
  if (format == "token") return(res$label)
  .vocab_value(res$label, res$vocab, tf)
}

# -----------------------------------------------------------------------------
# The named conversions
# -----------------------------------------------------------------------------

#' Read a timeframe off timeslices
#'
#' Convenience wrappers over [`as_timeframe()`] for the timeframes asked for
#' most often. Each returns an integer, and each needs the calendar the
#' timeslices belong to -- the label text is never parsed.
#'
#' A timeframe is available when it is a function of the calendar's
#' timeslices. `tsl2hour()` works on `"d365_h24"` because each timeslice is
#' one hour, and fails on `"m12"` because a month spans 24 of them.
#'
#' @param tsl Character vector of timeslice labels.
#' @param calendar A [`Calendar`], or the name of one (`"d365_h24"`).
#' @param year The year the timeslices fall in; see [`as_timeframe()`].
#'
#' @return Integer vector, `NA` where a label is not in the calendar.
#'
#' @examples
#' tsl2hour(c("d001_h00", "d100_h20"), "d365_h24")   # 0 20
#' tsl2yday(c("d001_h00", "d100_h20"), "d365_h24")   # 1 100
#' tsl2month(c("d001_h00", "d100_h20"), "d365_h24")  # 1 4
#' hour2HOUR(c(0, 20))                               # "h00" "h20"
#' @name timeslice_conversions
NULL

#' @rdname timeslice_conversions
#' @export
tsl2hour <- function(tsl, calendar) {
  as_timeframe(as.character(tsl), "HOUR", calendar = calendar)
}

#' @rdname timeslice_conversions
#' @export
tsl2yday <- function(tsl, calendar) {
  as_timeframe(as.character(tsl), "YDAY", calendar = calendar)
}

#' @rdname timeslice_conversions
#' @export
tsl2month <- function(tsl, calendar, year = NULL) {
  as_timeframe(as.character(tsl), "MONTH", calendar = calendar, year = year)
}

#' @rdname timeslice_conversions
#' @export
hour2HOUR <- function(x, calendar = NULL) {
  as_timeframe(as.numeric(x), "HOUR", format = "token", calendar = calendar)
}

#' @rdname timeslice_conversions
#' @param x Integer vector of timeframe values.
#' @export
yday2YDAY <- function(x, calendar = NULL) {
  as_timeframe(as.numeric(x), "YDAY", format = "token", calendar = calendar)
}

# -----------------------------------------------------------------------------
# The datetime round trip
# -----------------------------------------------------------------------------

#' Convert between timeslices and datetimes
#'
#' `dtm2tsl()` labels instants with the timeslice they fall in.
#' `tsl2dtm()` goes back, returning the instant each timeslice STARTS at --
#' which is what a real datetime axis on a plot needs.
#'
#' Timeslice labels carry no year, so `tsl2dtm()` needs one. Pass a single year
#' for the whole vector, or one year per element when the rows span several.
#'
#' @param tsl Character vector of timeslice labels.
#' @param dtm A `POSIXct`, `POSIXlt` or `Date` vector.
#' @param calendar A [`Calendar`], or the name of one (`"d365_h24"`).
#' @param year A single year, or one per element of `tsl`.
#' @param tz Time zone for the generated instants.
#' @param alignment How real instants beyond the calendar's vocabulary map onto
#'   it; see [`ALIGNMENT_RULES`]. `NULL` uses the calendar's own.
#'
#' @return `tsl2dtm()` a `POSIXct` vector, `NA` where a label is unknown.
#'   `dtm2tsl()` a character vector of timeslice labels.
#'
#' @examples
#' tsl2dtm(c("d001_h00", "d100_h20"), "d365_h24", year = 2021)
#' dtm2tsl(as.POSIXct("2021-04-10 20:00", tz = "UTC"), "d365_h24")
#' @name timeslice_datetime
NULL

#' @rdname timeslice_datetime
#' @export
tsl2dtm <- function(tsl, calendar, year, tz = "UTC", alignment = NULL) {
  cal <- .as_calendar(calendar)
  tsl <- as.character(tsl)
  year <- as.integer(year)
  if (length(year) == 0L || anyNA(year)) {
    .stop("`year` must be one or more integers")
  }
  if (length(year) != 1L && length(year) != length(tsl)) {
    .stop(paste0("`year` must be length 1 or length(tsl) (%d), not %d"),
          length(tsl), length(year))
  }
  grid <- expand_calendar(cal, year = unique(year), tz = tz,
                          alignment = alignment)
  # A coarse label repeats across the grid, so the first match is the instant
  # the period starts at.
  i <- .grid_match(tsl, year, grid)
  # A sampled calendar's own grid carries no labels -- filtering leaves the
  # instants in place but unlabelled. Its timeslices are drawn from the
  # parent's vocabulary, so date them against the parent instead.
  if (anyNA(i) && !all(is.na(tsl))) {
    ref <- .reference_calendar(cal)
    if (!is.null(ref)) {
      rgrid <- expand_calendar(ref, year = unique(year), tz = tz,
                               alignment = alignment)
      j <- .grid_match(tsl, year, rgrid)
      out <- grid$datetime[i]
      out[is.na(i)] <- rgrid$datetime[j][is.na(i)]
      return(out)
    }
  }
  grid$datetime[i]
}

#' Position of (year, timeslice) pairs in an expanded grid
#' @noRd
.grid_match <- function(tsl, year, grid) {
  if (length(year) == 1L) return(match(tsl, grid$timeslice))
  sep <- intToUtf8(13L)
  match(paste(year, tsl, sep = sep),
        paste(grid$year, grid$timeslice, sep = sep))
}

#' @rdname timeslice_datetime
#' @export
dtm2tsl <- function(dtm, calendar, alignment = NULL) {
  datetime_to_timeslice(dtm, .as_calendar(calendar), alignment = alignment)
}

#' Read a timeframe by going through the instant a timeslice names
#'
#' The last resort, and the only route for a timeframe no token claims (MDAY,
#' MWEEK, SECOND) or a calendar no crosswalk can be built from (a sampled one).
#' @noRd
.derive_via_instant <- function(x, cal, timeframe, year) {
  dtm <- tsl2dtm(x, cal, year = year)
  known <- !is.na(x) & x %in% calendar_timeslices(cal)
  if (any(known) && all(is.na(dtm[known]))) {
    # A sampled calendar's own grid carries no labels, but its timeslices are
    # drawn from the parent's vocabulary, so date them against the parent.
    parent <- S7::prop(cal, "meta")$parent_name
    if (!is.null(parent) && nzchar(parent)) {
      dtm <- tsl2dtm(x, calendar(parent), year = year)
    }
  }
  if (any(known) && all(is.na(dtm[known]))) {
    .stop(paste0("cannot place calendar \"%s\"'s timeslices on a timeline, ",
                 "so %s cannot be derived from them"),
          .calendar_name(cal, require = FALSE), timeframe)
  }
  list(label = NULL, vocab = NULL,
       value = as_timeframe(dtm, timeframe, format = "numeric"))
}

#' The complete calendar to date a subset calendar's timeslices against
#'
#' A calendar holding only some of its timeslices has an unlabelled grid, so its
#' own expansion cannot place them in time. `filter_calendar()` records the
#' parent it came from; a hand-built one does not, and its complete form is
#' rebuilt from each timeframe's token instead.
#' @noRd
.reference_calendar <- function(cal) {
  own <- .calendar_name(cal, require = FALSE)
  parent <- S7::prop(cal, "meta")$parent_name
  if (!is.null(parent) && nzchar(parent) && !identical(parent, own)) {
    ref <- tryCatch(calendar(parent), error = function(e) NULL)
    if (!is.null(ref)) return(ref)
  }
  .complete_calendar(cal)
}
