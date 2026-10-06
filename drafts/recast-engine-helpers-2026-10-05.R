# Archived 2026-10-05 from R/recast.R: recast_calendar() now aggregates
# through multiscales::recast_crosswalk(), which carries the same rule
# expressions and folds the copy-constancy check into its summarise.

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

