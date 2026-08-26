# =========================================================================== #
# Cross-language golden specs: the R implementation re-loads every
# specs/golden pair and must reproduce expected.csv (the C++/Python ports
# consume the same files later). Generator + shared runner:
# tools/specs/make_goldens.R. Behaviour change => regenerate in the same
# commit.
# =========================================================================== #

skip_if_not_installed("yaml")

.specs_env <- function() {
  root <- normalizePath(test_path("..", ".."), mustWork = TRUE)
  tool <- file.path(root, "tools", "specs", "make_goldens.R")
  skip_if(!file.exists(tool), "tools/specs/make_goldens.R not present")
  env <- new.env(parent = globalenv())
  withr::with_dir(root, sys.source(tool, envir = env))
  list(env = env, root = root)
}

test_that("every golden spec reproduces under the R implementation", {
  s <- .specs_env()
  golden <- file.path(s$root, "specs", "golden")
  skip_if(!dir.exists(golden), "no specs/golden yet")
  dirs <- list.dirs(golden, recursive = FALSE)
  expect_gt(length(dirs), 0)
  for (d in dirs) {
    files <- list.files(d)
    expect_setequal(files, c("input.yaml", "expected.csv"))
    spec <- yaml::read_yaml(file.path(d, "input.yaml"))
    got <- withr::with_dir(
      s$root, suppressWarnings(s$env$run_spec_op(spec)))
    exp <- utils::read.csv(file.path(d, "expected.csv"),
                           stringsAsFactors = FALSE)
    expect_identical(nrow(got), nrow(exp),
                     label = paste0(basename(d), " row count"))
    for (cc in names(exp)) {
      g <- got[[cc]]
      if (is.numeric(g)) {
        expect_equal(g, as.numeric(exp[[cc]]), tolerance = 1e-12,
                     label = paste0(basename(d), "$", cc))
      } else {
        expect_equal(as.character(g), as.character(exp[[cc]]),
                     label = paste0(basename(d), "$", cc))
      }
    }
  }
})

test_that("specs/ holds no orphan files", {
  s <- .specs_env()
  golden <- file.path(s$root, "specs", "golden")
  skip_if(!dir.exists(golden), "no specs/golden yet")
  loose <- setdiff(list.files(golden), basename(list.dirs(golden,
                                                          recursive = FALSE)))
  expect_identical(loose, character(0))
})
