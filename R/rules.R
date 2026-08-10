# =============================================================================
# Recast rule + pairwise conversion registries
# =============================================================================
# Mirrors `geoscales/R/rules.R` (which itself mirrors the token registry in
# `R/tokens.R`): package-level environments consulted by `calendar_recast()` when the
# caller does not pass `rule=`. An explicit argument always wins.
#
# Two registries live here:
#   * .RULE_REGISTRY       — value-column name -> aggregation rule
#   * .CONVERSION_REGISTRY — "fromName->toName" -> custom conversion function,
#                            the pairwise override for the A -> base -> B route
# =============================================================================

#' Supported aggregation rules
#'
#' Each rule defines behaviour in **both** directions of the instant grid, so
#' aggregation and disaggregation are one operation (the geoscales split of
#' extensive vs intensive quantities):
#'
#' \describe{
#'   \item{`weighted_mean`}{Down: copy. Up: mean weighted by the declared
#'     `leaves$share` of each source slice. For intensive quantities
#'     (load, price, efficiency). The default.}
#'   \item{`sum`}{Down: split equally across the slice's grid instants.
#'     Up: sum. Conserves totals; for extensive quantities (energy, cost).}
#'   \item{`mean`}{Down: copy. Up: plain mean over instants — a time-weighted
#'     mean, since the grid is uniform. Differs from `weighted_mean` exactly
#'     when declared shares differ from real-time coverage.}
#'   \item{`copy`}{Down: copy. Up: the common value, erroring if it is not
#'     constant. For slice-invariant scalars.}
#'   \item{`sd`}{Up: standard deviation over instants — the spread of the
#'     fine signal within each target slice. Aggregation-only; going finer it
#'     degenerates to 0/NA.}
#' }
#'
#' @format A character vector of length 5.
#' @examples
#' RECAST_RULES
#' @export
RECAST_RULES <- c("weighted_mean", "sum", "mean", "copy", "sd")

#' Supported alignment rules
#'
#' Alignment declares how real Gregorian instants that fall outside a
#' calendar's vocabulary map onto it — a separate axis from aggregation
#' (conflating the two is how a non-conserving `sum` arises). Resurrects the
#' `alignment_rule` vocabulary of the predecessor `timeslices` package.
#'
#' \describe{
#'   \item{`exact`}{Error if any instant falls outside the vocabulary.}
#'   \item{`drop_last`}{Instants past the last label map to `NA` (e.g. the
#'     trailing days of the year for `d360`).}
#'   \item{`drop_feb29`}{Feb 29 maps to `NA`; later ydays shift down by one,
#'     so Dec 31 of a leap year is still `d365`.}
#'   \item{`repeat_last`}{Instants past the last label clamp to it (e.g.
#'     week 53 folds into `w52`).}
#' }
#'
#' Alignment lives per-timeframe in a calendar's `meta$alignment` (a named
#' list), seeded by the tokens that built it and overridable at construction
#' or in [`instant_to_slice()`]. Unaligned out-of-vocabulary instants map to
#' `NA`, surfaced by `calendar_recast()`'s `na_action`.
#'
#' @format A character vector of length 4.
#' @examples
#' ALIGNMENT_RULES
#' @export
ALIGNMENT_RULES <- c("exact", "drop_last", "drop_feb29", "repeat_last")

#' @noRd
.RULE_REGISTRY <- new.env(parent = emptyenv())

#' @noRd
.CONVERSION_REGISTRY <- new.env(parent = emptyenv())

# Per-parameter rules ----------------------------------------------------------

#' Register how a parameter should be recast
#'
#' Records the aggregation rule to use for a named value column, so callers
#' of [`calendar_recast()`] need not repeat it. Downstream packages can register their
#' own parameter maps at load time. An explicit `rule=` argument to
#' [`calendar_recast()`] always wins; unregistered columns default to
#' `"weighted_mean"`.
#'
#' @param param Name of the value column.
#' @param rule One of [`RECAST_RULES`].
#'
#' @return Invisibly, the registered entry.
#'
#' @examples
#' register_rule("energy", "sum")
#' register_rule("price", "weighted_mean")
#' get_rule("energy")
#' @export
register_rule <- function(param, rule) {
  if (!is.character(param) || length(param) != 1L || is.na(param) ||
      !nzchar(param)) {
    stop("`param` must be a single non-empty string", call. = FALSE)
  }
  rule <- match.arg(rule, RECAST_RULES)
  entry <- list(rule = rule)
  assign(param, entry, envir = .RULE_REGISTRY)
  invisible(entry)
}

#' Look up a registered rule
#'
#' @param param Name of the value column.
#'
#' @return A list with element `rule`, or `NULL` if `param` has not been
#'   registered.
#'
#' @examples
#' register_rule("demand", "sum")
#' get_rule("demand")
#' get_rule("not_registered")
#' @export
get_rule <- function(param) {
  if (!is.character(param) || length(param) != 1L) return(NULL)
  if (!exists(param, envir = .RULE_REGISTRY, inherits = FALSE)) return(NULL)
  get(param, envir = .RULE_REGISTRY, inherits = FALSE)
}

#' List registered rules
#'
#' @return A `data.frame` with columns `param` and `rule`.
#'
#' @examples
#' register_rule("invcost", "weighted_mean")
#' list_rules()
#' @export
list_rules <- function() {
  nms <- sort(ls(envir = .RULE_REGISTRY, all.names = FALSE))
  data.frame(
    param = nms,
    rule  = vapply(nms, function(p) get_rule(p)$rule, character(1),
                   USE.NAMES = FALSE),
    stringsAsFactors = FALSE
  )
}

#' Clear the rule registry
#'
#' Mainly useful in tests.
#'
#' @param param Optional character vector of names to remove. `NULL` (default)
#'   clears everything.
#'
#' @return Invisibly `NULL`.
#'
#' @examples
#' register_rule("tmp_param", "sum")
#' clear_rules("tmp_param")
#' @export
clear_rules <- function(param = NULL) {
  if (is.null(param)) {
    rm(list = ls(envir = .RULE_REGISTRY, all.names = TRUE),
       envir = .RULE_REGISTRY)
  } else {
    present <- intersect(param, ls(envir = .RULE_REGISTRY, all.names = TRUE))
    if (length(present) > 0L) rm(list = present, envir = .RULE_REGISTRY)
  }
  invisible(NULL)
}

# Pairwise conversion overrides ------------------------------------------------

#' Register a pairwise calendar conversion override
#'
#' By default [`calendar_recast()`] routes every conversion through the shared instant
#' grid (`A -> base -> B`). A registered override short-circuits that route
#' for one named calendar pair — the escape hatch for exact nested-calendar
#' arithmetic or anything the grid cannot express.
#'
#' @param from,to Calendar names (`meta$name`) the override applies to.
#' @param fun A function with signature `fun(x, from, to, ...)` receiving the
#'   same arguments as [`calendar_recast()`] and returning the recast `data.frame`.
#'   `NULL` removes a previously registered override.
#'
#' @return Invisibly, the registry key (`"from->to"`).
#'
#' @examples
#' register_conversion("m12", "q4", function(x, from, to, ...) {
#'   # trivial exact nesting: quarters are consecutive month triples
#'   q <- rep(sprintf("Q%d", 1:4), each = 3)
#'   stats::aggregate(x[-1], list(slice = q[match(x$slice,
#'     S7::prop(from, "leaves")$slice)]), sum)
#' })
#' "m12->q4" %in% list_conversions()$key
#' clear_conversions()
#' @export
register_conversion <- function(from, to, fun) {
  for (nm in c(from, to)) {
    if (!is.character(nm) || length(nm) != 1L || is.na(nm) || !nzchar(nm)) {
      stop("`from` and `to` must be single non-empty calendar names",
           call. = FALSE)
    }
  }
  key <- paste0(from, "->", to)
  if (is.null(fun)) {
    if (exists(key, envir = .CONVERSION_REGISTRY, inherits = FALSE)) {
      rm(list = key, envir = .CONVERSION_REGISTRY)
    }
    return(invisible(key))
  }
  if (!is.function(fun)) {
    stop("`fun` must be a function(x, from, to, ...) or NULL", call. = FALSE)
  }
  assign(key, fun, envir = .CONVERSION_REGISTRY)
  invisible(key)
}

#' @rdname register_conversion
#' @return `get_conversion()` returns the registered function or `NULL`.
#' @export
get_conversion <- function(from, to) {
  key <- paste0(from, "->", to)
  if (!exists(key, envir = .CONVERSION_REGISTRY, inherits = FALSE)) {
    return(NULL)
  }
  get(key, envir = .CONVERSION_REGISTRY, inherits = FALSE)
}

#' @rdname register_conversion
#' @return `list_conversions()` returns a `data.frame` with column `key`.
#' @export
list_conversions <- function() {
  data.frame(key = sort(ls(envir = .CONVERSION_REGISTRY, all.names = FALSE)),
             stringsAsFactors = FALSE)
}

#' @rdname register_conversion
#' @param key Optional character vector of `"from->to"` keys to remove;
#'   `NULL` (default) clears everything.
#' @export
clear_conversions <- function(key = NULL) {
  if (is.null(key)) {
    rm(list = ls(envir = .CONVERSION_REGISTRY, all.names = TRUE),
       envir = .CONVERSION_REGISTRY)
  } else {
    present <- intersect(key,
                         ls(envir = .CONVERSION_REGISTRY, all.names = TRUE))
    if (length(present) > 0L) rm(list = present, envir = .CONVERSION_REGISTRY)
  }
  invisible(NULL)
}
