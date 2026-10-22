# =============================================================================
# calendar_map() / calendar_map_between() -- the crosswalk tables
# =============================================================================
# Two functions, one per shape:
#   * calendar_map(x, from, to) -- between two timeframes of ONE calendar,
#     derived by the shared core from the calendar's own atom layer;
#   * calendar_map_between(from, to, year) -- between TWO calendars, the
#     A -> base grid -> B route collapsed once into a small in-memory table:
#     one row per (year, from-timeslice, to-timeslice) overlap, carrying the
#     grid counts and share weights every recast rule needs.
# `recast_calendar()` is a join against the between-table plus one grouped
# summarise, which is what lets the converters run unchanged over
# data.frame / data.table / arrow backends -- the data never has to be
# exploded to grid resolution.
#
# Between-maps are memoised by (from-name, to-name, years, by, tz). Calendars
# are treated as immutable values: mutating or renaming a Calendar after
# mapping leaves stale cache entries behind, exactly as with the pairwise
# conversion registry.
# =============================================================================

#' @noRd
.MAP_CACHE <- new.env(parent = emptyenv())

#' @noRd
.MAP_REGISTRY <- new.env(parent = emptyenv())

#' Crosswalk between two timeframes of a calendar
#'
#' Materialises the `from -> timeslices -> to` route within one calendar as
#' a table: one row per pair of overlapping units with `n_from` (timeslices
#' in the `source` unit), `n_overlap` (timeslices the pair shares), `w` (the
#' weight of the overlap) and `w_from` (the full weight of the `source` unit).
#' The two label columns are named by the timeframes. A crosswalk registered
#' with [`register_calendar_map()`] is returned as-is instead of being
#' derived.
#'
#' @param x The [`Calendar`] the timeframes belong to.
#' @param source,target Timeframe names of `x`.
#' @param from,to Deprecated names of `source` and `target`.
#' @param weight Weight column for `w`. `NULL` uses the calendar's default
#'   weight; when it declares none, every timeslice gets weight 1.
#' @param ... Passed to the shared core, e.g. `by =` for extra identifier
#'   columns.
#'
#' @return A `data.frame` with columns `<source>`, `<target>` (`NA` = uncovered by
#'   `target`), `n_from`, `n_overlap`, `w`, `w_from`.
#'
#' @seealso [`calendar_map_between()`] for the map between two calendars.
#' @examples
#' cal <- calendar("m12_h24")
#' head(calendar_map(cal, "MONTH", "HOUR"))
#' @export
calendar_map <- function(x, source, target, weight = NULL, ...,
                         from = lifecycle::deprecated(), to = lifecycle::deprecated()) {
  if (lifecycle::is_present(from)) {
    .arg_renamed("calendar_map", "from", "source", !missing(source))
    source <- from
  }
  if (lifecycle::is_present(to)) {
    .arg_renamed("calendar_map", "to", "target", !missing(target))
    target <- to
  }
  from <- source
  to <- target
  if (S7::S7_inherits(from, Calendar) || S7::S7_inherits(to, Calendar)) {
    .stop(paste0("`source` and `target` are timeframe names of `x`; for the map ",
                 "between two calendars use `calendar_map_between()`"))
  }
  .check_calendar(x, "x")
  .check_timeframe(x, from, "source")
  .check_timeframe(x, to, "target")
  nestedscales::scale_map(x, from, to, weight = weight, ...)
}

#' Crosswalk between two calendars over the base grid
#'
#' Materialises the `A -> base -> B` route as a table: for the requested
#' model year(s), one row per pair of overlapping timeslices with
#'
#' * `n_from` -- grid points in the `source` timeslice (its full set, before
#'   any target coverage is considered),
#' * `n_overlap` -- grid points the pair shares,
#' * `w` -- the share weight of the overlap
#'   (`leaves$share[from] * n_overlap / n_from`), the quantity
#'   `"weighted_mean"` aggregation uses.
#'
#' The two label columns are named by the calendars' names (so the map
#' joins directly onto datasets labelled by [`join_calendar()`]); rows with
#' an `NA` target label are grid points `target` does not cover. A crosswalk
#' registered with [`register_calendar_map_between()`] is returned as-is
#' instead of being derived from the grid.
#'
#' @param source,target [`Calendar`] objects (both must be named).
#' @param from,to Deprecated names of `source` and `target`.
#' @param year Integer vector of model year(s); multi-year maps carry all
#'   years in the `year` column.
#' @param by Grid resolution (`seq.POSIXt` step). Default: the finest
#'   timeframe of the two calendars.
#' @param tz Time zone of the grid. Default `"UTC"`.
#'
#' @return A `data.frame` with columns `year`, `<source name>`, `<target name>`
#'   (`NA` = uncovered by `target`), `n_from`, `n_overlap`, `w`.
#'
#' @seealso [`calendar_map()`] for the map between two timeframes of one
#'   calendar.
#' @examples
#' m12 <- calendar_build("m12")
#' q4  <- calendar_build("q4")
#' calendar_map_between(m12, q4, year = 2021)
#' @export
calendar_map_between <- function(source, target, year, by = NULL, tz = "UTC",
                                 from = lifecycle::deprecated(), to = lifecycle::deprecated()) {
  if (lifecycle::is_present(from)) {
    .arg_renamed("calendar_map_between", "from", "source", !missing(source))
    source <- from
  }
  if (lifecycle::is_present(to)) {
    .arg_renamed("calendar_map_between", "to", "target", !missing(target))
    target <- to
  }
  from <- source
  to <- target
  .check_calendar(from, "source")
  .check_calendar(to, "target")
  from_nm <- .calendar_name(from, arg = "source")
  to_nm   <- .calendar_name(to, arg = "target")
  if (identical(from_nm, to_nm)) {
    .stop(paste0("`source` and `target` have the same name (\"%s\"); the map's ",
                 "label columns are named by the calendars -- rename one"),
          from_nm)
  }
  year <- as.integer(year)
  if (length(year) == 0L || anyNA(year)) {
    .stop("`year` must be one or more integers")
  }
  if (is.null(by)) {
    by <- .default_step(union(S7::prop(from, "timeframes"),
                              S7::prop(to, "timeframes")))
  }

  reg <- .get_calendar_map(from_nm, to_nm)
  if (!is.null(reg)) {
    return(reg)
  }

  ck <- paste(from_nm, to_nm, paste(year, collapse = ","), by, tz,
              sep = "\r")
  hit <- .MAP_CACHE[[ck]]
  if (!is.null(hit)) {
    return(hit)
  }

  from_leaves <- S7::prop(from, "leaftable")
  share_map <- stats::setNames(from_leaves$share, from_leaves$timeslice)

  chunks <- lapply(year, function(y) {
    dtm <- .model_year_datetimes(from, y, by, tz)
    s_from <- datetime_to_timeslice(dtm, from)
    s_to   <- datetime_to_timeslice(dtm, to)
    ok <- !is.na(s_from)
    s_from <- s_from[ok]
    s_to   <- s_to[ok]
    if (length(s_from) == 0L) {
      return(NULL)
    }
    d <- data.frame(from = s_from, to = s_to, stringsAsFactors = FALSE)
    d |>
      dplyr::count(.data$from, .data$to, name = "n_overlap") |>
      dplyr::mutate(year = y) |>
      as.data.frame()
  })
  map <- do.call(rbind, Filter(Negate(is.null), chunks))
  if (is.null(map) || nrow(map) == 0L) {
    .stop("the grid produced no overlap between `source` and `target`")
  }
  map <- map |>
    dplyr::group_by(.data$year, .data$from) |>
    dplyr::mutate(n_from = sum(.data$n_overlap)) |>
    dplyr::ungroup() |>
    dplyr::mutate(
      w = as.numeric(share_map[.data$from]) * .data$n_overlap / .data$n_from
    ) |>
    as.data.frame()
  map <- map[, c("year", "from", "to", "n_from", "n_overlap", "w"),
             drop = FALSE]
  names(map)[names(map) == "from"] <- from_nm
  names(map)[names(map) == "to"]   <- to_nm

  .MAP_CACHE[[ck]] <- map
  map
}

# Registry ---------------------------------------------------------------------

#' Register / look up a direct calendar crosswalk
#'
#' A registered map short-circuits the derivation in [`calendar_map()`] or
#' [`calendar_map_between()`] (and thereby [`recast_calendar()`]) for one
#' pair of resolutions -- the table analogue of the functional override in
#' [`register_calendar_conversion()`], for cases where the exact
#' correspondence is known (provably nested calendars, hand-audited
#' crosswalks).
#'
#' `register_calendar_map()` and `get_calendar_map()` handle a pair of
#' timeframes of one calendar; the map is scoped to that calendar, so the
#' same timeframe pair in two calendars does not collide.
#' `register_calendar_map_between()` and `get_calendar_map_between()` handle
#' a pair of calendars.
#'
#' @param x The [`Calendar`] the timeframes belong to, or its name.
#' @param source,target For the within-calendar functions, timeframe names of `x`.
#' @param from,to Deprecated names of `source` and `target`.
#'   For the `_between` functions, two [`Calendar`] objects or their names
#'   (`meta$name`).
#' @param map A `data.frame` shaped like the corresponding map result: the
#'   two label columns named after the timeframes (plus `n_from`,
#'   `n_overlap`, `w`, `w_from`) or after the calendars (plus `year`,
#'   `n_from`, `n_overlap`, `w`). `NULL` removes a previously registered map.
#'
#' @return Invisibly, the registry key. The `get_` functions return the
#'   registered map (or `NULL`).
#'
#' @examples
#' between <- calendar_map_between(calendar("m12"), calendar("q4"), year = 2021)
#' register_calendar_map_between("m12", "q4", between)
#' get_calendar_map_between("m12", "q4")
#' list_calendar_maps()
#' register_calendar_map_between("m12", "q4", NULL)   # remove again
#'
#' cal <- calendar("m12_h24")
#' within <- calendar_map(cal, "MONTH", "HOUR")
#' register_calendar_map(cal, "MONTH", "HOUR", within)
#' identical(get_calendar_map(cal, "MONTH", "HOUR"), within)
#' clear_calendar_maps(registry = TRUE)
#' @export
register_calendar_map <- function(x, source, target, map,
                                  from = lifecycle::deprecated(), to = lifecycle::deprecated()) {
  if (lifecycle::is_present(from)) {
    .arg_renamed("register_calendar_map", "from", "source", !missing(source))
    source <- from
  }
  if (lifecycle::is_present(to)) {
    .arg_renamed("register_calendar_map", "to", "target", !missing(target))
    target <- to
  }
  from <- source
  to <- target
  if (!is.character(x)) .check_calendar(x, "x")
  nestedscales::register_scale_map(x, from, to, map)
}

#' @rdname register_calendar_map
#' @export
register_calendar_map_between <- function(source, target, map,
                                          from = lifecycle::deprecated(), to = lifecycle::deprecated()) {
  if (lifecycle::is_present(from)) {
    .arg_renamed("register_calendar_map_between", "from", "source", !missing(source))
    source <- from
  }
  if (lifecycle::is_present(to)) {
    .arg_renamed("register_calendar_map_between", "to", "target", !missing(target))
    target <- to
  }
  from <- source
  to <- target
  from_nm <- .map_name_of(from, "source")
  to_nm   <- .map_name_of(to, "target")
  key <- paste0(from_nm, "->", to_nm)
  if (is.null(map)) {
    if (exists(key, envir = .MAP_REGISTRY, inherits = FALSE)) {
      rm(list = key, envir = .MAP_REGISTRY)
    }
    return(invisible(key))
  }
  if (!is.data.frame(map)) {
    .stop("`map` must be a data.frame (see `calendar_map_between()`) or NULL")
  }
  need <- c("year", from_nm, to_nm, "n_from", "n_overlap", "w")
  miss <- setdiff(need, names(map))
  if (length(miss) > 0L) {
    .stop("`map` is missing column(s): %s", .preview(miss))
  }
  assign(key, as.data.frame(map), envir = .MAP_REGISTRY)
  invisible(key)
}

#' A Calendar's name, or a name given directly
#' @noRd
.map_name_of <- function(z, arg) {
  if (is.character(z) && length(z) == 1L && nzchar(z)) return(z)
  .check_calendar(z, arg)
  .calendar_name(z, arg = arg)
}

#' @noRd
.get_calendar_map <- function(from_nm, to_nm) {
  key <- paste0(from_nm, "->", to_nm)
  if (!exists(key, envir = .MAP_REGISTRY, inherits = FALSE)) {
    return(NULL)
  }
  get(key, envir = .MAP_REGISTRY, inherits = FALSE)
}

#' @rdname register_calendar_map
#' @export
get_calendar_map <- function(x, source, target,
                             from = lifecycle::deprecated(), to = lifecycle::deprecated()) {
  if (lifecycle::is_present(from)) {
    .arg_renamed("get_calendar_map", "from", "source", !missing(source))
    source <- from
  }
  if (lifecycle::is_present(to)) {
    .arg_renamed("get_calendar_map", "to", "target", !missing(target))
    target <- to
  }
  from <- source
  to <- target
  if (!is.character(x)) .check_calendar(x, "x")
  nestedscales::get_scale_map(x, from, to)
}

#' @rdname register_calendar_map
#' @export
get_calendar_map_between <- function(source, target,
                                     from = lifecycle::deprecated(), to = lifecycle::deprecated()) {
  if (lifecycle::is_present(from)) {
    .arg_renamed("get_calendar_map_between", "from", "source", !missing(source))
    source <- from
  }
  if (lifecycle::is_present(to)) {
    .arg_renamed("get_calendar_map_between", "to", "target", !missing(target))
    target <- to
  }
  from <- source
  to <- target
  .get_calendar_map(.map_name_of(from, "source"), .map_name_of(to, "target"))
}

#' List the registered crosswalks
#'
#' @return A `data.frame` with one row per registered map, between calendars
#'   (`"from->to"`) and within one (`"calendar:from->to"`): `key`, `from`,
#'   `to`. Zero rows when none are registered (mirrors
#'   `geoscales::list_geoscale_maps()`).
#' @export
#'
#' @examples
#' list_calendar_maps()
list_calendar_maps <- function() {
  keys <- c(sort(ls(envir = .MAP_REGISTRY, all.names = TRUE)),
            nestedscales::list_scale_maps()$key)
  parts <- strsplit(sub("^[^:]*:", "", keys), "->", fixed = TRUE)
  data.frame(
    key  = keys,
    from = vapply(parts, `[`, "", 1),
    to   = vapply(parts, `[`, "", 2),
    stringsAsFactors = FALSE
  )
}

#' Clear the crosswalk cache (and optionally the registered maps)
#'
#' Mainly useful in tests, or after mutating a Calendar object in place
#' (between-maps are memoised by calendar NAME).
#'
#' @param registry Also clear the maps registered with
#'   [`register_calendar_map()`] and [`register_calendar_map_between()`].
#'   Default `FALSE`.
#' @return Invisibly `NULL`.
#' @export
#'
#' @examples
#' clear_calendar_maps()                 # drop the memo cache only
#' clear_calendar_maps(registry = TRUE)  # ... and the registered maps
clear_calendar_maps <- function(registry = FALSE) {
  rm(list = ls(envir = .MAP_CACHE, all.names = TRUE), envir = .MAP_CACHE)
  if (isTRUE(registry)) {
    rm(list = ls(envir = .MAP_REGISTRY, all.names = TRUE),
       envir = .MAP_REGISTRY)
    nestedscales::clear_scale_maps()
  }
  invisible(NULL)
}
