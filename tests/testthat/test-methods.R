# =========================================================================== #
# Base-generic methods on Calendar: summary / names / as.data.frame /
# ggplot2::fortify (mirrored in geoscales/tests/testthat/test-methods.R).
# =========================================================================== #

# @covers calendar_coverage calendar_leaftable depth=U
test_that("summary() returns the classed quantitative view", {
  cal <- calendar("m12_h24")
  s <- summary(cal)
  expect_s3_class(s, "summary_Calendar")
  expect_named(s, c("name", "desc", "timeframes", "n_timeslices",
                    "year_fraction", "coverage", "sampled", "parent_name",
                    "coverage_class", "regularity", "share_range",
                    "weight_range", "year_start", "utc_offset_minutes"))
  expect_equal(s$timeframes, c(MONTH = 12L, HOUR = 24L))
  expect_identical(s$n_timeslices, 288L)
  expect_false(s$sampled)
  expect_identical(s$coverage_class, "complete")  # catalog metadata
  expect_output(print(s), "summary of Calendar 'm12_h24'")
  expect_output(print(s), "MONTH \\(12\\) / HOUR \\(24\\)")
})

test_that("summary() reports a sample's coverage and parent", {
  win <- filter_calendar(calendar("s4_h24"), "SEASON", "WIN")
  s <- summary(win)
  expect_true(s$sampled)
  expect_lt(s$coverage[["share"]], 1)
  expect_identical(s$parent_name, "s4_h24")
  expect_output(print(s), "SAMPLED")
  expect_output(print(s), "of 's4_h24'")
})

test_that("names() returns the timeframes, not leaftable columns", {
  cal <- calendar("q4_h24")
  expect_identical(names(cal), calendar_timeframes(cal))
  expect_identical(names(cal), c("QUARTER", "HOUR"))
})

test_that("as.data.frame() equals the leaftable accessor", {
  cal <- calendar("m12")
  expect_identical(as.data.frame(cal), calendar_leaftable(cal))
})

test_that("fortify() feeds ggplot() directly", {
  skip_if_not_installed("ggplot2")
  cal <- calendar("m12")
  expect_identical(ggplot2::fortify(cal), calendar_leaftable(cal))
  p <- ggplot2::ggplot(cal) +
    ggplot2::geom_col(ggplot2::aes(timeslice, share))
  expect_s3_class(p, "ggplot")
  built <- ggplot2::ggplot_build(p)
  expect_identical(nrow(built$data[[1]]), 12L)
})
