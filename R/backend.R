# =============================================================================
# Backend handling for the conversion verbs
# =============================================================================
# The converters (recast_calendar, recast_to_timebase, recast_from_timebase,
# join_calendar) are written on dplyr verbs only, so the SAME pipeline runs
# on an in-memory data.frame/tibble, a data.table (through dtplyr), and an
# arrow Dataset/query. Contract:
#
#   data.frame  -> data.frame          (computed)
#   tibble      -> tibble              (computed)
#   data.table  -> data.table          (computed)
#   dtplyr/arrow (lazy) -> the UNCOLLECTED query, unless collect = TRUE
#
# The calendar side of every join (grids, crosswalks, leaf attributes) is a
# small in-memory frame, so lazy inputs never have to be materialised for
# the calendar arithmetic; only cheap aggregates (distinct keys / years,
# `copy`-rule guards) are collected eagerly.
# =============================================================================

# dtplyr generates data.table syntax that is evaluated with THIS package as
# the calling namespace; without this flag data.table's cedta() check makes
# `[.data.table` fall through to `[.data.frame` and the joins break.
.datatable.aware <- TRUE

# Internal working columns referenced as bare symbols inside dplyr verbs
# (bare symbols, not `.data[[...]]`, because dtplyr and arrow mistranslate
# pronoun subsetting) -- declared so R CMD check knows they are data masks.
utils::globalVariables(c(".ts_to", ".ts_y", ".ts_f", ".ts_n_from",
                         ".ts_n_overlap", ".ts_w", ".ts_label",
                         ".ts_year"))

#' Which backend does `x` belong to?
#' @noRd
.ts_backend <- function(x) {
  if (inherits(x, c("arrow_dplyr_query", "ArrowObject", "Dataset",
                    "ArrowTabular", "RecordBatchReader"))) {
    return("arrow")
  }
  if (inherits(x, "dtplyr_step")) return("dtplyr")
  if (inherits(x, "data.table")) return("data.table")
  if (inherits(x, "tbl_df")) return("tibble")
  if (is.data.frame(x)) return("data.frame")
  NA_character_
}

#' Is this backend lazy (query-producing)?
#' @noRd
.ts_is_lazy <- function(backend) backend %in% c("arrow", "dtplyr")

#' Lift `x` into a dplyr-compatible carrier for the pipeline
#' @noRd
.ts_lazy <- function(x, backend) {
  if (backend == "data.table") {
    if (!requireNamespace("dtplyr", quietly = TRUE)) {
      # dplyr verbs work on a bare data.table too (it is a data.frame);
      # dtplyr just makes them translate to data.table code
      return(x)
    }
    return(dtplyr::lazy_dt(x))
  }
  x
}

#' A zero-row, correctly typed frame describing `x`'s columns
#' @noRd
.ts_schema <- function(x) {
  as.data.frame(dplyr::collect(utils::head(x, 0L)))
}

#' Column names of any backend
#' @noRd
.ts_names <- function(x) {
  names(.ts_schema(x))
}

#' Cheap eager evaluation of a small aggregate over any backend
#' @noRd
.ts_pull <- function(q) {
  as.data.frame(dplyr::collect(q))
}

#' Return `out` (a pipeline result over `x`) in `x`'s own format
#'
#' Lazy inputs stay lazy unless `collect = TRUE`; eager inputs are always
#' computed back to their class.
#' @noRd
.ts_restore <- function(out, backend, collect = NULL) {
  lazy <- .ts_is_lazy(backend)
  if (lazy && !isTRUE(collect)) {
    return(out)
  }
  res <- dplyr::collect(out)
  switch(backend,
    "data.table" = if (requireNamespace("data.table", quietly = TRUE)) {
      data.table::as.data.table(res)
    } else as.data.frame(res),
    "tibble" = if (requireNamespace("tibble", quietly = TRUE)) {
      tibble::as_tibble(res)
    } else as.data.frame(res),
    "arrow" = res,
    "dtplyr" = if (requireNamespace("data.table", quietly = TRUE)) {
      data.table::as.data.table(res)
    } else as.data.frame(res),
    as.data.frame(res)
  )
}
