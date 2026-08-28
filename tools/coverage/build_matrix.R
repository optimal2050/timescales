# =========================================================================== #
# build_matrix.R -- the FUNCTION-surface test-coverage matrix of a scales
# package (identical file in timescales and geoscales; it reads the package
# name from DESCRIPTION).
#
# Usage (from the package root):
#   Rscript tools/coverage/build_matrix.R            # regenerate CSV + summary
#   Rscript tools/coverage/build_matrix.R --check    # validate @covers tags
#
# Rows come from the installed NAMESPACE + formals() -- never hand-enumerated,
# so a new export shows up automatically as covered_depth = "none". The
# join/recast core family additionally gets one row PER ARGUMENT, so
# argument-level gaps are visible.
#
# Coverage comes from two scans of tests/testthat/*.R:
#   1. Structured tags (authoritative):
#        # @covers join_calendar depth=B backends=data.frame,tibble,arrow
#      depth in U < P < B (unit < property < backend-swept).
#   2. Keyword inference (fallback, status="inferred"): exact-name mention;
#      file depth B if it sweeps backends, P if it uses the invariant
#      harness, else U. Argument rows infer from `arg =` next to the verb.
#
# Outputs: tests/coverage/function-matrix.csv, tests/coverage/matrix-summary.md
# Adapted from energyRt/tools/coverage/build_matrix.R (parameter surface).
# =========================================================================== #

suppressMessages({
  stopifnot(file.exists("DESCRIPTION"))
  PKG <- unname(read.dcf("DESCRIPTION")[1, "Package"])
  # already loaded when sourced from the test suite; load from source
  # otherwise (metadata must match the code under test)
  if (!isNamespaceLoaded(PKG)) {
    if (requireNamespace("pkgload", quietly = TRUE)) {
      pkgload::load_all(".", quiet = TRUE, export_all = FALSE)
    } else {
      library(PKG, character.only = TRUE)
    }
  }
  library(data.table)
})

DEPTHS <- c(none = 0L, U = 1L, P = 2L, B = 3L)
depth_max <- function(a, b) names(DEPTHS)[max(DEPTHS[[a]], DEPTHS[[b]]) + 1L]

BACKENDS <- c("data.frame", "tibble", "data.table", "dtplyr", "arrow")

# The backend-plumbed core family (per package): must carry depth=B tags
core_family <- function() {
  if (PKG == "timescales") {
    c("join_calendar", "recast_calendar", "recast_to_timebase",
      "recast_from_timebase")
  } else {
    c("join_geoscale", "recast_geoscale", "recast_to_geoatoms",
      "recast_from_geoatoms")
  }
}

# The wider family that gets per-argument rows (core + structure verbs)
arg_family <- function() {
  c(core_family(),
    if (PKG == "timescales") c("filter_calendar", "prune_calendar")
    else c("filter_geoscale", "prune_geoscale"))
}

# --------------------------------------------------------------------------- #
# Row assembly from the NAMESPACE surface
# --------------------------------------------------------------------------- #

ns_exports <- function() {
  ln <- readLines("NAMESPACE", warn = FALSE)
  ex <- sub("^export\\((.*)\\)$", "\\1", grep("^export\\(", ln, value = TRUE))
  ex <- gsub('"', "", ex)
  sort(unique(ex[!grepl("^\\[", ex)]))
}

kind_of <- function(nm, obj) {
  if (!is.function(obj)) return("constant")
  if (grepl("^(register|get|list|clear)_", nm)) return("registry")
  if (grepl("^(geom_|theme_)|_(autoplot|plot|layout|breaks)$|_wall_|weekdays$",
            nm)) return("plot")
  if (grepl("^(Calendar|Geoscale)$|_from_|_build$|^calendar$|^base_calendar$|^ne_|_example$",
            nm)) return("constructor")
  if (grepl("^(join|recast|filter|prune|expand|attach|add|zoom)_|_to_timeslice$|_to_region$|^as_timeframe$|^instant",
            nm)) return("verb")
  "query"
}

assemble_rows <- function() {
  ns <- asNamespace(PKG)
  ex <- ns_exports()
  rows <- rbindlist(lapply(ex, function(nm) {
    obj <- tryCatch(get(nm, envir = ns), error = function(e) NULL)
    args <- if (is.function(obj)) paste(names(formals(obj)), collapse = "+")
            else ""
    data.table(name = nm, kind = kind_of(nm, obj), args = args, of = "")
  }))
  # argument rows for the core family: "fn(arg)"
  arg_rows <- rbindlist(lapply(intersect(arg_family(), ex), function(fn) {
    fm <- names(formals(get(fn, envir = ns)))
    data.table(name = paste0(fn, "(", fm, ")"), kind = "argument",
               args = "", of = fn)
  }))
  rbindlist(list(rows, arg_rows))
}

# --------------------------------------------------------------------------- #
# Test-file scanning (tag grammar identical to energyRt's)
# --------------------------------------------------------------------------- #

test_dir_default <- function() file.path("tests", "testthat")

file_depth <- function(txt) {
  blob <- paste(txt, collapse = "\n")
  sweeps <- grepl("expect_backend_contract|test_backends\\(", blob) ||
    sum(vapply(BACKENDS[-1], function(b) grepl(b, blob, fixed = TRUE),
               TRUE)) >= 2
  props <- grepl(paste0("expect_conserves|expect_composition_identity|",
                        "expect_round_trip|expect_within_envelope|",
                        "expect_join_contract|expect_completion"), blob)
  if (sweeps) "B" else if (props) "P" else "U"
}

parse_tags <- function(lines, file) {
  hits <- grep("^\\s*#+\\s*@covers\\s+", lines, value = TRUE)
  if (!length(hits)) return(NULL)
  rbindlist(lapply(hits, function(h) {
    body <- sub("^\\s*#+\\s*@covers\\s+", "", h)
    toks <- strsplit(trimws(body), "\\s+")[[1]]
    kv <- grepl("=", toks, fixed = TRUE) & !grepl("\\(", toks)
    opts <- toks[kv]; names_ <- toks[!kv]
    getopt <- function(key, default) {
      m <- grep(paste0("^", key, "="), opts, value = TRUE)
      if (length(m)) sub(paste0("^", key, "="), "", m[1]) else default
    }
    data.table(name = names_, depth = getopt("depth", "U"),
               backends = getopt("backends", ""), file = file)
  }))
}

scan_tests <- function(dir = test_dir_default()) {
  files <- list.files(dir, pattern = "^(test|helper)-.*\\.R$",
                      full.names = TRUE)
  tags <- list(); infer <- list()
  for (f in files) {
    lines <- readLines(f, warn = FALSE, encoding = "UTF-8")
    tg <- parse_tags(lines, basename(f))
    if (!is.null(tg)) tags[[f]] <- tg
    infer[[basename(f)]] <- list(txt = lines, depth = file_depth(lines))
  }
  list(tags = if (length(tags)) rbindlist(tags) else NULL, files = infer)
}

infer_coverage <- function(rows, files) {
  res <- rows[, .(name, kind, of)]
  res[, `:=`(inf_depth = "none", inf_files = "")]
  for (fn in names(files)) {
    blob <- paste(files[[fn]]$txt, collapse = "\n")
    fd <- files[[fn]]$depth
    for (i in seq_len(nrow(res))) {
      if (res$kind[i] == "argument") {
        verb <- res$of[i]
        arg <- sub("^.*\\((.*)\\)$", "\\1", res$name[i])
        # structure/selector args are usually passed positionally
        positional <- c("x", "...", "calendar", "gs", "from", "to",
                        "timeframe", "geoframe", "labels", "region")
        hit <- grepl(paste0("\\b", verb, "\\b"), blob) &&
          (arg %in% positional ||
             grepl(paste0("\\b", arg, "\\s*="), blob))
      } else {
        hit <- grepl(paste0("\\b", res$name[i], "\\b"), blob)
      }
      if (hit) {
        res$inf_depth[i] <- depth_max(res$inf_depth[i], fd)
        res$inf_files[i] <- sub("^;", "", paste(
          c(strsplit(res$inf_files[i], ";")[[1]], fn), collapse = ";"))
      }
    }
  }
  res[, .(name, inf_depth, inf_files)]
}

# --------------------------------------------------------------------------- #
# Tag validation (--check)
# --------------------------------------------------------------------------- #

check_tags <- function(dir = test_dir_default(), rows = assemble_rows()) {
  sc <- scan_tests(dir)
  if (is.null(sc$tags)) {
    message("No @covers tags found -- nothing to validate.")
    return(invisible(TRUE))
  }
  known <- rows$name
  bad_name <- sc$tags[!name %in% known]
  bad_depth <- sc$tags[!depth %in% names(DEPTHS)]
  bad_bk <- sc$tags[nzchar(backends) &
                      !vapply(strsplit(backends, ","),
                              function(b) all(b %in% BACKENDS), TRUE)]
  ok <- TRUE
  for (dt_bad in list(bad_name, bad_depth, bad_bk)) {
    if (nrow(dt_bad)) {
      ok <- FALSE
      for (i in seq_len(nrow(dt_bad)))
        message("BAD @covers entry '", dt_bad$name[i], "' (depth=",
                dt_bad$depth[i], " backends=", dt_bad$backends[i],
                ") in ", dt_bad$file[i])
    }
  }
  if (ok) message("All ", nrow(sc$tags), " @covers tags resolve.")
  invisible(ok)
}

# --------------------------------------------------------------------------- #
# Matrix build + summary
# --------------------------------------------------------------------------- #

build_matrix <- function(dir = test_dir_default()) {
  rows <- assemble_rows()
  sc <- scan_tests(dir)
  inf <- infer_coverage(rows, sc$files)
  rows[inf, `:=`(covered_depth = i.inf_depth, test_files = i.inf_files),
       on = "name"]
  rows[, `:=`(backends_covered = "",
              status = fifelse(covered_depth == "none", "", "inferred"))]
  if (!is.null(sc$tags)) {
    agg <- sc$tags[, .(
      depth = names(DEPTHS)[max(DEPTHS[depth]) + 1L],
      backends = paste(sort(unique(setdiff(
        unlist(strsplit(backends, ",")), ""))), collapse = ","),
      files = paste(sort(unique(file)), collapse = ";")
    ), by = name]
    rows[agg, `:=`(covered_depth = i.depth, backends_covered = i.backends,
                   test_files = i.files, status = "tagged"), on = "name"]
  }
  setcolorder(rows, c("name", "kind", "of", "args", "covered_depth",
                      "backends_covered", "test_files", "status"))
  rows[]
}

write_summary <- function(rows, path) {
  lines <- c("# Coverage matrix summary", "",
             paste0("Package: ", PKG, " ",
                    as.character(packageVersion(PKG))), "")
  tab <- dcast(rows[, .N, by = .(kind, covered_depth)],
               kind ~ factor(covered_depth, levels = names(DEPTHS)),
               value.var = "N", fill = 0L)
  lines <- c(lines, "## Rows by kind x depth", "", "```",
             capture.output(print(tab, row.names = FALSE)), "```", "")

  # the backend table of the core entry points, from tags
  core <- rows[name %in% core_family() & nzchar(backends_covered)]
  bk_tab <- rbindlist(lapply(seq_len(nrow(core)), function(i) {
    got <- strsplit(core$backends_covered[i], ",")[[1]]
    as.data.table(c(list(fn = core$name[i]),
                    stats::setNames(as.list(BACKENDS %in% got), BACKENDS)))
  }))
  lines <- c(lines, "## Backend sweep (from @covers tags)", "", "```",
             if (nrow(bk_tab)) capture.output(print(bk_tab, row.names = FALSE))
             else "(no depth=B tags yet)", "```", "")

  gaps <- rows[covered_depth == "none"][order(kind, name)]
  lines <- c(lines, paste0("## Zero-coverage rows (", nrow(gaps), ")"), "",
             "```",
             capture.output(print(gaps[, .(name, kind)], row.names = FALSE,
                                  nrows = Inf)), "```", "")
  lines <- c(lines, paste0(
    "Tagged rows: ", rows[status == "tagged", .N],
    " | inferred: ", rows[status == "inferred", .N],
    " | uncovered: ", rows[covered_depth == "none", .N],
    " of ", nrow(rows)))
  writeLines(lines, path)
}

main <- function(args = commandArgs(trailingOnly = TRUE)) {
  if ("--check" %in% args) {
    ok <- check_tags()
    quit(status = if (isTRUE(ok)) 0L else 1L)
  }
  out_dir <- file.path("tests", "coverage")
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  rows <- build_matrix()
  csv <- file.path(out_dir, "function-matrix.csv")
  fwrite(rows, csv)
  write_summary(rows, file.path(out_dir, "matrix-summary.md"))
  message("Wrote ", csv, " (", nrow(rows), " rows) and matrix-summary.md")
}

if (sys.nframe() == 0L) main()
