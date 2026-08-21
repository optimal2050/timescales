# join_calendar(): calendar-named attach, multi-calendar coexistence ---------

test_that("the label column is named after the calendar", {
  cal <- calendar("m12_h24")
  x <- data.frame(timeslice = S7::prop(cal, "leaftable")$timeslice, v = 1)
  j <- join_calendar(x, cal)
  expect_named(j, c("timeslice", "v", "m12_h24"))
  expect_identical(j$m12_h24, j$timeslice)
})

test_that("two calendars attach side by side from a datetime key", {
  xt <- data.frame(
    datetime = seq(as.POSIXct("2021-01-01", tz = "UTC"),
                   by = "hour", length.out = 72),
    v = 1)
  j <- join_calendar(xt, calendar("m12_h24"))
  j <- join_calendar(j, calendar("q4_h24"))
  expect_true(all(c("m12_h24", "q4_h24") %in% names(j)))
  expect_equal(j$m12_h24[1], "m01_h00")
  expect_equal(j$q4_h24[1],  "Q1_h00")
  # the attached pair matches datetime_to_timeslice directly
  expect_identical(j$m12_h24,
                   datetime_to_timeslice(xt$datetime, calendar("m12_h24")))
})

test_that("attach refuses to overwrite existing columns", {
  cal <- calendar("m12")
  # a prefixed column that the attach would produce already exists
  x <- data.frame(timeslice = "m01", m12.MONTH = "clash", v = 1)
  expect_error(join_calendar(x, cal, timeframes = "MONTH"), "overwrite")
  # an existing calendar-named column is reused as the key -- garbage in it
  # is a no-match error, not an overwrite
  x2 <- data.frame(timeslice = "m01", m12 = "clash", v = 1)
  expect_error(join_calendar(x2, cal), "no rows")
})

test_that("timeframe and meta columns come calendar-prefixed", {
  cal <- calendar("m12_h24")
  x <- data.frame(timeslice = S7::prop(cal, "leaftable")$timeslice, v = 1)
  j <- join_calendar(x, cal, timeframes = "MONTH", meta = TRUE)
  expect_true(all(c("m12_h24", "m12_h24.MONTH", "m12_h24.share",
                    "m12_h24.weight") %in% names(j)))
  expect_true(is.factor(j$m12_h24.MONTH))
  j2 <- join_calendar(x, cal, timeframes = "MONTH", as_factor = FALSE)
  expect_type(j2$m12_h24.MONTH, "character")
})

test_that("an existing calendar-named column is reused as the key", {
  cal <- calendar("m12")
  x <- data.frame(m12 = sprintf("m%02d", 1:12), v = 1)
  j <- join_calendar(x, cal, timeframes = "MONTH")
  expect_named(j, c("m12", "v", "m12.MONTH"))
  # nothing requested and label present -> unchanged
  expect_identical(join_calendar(x[, "m12", drop = FALSE], cal),
                   x[, "m12", drop = FALSE])
})

test_that("an unnamed calendar cannot attach", {
  m12 <- calendar_build("m12")
  anon <- calendar_from_leaftable(
    S7::prop(m12, "leaftable"), timeframes = S7::prop(m12, "timeframes"))
  x <- data.frame(timeslice = "m01", v = 1)
  expect_error(join_calendar(x, anon), "no name")
})
