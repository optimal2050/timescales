# Helpers --------------------------------------------------------------------

.month_cal <- function() {
  days <- c(31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31)
  calendar_from_leaves(
    data.frame(MONTH = sprintf("m%02d", 1:12),
               share = days / 365, weight = days),
    timeframes = "MONTH", name = "m12"
  )
}

.quarter_cal <- function() {
  q_days <- c(90, 91, 92, 92)  # non-leap
  calendar_from_leaves(
    data.frame(QUARTER = sprintf("Q%d", 1:4),
               share = q_days / 365, weight = q_days),
    timeframes = "QUARTER", name = "q4"
  )
}

.month_hour_cal <- function() {
  days <- c(31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31)
  names(days) <- sprintf("m%02d", 1:12)
  df <- expand.grid(
    MONTH = sprintf("m%02d", 1:12),
    HOUR  = sprintf("h%02d", 0:23),
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  df$share  <- days[df$MONTH] / 365 / 24
  df$weight <- days[df$MONTH] / 24
  calendar_from_leaves(df, timeframes = c("MONTH", "HOUR"), name = "m12_h24")
}

# instant_to_slice -----------------------------------------------------------

test_that("instant_to_slice maps datetimes to slice IDs (single timeframe)", {
  cal <- .month_cal()
  dtm <- lubridate::ymd(c("2021-01-15", "2021-07-04", "2021-12-31"))
  expect_equal(instant_to_slice(dtm, cal), c("m01", "m07", "m12"))
})

test_that("instant_to_slice maps to composite slice IDs (two timeframes)", {
  cal <- .month_hour_cal()
  dtm <- lubridate::ymd_h(c("2021-01-15 00", "2021-07-04 13"), tz = "UTC")
  expect_equal(instant_to_slice(dtm, cal), c("m01_h00", "m07_h13"))
})

test_that("instant_to_slice returns NA for instants outside coverage", {
  # Calendar covers only Jan + Feb; July datetimes have no matching slice.
  df <- data.frame(MONTH = c("m01", "m02"),
                   share = c(31, 28) / 365, weight = c(31, 28))
  cal <- calendar_from_leaves(df, timeframes = "MONTH",
                              year_fraction = 59 / 365)
  out <- instant_to_slice(lubridate::ymd(c("2021-01-15", "2021-07-04")), cal)
  expect_equal(out, c("m01", NA_character_))
})

test_that("instant_to_slice rejects non-Calendar input", {
  expect_error(instant_to_slice(lubridate::ymd("2021-01-01"), list()),
               "Calendar")
})

# expand_calendar ------------------------------------------------------------

test_that("expand_calendar enumerates a year at the right resolution", {
  cal <- .month_cal()
  grid <- expand_calendar(cal, year = 2021, by = "day")
  expect_named(grid, c("datetime", "slice"))
  expect_equal(nrow(grid), 365)
  expect_setequal(unique(grid$slice), sprintf("m%02d", 1:12))
})

test_that("expand_calendar default resolution follows finest timeframe", {
  cal <- .month_hour_cal()
  grid <- expand_calendar(cal, year = 2021)  # default -> hourly
  expect_equal(nrow(grid), 365 * 24)
})

test_that("expand_calendar handles leap years correctly", {
  cal <- .month_cal()
  grid <- expand_calendar(cal, year = 2020, by = "day")
  expect_equal(nrow(grid), 366)
  # Feb 29 still maps to m02 because the calendar has m02
  feb29 <- grid$slice[grid$datetime == as.POSIXct("2020-02-29", tz = "UTC")]
  expect_equal(feb29, "m02")
})

# recast ---------------------------------------------------------------------

test_that("recast aggregates monthly -> quarterly with day-weighted mean", {
  cal_m <- .month_cal()
  cal_q <- .quarter_cal()
  x <- data.frame(slice = sprintf("m%02d", 1:12),
                  load  = seq(100, 210, length.out = 12))
  out <- recast(x, from = cal_m, to = cal_q, year = 2021,
                rule = "weighted_mean", by = "day")
  expect_named(out, c("slice", "load"))
  expect_equal(out$slice, sprintf("Q%d", 1:4))

  # Q1 = (31*v1 + 28*v2 + 31*v3) / 90
  v <- x$load
  expected_q1 <- (31 * v[1] + 28 * v[2] + 31 * v[3]) / 90
  expect_equal(out$load[1], expected_q1, tolerance = 1e-10)
})

test_that("recast 'sum' rule sums values across grid instants", {
  cal_m <- .month_cal()
  cal_q <- .quarter_cal()
  # one unit per month -> Q1 should sum to 90 (days in Q1) on daily grid
  x <- data.frame(slice = sprintf("m%02d", 1:12), v = rep(1, 12))
  out <- recast(x, from = cal_m, to = cal_q, year = 2021,
                rule = "sum", by = "day")
  expect_equal(out$v[1], 90)  # 31 + 28 + 31
  expect_equal(out$v[2], 91)  # 30 + 31 + 30
})

test_that("recast roundtrips identity on the same calendar", {
  cal <- .month_cal()
  x <- data.frame(slice = sprintf("m%02d", 1:12),
                  v = seq_len(12) * 1.5)
  out <- recast(x, from = cal, to = cal, year = 2021, by = "day")
  expect_equal(out$v, x$v, tolerance = 1e-10)
})

test_that("recast warns when source slices are missing from x", {
  cal_m <- .month_cal()
  cal_q <- .quarter_cal()
  x <- data.frame(slice = sprintf("m%02d", 1:6),  # only first half-year
                  load  = 1:6 * 1.0)
  expect_warning(
    recast(x, from = cal_m, to = cal_q, year = 2021, by = "day"),
    "missing from `x`"
  )
})

test_that("recast errors when key column missing", {
  cal_m <- .month_cal()
  cal_q <- .quarter_cal()
  x <- data.frame(month = sprintf("m%02d", 1:12), v = 1:12)
  expect_error(
    recast(x, from = cal_m, to = cal_q, year = 2021),
    "no column named"
  )
})

test_that("recast handles multiple value columns", {
  cal_m <- .month_cal()
  cal_q <- .quarter_cal()
  x <- data.frame(slice = sprintf("m%02d", 1:12),
                  a = 1:12 * 1.0,
                  b = 12:1 * 1.0)
  out <- recast(x, from = cal_m, to = cal_q, year = 2021, by = "day")
  expect_named(out, c("slice", "a", "b"))
  expect_equal(nrow(out), 4)
})
