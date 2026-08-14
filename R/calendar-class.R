# =============================================================================
# Calendar (S7 class) — slim core type
# =============================================================================
# A `Calendar` is a nested time partition of a (model) year:
#
#   * `leaves`     — flat enumeration of leaf timeslices, with one column per
#                    timeframe in the hierarchy plus `timeslice`, `share`, `weight`
#   * `timeframes` — ordered character vector naming the hierarchy, coarsest
#                    first (e.g. `c("MONTH", "MDAY", "HOUR")`)
#   * `levels`     — named list giving the full ordered token vocabulary at
#                    each timeframe (e.g. `levels$MONTH = c("m01", ..., "m12")`)
#   * `meta`       — small named list of model-level attributes:
#                      * `name`, `desc`            character
#                      * `year_start`              list(month, day)
#                      * `utc_offset_minutes`      single integer
#                      * `year_fraction`           numeric, default 1
#
# Anything that can be derived from these (composite IDs, parent/child tables,
# regularity classification, ...) is computed on demand by separate functions.
# Nothing is cached on the object.
# =============================================================================

#' Calendar (S7 class)
#'
#' A nested time partition: a flat table of weighted leaf timeslices plus the
#' ordered hierarchy of timeframes that produced them.
#'
#' Construct with [`calendar_from_leaves()`] (the general escape hatch).
#' Higher-level constructors built on tokens and a catalog will arrive in a
#' later phase.
#'
#' @param leaves `data.frame` with columns `timeslice`, `share`, `weight`, plus
#'   one column per timeframe in `timeframes`.
#' @param timeframes Ordered character vector of timeframe names (coarsest
#'   first); each name must appear as a column in `leaves`.
#' @param levels Named list; `levels[[tf]]` is the full ordered set of
#'   allowed tokens at timeframe `tf`. Must equal `unique(leaves[[tf]])` as
#'   a set.
#' @param meta Named list of model-level attributes (`name`, `desc`,
#'   `year_start`, `utc_offset_minutes`, `year_fraction`).
#'
#' @export
Calendar <- S7::new_class(
  "Calendar",
  properties = list(
    leaves     = S7::new_property(S7::class_data.frame),
    timeframes = S7::new_property(S7::class_character),
    levels     = S7::new_property(S7::class_list),
    meta       = S7::new_property(S7::class_list, default = list())
  ),
  constructor = function(leaves, timeframes, levels, meta = list()) {
    S7::new_object(
      S7::S7_object(),
      leaves     = leaves,
      timeframes = timeframes,
      levels     = levels,
      meta       = meta
    )
  },
  validator = function(self) {
    errs <- character()

    leaves <- S7::prop(self, "leaves")
    timeframes <- S7::prop(self, "timeframes")
    levels <- S7::prop(self, "levels")
    meta <- S7::prop(self, "meta")

    # leaves ------------------------------------------------------------------
    if (!is.data.frame(leaves)) {
      return("`leaves` must be a data.frame")
    }
    required <- c("timeslice", "share", "weight")
    missing <- setdiff(required, names(leaves))
    if (length(missing) > 0) {
      errs <- c(errs, sprintf("`leaves` missing columns: %s",
                              paste(missing, collapse = ", ")))
    }

    # timeframes --------------------------------------------------------------
    if (!is.character(timeframes) || length(timeframes) == 0L ||
        anyNA(timeframes) || any(timeframes == "")) {
      errs <- c(errs, "`timeframes` must be a non-empty character vector")
    } else if (anyDuplicated(timeframes)) {
      errs <- c(errs, "`timeframes` must be unique")
    } else if (any(timeframes %in% c("slice", "timeslice", "share",
                                     "weight"))) {
      # reserved leaf-table column names: a timeframe called `share` would
      # silently corrupt the leaves table (`slice` stays reserved as the
      # pre-rename spelling)
      errs <- c(errs, paste0("`timeframes` must not use the reserved names ",
                             "slice, timeslice, share, weight"))
    } else {
      missing_cols <- setdiff(timeframes, names(leaves))
      if (length(missing_cols) > 0) {
        errs <- c(errs, sprintf("`leaves` missing timeframe columns: %s",
                                paste(missing_cols, collapse = ", ")))
      }
    }

    # levels ------------------------------------------------------------------
    if (!is.list(levels)) {
      errs <- c(errs, "`levels` must be a list")
    } else if (length(errs) == 0L) {
      missing_lv <- setdiff(timeframes, names(levels))
      if (length(missing_lv) > 0) {
        errs <- c(errs, sprintf("`levels` missing entries for: %s",
                                paste(missing_lv, collapse = ", ")))
      }
      for (tf in intersect(timeframes, names(levels))) {
        lv <- levels[[tf]]
        if (!is.character(lv) || length(lv) == 0L ||
            anyNA(lv) || any(lv == "") || anyDuplicated(lv)) {
          errs <- c(errs, sprintf(
            "`levels[[\"%s\"]]` must be a unique non-empty character vector",
            tf))
          next
        }
        seen <- unique(as.character(leaves[[tf]]))
        if (!setequal(seen, lv)) {
          errs <- c(errs, sprintf(
            paste0("`levels[[\"%s\"]]` must contain exactly the values ",
                   "present in `leaves$%s`"),
            tf, tf))
        }
      }
    }

    # timeslice / share / weight columns -----------------------------------------
    if ("timeslice" %in% names(leaves)) {
      sid <- leaves$timeslice
      if (!is.character(sid) || anyNA(sid) || any(sid == "") ||
          anyDuplicated(sid)) {
        errs <- c(errs,
                  "`leaves$timeslice` must be a unique non-empty character vector")
      }
    }
    if ("share" %in% names(leaves)) {
      sh <- leaves$share
      if (!is.numeric(sh) || any(!is.finite(sh)) || any(sh <= 0)) {
        errs <- c(errs, "`leaves$share` must be finite numeric values > 0")
      }
    }
    if ("weight" %in% names(leaves)) {
      w <- leaves$weight
      if (!is.numeric(w) || any(!is.finite(w)) || any(w < 0)) {
        errs <- c(errs, "`leaves$weight` must be finite numeric values >= 0")
      }
    }

    # meta --------------------------------------------------------------------
    if (!is.list(meta)) {
      errs <- c(errs, "`meta` must be a list")
    } else {
      yf <- meta$year_fraction %||% 1
      if (!is.numeric(yf) || length(yf) != 1L || !is.finite(yf) || yf <= 0) {
        errs <- c(errs,
                  "`meta$year_fraction` must be a single finite numeric > 0")
      } else if ("share" %in% names(leaves) && is.numeric(leaves$share) &&
                 all(is.finite(leaves$share))) {
        if (abs(sum(leaves$share) - yf) > 1e-9) {
          errs <- c(errs, sprintf(
            paste0("sum(`leaves$share`) (%g) must equal ",
                   "`meta$year_fraction` (%g)"),
            sum(leaves$share), yf))
        }
      }

      ys <- meta$year_start
      if (!is.null(ys)) {
        if (!is.list(ys) || is.null(ys$month) || is.null(ys$day)) {
          errs <- c(errs, "`meta$year_start` must be `list(month = , day = )`")
        } else {
          m <- as.integer(ys$month)
          d <- as.integer(ys$day)
          if (length(m) != 1L || is.na(m) || m < 1 || m > 12) {
            errs <- c(errs,
                      "`meta$year_start$month` must be an integer in 1:12")
          }
          if (length(d) != 1L || is.na(d) || d < 1 || d > 31) {
            errs <- c(errs, "`meta$year_start$day` must be an integer in 1:31")
          }
        }
      }

      uom <- meta$utc_offset_minutes
      if (!is.null(uom)) {
        if (!is.numeric(uom) || length(uom) != 1L || !is.finite(uom) ||
            abs(uom - round(uom)) > 1e-10) {
          errs <- c(errs, paste0("`meta$utc_offset_minutes` must be a single ",
                                 "integer (minutes)"))
        }
      }
    }

    if (length(errs) == 0L) NULL else errs
  }
)

# Format / print ---------------------------------------------------------------

S7::method(format, Calendar) <- function(x, ...) {
  sprintf("<Calendar[%s] leaf=%d>",
          paste(S7::prop(x, "timeframes"), collapse = "/"),
          nrow(S7::prop(x, "leaves")))
}

#' @export
#' @method print Calendar
print.Calendar <- function(x, ...) {
  meta <- S7::prop(x, "meta")
  tf   <- S7::prop(x, "timeframes")
  lv   <- S7::prop(x, "levels")
  lf   <- S7::prop(x, "leaves")

  name <- meta$name %||% ""
  cat("Calendar:", if (nzchar(name)) name else "<unnamed>", "\n")
  if (!is.null(meta$desc) && nzchar(meta$desc)) {
    cat("Description:", meta$desc, "\n")
  }

  cat("Timeframes (", length(tf), "):\n", sep = "")
  for (t in tf) {
    n <- length(lv[[t]])
    tok <- meta$tokens[[t]]
    aln <- meta$alignment[[t]]
    extras <- c(if (!is.null(tok)) paste0("token: ", tok),
                if (!is.null(aln)) paste0("alignment: ", aln))
    cat("  - ", t, " (", n, ")",
        if (length(extras) > 0) paste0(" [", paste(extras, collapse = ", "),
                                       "]"),
        "\n", sep = "")
  }
  cat("Leaf timeslices: ", nrow(lf), "\n", sep = "")
  cat("year_fraction: ", meta$year_fraction %||% 1, "\n", sep = "")
  if (!is.null(meta$year_start)) {
    cat(sprintf("year_start: month=%d, day=%d\n",
                as.integer(meta$year_start$month),
                as.integer(meta$year_start$day)))
  }
  if (!is.null(meta$utc_offset_minutes)) {
    cat("utc_offset_minutes: ", meta$utc_offset_minutes, "\n", sep = "")
  }
  invisible(x)
}

S7::method(print, Calendar) <- print.Calendar

# Backward-compat alias: dispatch on the fully-qualified S7 class name so
# base-R `print()` finds it before falling through to `print.S7_object`.
#' @export
`print.timescales::Calendar` <- print.Calendar
