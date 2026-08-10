# =============================================================================
# Datetime <-> slice conversions and calendar expansion
# =============================================================================
# Three building blocks:
#
#   instant_to_slice(dtm, cal)        datetime vector -> slice IDs
#   expand_calendar(cal, years, by)   enumerate the instants of model year(s)
#                                     -> data.frame(datetime, year, slice)
#   recast(x, from, to, ...)          value-on-slice-in-A -> value-on-slice-in-B
#
# `recast()` follows the geoscales two-step over the base instant grid
# (see R/base-calendar.R): project source values DOWN to instants, aggregate
# UP to target slices. Aggregation rules (RECAST_RULES) and alignment rules
# (ALIGNMENT_RULES) are separate axes — see R/rules.R and dev/review-core.md.
# =============================================================================

# Fixed cardinalities used by the positional vocabulary fallback. WDAY is
# deliberately absent: lubridate's default week start would misalign
# Monday-first vocabularies, and the label match already covers `wd7`.
.FULL_CARDINALITY <- c(QUARTER = 4L, MONTH = 12L, HOUR = 24L,
                       WHOUR = 168L, MINUTE = 60L, SECOND = 60L,
                       SEASON = 4L, DAYTYPE = 2L, HOURTYPE = 3L)

# -----------------------------------------------------------------------------
# instant_to_slice()
# -----------------------------------------------------------------------------

#' Map datetimes to calendar slice IDs
#'
#' Extracts each calendar timeframe's component from `dtm`, applies the
#' calendar's alignment rules (`meta$alignment`, see [`ALIGNMENT_RULES`]),
#' and looks the resulting tuple up in `calendar@leaves`. Datetimes that
#' produce a tuple not present in the calendar return `NA`.
#'
#' Local time is `dtm` plus `meta$utc_offset_minutes`; when
#' `meta$year_start` is not January 1, `YDAY` and `YEAR` are computed
#' relative to that anchor (MONTH/QUARTER/WEEK remain Gregorian).
#'
#' Labels are resolved by formatted-token match against the calendar's
#' vocabulary first; for enum vocabularies of full fixed cardinality
#' (12 months, 4 quarters, 24 hours, ...) an ordinal positional fallback
#' applies, which assumes the vocabulary is in natural order — this is what
#' makes `m12a` (`JAN`..`DEC`) work.
#'
#' @param dtm A `POSIXct`/`POSIXlt`/`Date` vector.
#' @param calendar A [`Calendar`].
#' @param alignment Optional override of the calendar's alignment: a single
#'   rule applied to every timeframe, or a named list/vector per timeframe.
#'   `NULL` (default) uses `meta$alignment`.
#'
#' @return A character vector of slice IDs the same length as `dtm`.
#'
#' @examples
#' cal <- calendar_build("m12")
#' instant_to_slice(lubridate::ymd(c("2020-01-15", "2020-07-04")), cal)
#'
#' # Enum vocabularies resolve positionally
#' instant_to_slice(lubridate::ymd("2021-03-15"), calendar_build("m12a"))
#'
#' # d365 drops Feb 29 and keeps Dec 31 = d365 on leap years
#' d365 <- calendar_build("d365")
#' instant_to_slice(lubridate::ymd(c("2020-02-29", "2020-12-31")), d365)
#' @export
instant_to_slice <- function(dtm, calendar, alignment = NULL) {
  if (!inherits(calendar, "timescales::Calendar") &&
      !S7::S7_inherits(calendar, Calendar)) {
    stop("`calendar` must be a Calendar object", call. = FALSE)
  }
  if (inherits(dtm, "Date")) dtm <- as.POSIXct(dtm, tz = "UTC")

  tfs    <- S7::prop(calendar, "timeframes")
  leaves <- S7::prop(calendar, "leaves")
  levels <- S7::prop(calendar, "levels")
  meta   <- S7::prop(calendar, "meta")

  offset <- meta$utc_offset_minutes %||% 0L
  local  <- if (offset != 0) dtm + as.numeric(offset) * 60 else dtm

  # One label vector per timeframe
  labs <- lapply(tfs, function(tf) {
    .tf_labels(local, tf,
               vocab = levels[[tf]],
               align = .resolve_alignment(alignment, meta$alignment, tf),
               ys    = meta$year_start)
  })

  # Rows with any NA component are NA slices
  any_na <- Reduce(`|`, lapply(labs, is.na))
  dtm_key <- do.call(paste, c(labs, sep = "\u0001"))
  dtm_key[any_na] <- NA_character_

  leaf_key <- do.call(paste,
    c(lapply(tfs, function(tf) as.character(leaves[[tf]])), sep = "\u0001"))

  leaves$slice[match(dtm_key, leaf_key)]
}

#' Resolve the alignment rule for one timeframe
#' @noRd
.resolve_alignment <- function(alignment, meta_align, tf) {
  if (!is.null(alignment)) {
    if (is.character(alignment) && length(alignment) == 1L &&
        is.null(names(alignment))) {
      return(match.arg(alignment, ALIGNMENT_RULES))
    }
    a <- alignment[[tf]]
    if (!is.null(a)) return(match.arg(a, ALIGNMENT_RULES))
  }
  if (!is.null(meta_align)) {
    a <- meta_align[[tf]]
    if (!is.null(a)) return(a)
  }
  NULL
}

#' Labels of one timeframe for a local datetime vector
#' @noRd
.tf_labels <- function(local, tf, vocab, align, ys) {
  n <- length(local)
  if (tf == "ANNUAL") return(rep("ANNUAL", n))
  K <- length(vocab)
  zero_based <- tf %in% c("HOUR", "MINUTE", "SECOND", "WHOUR")

  # Numeric component, year_start-aware for the year axes
  if (tf %in% c("YDAY", "YEAR") && .nontrivial_year_start(ys)) {
    anchor <- .anchor_dates(local, ys)
    v <- if (tf == "YEAR") as.integer(format(anchor, "%Y"))
         else as.integer(as.Date(local) - anchor) + 1L
  } else {
    v <- as.integer(as_timeframe(local, tf, format = "numeric"))
  }

  # YEAR is an open axis, not an ordinal into a vocabulary — label match only
  if (tf == "YEAR") {
    tok <- rep(NA_character_, n)
    ok  <- !is.na(v)
    if (any(ok)) tok[ok] <- .TIMEFRAME_FORMATTERS[["YEAR"]](v[ok])
    return(ifelse(!is.na(tok) & tok %in% vocab, tok, NA_character_))
  }

  if (tf == "YDAY" && identical(align, "drop_feb29")) {
    dts  <- as.Date(local)
    is29 <- !is.na(dts) & format(dts, "%m-%d") == "02-29"
    anchor <- if (.nontrivial_year_start(ys)) .anchor_dates(local, ys)
              else as.Date(sprintf("%s-01-01", format(dts, "%Y")))
    v <- v - .feb29_between(anchor, dts)
    v[is29] <- NA_integer_
  }

  # Alignment for instants beyond the vocabulary
  ord  <- if (zero_based) v + 1L else v
  over <- !is.na(ord) & ord > K
  if (any(over)) {
    if (identical(align, "exact")) {
      stop(sprintf(
        paste0("alignment \"exact\": %d instant(s) fall outside the %s ",
               "vocabulary (%d labels)"),
        sum(over), tf, K), call. = FALSE)
    } else if (identical(align, "repeat_last")) {
      ord[over] <- K
    } else {
      ord[over] <- NA_integer_
    }
  }
  v_fmt <- if (zero_based) ord - 1L else ord

  # 1. formatted-token match against the vocabulary
  if (tf == "WDAY") {
    tok <- as_timeframe(local, "WDAY", format = "token")
  } else {
    fmt <- .TIMEFRAME_FORMATTERS[[tf]]
    tok <- rep(NA_character_, n)
    ok  <- !is.na(v_fmt)
    if (any(ok)) tok[ok] <- fmt(v_fmt[ok])
  }
  out <- ifelse(!is.na(tok) & tok %in% vocab, tok, NA_character_)

  # 2. positional fallback for full-cardinality enum vocabularies
  need <- is.na(out) & !is.na(ord)
  if (any(need)) {
    full <- .FULL_CARDINALITY[tf]
    if (!is.na(full) && K == full) out[need] <- vocab[ord[need]]
  }
  out
}

#' @noRd
.nontrivial_year_start <- function(ys) {
  !is.null(ys) && !(as.integer(ys$month) == 1L && as.integer(ys$day) == 1L)
}

#' Most recent year_start anchor on or before each instant
#' @noRd
.anchor_dates <- function(local, ys) {
  dts <- as.Date(local)
  y   <- as.integer(format(dts, "%Y"))
  a   <- as.Date(sprintf("%04d-%02d-%02d", y,
                         as.integer(ys$month), as.integer(ys$day)))
  before <- !is.na(dts) & dts < a
  if (any(before)) {
    a[before] <- as.Date(sprintf("%04d-%02d-%02d", y[before] - 1L,
                                 as.integer(ys$month), as.integer(ys$day)))
  }
  a
}

#' Number of Feb 29ths in [anchor, date), vectorised
#' @noRd
.feb29_between <- function(anchor, dts) {
  ya  <- as.integer(format(anchor, "%Y"))
  cnt <- integer(length(anchor))
  for (off in 0:1) {
    yy <- ya + off
    isleap <- (yy %% 4L == 0L & yy %% 100L != 0L) | yy %% 400L == 0L
    cand <- rep(as.Date(NA), length(anchor))
    if (any(isleap)) {
      cand[isleap] <- as.Date(sprintf("%04d-02-29", yy[isleap]))
    }
    hit <- !is.na(cand) & cand >= anchor & cand < dts
    cnt <- cnt + as.integer(hit)
  }
  cnt
}

# -----------------------------------------------------------------------------
# expand_calendar()
# -----------------------------------------------------------------------------

#' Enumerate the instants of one or more model years mapped to slices
#'
#' Materialises the calendar on the base instant grid: one row per instant of
#' each requested model year, with the slice that instant belongs to (via
#' [`instant_to_slice()`]). The model year spans `[year_start(y),
#' year_start(y + 1))` in the calendar's local time (`meta$year_start`,
#' `meta$utc_offset_minutes`); with the default metadata that is simply the
#' Gregorian year in `tz`.
#'
#' @param calendar A [`Calendar`].
#' @param year Integer vector — the model year(s) to enumerate.
#' @param by Resolution string passed to `seq.POSIXt`'s `by` argument
#'   (`"hour"`, `"day"`, `"15 min"`, ...). Defaults to the finest of the
#'   calendar's timeframes.
#' @param tz Time zone of the returned instants. Defaults to `"UTC"`.
#' @param alignment Optional alignment override, as in
#'   [`instant_to_slice()`].
#'
#' @return A `data.frame` with columns `datetime` (POSIXct), `year`
#'   (integer, model year) and `slice` (character). Rows where `slice` is
#'   `NA` are instants the calendar does not cover.
#'
#' @examples
#' cal <- calendar_build("m12")
#' grid <- expand_calendar(cal, year = 2021, by = "day")
#' nrow(grid)                                  # 365
#' nrow(expand_calendar(cal, 2020, by = "day"))  # 366 (leap year)
#' @export
expand_calendar <- function(calendar, year, by = NULL, tz = "UTC",
                            alignment = NULL) {
  if (!S7::S7_inherits(calendar, Calendar)) {
    stop("`calendar` must be a Calendar object", call. = FALSE)
  }
  year <- as.integer(year)
  if (length(year) == 0L || anyNA(year)) {
    stop("`year` must be one or more integers", call. = FALSE)
  }

  if (is.null(by)) {
    by <- .default_step(S7::prop(calendar, "timeframes"))
  }

  chunks <- lapply(year, function(y) {
    dtm <- .model_year_instants(calendar, y, by, tz)
    data.frame(
      datetime = dtm,
      year     = y,
      slice    = instant_to_slice(dtm, calendar, alignment = alignment),
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, chunks)
  rownames(out) <- NULL
  out
}

#' Finest seq.POSIXt step implied by a set of timeframes
#' @noRd
.default_step <- function(tfs) {
  if ("SECOND" %in% tfs) "sec"
  else if ("MINUTE" %in% tfs) "min"
  else if (any(c("HOUR", "WHOUR") %in% tfs)) "hour"
  else "day"
}

#' Instants of one model year, honouring year_start and utc offset
#' @noRd
.model_year_instants <- function(calendar, year, by, tz) {
  meta   <- S7::prop(calendar, "meta")
  ys     <- meta$year_start %||% list(month = 1L, day = 1L)
  offset <- meta$utc_offset_minutes %||% 0L

  # Default metadata -> the cached base grid
  if (!.nontrivial_year_start(ys) && offset == 0) {
    return(base_calendar(year, by = by, tz = tz)$datetime)
  }

  fmt <- "%04d-%02d-%02d 00:00:00"
  start <- as.POSIXct(sprintf(fmt, year,
                              as.integer(ys$month), as.integer(ys$day)),
                      tz = tz)
  end   <- as.POSIXct(sprintf(fmt, year + 1L,
                              as.integer(ys$month), as.integer(ys$day)),
                      tz = tz)
  # The window is defined in calendar-local time; shift back to grid time
  if (offset != 0) {
    start <- start - as.numeric(offset) * 60
    end   <- end - as.numeric(offset) * 60
  }
  dtm <- seq(start, end, by = by)
  dtm[dtm < end]
}

# -----------------------------------------------------------------------------
# recast()
# -----------------------------------------------------------------------------

#' Recast values from one calendar to another
#'
#' The central conversion verb. Takes a `data.frame` keyed by slice in
#' calendar `from` with one or more numeric value columns, and returns a
#' `data.frame` keyed by slice in calendar `to`. Every conversion routes
#' `A -> base -> B` through the shared instant grid: source values are
#' projected down to instants, then aggregated up to target slices, so
#' aggregation and disaggregation are one operation. A pairwise override
#' registered with [`register_conversion()`] short-circuits the route.
#'
#' @param x `data.frame` with a column named by `key` (default `"slice"`)
#'   plus one or more numeric value columns.
#' @param from Source [`Calendar`].
#' @param to Destination [`Calendar`], or a timeframe name of `from`
#'   (including `"ANNUAL"`) for within-calendar aggregation via
#'   [`calendar_at_level()`].
#' @param year Integer scalar model year used to materialise both calendars
#'   on the shared grid.
#' @param key Name of the slice key column in `x`. Default `"slice"`.
#' @param values Character vector of value columns to transform. Default:
#'   all numeric columns other than `key`.
#' @param rule One of [`RECAST_RULES`], applied to every value column; or
#'   `NULL` (default) to look each column up with [`get_rule()`], falling
#'   back to `"weighted_mean"`.
#' @param by Grid resolution for the shared instant grid. Defaults to the
#'   finest timeframe of the two calendars.
#' @param tz Time zone for the shared grid. Default `"UTC"`.
#' @param na_action What to do with grid instants not covered by `to`:
#'   `"drop"` (default, with a warning — the affected source share is
#'   genuinely lost), `"error"`, or `"keep"` (retain an explicit `NA` slice
#'   row so totals conserve). Instants not covered by `from` carry no data
#'   and are always dropped.
#'
#' @return A `data.frame` keyed by slice in `to`, with one row per slice in
#'   `to` (plus an `NA` row under `na_action = "keep"`) and the same value
#'   columns as in `x`.
#'
#' @details
#' Rules (see [`RECAST_RULES`]): `"sum"` splits each source value equally
#' across its slice's grid instants before summing up, so totals are
#' conserved. `"weighted_mean"` weights by the declared `leaves$share` of
#' each source slice; `"mean"` is the plain (time-weighted) mean over
#' instants — the two differ exactly when declared shares differ from
#' real-time coverage. `"copy"` requires a constant value per target slice;
#' `"sd"` is aggregation-only.
#'
#' @examples
#' cal_m <- calendar_build("m12")
#' cal_q <- calendar_build("q4")
#'
#' x <- data.frame(
#'   slice = sprintf("m%02d", 1:12),
#'   load  = seq(100, 210, length.out = 12)
#' )
#' recast(x, from = cal_m, to = cal_q, year = 2021)
#'
#' # Within-calendar aggregation, and the ANNUAL root
#' cal <- calendar_build("q4", "h24")
#' xh <- data.frame(slice = S7::prop(cal, "leaves")$slice, energy = 1)
#' recast(xh, cal, to = "ANNUAL", year = 2021, rule = "sum")  # 96
#' @export
recast <- function(x, from, to, year,
                   key = "slice",
                   values = NULL,
                   rule = NULL,
                   by = NULL,
                   tz = "UTC",
                   na_action = c("drop", "error", "keep")) {
  na_action <- match.arg(na_action)

  if (!is.data.frame(x)) {
    stop("`x` must be a data.frame", call. = FALSE)
  }
  if (!key %in% names(x)) {
    stop(sprintf("`x` has no column named `%s`", key), call. = FALSE)
  }
  if (!S7::S7_inherits(from, Calendar)) {
    stop("`from` must be a Calendar object", call. = FALSE)
  }
  if (is.character(to)) {
    to <- calendar_at_level(from, to)
  } else if (!S7::S7_inherits(to, Calendar)) {
    stop("`to` must be a Calendar object or a timeframe name of `from`",
         call. = FALSE)
  }
  year <- as.integer(year)
  if (length(year) != 1L || is.na(year)) {
    stop("`year` must be a single integer", call. = FALSE)
  }

  # Pairwise override, keyed by calendar names
  from_meta <- S7::prop(from, "meta")
  to_meta   <- S7::prop(to, "meta")
  if (!is.null(from_meta$name) && !is.null(to_meta$name) &&
      nzchar(from_meta$name) && nzchar(to_meta$name)) {
    fn <- get_conversion(from_meta$name, to_meta$name)
    if (!is.null(fn)) {
      return(fn(x, from, to, year = year, key = key, values = values,
                rule = rule, by = by, tz = tz, na_action = na_action))
    }
  }

  if (is.null(values)) {
    candidates <- setdiff(names(x), key)
    values <- candidates[vapply(x[candidates], is.numeric, logical(1))]
    if (length(values) == 0L) {
      stop("No numeric value columns found in `x`. Specify `values=`.",
           call. = FALSE)
    }
  } else if (!all(values %in% names(x))) {
    stop("Some `values` columns are not in `x`: ",
         paste(setdiff(values, names(x)), collapse = ", "),
         call. = FALSE)
  }

  # Per-column rules: explicit argument > registry > weighted_mean
  rules <- vapply(values, function(v) {
    if (!is.null(rule)) return(match.arg(rule, RECAST_RULES))
    reg <- get_rule(v)
    if (is.null(reg)) "weighted_mean" else reg$rule
  }, character(1))

  # Shared instant grid (A -> base -> B), windowed by `from`'s model year
  if (is.null(by)) {
    by <- .default_step(union(S7::prop(from, "timeframes"),
                              S7::prop(to, "timeframes")))
  }
  dtm <- .model_year_instants(from, year, by, tz)

  s_from <- instant_to_slice(dtm, from)
  s_to   <- instant_to_slice(dtm, to)

  if (na_action == "error") {
    n_bad <- sum(is.na(s_from) | is.na(s_to))
    if (n_bad > 0L) {
      stop(sprintf(
        paste0("%d grid instant(s) are not covered by both calendars; ",
               "use na_action = \"drop\" or \"keep\""), n_bad),
        call. = FALSE)
    }
  }

  # Instants the source calendar does not cover carry no data
  ok <- !is.na(s_from)
  s_from <- s_from[ok]
  s_to   <- s_to[ok]

  # Down-projection factors are computed over each source slice's FULL
  # instant set, so share falling on target-uncovered instants is genuinely
  # lost under na_action = "drop" rather than reallocated to siblings.
  n_grid <- table(s_from)
  n_i    <- as.numeric(n_grid[s_from])

  from_leaves <- S7::prop(from, "leaves")
  share_map <- stats::setNames(from_leaves$share, from_leaves$slice)
  w_i <- as.numeric(share_map[s_from]) / n_i

  if (any(is.na(s_to))) {
    if (na_action == "drop") {
      drop_i <- is.na(s_to)
      affected <- intersect(unique(s_from[drop_i]),
                            stats::na.omit(as.character(x[[key]])))
      warning(sprintf(
        paste0("%d grid instant(s) are not covered by `to`; the share of ",
               "%d source slice(s) falling on them is dropped. ",
               "Use na_action = \"keep\" to conserve totals."),
        sum(drop_i), length(affected)), call. = FALSE)
      s_from <- s_from[!drop_i]
      s_to   <- s_to[!drop_i]
      n_i    <- n_i[!drop_i]
      w_i    <- w_i[!drop_i]
    }
    # na_action == "keep": NA stays as an explicit group
  }

  # Look up x values for each grid instant
  xi <- match(s_from, x[[key]])
  if (anyNA(xi)) {
    missing_slices <- setdiff(unique(s_from), x[[key]])
    if (length(missing_slices) > 0L) {
      warning(sprintf(
        paste0("%d source slice(s) present on the grid but missing from ",
               "`x` (e.g. %s); produced NAs."),
        length(missing_slices),
        paste(utils::head(missing_slices, 3L), collapse = ", ")),
        call. = FALSE)
    }
  }

  # Aggregate per destination slice
  target_keys <- S7::prop(to, "leaves")$slice
  keep_na_row <- na_action == "keep" && anyNA(s_to)

  out <- data.frame(slice = c(target_keys,
                              if (keep_na_row) NA_character_),
                    stringsAsFactors = FALSE)
  names(out) <- key

  grp <- addNA(factor(s_to, levels = target_keys), ifany = keep_na_row)
  idx <- split(seq_along(s_to), grp)

  for (v in values) {
    vals <- x[[v]][xi]
    r <- rules[[v]]
    if (r == "sum") vals <- vals / n_i
    out[[v]] <- .recast_aggregate(vals, w_i, idx, r, v, out[[key]])
  }
  out
}

#' Aggregate instant values into target slices under one rule
#' @noRd
.recast_aggregate <- function(vals, w, idx, rule, vname, target_keys) {
  fn <- switch(
    rule,
    sum           = function(i) sum(vals[i]),
    mean          = function(i) mean(vals[i]),
    weighted_mean = function(i) {
      sw <- sum(w[i])
      if (isTRUE(sw > 0)) sum(vals[i] * w[i]) / sw else mean(vals[i])
    },
    copy          = function(i) {
      u <- unique(vals[i])
      if (length(u) > 1L && diff(range(u, na.rm = TRUE)) > 1e-9) {
        stop(sprintf(
          paste0("rule \"copy\" for `%s`: values are not constant within ",
                 "a target slice"), vname), call. = FALSE)
      }
      u[[1L]]
    },
    sd            = function(i) stats::sd(vals[i]),
    stop("Unknown rule: ", rule, call. = FALSE)
  )

  out <- rep(NA_real_, length(target_keys))
  nm  <- names(idx)
  for (j in seq_along(idx)) {
    if (length(idx[[j]]) == 0L) next
    pos <- if (is.na(nm[j]) || nm[j] == "NA") which(is.na(target_keys))
           else which(!is.na(target_keys) & target_keys == nm[j])
    if (length(pos) == 1L) out[pos] <- fn(idx[[j]])
  }
  out
}
