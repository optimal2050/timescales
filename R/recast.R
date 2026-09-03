# =============================================================================
# Datetime <-> timeslice conversions and calendar expansion
# =============================================================================
# Building blocks:
#
#   datetime_to_timeslice(dtm, cal)   datetime vector -> timeslice IDs
#   expand_calendar(cal, years, by)   enumerate the base grid of model year(s)
#                                     -> data.frame(datetime, year, timeslice)
#   recast_to_timebase(x, cal)            timeslice data -> base-grid (datetime) rows
#   recast_from_timebase(x, cal)          datetime rows  -> timeslice data
#   recast(x, from, to, ...)          value-on-timeslice-in-A -> in-B
#
# Every conversion routes `A -> base -> B` through the shared datetime grid
# (see R/base-calendar.R): source values are projected DOWN to grid points,
# then aggregated UP to target timeslices -- recast_calendar() is the fused
# one-call route, recast_to_timebase()/recast_from_timebase() are its two public
# halves. The route itself is collapsed into a small crosswalk table by
# calendar_map() (R/map.R), so the converters are single dplyr pipelines
# that run unchanged over data.frame / tibble / data.table / arrow inputs
# (see R/backend.R for the format contract).
#
# Aggregation rules (CALENDAR_RULES) and alignment rules (ALIGNMENT_RULES)
# are separate axes -- see R/rules.R and dev/review-core.md.
# =============================================================================

# Fixed cardinalities used by the positional vocabulary fallback. WDAY is
# deliberately absent: lubridate's default week start would misalign
# Monday-first vocabularies, and the label match already covers `wd7`.
.FULL_CARDINALITY <- c(QUARTER = 4L, MONTH = 12L, HOUR = 24L,
                       WHOUR = 168L, MINUTE = 60L, SECOND = 60L,
                       SEASON = 4L, DAYTYPE = 2L, HOURTYPE = 3L)

# Internal working columns; user columns may not collide with these
.TS_COLS <- c(".ts_parent", ".ts_tot",
              ".ts_to", ".ts_n_from", ".ts_n_overlap", ".ts_w", ".ts_f")

# -----------------------------------------------------------------------------
# datetime_to_timeslice()
# -----------------------------------------------------------------------------

#' Map datetimes to calendar timeslice IDs
#'
#' Extracts each calendar timeframe's component from `dtm`, applies the
#' calendar's alignment rules (`meta$alignment`, see [`ALIGNMENT_RULES`]),
#' and looks the resulting tuple up in `calendar@leaftable`. Datetimes that
#' produce a tuple not present in the calendar return `NA`.
#'
#' Local time is `dtm` plus `meta$utc_offset_minutes`; when
#' `meta$year_start` is not January 1, `YDAY` and `YEAR` are computed
#' relative to that anchor (MONTH/QUARTER/WEEK remain Gregorian).
#'
#' Labels are resolved by formatted-token match against the calendar's
#' vocabulary first; for enum vocabularies of full fixed cardinality
#' (12 months, 4 quarters, 24 hours, ...) an ordinal positional fallback
#' applies, which assumes the vocabulary is in natural order -- this is what
#' makes `m12a` (`JAN`..`DEC`) work.
#'
#' @param dtm A `POSIXct`/`POSIXlt`/`Date` vector.
#' @param calendar A [`Calendar`].
#' @param alignment Optional override of the calendar's alignment: a single
#'   rule applied to every timeframe, or a named list/vector per timeframe.
#'   `NULL` (default) uses `meta$alignment`.
#'
#' @return A character vector of timeslice IDs the same length as `dtm`.
#'
#' @examples
#' cal <- calendar_build("m12")
#' datetime_to_timeslice(lubridate::ymd(c("2020-01-15", "2020-07-04")), cal)
#'
#' # Enum vocabularies resolve positionally
#' datetime_to_timeslice(lubridate::ymd("2021-03-15"), calendar_build("m12a"))
#'
#' # d365 drops Feb 29 and keeps Dec 31 = d365 on leap years
#' d365 <- calendar_build("d365")
#' datetime_to_timeslice(lubridate::ymd(c("2020-02-29", "2020-12-31")), d365)
#' @export
datetime_to_timeslice <- function(dtm, calendar, alignment = NULL) {
  if (!inherits(calendar, "timescales::Calendar") &&
      !S7::S7_inherits(calendar, Calendar)) {
    stop("`calendar` must be a Calendar object", call. = FALSE)
  }
  if (inherits(dtm, "Date")) dtm <- as.POSIXct(dtm, tz = "UTC")

  tfs    <- S7::prop(calendar, "timeframes")
  leaves <- S7::prop(calendar, "leaftable")
  levels <- S7::prop(calendar, "members")
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

  # Rows with any NA component are NA timeslices
  any_na <- Reduce(`|`, lapply(labs, is.na))
  dtm_key <- do.call(paste, c(labs, sep = ""))
  dtm_key[any_na] <- NA_character_

  leaf_key <- do.call(paste,
    c(lapply(tfs, function(tf) as.character(leaves[[tf]])), sep = ""))

  leaves$timeslice[match(dtm_key, leaf_key)]
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

  # YEAR is an open axis, not an ordinal into a vocabulary -- label match only
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

  # Alignment for grid points beyond the vocabulary
  ord  <- if (zero_based) v + 1L else v
  over <- !is.na(ord) & ord > K
  if (any(over)) {
    if (identical(align, "exact")) {
      stop(sprintf(
        paste0("alignment \"exact\": %d grid point(s) fall outside the %s ",
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

#' Most recent year_start anchor on or before each datetime
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

#' Enumerate the base grid of one or more model years mapped to timeslices
#'
#' Materialises the calendar on the base datetime grid: one row per grid
#' point of each requested model year, with the timeslice that point belongs
#' to (via [`datetime_to_timeslice()`]). The model year spans
#' `[year_start(y), year_start(y + 1))` in the calendar's local time
#' (`meta$year_start`, `meta$utc_offset_minutes`); with the default metadata
#' that is simply the Gregorian year in `tz`.
#'
#' @param x A [`Calendar`].
#' @param year Integer vector -- the model year(s) to enumerate.
#' @param by Resolution string passed to `seq.POSIXt`'s `by` argument
#'   (`"hour"`, `"day"`, `"15 min"`, ...). Defaults to the finest of the
#'   calendar's timeframes.
#' @param tz Time zone of the returned datetimes. Defaults to `"UTC"`.
#' @param alignment Optional alignment override, as in
#'   [`datetime_to_timeslice()`].
#'
#' @return A `data.frame` with columns `datetime` (POSIXct), `year`
#'   (integer, model year) and `timeslice` (character). Rows where
#'   `timeslice` is `NA` are grid points the calendar does not cover.
#'
#' @examples
#' cal <- calendar_build("m12")
#' grid <- expand_calendar(cal, year = 2021, by = "day")
#' nrow(grid)                                  # 365
#' nrow(expand_calendar(cal, 2020, by = "day"))  # 366 (leap year)
#' @export
expand_calendar <- function(x, year, by = NULL, tz = "UTC",
                            alignment = NULL) {
  if (!S7::S7_inherits(x, Calendar)) {
    stop("`x` must be a Calendar object", call. = FALSE)
  }
  year <- as.integer(year)
  if (length(year) == 0L || anyNA(year)) {
    stop("`year` must be one or more integers", call. = FALSE)
  }

  if (is.null(by)) {
    by <- .default_step(S7::prop(x, "timeframes"))
  }

  chunks <- lapply(year, function(y) {
    dtm <- .model_year_datetimes(x, y, by, tz)
    data.frame(
      datetime = dtm,
      year     = y,
      timeslice = datetime_to_timeslice(dtm, x, alignment = alignment),
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

#' Datetimes of one model year, honouring year_start and utc offset
#' @noRd
.model_year_datetimes <- function(calendar, year, by, tz) {
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
# shared internals of the converters
# -----------------------------------------------------------------------------

#' Resolve per-column aggregation rules: explicit > registry > ERROR.
#' There is deliberately NO fallback (user ruling 2026-08-13): a silently
#' guessed rule is a silent unit error waiting to happen.
#' @noRd
.rules_for <- function(values, rule) {
  vapply(values, function(v) {
    if (!is.null(rule)) return(match.arg(rule, CALENDAR_RULES))
    reg <- get_calendar_rule(v)
    if (is.null(reg)) {
      .stop(paste0("no aggregation rule for value column `%s`; pass `rule=` ",
                   "or register one with register_calendar_rule(\"%s\", ...)"), v, v)
    }
    reg$rule
  }, character(1))
}

#' Auto-detect numeric value columns of `x` (given its zero-row schema)
#' @noRd
.values_for <- function(schema, key, drop_cols, values) {
  if (is.null(values)) {
    candidates <- setdiff(names(schema), c(key, drop_cols))
    values <- candidates[vapply(schema[candidates], is.numeric, logical(1))]
    if (length(values) == 0L) {
      .stop("no numeric value columns found in `x`; specify `values=`")
    }
    return(values)
  }
  if (!all(values %in% names(schema))) {
    .stop("value column(s) not in `x`: %s",
          .preview(setdiff(values, names(schema))))
  }
  values
}

#' Guard against user columns colliding with internal working columns
#' @noRd
.check_ts_cols <- function(schema) {
  clash <- intersect(names(schema), .TS_COLS)
  if (length(clash) > 0L) {
    .stop("`x` uses reserved column name(s): %s", .preview(clash))
  }
}

#' Build the per-value-column summarise expressions for one rule set.
#' Bare symbols (never `.data[[...]]`) so the expressions translate on
#' every backend -- dtplyr and arrow both mistranslate pronoun subsetting
#' in places where plain symbols work.
#' @noRd
.rule_exprs <- function(values, rules) {
  out <- list()
  f  <- rlang::sym(".ts_f")
  nn <- rlang::sym(".ts_n_overlap")
  ww <- rlang::sym(".ts_w")
  for (v in values) {
    sym <- rlang::sym(v)
    out[[v]] <- switch(
      rules[[v]],
      sum = rlang::expr(sum(!!sym * !!f)),
      mean = rlang::expr(sum(!!sym * !!nn) / sum(!!nn)),
      weighted_mean = rlang::expr(
        dplyr::if_else(sum(!!ww) > 0,
                       sum(!!sym * !!ww) / sum(!!ww),
                       sum(!!sym * !!nn) / sum(!!nn))),
      copy = rlang::expr(mean(!!sym)),   # constancy pre-checked eagerly
      sd = rlang::expr(
        dplyr::if_else(
          sum(!!nn) > 1,
          sqrt((sum(!!nn * (!!sym)^2) -
                  (sum(!!nn * (!!sym)))^2 / sum(!!nn)) /
                 (sum(!!nn) - 1)),
          NA_real_)),
      .stop("Unknown rule: %s", rules[[v]])
    )
  }
  out
}

#' Eager constancy guard for `copy`-rule columns
#' @noRd
.check_copy_rule <- function(joined, grp_cols, copy_cols) {
  if (length(copy_cols) == 0L) return(invisible(NULL))
  chk <- joined |>
    dplyr::group_by(dplyr::across(dplyr::all_of(grp_cols))) |>
    dplyr::summarise(
      dplyr::across(dplyr::all_of(copy_cols),
                    list(mx = ~ max(.x), mn = ~ min(.x))),
      .groups = "drop")
  chk <- .ts_pull(chk)
  for (v in copy_cols) {
    rng <- chk[[paste0(v, "_mx")]] - chk[[paste0(v, "_mn")]]
    if (any(!is.na(rng) & rng > 1e-9)) {
      stop(sprintf(
        paste0("rule \"copy\" for `%s`: values are not constant within ",
               "a target timeslice"), v), call. = FALSE)
    }
  }
  invisible(NULL)
}

#' Complete a materialised result to the full target vocabulary, in the
#' contract order: identifier groups in first-appearance order, target
#' keys in vocabulary order, the NA row (if any) last.
#' @noRd
.recast_complete <- function(res, idc, out_keys, key, id_cols, values) {
  full <- data.frame(x = out_keys, stringsAsFactors = FALSE)
  names(full) <- key
  if (nrow(idc) > 0L && length(id_cols) > 0L) {
    full <- dplyr::cross_join(idc, full)
  }
  out <- dplyr::left_join(full, res, by = c(id_cols, key),
                          na_matches = "na")
  as.data.frame(out)[, c(key, id_cols, values), drop = FALSE]
}

#' Ensure a calendar has a name for map/cache purposes; anonymous
#' calendars get a positional stand-in (bypassing cache and registries)
#' @noRd
.named_or_temp <- function(cal, temp) {
  nm <- .calendar_name(cal, require = FALSE)
  if (nzchar(nm)) return(cal)
  meta <- S7::prop(cal, "meta")
  meta$name <- temp
  S7::prop(cal, "meta") <- meta
  cal
}

# -----------------------------------------------------------------------------
# recast_calendar()
# -----------------------------------------------------------------------------

#' Recast values from one calendar to another
#'
#' The central conversion verb. Takes a table keyed by timeslice in
#' calendar `from` with one or more numeric value columns, and returns the
#' same table keyed by timeslice in calendar `to`. Every conversion routes
#' `A -> base -> B` through the shared datetime grid: source values are
#' projected down to grid points, then aggregated up to target timeslices,
#' so aggregation and disaggregation are one operation. The route is
#' evaluated as one dplyr pipeline against the [`calendar_map()`]
#' crosswalk, so `x` may live in any supported backend (see below). A
#' pairwise override registered with [`register_calendar_conversion()`] (or a
#' crosswalk registered with [`register_calendar_map()`]) short-circuits
#' the grid route.
#'
#' Columns of `x` that are neither the key nor a value column are treated
#' as identifiers (panel columns -- a `city`, a scenario) and preserved as
#' grouping columns, so panel data recasts correctly in one call; this is
#' what makes mixed pipelines like
#' `x |> recast_calendar(...) |> recast_geoscale(...)` work. Columns named like
#' `from`'s timeframes are treated as timeslice attributes and dropped.
#'
#' The public halves of the route are [`recast_to_timebase()`] and
#' [`recast_from_timebase()`]; `recast_calendar(x, from, to)` is equivalent to
#' `recast_from_timebase(recast_to_timebase(x, from), to)`.
#'
#' @section Backends:
#' `x` may be a `data.frame`, tibble, `data.table`, `dtplyr` lazy table,
#' or an arrow Dataset/Table/query. The result comes back in the input's
#' class; lazy inputs (arrow, dtplyr) return the uncollected query unless
#' `collect = TRUE`. Lazy results contain the observed target timeslices
#' only -- the full-vocabulary completion (and its `NA` rows) applies when
#' the result is materialised.
#'
#' @param x The data to recast, in any supported backend, with a column
#'   named by `key` plus one or more numeric value columns; other columns
#'   are preserved as identifiers.
#' @param from Source [`Calendar`].
#' @param to Destination [`Calendar`], or a timeframe name of `from`
#'   (including `"ANNUAL"`) for within-calendar aggregation via
#'   [`prune_calendar()`].
#' @param year Integer scalar model year used to materialise both calendars
#'   on the shared grid.
#' @param key Name of the timeslice key column in `x`. `NULL` (default)
#'   resolves to `"timeslice"`.
#' @param values Character vector of value columns to transform. Default:
#'   all numeric columns other than `key` and `from`'s timeframe columns.
#'   Numeric identifiers (e.g. `year`) must be excluded explicitly.
#' @param rule One of [`CALENDAR_RULES`], applied to every value column; or
#'   `NULL` (default) to look each column up with [`get_calendar_rule()`]. A column
#'   with neither an explicit `rule=` nor a registry entry is an ERROR --
#'   there is deliberately no fallback (a silently guessed rule is a
#'   silent unit error).
#' @param by Grid resolution for the shared datetime grid. Defaults to the
#'   finest timeframe of the two calendars.
#' @param tz Time zone for the shared grid. Default `"UTC"`.
#' @param na_action What to do with grid points not covered by `to`:
#'   `"drop"` (default, with a warning -- the affected source share is
#'   genuinely lost), `"error"`, or `"keep"` (retain an explicit `NA`
#'   timeslice row so totals conserve). Grid points not covered by `from`
#'   carry no data and are always dropped.
#' @param parent `rule = "share"` only: the [`Calendar`] (or timeframe name
#'   of `from`) defining the groups the shares are taken within. `NULL`
#'   (default) uses `to` when it differs from `from`, else `from` pruned
#'   to its second-finest timeframe.
#' @param collect For lazy inputs (arrow, dtplyr): materialise the result
#'   (`TRUE`) or return the uncollected query (default).
#'
#' @return The recast table in the input's class, with columns
#'   `c(key, identifiers, values)`: per identifier combination, one row per
#'   timeslice in `to` (the full target vocabulary, `NA` where uncovered --
#'   a deliberate divergence from `recast_geoscale()`, which emits observed
#'   combinations only), plus an `NA` timeslice row under
#'   `na_action = "keep"`. Identifier column types are preserved.
#'
#' @details
#' Rules (see [`CALENDAR_RULES`]): `"sum"` splits each source value equally
#' across its timeslice's grid points before summing up, so totals are
#' conserved. `"weighted_mean"` weights by the declared `leaves$share` of
#' each source timeslice; `"mean"` is the plain (time-weighted) mean over
#' grid points -- the two differ exactly when declared shares differ from
#' real-time coverage. `"copy"` requires a constant value per target
#' timeslice; `"sd"` is aggregation-only. There is no `weight=` argument: a
#' calendar has exactly one weighting, its `leaves$share`.
#'
#' `"share"` inverts the output contract: the result stays keyed by
#' `from`'s timeslices, and each value becomes that timeslice's share of
#' the total over its parent timeslice (so shares sum to 1 per parent, per
#' identifier combination). The parent is `parent=`, defaulting to `to` --
#' `recast_calendar(x, cal_h, to = "YDAY", rule = "share")` reads: each
#' hour's share within its day. The source timeslices must nest within the
#' parent's (a week-vs-month pair errors). A parent whose total is zero
#' yields `NA` shares. `"share"` cannot be combined with other rules in
#' one call.
#'
#' @examples
#' cal_m <- calendar_build("m12")
#' cal_q <- calendar_build("q4")
#'
#' x <- data.frame(
#'   timeslice = sprintf("m%02d", 1:12),
#'   load  = seq(100, 210, length.out = 12)
#' )
#' recast_calendar(x, from = cal_m, to = cal_q, year = 2021,
#'                 rule = "weighted_mean")
#'
#' # Panel data: the city column is carried through
#' xp <- rbind(transform(x, city = "A"), transform(x, city = "B"))
#' recast_calendar(xp, cal_m, cal_q, year = 2021, rule = "sum")
#'
#' # Within-calendar aggregation, and the ANNUAL root
#' cal <- calendar_build("q4", "h24")
#' xh <- data.frame(timeslice = S7::prop(cal, "leaftable")$timeslice, energy = 1)
#' recast_calendar(xh, cal, to = "ANNUAL", year = 2021, rule = "sum")  # 96
#' @export
recast_calendar <- function(x, from, to, year,
                            key = NULL,
                            values = NULL,
                            rule = NULL,
                            by = NULL,
                            tz = "UTC",
                            na_action = c("drop", "error", "keep"),
                            parent = NULL,
                            collect = NULL) {
  na_action <- match.arg(na_action)

  backend <- .ts_backend(x)
  if (is.na(backend)) {
    .stop(paste0("`x` must be a data.frame, tibble, data.table, or an ",
                 "arrow table/dataset/query"))
  }
  if (is.null(key)) key <- "timeslice"
  schema <- .ts_schema(x)
  if (!key %in% names(schema)) {
    .stop("`x` has no column named `%s`; pass `key=`", key)
  }
  .check_ts_cols(schema)
  .check_calendar(from, "from")
  if (is.character(to)) {
    to <- prune_calendar(from, to)
  } else {
    .check_calendar(to, "to")
  }
  year <- as.integer(year)
  if (length(year) != 1L || is.na(year)) {
    .stop("`year` must be a single integer")
  }
  # rule "share" needs the calendars before the working renames below
  from_orig <- from
  to_orig <- to

  # Pairwise functional override, keyed by calendar names
  from_meta <- S7::prop(from, "meta")
  to_meta   <- S7::prop(to, "meta")
  if (!is.null(from_meta$name) && !is.null(to_meta$name) &&
      nzchar(from_meta$name) && nzchar(to_meta$name)) {
    fn <- get_calendar_conversion(from_meta$name, to_meta$name)
    if (!is.null(fn)) {
      return(fn(x, from, to, year = year, key = key, values = values,
                rule = rule, by = by, tz = tz, na_action = na_action))
    }
  }

  # Anonymous calendars still convert; they just bypass cache and registry
  from <- .named_or_temp(from, ".from")
  to   <- .named_or_temp(to, ".to")
  from_nm <- .calendar_name(from)
  to_nm   <- .calendar_name(to)
  if (identical(from_nm, to_nm)) {
    # identity / same-name recast: the map's label columns are named by the
    # calendars, so the target needs a distinct working name
    to_meta2 <- S7::prop(to, "meta")
    to_meta2$name <- paste0(to_nm, "..to")
    S7::prop(to, "meta") <- to_meta2
    to_nm <- to_meta2$name
  }

  tfs_from <- S7::prop(from, "timeframes")
  values <- .values_for(schema, key, tfs_from, values)
  id_cols <- setdiff(names(schema), c(key, values, tfs_from))
  rules <- .rules_for(values, rule)

  # Warn about source keys the calendar does not know (eager, small)
  from_leaves <- S7::prop(from, "leaftable")
  src_keys <- .ts_pull(
    dplyr::distinct(dplyr::select(x, dplyr::all_of(key))))[[key]]
  src_keys <- unique(stats::na.omit(as.character(src_keys)))
  unknown <- setdiff(src_keys, from_leaves$timeslice)
  if (length(unknown) > 0L) {
    .warn("%d code(s) in `x$%s` are not timeslices of `from` and were ignored: %s",
          length(unknown), key, .preview(unknown))
  }

  # -- share within parent: result keyed by `from`'s timeslices -------------
  is_share <- rules %in% c("share", "logshare")
  if (any(is_share)) {
    if (!all(is_share)) {
      .stop(paste0("rule \"share\" keeps the output keyed by `from` and ",
                   "cannot be mixed with other rules in one call; recast ",
                   "the columns separately"))
    }
    return(.ts_recast_share(x, backend, from_orig, to_orig, parent, year,
                            key, values, id_cols, by, tz, na_action,
                            collect))
  }
  if (!is.null(parent)) {
    .stop("`parent` applies to rule \"share\" only")
  }

  # The crosswalk (A -> base -> B collapsed)
  map <- calendar_map(from, to, year, by = by, tz = tz)

  if (na_action == "error") {
    n_bad <- (attr(map, "n_from_na") %||% 0L) +
      sum(map$n_overlap[is.na(map[[to_nm]])])
    if (n_bad > 0L) {
      .stop(paste0("%d grid point(s) are not covered by both calendars; ",
                   "use na_action = \"drop\" or \"keep\""), n_bad)
    }
  }

  uncovered <- is.na(map[[to_nm]])
  if (any(uncovered)) {
    if (na_action == "drop") {
      affected <- intersect(unique(map[[from_nm]][uncovered]), src_keys)
      .warn(paste0("%d grid point(s) are not covered by `to`; the share ",
                   "of %d source timeslice(s) falling on them is dropped; use ",
                   "na_action = \"keep\" to conserve totals"),
            sum(map$n_overlap[uncovered]), length(affected))
      map <- map[!uncovered, , drop = FALSE]
    }
    # na_action == "keep": the NA target stays as an explicit group
  }

  # Missing-source warning: grid timeslices absent from an identifier group
  idc <- if (length(id_cols) > 0L) {
    .ts_pull(dplyr::distinct(dplyr::select(x, dplyr::all_of(id_cols))))
  } else {
    data.frame()
  }
  grid_from <- unique(map[[from_nm]])
  if (length(id_cols) > 0L) {
    keysets <- .ts_pull(dplyr::distinct(
      dplyr::select(x, dplyr::all_of(c(id_cols, key)))))
    gk <- do.call(paste, c(lapply(keysets[id_cols], as.character), sep = "\r"))
    all_missing <- unique(unlist(lapply(split(keysets[[key]], gk), function(kk)
      setdiff(grid_from, as.character(kk)))))
  } else {
    all_missing <- setdiff(grid_from, src_keys)
  }
  if (length(all_missing) > 0L) {
    .warn(paste0("%d source timeslice(s) present on the grid but missing from ",
                 "`x` (e.g. %s); produced NAs"),
          length(all_missing), .preview(all_missing))
  }

  # One pipeline: cross the crosswalk into each identifier group, attach the
  # data, aggregate per rule
  jmap <- map
  names(jmap)[names(jmap) == from_nm] <- key
  names(jmap)[names(jmap) == to_nm]   <- ".ts_to"
  names(jmap)[names(jmap) == "n_from"]    <- ".ts_n_from"
  names(jmap)[names(jmap) == "n_overlap"] <- ".ts_n_overlap"
  names(jmap)[names(jmap) == "w"]         <- ".ts_w"
  jmap$year <- NULL
  jmap$.ts_f <- jmap$.ts_n_overlap / jmap$.ts_n_from

  base_grid <- if (length(id_cols) > 0L && nrow(idc) > 0L) {
    dplyr::cross_join(idc, jmap)
  } else {
    jmap
  }

  xq <- .ts_lazy(x, backend)
  joined <- dplyr::right_join(xq, base_grid,
                              by = c(id_cols, key), na_matches = "na")

  grp_cols <- c(id_cols, ".ts_to")
  .check_copy_rule(joined, grp_cols, values[rules == "copy"])

  res <- joined |>
    dplyr::group_by(dplyr::across(dplyr::all_of(grp_cols))) |>
    dplyr::summarise(!!!.rule_exprs(values, rules), .groups = "drop") |>
    dplyr::rename(!!rlang::sym(key) := !!rlang::sym(".ts_to"))

  # Lazy return: observed groups, uncollected
  if (.ts_is_lazy(backend) && !isTRUE(collect)) {
    return(dplyr::select(res, dplyr::all_of(c(key, id_cols, values))))
  }

  # Materialised return: complete to the full target vocabulary, in the
  # contract order
  res <- as.data.frame(dplyr::collect(res))
  target_keys <- S7::prop(to, "leaftable")$timeslice
  keep_na_row <- na_action == "keep" && any(uncovered)
  out_keys <- c(target_keys, if (keep_na_row) NA_character_)
  out <- .recast_complete(res, idc, out_keys, key, id_cols, values)
  .ts_restore(out, backend, collect = collect)
}

#' Resolve the parent calendar for rule "share": explicit `parent=` wins
#' (a timeframe name is pruned from `from`), then `to` when it differs from
#' `from`, then `from` pruned to its second-finest timeframe.
#' @noRd
.ts_share_parent <- function(from, to, parent) {
  if (!is.null(parent)) {
    if (is.character(parent)) parent <- prune_calendar(from, parent)
    .check_calendar(parent, "parent")
    if (!identical(to, from) && !identical(to, parent)) {
      .stop(paste0("conflicting parents: `to` and `parent` name ",
                   "different calendars; for rule \"share\" pass ",
                   "the parent once"))
    }
    return(parent)
  }
  if (!identical(to, from)) return(to)
  tfs <- S7::prop(from, "timeframes")
  if (length(tfs) < 2L) {
    .stop(paste0("`from` has a single timeframe and no coarser ",
                 "parent; pass `parent=`"))
  }
  prune_calendar(from, tfs[[length(tfs) - 1L]])
}

#' rule = "share": each source timeslice's value over its parent-group
#' total. Output stays keyed by `from`'s timeslices -- the one rule that
#' does not change the key.
#' @noRd
.ts_recast_share <- function(x, backend, from, to, parent, year, key,
                             values, id_cols, by, tz, na_action, collect) {
  parent <- .ts_share_parent(from, to, parent)

  from2 <- .named_or_temp(from, ".from")
  par2  <- .named_or_temp(parent, ".parent")
  from_nm <- .calendar_name(from2)
  par_nm  <- .calendar_name(par2)
  if (identical(from_nm, par_nm)) {
    pm <- S7::prop(par2, "meta")
    pm$name <- paste0(par_nm, "..parent")
    S7::prop(par2, "meta") <- pm
    par_nm <- pm$name
  }
  map <- as.data.frame(calendar_map(from2, par2, year, by = by, tz = tz))
  mem <- unique(map[, c(from_nm, par_nm)])

  # shares within a parent are only well-defined when `from` nests in it
  n_par <- table(mem[[from_nm]][!is.na(mem[[par_nm]])])
  split_codes <- names(n_par)[n_par > 1L]
  if (length(split_codes) > 0L) {
    .stop(paste0("rule \"share\": %d timeslice(s) of `from` straddle ",
                 "more than one parent timeslice (%s); the source must ",
                 "nest within the parent"),
          length(split_codes), .preview(split_codes))
  }

  orphan <- is.na(mem[[par_nm]])
  if (any(orphan)) {
    if (na_action == "error") {
      .stop(paste0("%d timeslice(s) of `from` are not covered by the ",
                   "parent; use na_action = \"drop\" or \"keep\""),
            sum(orphan))
    }
    if (na_action == "drop") {
      .warn(paste0("%d timeslice(s) of `from` are not covered by the ",
                   "parent and get NA shares (%s). Use na_action = ",
                   "\"keep\" to treat them as one group."),
            sum(orphan), .preview(mem[[from_nm]][orphan]))
      mem <- mem[!orphan, , drop = FALSE]
    }
    # "keep": the NA parent stays as an explicit group
  }

  jmem <- mem
  names(jmem) <- c(key, ".ts_parent")

  xq <- dplyr::select(.ts_lazy(x, backend),
                      dplyr::all_of(c(id_cols, key, values)))
  joined <- dplyr::inner_join(xq, jmem, by = key)

  tot_nms <- paste0(".ts_tot_", seq_along(values))
  tot_exprs <- lapply(values, function(v) rlang::expr(sum(!!rlang::sym(v))))
  names(tot_exprs) <- tot_nms
  tot <- joined |>
    dplyr::group_by(dplyr::across(dplyr::all_of(c(id_cols, ".ts_parent")))) |>
    dplyr::summarise(!!!tot_exprs, .groups = "drop")

  share_exprs <- lapply(seq_along(values), function(i) {
    v <- rlang::sym(values[[i]])
    t <- rlang::sym(tot_nms[[i]])
    rlang::expr(dplyr::if_else(!!t != 0, !!v / !!t, NA_real_))
  })
  names(share_exprs) <- values

  res <- joined |>
    dplyr::left_join(tot, by = c(id_cols, ".ts_parent"),
                     na_matches = "na") |>
    dplyr::mutate(!!!share_exprs) |>
    dplyr::select(dplyr::all_of(c(key, id_cols, values)))

  if (.ts_is_lazy(backend) && !isTRUE(collect)) {
    return(res)
  }

  idc <- if (length(id_cols) > 0L) {
    .ts_pull(dplyr::distinct(dplyr::select(.ts_lazy(x, backend),
                                           dplyr::all_of(id_cols))))
  } else {
    data.frame()
  }
  res <- as.data.frame(dplyr::collect(res))
  out_keys <- S7::prop(from, "leaftable")$timeslice
  out <- .recast_complete(res, idc, out_keys, key, id_cols, values)
  .ts_restore(out, backend, collect = collect)
}

#' rule "share" is only meaningful in recast_calendar(), whose output key
#' it keeps at the source; the base-grid halves keep the standard contract
#' @noRd
.ts_no_share <- function(rules, where) {
  if (any(rules %in% c("share", "logshare"))) {
    .stop(paste0("rule \"share\" is not supported by %s(); use ",
                 "recast_calendar() with a parent calendar or timeframe"),
          where)
  }
}

# -----------------------------------------------------------------------------
# recast_to_timebase() / recast_from_timebase()
# -----------------------------------------------------------------------------

#' Recast timeslice data down to the base grid, and back
#'
#' The two public halves of the `A -> base -> B` route:
#' `recast_to_timebase()` projects timeslice-keyed data DOWN to the base
#' datetime grid (one row per grid point), and `recast_from_timebase()`
#' aggregates datetime-keyed data UP into a calendar's timeslices. Their
#' composition is [`recast_calendar()`]:
#' `recast_from_timebase(recast_to_timebase(x, from), to)`.
#'
#' Going down, extensive columns (rule `"sum"`) are split equally across a
#' timeslice's grid points so totals conserve; intensive columns are
#' repeated. A `weight` column (the source timeslice's `share` divided by
#' its grid-point count) is attached by default so that the return trip's
#' `"weighted_mean"` reproduces the source calendar's weighting exactly;
#' pass `attach_weight = FALSE` to omit it.
#'
#' Going up, rules act on the grid rows directly: `"sum"` sums,
#' `"mean"` averages, `"weighted_mean"` uses the `weight` column when
#' present (else it equals `"mean"`), `"copy"` requires constancy, `"sd"`
#' is the standard deviation over the grid points.
#'
#' Both ends run as dplyr pipelines and accept any supported backend (see
#' [`recast_calendar()`]'s Backends section); the calendar side of every
#' join is a small in-memory grid.
#'
#' @param x The data: for `recast_to_timebase()` keyed by timeslice (`key`
#'   column, plus an optional `year` column for multi-year data); for
#'   `recast_from_timebase()` keyed by a POSIXct `datetime` column.
#' @param calendar The [`Calendar`] the data is keyed in (`to_base`) or
#'   aggregated into (`from_base`).
#' @param year Model year(s) for the grid. `recast_to_timebase()`: defaults to
#'   the distinct values of `x$year` when present (required otherwise).
#'   `recast_from_timebase()`: defaults to the span of years observed in
#'   `x$datetime` (padded one year each side for year_start offsets).
#' @param key `to_base`: the timeslice key column, default `"timeslice"`
#'   (falling back to a column named like the calendar). `from_base`: the
#'   datetime column, default `"datetime"`.
#' @param values,rule,by,tz As in [`recast_calendar()`].
#' @param attach_weight `to_base` only: attach the `weight` column (default
#'   `TRUE`).
#' @param na_action `from_base` only: what to do with rows whose datetime
#'   the calendar does not cover -- `"drop"` (default, warning), `"error"`,
#'   or `"keep"` (an `NA` timeslice row).
#' @param collect For lazy inputs: materialise (`TRUE`) or return the
#'   query (default).
#'
#' @return `recast_to_timebase()`: one row per (grid point x identifier
#'   combination) with columns `datetime`, `year`, identifiers, values
#'   (and `weight`). `recast_from_timebase()`: one row per (year x timeslice x
#'   identifier combination) with columns `key`-named timeslice, `year`,
#'   identifiers, values. Both in the input's class; lazy in, lazy out.
#'
#' @examples
#' m12 <- calendar_build("m12")
#' x <- data.frame(timeslice = sprintf("m%02d", 1:12), energy = 1:12)
#' g <- recast_to_timebase(x, m12, year = 2021, rule = "sum", by = "day")
#' head(g)
#' sum(g$energy)  # 78 -- totals conserve
#'
#' q4 <- calendar_build("q4")
#' recast_from_timebase(g, q4, rule = "sum", by = "day")
#' @export
recast_to_timebase <- function(x, calendar, year = NULL,
                           key = NULL, values = NULL, rule = NULL,
                           by = NULL, tz = "UTC", attach_weight = TRUE,
                           collect = NULL) {
  backend <- .ts_backend(x)
  if (is.na(backend)) {
    .stop(paste0("`x` must be a data.frame, tibble, data.table, or an ",
                 "arrow table/dataset/query"))
  }
  .check_calendar(calendar)
  schema <- .ts_schema(x)
  .check_ts_cols(schema)
  cal_nm <- .calendar_name(calendar, require = FALSE)
  if (is.null(key)) {
    key <- if ("timeslice" %in% names(schema)) "timeslice"
           else if (nzchar(cal_nm) && cal_nm %in% names(schema)) cal_nm
           else "timeslice"
  }
  if (!key %in% names(schema)) {
    .stop("`x` has no column named `%s`; pass `key=`", key)
  }
  for (cc in c("datetime", if (isTRUE(attach_weight)) "weight")) {
    if (cc %in% names(schema)) {
      .stop("`x` already has a `%s` column; rename it first", cc)
    }
  }

  has_year <- "year" %in% names(schema)
  if (is.null(year)) {
    if (!has_year) {
      .stop("`x` has no `year` column; pass `year=`")
    }
    year <- sort(.ts_pull(
      dplyr::distinct(dplyr::select(x, dplyr::all_of("year"))))$year)
  }
  year <- as.integer(year)

  tfs <- S7::prop(calendar, "timeframes")
  values <- .values_for(schema, key, c(tfs, "year"), values)
  rules <- .rules_for(values, rule)
  .ts_no_share(rules, "recast_to_timebase")

  # Unknown-key warning (eager, small)
  leaves <- S7::prop(calendar, "leaftable")
  src_keys <- .ts_pull(
    dplyr::distinct(dplyr::select(x, dplyr::all_of(key))))[[key]]
  unknown <- setdiff(unique(stats::na.omit(as.character(src_keys))),
                     leaves$timeslice)
  if (length(unknown) > 0L) {
    .warn("%d code(s) in `x$%s` are not timeslices of the calendar: %s",
          length(unknown), key, .preview(unknown))
  }

  # The in-memory grid, with per-(year, timeslice) point counts and weights
  grid <- expand_calendar(calendar, year, by = by, tz = tz)
  grid <- grid[!is.na(grid$timeslice), , drop = FALSE]
  share_map <- stats::setNames(leaves$share, leaves$timeslice)
  grid <- grid |>
    dplyr::group_by(.data$year, .data$timeslice) |>
    dplyr::mutate(.ts_n_from = dplyr::n()) |>
    dplyr::ungroup() |>
    as.data.frame()
  if (isTRUE(attach_weight)) {
    grid$weight <- as.numeric(share_map[grid$timeslice]) / grid$.ts_n_from
  }
  names(grid)[names(grid) == "timeslice"] <- key
  join_by <- c(key, if (has_year) "year")   # grid supplies `year` otherwise

  xq <- .ts_lazy(x, backend)
  out <- dplyr::inner_join(xq, grid, by = join_by, na_matches = "na")

  # Extensive columns split across the timeslice's grid points
  sum_cols <- values[rules == "sum"]
  if (length(sum_cols) > 0L) {
    out <- dplyr::mutate(out, dplyr::across(
      dplyr::all_of(sum_cols), ~ .x / .ts_n_from))
  }

  id_cols <- setdiff(names(schema), c(key, values, tfs, "year"))
  keep <- c("datetime", "year", id_cols, values,
            if (isTRUE(attach_weight)) "weight")
  out <- dplyr::select(out, dplyr::all_of(keep))
  .ts_restore(out, backend, collect = collect)
}

#' @rdname recast_to_timebase
#' @export
recast_from_timebase <- function(x, calendar, year = NULL,
                             key = NULL, values = NULL, rule = NULL,
                             by = NULL, tz = "UTC",
                             na_action = c("drop", "error", "keep"),
                             collect = NULL) {
  na_action <- match.arg(na_action)
  backend <- .ts_backend(x)
  if (is.na(backend)) {
    .stop(paste0("`x` must be a data.frame, tibble, data.table, or an ",
                 "arrow table/dataset/query"))
  }
  .check_calendar(calendar)
  schema <- .ts_schema(x)
  .check_ts_cols(schema)
  if (is.null(key)) key <- "datetime"
  if (!key %in% names(schema)) {
    .stop("`x` has no column named `%s`; pass `key=`", key)
  }
  if ("timeslice" %in% names(schema)) {
    .stop("`x` already has a `timeslice` column; rename it first")
  }

  # Grid years: observed span padded one year each side (year_start /
  # utc-offset windows can reach into the neighbouring Gregorian year)
  if (is.null(year)) {
    yy <- .ts_pull(
      .ts_lazy(x, backend) |>
        dplyr::mutate(.ts_y = lubridate::year(!!rlang::sym(key))) |>
        dplyr::summarise(mn = min(.ts_y), mx = max(.ts_y)))
    year <- (as.integer(yy$mn[1]) - 1L):(as.integer(yy$mx[1]) + 1L)
  }
  year <- as.integer(year)

  tfs <- S7::prop(calendar, "timeframes")
  values <- .values_for(schema, key, c(tfs, "year", "weight"), values)
  rules <- .rules_for(values, rule)
  .ts_no_share(rules, "recast_from_timebase")
  has_weight <- "weight" %in% names(schema)

  grid <- expand_calendar(calendar, year, by = by, tz = tz)
  names(grid)[names(grid) == "datetime"] <- key
  names(grid)[names(grid) == "year"] <- ".ts_year"
  names(grid)[names(grid) == "timeslice"] <- ".ts_to"

  xq <- .ts_lazy(x, backend)
  joined <- dplyr::left_join(xq, grid, by = key, na_matches = "na")

  # Coverage accounting (eager, aggregate only)
  cover <- .ts_pull(
    joined |>
      dplyr::summarise(n = dplyr::n(),
                       n_na = sum(as.integer(is.na(.ts_to)))))
  if (cover$n_na[1] > 0L) {
    if (na_action == "error") {
      .stop(paste0("%d row(s) of `x` fall on datetimes the calendar does ",
                   "not cover; use na_action = \"drop\" or \"keep\""),
            cover$n_na[1])
    }
    if (na_action == "drop") {
      .warn(paste0("%d row(s) of `x` fall on datetimes the calendar does ",
                   "not cover and were dropped; use na_action = \"keep\" ",
                   "to conserve totals"), cover$n_na[1])
      joined <- dplyr::filter(joined, !is.na(.ts_to))
    }
  }

  id_cols <- setdiff(names(schema),
                     c(key, values, "weight", "year", tfs))
  grp_cols <- c(".ts_year", ".ts_to", id_cols)

  # Rule expressions on grid rows: n_overlap == 1 per row; weighted_mean
  # uses the carried `weight` when present
  exprs <- list()
  for (v in values) {
    sym <- rlang::sym(v)
    exprs[[v]] <- switch(
      rules[[v]],
      sum = rlang::expr(sum(!!sym)),
      mean = rlang::expr(mean(!!sym)),
      weighted_mean = if (has_weight) {
        rlang::expr(dplyr::if_else(
          sum(!!rlang::sym("weight")) > 0,
          sum(!!sym * !!rlang::sym("weight")) / sum(!!rlang::sym("weight")),
          mean(!!sym)))
      } else {
        rlang::expr(mean(!!sym))
      },
      copy = rlang::expr(mean(!!sym)),
      sd = rlang::expr(stats::sd(!!sym)),
      .stop("Unknown rule: %s", rules[[v]])
    )
  }
  copy_cols <- values[rules == "copy"]
  if (length(copy_cols) > 0L) {
    chk <- .ts_pull(
      joined |>
        dplyr::group_by(dplyr::across(dplyr::all_of(grp_cols))) |>
        dplyr::summarise(dplyr::across(
          dplyr::all_of(copy_cols), list(mx = ~ max(.x), mn = ~ min(.x))),
          .groups = "drop"))
    for (v in copy_cols) {
      rng <- chk[[paste0(v, "_mx")]] - chk[[paste0(v, "_mn")]]
      if (any(!is.na(rng) & rng > 1e-9)) {
        stop(sprintf(
          paste0("rule \"copy\" for `%s`: values are not constant within ",
                 "a target timeslice"), v), call. = FALSE)
      }
    }
  }

  res <- joined |>
    dplyr::group_by(dplyr::across(dplyr::all_of(grp_cols))) |>
    dplyr::summarise(!!!exprs, .groups = "drop") |>
    dplyr::rename(timeslice = !!rlang::sym(".ts_to"),
                  year = !!rlang::sym(".ts_year"))

  if (.ts_is_lazy(backend) && !isTRUE(collect)) {
    return(dplyr::select(res,
      dplyr::all_of(c("timeslice", "year", id_cols, values))))
  }

  res <- as.data.frame(dplyr::collect(res))
  # Drop the all-NA year rows that a "keep" NA-timeslice group produces
  res <- res[!is.na(res$year) | !is.na(res$timeslice) |
               na_action == "keep", , drop = FALSE]
  res <- res[, c("timeslice", "year", id_cols, values), drop = FALSE]
  res <- res[order(res$year, match(res$timeslice,
                                   S7::prop(calendar, "leaftable")$timeslice),
                   na.last = TRUE), , drop = FALSE]
  rownames(res) <- NULL
  .ts_restore(res, backend, collect = collect)
}

# -----------------------------------------------------------------------------
# recast() generic
# -----------------------------------------------------------------------------

#' Recast data between scales
#'
#' The pipeline verb of the *scales family: convert `x` between two
#' resolutions of one dimension, dispatching on the scale object given
#' as `from` -- a [Calendar] here; a `Geoscale` when the geoscales
#' package is loaded (which registers its own method). This lets one
#' verb chain across dimensions:
#'
#' ```r
#' x |>
#'   recast(cal_hourly, cal_monthly, year = 2021) |>
#'   recast(gs, to = "country")
#' ```
#'
#' The explicit per-package workers remain available:
#' [`recast_calendar()`] and `geoscales::recast_geoscale()`.
#'
#' @param x The data to convert, in any supported backend.
#' @param from The source scale object (here: the source [Calendar]).
#' @param ... Passed to the dispatched worker; for the Calendar method
#'   the arguments of [`recast_calendar()`] (`to`, `year`, `key`,
#'   `values`, `rule`, `by`, `tz`, `na_action`, `collect`).
#' @return The converted data (see the worker's documentation).
#' @export
recast <- S7::new_generic("recast", dispatch_args = c("x", "from"))

S7::method(recast, list(S7::class_any, Calendar)) <-
  function(x, from, to, year,
           key = NULL, values = NULL, rule = NULL, by = NULL,
           tz = "UTC", na_action = c("drop", "error", "keep"),
           collect = NULL, ...) {
    recast_calendar(x, from = from, to = to, year = year, key = key,
                    values = values, rule = rule, by = by, tz = tz,
                    na_action = na_action, collect = collect)
  }
