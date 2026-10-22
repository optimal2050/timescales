# `from`/`to` renamed `source`/`target` in 0.7.0; the old names still work ---

test_that("from/to still work, with a deprecation warning", {
  cal <- calendar("m12_h24")
  rlang::local_options(lifecycle_verbosity = "warning")
  new <- calendar_map(cal, "MONTH", "HOUR")
  old <- suppressWarnings(calendar_map(cal, from = "MONTH", to = "HOUR"))
  expect_identical(old, new)
  expect_warning(calendar_children(cal, "MONTH", "m01", to = "HOUR"),
                 "deprecated")
})

test_that("passing both spellings is an error", {
  cal <- calendar("m12_h24")
  expect_error(calendar_map(cal, "MONTH", target = "HOUR", to = "HOUR"),
               "pass `target` only")
})
