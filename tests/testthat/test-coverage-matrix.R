# =========================================================================== #
# The coverage matrix guards itself: every @covers tag must resolve against
# the function surface (a typo fails the suite), every export must classify,
# and the NAMESPACE must be intact. tools/coverage/build_matrix.R is the
# generator; tests/coverage/ holds the committed artifacts.
# =========================================================================== #

.matrix_tool_env <- function() {
  root <- normalizePath(test_path("..", ".."), mustWork = TRUE)
  tool <- file.path(root, "tools", "coverage", "build_matrix.R")
  skip_if(!file.exists(tool), "tools/coverage/build_matrix.R not present")
  skip_if_not_installed("data.table")
  env <- new.env(parent = globalenv())
  withr::with_dir(root, sys.source(tool, envir = env))
  env
}

test_that("every @covers tag resolves against the function surface", {
  env <- .matrix_tool_env()
  root <- normalizePath(test_path("..", ".."))
  expect_true(withr::with_dir(root, env$check_tags()))
})

test_that("every export classifies; the surface is complete", {
  env <- .matrix_tool_env()
  root <- normalizePath(test_path("..", ".."))
  rows <- withr::with_dir(root, env$build_matrix())
  expect_true(all(rows$kind %in% c("constant", "constructor", "verb",
                                   "query", "registry", "plot",
                                   "argument")))
  expect_true(all(nzchar(rows$name)))
  expect_false(any(duplicated(rows$name)))
  # the whole backend-plumbed core family carries depth=B tags
  core <- rows[rows$name %in% env$core_family() & rows$kind != "argument", ]
  expect_true(all(core$covered_depth %in% c("P", "B")))
})

test_that("NAMESPACE integrity: every export resolves to a real object", {
  # parse from disk -- load_all(export_all=TRUE) would mask a bad export
  np <- test_path("..", "..", "NAMESPACE")
  skip_if(!file.exists(np),
          "source NAMESPACE not present (installed-package check run)")
  ln <- readLines(np, warn = FALSE)
  ex <- sub("^export\\((.*)\\)$", "\\1",
            grep("^export\\(", ln, value = TRUE))
  ex <- gsub('"', "", ex)
  pkg <- environmentName(topenv(environment(calendar_leaftable)))
  for (nm in ex) {
    # getExportedValue resolves re-exports (e.g. recast) too
    ok <- !inherits(try(getExportedValue(pkg, nm), silent = TRUE),
                    "try-error")
    expect_true(ok, label = sprintf("export %s resolves", nm))
  }
})
