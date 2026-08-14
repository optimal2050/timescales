# =============================================================================
# Navigation, queries and subsetting on a Calendar
# =============================================================================
# The mirror of geoscales' navigation family (geoscale_children(),
# geoscale_family(), filter_geoscale(), ...) on the time hierarchy.
# Time levels nest strictly — every finer timeframe partitions the
# coarser one — so everything here is a closure over `@leaves`:
# label relationships are read off the leaf table, canonical order comes
# from `@levels`.
#
# Naming: properties/queries are calendar_*(); object transforms are
# verb_calendar() (filter_calendar, prune_calendar in base-calendar.R).
# =============================================================================

#' Calendar hierarchy queries
#'
#' Read-only queries on the timeframe hierarchy of a [Calendar] —
#' the time-side mirror of `geoscales::geoscale_levels()` and friends.
#'
#' * `calendar_timeframes()` — hierarchy names, coarsest first.
#' * `calendar_rank()` — position of a timeframe (1 = coarsest);
#'   `NA` for unknown names.
#' * `calendar_timeslices()` — with a `timeframe`, the canonical ordered
#'   labels at that level; without, the leaf `timeslice` ids.
#'
#' @param calendar A [Calendar].
#' @param timeframe A timeframe name (see `calendar_timeframes()`).
#' @return `calendar_timeframes()` and `calendar_timeslices()` return a
#'   character vector; `calendar_rank()` an integer.
#' @examples
#' cal <- calendar("q4_h24")
#' calendar_timeframes(cal)
#' calendar_rank(cal, "HOUR")
#' calendar_timeslices(cal, "QUARTER")
#' @name calendar_queries
NULL

#' @rdname calendar_queries
#' @export
calendar_timeframes <- function(calendar) {
  .check_calendar(calendar)
  S7::prop(calendar, "timeframes")
}

#' @rdname calendar_queries
#' @export
calendar_rank <- function(calendar, timeframe) {
  .check_calendar(calendar)
  match(timeframe, S7::prop(calendar, "timeframes"))
}

#' @rdname calendar_queries
#' @export
calendar_timeslices <- function(calendar, timeframe = NULL) {
  .check_calendar(calendar)
  if (is.null(timeframe)) {
    return(S7::prop(calendar, "leaves")$timeslice)
  }
  .check_leaf_timeframe(calendar, timeframe)
  # the validator guarantees levels[[tf]] == values present, so the
  # vocabulary IS the canonical ordered label set
  S7::prop(calendar, "levels")[[timeframe]]
}

#' Immediate parent-child pairs of a Calendar hierarchy
#'
#' One row per observed (parent label, child label) pair between each
#' consecutive timeframe pair — the time-side mirror of
#' `geoscales::geoscale_family()`.
#'
#' @param calendar A [Calendar].
#' @param parent,child Optional timeframe names restricting the output
#'   to one hierarchy step.
#' @return `data.frame(parent_timeframe, parent, child_timeframe, child)`.
#' @examples
#' calendar_family(calendar("q4_h24"))
#' @export
calendar_family <- function(calendar, parent = NULL, child = NULL) {
  .check_calendar(calendar)
  tfs <- S7::prop(calendar, "timeframes")
  leaves <- S7::prop(calendar, "leaves")
  if (length(tfs) < 2L) {
    return(data.frame(parent_timeframe = character(), parent = character(),
                      child_timeframe = character(), child = character(),
                      stringsAsFactors = FALSE))
  }
  pairs <- Map(c, tfs[-length(tfs)], tfs[-1L])
  if (!is.null(parent)) {
    .check_leaf_timeframe(calendar, parent, arg = "parent")
    pairs <- Filter(function(p) p[1] == parent, pairs)
  }
  if (!is.null(child)) {
    .check_leaf_timeframe(calendar, child, arg = "child")
    pairs <- Filter(function(p) p[2] == child, pairs)
  }
  out <- lapply(pairs, function(p) {
    u <- unique(leaves[, p, drop = FALSE])
    data.frame(parent_timeframe = p[1], parent = as.character(u[[1]]),
               child_timeframe = p[2], child = as.character(u[[2]]),
               stringsAsFactors = FALSE)
  })
  out <- do.call(rbind, c(out, list(make.row.names = FALSE)))
  if (is.null(out)) {
    out <- data.frame(parent_timeframe = character(), parent = character(),
                      child_timeframe = character(), child = character(),
                      stringsAsFactors = FALSE)
  }
  out
}

# A timeframe that exists as a leaves column ("ANNUAL" passes
# .check_timeframe but is the implicit root and has no labels).
#' @noRd
.check_leaf_timeframe <- function(calendar, timeframe, arg = "timeframe") {
  .check_timeframe(calendar, timeframe, arg)
  if (!all(timeframe %in% S7::prop(calendar, "timeframes"))) {
    .stop(paste0("`%s` must be one of the calendar's timeframes; the ",
                 "ANNUAL root has no labels"), arg)
  }
  invisible(timeframe)
}

# Shared engine for the four navigation verbs: labels at `to` related to
# `label` at `timeframe`, in canonical order.
#' @noRd
.calendar_related <- function(calendar, timeframe, label, to) {
  .check_calendar(calendar)
  .check_leaf_timeframe(calendar, timeframe)
  .check_leaf_timeframe(calendar, to, arg = "to")
  levels <- S7::prop(calendar, "levels")
  unknown <- setdiff(label, levels[[timeframe]])
  if (length(unknown) > 0L) {
    .stop("unknown label(s) at timeframe '%s': %s", timeframe,
          .preview(unknown))
  }
  leaves <- S7::prop(calendar, "leaves")
  hits <- unique(as.character(
    leaves[[to]][leaves[[timeframe]] %in% label]))
  hits[order(match(hits, levels[[to]]))]
}

#' Navigate a Calendar hierarchy
#'
#' Labels related to `label` across timeframes — the time-side mirror of
#' `geoscales::geoscale_children()` and friends. Time levels nest
#' strictly, so these are exact partitions:
#'
#' * `calendar_children()` — one step finer (or at `to`).
#' * `calendar_parents()` — one step coarser (or at `to`).
#' * `calendar_descendants()` — all finer timeframes (down to `to`).
#' * `calendar_ancestors()` — all coarser timeframes (up to `to`).
#'
#' @param calendar A [Calendar].
#' @param timeframe The timeframe `label` lives at.
#' @param label One or more labels at `timeframe`.
#' @param to Optional target timeframe; defaults to the adjacent one
#'   (children/parents) or the full transitive range
#'   (descendants/ancestors).
#' @return `calendar_children()` / `calendar_parents()` return a
#'   character vector; `calendar_descendants()` /
#'   `calendar_ancestors()` a `data.frame(timeframe, label)`.
#' @examples
#' cal <- calendar("q4_h24")
#' calendar_children(cal, "QUARTER", "Q1")
#' calendar_parents(cal, "HOUR", "h00")
#' @name calendar_navigate
NULL

#' @rdname calendar_navigate
#' @export
calendar_children <- function(calendar, timeframe, label, to = NULL) {
  tfs <- calendar_timeframes(calendar)
  i <- match(timeframe, tfs)
  if (is.na(i)) .check_leaf_timeframe(calendar, timeframe)
  if (is.null(to)) {
    if (i == length(tfs)) {
      .stop("'%s' is the finest timeframe; it has no children", timeframe)
    }
    to <- tfs[i + 1L]
  }
  .calendar_related(calendar, timeframe, label, to)
}

#' @rdname calendar_navigate
#' @export
calendar_parents <- function(calendar, timeframe, label, to = NULL) {
  tfs <- calendar_timeframes(calendar)
  i <- match(timeframe, tfs)
  if (is.na(i)) .check_leaf_timeframe(calendar, timeframe)
  if (is.null(to)) {
    if (i == 1L) {
      .stop("'%s' is the coarsest timeframe; it has no parents", timeframe)
    }
    to <- tfs[i - 1L]
  }
  .calendar_related(calendar, timeframe, label, to)
}

#' @rdname calendar_navigate
#' @export
calendar_descendants <- function(calendar, timeframe, label, to = NULL) {
  tfs <- calendar_timeframes(calendar)
  i <- match(timeframe, tfs)
  if (is.na(i)) .check_leaf_timeframe(calendar, timeframe)
  j <- if (is.null(to)) length(tfs) else match(to, tfs)
  if (is.na(j)) .check_leaf_timeframe(calendar, to, arg = "to")
  if (j <= i) .stop("`to` must be finer than '%s'", timeframe)
  out <- lapply(tfs[seq(i + 1L, j)], function(tf) {
    data.frame(timeframe = tf,
               label = .calendar_related(calendar, timeframe, label, tf),
               stringsAsFactors = FALSE)
  })
  do.call(rbind, c(out, list(make.row.names = FALSE)))
}

#' @rdname calendar_navigate
#' @export
calendar_ancestors <- function(calendar, timeframe, label, to = NULL) {
  tfs <- calendar_timeframes(calendar)
  i <- match(timeframe, tfs)
  if (is.na(i)) .check_leaf_timeframe(calendar, timeframe)
  j <- if (is.null(to)) 1L else match(to, tfs)
  if (is.na(j)) .check_leaf_timeframe(calendar, to, arg = "to")
  if (j >= i) .stop("`to` must be coarser than '%s'", timeframe)
  out <- lapply(tfs[seq(j, i - 1L)], function(tf) {
    data.frame(timeframe = tf,
               label = .calendar_related(calendar, timeframe, label, tf),
               stringsAsFactors = FALSE)
  })
  do.call(rbind, c(out, list(make.row.names = FALSE)))
}

#' Duration shares at a timeframe
#'
#' Leaf shares summed to a timeframe and normalized — the time-side
#' mirror of `geoscales::geoscale_share()`. Without `within`, shares sum
#' to 1 over the whole calendar; with `within` (a coarser timeframe),
#' they sum to 1 inside each parent label.
#'
#' @param calendar A [Calendar].
#' @param timeframe Timeframe to aggregate the shares at.
#' @param within Optional coarser timeframe to normalize within.
#' @return A `data.frame` with the `timeframe` column (and the `within`
#'   column when given) plus `share`.
#' @examples
#' calendar_share(calendar("m12"), "MONTH")
#' calendar_share(calendar("q4_h24"), "HOUR", within = "QUARTER")
#' @export
calendar_share <- function(calendar, timeframe, within = NULL) {
  .check_calendar(calendar)
  .check_leaf_timeframe(calendar, timeframe)
  leaves <- S7::prop(calendar, "leaves")
  levels <- S7::prop(calendar, "levels")
  if (is.null(within)) {
    agg <- stats::aggregate(leaves$share,
                            by = stats::setNames(
                              list(as.character(leaves[[timeframe]])),
                              timeframe),
                            FUN = sum)
    names(agg)[2L] <- "share"
    agg$share <- agg$share / sum(agg$share)
    agg <- agg[order(match(agg[[timeframe]], levels[[timeframe]])), ,
               drop = FALSE]
    rownames(agg) <- NULL
    return(agg)
  }
  .check_leaf_timeframe(calendar, within, arg = "within")
  tfs <- S7::prop(calendar, "timeframes")
  if (match(within, tfs) >= match(timeframe, tfs)) {
    .stop("`within` ('%s') must be coarser than `timeframe` ('%s')",
          within, timeframe)
  }
  agg <- stats::aggregate(
    leaves$share,
    by = stats::setNames(
      list(as.character(leaves[[within]]),
           as.character(leaves[[timeframe]])),
      c(within, timeframe)),
    FUN = sum)
  names(agg)[3L] <- "share"
  tot <- stats::ave(agg$share, agg[[within]], FUN = sum)
  agg$share <- agg$share / tot
  agg <- agg[order(match(agg[[within]], levels[[within]]),
                   match(agg[[timeframe]], levels[[timeframe]])), ,
             drop = FALSE]
  rownames(agg) <- NULL
  agg
}

#' Filter a Calendar to selected labels
#'
#' Keep only the leaf timeslices whose `timeframe` label is in `labels`
#' — the time-side mirror of `geoscales::filter_geoscale()`. Shares are
#' NOT renormalized: the result is a partial-year calendar whose
#' `meta$year_fraction` is set to the surviving `sum(share)` (use
#' [calendar_share()] when normalized shares are needed). Level
#' vocabularies are subset to the surviving labels.
#'
#' `cal[timeframe, labels]` is subsetting sugar for the same operation.
#'
#' @param calendar A [Calendar].
#' @param timeframe Timeframe the labels live at.
#' @param labels Labels at `timeframe` to keep.
#' @return A [Calendar] covering the selected part of the year.
#' @examples
#' win <- filter_calendar(calendar("s4_h24"), "SEASON", "WIN")
#' win <- calendar("s4_h24")["SEASON", "WIN"]   # same
#' @export
filter_calendar <- function(calendar, timeframe, labels) {
  .check_calendar(calendar)
  .check_leaf_timeframe(calendar, timeframe)
  levels <- S7::prop(calendar, "levels")
  unknown <- setdiff(labels, levels[[timeframe]])
  if (length(unknown) > 0L) {
    .stop("unknown label(s) at timeframe '%s': %s", timeframe,
          .preview(unknown))
  }
  leaves <- S7::prop(calendar, "leaves")
  keep <- as.character(leaves[[timeframe]]) %in% labels
  if (!any(keep)) {
    .stop("no timeslices left after filtering '%s' to %s", timeframe,
          .preview(labels))
  }
  lf <- leaves[keep, , drop = FALSE]
  rownames(lf) <- NULL
  tfs <- S7::prop(calendar, "timeframes")
  lv <- lapply(stats::setNames(tfs, tfs), function(tf) {
    levels[[tf]][levels[[tf]] %in% unique(as.character(lf[[tf]]))]
  })
  meta <- S7::prop(calendar, "meta")
  meta$year_fraction <- sum(lf$share)
  Calendar(leaves = lf, timeframes = tfs, levels = lv, meta = meta)
}

#' @rdname filter_calendar
#' @param x A [Calendar] (the `[` method's object).
#' @param i,j `x[i, j]` is `filter_calendar(x, timeframe = i, labels = j)`.
#' @param ... Ignored (S3 signature compatibility).
#' @export
#' @method [ Calendar
`[.Calendar` <- function(x, i, j, ...) {
  filter_calendar(x, i, j)
}

# S7 objects carry the package-qualified class string first, so base-R
# S3 dispatch needs this spelling too (see print.timescales::Calendar).
#' @rdname filter_calendar
#' @export
`[.timescales::Calendar` <- `[.Calendar`
