# =============================================================================
# Calendar (S7 class) — slim core type
# =============================================================================
# A `Calendar` is a nested time partition of a (model) year:
#
#   * `leaftable`  — flat enumeration of leaf timeslices (one row per leaf,
#                    one column per timeframe plus `timeslice`, `share`, `weight`)
#   * `timeframes` — ordered character vector naming the hierarchy, coarsest
#                    first (e.g. `c("MONTH", "MDAY", "HOUR")`)
#   * `members`    — named list giving each timeframe's ordered member labels
#                    (e.g. `members$MONTH = c("m01", ..., "m12")`)
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
#' Construct with [`calendar_from_leaftable()`] (the general escape hatch).
#' Higher-level constructors built on tokens and a catalog will arrive in a
#' later phase.
#'
#' @param leaftable `data.frame` with columns `timeslice`, `share`, `weight`,
#'   plus one column per timeframe in `timeframes`.
#' @param timeframes Ordered character vector of timeframe names (coarsest
#'   first); each name must appear as a column in `leaftable`.
#' @param members Named list; `members[[tf]]` is the full ordered set of
#'   allowed labels at timeframe `tf`. Must equal `unique(leaftable[[tf]])`
#'   as a set.
#' @param meta Named list of model-level attributes (`name`, `desc`,
#'   `year_start`, `utc_offset_minutes`, `year_fraction`).
#'
#' @export
Calendar <- S7::new_class(
  "Calendar",
  properties = list(
    leaftable  = S7::new_property(S7::class_data.frame),
    timeframes = S7::new_property(S7::class_character),
    members    = S7::new_property(S7::class_list),
    meta       = S7::new_property(S7::class_list, default = list())
  ),
  constructor = function(leaftable, timeframes, members, meta = list()) {
    S7::new_object(
      S7::S7_object(),
      leaftable  = leaftable,
      timeframes = timeframes,
      members    = members,
      meta       = meta
    )
  },
  validator = function(self) {
    errs <- character()

    leaftable <- S7::prop(self, "leaftable")
    timeframes <- S7::prop(self, "timeframes")
    members <- S7::prop(self, "members")
    meta <- S7::prop(self, "meta")

    # leaves ------------------------------------------------------------------
    if (!is.data.frame(leaftable)) {
      return("`leaftable` must be a data.frame")
    }
    required <- c("timeslice", "share", "weight")
    missing <- setdiff(required, names(leaftable))
    if (length(missing) > 0) {
      errs <- c(errs, sprintf("`leaftable` missing columns: %s",
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
      # silently corrupt the leaftable (`slice` stays reserved as the
      # pre-rename spelling)
      errs <- c(errs, paste0("`timeframes` must not use the reserved names ",
                             "slice, timeslice, share, weight"))
    } else {
      missing_cols <- setdiff(timeframes, names(leaftable))
      if (length(missing_cols) > 0) {
        errs <- c(errs, sprintf("`leaftable` missing timeframe columns: %s",
                                paste(missing_cols, collapse = ", ")))
      }
    }

    # levels ------------------------------------------------------------------
    if (!is.list(members)) {
      errs <- c(errs, "`members` must be a list")
    } else if (length(errs) == 0L) {
      missing_lv <- setdiff(timeframes, names(members))
      if (length(missing_lv) > 0) {
        errs <- c(errs, sprintf("`members` missing entries for: %s",
                                paste(missing_lv, collapse = ", ")))
      }
      for (tf in intersect(timeframes, names(members))) {
        lv <- members[[tf]]
        if (!is.character(lv) || length(lv) == 0L ||
            anyNA(lv) || any(lv == "") || anyDuplicated(lv)) {
          errs <- c(errs, sprintf(
            "`members[[\"%s\"]]` must be a unique non-empty character vector",
            tf))
          next
        }
        seen <- unique(as.character(leaftable[[tf]]))
        if (!setequal(seen, lv)) {
          errs <- c(errs, sprintf(
            paste0("`members[[\"%s\"]]` must contain exactly the values ",
                   "present in `leaftable$%s`"),
            tf, tf))
        }
      }
    }

    # timeslice / share / weight columns -----------------------------------------
    if ("timeslice" %in% names(leaftable)) {
      sid <- leaftable$timeslice
      if (!is.character(sid) || anyNA(sid) || any(sid == "") ||
          anyDuplicated(sid)) {
        errs <- c(errs,
                  "`leaftable$timeslice` must be a unique non-empty character vector")
      }
    }
    if ("share" %in% names(leaftable)) {
      sh <- leaftable$share
      if (!is.numeric(sh) || any(!is.finite(sh)) || any(sh <= 0)) {
        errs <- c(errs, "`leaftable$share` must be finite numeric values > 0")
      }
    }
    if ("weight" %in% names(leaftable)) {
      w <- leaftable$weight
      if (!is.numeric(w) || any(!is.finite(w)) || any(w < 0)) {
        errs <- c(errs, "`leaftable$weight` must be finite numeric values >= 0")
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
      } else if ("share" %in% names(leaftable) && is.numeric(leaftable$share) &&
                 all(is.finite(leaftable$share))) {
        if (abs(sum(leaftable$share) - yf) > 1e-9) {
          errs <- c(errs, sprintf(
            paste0("sum(`leaftable$share`) (%g) must equal ",
                   "`meta$year_fraction` (%g)"),
            sum(leaftable$share), yf))
        }
      }

      # sample bookkeeping: coverage must be verifiable from the object
      # (the exact mirror of the geoscales Geoscale validator)
      # [[ ]] indexing: `meta$coverage` would partial-match the catalog's
      # `meta$coverage_class`
      if (!is.null(meta[["coverage"]])) {
        cov <- meta[["coverage"]]
        wts <- c("share", "weight")
        if (!is.numeric(cov) || is.null(names(cov)) ||
            !all(names(cov) %in% wts)) {
          errs <- c(errs, paste0("`meta$coverage` must be a named numeric ",
                                 "over \"share\"/\"weight\""))
        } else if (!all(is.finite(cov)) || any(cov <= 0) || any(cov > 1)) {
          errs <- c(errs, "`meta$coverage` values must lie in (0, 1]")
        } else if (!is.null(meta[["parent_totals"]])) {
          pt <- meta[["parent_totals"]]
          for (w in intersect(names(cov), names(pt))) {
            if (!w %in% names(leaftable) || !is.numeric(leaftable[[w]])) next
            got <- sum(leaftable[[w]], na.rm = TRUE) / pt[[w]]
            if (abs(got - cov[[w]]) > 1e-8) {
              errs <- c(errs, sprintf(
                "`meta$coverage[\"%s\"]` (%.6g) does not match the leaftable (%.6g)",
                w, cov[[w]], got))
            }
          }
        }
        if (!is.null(meta[["parent_name"]]) &&
            !(is.character(meta[["parent_name"]]) &&
              length(meta[["parent_name"]]) == 1L)) {
          errs <- c(errs, "`meta$parent_name` must be a single string")
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
          nrow(S7::prop(x, "leaftable")))
}

#' @export
#' @method print Calendar
print.Calendar <- function(x, ...) {
  meta <- S7::prop(x, "meta")
  tf   <- S7::prop(x, "timeframes")
  lv   <- S7::prop(x, "members")
  lf   <- S7::prop(x, "leaftable")

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
