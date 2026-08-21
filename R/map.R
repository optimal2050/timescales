# =============================================================================
# calendar_map() -- the crosswalk between two calendars on the base grid
# =============================================================================
# The A -> base -> B route, collapsed once into a small in-memory table: one
# row per (year, from-timeslice, to-timeslice) overlap, carrying the grid
# counts and share weights every recast rule needs. `recast_calendar()` is a
# join against this table plus one grouped summarise, which is what lets the
# converters run unchanged over data.frame / data.table / arrow backends --
# the data never has to be exploded to grid resolution.
#
# Maps are memoised by (from-name, to-name, years, by, tz). Calendars are
# treated as immutable values: mutating or renaming a Calendar after mapping
# leaves stale cache entries behind, exactly as with the pairwise conversion
# registry.
# =============================================================================

#' @noRd
.MAP_CACHE <- new.env(parent = emptyenv())

#' @noRd
.MAP_REGISTRY <- new.env(parent = emptyenv())

#' Crosswalk between two calendars over the base grid
#'
#' Materialises the `A -> base -> B` route as a table: for the requested
#' model year(s), one row per pair of overlapping timeslices with
#'
#' * `n_from` -- grid points in the `from` timeslice (its full set, before
#'   any target coverage is considered),
#' * `n_overlap` -- grid points the pair shares,
#' * `w` -- the share weight of the overlap
#'   (`leaves$share[from] * n_overlap / n_from`), the quantity
#'   `"weighted_mean"` aggregation uses.
#'
#' The two label columns are named by the calendars' names (so the map
#' joins directly onto datasets labelled by [`join_calendar()`]); rows with
#' an `NA` target label are grid points `to` does not cover. A crosswalk
#' registered with [`register_calendar_map()`] is returned as-is instead of
#' being derived from the grid.
#'
#' @param from,to [`Calendar`] objects (both must be named).
#' @param year Integer vector of model year(s); multi-year maps carry all
#'   years in the `year` column.
#' @param by Grid resolution (`seq.POSIXt` step). Default: the finest
#'   timeframe of the two calendars.
#' @param tz Time zone of the grid. Default `"UTC"`.
#'
#' @return A `data.frame` with columns `year`, `<from name>`, `<to name>`
#'   (`NA` = uncovered by `to`), `n_from`, `n_overlap`, `w`.
#'
#' @examples
#' m12 <- calendar_build("m12")
#' q4  <- calendar_build("q4")
#' calendar_map(m12, q4, year = 2021)
#' @export
calendar_map <- function(from, to, year, by = NULL, tz = "UTC") {
  .check_calendar(from, "from")
  .check_calendar(to, "to")
  from_nm <- .calendar_name(from, arg = "from")
  to_nm   <- .calendar_name(to, arg = "to")
  if (identical(from_nm, to_nm)) {
    .stop(paste0("`from` and `to` have the same name (\"%s\"); the map's ",
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
    .stop("the grid produced no overlap between `from` and `to`")
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

#' Register / look up a direct calendar crosswalk
#'
#' A registered map short-circuits the base-grid derivation in
#' [`calendar_map()`] (and thereby [`recast_calendar()`]) for one calendar
#' pair -- the table analogue of the functional override in
#' [`register_conversion()`], for cases where the exact correspondence is
#' known (provably nested calendars, hand-audited crosswalks).
#'
#' @param from,to Calendar names (`meta$name`) the map applies to, or
#'   [`Calendar`] objects (their names are used).
#' @param map A `data.frame` shaped like a [`calendar_map()`] result: the
#'   two label columns named after `from` and `to`, plus `year`, `n_from`,
#'   `n_overlap` and `w`. `NULL` removes a previously registered map.
#'
#' @return Invisibly, the registry key (`"from->to"`).
#' @export
register_calendar_map <- function(from, to, map) {
  nm_of <- function(z, arg) {
    if (is.character(z) && length(z) == 1L && nzchar(z)) return(z)
    .check_calendar(z, arg)
    .calendar_name(z, arg = arg)
  }
  from_nm <- nm_of(from, "from")
  to_nm   <- nm_of(to, "to")
  key <- paste0(from_nm, "->", to_nm)
  if (is.null(map)) {
    if (exists(key, envir = .MAP_REGISTRY, inherits = FALSE)) {
      rm(list = key, envir = .MAP_REGISTRY)
    }
    return(invisible(key))
  }
  if (!is.data.frame(map)) {
    .stop("`map` must be a data.frame (see `calendar_map()`) or NULL")
  }
  need <- c("year", from_nm, to_nm, "n_from", "n_overlap", "w")
  miss <- setdiff(need, names(map))
  if (length(miss) > 0L) {
    .stop("`map` is missing column(s): %s", .preview(miss))
  }
  assign(key, as.data.frame(map), envir = .MAP_REGISTRY)
  invisible(key)
}

#' @noRd
.get_calendar_map <- function(from_nm, to_nm) {
  key <- paste0(from_nm, "->", to_nm)
  if (!exists(key, envir = .MAP_REGISTRY, inherits = FALSE)) {
    return(NULL)
  }
  get(key, envir = .MAP_REGISTRY, inherits = FALSE)
}

#' Clear the crosswalk cache (and optionally the registered maps)
#'
#' Mainly useful in tests, or after mutating a Calendar object in place
#' (maps are memoised by calendar NAME).
#'
#' @param registry Also clear maps registered with
#'   [`register_calendar_map()`]. Default `FALSE`.
#' @return Invisibly `NULL`.
#' @export
clear_calendar_maps <- function(registry = FALSE) {
  rm(list = ls(envir = .MAP_CACHE, all.names = TRUE), envir = .MAP_CACHE)
  if (isTRUE(registry)) {
    rm(list = ls(envir = .MAP_REGISTRY, all.names = TRUE),
       envir = .MAP_REGISTRY)
  }
  invisible(NULL)
}
