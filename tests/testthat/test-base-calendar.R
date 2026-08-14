# base_calendar ---------------------------------------------------------------

test_that("base_calendar enumerates real years, leap-aware", {
  expect_equal(nrow(base_calendar(2021)), 8760)
  expect_equal(nrow(base_calendar(2020)), 8784)
  expect_named(base_calendar(2021), c("datetime", "year"))
})

test_that("base_calendar spans multiple years at any step", {
  g <- base_calendar(2019:2020, by = "day")
  expect_equal(nrow(g), 365 + 366)
  expect_equal(unique(g$year), c(2019L, 2020L))
  expect_equal(g$datetime[1], as.POSIXct("2019-01-01", tz = "UTC"))
})

test_that("base_calendar results are cached", {
  a <- base_calendar(2021, by = "day")
  b <- base_calendar(2021, by = "day")
  expect_identical(a, b)
})

test_that("base_calendar validates years", {
  expect_error(base_calendar(integer(0)), "integers")
  expect_error(base_calendar(NA), "integers")
})

# prune_calendar -----------------------------------------------------------

test_that("prune_calendar truncates the hierarchy and sums shares", {
  cal <- calendar_build("q4", "h24")
  q <- prune_calendar(cal, "QUARTER")

  expect_equal(S7::prop(q, "timeframes"), "QUARTER")
  expect_equal(S7::prop(q, "leaves")$timeslice, sprintf("Q%d", 1:4))
  # Shares sum over the dropped hours: quarter share is preserved
  expect_equal(S7::prop(q, "leaves")$share,
               c(90, 91, 92, 92) / 365, tolerance = 1e-9)
  expect_equal(sum(S7::prop(q, "leaves")$share), 1, tolerance = 1e-9)
  expect_equal(S7::prop(q, "meta")$name, "q4_h24@QUARTER")
})

test_that("prune_calendar('ANNUAL') returns the one-timeslice root", {
  cal <- calendar_build("m12", "h24")
  root <- prune_calendar(cal, "ANNUAL")

  expect_equal(S7::prop(root, "timeframes"), "ANNUAL")
  lv <- S7::prop(root, "leaves")
  expect_equal(nrow(lv), 1L)
  expect_equal(lv$timeslice, "ANNUAL")
  expect_equal(lv$share, 1, tolerance = 1e-9)
})

test_that("prune_calendar keeps token/alignment provenance of kept levels", {
  cal <- calendar_build("d365", "h24")
  d <- prune_calendar(cal, "YDAY")
  meta <- S7::prop(d, "meta")
  expect_equal(unname(meta$tokens["YDAY"]), "d365")
  expect_equal(meta$alignment$YDAY, "drop_feb29")
})

test_that("prune_calendar rejects unknown timeframes", {
  cal <- calendar_build("m12")
  expect_error(prune_calendar(cal, "HOUR"), "timeframes")
})

test_that("instant_to_timeslice works on an ANNUAL root calendar", {
  root <- prune_calendar(calendar_build("m12"), "ANNUAL")
  dtm <- lubridate::ymd(c("2021-01-01", "2021-12-31"))
  expect_equal(instant_to_timeslice(dtm, root), c("ANNUAL", "ANNUAL"))
})
