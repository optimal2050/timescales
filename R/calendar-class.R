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

# Summary ----------------------------------------------------------------------

#' Summarize a Calendar
#'
#' Complements [print()] with the quantitative view: coverage of a
#' sampled calendar, share/weight statistics, and the catalog
#' classification when present. Returns a `"summary_Calendar"` object
#' (a list) with its own print method — the mirror of
#' `summary.Geoscale()` in geoscales.
#'
#' @param object A [Calendar].
#' @param x A `"summary_Calendar"` object (the print method's argument).
#' @param ... Ignored.
#' @return `summary()` returns a list of class `"summary_Calendar"`:
#'   `name`, `desc`, `timeframes` (named member counts),
#'   `n_timeslices`, `year_fraction`, `coverage` (see
#'   [calendar_coverage()]), `sampled`, `parent_name`,
#'   `coverage_class`/`regularity` (catalog designs only),
#'   `share_range`, `weight_range`, `year_start`, `utc_offset_minutes`.
#' @examples
#' summary(calendar("m12_h24"))
#' summary(filter_calendar(calendar("s4_h24"), "SEASON", "WIN"))
#' @export
#' @method summary Calendar
summary.Calendar <- function(object, ...) {
  meta <- S7::prop(object, "meta")
  lv <- S7::prop(object, "members")
  lf <- S7::prop(object, "leaftable")
  cov <- calendar_coverage(object)
  out <- list(
    name = meta[["name"]] %||% "",
    desc = meta[["desc"]] %||% "",
    timeframes = vapply(lv, length, integer(1)),
    n_timeslices = nrow(lf),
    year_fraction = meta[["year_fraction"]] %||% 1,
    coverage = cov,
    sampled = any(cov < 1),
    parent_name = meta[["parent_name"]],
    coverage_class = meta[["coverage_class"]],
    regularity = meta[["regularity"]],
    share_range = range(lf$share),
    weight_range = range(lf$weight),
    year_start = meta[["year_start"]],
    utc_offset_minutes = meta[["utc_offset_minutes"]]
  )
  class(out) <- "summary_Calendar"
  out
}

S7::method(summary, Calendar) <- summary.Calendar

#' @rdname summary.Calendar
#' @export
`summary.timescales::Calendar` <- summary.Calendar

#' @rdname summary.Calendar
#' @export
#' @method print summary_Calendar
print.summary_Calendar <- function(x, ...) {
  cat("<summary of Calendar", if (nzchar(x$name)) paste0("'", x$name, "'"),
      ">\n")
  if (nzchar(x$desc)) cat("  desc:          ", x$desc, "\n", sep = "")
  cat("  timeframes:     ",
      paste(sprintf("%s (%d)", names(x$timeframes), x$timeframes),
            collapse = " / "), "\n", sep = "")
  cat("  timeslices:     ", x$n_timeslices, "\n", sep = "")
  cat("  year_fraction:  ", format(x$year_fraction, digits = 6), "\n",
      sep = "")
  if (isTRUE(x$sampled)) {
    cat("  SAMPLED:        ",
        paste(sprintf("%s %.1f%%", names(x$coverage), 100 * x$coverage),
              collapse = ", "),
        if (!is.null(x$parent_name) && nzchar(x$parent_name)) {
          paste0(" of '", x$parent_name, "'")
        },
        "\n", sep = "")
  }
  if (!is.null(x$coverage_class)) {
    cat("  catalog:        ", x$coverage_class,
        if (!is.null(x$regularity)) paste0(", ", x$regularity),
        "\n", sep = "")
  }
  cat("  share range:    ",
      paste(format(x$share_range, digits = 4), collapse = " .. "),
      "\n", sep = "")
  cat("  weight range:   ",
      paste(format(x$weight_range, digits = 4), collapse = " .. "),
      "\n", sep = "")
  if (!is.null(x$year_start)) {
    cat(sprintf("  year_start:     month=%d, day=%d\n",
                as.integer(x$year_start$month),
                as.integer(x$year_start$day)))
  }
  if (!is.null(x$utc_offset_minutes)) {
    cat("  utc offset:     ", x$utc_offset_minutes, " min\n", sep = "")
  }
  invisible(x)
}

# Other base generics ----------------------------------------------------------

#' @rdname calendar_queries
#' @export
#' @method names Calendar
names.Calendar <- function(x) calendar_timeframes(x)

S7::method(names, Calendar) <- names.Calendar

#' @export
`names.timescales::Calendar` <- names.Calendar
