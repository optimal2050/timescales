# =========================================================================== #
# make_goldens.R -- generate the cross-language golden specs (timescales).
#
# Usage (from the package root):
#   Rscript tools/specs/make_goldens.R
#
# Writes, per specs/README.md:
#   specs/calendars/<name>.yaml            named structures (leaftable form)
#   specs/golden/NNN-<case>/input.yaml     structure ref + op + params + input
#   specs/golden/NNN-<case>/expected.csv   the R implementation's result
#
# The R test suite re-loads every pair and re-runs the op
# (tests/testthat/test-specs-golden.R sources THIS file for the runner), so
# R is the first consumer of the language-neutral goldens; the C++/Python
# ports are next. Numeric output is %.17g -- regeneration is byte-stable.
# Behaviour change => regenerate the goldens in the same commit.
# =========================================================================== #

suppressMessages({
  stopifnot(file.exists("DESCRIPTION"))
  PKG <- unname(read.dcf("DESCRIPTION")[1, "Package"])
  if (!isNamespaceLoaded(PKG)) {
    if (requireNamespace("pkgload", quietly = TRUE)) {
      pkgload::load_all(".", quiet = TRUE, export_all = FALSE)
    } else {
      library(PKG, character.only = TRUE)
    }
  }
  library(yaml)
})

STRUCT_DIR <- file.path("specs", "calendars")
GOLDEN_DIR <- file.path("specs", "golden")

# ---- structures ----------------------------------------------------------- #

spec_structures <- function() {
  list(
    m12     = timescales::calendar_leaftable(timescales::calendar("m12")),
    q4      = timescales::calendar_leaftable(timescales::calendar("q4")),
    m12_h24 = timescales::calendar_leaftable(timescales::calendar("m12_h24")),
    d360    = timescales::calendar_leaftable(timescales::calendar("d360"))
  )
}

struct_timeframes <- function(lt) {
  setdiff(names(lt), c("timeslice", "share", "weight"))
}

load_structure <- function(name, dir = STRUCT_DIR) {
  y <- yaml::read_yaml(file.path(dir, paste0(name, ".yaml")))
  lt <- as.data.frame(do.call(rbind, lapply(y$leaftable, as.data.frame)))
  for (cc in c("share", "weight")) lt[[cc]] <- as.numeric(lt[[cc]])
  timescales::calendar_from_leaftable(
    lt, timeframes = y$timeframes, name = y$name,
    year_fraction = sum(lt$share))
}

# ---- the op runner (shared by generator and test) ------------------------- #

run_spec_op <- function(spec, structures_dir = STRUCT_DIR) {
  x <- as.data.frame(do.call(rbind, lapply(spec$input, as.data.frame)))
  for (cc in names(x)) {
    if (!is.na(suppressWarnings(as.numeric(x[[cc]][1]))) &&
        !cc %in% c("timeslice", "id")) x[[cc]] <- as.numeric(x[[cc]])
  }
  p <- spec$params
  from <- load_structure(spec$structure, structures_dir)
  out <- switch(spec$op,
    recast = timescales::recast_calendar(
      x, from, load_structure(p$to, structures_dir),
      year = p$year, rule = p$rule, by = p$by,
      na_action = p$na_action %||% "drop"),
    recast_to_frame = timescales::recast_calendar(
      x, from, p$to_timeframe, year = p$year, rule = p$rule,
      by = p$by),
    join = timescales::join_calendar(
      x, from, timeframes = p$timeframes %||% NULL,
      meta = isTRUE(p$meta), as_factor = FALSE),
    filter = timescales::calendar_leaftable(
      timescales::filter_calendar(from, p$timeframe, unlist(p$labels))),
    prune = timescales::calendar_leaftable(
      timescales::prune_calendar(from, p$timeframe)),
    stop("unknown op: ", spec$op))
  out <- as.data.frame(out)
  key <- intersect(c("id", "timeslice", names(out)[1]), names(out))
  out <- out[do.call(order, out[key]), , drop = FALSE]
  rownames(out) <- NULL
  out
}

`%||%` <- function(a, b) if (is.null(a)) b else a

# ---- case set ------------------------------------------------------------- #

.in_tbl <- function(cal_name, col = "energy", v = NULL, ids = NULL) {
  lt <- spec_structures()[[cal_name]]
  d <- data.frame(timeslice = lt$timeslice)
  d[[col]] <- if (is.null(v)) as.numeric(seq_len(nrow(d))) else
    rep_len(as.numeric(v), nrow(d))
  if (!is.null(ids)) {
    d <- do.call(rbind, lapply(ids, function(i) cbind(d, id = i)))
  }
  d
}

spec_cases <- function() {
  list(
    list(id = "001-recast-m12-q4-sum", structure = "m12",
         op = "recast", input = .in_tbl("m12", ids = c("A", "B")),
         params = list(to = "q4", year = 2021L, rule = "sum", by = "day")),
    list(id = "002-recast-m12-q4-weighted-mean", structure = "m12",
         op = "recast", input = .in_tbl("m12"),
         params = list(to = "q4", year = 2021L, rule = "weighted_mean",
                       by = "month")),
    list(id = "003-recast-m12-q4-mean", structure = "m12",
         op = "recast", input = .in_tbl("m12"),
         params = list(to = "q4", year = 2021L, rule = "mean",
                       by = "month")),
    list(id = "004-recast-q4-m12-sum-down", structure = "q4",
         op = "recast", input = .in_tbl("q4"),
         params = list(to = "m12", year = 2021L, rule = "sum", by = "day")),
    list(id = "005-recast-m12-q4-copy", structure = "m12",
         op = "recast", input = .in_tbl("m12", col = "flag", v = 7),
         params = list(to = "q4", year = 2021L, rule = "copy", by = "day")),
    list(id = "006-recast-m12h24-month-sum", structure = "m12_h24",
         op = "recast_to_frame", input = .in_tbl("m12_h24"),
         params = list(to_timeframe = "MONTH", year = 2021L, rule = "sum")),
    list(id = "007-recast-m12-d360-keep-na", structure = "m12",
         op = "recast", input = .in_tbl("m12", v = 1),
         params = list(to = "d360", year = 2021L, rule = "sum", by = "day",
                       na_action = "keep")),
    list(id = "008-join-meta", structure = "m12",
         op = "join", input = .in_tbl("m12"),
         params = list(meta = TRUE)),
    list(id = "009-join-timeframes", structure = "m12_h24",
         op = "join", input = .in_tbl("m12_h24"),
         params = list(timeframes = list("MONTH"))),
    list(id = "010-filter-q1", structure = "m12",
         op = "filter", input = data.frame(),
         params = list(timeframe = "MONTH",
                       labels = list("m01", "m02", "m03"))),
    list(id = "011-prune-month", structure = "m12_h24",
         op = "prune", input = data.frame(),
         params = list(timeframe = "MONTH"))
  )
}

# ---- serialisation -------------------------------------------------------- #

.df_records <- function(d) {
  lapply(seq_len(nrow(d)), function(i) {
    r <- as.list(d[i, , drop = FALSE])
    lapply(r, function(v) if (is.numeric(v)) unname(v) else
      unname(as.character(v)))
  })
}

write_expected_csv <- function(out, path) {
  fmt <- out
  for (cc in names(fmt)) {
    if (is.numeric(fmt[[cc]])) fmt[[cc]] <- sprintf("%.17g", fmt[[cc]])
  }
  utils::write.csv(fmt, path, row.names = FALSE, quote = TRUE, na = "NA",
                   eol = "\n")
}

make_goldens <- function() {
  dir.create(STRUCT_DIR, recursive = TRUE, showWarnings = FALSE)
  for (nm in names(spec_structures())) {
    lt <- spec_structures()[[nm]]
    # "spec_" prefix: registry caches are keyed by NAME, and a rebuilt
    # structure must never collide with the catalog object it mirrors
    yaml::write_yaml(
      list(name = paste0("spec_", nm), timeframes = struct_timeframes(lt),
           leaftable = .df_records(lt)),
      file.path(STRUCT_DIR, paste0(nm, ".yaml")))
  }
  for (case in spec_cases()) {
    d <- file.path(GOLDEN_DIR, case$id)
    dir.create(d, recursive = TRUE, showWarnings = FALSE)
    spec <- list(structure = case$structure, op = case$op,
                 params = case$params,
                 input = if (nrow(case$input)) .df_records(case$input)
                         else list())
    yaml::write_yaml(spec, file.path(d, "input.yaml"))
    out <- suppressWarnings(run_spec_op(spec))
    write_expected_csv(out, file.path(d, "expected.csv"))
  }
  message("Wrote ", length(spec_cases()), " golden cases and ",
          length(spec_structures()), " structures under specs/")
}

if (sys.nframe() == 0L) make_goldens()
