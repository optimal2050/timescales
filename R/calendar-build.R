# =============================================================================
# Token-driven calendar constructors (layers 1 and 2)
# =============================================================================
# Layer 2: `calendar_build(token1, token2, ...)` — declarative, by tokens.
# Layer 1: `calendar(name)` — name-based shortcut; parses "d365_h24" etc.
#
# Both delegate to `calendar_from_leaftable()` (layer 3) under the hood.
# =============================================================================

#' Build a Calendar from token names
#'
#' Declarative constructor: name the timeframe vocabulary tokens in coarsest-
#' to-finest order. The Cartesian product of their labels becomes the leaf
#' table; each leaf's share is the product of its tokens' shares, scaled to
#' `year_fraction`.
#'
#' @param ... Character token names (see [`list_tokens()`]) in coarsest-first
#'   order, as positional arguments; each token's timeframe must be unique
#'   within the call. Additional NAMED entries are appended to `meta` of
#'   the resulting [`Calendar`] (names colliding with construction
#'   arguments are an error).
#' @param name Calendar name. Defaults to `paste(tokens, collapse = "_")`.
#' @param desc Free-text description.
#' @param year_start `list(month = , day = )`; defaults to January 1. A
#'   nontrivial anchor makes the model year span
#'   `[year_start(y), year_start(y + 1))`, anchors `YDAY`/`YEAR` to it, and
#'   rotates the MONTH/QUARTER member order so the anchor month comes
#'   first -- labels stay Gregorian (`m04` is April, always).
#' @param utc_offset_minutes Integer minutes; defaults to 0 (UTC). Local
#'   time = UTC + offset; e.g. `330L` for IST (UTC+5:30). Constant offsets
#'   only -- Olson time zones / DST are a planned later phase.
#' @param year_fraction Year fraction covered. Defaults to 1.
#'
#' @return A [`Calendar`].
#'
#' @section Fiscal calendars:
#' The catalog ships April-start fiscal designs -- `fy04_m12`,
#' `fy04_m12_h24`, `fy04_q4`, `fy04_q4_h24`, `fy04_d365`, `fy04_d365_h24`
#' -- for reporting systems whose year runs April..March (India, Japan).
#' The model year `y` spans `[y-04-01, y+1-04-01)` and the anchored `YEAR`
#' is the STARTING Gregorian year (Indian "FY 2021-22" is model year
#' 2021). Labels stay Gregorian (`m04` is April, `Q2` is Apr-Jun); the
#' fiscal identity lives in the anchored `YEAR`/`YDAY` and the April-first
#' member order. The entries are defined in UTC like the rest of the
#' catalog -- data already in Indian local time maps as-is, and true-UTC
#' instants use `calendar("fy04_m12", utc_offset_minutes = 330L)` (IST).
#' Other anchors follow the same pattern by argument, e.g.
#' `calendar("m12", year_start = list(month = 7L, day = 1L))`.
#'
#' @examples
#' cal <- calendar_build("d365", "h24", name = "d365_h24")
#' cal
#'
#' cal2 <- calendar_build("m12", "h24")
#' cal2
#' @export
calendar_build <- function(...,
                           name = NULL,
                           desc = "",
                           year_start = list(month = 1L, day = 1L),
                           utc_offset_minutes = 0L,
                           year_fraction = 1) {
  args  <- list(...)
  named <- names(args)
  if (is.null(named)) named <- rep("", length(args))
  is_token <- !nzchar(named)
  tokens <- args[is_token]

  if (length(tokens) == 0L) {
    stop("`calendar_build()` requires at least one token name as a ",
         "positional argument", call. = FALSE)
  }
  if (!all(vapply(tokens, function(x) is.character(x) && length(x) == 1L,
                  logical(1)))) {
    stop("Token arguments must be single character strings", call. = FALSE)
  }
  tokens <- vapply(tokens, identity, character(1))

  # Look up tokens
  defs <- lapply(tokens, get_token)
  tfs  <- vapply(defs, `[[`, character(1), "timeframe")
  if (anyDuplicated(tfs)) {
    stop("Duplicate timeframes among tokens: ",
         paste(tfs[duplicated(tfs)], collapse = ", "),
         call. = FALSE)
  }

  # Named extras in `...` are appended to `meta` (documented contract);
  # names colliding with construction arguments are user errors, not meta
  extra <- args[!is_token]
  reserved <- unique(c(names(formals(calendar_from_leaftable)),
                       "tokens", "alignment"))
  bad_extra <- intersect(names(extra), reserved)
  if (length(bad_extra) > 0L) {
    stop("Named argument(s) ", paste0("`", bad_extra, "`", collapse = ", "),
         " collide with construction arguments; rename the meta entr",
         if (length(bad_extra) > 1L) "ies" else "y", call. = FALSE)
  }

  # Expand each token; columns are kept as factors for stable ordering
  expansions <- lapply(defs, function(d) d$expand())

  # Fiscal member ordering: a nontrivial year_start rotates the year-cyclic
  # vocabularies (MONTH, QUARTER) so the anchor month's label comes first --
  # m04..m03 for an April start. Labels stay GREGORIAN (m04 is April,
  # always); only the ORDER changes, and each label keeps its own share.
  if (.nontrivial_year_start(year_start)) {
    expansions <- lapply(seq_along(expansions), function(i) {
      .rotate_fiscal(expansions[[i]], tfs[i], year_start)
    })
  }

  # Build the Cartesian product
  label_lists <- lapply(seq_along(expansions), function(i) {
    expansions[[i]]$label
  })
  names(label_lists) <- tfs

  grid <- do.call(expand.grid,
                  c(label_lists,
                    list(stringsAsFactors = FALSE, KEEP.OUT.ATTRS = FALSE)))

  # Compute share as product of per-token shares (a token-share lookup join)
  share <- rep(year_fraction, nrow(grid))
  for (i in seq_along(expansions)) {
    e <- expansions[[i]]
    map <- stats::setNames(e$share, e$label)
    share <- share * map[grid[[tfs[i]]]]
  }
  grid$share  <- as.numeric(share)
  # Default weight = share * 8760 hours
  grid$weight <- grid$share * 8760

  # Levels: the original ordered label set per timeframe (preserves order)
  levels_list <- stats::setNames(label_lists, tfs)

  if (is.null(name)) name <- paste(tokens, collapse = "_")

  # Provenance: which token built each timeframe, and the alignment each
  # token declares (how real instants beyond its vocabulary map onto it)
  tokens_by_tf <- stats::setNames(tokens, tfs)
  alignment <- lapply(defs, `[[`, "alignment")
  names(alignment) <- tfs
  alignment <- alignment[!vapply(alignment, is.null, logical(1))]

  do.call(calendar_from_leaftable, c(
    list(
      leaftable          = grid,
      timeframes         = tfs,
      members            = levels_list,
      name               = name,
      desc               = desc,
      year_start         = year_start,
      utc_offset_minutes = utc_offset_minutes,
      year_fraction      = year_fraction,
      tokens             = tokens_by_tf,
      alignment          = if (length(alignment) > 0L) alignment else NULL
    ),
    extra
  ))
}

#' Rotate a year-cyclic token expansion to start at the fiscal anchor
#'
#' Only full-cardinality MONTH (12) and QUARTER (4) vocabularies rotate;
#' everything else (YDAY is inherently anchored, HOUR is sub-daily, SEASON
#' straddles the year boundary by design) is returned unchanged.
#' @noRd
.rotate_fiscal <- function(expansion, tf, year_start) {
  n <- nrow(expansion)
  start <- if (tf == "MONTH" && n == 12L) {
    as.integer(year_start$month)
  } else if (tf == "QUARTER" && n == 4L) {
    (as.integer(year_start$month) - 1L) %/% 3L + 1L
  } else {
    1L
  }
  if (start <= 1L) return(expansion)
  expansion[c(start:n, 1:(start - 1L)), , drop = FALSE]
}

#' Build a Calendar by name
#'
#' Convenience shortcut. Names listed in [`calendar_catalog()`] build the
#' catalog design (with `coverage`/`regularity` metadata attached; the
#' `m12_md*` family uses a dedicated ragged month/day builder). Any other
#' name is parsed as `_`-joined tokens and dispatched to
#' [`calendar_build()`]. The leading `y_` prefix (year-qualified) is
#' currently stripped and recorded in `meta$year_qualified` — full
#' year-prefix semantics arrive in a later phase.
#'
#' @param name Character scalar — a token-style calendar name (`"d365"`,
#'   `"d365_h24"`, `"m12_h24"`, `"q4_h24"`, ...).
#' @param ... Passed through to [`calendar_build()`] (`year_start`,
#'   `utc_offset_minutes`, `year_fraction`, `desc`).
#'
#' @return A [`Calendar`].
#'
#' @examples
#' calendar("d365_h24")
#' calendar("m12_h24")
#' @rdname calendar_build
#' @export
calendar <- function(name, ...) {
  if (!is.character(name) || length(name) != 1L || !nzchar(name)) {
    stop("`name` must be a single non-empty character string", call. = FALSE)
  }

  year_qualified <- FALSE
  parsed_name <- name
  if (startsWith(parsed_name, "y_")) {
    year_qualified <- TRUE
    parsed_name <- sub("^y_", "", parsed_name)
  }

  # Catalog entries first: they carry coverage/regularity metadata, and the
  # m12_md* designs are non-Cartesian (not expressible as a token product)
  entry <- .CALENDAR_CATALOG[[parsed_name]]
  if (!is.null(entry)) {
    cal <- .calendar_from_catalog(parsed_name, entry, name = name, ...)
    if (year_qualified) {
      cal@meta$year_qualified <- TRUE
    }
    return(cal)
  }

  tokens <- strsplit(parsed_name, "_", fixed = TRUE)[[1]]
  unknown <- setdiff(tokens, list_tokens())
  if (length(unknown) > 0L) {
    stop("Unknown token(s) in '", name, "': ",
         paste(unknown, collapse = ", "),
         ". Use list_tokens() to see available tokens and calendar_catalog() ",
         "for the named designs, or register_token() to add custom tokens.",
         call. = FALSE)
  }

  cal <- do.call(calendar_build,
                 c(as.list(tokens), list(name = name, ...)))
  if (year_qualified) {
    cal@meta$year_qualified <- TRUE
  }
  cal
}
