test_that("CORE_TIMEFRAMES is the expected vocabulary", {
  expect_type(CORE_TIMEFRAMES, "character")
  expect_true(all(c("YEAR", "MONTH", "MDAY", "YDAY", "HOUR", "MINUTE",
                    "SECOND", "WDAY", "WEEK", "MWEEK", "QUARTER")
                  %in% CORE_TIMEFRAMES))
})

test_that("as_timeframe.POSIXt extracts numeric values", {
  dtm <- lubridate::ymd_h("2020-03-15 14", tz = "UTC")
  expect_equal(as_timeframe(dtm, "YEAR"), 2020)
  expect_equal(as_timeframe(dtm, "MONTH"), 3)
  expect_equal(as_timeframe(dtm, "MDAY"), 15)
  expect_equal(as_timeframe(dtm, "YDAY"), 75)
  expect_equal(as_timeframe(dtm, "HOUR"), 14)
})

test_that("as_timeframe formats as tokens", {
  dtm <- lubridate::ymd_h("2020-03-15 14", tz = "UTC")
  expect_equal(as_timeframe(dtm, "MONTH", format = "token"), "m03")
  expect_equal(as_timeframe(dtm, "HOUR", format = "token"), "h14")
  expect_equal(as_timeframe(dtm, "YDAY", format = "token"), "d075")
  expect_equal(as_timeframe(dtm, "YEAR", format = "token"), "y2020")
})

test_that("as_timeframe.Date works on Date input", {
  d <- as.Date("2020-03-15")
  expect_equal(as_timeframe(d, "MONTH"), 3)
  expect_equal(as_timeframe(d, "MDAY", format = "token"), "d15")
})

test_that("as_timeframe rejects unknown timeframes", {
  expect_error(
    as_timeframe(lubridate::ymd("2020-01-01"), "BANANA"),
    "Unsupported timeframe"
  )
})

test_that("as_timeframe rejects unsupported classes", {
  expect_error(as_timeframe("not a date", "YEAR"),
               "not implemented for class")
})

test_that("as_timeframe preserves NA positions", {
  dtm <- c(lubridate::ymd("2020-01-01"), NA, lubridate::ymd("2020-12-31"))
  expect_equal(as_timeframe(dtm, "MONTH"),
               c(1, NA_integer_, 12))
  expect_equal(as_timeframe(dtm, "MONTH", format = "token"),
               c("m01", NA_character_, "m12"))
})

test_that("WDAY token formatting honours week_start", {
  # 2020-01-01 was a Wednesday
  dtm <- lubridate::ymd("2020-01-01")
  expect_equal(as_timeframe(dtm, "WDAY", format = "token"), "WED")
})

test_that("MWEEK uses calendar-grid (not naive ceil)", {
  # 2020-03-01 = Sunday → first row of March grid (Sunday-start)
  expect_equal(as_timeframe(lubridate::ymd("2020-03-01"), "MWEEK"), 1)
  expect_equal(as_timeframe(lubridate::ymd("2020-03-15"), "MWEEK"), 3)
})
