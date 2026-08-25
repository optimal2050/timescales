# =============================================================================
# Navigation, queries and subsetting on a Calendar
# =============================================================================
# The mirror of geoscales' navigation family (geoscale_children(),
# geoscale_family(), filter_geoscale(), ...) on the time hierarchy.
# Time levels nest strictly — every finer timeframe partitions the
# coarser one — so everything here is a closure over `@leaftable`:
# label relationships are read off the leaf table, canonical order comes
# from `@members`.
#
# Naming: properties/queries are calendar_*(); object transforms are
# verb_calendar() (filter_calendar, prune_calendar in base-calendar.R).
# =============================================================================

#' Calendar hierarchy queries
#'
#' Read-only queries on the timeframe hierarchy of a [Calendar] —
#' the time-side mirror of `geoscales::geoscale_geoframes()` and friends.
#'
#' * `calendar_timeframes()` — hierarchy names, coarsest first.
#' * `calendar_rank()` — position of a timeframe (1 = coarsest);
#'   `NA` for unknown names.
#' * `calendar_timeslices()` — with a `timeframe`, the canonical ordered
#'   labels at that level; without, the leaf `timeslice` ids.
#'
#' @param x A [Calendar].
#' @param timeframe A timeframe name (see `calendar_timeframes()`).
#' @param finest `calendar_timeframes()` only: return just the finest
#'   timeframe (the atom layer) instead of the full ordered vector — the
#'   twin of `geoscales::geoscale_geoframes(x, finest = TRUE)`.
#' @param qualified `calendar_timeslices()` only: return the qualified
#'   node IDs at `timeframe` -- the leaf IDs of
#'   `prune_calendar(calendar, timeframe)` -- instead of the bare member
#'   labels. This is the per-frame node view the energyRt bridge consumes.
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
calendar_timeframes <- function(x, finest = FALSE) {
  .check_calendar(x)
  tf <- S7::prop(x, "timeframes")
  if (isTRUE(finest)) tf[length(tf)] else tf
}

#' @rdname calendar_queries
#' @export
calendar_rank <- function(x, timeframe) {
  .check_calendar(x)
  match(timeframe, S7::prop(x, "timeframes"))
}

#' @rdname calendar_queries
#' @export
calendar_timeslices <- function(x, timeframe = NULL,
                                qualified = FALSE) {
  .check_calendar(x)
  if (is.null(timeframe)) {
    return(S7::prop(x, "leaftable")$timeslice)
  }
  .check_leaf_timeframe(x, timeframe)
  if (isTRUE(qualified)) {
    # the NODE IDs at this timeframe = the leaf IDs of the calendar
    # pruned there ("a timeslice at frame f is a leaf of prune(cal, f)")
    # -- what the energyRt bridge consumes (its calendar@timeframes list)
    return(S7::prop(prune_calendar(x, timeframe),
                    "leaftable")$timeslice)
  }
  # the validator guarantees members[[tf]] == values present, so the
  # member set IS the canonical ordered label set
  S7::prop(x, "members")[[timeframe]]
}

#' The leaftable of a Calendar
#'
#' The one-row-per-timeslice table the calendar is built on, as a plain
#' `data.frame` — the exported accessor to prefer over reaching for
#' `x@leaftable` (the twin of `geoscales::geoscale_leaftable()`).
#'
#' @param x A [Calendar].
#' @return A `data.frame`: one row per timeslice, with the timeframe
#'   columns plus `timeslice`, `share`, `weight`.
#' @examples
#' head(calendar_leaftable(calendar("m12")))
#' @export
calendar_leaftable <- function(x) {
  .check_calendar(x)
  S7::prop(x, "leaftable")
}

#' All ancestor-descendant pairs of a Calendar hierarchy
#'
#' One row per observed (ancestor label, descendant label) pair across
#' EVERY ordered timeframe pair — not just adjacent ones. The time-side
#' twin of `geoscales::geoscale_ancestry()`; [calendar_family()] is the
#' adjacent-pairs-only view.
#'
#' @param x A [Calendar].
#' @return `data.frame(parent_timeframe, parent, child_timeframe, child)`.
#' @examples
#' head(calendar_ancestry(calendar("q4_h24")))
#' @export
calendar_ancestry <- function(x) {
  .check_calendar(x)
  tfs <- S7::prop(x, "timeframes")
  if (length(tfs) < 2L) {
    return(data.frame(parent_timeframe = character(), parent = character(),
                      child_timeframe = character(), child = character(),
                      stringsAsFactors = FALSE))
  }
  leaves <- S7::prop(x, "leaftable")
  parts <- list()
  for (i in seq_len(length(tfs) - 1L)) {
    for (j in seq(i + 1L, length(tfs))) {
      u <- unique(leaves[, c(tfs[i], tfs[j]), drop = FALSE])
      parts[[length(parts) + 1L]] <- data.frame(
        parent_timeframe = tfs[i], parent = as.character(u[[1]]),
        child_timeframe = tfs[j], child = as.character(u[[2]]),
        stringsAsFactors = FALSE)
    }
  }
  out <- do.call(rbind, parts)
  out <- out[order(out$parent_timeframe, out$parent,
                   out$child_timeframe, out$child), , drop = FALSE]
  rownames(out) <- NULL
  out
}

#' Immediate parent-child pairs of a Calendar hierarchy
#'
#' One row per observed (parent label, child label) pair between each
#' consecutive timeframe pair — the time-side mirror of
#' `geoscales::geoscale_family()`.
#'
#' @param x A [Calendar].
#' @param parent,child Optional timeframe names restricting the output
#'   to one hierarchy step.
#' @return `data.frame(parent_timeframe, parent, child_timeframe, child)`.
#' @examples
#' calendar_family(calendar("q4_h24"))
#' @export
calendar_family <- function(x, parent = NULL, child = NULL) {
  .check_calendar(x)
  tfs <- S7::prop(x, "timeframes")
  leaves <- S7::prop(x, "leaftable")
  if (length(tfs) < 2L) {
    return(data.frame(parent_timeframe = character(), parent = character(),
                      child_timeframe = character(), child = character(),
                      stringsAsFactors = FALSE))
  }
  pairs <- Map(c, tfs[-length(tfs)], tfs[-1L])
  if (!is.null(parent)) {
    .check_leaf_timeframe(x, parent, arg = "parent")
    pairs <- Filter(function(p) p[1] == parent, pairs)
  }
  if (!is.null(child)) {
    .check_leaf_timeframe(x, child, arg = "child")
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
  levels <- S7::prop(calendar, "members")
  unknown <- setdiff(label, levels[[timeframe]])
  if (length(unknown) > 0L) {
    .stop("unknown label(s) at timeframe '%s': %s", timeframe,
          .preview(unknown))
  }
  leaves <- S7::prop(calendar, "leaftable")
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
#' @param x A [Calendar].
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
calendar_children <- function(x, timeframe, label, to = NULL) {
  tfs <- calendar_timeframes(x)
  i <- match(timeframe, tfs)
  if (is.na(i)) .check_leaf_timeframe(x, timeframe)
  if (is.null(to)) {
    if (i == length(tfs)) {
      .stop("'%s' is the finest timeframe; it has no children", timeframe)
    }
    to <- tfs[i + 1L]
  }
  .calendar_related(x, timeframe, label, to)
}

#' @rdname calendar_navigate
#' @export
calendar_parents <- function(x, timeframe, label, to = NULL) {
  tfs <- calendar_timeframes(x)
  i <- match(timeframe, tfs)
  if (is.na(i)) .check_leaf_timeframe(x, timeframe)
  if (is.null(to)) {
    if (i == 1L) {
      .stop("'%s' is the coarsest timeframe; it has no parents", timeframe)
    }
    to <- tfs[i - 1L]
  }
  .calendar_related(x, timeframe, label, to)
}

#' @rdname calendar_navigate
#' @export
calendar_descendants <- function(x, timeframe, label, to = NULL) {
  tfs <- calendar_timeframes(x)
  i <- match(timeframe, tfs)
  if (is.na(i)) .check_leaf_timeframe(x, timeframe)
  j <- if (is.null(to)) length(tfs) else match(to, tfs)
  if (is.na(j)) .check_leaf_timeframe(x, to, arg = "to")
  if (j <= i) .stop("`to` must be finer than '%s'", timeframe)
  out <- lapply(tfs[seq(i + 1L, j)], function(tf) {
    data.frame(timeframe = tf,
               label = .calendar_related(x, timeframe, label, tf),
               stringsAsFactors = FALSE)
  })
  do.call(rbind, c(out, list(make.row.names = FALSE)))
}

#' @rdname calendar_navigate
#' @export
calendar_ancestors <- function(x, timeframe, label, to = NULL) {
  tfs <- calendar_timeframes(x)
  i <- match(timeframe, tfs)
  if (is.na(i)) .check_leaf_timeframe(x, timeframe)
  j <- if (is.null(to)) 1L else match(to, tfs)
  if (is.na(j)) .check_leaf_timeframe(x, to, arg = "to")
  if (j >= i) .stop("`to` must be coarser than '%s'", timeframe)
  out <- lapply(tfs[seq(j, i - 1L)], function(tf) {
    data.frame(timeframe = tf,
               label = .calendar_related(x, timeframe, label, tf),
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
#' @param x A [Calendar].
#' @param timeframe Timeframe to aggregate the shares at.
#' @param within Optional coarser timeframe to normalize within.
#' @return A `data.frame` with the `timeframe` column (and the `within`
#'   column when given) plus `share`.
#' @examples
#' calendar_share(calendar("m12"), "MONTH")
#' calendar_share(calendar("q4_h24"), "HOUR", within = "QUARTER")
#' @export
calendar_share <- function(x, timeframe, within = NULL) {
  .check_calendar(x)
  .check_leaf_timeframe(x, timeframe)
  leaves <- S7::prop(x, "leaftable")
  levels <- S7::prop(x, "members")
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
  .check_leaf_timeframe(x, within, arg = "within")
  tfs <- S7::prop(x, "timeframes")
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
#' A real sample (fewer leaves than the parent) is book-kept exactly like
#' a geoscales sample: the result is renamed
#' `"base[timeframe:labels-or-hash]"` (so two different samples of one
#' parent never collide in registries or joins), the root parent's name
#' and totals are recorded in `meta$parent_name`/`meta$parent_totals`,
#' and `meta$coverage` holds the surviving fraction of `share` and
#' `weight` (read it with [calendar_coverage()]). Filter-of-filter
#' composes against the root parent. A filter that keeps everything is a
#' true no-op: the calendar is returned unchanged.
#'
#' There is no `drop_empty_timeframes=` twin of the geoscales argument:
#' a calendar leaftable is total (no `NA` memberships), so no timeframe
#' can empty out under filtering.
#'
#' `cal[timeframe, labels]` is subsetting sugar for the same operation.
#'
#' @param x A [Calendar].
#' @param timeframe Timeframe the labels live at.
#' @param labels Labels at `timeframe` to keep.
#' @return A [Calendar] covering the selected part of the year.
#' @examples
#' win <- filter_calendar(calendar("s4_h24"), "SEASON", "WIN")
#' win <- calendar("s4_h24")["SEASON", "WIN"]   # same
#' calendar_coverage(win)
#' @export
filter_calendar <- function(x, timeframe, labels) {
  .check_calendar(x)
  .check_leaf_timeframe(x, timeframe)
  levels <- S7::prop(x, "members")
  unknown <- setdiff(labels, levels[[timeframe]])
  if (length(unknown) > 0L) {
    .stop("unknown label(s) at timeframe '%s': %s", timeframe,
          .preview(unknown))
  }
  leaves <- S7::prop(x, "leaftable")
  keep <- as.character(leaves[[timeframe]]) %in% labels
  if (!any(keep)) {
    .stop("no timeslices left after filtering '%s' to %s", timeframe,
          .preview(labels))
  }
  if (all(keep)) return(x)                    # a true no-op, not a resample
  lf <- leaves[keep, , drop = FALSE]
  rownames(lf) <- NULL
  tfs <- S7::prop(x, "timeframes")
  lv <- lapply(stats::setNames(tfs, tfs), function(tf) {
    levels[[tf]][levels[[tf]] %in% unique(as.character(lf[[tf]]))]
  })
  codes <- unique(as.character(lf[[timeframe]]))
  # the tag must IDENTIFY the sample, not just count it -- two different
  # single-season samples may not share a name (geoscales convention)
  id <- if (sum(nchar(codes)) + length(codes) <= 24L) {
    paste(codes, collapse = "+")
  } else {
    paste0(length(codes), "~", substr(rlang::hash(sort(codes)), 1, 8))
  }
  meta <- .calendar_sample_meta(x, kept = lf,
                                tag = sprintf("[%s:%s]", timeframe, id))
  meta$year_fraction <- sum(lf$share)
  Calendar(leaftable = lf, timeframes = tfs, members = lv, meta = meta)
}

# Sample bookkeeping: coverage / parent_totals / parent_name / name.
# Coverage is always a fraction of the ROOT parent (an existing
# `parent_totals` is reused, so filter-of-filter composes), and the
# mangled name is built from the root parent's name plus `tag`.
# The calendar's "weights" are its two built-in numeric columns.
#' @noRd
.calendar_sample_meta <- function(x, kept, tag) {
  wts <- c("share", "weight")
  leaves <- S7::prop(x, "leaftable")
  meta <- S7::prop(x, "meta")
  totals <- meta[["parent_totals"]]        # [[ ]]: `$` would partial-match
  if (is.null(totals)) {
    totals <- vapply(wts, function(w) sum(leaves[[w]], na.rm = TRUE),
                     numeric(1))
    names(totals) <- wts
  }
  cov <- vapply(wts, function(w) sum(kept[[w]], na.rm = TRUE) / totals[[w]],
                numeric(1))
  names(cov) <- wts
  base <- meta[["parent_name"]] %||% meta[["name"]] %||% ""
  meta$parent_totals <- totals
  meta$coverage      <- cov
  meta$parent_name   <- base
  meta$name          <- paste0(base, tag)
  meta
}

#' Coverage of a sampled Calendar
#'
#' The fraction of the ROOT parent calendar that a [filter_calendar()]
#' sample retains, per built-in weight column (`share`, `weight`) — the
#' time-side mirror of `geoscales::geoscale_coverage()`. A calendar that
#' was never sampled reports 1 for both.
#'
#' @param x A [Calendar].
#' @param weight `"share"`, `"weight"`, or `NULL` (default) for the named
#'   vector over both.
#' @return A named numeric vector, or a single value with `weight=`.
#' @examples
#' calendar_coverage(filter_calendar(calendar("s4_h24"), "SEASON", "WIN"))
#' @export
calendar_coverage <- function(x, weight = NULL) {
  .check_calendar(x)
  wts <- c("share", "weight")
  full <- stats::setNames(rep(1, length(wts)), wts)
  cov <- S7::prop(x, "meta")[["coverage"]]   # exact: never coverage_class
  if (!is.null(cov)) full[names(cov)] <- unname(cov)
  if (is.null(weight)) return(full)
  if (!weight %in% wts) {
    .stop("unknown weight `%s`; use \"share\" or \"weight\"", weight)
  }
  unname(full[[weight]])
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
